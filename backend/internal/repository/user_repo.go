package repository

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"seeker/internal/model"
	"seeker/pkg/i18n"

	"github.com/google/uuid"
)

type UserRepo struct {
	db *sql.DB
}

func NewUserRepo(db *sql.DB) *UserRepo {
	return &UserRepo{db: db}
}

func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*model.User, error) {
	query := `SELECT id, email, nickname, avatar, device_id, balance, frozen_balance, created_at, updated_at 
			  FROM users WHERE email = ?`
	u := &model.User{}
	err := r.db.QueryRowContext(ctx, query, email).Scan(
		&u.ID, &u.Email, &u.Nickname, &u.Avatar, &u.DeviceID,
		&u.Balance, &u.FrozenBal, &u.CreatedAt, &u.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return u, err
}

func (r *UserRepo) FindByID(ctx context.Context, id string) (*model.User, error) {
	query := `SELECT id, email, nickname, avatar, device_id, balance, frozen_balance, created_at, updated_at 
			  FROM users WHERE id = ?`
	u := &model.User{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&u.ID, &u.Email, &u.Nickname, &u.Avatar, &u.DeviceID,
		&u.Balance, &u.FrozenBal, &u.CreatedAt, &u.UpdatedAt,
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
