package service

import (
	"context"
	"errors"
	"fmt"
	"log"

	"seeker/internal/repository"
	"seeker/pkg/i18n"
)

// ErrActiveTasks 账户删除前置校验失败：名下存在进行中任务（claimed/submitted/disputed）。
// Handler 通过 errors.Is 判断后返回 409，替代脆弱的文案字符串匹配。
var ErrActiveTasks = errors.New("active tasks block account deletion")

// AccountService 账户生命周期管理（GDPR / App Store 5.1.1(v) 账户删除合规）
type AccountService struct {
	userRepo       *repository.UserRepo
	taskRepo       *repository.TaskRepo
	messageRepo    *repository.MessageRepo
	submissionRepo *repository.SubmissionRepo
	notifyRepo     *repository.NotificationRepo
	txRepo         *repository.TransactionRepo
	rechargeRepo   *repository.RechargeRepo
	deviceRepo     *repository.DeviceTokenRepo
}

func NewAccountService(
	userRepo *repository.UserRepo,
	taskRepo *repository.TaskRepo,
	messageRepo *repository.MessageRepo,
	submissionRepo *repository.SubmissionRepo,
	notifyRepo *repository.NotificationRepo,
	txRepo *repository.TransactionRepo,
	rechargeRepo *repository.RechargeRepo,
	deviceRepo *repository.DeviceTokenRepo,
) *AccountService {
	return &AccountService{
		userRepo:       userRepo,
		taskRepo:       taskRepo,
		messageRepo:    messageRepo,
		submissionRepo: submissionRepo,
		notifyRepo:     notifyRepo,
		txRepo:         txRepo,
		rechargeRepo:   rechargeRepo,
		deviceRepo:     deviceRepo,
	}
}

// DeleteAccount 彻底删除账户及其全部个人数据。
// 前置校验：用户名下（作为发布人或接单人）不得存在进行中任务
// （claimed/submitted/disputed），否则返回错误提示先完成或放弃。
// 清理范围：
//   - 自己发布的全部任务（含已发布未认领的）及其级联数据
//     （履约消息、提交记录、通知、争议；金豆流水解除任务关联）
//   - 个人通知、金豆流水、充值订单、验证码记录
//   - 用户记录本身
//
// 注意：他人发布、由本用户接单的历史任务记录保留（任务归属他人，
// claimer_id 悬空仅在详情展示昵称时降级，不影响功能）。
func (s *AccountService) DeleteAccount(ctx context.Context, userID string) error {
	lang := i18n.LanguageFromCtx(ctx)

	// 1) 进行中任务检查：任何一方有未完结任务都禁止删除
	active, err := s.taskRepo.CountActiveByUser(ctx, userID)
	if err != nil {
		log.Printf("[DeleteAccount] user=%s check active tasks error: %v", userID, err)
		return fmt.Errorf("check active tasks: %w", err)
	}
	if active > 0 {
		log.Printf("[DeleteAccount] user=%s blocked by %d active tasks", userID, active)
		return fmt.Errorf("%w: %s", ErrActiveTasks, i18n.T(lang, "account_delete_active_tasks"))
	}

	// 2) 删除自己发布的全部任务（含级联数据）
	taskIDs, err := s.taskRepo.FindIDsByPublisher(ctx, userID)
	if err != nil {
		return fmt.Errorf("list own tasks: %w", err)
	}
	for _, taskID := range taskIDs {
		_ = s.txRepo.UnlinkTask(ctx, taskID)
		_ = s.messageRepo.DeleteByTaskID(ctx, taskID)
		_ = s.submissionRepo.DeleteByTaskID(ctx, taskID)
		_ = s.notifyRepo.DeleteByTaskID(ctx, taskID)
		_ = s.notifyRepo.DeleteDisputeByTaskID(ctx, taskID)
	}
	if err := s.taskRepo.DeleteAllByPublisher(ctx, userID); err != nil {
		log.Printf("[DeleteAccount] user=%s delete own tasks error: %v", userID, err)
		return fmt.Errorf("delete own tasks: %w", err)
	}

	// 3) 删除个人数据与用户记录
	_ = s.deviceRepo.DeleteByUser(ctx, userID) // 推送设备登记
	if err := s.userRepo.DeleteCascade(ctx, userID); err != nil {
		log.Printf("[DeleteAccount] user=%s delete cascade error: %v", userID, err)
		return fmt.Errorf("delete account: %w", err)
	}
	return nil
}
