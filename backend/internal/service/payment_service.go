package service

import (
	"context"
	"errors"
	"fmt"

	"seeker/internal/model"
	"seeker/internal/repository"
	"seeker/internal/websocket"
	"seeker/pkg/i18n"
)

type PaymentService struct {
	userRepo        *repository.UserRepo
	taskRepo        *repository.TaskRepo
	transactionRepo *repository.TransactionRepo
	notifyRepo      *repository.NotificationRepo
	wsHub           *websocket.Hub
	push            *PushService
}

func NewPaymentService(
	userRepo *repository.UserRepo,
	taskRepo *repository.TaskRepo,
	transactionRepo *repository.TransactionRepo,
	notifyRepo *repository.NotificationRepo,
	wsHub *websocket.Hub,
	push *PushService,
) *PaymentService {
	return &PaymentService{
		userRepo:        userRepo,
		taskRepo:        taskRepo,
		transactionRepo: transactionRepo,
		notifyRepo:      notifyRepo,
		wsHub:           wsHub,
		push:            push,
	}
}

func (s *PaymentService) ConfirmTask(ctx context.Context, taskID, publisherID string) error {
	task, err := s.taskRepo.FindByID(ctx, taskID)
	if err != nil {
		return err
	}
	if task == nil || task.PublisherID != publisherID {
		return errors.New(i18n.TCtx(ctx, "not_publisher"))
	}
	if task.Status != model.StatusSubmitted {
		return errors.New(i18n.TCtx(ctx, "task_status_invalid"))
	}

	if err := s.taskRepo.Confirm(ctx, taskID); err != nil {
		return err
	}

	claimerID := ""
	if task.ClaimerID != nil {
		claimerID = *task.ClaimerID
	}

	// 金豆结算：发布时已预扣，确认后全额发放给猎人（记入 beans_earned）
	if claimerID != "" {
		if err := s.userRepo.AddBeans(ctx, claimerID, task.BountyBeans, true); err != nil {
			return fmt.Errorf("%s: %w", i18n.TCtx(ctx, "bounty_payout_failed"), err)
		}
	}

	lang := i18n.LanguageFromCtx(ctx)
	tx := &model.Transaction{
		TaskID:     &taskID,
		FromUserID: publisherID,
		ToUserID:   &claimerID,
		Type:       model.TxTypeBeanReward,
		Status:     model.TxStatusSuccess,
		BeansDelta: task.BountyBeans,
		Remark:     i18n.T(lang, "bean_reward", task.BountyBeans, task.Title),
	}
	s.transactionRepo.Create(ctx, tx)

	notifyAndPush(ctx, s.notifyRepo, s.push, claimerID, "task_confirmed",
		i18n.T(lang, "notif_bounty_received_title"),
		i18n.T(lang, "notif_bounty_received_body", task.BountyBeans, task.Title),
		taskID)

	if claimerID != "" {
		s.wsHub.SendToUser(claimerID, websocket.Message{
			Type:    websocket.MsgTypeTaskConfirmed,
			Payload: map[string]interface{}{"task_id": taskID, "beans": task.BountyBeans},
		})
	}

	return nil
}

// Recharge adds balance and writes a transaction record (dev/mock only).
func (s *PaymentService) Recharge(ctx context.Context, userID string, amount float64) error {
	if amount <= 0 {
		return errors.New(i18n.TCtx(ctx, "recharge_min_amount"))
	}

	if err := s.userRepo.UpdateBalance(ctx, userID, amount, 0, 0, 0); err != nil {
		return fmt.Errorf("%s: %w", i18n.TCtx(ctx, "recharge_failed"), err)
	}

	lang := i18n.LanguageFromCtx(ctx)
	tx := &model.Transaction{
		FromUserID: userID,
		Amount:     amount,
		Type:       model.TxTypeRecharge,
		Status:     model.TxStatusSuccess,
		Remark:     i18n.T(lang, "recharge_simulated"),
	}
	if _, err := s.transactionRepo.Create(ctx, tx); err != nil {
		return fmt.Errorf("%s: %w", i18n.TCtx(ctx, "recharge_txn_failed"), err)
	}

	return nil
}

func (s *PaymentService) AbandonTask(ctx context.Context, taskID, claimerID string) error {
	task, err := s.taskRepo.FindByID(ctx, taskID)
	if err != nil {
		return err
	}
	if task == nil || task.ClaimerID == nil || *task.ClaimerID != claimerID {
		return errors.New(i18n.TCtx(ctx, "not_claimer"))
	}
	if task.Status != model.StatusClaimed {
		return errors.New(i18n.TCtx(ctx, "task_status_invalid"))
	}

	if err := s.taskRepo.Release(ctx, taskID); err != nil {
		return err
	}

	lang := i18n.LanguageFromCtx(ctx)
	notifyAndPush(ctx, s.notifyRepo, s.push, task.PublisherID, "task_released",
		i18n.T(lang, "notif_task_abandoned_title"),
		i18n.T(lang, "notif_task_abandoned_body", task.Title),
		taskID)

	return nil
}

