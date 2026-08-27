package repository

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
)

// DeviceTokenRepo APNs 设备 token 存储
type DeviceTokenRepo struct {
	db *sql.DB
}

func NewDeviceTokenRepo(db *sql.DB) *DeviceTokenRepo {
	return &DeviceTokenRepo{db: db}
}

// Upsert 登记设备 token（同一 token 更新归属用户；换账号登录后通知发新账号）
func (r *DeviceTokenRepo) Upsert(ctx context.Context, userID, token, platform string) error {
	query := `INSERT INTO device_tokens (id, user_id, token, platform, updated_at)
			  VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
			  ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id, updated_at = CURRENT_TIMESTAMP`
	_, err := r.db.ExecContext(ctx, query, uuid.NewString(), userID, token, platform)
	return err
}

// FindByUser 列出用户全部设备的推送 token
func (r *DeviceTokenRepo) FindByUser(ctx context.Context, userID string) ([]string, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT token FROM device_tokens WHERE user_id = ? ORDER BY updated_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

// Delete 删除失效的设备 token（APNs 410）
func (r *DeviceTokenRepo) Delete(ctx context.Context, token string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM device_tokens WHERE token = ?`, token)
	return err
}

// DeleteByUser 账户删除时清理全部设备登记
func (r *DeviceTokenRepo) DeleteByUser(ctx context.Context, userID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM device_tokens WHERE user_id = ?`, userID)
	return err
}
