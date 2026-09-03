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

// ErrQuotaInsufficient 金豆不足
var ErrQuotaInsufficient = errors.New("insufficient beans")

type UserRepo struct {
	db *sql.DB
}

func NewUserRepo(db *sql.DB) *UserRepo {
	return &UserRepo{db: db}
}

const userCols = `id, email, nickname, avatar, device_id, balance, frozen_balance, total_earned, total_spent, beans_purchased, beans_earned, created_at, updated_at`

func scanUser(row interface{ Scan(dest ...interface{}) error }) (*model.User, error) {
	u := &model.User{}
	err := row.Scan(
		&u.ID, &u.Email, &u.Nickname, &u.Avatar, &u.DeviceID,
		&u.Balance, &u.FrozenBal, &u.TotalEarned, &u.TotalSpent,
		&u.BeansPurchased, &u.BeansEarned,
		&u.CreatedAt, &u.UpdatedAt,
	)
	return u, err
}

func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*model.User, error) {
	u, err := scanUser(r.db.QueryRowContext(ctx, `SELECT `+userCols+` FROM users WHERE email = ?`, email))
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return u, err
}

func (r *UserRepo) FindByID(ctx context.Context, id string) (*model.User, error) {
	u, err := scanUser(r.db.QueryRowContext(ctx, `SELECT `+userCols+` FROM users WHERE id = ?`, id))
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
	// 注册礼金豆由代码显式发放（model.FreeBeans），不依赖 DB 列默认值：
	// 线上旧库 beans_purchased 列默认值仍是 3（早期版本所建，ALTER 无法修改），
	// 依赖默认值会导致新用户拿 3 豆而无法发布最低 5 豆的任务。
	query := `INSERT INTO users (id, email, nickname, avatar, device_id, beans_purchased) VALUES (?, ?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query, id, email, nickname, "default", deviceID, model.FreeBeans)
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

// UpdateNickname 更新用户昵称，空字符串会被过滤
func (r *UserRepo) UpdateNickname(ctx context.Context, userID, nickname string) error {
	if strings.TrimSpace(nickname) == "" {
		return fmt.Errorf("nickname cannot be empty")
	}
	query := `UPDATE users SET nickname = ?, updated_at = ? WHERE id = ?`
	_, err := r.db.ExecContext(ctx, query, nickname, time.Now(), userID)
	return err
}

// UpdateBalance 遗留钱包余额账务（提现/历史数据兼容），金豆体系不使用
func (r *UserRepo) UpdateBalance(ctx context.Context, userID string, balanceDelta, frozenDelta, totalSpentDelta, totalEarnedDelta float64) error {
	query := `UPDATE users SET balance = balance + ?, frozen_balance = frozen_balance + ?, total_spent = total_spent + ?, total_earned = total_earned + ?, updated_at = ? WHERE id = ?`

	_, err := r.db.ExecContext(ctx, query, balanceDelta, frozenDelta, totalSpentDelta, totalEarnedDelta, time.Now(), userID)
	return err
}

// DecBeans 原子消耗金豆：先扣 beans_purchased，不足部分再扣 beans_earned。
// 总额不足返回 ErrQuotaInsufficient。
func (r *UserRepo) DecBeans(ctx context.Context, userID string, n int) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE users SET
			beans_purchased = beans_purchased - MIN(beans_purchased, ?),
			beans_earned = beans_earned - (? - MIN(beans_purchased, ?)),
			updated_at = ?
		WHERE id = ? AND (beans_purchased + beans_earned) >= ?`,
		n, n, n, time.Now(), userID, n)
	if err != nil {
		return err
	}
	if affected, _ := res.RowsAffected(); affected == 0 {
		return ErrQuotaInsufficient
	}
	return nil
}

// AddBeans 发放金豆：earned=true 记入 beans_earned（任务奖励，V2 可提现）；
// 否则记入 beans_purchased（IAP 充值、退款返还、注册礼）。
func (r *UserRepo) AddBeans(ctx context.Context, userID string, n int, earned bool) error {
	col := "beans_purchased"
	if earned {
		col = "beans_earned"
	}
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET `+col+` = `+col+` + ?, updated_at = ? WHERE id = ?`, n, time.Now(), userID)
	return err
}

// DeleteCascade 彻底删除账户：个人关联数据 + 用户记录（GDPR / 审核合规）。
// 前置条件：进行中任务检查与任务级联删除已由 AccountService 完成。
func (r *UserRepo) DeleteCascade(ctx context.Context, userID string) error {
	// 1) 取 email（删验证码记录用）
	var email string
	if err := r.db.QueryRowContext(ctx, `SELECT email FROM users WHERE id = ?`, userID).Scan(&email); err != nil {
		return err
	}
	// 2) 删除个人关联数据（含他在别人任务下的提交证据与聊天消息，
	//    这些行带 REFERENCES users(id) 外键，不清会导致删用户失败）
	for _, q := range []struct {
		sql  string
		args []interface{}
	}{
		{`DELETE FROM notifications WHERE user_id = ?`, []interface{}{userID}},
		{`DELETE FROM transactions WHERE from_user_id = ? OR to_user_id = ?`, []interface{}{userID, userID}},
		{`DELETE FROM recharge_orders WHERE user_id = ?`, []interface{}{userID}},
		{`DELETE FROM submissions WHERE claimer_id = ?`, []interface{}{userID}},
		{`DELETE FROM task_messages WHERE sender_id = ?`, []interface{}{userID}},
		// 他在别人任务下的接单记录：置空而非删行（发布人的历史任务保留，
		// 前置检查已保证无进行中任务，此处只可能是终态任务）
		{`UPDATE tasks SET claimer_id = NULL WHERE claimer_id = ?`, []interface{}{userID}},
		{`DELETE FROM email_codes WHERE email = ?`, []interface{}{email}},
		// 应用层级联：举报与拉黑记录（表无 FK，但孤儿数据会造成引用残留）
		{`DELETE FROM content_reports WHERE reporter_id = ?`, []interface{}{userID}},
		{`DELETE FROM user_blocks WHERE blocker_id = ? OR blocked_id = ?`, []interface{}{userID, userID}},
	} {
		if _, err := r.db.ExecContext(ctx, q.sql, q.args...); err != nil {
			return err
		}
	}
	// 3) 删除用户记录本身
	res, err := r.db.ExecContext(ctx, `DELETE FROM users WHERE id = ?`, userID)
	if err != nil {
		return err
	}
	if affected, _ := res.RowsAffected(); affected == 0 {
		return fmt.Errorf("user not found")
	}
	return nil
}
