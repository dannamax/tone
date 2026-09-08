package handler

import (
	"database/sql"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"seeker/pkg/response"
)

// AdminStatsHandler 只读运营统计接口（对应 scripts/stats.sh 的全部口径）。
// 通过独立静态令牌（X-Admin-Token）鉴权，与用户 JWT 体系完全解耦；
// 未配置 ADMIN_API_TOKEN 时端点自动禁用（见 middleware.AdminTokenMiddleware）。
// 该接口为纯新增路由，不影响 App 现有使用的任何接口与数据库 schema。
type AdminStatsHandler struct {
	db *sql.DB
}

func NewAdminStatsHandler(db *sql.DB) *AdminStatsHandler {
	return &AdminStatsHandler{db: db}
}

// MaskEmail 邮箱脱敏：本地部分仅保留首字符，如 "alice@mail.com" -> "a***@mail.com"。
func MaskEmail(email string) string {
	at := strings.Index(email, "@")
	if at <= 0 {
		return "***"
	}
	return email[:1] + "***" + email[at:]
}

// GetStats GET /api/v1/admin/stats?mask=1
// 返回用户/任务/金豆流水/充值订单/推送设备/最近注册等只读统计。
// 时间条件使用参数化 UTC 时间，SQLite 与 PostgreSQL 双方言兼容。
func (h *AdminStatsHandler) GetStats(c *gin.Context) {
	mask := c.Query("mask") == "1"
	since24h := time.Now().UTC().Add(-24 * time.Hour).Format("2006-01-02 15:04:05")
	since7d := time.Now().UTC().Add(-7 * 24 * time.Hour).Format("2006-01-02 15:04:05")
	out := gin.H{"generated_at": time.Now().UTC().Format(time.RFC3339)}

	// ---- 用户 ----
	var totalUsers, new24h, new7d int
	_ = h.db.QueryRow(`SELECT COUNT(*),
		COALESCE(SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END), 0),
		COALESCE(SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END), 0)
		FROM users`, since24h, since7d).Scan(&totalUsers, &new24h, &new7d)
	out["users"] = gin.H{"total": totalUsers, "new_24h": new24h, "new_7d": new7d}

	// ---- 任务（按状态）----
	out["tasks"] = gin.H{"by_status": h.pairCounts(
		`SELECT COALESCE(status, ''), COUNT(*) FROM tasks GROUP BY status`)}

	// ---- 金豆流水（按类型）----
	out["transactions"] = gin.H{"by_type": h.txByType()}

	// ---- 充值订单（按状态+渠道）----
	out["recharge_orders"] = gin.H{"by_status": h.rechargeByStatus()}

	// ---- 推送设备（≈装机量）----
	var devices int
	_ = h.db.QueryRow(`SELECT COUNT(*) FROM device_tokens`).Scan(&devices)
	out["push_devices"] = devices

	// ---- 最近注册（最新 10 条）----
	type registration struct {
		Email     string `json:"email"`
		CreatedAt string `json:"created_at"`
	}
	regs := []registration{}
	rows, err := h.db.Query(`SELECT email, created_at FROM users ORDER BY created_at DESC LIMIT 10`)
	if err == nil {
		for rows.Next() {
			var r registration
			if err := rows.Scan(&r.Email, &r.CreatedAt); err == nil {
				if mask {
					r.Email = MaskEmail(r.Email)
				}
				regs = append(regs, r)
			}
		}
		_ = rows.Err() // 统计接口：迭代中止时返回已收集的部分数据即可
		rows.Close()
	}
	out["recent_registrations"] = regs

	response.Success(c, out)
}

// pairCounts 通用分组计数（文本列 + 计数），空结果返回空数组。
func (h *AdminStatsHandler) pairCounts(query string) []gin.H {
	result := []gin.H{}
	rows, err := h.db.Query(query)
	if err != nil {
		return result
	}
	defer rows.Close()
	for rows.Next() {
		var k string
		var v int
		if err := rows.Scan(&k, &v); err == nil {
			result = append(result, gin.H{"key": k, "count": v})
		}
	}
	_ = rows.Err()
	return result
}

// txByType 金豆流水按类型聚合（笔数 + 金豆合计）。
func (h *AdminStatsHandler) txByType() []gin.H {
	result := []gin.H{}
	rows, err := h.db.Query(
		`SELECT tx_type, COUNT(*), ROUND(SUM(amount), 1) FROM transactions GROUP BY tx_type`)
	if err != nil {
		return result
	}
	defer rows.Close()
	for rows.Next() {
		var txType string
		var count int
		var beans sql.NullFloat64
		if err := rows.Scan(&txType, &count, &beans); err == nil {
			result = append(result, gin.H{
				"type": txType, "count": count, "beans": beans.Float64,
			})
		}
	}
	_ = rows.Err()
	return result
}

// rechargeByStatus 充值订单按状态 + 渠道聚合（订单数 + 金额合计）。
func (h *AdminStatsHandler) rechargeByStatus() []gin.H {
	result := []gin.H{}
	rows, err := h.db.Query(
		`SELECT status, channel, COUNT(*), ROUND(SUM(amount), 2) FROM recharge_orders GROUP BY status, channel`)
	if err != nil {
		return result
	}
	defer rows.Close()
	for rows.Next() {
		var status, channel string
		var orders int
		var amount sql.NullFloat64
		if err := rows.Scan(&status, &channel, &orders, &amount); err == nil {
			result = append(result, gin.H{
				"status": status, "channel": channel,
				"orders": orders, "amount": amount.Float64,
			})
		}
	}
	_ = rows.Err()
	return result
}
