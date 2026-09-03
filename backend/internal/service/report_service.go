package service

import (
	"context"
	"errors"

	"seeker/internal/model"
	"seeker/internal/repository"
	"seeker/pkg/i18n"
)

type ReportService struct {
	reportRepo *repository.ReportRepo
	userRepo   *repository.UserRepo
	taskRepo   *repository.TaskRepo
}

func NewReportService(reportRepo *repository.ReportRepo, userRepo *repository.UserRepo, taskRepo *repository.TaskRepo) *ReportService {
	return &ReportService{reportRepo: reportRepo, userRepo: userRepo, taskRepo: taskRepo}
}

// Block 拉黑用户。被拉黑后双方互相不可见任务、不可领取、不可在任务内发消息。
func (s *ReportService) Block(ctx context.Context, userID, targetID string) error {
	if userID == targetID {
		return errors.New(i18n.TCtx(ctx, "cannot_block_self"))
	}
	u, err := s.userRepo.FindByID(ctx, targetID)
	if err != nil {
		return err
	}
	if u == nil {
		return errors.New(i18n.TCtx(ctx, "user_not_found"))
	}
	return s.reportRepo.Block(ctx, userID, targetID)
}

// Unblock 解除拉黑。
func (s *ReportService) Unblock(ctx context.Context, userID, targetID string) error {
	return s.reportRepo.Unblock(ctx, userID, targetID)
}

// ListBlocked 拉黑列表。
func (s *ReportService) ListBlocked(ctx context.Context, userID string) ([]model.BlockedUser, error) {
	return s.reportRepo.ListBlocked(ctx, userID)
}

// Report 提交举报（target 存在性校验后落库，供运营核查）。
func (s *ReportService) Report(ctx context.Context, userID string, req *model.ReportRequest) error {
	switch req.TargetType {
	case model.ReportTargetTask:
		t, err := s.taskRepo.FindByID(ctx, req.TargetID)
		if err != nil {
			return err
		}
		if t == nil {
			return errors.New(i18n.TCtx(ctx, "task_not_found"))
		}
	case model.ReportTargetUser:
		u, err := s.userRepo.FindByID(ctx, req.TargetID)
		if err != nil {
			return err
		}
		if u == nil {
			return errors.New(i18n.TCtx(ctx, "user_not_found"))
		}
	}

	rep := &model.ContentReport{
		ReporterID: userID,
		TargetType: req.TargetType,
		TargetID:   req.TargetID,
		Reason:     req.Reason,
	}
	return s.reportRepo.CreateReport(ctx, rep)
}
