package model

import "time"

// Content types accepted by the report endpoint.
const (
	ReportTargetTask    = "task"
	ReportTargetUser    = "user"
	ReportTargetMessage = "message"
)

// ContentReport 用户举报记录（任务 / 用户 / 消息），V1 落库供运营核查。
type ContentReport struct {
	ID         string    `json:"id"`
	ReporterID string    `json:"reporter_id"`
	TargetType string    `json:"target_type"`
	TargetID   string    `json:"target_id"`
	Reason     string    `json:"reason"`
	CreatedAt  time.Time `json:"created_at"`
}

// ReportRequest 举报请求体。
type ReportRequest struct {
	TargetType string `json:"target_type" binding:"required,oneof=task user message"`
	TargetID   string `json:"target_id" binding:"required"`
	Reason     string `json:"reason" binding:"required,min=1,max=500"`
}

// BlockedUser 拉黑列表条目。
type BlockedUser struct {
	UserID    string    `json:"user_id"`
	Nickname  string    `json:"nickname"`
	CreatedAt time.Time `json:"created_at"`
}
