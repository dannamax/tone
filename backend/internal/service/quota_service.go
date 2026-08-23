package service

import (
	"context"
	"fmt"

	"seeker/internal/model"
	"seeker/internal/repository"
	"seeker/pkg/appleiap"
	"seeker/pkg/i18n"
)

// QuotaService 发布额度充值与发放（方案1）
type QuotaService struct {
	rechargeRepo *repository.RechargeRepo
	userRepo     *repository.UserRepo
	txRepo       *repository.TransactionRepo
	verifier     *appleiap.Verifier
}

func NewQuotaService(repo *repository.RechargeRepo, userRepo *repository.UserRepo, txRepo *repository.TransactionRepo, verifier *appleiap.Verifier) *QuotaService {
	return &QuotaService{rechargeRepo: repo, userRepo: userRepo, txRepo: txRepo, verifier: verifier}
}

// Packages 返回可用套餐列表
func (s *QuotaService) Packages(ctx context.Context) []model.QuotaPackage {
	return model.QuotaPackagesList()
}

// CreateOrder 创建充值订单（不实际扣钱，等待支付回调）
func (s *QuotaService) CreateOrder(ctx context.Context, userID, packageID, channel string) (*model.RechargeOrder, error) {
	pkg, ok := model.GetQuotaPackage(packageID)
	if !ok {
		return nil, fmt.Errorf("%s: %s", i18n.TCtx(ctx, "package_not_found"), packageID)
	}
	order := &model.RechargeOrder{
		UserID:       userID,
		PackageID:    pkg.ID,
		Channel:      channel,
		Amount:       pkg.Price,
		Currency:     pkg.Currency,
		QuotaGranted: pkg.Quota,
	}
	return s.rechargeRepo.Create(ctx, order)
}

// redeem 支付成功后幂等发放额度 + 写流水
func (s *QuotaService) redeem(ctx context.Context, order *model.RechargeOrder) error {
	_, err := s.rechargeRepo.MarkPaid(ctx, order.ID, order.GatewayOrderID, order.QuotaGranted,
		func(c context.Context, uid string, n int) error {
			return s.userRepo.AddQuota(c, uid, n)
		})
	if err != nil {
		return err
	}
	// 写额度购买流水
	_, err = s.txRepo.Create(ctx, &model.Transaction{
		FromUserID: order.UserID,
		Amount:     order.Amount,
		Type:       model.TxTypeQuotaBuy,
		Status:     model.TxStatusSuccess,
		Remark:     "quota package:" + order.PackageID,
		OrderID:    &order.ID,
		QuotaDelta: order.QuotaGranted,
	})
	return err
}

// ConfirmAppleIAP 校验 Apple 回执并发放额度（步骤3核心）
// 流程：
//  1. 查订单，确认存在且属于当前用户（用户归属由 handler 校验）。
//  2. 调用 Apple verifyReceipt 校验 receiptData，得到与套餐匹配的 transaction_id。
//  3. 用 transaction_id 作为 GatewayOrderID 幂等发放额度（MarkPaid 已按该键去重）。
func (s *QuotaService) ConfirmAppleIAP(ctx context.Context, orderID, receiptData, _ string) (*model.RechargeOrder, error) {
	order, err := s.rechargeRepo.FindByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if order == nil {
		return nil, fmt.Errorf("%s", i18n.TCtx(ctx, "order_not_found"))
	}
	if order.Status == model.OrderStatusPaid {
		// 已支付：幂等返回，避免重复发放
		return order, nil
	}

	pkg, ok := model.GetQuotaPackage(order.PackageID)
	if !ok {
		return nil, fmt.Errorf("%s: %s", i18n.TCtx(ctx, "package_not_found"), order.PackageID)
	}

	if s.verifier == nil {
		return nil, fmt.Errorf("%s", i18n.TCtx(ctx, "service_unavailable"))
	}

	// 调苹果校验，要求回执中存在与套餐对应的 product_id 且未取消的交易。
	res, err := s.verifier.Verify(ctx, receiptData, pkg.AppleProductID)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", i18n.TCtx(ctx, "invalid_receipt"), err)
	}

	order.GatewayOrderID = res.TransactionID
	if err := s.redeem(ctx, order); err != nil {
		return nil, err
	}
	return s.rechargeRepo.FindByID(ctx, orderID)
}

// GetOrder 查询订单状态
func (s *QuotaService) GetOrder(ctx context.Context, orderID string) (*model.RechargeOrder, error) {
	return s.rechargeRepo.FindByID(ctx, orderID)
}
