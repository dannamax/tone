package repository

import (
	"context"
	"database/sql"
	"encoding/json"

	"seeker/internal/model"

	"github.com/google/uuid"
)

type MessageRepo struct {
	db *sql.DB
}

func NewMessageRepo(db *sql.DB) *MessageRepo {
	return &MessageRepo{db: db}
}

func (r *MessageRepo) Create(ctx context.Context, m *model.TaskMessage) (*model.TaskMessage, error) {
	m.ID = uuid.NewString()

	imageJSON, _ := json.Marshal(m.ImageURLs)
	if imageJSON == nil {
		imageJSON = []byte("[]")
	}

	query := `INSERT INTO task_messages (id, task_id, sender_id, content, image_urls) VALUES (?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query, m.ID, m.TaskID, m.SenderID, m.Content, string(imageJSON))
	if err != nil {
		return nil, err
	}

	return r.FindByID(ctx, m.ID)
}

func (r *MessageRepo) FindByTaskID(ctx context.Context, taskID string) ([]model.TaskMessage, error) {
	query := `SELECT id, task_id, sender_id, content, image_urls, created_at 
			  FROM task_messages WHERE task_id = ? ORDER BY created_at ASC`
	rows, err := r.db.QueryContext(ctx, query, taskID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []model.TaskMessage
	for rows.Next() {
		var m model.TaskMessage
		var imageJSON string
		if err := rows.Scan(&m.ID, &m.TaskID, &m.SenderID, &m.Content, &imageJSON, &m.CreatedAt); err != nil {
			return nil, err
		}
		if err := json.Unmarshal([]byte(imageJSON), &m.ImageURLs); err != nil {
			m.ImageURLs = []string{}
		}
		msgs = append(msgs, m)
	}
	return msgs, nil
}

// DeleteByTaskID 删除任务的全部履约对话消息（任务删除时级联清理）。
func (r *MessageRepo) DeleteByTaskID(ctx context.Context, taskID string) error {
	query := `DELETE FROM task_messages WHERE task_id = ?`
	_, err := r.db.ExecContext(ctx, query, taskID)
	return err
}

func (r *MessageRepo) FindByID(ctx context.Context, id string) (*model.TaskMessage, error) {
	query := `SELECT id, task_id, sender_id, content, image_urls, created_at 
			  FROM task_messages WHERE id = ?`
	var m model.TaskMessage
	var imageJSON string
	err := r.db.QueryRowContext(ctx, query, id).Scan(&m.ID, &m.TaskID, &m.SenderID, &m.Content, &imageJSON, &m.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal([]byte(imageJSON), &m.ImageURLs); err != nil {
		m.ImageURLs = []string{}
	}
	return &m, nil
}
