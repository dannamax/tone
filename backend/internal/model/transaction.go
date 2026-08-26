package model

import "time"

type TransactionType string

const (
	TxTypeFreeze   TransactionType = "freeze"
	TxTypeRelease  TransactionType = "release"
	TxTypeRefund   TransactionType = "refund"
	TxTypeWithdraw TransactionType = "withdraw"
	TxTypeRecharge TransactionType = "recharge"

	// 金豆体系（V1 全封闭：不可提现；V2 将开放 earned 豆提现）
	TxTypeBeanBuy    TransactionType = "bean_buy"    // IAP 充值购买金豆
	TxTypeBeanSpend  TransactionType = "bean_spend"  // 发布任务消耗金豆
	TxTypeBeanReward TransactionType = "bean_reward" // 任务完成奖励金豆（进 earned）
	TxTypeBeanRefund TransactionType = "bean_refund" // 任务退款/撤回返还金豆
	TxTypeBeanGrant  TransactionType = "bean_grant"  // 系统赠送/补偿金豆
)

type TransactionStatus string

const (
	TxStatusPending TransactionStatus = "pending"
	TxStatusSuccess TransactionStatus = "success"
	TxStatusFailed  TransactionStatus = "failed"
)

type Transaction struct {
	ID         string            `json:"id" db:"id"`
	TaskID     *string           `json:"task_id,omitempty" db:"task_id"`
	FromUserID string            `json:"from_user_id" db:"from_user_id"`
	ToUserID   *string           `json:"to_user_id,omitempty" db:"to_user_id"`
	Amount     float64           `json:"amount" db:"amount"`
	Fee        float64           `json:"fee" db:"fee"`
	Type       TransactionType   `json:"type" db:"tx_type"`
	Status     TransactionStatus `json:"status" db:"tx_status"`
	Remark     string            `json:"remark,omitempty" db:"remark"`
	OrderID    *string           `json:"order_id,omitempty" db:"order_id"`
	BeansDelta int               `json:"beans_delta" db:"beans_delta"` // 金豆变动（正=入账，负=扣减）
	CreatedAt  time.Time         `json:"created_at" db:"created_at"`
}

type WithdrawRequest struct {
	Amount  float64 `json:"amount" binding:"required,gte=10"`
	Channel string  `json:"channel" binding:"required,oneof=wechat alipay"`
	Account string  `json:"account" binding:"required"`
}

type WalletInfo struct {
	Balance         float64 `json:"balance"`
	FrozenBal       float64 `json:"frozen_balance"`
	TotalEarned     float64 `json:"total_earned"`
	TotalSpent      float64 `json:"total_spent"`
	BeansPurchased  int     `json:"beans_purchased"`        // 充值金豆（不可提现）
	BeansEarned     int     `json:"beans_earned"`            // 任务赚取金豆（V2 将开放提现）
	BeansTotal      int     `json:"beans_total"`             // 可用金豆总数
	CompletedTasks  int     `json:"completed_tasks"`         // 猎人已确认完成的任务数（兑换资格第二维）
	CanWithdraw     bool    `json:"can_withdraw"`
}
