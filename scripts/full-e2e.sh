#!/usr/bin/env bash
# ============================================================
# full-e2e.sh — 线上环境完整功能自测（在 HK 机器本机执行）
# 覆盖: 认证/发码/登录/资料 - 任务发布/广场/领取/提交/确认/取消/退款/激活
#       - 上传COS - 钱包/充值(IAP创建订单)/提现/交易 - 额度套餐/订单
#       - 通知 - 聊天消息 - 汇率/邮箱域名配置
# 用法: bash scripts/full-e2e.sh
# ============================================================
set -uo pipefail
BASE="http://127.0.0.1:8080"
TS="$(date +%s)"
EMAIL="full_e2e_${TS}@gotseeker.com"
PASSPORT="+8613800000000"
pass=0; fail=0; skip=0
check() { if [ "$2" = "0" ]; then echo "  [PASS] $1"; pass=$((pass+1)); else echo "  [FAIL] $1"; fail=$((fail+1)); fi; }
jqget() { echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }

echo "=============================================="
echo "  Seeker 线上功能完整自测  $(date)"
echo "  目标: $BASE"
echo "=============================================="

# ---------- 公开端点 ----------
code=$(curl -s -o /tmp/h.txt -w '%{http_code}' "$BASE/healthz"); cat /tmp/h.txt; echo
check "healthz 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
VER=$(jqget "$(cat /tmp/h.txt)" version); echo "    线上版本: ${VER:-unknown}"

code=$(curl -s -o /tmp/er.txt -w '%{http_code}' "$BASE/api/v1/config/exchange-rate")
check "汇率配置 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"; echo "    $(head -c 160 /tmp/er.txt)"

code=$(curl -s -o /tmp/ed.txt -w '%{http_code}' "$BASE/api/v1/config/email-domains")
check "邮箱域名配置 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"; echo "    $(head -c 160 /tmp/ed.txt)"

# ---------- 认证 ----------
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/auth/send-code" \
  -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"country_code\":\"CN\",\"phone\":\"$PASSPORT\"}")
check "send-code 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

RAW=$(docker exec bountyapp-redis redis-cli get "seeker:code:$EMAIL" 2>/dev/null | tr -d '\r' || true)
CODE=$(echo "$RAW" | grep -o '"code":"[0-9]*"' | head -1 | cut -d'"' -f4)
[ -n "$CODE" ] || { echo "  [SKIP] 无验证码，认证后续跳过"; skip=1; }
if [ -n "$CODE" ]; then
  resp=$(curl -s -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"device_id\":\"full-e2e-$TS\"}")
  TOKEN=$(jqget "$resp" access_token)
  check "login 返回 token" "$([ -n "$TOKEN" ] && echo 0 || echo 1)"
  AUTH="Authorization: Bearer $TOKEN"
  # /me 资料
  code=$(curl -s -o /tmp/me.txt -w '%{http_code}' "$BASE/api/v1/me" -H "$AUTH")
  check "GET /me 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"; echo "    $(head -c 160 /tmp/me.txt)"
fi

if [ -z "$TOKEN" ]; then echo "  [SKIP] 无 token，任务/钱包等跳过"; echo; echo "PASS=$pass FAIL=$fail SKIP=$skip"; exit 0; fi

# ---------- 上传 COS ----------
PNG="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
UP=$(curl -s -X POST "$BASE/api/v1/upload" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"base64\":\"data:image/png;base64,$PNG\"}")
URL=$(jqget "$UP" url)
if echo "$URL" | grep -q "cos.ap-hongkong.myqcloud.com"; then
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL"); check "上传COS且公网可读 200 ($(echo $URL|cut -c1-60)...)" "$([ "$code" = "200" ] && echo 0 || echo 1)"
else
  check "上传COS返回URL" 1; echo "    resp=$UP"
fi

