package model

import "time"

type TransactionType string

const (
	TxTypeFreeze   TransactionType = "freeze"
	TxTypeRelease  TransactionType = "release"
	TxTypeRefund   TransactionType = "refund"
	TxTypeWithdraw TransactionType = "withdraw"
	TxTypeRecharge TransactionType = "recharge"
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
	CreatedAt  time.Time         `json:"created_at" db:"created_at"`
}

type WithdrawRequest struct {
	Amount  float64 `json:"amount" binding:"required,gte=10"`
	Channel string  `json:"channel" binding:"required,oneof=wechat alipay"`
	Account string  `json:"account" binding:"required"`
}

type WalletInfo struct {
	Balance      float64 `json:"balance"`
	FrozenBal    float64 `json:"frozen_balance"`
	TotalEarned  float64 `json:"total_earned"`
	TotalSpent   float64 `json:"total_spent"`
	CanWithdraw  bool    `json:"can_withdraw"`
}
