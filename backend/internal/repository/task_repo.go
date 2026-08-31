package repository

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
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

// taskCols 任务查询列（bounty_beans 为金豆赏金）
var taskCols = []string{
	"id", "publisher_id", "title", "description", "target_lat", "target_lng", "target_addr",
	"radius", "time_limit", "bounty_beans", "status", "claimer_id", "claimed_at",
	"submitted_at", "confirmed_at", "refunded_at", "created_at", "updated_at",
}

const taskColsSQL = `id, publisher_id, title, description, target_lat, target_lng, target_addr,
			  radius, time_limit, bounty_beans, status, claimer_id, claimed_at,
			  submitted_at, confirmed_at, refunded_at, created_at, updated_at`

func prefixedTaskCols(prefix string) string {
	return prefix + strings.Join(taskCols, ", "+prefix)
}

func scanTaskDest(t *model.Task) []interface{} {
	return []interface{}{
		&t.ID, &t.PublisherID, &t.Title, &t.Description,
		&t.TargetLat, &t.TargetLng, &t.TargetAddr, &t.Radius,
		&t.TimeLimit, &t.BountyBeans, &t.Status,
		&t.ClaimerID, &t.ClaimedAt, &t.SubmittedAt, &t.ConfirmedAt,
		&t.RefundedAt, &t.CreatedAt, &t.UpdatedAt,
	}
}

