package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"seeker/internal/model"

	"github.com/google/uuid"
)

type TaskRepo struct {
	db *sql.DB
}

func NewTaskRepo(db *sql.DB) *TaskRepo {
	return &TaskRepo{db: db}
}

func (r *TaskRepo) Create(ctx context.Context, t *model.Task) (*model.Task, error) {
	t.ID = uuid.NewString()
	if t.Status == "" {
		t.Status = model.StatusPublished
	}
	t.CreatedAt = time.Now()
	t.UpdatedAt = time.Now()
	query := `INSERT INTO tasks (id, publisher_id, title, description, target_lat, target_lng, target_addr, radius, time_limit, bounty, fee, currency, status, created_at, updated_at) 
			  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query,
		t.ID, t.PublisherID, t.Title, t.Description, t.TargetLat, t.TargetLng,
		t.TargetAddr, t.Radius, t.TimeLimit, t.Bounty, t.Fee, t.Currency, t.Status, t.CreatedAt, t.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return t, nil
}

// Activate 将待提交任务转为已发布
func (r *TaskRepo) Activate(ctx context.Context, taskID string) error {
	query := `UPDATE tasks SET status = ?, updated_at = ? WHERE id = ? AND status = 'pending'`
	result, err := r.db.ExecContext(ctx, query, model.StatusPublished, time.Now(), taskID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return fmt.Errorf("任务不存在或状态不正确")
	}
	return nil
}

func (r *TaskRepo) FindByID(ctx context.Context, id string) (*model.Task, error) {
	query := `SELECT id, publisher_id, title, description, target_lat, target_lng, target_addr, 
			  radius, time_limit, bounty, fee, currency, status, claimer_id, claimed_at, submitted_at, confirmed_at, refunded_at, created_at, updated_at 
			  FROM tasks WHERE id = ?`
	t := &model.Task{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&t.ID, &t.PublisherID, &t.Title, &t.Description,
		&t.TargetLat, &t.TargetLng, &t.TargetAddr, &t.Radius,
		&t.TimeLimit, &t.Bounty, &t.Fee, &t.Currency, &t.Status,
		&t.ClaimerID, &t.ClaimedAt, &t.SubmittedAt, &t.ConfirmedAt,
		&t.RefundedAt, &t.CreatedAt, &t.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return t, err
}

// SquareList 按 Haversine 球面距离排序，过滤半径内的已发布任务。
// 当 lat、lng 均为 0 时视为「全部」，不计算距离，返回所有已发布任务。
// SQLite 无 PostGIS，使用内联公式计算两坐标间米数距离。
func (r *TaskRepo) SquareList(ctx context.Context, lat, lng float64, radius, limit, offset int) ([]model.Task, int64, error) {
	if lat == 0 && lng == 0 {
		var total int64
		if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM tasks WHERE status = 'published'`).Scan(&total); err != nil {
			return nil, 0, err
		}

		query := `SELECT id, publisher_id, title, description, target_lat, target_lng, target_addr, 
				  radius, time_limit, bounty, fee, currency, status, claimer_id, claimed_at, submitted_at, 
				  confirmed_at, refunded_at, created_at, updated_at,
				  0 AS distance
				  FROM tasks 
				  WHERE status = 'published' 
				  ORDER BY created_at DESC
				  LIMIT ? OFFSET ?`

		rows, err := r.db.QueryContext(ctx, query, limit, offset)
		if err != nil {
			return nil, 0, err
		}
		defer rows.Close()

		var tasks []model.Task
		for rows.Next() {
			var t model.Task
			if err := rows.Scan(
				&t.ID, &t.PublisherID, &t.Title, &t.Description,
				&t.TargetLat, &t.TargetLng, &t.TargetAddr, &t.Radius,
				&t.TimeLimit, &t.Bounty, &t.Fee, &t.Currency, &t.Status,
				&t.ClaimerID, &t.ClaimedAt, &t.SubmittedAt, &t.ConfirmedAt,
				&t.RefundedAt, &t.CreatedAt, &t.UpdatedAt, &t.Distance,
			); err != nil {
				return nil, 0, err
			}
			tasks = append(tasks, t)
		}
		return tasks, total, nil
	}

	distanceExpr := `(6371000 * acos(cos(radians(?)) * cos(radians(target_lat)) * cos(radians(target_lng) - radians(?)) + sin(radians(?)) * sin(radians(target_lat))))`

	// radius <= 0 表示"全部"，仅按距离排序展示，不做距离硬过滤；
	// radius > 0 表示查看该半径内的附近任务。
	var countQuery string
	if radius <= 0 {
		countQuery = `SELECT COUNT(*) FROM tasks WHERE status = 'published'`
	} else {
		countQuery = fmt.Sprintf(`SELECT COUNT(*) FROM tasks WHERE status = 'published' AND %s <= ?`, distanceExpr)
	}
	var total int64
	if radius <= 0 {
		if err := r.db.QueryRowContext(ctx, countQuery).Scan(&total); err != nil {
			return nil, 0, err
		}
	} else {
		if err := r.db.QueryRowContext(ctx, countQuery, lat, lng, lat, radius).Scan(&total); err != nil {
			return nil, 0, err
		}
	}

	var query string
	if radius <= 0 {
		query = fmt.Sprintf(`SELECT t.id, t.publisher_id, t.title, t.description, t.target_lat, t.target_lng, t.target_addr, 
				  t.radius, t.time_limit, t.bounty, t.fee, t.currency, t.status, t.claimer_id, t.claimed_at, t.submitted_at, 
				  t.confirmed_at, t.refunded_at, t.created_at, t.updated_at,
				  %s AS distance
				  FROM tasks t 
				  WHERE t.status = 'published' 
				  ORDER BY distance
				  LIMIT ? OFFSET ?`, distanceExpr)
	} else {
		query = fmt.Sprintf(`SELECT t.id, t.publisher_id, t.title, t.description, t.target_lat, t.target_lng, t.target_addr, 
				  t.radius, t.time_limit, t.bounty, t.fee, t.currency, t.status, t.claimer_id, t.claimed_at, t.submitted_at, 
				  t.confirmed_at, t.refunded_at, t.created_at, t.updated_at,
				  %s AS distance
				  FROM tasks t 
				  WHERE t.status = 'published' AND %s <= ?
				  ORDER BY distance
				  LIMIT ? OFFSET ?`, distanceExpr, distanceExpr)
	}

	var rows *sql.Rows
	var err error
	if radius <= 0 {
		rows, err = r.db.QueryContext(ctx, query, lat, lng, lat, limit, offset)
	} else {
		rows, err = r.db.QueryContext(ctx, query, lat, lng, lat, lat, lng, lat, radius, limit, offset)
	}
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var tasks []model.Task
	for rows.Next() {
		var t model.Task
		if err := rows.Scan(
			&t.ID, &t.PublisherID, &t.Title, &t.Description,
			&t.TargetLat, &t.TargetLng, &t.TargetAddr, &t.Radius,
			&t.TimeLimit, &t.Bounty, &t.Fee, &t.Currency, &t.Status,
			&t.ClaimerID, &t.ClaimedAt, &t.SubmittedAt, &t.ConfirmedAt,
			&t.RefundedAt, &t.CreatedAt, &t.UpdatedAt, &t.Distance,
		); err != nil {
			return nil, 0, err
		}
		tasks = append(tasks, t)
	}
	return tasks, total, nil
}

