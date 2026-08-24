package model

import "time"

type User struct {
	ID           string    `json:"id" db:"id"`
	Email        string    `json:"email,omitempty" db:"email"`
	Nickname     string    `json:"nickname" db:"nickname"`
	Avatar       string    `json:"avatar" db:"avatar"`
	DeviceID     string    `json:"device_id" db:"device_id"`
	Balance      float64   `json:"balance" db:"balance"`
	FrozenBal    float64   `json:"frozen_balance" db:"frozen_balance"`
	TotalEarned  float64   `json:"total_earned" db:"total_earned"`
	TotalSpent   float64   `json:"total_spent" db:"total_spent"`
	PublishQuota int       `json:"publish_quota" db:"publish_quota"`
	UsedQuota    int       `json:"used_quota" db:"used_quota"`
	Role         string    `json:"role" db:"role"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
}

// FreeQuota 新用户赠送的免费发布额度
const FreeQuota = 3

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Code     string `json:"code" binding:"required,len=6"`
	DeviceID string `json:"device_id" binding:"required"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Code     string `json:"code" binding:"required,len=6"`
	DeviceID string `json:"device_id" binding:"required"`
}

type SendCodeRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type TokenResponse struct {
	AccessToken string `json:"access_token"`
	ExpiresIn   int64  `json:"expires_in"`
	User        User   `json:"user"`
}
