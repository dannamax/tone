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

// CreateOrder 创建金豆充值订单（不实际扣钱，等待支付回调）
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
		BeansGranted: pkg.Beans,
	}
	return s.rechargeRepo.Create(ctx, order)
}

// redeem 支付成功后幂等发放金豆（进 beans_purchased） + 写流水
func (s *QuotaService) redeem(ctx context.Context, order *model.RechargeOrder) error {
	_, err := s.rechargeRepo.MarkPaid(ctx, order.ID, order.GatewayOrderID, order.BeansGranted,
		func(c context.Context, uid string, n int) error {
			return s.userRepo.AddBeans(c, uid, n, false)
		})
	if err != nil {
		return err
	}
	// 写金豆购买流水
	_, err = s.txRepo.Create(ctx, &model.Transaction{
		FromUserID: order.UserID,
		Amount:     order.Amount,
		Type:       model.TxTypeBeanBuy,
		Status:     model.TxStatusSuccess,
		Remark:     "beans package:" + order.PackageID,
		OrderID:    &order.ID,
		BeansDelta: order.BeansGranted,
	})
	return err
}

// ConfirmAppleIAP 校验 Apple 回执并发放额度（步骤3核心）
// 流程：
//  1. 查订单，确认存在且属于当前用户（用户归属由 handler 校验）。
//  2. 优先用 StoreKit 2 的 JWS（transaction.jwsRepresentation）本地验签：
//     验签证书链（Apple 根证书信任锚）+ 验签名 + 校验 productId 匹配。
//  3. 若无 JWS，回退到 legacy verifyReceipt（receipt_data）。
//  4. 用 transaction_id 作为 GatewayOrderID 幂等发放额度（MarkPaid 已按该键去重）。
func (s *QuotaService) ConfirmAppleIAP(ctx context.Context, orderID, receiptData, jws string) (*model.RechargeOrder, error) {
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

	gatewayTxID := ""

	// 主路径：StoreKit 2 JWS 本地验签。
	if jws != "" {
		claims, verr := appleiap.VerifyJWS(jws, pkg.AppleProductID)
		if verr != nil {
			return nil, fmt.Errorf("%s: %v", i18n.TCtx(ctx, "invalid_receipt"), verr)
		}
		gatewayTxID = claims.TransactionID
	} else if receiptData != "" && s.verifier != nil {
		// 回退路径：legacy verifyReceipt。
		res, verr := s.verifier.Verify(ctx, receiptData, pkg.AppleProductID)
		if verr != nil {
			return nil, fmt.Errorf("%s: %v", i18n.TCtx(ctx, "invalid_receipt"), verr)
		}
		gatewayTxID = res.TransactionID
	} else {
		return nil, fmt.Errorf("%s", i18n.TCtx(ctx, "service_unavailable"))
	}

	order.GatewayOrderID = gatewayTxID
	if err := s.redeem(ctx, order); err != nil {
		return nil, err
	}
	return s.rechargeRepo.FindByID(ctx, orderID)
}

// GetOrder 查询订单状态
func (s *QuotaService) GetOrder(ctx context.Context, orderID string) (*model.RechargeOrder, error) {
	return s.rechargeRepo.FindByID(ctx, orderID)
}

// RestoreResult 恢复购买结果统计
type RestoreResult struct {
	Restored int `json:"restored"` // 本次补发入账的笔数（已付款但未确认的订单）
	Already  int `json:"already"`  // 早已入账、跳过的笔数
	Unknown  int `json:"unknown"`  // 无法关联到任何订单的交易数
}

// RestoreAppleIAP 恢复购买：客户端上传 App Store 历史交易的 JWS 列表，
// 后端逐笔验签并按 Apple transaction_id 关联本地订单：
//   - 订单已 paid            → 跳过（早已入账，MarkPaid 幂等）
//   - 订单 created（已付款但 confirm 中断）→ 补发金豆
//   - 无订单 → 尝试用 product_id 绑定该用户最早的未支付同套餐订单 → 补发
//   - 均无法关联（如他人交易/非本 App 商品）→ 计入 unknown
//
// 注意：金豆为消耗型（consumable），Apple 官方不保证可恢复；
// 本接口的价值是补齐「付款成功但入账失败/中断」的边缘场景。
func (s *QuotaService) RestoreAppleIAP(ctx context.Context, userID string, jwsList []string) (*RestoreResult, error) {
	result := &RestoreResult{}

	for _, jws := range jwsList {
		// 宽松验签（不绑定单一 productId），随后按 product 反查套餐
		claims, err := appleiap.VerifyJWS(jws, "")
		if err != nil {
			result.Unknown++
			continue
		}

		// 只认本 App 的套餐商品
		pkg, ok := model.GetQuotaPackageByAppleProductID(claims.ProductID)
		if !ok {
			result.Unknown++
			continue
		}

		// 按 Apple transaction_id 精确匹配本地订单
		order, err := s.rechargeRepo.FindByGateway(ctx, model.ChannelApple, claims.TransactionID)
		if err != nil {
			return nil, err
		}
		if order != nil {
			if order.UserID != userID {
				result.Unknown++ // 他人的交易，忽略
				continue
			}
			if order.Status == model.OrderStatusPaid {
				result.Already++ // 早已入账
				continue
			}
			if _, err := s.redeemOrderWithTxID(ctx, order, claims.TransactionID); err != nil {
				return nil, err
			}
			result.Restored++
			continue
		}

		// 无精确匹配：尝试绑定该用户最早的未支付同套餐订单（付款后 confirm 中断的场景）
		pending, err := s.rechargeRepo.FindOldestCreated(ctx, userID, pkg.ID)
		if err != nil {
			return nil, err
		}
		if pending == nil {
			result.Unknown++
			continue
		}
		if _, err := s.redeemOrderWithTxID(ctx, pending, claims.TransactionID); err != nil {
			return nil, err
		}
		result.Restored++
	}

	return result, nil
}

// redeemOrderWithTxID 以指定 Apple transaction_id 幂等入账
func (s *QuotaService) redeemOrderWithTxID(ctx context.Context, order *model.RechargeOrder, txID string) (*model.RechargeOrder, error) {
	if order.Status == model.OrderStatusPaid {
		return order, nil
	}
	order.GatewayOrderID = txID
	if err := s.redeem(ctx, order); err != nil {
		return nil, err
	}
	return s.rechargeRepo.FindByID(ctx, order.ID)
}
