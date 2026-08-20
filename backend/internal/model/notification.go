package model

import "time"

type Dispute struct {
	ID         string     `json:"id" db:"id"`
	TaskID     string     `json:"task_id" db:"task_id"`
	Reason     string     `json:"reason" db:"reason"`
	Result     *string    `json:"result,omitempty" db:"result"`
	ResolvedAt *time.Time `json:"resolved_at,omitempty" db:"resolved_at"`
	CreatedAt  time.Time  `json:"created_at" db:"created_at"`
}

type Notification struct {
	ID      string    `json:"id" db:"id"`
	UserID  string    `json:"user_id" db:"user_id"`
	Type    string    `json:"type" db:"type"`
	Title   string    `json:"title" db:"title"`
	Content string    `json:"content" db:"content"`
	TaskID  *string   `json:"task_id,omitempty" db:"task_id"`
	IsRead  bool      `json:"is_read" db:"is_read"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

// NotificationType 常量
const (
	NotifyTaskClaimed    = "task_claimed"
	NotifyTaskSubmitted  = "task_submitted"
	NotifyTaskConfirmed  = "task_confirmed"
	NotifyTaskReleased   = "task_released"
	NotifyTaskDisputed   = "task_disputed"
	NotifyTaskRefunded   = "task_refunded"
	NotifySystem         = "system"
)