func (r *TaskRepo) Create(ctx context.Context, t *model.Task) (*model.Task, error) {
	t.ID = uuid.NewString()
	if t.Status == "" {
		t.Status = model.StatusPublished
	}
	if t.BountyBeans <= 0 {
		t.BountyBeans = model.MinBountyBeans
	}
	t.CreatedAt = time.Now()
	t.UpdatedAt = time.Now()
	query := `INSERT INTO tasks (id, publisher_id, title, description, target_lat, target_lng, target_addr, radius, time_limit, bounty_beans, status, created_at, updated_at)
			  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query,
		t.ID, t.PublisherID, t.Title, t.Description, t.TargetLat, t.TargetLng,
		t.TargetAddr, t.Radius, t.TimeLimit, t.BountyBeans, t.Status, t.CreatedAt, t.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return t, nil
}

// Activate 旧版兼容：金豆制下任务发布即生效。
func (r *TaskRepo) Activate(ctx context.Context, taskID string) error {
	query := `UPDATE tasks SET status = ?, updated_at = ? WHERE id = ? AND status = 'pending'`
	result, err := r.db.ExecContext(ctx, query, model.StatusPublished, time.Now(), taskID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("task not found or already active")
	}
	return nil
}

func (r *TaskRepo) FindByID(ctx context.Context, id string) (*model.Task, error) {
	query := `SELECT ` + taskColsSQL + ` FROM tasks WHERE id = ?`
	t := &model.Task{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(scanTaskDest(t)...)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return t, err
}

// SquareList 任务广场列表，支持多维度排序：
//   - distance（默认）：Haversine 距离升序
//   - beans：赏金金豆降序
//   - newest：发布时间降序
//
// lat、lng 均为 0 视为「全部」；radius > 0 表示仅返回该半径内的任务。
func (r *TaskRepo) SquareList(ctx context.Context, lat, lng float64, radius, limit, offset int, sort string) ([]model.Task, int64, error) {
	cols := prefixedTaskCols("t.")

	if lat == 0 && lng == 0 {
		var total int64
		if err := r.db.QueryRowContext(ctx,
			`SELECT COUNT(*) FROM tasks WHERE status = 'published'`).Scan(&total); err != nil {
			return nil, 0, err
		}
		order := "t.created_at DESC"
		if sort == model.SortBeans {
			order = "t.bounty_beans DESC, t.created_at DESC"
		}
		query := fmt.Sprintf(`SELECT %s, 0 AS distance FROM tasks t
				  WHERE t.status = 'published' ORDER BY %s LIMIT ? OFFSET ?`, cols, order)
		rows, err := r.db.QueryContext(ctx, query, limit, offset)
		if err != nil {
			return nil, 0, err
		}
		defer rows.Close()
		return scanAllRows(rows), total, nil
	}

	// 有坐标：distance 仍计算返回（展示用），排序维度由 sort 决定
	dExpr := `(6371000 * acos(cos(radians(?)) * cos(radians(t.target_lat)) * cos(radians(t.target_lng) - radians(?)) + sin(radians(?)) * sin(radians(t.target_lat))))`

	var order string
	switch sort {
	case model.SortBeans:
		order = "t.bounty_beans DESC, t.created_at DESC"
	case model.SortNewest:
		order = "t.created_at DESC"
	default:
		order = "distance"
	}

	var total int64
	if radius <= 0 {
		if err := r.db.QueryRowContext(ctx,
			`SELECT COUNT(*) FROM tasks WHERE status = 'published'`).Scan(&total); err != nil {
			return nil, 0, err
		}
	} else {
		countQ := fmt.Sprintf(`SELECT COUNT(*) FROM tasks t WHERE t.status = 'published' AND %s <= ?`, dExpr)
		if err := r.db.QueryRowContext(ctx, countQ, lat, lng, lat, radius).Scan(&total); err != nil {
			return nil, 0, err
		}
	}

	var query string
	if radius <= 0 {
		query = fmt.Sprintf(`SELECT %s, %s AS distance FROM tasks t
				  WHERE t.status = 'published' ORDER BY %s LIMIT ? OFFSET ?`, cols, dExpr, order)
	} else {
		query = fmt.Sprintf(`SELECT %s, %s AS distance FROM tasks t
				  WHERE t.status = 'published' AND %s <= ? ORDER BY %s LIMIT ? OFFSET ?`, cols, dExpr, dExpr, order)
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
		if err := rows.Scan(append(scanTaskDest(&t), &t.Distance)...); err != nil {
			return nil, 0, err
		}
		tasks = append(tasks, t)
	}
	return tasks, total, nil
}

// scanAllRows 扫描不含 distance 列的行集
func scanAllRows(rows *sql.Rows) []model.Task {
	var tasks []model.Task
	for rows.Next() {
		var t model.Task
		if err := rows.Scan(scanTaskDest(&t)...); err != nil {
			continue
		}
		tasks = append(tasks, t)
	}
	return tasks
}

func (r *TaskRepo) UpdateStatus(ctx context.Context, id string, status model.TaskStatus) error {
	_, err := r.db.ExecContext(ctx, `UPDATE tasks SET status = ?, updated_at = ? WHERE id = ?`, status, time.Now(), id)
	return err
}

func (r *TaskRepo) Claim(ctx context.Context, taskID, claimerID string) error {
	query := `UPDATE tasks SET status = ?, claimer_id = ?, claimed_at = ?, updated_at = ?
			  WHERE id = ? AND status = 'published'`
	result, err := r.db.ExecContext(ctx, query, model.StatusClaimed, claimerID, time.Now(), time.Now(), taskID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("task already claimed or not found")
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

// CountConfirmedByClaimer 统计猎人已获发布者确认（结算完成）的任务数，
// 用于奖励中心兑换资格的第二维门槛（防高赏金速通）。
func (r *TaskRepo) CountConfirmedByClaimer(ctx context.Context, userID string) (int, error) {
	query := `SELECT COUNT(*) FROM tasks WHERE claimer_id = ? AND status = 'confirmed'`
	var count int
	err := r.db.QueryRowContext(ctx, query, userID).Scan(&count)
	return count, err
}

func (r *TaskRepo) FindPublishedByUser(ctx context.Context, userID string, page, size int) ([]model.Task, int64, error) {
	var total int64
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM tasks WHERE publisher_id = ?`, userID).Scan(&total); err != nil {
		return nil, 0, err
	}
	query := `SELECT ` + taskColsSQL + `
			  FROM tasks WHERE publisher_id = ? AND status <> 'cancelled' ORDER BY created_at DESC LIMIT ? OFFSET ?`
	return r.listTasks(ctx, query, total, userID, size, (page-1)*size)
}

