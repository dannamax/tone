#!/usr/bin/env bash
# SeekerHub 运营数据速览 — 在 HK 服务器执行: bash /opt/bountyapp/scripts/stats.sh
# 注意: 时间戳均为 UTC（北京时间 +8）
set -e
DB=/var/lib/docker/volumes/deploy_appdata/_data/seekerdb.sqlite

echo "==== 用户 ===="
sqlite3 -header -column "$DB" "
SELECT COUNT(*) AS total_users,
       SUM(CASE WHEN created_at >= datetime('now','-1 day') THEN 1 ELSE 0 END) AS new_24h,
       SUM(CASE WHEN created_at >= datetime('now','-7 day') THEN 1 ELSE 0 END) AS new_7d
FROM users;"

echo "==== 任务（按状态）===="
sqlite3 -header -column "$DB" "
SELECT status, COUNT(*) AS count FROM tasks GROUP BY status;"

echo "==== 金豆流水（按类型）===="
sqlite3 -header -column "$DB" "
SELECT tx_type, COUNT(*) AS count, ROUND(SUM(amount),1) AS beans_total
FROM transactions GROUP BY tx_type;"

echo "==== 充值订单 ===="
sqlite3 -header -column "$DB" "
SELECT status, channel, COUNT(*) AS orders,
       ROUND(SUM(amount),2) AS amount
FROM recharge_orders GROUP BY status, channel;"

echo "==== 推送设备（≈装机量）===="
sqlite3 -header -column "$DB" "SELECT COUNT(*) AS devices FROM device_tokens;"

echo "==== 最近注册（最新10条）===="
sqlite3 -header -column "$DB" "
SELECT email, created_at FROM users ORDER BY created_at DESC LIMIT 10;"

echo "==== 快照时间(UTC): $(date -u '+%F %T') ===="
