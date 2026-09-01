package model

import "time"

type TaskStatus string

const (
	StatusPublished TaskStatus = "published"
	StatusClaimed   TaskStatus = "claimed"
	StatusSubmitted TaskStatus = "submitted"
	StatusCompleted TaskStatus = "completed"
	StatusDisputed  TaskStatus = "disputed"
	StatusRefunded  TaskStatus = "refunded"
	StatusReleased  TaskStatus = "released"
	StatusCancelled TaskStatus = "cancelled"
)

// 任务广场排序维度
const (
	SortDistance = ""       // 默认按距离
	SortBeans    = "beans"  // 按赏金金豆数降序
	SortNewest   = "newest" // 按发布时间降序
)

type Task struct {
	ID          string     `json:"id" db:"id"`
	PublisherID string     `json:"publisher_id" db:"publisher_id"`
	Title       string     `json:"title" db:"title"`
	Description string     `json:"description" db:"description"`
	TargetLat   float64    `json:"target_lat" db:"target_lat"`
	TargetLng   float64    `json:"target_lng" db:"target_lng"`
	TargetAddr  string     `json:"target_addr" db:"target_addr"`
	Radius      int        `json:"radius" db:"radius"`
	TimeLimit   int        `json:"time_limit" db:"time_limit"`
	BountyBeans int        `json:"bounty_beans" db:"bounty_beans"` // 赏金金豆数（发布时预扣，确认后归猎人）
	Status      TaskStatus `json:"status" db:"status"`
	ClaimerID   *string    `json:"claimer_id,omitempty" db:"claimer_id"`
	ClaimedAt   *time.Time `json:"claimed_at,omitempty" db:"claimed_at"`
	SubmittedAt *time.Time `json:"submitted_at,omitempty" db:"submitted_at"`
	ConfirmedAt *time.Time `json:"confirmed_at,omitempty" db:"confirmed_at"`
	RefundedAt  *time.Time `json:"refunded_at,omitempty" db:"refunded_at"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`

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
	BountyBeans int     `json:"bounty_beans" binding:"required,gte=5,lte=50"`
}

// ClaimRequest 领取任务请求：必须携带领取者当前位置（定向领取围栏校验）
type ClaimRequest struct {
	Lat float64 `json:"lat" binding:"required"`
	Lng float64 `json:"lng" binding:"required"`
}

type SquareListRequest struct {
	Lat    float64 `form:"lat"`
	Lng    float64 `form:"lng"`
	Radius int     `form:"radius" binding:"omitempty,oneof=0 1000 3000 5000 10000"`
	Page   int     `form:"page" binding:"omitempty,min=1"`
	Size   int     `form:"size" binding:"omitempty,min=1,max=50"`
	Sort   string  `form:"sort"` // distance（默认）/ beans / newest
}

// NormalizedSort 返回白名单化的排序键
func (r SquareListRequest) NormalizedSort() string {
	switch r.Sort {
	case "beans":
		return "beans"
	case "newest":
		return "newest"
	default:
		return "distance"
	}
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
	MinWithdrawAmount      = 10.0
	AutoConfirmHours       = 24
	TaskExpireHours        = 2
	MaxPhotosPerSubmission = 3
	MinBountyBeans         = 5 // 高频充值模型：最低赏金与最小充值包等值，$0.99=5豆=1次任务
	MaxBountyBeans         = 50
)