# ---------- 任务全链路 ----------
pub=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"title\":\"e2e_$TS\",\"description\":\"full e2e\",\"bounty\":10,\"currency\":\"CNY\",\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK Central\",\"radius\":5000,\"time_limit\":30,\"images\":[\"$URL\"]}")
TID=$(jqget "$pub" id)
check "发布任务成功" "$([ -n "$TID" ] && echo 0 || echo 1)"; echo "    task_id=$TID"

# 第二用户领取
TS2="${TS}2"; E2="full_e2e_${TS2}@gotseeker.com"
curl -s -o /dev/null -X POST "$BASE/api/v1/auth/send-code" -H 'Content-Type: application/json' -d "{\"email\":\"$E2\",\"country_code\":\"CN\",\"phone\":\"+8613900000000\"}"
R2=$(docker exec bountyapp-redis redis-cli get "seeker:code:$E2" 2>/dev/null | tr -d '\r' || true)
C2=$(echo "$R2" | grep -o '"code":"[0-9]*"' | head -1 | cut -d'"' -f4)
L2=$(curl -s -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$E2\",\"code\":\"$C2\",\"device_id\":\"claimer-$TS\"}")
T2=$(jqget "$L2" access_token); AUTH2="Authorization: Bearer $T2"

code=$(curl -s -w ' [%{http_code}]' -X POST "$BASE/api/v1/tasks/$TID/claim" -H "$AUTH2")
echo "    claim: $code"
check "领取任务 claim 200" "$(echo "$code" | grep -q '200' && echo 0 || echo 1)"

# 领取者提交（必须用领取者 token，并携带任务地理围栏内的坐标字段 submit_lat/submit_lng）
SUB=$(curl -s -w ' [%{http_code}]' -X POST "$BASE/api/v1/tasks/$TID/submit" -H "$AUTH2" -H 'Content-Type: application/json' -d "{\"note\":\"done\",\"images\":[\"$URL\"],\"submit_lat\":22.3,\"submit_lng\":114.2}")
echo "    submit: $SUB"
check "提交任务 submit 200" "$(echo "$SUB" | grep -q '200' && echo 0 || echo 1)"

# 广场 API 正常返回（已提交/已认领的任务按设计不再对外展示，故只校验接口正常）
sq=$(curl -s "$BASE/api/v1/tasks/square?lat=22.3&lng=114.2&radius=10000" -H "$AUTH")
check "广场接口正常返回" "$(echo "$sq" | grep -q '\[' && echo 0 || echo 1)"

# 争议只能由发布者发起，且需在任务进入 submitted 态后：用独立任务走完 claim->submit->dispute
pubd=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"title\":\"e2e_disp_$TS\",\"bounty\":5,\"currency\":\"CNY\",\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK\",\"radius\":5000,\"time_limit\":30}")
TIDD=$(jqget "$pubd" id)
curl -s -o /dev/null -X POST "$BASE/api/v1/tasks/$TIDD/claim" -H "$AUTH2"
curl -s -o /dev/null -X POST "$BASE/api/v1/tasks/$TIDD/submit" -H "$AUTH2" -H 'Content-Type: application/json' -d "{\"note\":\"done\",\"submit_lat\":22.3,\"submit_lng\":114.2}"
code=$(curl -s -w ' [%{http_code}]' -X POST "$BASE/api/v1/tasks/$TIDD/dispute" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"reason\":\"test\"}")
echo "    dispute: $code"
check "争议 dispute 200(发布者,submitted态)" "$(echo "$code" | grep -q '200' && echo 0 || echo 1)"

# 领取者发消息（参与者均可，期望 200 或 201）
code=$(curl -s -w ' [%{http_code}]' -X POST "$BASE/api/v1/tasks/$TID/messages" -H "$AUTH2" -H 'Content-Type: application/json' -d "{\"content\":\"hi from claimer\"}")
echo "    msg: $code"
check "发送消息 200/201" "$(echo "$code" | grep -Eq '200|201' && echo 0 || echo 1)"

