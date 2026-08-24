#!/usr/bin/env bash
# ============================================================
# e2e-smoke.sh — 部署后端到端冒烟测试（固化进仓库）
#
# 验证已部署后端的核心链路：发码 → 注册/登录 → 发布 → 广场 → 确认。
# 用于 CD 后置验证或本地手动 smoke。测试数据使用 e2e_smoke_ 前缀，
# 清理时仅删除该前缀，避免误伤真实/demo 数据。
#
# 用法:
#   ./scripts/e2e-smoke.sh [base-url]      # 默认 http://127.0.0.1:8080
#   ./scripts/e2e-smoke.sh https://api.gotseeker.com
# ============================================================
set -uo pipefail

BASE="${1:-http://127.0.0.1:8080}"
TS="$(date +%s)"
EMAIL="e2e_smoke_${TS}@gotseeker.com"
PASS="SmokeTest123!"
PASSPORT="+8613800000000"

pass=0; fail=0
check() { # desc, condition
  if [ "$2" = "0" ]; then echo "  [PASS] $1"; pass=$((pass+1)); else echo "  [FAIL] $1"; fail=$((fail+1)); fi
}

echo "==> 目标: $BASE  测试邮箱: $EMAIL"

# 1. healthz
code=$(curl -s -o /tmp/h.txt -w '%{http_code}' "$BASE/healthz"); cat /tmp/h.txt; echo
check "healthz 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
VER=$(grep -o '"version":"[^"]*"' /tmp/h.txt | cut -d'"' -f4)
echo "    线上版本: ${VER:-unknown}"

# 2. 发码
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/auth/send-code" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"country_code\":\"CN\",\"phone\":\"$PASSPORT\"}")
check "send-code 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

# 3. 取验证码（依赖部署环境 CODE_STORE=redis；redis key 前缀 seeker:code:<email>）
#    优先用 docker redis 容器取（HK 部署场景），兜底本机 redis-cli，再兜底手动输入
CODE=""
RAW=""
if command -v docker >/dev/null 2>&1; then
  RAW=$(docker exec bountyapp-redis redis-cli get "seeker:code:$EMAIL" 2>/dev/null | tr -d '\r' || true)
fi
if [ -z "$RAW" ] && command -v redis-cli >/dev/null 2>&1; then
  RAW=$(redis-cli --no-auth-warning get "seeker:code:$EMAIL" 2>/dev/null | tr -d '\r' || true)
fi
# redis 中存的是 JSON: {"code":"123456","exp":...}，需提取纯数字验证码
if [ -n "$RAW" ]; then
  CODE=$(echo "$RAW" | grep -o '"code":"[0-9]*"' | head -1 | cut -d'"' -f4)
fi
if [ -z "$CODE" ]; then
  echo "  [INFO] 无法自动获取验证码（非 HK 本机/无 redis）。"
  echo -n "  请手动输入验证码: "; read -r CODE
fi
[ -n "$CODE" ] || { echo "  [SKIP] 无验证码，后续步骤跳过"; exit 0; }

# 4. 注册/登录拿 token（端点为 /auth/login，需 device_id）
resp=$(curl -s -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"device_id\":\"e2e-smoke-$TS\"}")
TOKEN=$(echo "$resp" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4)
check "login 返回 token" "$([ -n "$TOKEN" ] && echo 0 || echo 1)"
echo "    $resp" | head -c 200; echo

# 5. 发布任务
TITLE="smoke_$TS"
pub=$(curl -s -X POST "$BASE/api/v1/tasks" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"title\":\"$TITLE\",\"description\":\"e2e smoke\",\"bounty\":10,\"currency\":\"CNY\",\"lat\":22.3,\"lng\":114.2,\"radius\":5000}")
TID=$(echo "$pub" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
check "发布任务成功" "$([ -n "$TID" ] && echo 0 || echo 1)"
echo "    task_id=$TID"

# 6. 广场可见
sq=$(curl -s "$BASE/api/v1/tasks/square?lat=22.3&lng=114.2&radius=10000")
check "广场返回数据" "$(echo "$sq" | grep -q "$TITLE" && echo 0 || echo 1)"

# 7. 取消任务（验证 abandon 链路）
cc=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$TID/cancel" -H "Authorization: Bearer $TOKEN")
check "cancel 200" "$([ "$cc" = "200" ] && echo 0 || echo 1)"

echo ""
echo "==> 冒烟结果: PASS=$pass FAIL=$fail"
[ "$fail" = "0" ] && exit 0 || exit 1
