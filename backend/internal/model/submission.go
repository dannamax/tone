package model

import "time"

type Submission struct {
	ID         string    `json:"id" db:"id"`
	TaskID     string    `json:"task_id" db:"task_id"`
	ClaimerID  string    `json:"claimer_id" db:"claimer_id"`
	Photos     []Photo   `json:"photos"`
	Note       *string   `json:"note,omitempty" db:"note"`
	SubmitLat  float64   `json:"submit_lat" db:"submit_lat"`
	SubmitLng  float64   `json:"submit_lng" db:"submit_lng"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}

type Photo struct {
	ID        string    `json:"id" db:"id"`
	SubID     string    `json:"submission_id" db:"submission_id"`
	URL       string    `json:"url" db:"url"`
	Latitude  float64   `json:"latitude" db:"latitude"`
	Longitude float64   `json:"longitude" db:"longitude"`
	Timestamp time.Time `json:"timestamp" db:"photo_timestamp"`
	PHash     string    `json:"-" db:"phash"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type SubmitEvidenceRequest struct {
	TaskID    string        `json:"task_id" binding:"required"`
	Photos    []PhotoUpload `json:"photos" binding:"omitempty,max=3"`
	Note      *string       `json:"note,omitempty" binding:"omitempty,max=200"`
	SubmitLat float64       `json:"submit_lat"`
	SubmitLng float64       `json:"submit_lng"`
}

type PhotoUpload struct {
	URL       string    `json:"url" binding:"required"`
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	Timestamp time.Time `json:"timestamp" binding:"required"`
}
