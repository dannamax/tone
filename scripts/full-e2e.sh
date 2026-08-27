#!/usr/bin/env bash
# ============================================================
# full-e2e.sh — 线上环境完整功能自测（在 HK 机器本机执行）
# 经济模型：金豆 beans（发布预扣 → 确认入账接单人 → 取消/退款返还发布者）
#
# 覆盖:
#   认证: 发码(含60s冷却429) / 注册登录 / /me(注册礼5豆断言)
#   上传: COS 公网可读
#   任务: 发布(扣豆断言) / 豆不足拦截 / claim / submit / confirm(入账断言)
#         dispute→refund(退豆断言) / cancel(退豆断言) / 广场+排序 / 详情 / 我的任务
#   聊天: 双向消息
#   钱包: beans 字段 / 交易流水 / 提现 / 模拟充值 / 401
#   IAP:  套餐映射(pkg_usd_2/5/10) / 创建订单 / 查询订单 / 假JWS拒绝
#   通知: 列表 / 标记已读
#   配置: 汇率 / 邮箱域名
#
# 用法: bash scripts/full-e2e.sh        （须在 HK 机器 /opt/bountyapp 下执行）
# 测试数据: full_e2e_ 前缀，可安全清理
# ============================================================
set -uo pipefail
BASE="http://127.0.0.1:8080"
TS="$(date +%s)"
EMAIL="full_e2e_${TS}@gotseeker.com"
EMAIL2="full_e2e_${TS}b@gotseeker.com"
PASSPORT="+8613800000000"
pass=0; fail=0; skip=0

# ---------- 发信通道保护 ----------
# 本脚本跑在 HK 机器、针对已部署的生产后端。e2e 只需要验证码"生成并被脚本
# 读到"(从 redis 读取)，不需要真实投递。若后端仍用真实 SMTP(个人 163 等)，
# 会向大量测试邮箱真实发信并产生退信、损害发件信誉。
# 默认拒绝在真实 SMTP 通道上跑，除非显式声明:
#   E2E_ALLOW_REAL_EMAIL=1 bash scripts/full-e2e.sh
if [ "${E2E_ALLOW_REAL_EMAIL:-0}" != "1" ]; then
  CUR_PROV=""
  if command -v docker >/dev/null 2>&1; then
    CUR_PROV=$(docker exec bountyapp printenv EMAIL_PROVIDER 2>/dev/null | tr -d '\r' || true)
  fi
  if [ "$CUR_PROV" = "smtp" ]; then
    echo "  [ABORT] 后端 EMAIL_PROVIDER=smtp(真实个人邮箱)。直接跑会灌退信、损害发件信誉。"
    echo "          请先把 HK 部署的 EMAIL_PROVIDER 改为 resend 或 mock，再运行；"
    echo "          或显式确认风险: E2E_ALLOW_REAL_EMAIL=1 bash scripts/full-e2e.sh"
    exit 1
  fi
  if [ -z "$CUR_PROV" ]; then
    echo "  [WARN] 无法探测当前 EMAIL_PROVIDER。若后端仍为真实 SMTP，本脚本会触发真实发信并产生退信。"
    echo "         请确认部署的 EMAIL_PROVIDER 已为 resend 或 mock；或显式声明: E2E_ALLOW_REAL_EMAIL=1"
    exit 1
  fi
  echo "  [INFO] 当前 EMAIL_PROVIDER=$CUR_PROV，非真实 SMTP，继续 e2e。"
fi

check() { if [ "$2" = "0" ]; then echo "  [PASS] $1"; pass=$((pass+1)); else echo "  [FAIL] $1"; fail=$((fail+1)); fi; }
jqget() { echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
beans() { echo "$1" | grep -o "\"$2\":[0-9]*" | head -1 | cut -d':' -f2; }

login_user() { # $1=email -> stdout token
  curl -s -o /dev/null -X POST "$BASE/api/v1/auth/send-code" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"country_code\":\"CN\",\"phone\":\"$PASSPORT\"}"
  RAW=$(docker exec bountyapp-redis redis-cli get "seeker:code:$1" 2>/dev/null | tr -d '\r' || true)
  C=$(echo "$RAW" | grep -o '"code":"[0-9]*"' | head -1 | cut -d'"' -f4)
  [ -n "$C" ] || { echo ""; return 1; }
  resp=$(curl -s -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"code\":\"$C\",\"device_id\":\"e2e-$TS\"}")
  echo "$resp" | grep -o '"access_token":"[^"]*"' | head -1 | cut -d'"' -f4
}

echo "=============================================="
echo "  Seeker 线上功能完整自测（金豆经济模型）  $(date)"
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

# ---------- 用户A：发码 + 冷却 + 登录 ----------
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/auth/send-code" \
  -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"country_code\":\"CN\",\"phone\":\"$PASSPORT\"}")
