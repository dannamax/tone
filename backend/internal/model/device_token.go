package model

import "time"

// DeviceToken 用户设备的 APNs 推送 token（一台设备一行，token 唯一）
type DeviceToken struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Token     string    `json:"token"`
	Platform  string    `json:"platform"` // ios
	UpdatedAt time.Time `json:"updated_at"`
}