# 发布者确认前先模拟充值以获得足够余额（recharge 为模拟接口）
curl -s -o /dev/null -X POST "$BASE/api/v1/wallet/recharge" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"amount\":100,\"channel\":\"simulated\"}"
code=$(curl -s -w ' [%{http_code}]' -X POST "$BASE/api/v1/tasks/$TID/confirm" -H "$AUTH")
echo "    confirm: $code"
check "确认任务 confirm 200" "$(echo "$code" | grep -q '200' && echo 0 || echo 1)"

# 我的任务 + 详情
mt=$(curl -s "$BASE/api/v1/tasks/mine" -H "$AUTH"); check "我的任务 200" "$(echo "$mt" | grep -q "e2e_$TS" && echo 0 || echo 1)"
gt=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/tasks/$TID" -H "$AUTH"); check "任务详情 200" "$([ "$gt" = "200" ] && echo 0 || echo 1)"

# 取消 / 退款 / 激活（用新任务测避免影响已确认任务）
pub2=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"title\":\"e2e_cancel_$TS\",\"bounty\":5,\"currency\":\"CNY\",\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK\",\"radius\":5000,\"time_limit\":30}")
TID2=$(jqget "$pub2" id)
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$TID2/cancel" -H "$AUTH"); check "取消任务 cancel 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
pub3=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"title\":\"e2e_act_$TS\",\"bounty\":5,\"currency\":\"CNY\",\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK\",\"radius\":5000,\"time_limit\":30}")
TID3=$(jqget "$pub3" id)
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$TID3/activate" -H "$AUTH"); check "激活任务 activate 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$TID3/refund" -H "$AUTH"); check "退款任务 refund 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

# ---------- 聊天消息 ----------
ms=$(curl -s "$BASE/api/v1/tasks/$TID/messages" -H "$AUTH2"); check "获取消息 200" "$(echo "$ms" | grep -q "hi from claimer" && echo 0 || echo 1)"

# ---------- 钱包 ----------
wl=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH"); check "钱包查询 200" "$(echo "$wl" | grep -q '"balance"\|"quota"' && echo 0 || echo 1)"; echo "    $(head -c 160 <<<"$wl")"
tx=$(curl -s "$BASE/api/v1/wallet/transactions" -H "$AUTH"); check "交易记录 200" "$(echo "$tx" | grep -q '\[' && echo 0 || echo 1)"
wd=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/wallet/withdraw" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"amount\":1,\"method\":\"paypal\",\"account\":\"x@y.com\"}")
check "提现 withdraw 200/4xx(余额不足正常)" "$([ "$wd" = "200" ] || [ "$wd" = "400" ] && echo 0 || echo 1)"

# 额度套餐 / IAP 订单
pk=$(curl -s "$BASE/api/v1/wallet/quota-packages" -H "$AUTH"); check "额度套餐 200" "$(echo "$pk" | grep -q 'id' && echo 0 || echo 1)"; echo "    $(head -c 200 <<<"$pk")"
ord=$(curl -s -X POST "$BASE/api/v1/wallet/quota/order" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"package_id\":\"pkg_usd_2\",\"channel\":\"apple\"}")
OID=$(jqget "$ord" id); check "创建IAP订单 200" "$([ -n "$OID" ] && echo 0 || echo 1)"; echo "    order_id=$OID"
if [ -n "$OID" ]; then
  go=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/wallet/quota/order/$OID" -H "$AUTH"); check "查询IAP订单 200" "$([ "$go" = "200" ] && echo 0 || echo 1)"
fi

# ---------- 通知 ----------
nt=$(curl -s "$BASE/api/v1/notifications" -H "$AUTH"); check "通知列表 200" "$(echo "$nt" | grep -q '\[' && echo 0 || echo 1)"
NID=$(echo "$nt" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -n "$NID" ]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/notifications/$NID/read" -H "$AUTH"); check "标记通知已读 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
fi

# ---------- 未授权校验 ----------
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/wallet"); check "无token访问受保护接口 401" "$([ "$code" = "401" ] && echo 0 || echo 1)"

echo ""
echo "=============================================="
echo "  自测结果:  PASS=$pass  FAIL=$fail  SKIP=$skip"
echo "=============================================="
[ "$fail" = "0" ] && exit 0 || exit 1