check "A send-code 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/auth/send-code" \
  -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"country_code\":\"CN\",\"phone\":\"$PASSPORT\"}")
check "A 二次发码冷却 429" "$([ "$code" = "429" ] && echo 0 || echo 1)"

TOKEN=$(login_user "$EMAIL")
check "A login 返回 token" "$([ -n "$TOKEN" ] && echo 0 || echo 1)"
[ -n "$TOKEN" ] || { echo "  [SKIP] 无 token，后续全部跳过"; exit 1; }
AUTH="Authorization: Bearer $TOKEN"

# 用户B
TOKEN2=$(login_user "$EMAIL2")
check "B login 返回 token" "$([ -n "$TOKEN2" ] && echo 0 || echo 1)"
AUTH2="Authorization: Bearer $TOKEN2"

# /me 注册礼 5 豆断言
me=$(curl -s "$BASE/api/v1/me" -H "$AUTH")
check "GET /me 200" "$([ "$(echo "$me" | grep -c beans_purchased)" != "0" ] && echo 0 || echo 1)"
BEAN0=$(beans "$me" beans_purchased)
check "A 注册礼 beans_purchased=5" "$([ "${BEAN0:-x}" = "5" ] && echo 0 || echo 1)"; echo "    beans_purchased=$BEAN0"

# ---------- 上传 COS ----------
PNG="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
UP=$(curl -s -X POST "$BASE/api/v1/upload" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"base64\":\"data:image/png;base64,$PNG\"}")
URL=$(jqget "$UP" url)
if echo "$URL" | grep -q "cos.ap-hongkong.myqcloud.com"; then
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL"); check "上传COS且公网可读 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
else
  check "上传COS返回URL" 1; echo "    resp=$UP"
fi

# ---------- 任务1: A发布(扣豆) → B认领提交 → A确认(入账) ----------
pub=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"title\":\"e2e_$TS\",\"description\":\"full e2e beans\",\"bounty_beans\":5,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK Central\",\"radius\":5000,\"time_limit\":30,\"images\":[\"$URL\"]}")
TID=$(jqget "$pub" id)
check "T1 发布任务(bounty_beans=5) 201" "$([ -n "$TID" ] && echo 0 || echo 1)"; echo "    task_id=$TID"

wl=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH")
BT=$(beans "$wl" beans_total)
check "T1 发布后 A 扣豆 beans_total=0" "$([ "${BT:-x}" = "0" ] && echo 0 || echo 1)"; echo "    A beans_total=$BT"

# 豆不足拦截（A 当前 0 豆）
code=$(curl -s -o /tmp/nope.txt -w '%{http_code}' -X POST "$BASE/api/v1/tasks" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"title\":\"should_fail\",\"bounty_beans\":5,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK\",\"radius\":5000,\"time_limit\":30}")
check "A 豆不足发布被拦截 4xx" "$([ "$code" = "400" ] || [ "$code" = "402" ] || [ "$code" = "422" ] && echo 0 || echo 1)"; echo "    http=$code $(head -c 120 /tmp/nope.txt)"

# 发布校验：金豆区间外(4)
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks" -H "$AUTH2" -H 'Content-Type: application/json' \
  -d "{\"title\":\"bad\",\"bounty_beans\":4,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK\",\"radius\":5000,\"time_limit\":30}")
check "B bounty_beans=4 校验拒绝 4xx" "$([ "$code" = "400" ] || [ "$code" = "422" ] && echo 0 || echo 1)"

# T1 链路
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$TID/claim" -H "$AUTH2")
check "T1 B claim 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

