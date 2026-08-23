package model

import "time"

// RechargeOrder 充值购买发布额度订单（支付基座，必须幂等）
type RechargeOrder struct {
	ID             string     `json:"id" db:"id"`                          // 商户订单号 out_trade_no (uuid)
	UserID         string     `json:"user_id" db:"user_id"`
	PackageID      string     `json:"package_id" db:"package_id"`
	Channel        string     `json:"channel" db:"channel"`                // apple / stripe / wechat / alipay
	Amount         float64    `json:"amount" db:"amount"`                  // 实际支付金额
	Currency       string     `json:"currency" db:"currency"`
	QuotaGranted   int        `json:"quota_granted" db:"quota_granted"`    // 本次应发放额度
	Status         string     `json:"status" db:"status"`                  // created / paid / failed / refunded
	GatewayOrderID string     `json:"gateway_order_id,omitempty" db:"gateway_order_id"` // 支付机构订单号(幂等用)
	ReceiptData    string     `json:"-" db:"receipt_data"`                 // 支付凭证(raw)，如 Apple receipt
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	PaidAt         *time.Time `json:"paid_at,omitempty" db:"paid_at"`
}

// 充值订单状态
const (
	OrderStatusCreated   = "created"
	OrderStatusPaid      = "paid"
	OrderStatusFailed    = "failed"
	OrderStatusRefunded  = "refunded"
)

// RechargeChannel 支持的充值渠道
const (
	ChannelApple   = "apple"
	ChannelStripe  = "stripe"
	ChannelWechat  = "wechat"
	ChannelAlipay  = "alipay"
)

// CreateRechargeRequest 创建充值订单请求
type CreateRechargeRequest struct {
	PackageID string `json:"package_id" binding:"required"`
	Channel   string `json:"channel" binding:"required,oneof=apple stripe wechat alipay"`
}

// 支付回调/校验通用请求（Apple IAP 用）
type AppleVerifyRequest struct {
	OrderID     string `json:"order_id" binding:"required"`
	ReceiptData string `json:"receipt_data" binding:"required"`
}
