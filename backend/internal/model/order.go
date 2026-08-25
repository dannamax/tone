package model

import "time"

// RechargeOrder 金豆充值订单（支付基座，必须幂等）
type RechargeOrder struct {
	ID            string     `json:"id" db:"id"`                            // 商户订单号 out_trade_no (uuid)
	UserID        string     `json:"user_id" db:"user_id"`
	PackageID     string     `json:"package_id" db:"package_id"`
	Channel       string     `json:"channel" db:"channel"`                   // apple / stripe / wechat / alipay
	Amount        float64    `json:"amount" db:"amount"`                    // 实际支付金额
	Currency      string     `json:"currency" db:"currency"`
	BeansGranted  int        `json:"beans_granted" db:"beans_granted"`       // 本次应发放金豆数
	Status        string     `json:"status" db:"status"`                     // created / paid / failed / refunded
	GatewayOrderID string    `json:"gateway_order_id" db:"gateway_order_id"` // 支付机构订单号（transaction_id）
	ReceiptData   string     `json:"receipt_data,omitempty" db:"receipt_data"`
	PaidAt        *time.Time `json:"paid_at,omitempty" db:"paid_at"`
	CreatedAt     time.Time  `json:"created_at" db:"created_at"`
}

// 订单状态
const (
	OrderStatusCreated = "created"
	OrderStatusPaid    = "paid"
	OrderStatusFailed  = "failed"
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
//
// StoreKit 2 路径：客户端发送 transaction 的 JWS 原文（transaction.jwsRepresentation），
// 由后端本地验签（pkg/appleiap 用 Apple 根证书校验签名链 + productId 匹配）。
// 为兼容旧链路，receipt_data 仍保留（legacy verifyReceipt 回退）。
type AppleVerifyRequest struct {
	OrderID     string `json:"order_id" binding:"required"`
	ReceiptData string `json:"receipt_data"`
	JWS         string `json:"jws"` // StoreKit 2: signed transaction JWS (transaction.jwsRepresentation)
}
