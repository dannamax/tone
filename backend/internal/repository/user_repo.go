package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"seeker/internal/model"
	"seeker/pkg/i18n"

	"github.com/google/uuid"
)

// ErrQuotaInsufficient 发布额度不足
var ErrQuotaInsufficient = errors.New("insufficient publish quota")

type UserRepo struct {
	db *sql.DB
}

func NewUserRepo(db *sql.DB) *UserRepo {
	return &UserRepo{db: db}
}

func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*model.User, error) {
	query := `SELECT id, email, nickname, avatar, device_id, balance, frozen_balance, publish_quota, used_quota, created_at, updated_at 
			  FROM users WHERE email = ?`
	u := &model.User{}
	err := r.db.QueryRowContext(ctx, query, email).Scan(
		&u.ID, &u.Email, &u.Nickname, &u.Avatar, &u.DeviceID,
		&u.Balance, &u.FrozenBal, &u.PublishQuota, &u.UsedQuota,
		&u.CreatedAt, &u.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return u, err
}

func (r *UserRepo) FindByID(ctx context.Context, id string) (*model.User, error) {
	query := `SELECT id, email, nickname, avatar, device_id, balance, frozen_balance, publish_quota, used_quota, created_at, updated_at 
			  FROM users WHERE id = ?`
	u := &model.User{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&u.ID, &u.Email, &u.Nickname, &u.Avatar, &u.DeviceID,
		&u.Balance, &u.FrozenBal, &u.PublishQuota, &u.UsedQuota,
		&u.CreatedAt, &u.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return u, err
}

func (r *UserRepo) CreateByEmail(ctx context.Context, email, deviceID string) (*model.User, error) {
	local := email
	if at := strings.Index(email, "@"); at > 0 {
		local = email[:at]
	}
	nickname := fmt.Sprintf(i18n.T(i18n.LangEN, "default_nickname"), local)
	id := uuid.NewString()
	query := `INSERT INTO users (id, email, nickname, avatar, device_id) VALUES (?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query, id, email, nickname, "default", deviceID)
	if err != nil {
		return nil, err
	}
	return r.FindByID(ctx, id)
}

func (r *UserRepo) UpdateDevice(ctx context.Context, userID, deviceID string) error {
	query := `UPDATE users SET device_id = ?, updated_at = ? WHERE id = ?`
	_, err := r.db.ExecContext(ctx, query, deviceID, time.Now(), userID)
	return err
}

func (r *UserRepo) UpdateBalance(ctx context.Context, userID string, balanceDelta, frozenDelta float64) error {
	query := `UPDATE users SET balance = balance + ?, frozen_balance = frozen_balance + ?, updated_at = ? WHERE id = ?`
	
   _, err := r.db.ExecContext(ctx, query, balanceDelta, frozenDelta, time.Now(), userID)
	return err
}

// DecQuota 原子消耗发布额度；额度不足返回 ErrQuotaInsufficient
func (r *UserRepo) DecQuota(ctx context.Context, userID string, n int) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE users SET publish_quota = publish_quota - ?, used_quota = used_quota + ?, updated_at = ? 
		 WHERE id = ? AND publish_quota >= ?`, n, n, time.Now(), userID, n)
	if err != nil {
		return err
	}
	if affected, _ := res.RowsAffected(); affected == 0 {
		return ErrQuotaInsufficient
	}
	return nil
}

// AddQuota 发放发布额度（充值成功时调用）
func (r *UserRepo) AddQuota(ctx context.Context, userID string, n int) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET publish_quota = publish_quota + ?, updated_at = ? WHERE id = ?`, n, time.Now(), userID)
	return err
}