// CancelByPublisher 允许发布人撤回自己已发布且未被认领的任务，预扣金豆全额返还。
func (s *PaymentService) CancelByPublisher(ctx context.Context, taskID, publisherID string) error {
	task, err := s.taskRepo.FindByID(ctx, taskID)
	if err != nil {
		return err
	}
	if task == nil || task.PublisherID != publisherID {
		return errors.New(i18n.TCtx(ctx, "not_publisher"))
	}
	if task.Status != model.StatusPublished {
		return errors.New(i18n.TCtx(ctx, "task_status_invalid"))
	}

	if err := s.taskRepo.CancelByPublisher(ctx, taskID, publisherID); err != nil {
		return err
	}

	// 金豆返还发布者（记入 beans_purchased）
	if err := s.userRepo.AddBeans(ctx, publisherID, task.BountyBeans, false); err != nil {
		return fmt.Errorf("%s: %w", i18n.TCtx(ctx, "bean_refund_failed"), err)
	}

	lang := i18n.LanguageFromCtx(ctx)
	s.transactionRepo.Create(ctx, &model.Transaction{
		TaskID:     &taskID,
		FromUserID: publisherID,
		Type:       model.TxTypeBeanRefund,
		Status:     model.TxStatusSuccess,
		BeansDelta: task.BountyBeans,
		Remark:     i18n.T(lang, "bean_refund", task.BountyBeans, task.Title),
	})

	notifyAndPush(ctx, s.notifyRepo, s.push, publisherID, "task_cancelled",
		i18n.T(lang, "notif_task_cancelled_title"),
		i18n.T(lang, "notif_task_cancelled_body", task.Title),
		taskID)

	return nil
}

func (s *PaymentService) DisputeTask(ctx context.Context, taskID, publisherID, reason string) error {
	task, err := s.taskRepo.FindByID(ctx, taskID)
	if err != nil {
		return err
	}
	if task == nil || task.PublisherID != publisherID {
		return errors.New(i18n.TCtx(ctx, "not_publisher"))
	}
	if task.Status != model.StatusSubmitted {
		return errors.New(i18n.TCtx(ctx, "task_status_invalid"))
	}

	if err := s.taskRepo.MarkDisputed(ctx, taskID); err != nil {
		return err
	}

	if _, err := s.notifyRepo.CreateDispute(ctx, taskID, reason); err != nil {
		return err
	}

	if task.ClaimerID != nil {
		lang := i18n.LanguageFromCtx(ctx)
		notifyAndPush(ctx, s.notifyRepo, s.push, *task.ClaimerID, "task_disputed",
			i18n.T(lang, "notif_task_disputed_title"),
			i18n.T(lang, "notif_task_disputed_body", task.Title),
			taskID)
		s.wsHub.SendToUser(*task.ClaimerID, websocket.Message{
			Type:    websocket.MsgTypeTaskDisputed,
			Payload: map[string]string{"task_id": taskID},
		})
	}

	return nil
}

func (s *PaymentService) RefundTask(ctx context.Context, taskID, publisherID string) error {
	task, err := s.taskRepo.FindByID(ctx, taskID)
	if err != nil {
		return err
	}
	if task == nil || task.PublisherID != publisherID {
		return errors.New(i18n.TCtx(ctx, "not_publisher"))
	}

	if err := s.taskRepo.Refund(ctx, taskID); err != nil {
		return err
	}

	// 金豆退款：预扣赏金返还发布者（记入 beans_purchased）
	if err := s.userRepo.AddBeans(ctx, publisherID, task.BountyBeans, false); err != nil {
		return fmt.Errorf("%s: %w", i18n.TCtx(ctx, "refund_failed"), err)
	}

	lang := i18n.LanguageFromCtx(ctx)
	tx := &model.Transaction{
		TaskID:     &taskID,
		FromUserID: publisherID,
		Type:       model.TxTypeBeanRefund,
		Status:     model.TxStatusSuccess,
		BeansDelta: task.BountyBeans,
		Remark:     i18n.T(lang, "txn_refunded"),
	}
	s.transactionRepo.Create(ctx, tx)

	notifyAndPush(ctx, s.notifyRepo, s.push, publisherID, "task_refunded",
		i18n.T(lang, "notif_task_refunded_title"),
		i18n.T(lang, "notif_task_refunded_body", task.BountyBeans, task.Title),
		taskID)

	return nil
}
