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
	messageRepo    *repository.MessageRepo
	wsHub          *websocket.Hub
	txRepo         *repository.TransactionRepo
}

func NewTaskService(
	taskRepo *repository.TaskRepo,
	userRepo *repository.UserRepo,
	notifyRepo *repository.NotificationRepo,
	submissionRepo *repository.SubmissionRepo,
	messageRepo *repository.MessageRepo,
	wsHub *websocket.Hub,
	txRepo *repository.TransactionRepo,
) *TaskService {
	return &TaskService{
		taskRepo:       taskRepo,
		userRepo:       userRepo,
		notifyRepo:     notifyRepo,
		submissionRepo: submissionRepo,
		messageRepo:    messageRepo,
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

// SkippedTask 批量删除时被跳过的任务及原因（前端展示用）
type SkippedTask struct {
	TaskID string `json:"task_id"`
	Reason string `json:"reason"`
}

// DeleteTasksResult 批量删除结果
type DeleteTasksResult struct {
	Deleted []string      `json:"deleted"`
	Refunded int          `json:"refunded"`   // 其中删除前自动退豆的任务数（原状态为 published）
	Skipped []SkippedTask `json:"skipped"`
}

// isTerminalStatus 终态：金豆闭环已结束，可安全删除
func isTerminalStatus(st model.TaskStatus) bool {
	return st == model.StatusCompleted || st == model.StatusCancelled ||
		st == model.StatusRefunded || st == model.StatusReleased
}

// DeleteTasks 发布人删除自己发布的任务（单个或批量）。
// 金豆安全规则：
//   - completed/cancelled/refunded/released 终态 → 直接删除（金豆已结算完毕）
//   - published（未被认领）→ 删除后自动全额退豆（等同撤回）
//   - claimed/submitted/disputed（进行中）→ 拒绝删除，跳过并返回原因
//
// 执行顺序（防刷豆）：先完成全部删除动作，最后才退豆 —— 若删除失败则
// 退豆不会执行，避免"退豆成功但任务未删"被重复利用。
// 级联清理：履约消息、提交记录、通知、争议；金豆流水保留作为账本
// （仅解除 task_id 关联，remark 中保留任务标题文字）。
func (s *TaskService) DeleteTasks(ctx context.Context, publisherID string, taskIDs []string) (*DeleteTasksResult, error) {
	lang := i18n.LanguageFromCtx(ctx)
	result := &DeleteTasksResult{Deleted: []string{}, Skipped: []SkippedTask{}}

	for _, taskID := range taskIDs {
		task, err := s.taskRepo.FindByID(ctx, taskID)
		if err != nil {
			return nil, err
		}
		if task == nil || task.PublisherID != publisherID {
			result.Skipped = append(result.Skipped, SkippedTask{
				TaskID: taskID,
				Reason: i18n.T(lang, "task_not_found"),
			})
			continue
		}

		// 进行中任务不允许删除（保障猎人履约与金豆闭环）
		if !isTerminalStatus(task.Status) && task.Status != model.StatusPublished {
			result.Skipped = append(result.Skipped, SkippedTask{
				TaskID: taskID,
				Reason: i18n.T(lang, "task_delete_in_progress"),
			})
			continue
		}

		// 1) 解除金豆流水与任务的关联（账本行保留，仅置空 task_id）
		if err := s.txRepo.UnlinkTask(ctx, taskID); err != nil {
			return nil, fmt.Errorf("unlink transactions: %w", err)
		}
		// 2) 级联清理关联数据
		if err := s.messageRepo.DeleteByTaskID(ctx, taskID); err != nil {
			return nil, fmt.Errorf("delete messages: %w", err)
		}
		if err := s.submissionRepo.DeleteByTaskID(ctx, taskID); err != nil {
			return nil, fmt.Errorf("delete submissions: %w", err)
		}
		if err := s.notifyRepo.DeleteByTaskID(ctx, taskID); err != nil {
			return nil, fmt.Errorf("delete notifications: %w", err)
		}
		if err := s.notifyRepo.DeleteDisputeByTaskID(ctx, taskID); err != nil {
			return nil, fmt.Errorf("delete disputes: %w", err)
		}
		// 3) 删除任务本身（校验归属）
		if err := s.taskRepo.DeleteByOwner(ctx, taskID, publisherID); err != nil {
			return nil, err
		}

		// 4) 任务删除成功后才退豆（未认领任务预扣赏金全额返还发布者）
		if task.Status == model.StatusPublished {
			if err := s.userRepo.AddBeans(ctx, publisherID, task.BountyBeans, false); err != nil {
				// 任务已删但退豆失败：记录日志人工对账，不影响后续任务删除
				fmt.Printf("[TaskDelete] REFUND FAILED taskID=%s publisher=%s beans=%d err=%v\n",
					taskID, publisherID, task.BountyBeans, err)
			} else {
				s.txRepo.Create(ctx, &model.Transaction{
					FromUserID: publisherID,
					Type:       model.TxTypeBeanRefund,
					Status:     model.TxStatusSuccess,
					BeansDelta: task.BountyBeans,
					Remark:     i18n.T(lang, "bean_refund", task.BountyBeans, task.Title),
				})
				result.Refunded++
			}
		}
		result.Deleted = append(result.Deleted, taskID)
	}

	return result, nil
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