func (r *TaskRepo) UpdateStatus(ctx context.Context, id string, status model.TaskStatus) error {
	query := `UPDATE tasks SET status = ?, updated_at = ? WHERE id = ?`
	_, err := r.db.ExecContext(ctx, query, status, time.Now(), id)
	return err
}

func (r *TaskRepo) Claim(ctx context.Context, taskID, claimerID string) error {
	claimedAt := time.Now()
	query := `UPDATE tasks SET status = ?, claimer_id = ?, claimed_at = ?, updated_at = ? 
			  WHERE id = ? AND status = 'published'`
	result, err := r.db.ExecContext(ctx, query, model.StatusClaimed, claimerID, claimedAt, time.Now(), taskID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return fmt.Errorf("任务已被其他人领取或不存在")
	}
	return nil
}

func (r *TaskRepo) CountActiveByUser(ctx context.Context, userID string) (int, error) {
	query := `SELECT COUNT(*) FROM tasks WHERE (publisher_id = ? AND status IN ('claimed','submitted','disputed')) 
			  OR (claimer_id = ? AND status IN ('claimed','submitted'))`
	var count int
	err := r.db.QueryRowContext(ctx, query, userID, userID).Scan(&count)
	return count, err
}

func (r *TaskRepo) CountClaimedByUser(ctx context.Context, userID string) (int, error) {
	query := `SELECT COUNT(*) FROM tasks WHERE claimer_id = ? AND status = 'claimed'`
	var count int
	err := r.db.QueryRowContext(ctx, query, userID).Scan(&count)
	return count, err
}

func (r *TaskRepo) FindPublishedByUser(ctx context.Context, userID string, page, size int) ([]model.Task, int64, error) {
	countQuery := `SELECT COUNT(*) FROM tasks WHERE publisher_id = ?`
	var total int64
	if err := r.db.QueryRowContext(ctx, countQuery, userID).Scan(&total); err != nil {
		return nil, 0, err
	}
	query := `SELECT id, publisher_id, title, description, target_lat, target_lng, target_addr, 
			  radius, time_limit, bounty, fee, currency, status, claimer_id, claimed_at, submitted_at, confirmed_at, refunded_at, created_at, updated_at 
			  FROM tasks WHERE publisher_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?`
	return r.listTasks(ctx, query, total, userID, size, (page-1)*size)
}