func (r *TaskRepo) FindClaimedByUser(ctx context.Context, userID string, page, size int) ([]model.Task, int64, error) {
	var total int64
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM tasks WHERE claimer_id = ?`, userID).Scan(&total); err != nil {
		return nil, 0, err
	}
	query := `SELECT ` + taskColsSQL + `
			  FROM tasks WHERE claimer_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?`
	return r.listTasks(ctx, query, total, userID, size, (page-1)*size)
}

// CancelByPublisher 仅允许发布人撤回自己"已发布且未被认领"的任务。
// 金豆返还由 service 层统一处理（AddBeans）。
func (r *TaskRepo) CancelByPublisher(ctx context.Context, taskID, publisherID string) error {
	query := `UPDATE tasks SET status = ?, updated_at = ? WHERE id = ? AND publisher_id = ? AND status = 'published'`
	result, err := r.db.ExecContext(ctx, query, model.StatusCancelled, time.Now(), taskID, publisherID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("task not cancellable by publisher")
	}
	return nil
}

func (r *TaskRepo) Release(ctx context.Context, taskID string) error {
	query := `UPDATE tasks SET status = ?, claimer_id = NULL, claimed_at = NULL, updated_at = ?
			  WHERE id = ? AND status = 'claimed'`
	result, err := r.db.ExecContext(ctx, query, model.StatusReleased, time.Now(), taskID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
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
	if affected, _ := result.RowsAffected(); affected == 0 {
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
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("task status invalid for confirm")
	}
	return nil
}

func (r *TaskRepo) MarkDisputed(ctx context.Context, taskID string) error {
	query := `UPDATE tasks SET status = ?, updated_at = ? WHERE id = ? AND status = 'submitted'`
	result, err := r.db.ExecContext(ctx, query, model.StatusDisputed, time.Now(), taskID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("task status invalid for dispute")
	}
	return nil
}

// RequestChanges "要求补充证据"：submitted → claimed。
// 任务退回接单人，允许其修改后再次提交（支持多轮）；
// 与 Disputed（真正的纠纷，走仲裁/退款）严格区分。
func (r *TaskRepo) RequestChanges(ctx context.Context, taskID string) error {
	now := time.Now()
	query := `UPDATE tasks SET status = ?, updated_at = ? WHERE id = ? AND status = 'submitted'`
	result, err := r.db.ExecContext(ctx, query, model.StatusClaimed, now, taskID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("task status invalid for request changes")
	}
	return nil
}

func (r *TaskRepo) Refund(ctx context.Context, taskID string) error {
	query := `UPDATE tasks SET status = ?, refunded_at = ?, updated_at = ? WHERE id = ?`
	result, err := r.db.ExecContext(ctx, query, model.StatusRefunded, time.Now(), time.Now(), taskID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("task not found")
	}
	return nil
}

func (r *TaskRepo) FindExpiredTasks(ctx context.Context) ([]model.Task, error) {
	cutoff := time.Now().Add(-time.Duration(model.TaskExpireHours) * time.Hour)
	query := `SELECT ` + taskColsSQL + `
			  FROM tasks WHERE status = 'published' AND created_at < ?`
	rows, err := r.db.QueryContext(ctx, query, cutoff)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanAllRows(rows), nil
}

// DeleteByOwner 发布人硬删除自己的任务记录（仅校验归属，状态校验由 service 层完成）。
func (r *TaskRepo) DeleteByOwner(ctx context.Context, taskID, publisherID string) error {
	query := `DELETE FROM tasks WHERE id = ? AND publisher_id = ?`
	result, err := r.db.ExecContext(ctx, query, taskID, publisherID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("task not found or not owned by user")
	}
	return nil
}

// FindIDsByPublisher 列出用户发布的全部任务 ID（账户删除时级联清理用）
func (r *TaskRepo) FindIDsByPublisher(ctx context.Context, publisherID string) ([]string, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT id FROM tasks WHERE publisher_id = ?`, publisherID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// DeleteAllByPublisher 硬删除用户发布的全部任务（账户删除用，前置条件：无进行中任务）
func (r *TaskRepo) DeleteAllByPublisher(ctx context.Context, publisherID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM tasks WHERE publisher_id = ?`, publisherID)
	return err
}

func (r *TaskRepo) listTasks(ctx context.Context, query string, total int64, arg string, limit, offset int) ([]model.Task, int64, error) {
	rows, err := r.db.QueryContext(ctx, query, arg, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	return scanAllRows(rows), total, nil
}
