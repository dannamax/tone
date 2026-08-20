package service

import (
	"context"
	"errors"
	"fmt"

	"seeker/internal/model"
	"seeker/internal/repository"
	"seeker/pkg/i18n"
)

type WalletService struct {
	userRepo   *repository.UserRepo
	txRepo     *repository.TransactionRepo
	notifyRepo *repository.NotificationRepo
}

func NewWalletService(userRepo *repository.UserRepo, txRepo *repository.TransactionRepo, notifyRepo *repository.NotificationRepo) *WalletService {
	return &WalletService{
		userRepo:   userRepo,
		txRepo:     txRepo,
		notifyRepo: notifyRepo,
	}
}

func (s *WalletService) GetWalletInfo(ctx context.Context, userID string) (*model.WalletInfo, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	return &model.WalletInfo{
		Balance:     user.Balance,
		FrozenBal:   user.FrozenBal,
		CanWithdraw: user.Balance >= model.MinWithdrawAmount,
	}, nil
}

func (s *WalletService) Withdraw(ctx context.Context, userID string, req *model.WithdrawRequest) error {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return err
	}
	if user.Balance < req.Amount {
		return errors.New(i18n.TCtx(ctx, "wallet_withdraw_insufficient", user.Balance))
	}
	if req.Amount < model.MinWithdrawAmount {
		return errors.New(i18n.TCtx(ctx, "withdraw_below_min", model.MinWithdrawAmount))
	}

	if err := s.userRepo.UpdateBalance(ctx, userID, -req.Amount, 0); err != nil {
		return fmt.Errorf("%s: %w", i18n.TCtx(ctx, "deduct_failed"), err)
	}

	lang := i18n.LanguageFromCtx(ctx)
	tx := &model.Transaction{
		FromUserID: userID,
		Amount:     req.Amount,
		Type:       model.TxTypeWithdraw,
		Status:     model.TxStatusPending,
		Remark:     i18n.T(lang, "withdraw_to_channel", req.Channel, req.Account),
	}
	if _, err := s.txRepo.Create(ctx, tx); err != nil {
		return fmt.Errorf("%s: %w", i18n.TCtx(ctx, "recharge_txn_failed"), err)
	}

	return nil
}

// Recharge adds balance and writes a transaction record (dev/mock only).
func (s *WalletService) Recharge(ctx context.Context, userID string, amount float64) error {
	if amount <= 0 {
		return errors.New(i18n.TCtx(ctx, "recharge_min_amount"))
	}

	if err := s.userRepo.UpdateBalance(ctx, userID, amount, 0); err != nil {
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
	if _, err := s.txRepo.Create(ctx, tx); err != nil {
		return fmt.Errorf("%s: %w", i18n.TCtx(ctx, "recharge_txn_failed"), err)
	}

	return nil
}

func (s *WalletService) GetNotifications(ctx context.Context, userID string, page, size int) ([]model.Notification, int64, error) {
	return s.notifyRepo.ListByUser(ctx, userID, page, size)
}

func (s *WalletService) MarkAllRead(ctx context.Context, userID string) error {
	return s.notifyRepo.MarkAllRead(ctx, userID)
}
