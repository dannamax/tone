package repository

import (
	"context"
	"database/sql"

	"seeker/internal/model"

	"github.com/google/uuid"
)

// nullString 将 *string 转为 sql.NullString，nil 表示数据库 NULL。
func nullString(s *string) sql.NullString {
	if s == nil {
		return sql.NullString{}
	}
	return sql.NullString{String: *s, Valid: true}
}

type TransactionRepo struct {
	db *sql.DB
}

func NewTransactionRepo(db *sql.DB) *TransactionRepo {
	return &TransactionRepo{db: db}
}

func (r *TransactionRepo) Create(ctx context.Context, t *model.Transaction) (*model.Transaction, error) {
	t.ID = uuid.NewString()
	query := `INSERT INTO transactions (id, task_id, from_user_id, to_user_id, amount, fee, tx_type, tx_status, remark, order_id, beans_delta)
			  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query,
		t.ID, nullString(t.TaskID), t.FromUserID, t.ToUserID, t.Amount, t.Fee, t.Type, t.Status, t.Remark,
		nullString(t.OrderID), t.BeansDelta,
	)
	if err != nil {
		return nil, err
	}
	return t, nil
}

func (r *TransactionRepo) FindByUser(ctx context.Context, userID string, page, size int) ([]model.Transaction, int64, error) {
	countQuery := `SELECT COUNT(*) FROM transactions WHERE from_user_id = ? OR to_user_id = ?`
	var total int64
	if err := r.db.QueryRowContext(ctx, countQuery, userID, userID).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `SELECT id, task_id, from_user_id, to_user_id, amount, fee, tx_type, tx_status, remark, created_at 
			  FROM transactions WHERE from_user_id = ? OR to_user_id = ? 
			  ORDER BY created_at DESC LIMIT ? OFFSET ?`

	rows, err := r.db.QueryContext(ctx, query, userID, userID, size, (page-1)*size)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var txs []model.Transaction
	for rows.Next() {
		var t model.Transaction
		var taskIDNS sql.NullString
		if err := rows.Scan(
			&t.ID, &taskIDNS, &t.FromUserID, &t.ToUserID,
			&t.Amount, &t.Fee, &t.Type, &t.Status, &t.Remark, &t.CreatedAt,
		); err != nil {
			return nil, 0, err
		}
		if taskIDNS.Valid {
			v := taskIDNS.String
			t.TaskID = &v
		}
		txs = append(txs, t)
	}
	return txs, total, nil
}

// UnlinkTask 任务删除前解除流水与任务的关联（task_id 置 NULL）。
// 金豆流水是账本必须保留，仅切断外键引用，remark 中仍保留任务标题文字。
func (r *TransactionRepo) UnlinkTask(ctx context.Context, taskID string) error {
	_, err := r.db.ExecContext(ctx, `UPDATE transactions SET task_id = NULL WHERE task_id = ?`, taskID)
	return err
}

func (r *TransactionRepo) FindByTask(ctx context.Context, taskID string) ([]model.Transaction, error) {
	query := `SELECT id, task_id, from_user_id, to_user_id, amount, fee, tx_type, tx_status, remark, created_at 
			  FROM transactions WHERE task_id = ? ORDER BY created_at`
	rows, err := r.db.QueryContext(ctx, query, taskID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var txs []model.Transaction
	for rows.Next() {
		var t model.Transaction
		var taskIDNS sql.NullString
		if err := rows.Scan(
			&t.ID, &taskIDNS, &t.FromUserID, &t.ToUserID,
			&t.Amount, &t.Fee, &t.Type, &t.Status, &t.Remark, &t.CreatedAt,
		); err != nil {
			return nil, err
		}
		if taskIDNS.Valid {
			v := taskIDNS.String
			t.TaskID = &v
		}
		txs = append(txs, t)
	}
	return txs, nil
}