SUB=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$TID/submit" -H "$AUTH2" -H 'Content-Type: application/json' \
  -d "{\"note\":\"done\",\"images\":[\"$URL\"],\"submit_lat\":22.3,\"submit_lng\":114.2}")
check "T1 B submit 200" "$([ "$SUB" = "200" ] && echo 0 || echo 1)"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$TID/confirm" -H "$AUTH")
check "T1 A confirm 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

wl2=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH2")
BE=$(beans "$wl2" beans_earned); BT2=$(beans "$wl2" beans_total)
check "T1 确认后 B 入账 beans_earned=5" "$([ "${BE:-x}" = "5" ] && echo 0 || echo 1)"
check "T1 确认后 B beans_total=10" "$([ "${BT2:-x}" = "10" ] && echo 0 || echo 1)"; echo "    B beans_earned=$BE beans_total=$BT2"

# 提交内容可查
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/tasks/$TID/submission" -H "$AUTH")
check "T1 查询提交内容 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

# ---------- 任务2: B发布 → 广场可见 → A认领提交 → B争议 → 退款(退豆) ----------
pub=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH2" -H 'Content-Type: application/json' \
  -d "{\"title\":\"e2e_disp_$TS\",\"bounty_beans\":5,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK TST\",\"radius\":5000,\"time_limit\":30}")
T2=$(jqget "$pub" id)
check "T2 B 发布任务 201" "$([ -n "$T2" ] && echo 0 || echo 1)"

sq=$(curl -s "$BASE/api/v1/tasks/square?lat=22.3&lng=114.2&radius=10000" -H "$AUTH")
check "广场(距离排序)可见 T2" "$(echo "$sq" | grep -q "e2e_disp_$TS" && echo 0 || echo 1)"
sq=$(curl -s "$BASE/api/v1/tasks/square?lat=22.3&lng=114.2&radius=10000&sort=beans" -H "$AUTH")
check "广场(金豆排序)可见 T2" "$(echo "$sq" | grep -q "e2e_disp_$TS" && echo 0 || echo 1)"

curl -s -o /dev/null -X POST "$BASE/api/v1/tasks/$T2/claim" -H "$AUTH"
curl -s -o /dev/null -X POST "$BASE/api/v1/tasks/$T2/submit" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"note\":\"done\",\"submit_lat\":22.3,\"submit_lng\":114.2}"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$T2/dispute" -H "$AUTH2" -H 'Content-Type: application/json' -d "{\"reason\":\"e2e test\"}")
check "T2 B dispute 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

wl2=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH2"); BT2a=$(beans "$wl2" beans_total)
check "T2 B 发布后 beans_total=5" "$([ "${BT2a:-x}" = "5" ] && echo 0 || echo 1)"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$T2/refund" -H "$AUTH2")
check "T2 B refund 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
wl2=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH2"); BT2b=$(beans "$wl2" beans_total)
check "T2 退款后 B beans_total=10(退豆)" "$([ "${BT2b:-x}" = "10" ] && echo 0 || echo 1)"

# ---------- 任务3: B发布 → cancel(退豆) ----------
pub=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH2" -H 'Content-Type: application/json' \
  -d "{\"title\":\"e2e_cancel_$TS\",\"bounty_beans\":5,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK\",\"radius\":5000,\"time_limit\":30}")
T3=$(jqget "$pub" id)
check "T3 B 发布任务 201" "$([ -n "$T3" ] && echo 0 || echo 1)"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$T3/cancel" -H "$AUTH2")
check "T3 B cancel 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
wl2=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH2"); BT3=$(beans "$wl2" beans_total)
check "T3 取消后 B beans_total=10(退豆)" "$([ "${BT3:-x}" = "10" ] && echo 0 || echo 1)"

# ---------- 任务4: B发布 → A认领 → 双向聊天 → A提交 → B确认(赚豆) ----------
pub=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH2" -H 'Content-Type: application/json' \
  -d "{\"title\":\"e2e_chat_$TS\",\"bounty_beans\":5,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK Central\",\"radius\":5000,\"time_limit\":30}")
