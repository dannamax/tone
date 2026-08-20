package model

import "time"

type TaskStatus string

const (
	StatusPublished TaskStatus = "published"
	StatusPending   TaskStatus = "pending"
	StatusClaimed   TaskStatus = "claimed"
	StatusSubmitted TaskStatus = "submitted"
	StatusCompleted TaskStatus = "completed"
	StatusDisputed  TaskStatus = "disputed"
	StatusRefunded  TaskStatus = "refunded"
	StatusReleased  TaskStatus = "released"
)

type Task struct {
	ID           string     `json:"id" db:"id"`
	PublisherID  string     `json:"publisher_id" db:"publisher_id"`
	Title        string     `json:"title" db:"title"`
	Description  string     `json:"description" db:"description"`
	TargetLat    float64    `json:"target_lat" db:"target_lat"`
	TargetLng    float64    `json:"target_lng" db:"target_lng"`
	TargetAddr   string     `json:"target_addr" db:"target_addr"`
	Radius       int        `json:"radius" db:"radius"`
	TimeLimit    int        `json:"time_limit" db:"time_limit"`
	Bounty       float64    `json:"bounty" db:"bounty"`
	Fee          float64    `json:"fee" db:"fee"`
	Currency     string     `json:"currency" db:"currency"`
	Status       TaskStatus `json:"status" db:"status"`
	ClaimerID    *string    `json:"claimer_id,omitempty" db:"claimer_id"`
	ClaimedAt    *time.Time `json:"claimed_at,omitempty" db:"claimed_at"`
	SubmittedAt  *time.Time `json:"submitted_at,omitempty" db:"submitted_at"`
	ConfirmedAt  *time.Time `json:"confirmed_at,omitempty" db:"confirmed_at"`
	RefundedAt   *time.Time `json:"refunded_at,omitempty" db:"refunded_at"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`

	Distance float64 `json:"distance,omitempty"`
}

type PublishTaskRequest struct {
	Title       string  `json:"title" binding:"required,min=1,max=50"`
	Description string  `json:"description" binding:"omitempty,max=200"`
	TargetLat   float64 `json:"target_lat"`
	TargetLng   float64 `json:"target_lng"`
	TargetAddr  string  `json:"target_addr"`
	Radius      int     `json:"radius" binding:"required,oneof=1000 3000 5000 10000"`
	TimeLimit   int     `json:"time_limit" binding:"required,oneof=5 15 30 60 120"`
	Bounty      float64 `json:"bounty" binding:"required,gte=1,lte=200"`
	Currency    string  `json:"currency" binding:"required,oneof=CNY USD"`
}

type SquareListRequest struct {
	Lat    float64 `form:"lat"`
	Lng    float64 `form:"lng"`
	Radius int     `form:"radius" binding:"omitempty,oneof=0 1000 3000 5000 10000"`
	Page   int     `form:"page" binding:"omitempty,min=1"`
	Size   int     `form:"size" binding:"omitempty,min=1,max=50"`
}

func (r SquareListRequest) DefaultRadius() int {
	// Radius==0 表示「全部」，不按距离过滤，仅按距离排序展示
	return r.Radius
}

func (r SquareListRequest) DefaultPage() int {
	if r.Page == 0 {
		return 1
	}
	return r.Page
}

func (r SquareListRequest) DefaultSize() int {
	if r.Size == 0 {
		return 20
	}
	return r.Size
}

func (r SquareListRequest) Offset() int {
	return (r.DefaultPage() - 1) * r.DefaultSize()
}

const (
	MaxConcurrentTasks     = 3
	PlatformFeeRate        = 0.10
	MinWithdrawAmount      = 10.0
	AutoConfirmHours       = 24
	TaskExpireHours        = 2
	MaxPhotosPerSubmission = 3
	MinBounty              = 1.0
	MaxBounty              = 200.0
)

const (
	CurrencyCNY       = "CNY"
	CurrencyUSD       = "USD"
	USDCNYExchangeRate = 7.2
)

func ToCNY(amount float64, currency string) float64 {
	if currency == CurrencyUSD {
		return amount * USDCNYExchangeRate
	}
	return amount
}

func CurrencySymbol(currency string) string {
	if currency == CurrencyUSD {
		return "$"
	}
	return "¥"
}