func (r *TaskRepo) FindClaimedByUser(ctx context.Context, userID string, page, size int) ([]model.Task, int64, error) {
	countQuery := `SELECT COUNT(*) FROM tasks WHERE claimer_id = ?`
	var total int64
	if err := r.db.QueryRowContext(ctx, countQuery, userID).Scan(&total); err != nil {
		return nil, 0, err
	}
	query := `SELECT id, publisher_id, title, description, target_lat, target_lng, target_addr, 
			  radius, time_limit, bounty, fee, currency, status, claimer_id, claimed_at, submitted_at, confirmed_at, refunded_at, created_at, updated_at 
			  FROM tasks WHERE claimer_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?`
	return r.listTasks(ctx, query, total, userID, size, (page-1)*size)
}

func (r *TaskRepo) Release(ctx context.Context, taskID string) error {
	query := `UPDATE tasks SET status = ?, claimer_id = NULL, claimed_at = NULL, updated_at = ? 
			  WHERE id = ? AND status = 'claimed'`
	result, err := r.db.ExecContext(ctx, query, model.StatusReleased, time.Now(), taskID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return fmt.Errorf("task status invalid for release")
	}
	return nil
}

func (r *TaskRepo) Submit(ctx context.Context, taskID string) error {
	now := time.Now()
	query := `UPDATE tasks SET status = ?, submitted_at = ?, updated_at = ? 
			  WHERE id = ? AND status = 'claimed'`
	result, err := r.db.ExecContext(ctx, query, model.StatusSubmitted, now, now, taskID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return fmt.Errorf("task status invalid for submit")
	}
	return nil
}

func (r *TaskRepo) Confirm(ctx context.Context, taskID string) error {
	query := `UPDATE tasks SET status = ?, confirmed_at = ?, updated_at = ? 
			  WHERE id = ? AND status = 'submitted'`
	result, err := r.db.ExecContext(ctx, query, model.StatusCompleted, time.Now(), time.Now(), taskID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return fmt.Errorf("任务状态不正确，无法确认")
	}
	return nil
}

func (r *TaskRepo) MarkDisputed(ctx context.Context, taskID string) error {
	query := `UPDATE tasks SET status = ?, updated_at = ? WHERE id = ? AND status = 'submitted'`
	result, err := r.db.ExecContext(ctx, query, model.StatusDisputed, time.Now(), taskID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return fmt.Errorf("任务状态不正确")
	}
	return nil
}

func (r *TaskRepo) Refund(ctx context.Context, taskID string) error {
	query := `UPDATE tasks SET status = ?, refunded_at = ?, updated_at = ? WHERE id = ?`
	result, err := r.db.ExecContext(ctx, query, model.StatusRefunded, time.Now(), time.Now(), taskID)
	if err != nil {
		return err
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		return fmt.Errorf("任务不存在")
	}
	return nil
}

func (r *TaskRepo) FindExpiredTasks(ctx context.Context) ([]model.Task, error) {
	cutoff := time.Now().Add(-time.Duration(model.TaskExpireHours) * time.Hour)
	query := `SELECT id, publisher_id, title, description, target_lat, target_lng, target_addr, 
			  radius, time_limit, bounty, fee, currency, status, claimer_id, claimed_at, submitted_at, confirmed_at, refunded_at, created_at, updated_at 
			  FROM tasks WHERE status = 'published' AND created_at < ?`
	rows, err := r.db.QueryContext(ctx, query, cutoff)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tasks []model.Task
	for rows.Next() {
		var t model.Task
		if err := rows.Scan(
			&t.ID, &t.PublisherID, &t.Title, &t.Description,
			&t.TargetLat, &t.TargetLng, &t.TargetAddr, &t.Radius,
			&t.TimeLimit, &t.Bounty, &t.Fee, &t.Currency, &t.Status,
			&t.ClaimerID, &t.ClaimedAt, &t.SubmittedAt, &t.ConfirmedAt,
			&t.RefundedAt, &t.CreatedAt, &t.UpdatedAt,
		); err != nil {
			return nil, err
		}
		tasks = append(tasks, t)
	}
	return tasks, nil
}

func (r *TaskRepo) listTasks(ctx context.Context, query string, total int64, arg string, limit, offset int) ([]model.Task, int64, error) {
	rows, err := r.db.QueryContext(ctx, query, arg, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var tasks []model.Task
	for rows.Next() {
		var t model.Task
		if err := rows.Scan(
			&t.ID, &t.PublisherID, &t.Title, &t.Description,
			&t.TargetLat, &t.TargetLng, &t.TargetAddr, &t.Radius,
			&t.TimeLimit, &t.Bounty, &t.Fee, &t.Currency, &t.Status,
			&t.ClaimerID, &t.ClaimedAt, &t.SubmittedAt, &t.ConfirmedAt,
			&t.RefundedAt, &t.CreatedAt, &t.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		tasks = append(tasks, t)
	}
	return tasks, total, nil
}