T4=$(jqget "$pub" id)
check "T4 B 发布任务 201" "$([ -n "$T4" ] && echo 0 || echo 1)"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$T4/claim" -H "$AUTH")
check "T4 A claim 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$T4/messages" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"content\":\"hi from claimer\"}")
check "T4 A 发消息 200/201" "$( [ "$code" = "200" ] || [ "$code" = "201" ] && echo 0 || echo 1)"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$T4/messages" -H "$AUTH2" -H 'Content-Type: application/json' -d "{\"content\":\"hi from publisher\"}")
check "T4 B 发消息 200/201" "$( [ "$code" = "200" ] || [ "$code" = "201" ] && echo 0 || echo 1)"
ms=$(curl -s "$BASE/api/v1/tasks/$T4/messages" -H "$AUTH")
check "T4 消息记录双向可见" "$(echo "$ms" | grep -q "hi from claimer" && echo "$ms" | grep -q "hi from publisher" && echo 0 || echo 1)"

curl -s -o /dev/null -X POST "$BASE/api/v1/tasks/$T4/submit" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"note\":\"done\",\"images\":[\"$URL\"],\"submit_lat\":22.3,\"submit_lng\":114.2}"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/tasks/$T4/confirm" -H "$AUTH2")
check "T4 B confirm 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
wl=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH"); BEA=$(beans "$wl" beans_earned); BTA=$(beans "$wl" beans_total)
check "T4 确认后 A 赚豆 beans_total=5" "$([ "${BTA:-x}" = "5" ] && echo 0 || echo 1)"; echo "    A beans_earned=$BEA beans_total=$BTA"

# ---------- 我的任务 / 详情 ----------
mt=$(curl -s "$BASE/api/v1/tasks/mine" -H "$AUTH")
check "我的任务 200 且含 T1" "$(echo "$mt" | grep -q "e2e_$TS" && echo 0 || echo 1)"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/tasks/$TID" -H "$AUTH")
check "任务详情 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"

# ---------- 钱包 / 交易 / 模拟充值 / 提现 ----------
wl=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH")
check "钱包查询含 beans 字段" "$(echo "$wl" | grep -q '"beans_total"' && echo 0 || echo 1)"; echo "    $(head -c 200 <<<"$wl")"
tx=$(curl -s "$BASE/api/v1/wallet/transactions" -H "$AUTH")
check "交易记录 200" "$(echo "$tx" | grep -q '"total"' && echo 0 || echo 1)"
check "交易记录含 bean_spend" "$(echo "$tx" | grep -q 'bean_spend' && echo 0 || echo 1)"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/wallet/recharge" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"amount\":100}")
check "模拟充值 recharge 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
wd=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/wallet/withdraw" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"amount\":1,\"method\":\"paypal\",\"account\":\"x@y.com\"}")
check "提现 withdraw 200/4xx(门槛拦截正常)" "$([ "$wd" = "200" ] || [ "$wd" = "400" ] || [ "$wd" = "422" ] && echo 0 || echo 1)"

# ---------- IAP 套餐 / 订单 / 假收据拒绝 ----------
pk=$(curl -s "$BASE/api/v1/wallet/quota-packages" -H "$AUTH")
check "套餐含 pkg_usd_2(5豆)" "$(echo "$pk" | grep -q 'pkg_usd_2' && echo 0 || echo 1)"
check "套餐含 pkg_usd_5(10豆)" "$(echo "$pk" | grep -q 'pkg_usd_5' && echo 0 || echo 1)"
check "套餐含 pkg_usd_10(20豆)" "$(echo "$pk" | grep -q 'pkg_usd_10' && echo 0 || echo 1)"; echo "    $(head -c 220 <<<"$pk")"

ord=$(curl -s -X POST "$BASE/api/v1/wallet/quota/order" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"package_id\":\"pkg_usd_5\",\"channel\":\"apple\"}")
OID=$(jqget "$ord" id)
check "创建IAP订单(pkg_usd_5) 200" "$([ -n "$OID" ] && echo 0 || echo 1)"; echo "    order_id=$OID"
if [ -n "$OID" ]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/wallet/quota/order/$OID" -H "$AUTH")
  check "查询IAP订单 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
  # 假 JWS 必须被拒绝（防伪造充值）
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/wallet/quota/confirm-apple" -H "$AUTH" -H 'Content-Type: application/json' \
    -d "{\"order_id\":\"$OID\",\"jws\":\"eyJhbGciOiJFUzI1NiJ9.fake.signature\"}")
  check "假JWS确认被拒绝 4xx" "$([ "$code" = "400" ] || [ "$code" = "401" ] || [ "$code" = "422" ] && echo 0 || echo 1)"; echo "    http=$code"
