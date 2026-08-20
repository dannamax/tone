package model

import "time"

// TaskMessage 任务履约对话消息
type TaskMessage struct {
	ID        string    `json:"id"`
	TaskID    string    `json:"task_id"`
	SenderID  string    `json:"sender_id"`
	Content   string    `json:"content"`
	ImageURLs []string  `json:"image_urls"`
	CreatedAt time.Time `json:"created_at"`
}

// SendMessageRequest 发送消息请求
type SendMessageRequest struct {
	Content   string   `json:"content"`
	ImageURLs []string `json:"image_urls,omitempty"`
}

// UploadImageRequest 上传图片请求
type UploadImageRequest struct {
	Base64 string `json:"base64" binding:"required"`
	Name   string `json:"name"`
}

// UploadImageResponse 上传图片响应
type UploadImageResponse struct {
	URL string `json:"url"`
}
