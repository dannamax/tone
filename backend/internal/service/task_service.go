package service

import (
	"context"
	"errors"
	"fmt"

	"seeker/internal/model"
	"seeker/internal/repository"
	"seeker/internal/websocket"
	"seeker/pkg/geo"
	"seeker/pkg/i18n"
)

// 业务错误码
const (
	ErrInsufficientQuota = "INSUFFICIENT_QUOTA"
)

// TaskError 任务业务错误
type TaskError struct {
	Code    string
	Message string
}

func (e *TaskError) Error() string {
	return e.Message
}

func NewTaskError(code, message string) *TaskError {
	return &TaskError{Code: code, Message: message}
}

type TaskService struct {
	taskRepo       *repository.TaskRepo
	userRepo       *repository.UserRepo
	notifyRepo     *repository.NotificationRepo
	submissionRepo *repository.SubmissionRepo
	wsHub          *websocket.Hub
	txRepo         *repository.TransactionRepo
}

func NewTaskService(
	taskRepo *repository.TaskRepo,
	userRepo *repository.UserRepo,
	notifyRepo *repository.NotificationRepo,
	submissionRepo *repository.SubmissionRepo,
	wsHub *websocket.Hub,
	txRepo *repository.TransactionRepo,
) *TaskService {
	return &TaskService{
		taskRepo:       taskRepo,
		userRepo:       userRepo,
		notifyRepo:     notifyRepo,
		submissionRepo: submissionRepo,
		wsHub:          wsHub,
		txRepo:         txRepo,
	}
}

// Publish 发布任务：原子扣除金豆（先扣充值豆，再扣赚取豆），成功即发布。
// 金豆不足返回 ErrInsufficientQuota（HTTP 402 引导充值）。
func (s *TaskService) Publish(ctx context.Context, publisherID string, req *model.PublishTaskRequest) (*model.Task, error) {
	// 原子扣豆：不足直接失败，任务不创建
	if err := s.userRepo.DecBeans(ctx, publisherID, req.BountyBeans); err != nil {
		if err == repository.ErrQuotaInsufficient {
			return nil, NewTaskError(ErrInsufficientQuota,
				i18n.TCtx(ctx, "insufficient_beans", req.BountyBeans))
		}
		return nil, fmt.Errorf("%s: %w", i18n.TCtx(ctx, "bean_spend_failed"), err)
	}

	task := &model.Task{
		PublisherID: publisherID,
		Title:       req.Title,
		Description: req.Description,
		TargetLat:   req.TargetLat,
		TargetLng:   req.TargetLng,
		TargetAddr:  req.TargetAddr,
		Radius:      req.Radius,
		TimeLimit:   req.TimeLimit,
		BountyBeans: req.BountyBeans,
		Status:      model.StatusPublished,
	}

	created, err := s.taskRepo.Create(ctx, task)
	if err != nil {
		// 创建失败回滚已扣金豆
		_ = s.userRepo.AddBeans(ctx, publisherID, req.BountyBeans, false)
		return nil, fmt.Errorf("%s: %w", i18n.TCtx(ctx, "task_create_failed"), err)
	}

	// 写金豆消耗流水
	s.txRepo.Create(ctx, &model.Transaction{
		TaskID:     &created.ID,
		FromUserID: publisherID,
		Type:       model.TxTypeBeanSpend,
		Status:     model.TxStatusSuccess,
		BeansDelta: -req.BountyBeans,
		Remark:     i18n.T(i18n.LanguageFromCtx(ctx), "bean_spend", req.BountyBeans, created.Title),
	})

	return created, nil
}

func (s *TaskService) GetTask(ctx context.Context, taskID string) (*model.Task, error) {
	task, err := s.taskRepo.FindByID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	if task == nil {
		return nil, errors.New(i18n.TCtx(ctx, "task_not_found"))
	}
	return task, nil
}

func (s *TaskService) SquareList(ctx context.Context, req *model.SquareListRequest) ([]model.Task, int64, error) {
	return s.taskRepo.SquareList(ctx, req.Lat, req.Lng, req.DefaultRadius(), req.DefaultSize(), req.Offset(), req.NormalizedSort())
}