fi

# ---------- 通知 ----------
nt=$(curl -s "$BASE/api/v1/notifications" -H "$AUTH")
check "通知列表 200" "$(echo "$nt" | grep -q '"total"' && echo 0 || echo 1)"
NID=$(echo "$nt" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -n "$NID" ]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/notifications/$NID/read" -H "$AUTH")
  check "标记通知已读 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
else
  echo "  [SKIP] 无通知可标记（新号无通知属正常）"
fi

# ---------- 任务删除管理 ----------
# T5: A 发布未认领任务 → 删除(自动退豆)
pub=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"title\":\"e2e_del_$TS\",\"bounty_beans\":5,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK\",\"radius\":5000,\"time_limit\":30}")
T5=$(jqget "$pub" id)
check "T5 A 发布待删任务 201" "$([ -n "$T5" ] && echo 0 || echo 1)"
wl=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH"); BT5a=$(beans "$wl" beans_total)
check "T5 发布后 A beans_total=0(扣豆)" "$([ "${BT5a:-x}" = "0" ] && echo 0 || echo 1)"

code=$(curl -s -o /tmp/del.txt -w '%{http_code}' -X DELETE "$BASE/api/v1/tasks/$T5" -H "$AUTH")
check "T5 删除未认领任务 200" "$([ "$code" = "200" ] && echo 0 || echo 1)"
wl=$(curl -s "$BASE/api/v1/wallet" -H "$AUTH"); BT5b=$(beans "$wl" beans_total)
check "T5 删除后自动退豆 beans_total=5" "$([ "${BT5b:-x}" = "5" ] && echo 0 || echo 1)"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/tasks/$T5" -H "$AUTH")
check "T5 删除后详情 404" "$([ "$code" = "404" ] && echo 0 || echo 1)"

# T6: 进行中任务删除被跳过（A 发布 → B 认领 → A 删除被拒）
pub=$(curl -s -X POST "$BASE/api/v1/tasks" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"title\":\"e2e_delprog_$TS\",\"bounty_beans\":5,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"HK\",\"radius\":5000,\"time_limit\":30}")
T6=$(jqget "$pub" id)
curl -s -o /dev/null -X POST "$BASE/api/v1/tasks/$T6/claim" -H "$AUTH2"
code=$(curl -s -o /tmp/del2.txt -w '%{http_code}' -X DELETE "$BASE/api/v1/tasks/$T6" -H "$AUTH")
check "T6 删除进行中任务跳过(200+skipped)" "$([ "$code" = "200" ] && grep -q '"skipped":\[' /tmp/del2.txt && echo 0 || echo 1)"; echo "    resp=$(head -c 200 /tmp/del2.txt)"

# T7: 批量删除终态任务(T2 refunded + T3 cancelled)
bd=$(curl -s -X POST "$BASE/api/v1/tasks/delete-batch" -H "$AUTH2" -H 'Content-Type: application/json' \
  -d "{\"task_ids\":[\"$T2\",\"$T3\"]}")
check "T7 批量删除 200 且 2 个全删" "$(echo "$bd" | grep -q '"deleted":\["'"$T2"'","'"$T3"'"\]' && echo 0 || echo 1)"; echo "    resp=$(head -c 220 <<<"$bd")"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/tasks/$T2" -H "$AUTH2")
check "T7 批量删除后 T2 详情 404" "$([ "$code" = "404" ] && echo 0 || echo 1)"

# ---------- 未授权 ----------
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/wallet")
check "无token访问受保护接口 401" "$([ "$code" = "401" ] && echo 0 || echo 1)"

echo ""
echo "=============================================="
echo "  自测结果:  PASS=$pass  FAIL=$fail  SKIP=$skip"
echo "=============================================="
[ "$fail" = "0" ] && exit 0 || exit 1
