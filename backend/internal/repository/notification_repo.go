package repository

import (
	"context"
	"database/sql"

	"seeker/internal/model"

	"github.com/google/uuid"
)

type NotificationRepo struct {
	db *sql.DB
}

func NewNotificationRepo(db *sql.DB) *NotificationRepo {
	return &NotificationRepo{db: db}
}

func (r *NotificationRepo) Create(ctx context.Context, userID, notifyType, title, content, taskID string) (*model.Notification, error) {
	n := &model.Notification{
		UserID:  userID,
		Type:    notifyType,
		Title:   title,
		Content: content,
	}
	if taskID != "" {
		tid := taskID
		n.TaskID = &tid
	}
	n.ID = uuid.NewString()
	query := `INSERT INTO notifications (id, user_id, type, title, content, task_id, is_read) 
			  VALUES (?, ?, ?, ?, ?, ?, 0)`
	_, err := r.db.ExecContext(ctx, query, n.ID, n.UserID, n.Type, n.Title, n.Content, n.TaskID)
	if err != nil {
		return nil, err
	}
	return r.FindByID(ctx, n.ID)
}

func (r *NotificationRepo) FindByID(ctx context.Context, id string) (*model.Notification, error) {
	query := `SELECT id, user_id, type, title, content, task_id, is_read, created_at 
			  FROM notifications WHERE id = ?`
	n := &model.Notification{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&n.ID, &n.UserID, &n.Type, &n.Title, &n.Content, &n.TaskID, &n.IsRead, &n.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return n, err
}

func (r *NotificationRepo) ListByUser(ctx context.Context, userID string, page, size int) ([]model.Notification, int64, error) {
	countQuery := `SELECT COUNT(*) FROM notifications WHERE user_id = ?`
	var total int64
	if err := r.db.QueryRowContext(ctx, countQuery, userID).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `SELECT id, user_id, type, title, content, task_id, is_read, created_at 
			  FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?`
	rows, err := r.db.QueryContext(ctx, query, userID, size, (page-1)*size)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []model.Notification
	for rows.Next() {
		var n model.Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Content, &n.TaskID, &n.IsRead, &n.CreatedAt); err != nil {
			return nil, 0, err
		}
		list = append(list, n)
	}
	return list, total, nil
}

func (r *NotificationRepo) MarkRead(ctx context.Context, id, userID string) error {
	query := `UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?`
	_, err := r.db.ExecContext(ctx, query, id, userID)
	return err
}

func (r *NotificationRepo) MarkAllRead(ctx context.Context, userID string) error {
	query := `UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0`
	_, err := r.db.ExecContext(ctx, query, userID)
	return err
}

func (r *NotificationRepo) UnreadCount(ctx context.Context, userID string) (int, error) {
	query := `SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0`
	var count int
	err := r.db.QueryRowContext(ctx, query, userID).Scan(&count)
	return count, err
}

// DeleteByTaskID 删除任务相关的全部通知（任务删除时级联清理）。
func (r *NotificationRepo) DeleteByTaskID(ctx context.Context, taskID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM notifications WHERE task_id = ?`, taskID)
	return err
}

// DeleteByUser 删除用户的全部通知（账户删除用）。
func (r *NotificationRepo) DeleteByUser(ctx context.Context, userID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM notifications WHERE user_id = ?`, userID)
	return err
}

// DeleteByTaskID 删除任务的争议记录（任务删除时级联清理）。
func (r *NotificationRepo) DeleteDisputeByTaskID(ctx context.Context, taskID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM disputes WHERE task_id = ?`, taskID)
	return err
}

func (r *NotificationRepo) CreateDispute(ctx context.Context, taskID, reason string) (*model.Dispute, error) {
	id := uuid.NewString()
	query := `INSERT INTO disputes (id, task_id, reason) VALUES (?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query, id, taskID, reason)
	if err != nil {
		return nil, err
	}
	return &model.Dispute{ID: id, TaskID: taskID, Reason: reason}, nil
}

func (r *NotificationRepo) ResolveDispute(ctx context.Context, id, result string) error {
	query := `UPDATE disputes SET result = ?, resolved_at = CURRENT_TIMESTAMP WHERE id = ?`
	_, err := r.db.ExecContext(ctx, query, result, id)
	return err
}
