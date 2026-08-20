package repository

import (
	"context"
	"database/sql"

	"seeker/internal/model"

	"github.com/google/uuid"
)

type SubmissionRepo struct {
	db *sql.DB
}

func NewSubmissionRepo(db *sql.DB) *SubmissionRepo {
	return &SubmissionRepo{db: db}
}

func (r *SubmissionRepo) Create(ctx context.Context, s *model.Submission) (*model.Submission, error) {
	s.ID = uuid.NewString()
	query := `INSERT INTO submissions (id, task_id, claimer_id, note, submit_lat, submit_lng) 
			  VALUES (?, ?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query, s.ID, s.TaskID, s.ClaimerID, s.Note, s.SubmitLat, s.SubmitLng)
	if err != nil {
		return nil, err
	}

	for i := range s.Photos {
		s.Photos[i].SubID = s.ID
		if err := r.createPhoto(ctx, &s.Photos[i]); err != nil {
			return nil, err
		}
	}
	return r.FindByTaskID(ctx, s.TaskID)
}

func (r *SubmissionRepo) createPhoto(ctx context.Context, p *model.Photo) error {
	p.ID = uuid.NewString()
	query := `INSERT INTO submission_photos (id, submission_id, url, latitude, longitude, photo_timestamp, phash) 
			  VALUES (?, ?, ?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query, p.ID, p.SubID, p.URL, p.Latitude, p.Longitude, p.Timestamp, p.PHash)
	return err
}

func (r *SubmissionRepo) FindByTaskID(ctx context.Context, taskID string) (*model.Submission, error) {
	query := `SELECT id, task_id, claimer_id, note, submit_lat, submit_lng, created_at 
			  FROM submissions WHERE task_id = ? ORDER BY created_at DESC LIMIT 1`
	s := &model.Submission{}
	err := r.db.QueryRowContext(ctx, query, taskID).Scan(
		&s.ID, &s.TaskID, &s.ClaimerID, &s.Note, &s.SubmitLat, &s.SubmitLng, &s.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	photos, err := r.FindPhotos(ctx, s.ID)
	if err != nil {
		return nil, err
	}
	s.Photos = photos
	return s, nil
}

func (r *SubmissionRepo) FindPhotos(ctx context.Context, subID string) ([]model.Photo, error) {
	query := `SELECT id, submission_id, url, latitude, longitude, photo_timestamp, phash, created_at 
			  FROM submission_photos WHERE submission_id = ?`
	rows, err := r.db.QueryContext(ctx, query, subID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var photos []model.Photo
	for rows.Next() {
		var p model.Photo
		if err := rows.Scan(&p.ID, &p.SubID, &p.URL, &p.Latitude, &p.Longitude, &p.Timestamp, &p.PHash, &p.CreatedAt); err != nil {
			return nil, err
		}
		photos = append(photos, p)
	}
	return photos, nil
}

func (r *SubmissionRepo) IsPHashDuplicate(ctx context.Context, phash string) (bool, error) {
	query := `SELECT COUNT(*) FROM submission_photos WHERE phash = ?`
	var count int
	err := r.db.QueryRowContext(ctx, query, phash).Scan(&count)
	return count > 0, err
}
