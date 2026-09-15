package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"seeker/internal/model"

	"github.com/google/uuid"
)

type RechargeRepo struct {
	db *sql.DB
}

func NewRechargeRepo(db *sql.DB) *RechargeRepo {
	return &RechargeRepo{db: db}
}

// Create 新建金豆充值订单
func (r *RechargeRepo) Create(ctx context.Context, o *model.RechargeOrder) (*model.RechargeOrder, error) {
	id := uuid.NewString()
	o.ID = id
	o.Status = model.OrderStatusCreated
	o.CreatedAt = time.Now()
	query := `INSERT INTO recharge_orders (id, user_id, package_id, channel, amount, currency, beans_granted, status, gateway_order_id, receipt_data, created_at)
			  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
	_, err := r.db.ExecContext(ctx, query,
		o.ID, o.UserID, o.PackageID, o.Channel, o.Amount, o.Currency, o.BeansGranted, o.Status, o.GatewayOrderID, o.ReceiptData, o.CreatedAt)
	if err != nil {
		return nil, err
	}
	return o, nil
}

// FindByID 按商户订单号查询
func (r *RechargeRepo) FindByID(ctx context.Context, id string) (*model.RechargeOrder, error) {
	o := &model.RechargeOrder{}
	query := `SELECT id, user_id, package_id, channel, amount, currency, beans_granted, status, gateway_order_id, receipt_data, paid_at, created_at
			  FROM recharge_orders WHERE id = ?`
	var paidAt sql.NullTime
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&o.ID, &o.UserID, &o.PackageID, &o.Channel, &o.Amount, &o.Currency, &o.BeansGranted, &o.Status, &o.GatewayOrderID, &o.ReceiptData, &paidAt, &o.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if paidAt.Valid {
		v := paidAt.Time
		o.PaidAt = &v
	}
	return o, nil
}

// FindByGateway 按渠道+支付机构订单号查询（幂等查重用）
func (r *RechargeRepo) FindByGateway(ctx context.Context, channel, gatewayOrderID string) (*model.RechargeOrder, error) {
	o := &model.RechargeOrder{}
	query := `SELECT id, user_id, package_id, channel, amount, currency, beans_granted, status, gateway_order_id, receipt_data, paid_at, created_at
			  FROM recharge_orders WHERE channel = ? AND gateway_order_id = ?`
	var paidAt sql.NullTime
	err := r.db.QueryRowContext(ctx, query, channel, gatewayOrderID).Scan(
		&o.ID, &o.UserID, &o.PackageID, &o.Channel, &o.Amount, &o.Currency, &o.BeansGranted, &o.Status, &o.GatewayOrderID, &o.ReceiptData, &paidAt, &o.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if paidAt.Valid {
		v := paidAt.Time
		o.PaidAt = &v
	}
	return o, nil
}

// FindOldestCreated 找用户在某套餐下最早一笔未支付订单。
// 恢复购买场景：用户已付款但 confirm 中断（gateway_order_id 仍为空），
// 用历史交易按 product_id 关联到该订单补发。
func (r *RechargeRepo) FindOldestCreated(ctx context.Context, userID, packageID string) (*model.RechargeOrder, error) {
	o := &model.RechargeOrder{}
	query := `SELECT id, user_id, package_id, channel, amount, currency, beans_granted, status, gateway_order_id, receipt_data, paid_at, created_at
			  FROM recharge_orders WHERE user_id = ? AND package_id = ? AND status = ?
			  ORDER BY created_at ASC LIMIT 1`
	var paidAt sql.NullTime
	err := r.db.QueryRowContext(ctx, query, userID, packageID, model.OrderStatusCreated).Scan(
		&o.ID, &o.UserID, &o.PackageID, &o.Channel, &o.Amount, &o.Currency, &o.BeansGranted, &o.Status, &o.GatewayOrderID, &o.ReceiptData, &paidAt, &o.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return o, nil
}

// MarkPaid 幂等标记订单为已支付并发放金豆。
// 仅当订单处于 created 时才切换并加豆；已 paid 则直接返回成功（重复通知安全）。
func (r *RechargeRepo) MarkPaid(ctx context.Context, id, gatewayOrderID string, beansGranted int, addBeans func(ctx context.Context, userID string, n int) error) (*model.RechargeOrder, error) {
	o, err := r.FindByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if o == nil {
		return nil, ErrOrderNotFound
	}

	// 已支付：幂等返回，不再重复发放金豆
	if o.Status == model.OrderStatusPaid {
		return o, nil
	}

	// 乐观锁：仅 created -> paid 切换，避免并发重复发放
	res, err := r.db.ExecContext(ctx,
		`UPDATE recharge_orders SET status = ?, gateway_order_id = ?, beans_granted = ?, paid_at = ?
		 WHERE id = ? AND status = ?`,
		model.OrderStatusPaid, gatewayOrderID, beansGranted, time.Now(), id, model.OrderStatusCreated)
	if err != nil {
		return nil, err
	}
	if affected, _ := res.RowsAffected(); affected == 0 {
		o2, err := r.FindByID(ctx, id)
		if err != nil {
			return nil, err
		}
		if o2 != nil && o2.Status == model.OrderStatusPaid {
			return o2, nil
		}
		return nil, ErrOrderConflict
	}

	// 发放金豆（进 beans_purchased）
	if err := addBeans(ctx, o.UserID, beansGranted); err != nil {
		return nil, err
	}
	o.Status = model.OrderStatusPaid
	o.GatewayOrderID = gatewayOrderID
	o.BeansGranted = beansGranted
	t := time.Now()
	o.PaidAt = &t
	return o, nil
}

// ReportFailure 记录支付失败/取消原因（支付漏斗可观测性）。
// 仅当订单处于 created 时才更新为 failed；paid 订单不允许被客户端上报篡改。
func (r *RechargeRepo) ReportFailure(ctx context.Context, id, userID, stage, code, reason string) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE recharge_orders SET status = ?, fail_stage = ?, fail_code = ?, fail_reason = ?
		 WHERE id = ? AND user_id = ? AND status = ?`,
		model.OrderStatusFailed, stage, code, reason, id, userID, model.OrderStatusCreated)
	if err != nil {
		return err
	}
	if affected, _ := res.RowsAffected(); affected == 0 {
		return ErrOrderConflict
	}
	return nil
}

// ErrOrderNotFound / ErrOrderConflict 订单查询与并发错误
var ErrOrderNotFound = errors.New("recharge order not found")
var ErrOrderConflict = errors.New("recharge order status conflict")