func (s *TaskService) Claim(ctx context.Context, taskID, claimerID string) error {
	activeCount, err := s.taskRepo.CountClaimedByUser(ctx, claimerID)
	if err != nil {
		return err
	}
	if activeCount >= model.MaxConcurrentTasks {
		return errors.New(i18n.TCtx(ctx, "max_concurrent_tasks", model.MaxConcurrentTasks))
	}

	task, err := s.taskRepo.FindByID(ctx, taskID)
	if err != nil {
		return err
	}
	if task == nil {
		return errors.New(i18n.TCtx(ctx, "task_not_found"))
	}
	if task.PublisherID == claimerID {
		return errors.New(i18n.TCtx(ctx, "cannot_claim_own"))
	}
	if task.Status != model.StatusPublished {
		return errors.New(i18n.TCtx(ctx, "task_already_claimed"))
	}

	if err := s.taskRepo.Claim(ctx, taskID, claimerID); err != nil {
		return err
	}

	lang := i18n.LanguageFromCtx(ctx)
	s.notifyRepo.Create(ctx, task.PublisherID, "task_claimed",
		i18n.T(lang, "notif_task_claimed_title"),
		i18n.T(lang, "notif_task_claimed_body", task.Title),
		taskID)

	s.wsHub.SendToUser(task.PublisherID, websocket.Message{
		Type:    websocket.MsgTypeTaskClaimed,
		Payload: map[string]string{"task_id": taskID},
	})

	return nil
}

func (s *TaskService) Submit(ctx context.Context, taskID, claimerID string, req *model.SubmitEvidenceRequest) (*model.Submission, error) {
	task, err := s.taskRepo.FindByID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	if task == nil {
		return nil, errors.New(i18n.TCtx(ctx, "task_not_found"))
	}
	if task.Status != model.StatusClaimed || (task.ClaimerID == nil || *task.ClaimerID != claimerID) {
		return nil, errors.New(i18n.TCtx(ctx, "not_claimer"))
	}

	if !geo.IsWithinRadius(task.TargetLat, task.TargetLng, req.SubmitLat, req.SubmitLng, task.Radius) {
		return nil, errors.New(i18n.TCtx(ctx, "not_in_radius"))
	}

	if err := s.taskRepo.Submit(ctx, taskID); err != nil {
		return nil, err
	}

	sub := &model.Submission{
		TaskID:    taskID,
		ClaimerID: claimerID,
		Note:      req.Note,
		SubmitLat: req.SubmitLat,
		SubmitLng: req.SubmitLng,
	}
	for _, p := range req.Photos {
		sub.Photos = append(sub.Photos, model.Photo{
			URL:       p.URL,
			Latitude:  p.Latitude,
			Longitude: p.Longitude,
			Timestamp: p.Timestamp,
		})
	}

	created, err := s.submissionRepo.Create(ctx, sub)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", i18n.TCtx(ctx, "submission_save_failed"), err)
	}

	lang := i18n.LanguageFromCtx(ctx)
	s.notifyRepo.Create(ctx, task.PublisherID, "task_submitted",
		i18n.T(lang, "notif_task_submitted_title"),
		i18n.T(lang, "notif_task_submitted_body", task.Title),
		taskID)

	s.wsHub.SendToUser(task.PublisherID, websocket.Message{
		Type:    websocket.MsgTypeTaskSubmitted,
		Payload: map[string]string{"task_id": taskID, "submission_id": created.ID},
	})

	return created, nil
}

func (s *TaskService) GetPublishedTasks(ctx context.Context, userID string, page, size int) ([]model.Task, int64, error) {
	return s.taskRepo.FindPublishedByUser(ctx, userID, page, size)
}

func (s *TaskService) GetClaimedTasks(ctx context.Context, userID string, page, size int) ([]model.Task, int64, error) {
	return s.taskRepo.FindClaimedByUser(ctx, userID, page, size)
}

type SubmissionService struct {
	submissionRepo *repository.SubmissionRepo
}

func NewSubmissionService(submissionRepo *repository.SubmissionRepo) *SubmissionService {
	return &SubmissionService{submissionRepo: submissionRepo}
}

func (s *SubmissionService) GetByTaskID(ctx context.Context, taskID string) (*model.Submission, error) {
	return s.submissionRepo.FindByTaskID(ctx, taskID)
}
