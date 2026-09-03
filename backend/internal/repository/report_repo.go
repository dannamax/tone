package repository

import (
	"context"
	"database/sql"

	"seeker/internal/model"

	"github.com/google/uuid"
)

type ReportRepo struct {
	db *sql.DB
}

func NewReportRepo(db *sql.DB) *ReportRepo {
	return &ReportRepo{db: db}
}

// Block 拉黑用户（幂等：重复拉黑无副作用）。
func (r *ReportRepo) Block(ctx context.Context, blockerID, blockedID string) error {
	query := `INSERT INTO user_blocks (blocker_id, blocked_id) VALUES (?, ?)
			  ON CONFLICT (blocker_id, blocked_id) DO NOTHING`
	_, err := r.db.ExecContext(ctx, query, blockerID, blockedID)
	return err
}

// Unblock 解除拉黑。
func (r *ReportRepo) Unblock(ctx context.Context, blockerID, blockedID string) error {
	_, err := r.db.ExecContext(ctx,
		`DELETE FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?`, blockerID, blockedID)
	return err
}

// IsBlockedBetween 双向判断两个用户之间是否存在拉黑关系。
func (r *ReportRepo) IsBlockedBetween(ctx context.Context, userA, userB string) (bool, error) {
	query := `SELECT COUNT(*) FROM user_blocks
			  WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)`
	var n int
	err := r.db.QueryRowContext(ctx, query, userA, userB, userB, userA).Scan(&n)
	return n > 0, err
}

// ListBlocked 列出 blocker 拉黑的全部用户（含昵称，便于客户端展示）。
func (r *ReportRepo) ListBlocked(ctx context.Context, blockerID string) ([]model.BlockedUser, error) {
	query := `SELECT ub.blocked_id, COALESCE(u.nickname, ''), ub.created_at
			  FROM user_blocks ub LEFT JOIN users u ON u.id = ub.blocked_id
			  WHERE ub.blocker_id = ? ORDER BY ub.created_at DESC`
	rows, err := r.db.QueryContext(ctx, query, blockerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []model.BlockedUser{}
	for rows.Next() {
		var b model.BlockedUser
		if err := rows.Scan(&b.UserID, &b.Nickname, &b.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

// CreateReport 落一条举报记录。
func (r *ReportRepo) CreateReport(ctx context.Context, rep *model.ContentReport) error {
	rep.ID = uuid.NewString()
	query := `INSERT INTO content_reports (id, reporter_id, target_type, target_id, reason)
			  VALUES (?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query, rep.ID, rep.ReporterID, rep.TargetType, rep.TargetID, rep.Reason)
	return err
}
