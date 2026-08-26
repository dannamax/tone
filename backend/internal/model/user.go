package model

import "time"

type User struct {
	ID             string    `json:"id" db:"id"`
	Email          string    `json:"email,omitempty" db:"email"`
	Nickname       string    `json:"nickname" db:"nickname"`
	Avatar         string    `json:"avatar" db:"avatar"`
	DeviceID       string    `json:"device_id" db:"device_id"`
	Balance        float64   `json:"balance" db:"balance"`
	FrozenBal      float64   `json:"frozen_balance" db:"frozen_balance"`
	TotalEarned    float64   `json:"total_earned" db:"total_earned"`
	TotalSpent     float64   `json:"total_spent" db:"total_spent"`
	BeansPurchased int       `json:"beans_purchased" db:"beans_purchased"` // 充值/注册礼金豆（不可提现）
	BeansEarned    int       `json:"beans_earned" db:"beans_earned"`       // 任务赚取金豆（V2 将开放提现）
	Role           string    `json:"role" db:"role"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time `json:"updated_at" db:"updated_at"`
}

// BeansTotal 用户可用金豆总数
func (u *User) BeansTotal() int {
	return u.BeansPurchased + u.BeansEarned
}

// FreeBeans 新用户注册赠送的金豆数（与最低赏金等值，先尝后买：体验 1 次发布后触发充值）
const FreeBeans = 5

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
