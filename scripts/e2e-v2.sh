#!/usr/bin/env bash
# e2e-v2.sh — 新功能补测（HK 机器 /opt/bountyapp 下执行）
# 覆盖: A. PATCH /me 昵称  B. request-changes 多轮  C. disputed 撤销  D. 金豆守恒
# 断言方式: HTTP code + 详情接口复核 + /wallet 金豆（与 full-e2e 一致）
# 数据: full_v2_ 前缀，可安全清理
set -uo pipefail
BASE="http://127.0.0.1:8080"
TS="$(date +%s)"
A="full_v2_a_${TS}@gotseeker.com"
B="full_v2_b_${TS}@gotseeker.com"
pass=0; fail=0
check() { if [ "$2" = "0" ]; then echo "  [PASS] $1"; pass=$((pass+1)); else echo "  [FAIL] $1"; fail=$((fail+1)); fi }
jqget() { echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
numget() { echo "$1" | grep -o "\"$2\":[0-9-]*" | head -1 | cut -d':' -f2; }
codeof() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
# 详情接口复核状态
dstat() { curl -s "$BASE/api/v1/tasks/$1" -H "Authorization: Bearer $2" | grep -o '"status":"[a-z_]*"' | head -1 | cut -d'"' -f4; }
# /wallet 金豆总额
wbeans() { curl -s "$BASE/api/v1/wallet" -H "Authorization: Bearer $1" | grep -o '"beans_total":[0-9-]*' | head -1 | cut -d':' -f2; }

login_user() {
  curl -s -o /dev/null -X POST "$BASE/api/v1/auth/send-code" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"device_id\":\"v2-$TS\"}"
  sleep 1
  RAW=$(docker exec bountyapp-redis redis-cli get "seeker:code:$1" 2>/dev/null | tr -d '\r' || true)
  C=$(echo "$RAW" | grep -o '"code":"[0-9]*"' | head -1 | cut -d'"' -f4)
  [ -n "$C" ] || { echo ""; return 1; }
  curl -s -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"code\":\"$C\",\"device_id\":\"v2-$TS\"}" | \
    grep -o '"access_token":"[^"]*"' | head -1 | cut -d'"' -f4
}

echo "== A. PATCH /me nickname =="
TA=$(login_user "$A")
[ -n "$TA" ] || { echo "  [FAIL] A login"; exit 1; }
# 测试专用：直接给 A 加金豆（金豆只能经 IAP 验签入账，e2e 无法伪造 JWS）
ME_A=$(curl -s "$BASE/api/v1/me" -H "Authorization: Bearer $TA")
UID_A=$(jqget "$ME_A" id)
sqlite3 /var/lib/docker/volumes/deploy_appdata/_data/seekerdb.sqlite "UPDATE users SET beans_purchased=beans_purchased+100 WHERE id='$UID_A';"
AB0=$(wbeans "$TA")
check "A SQL add beans (>=100)" "$([ "${AB0:-0}" -ge "100" ] && echo 0 || echo 1)"; echo "    A beans_total=$AB0"

R1=$(curl -s -X PATCH "$BASE/api/v1/me" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{"nickname":"V2Tester"}')
check "PATCH /me nickname ok" "$([ "$(jqget "$R1" nickname)" = "V2Tester" ] && echo 0 || echo 1)"
R2=$(curl -s -X PATCH "$BASE/api/v1/me" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{"nickname":""}')
check "empty nickname rejected" "$([ "$(numget "$R2" code)" != "0" ] && echo 0 || echo 1)"
LONG=$(python3 -c "print('x'*40)")
R3=$(curl -s -X PATCH "$BASE/api/v1/me" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d "{\"nickname\":\"$LONG\"}")
check "long nickname rejected" "$([ "$(numget "$R3" code)" != "0" ] && echo 0 || echo 1)"

echo "== B. request-changes multi-round =="
TB=$(login_user "$B")
[ -n "$TB" ] || { echo "  [FAIL] B login"; exit 1; }
BB0=$(wbeans "$TB")

PUB=$(curl -s -X POST "$BASE/api/v1/tasks" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' \
  -d "{\"title\":\"full_v2_rc_$TS\",\"description\":\"v2 flow\",\"bounty_beans\":7,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"Test Beijing\",\"radius\":5000,\"time_limit\":30}")
TID=$(jqget "$PUB" id)
check "A publish 7-bean task" "$([ -n "$TID" ] && echo 0 || echo 1)"
[ -z "$TID" ] && { echo "  [ABORT] $PUB"; exit 1; }
AB1=$(wbeans "$TA")
check "A beans deducted (-7)" "$([ $((AB0 - AB1)) = "7" ] && echo 0 || echo 1)"

# 超围栏拒绝用例：北京坐标（39.79）领取 22.3 的任务 → 400
ooc=$(codeof -X POST "$BASE/api/v1/tasks/$TID/claim" -H "Authorization: Bearer $TB" -H "Content-Type: application/json" -d '{"lat":39.79,"lng":116.33}')
check "out-of-radius claim rejected (400)" "$([ "$ooc" = "400" ] && echo 0 || echo 1)"
c=$(codeof -X POST "$BASE/api/v1/tasks/$TID/claim" -H "Authorization: Bearer $TB" -H "Content-Type: application/json" -d '{"lat":22.3,"lng":114.2}')
check "B claim 200" "$([ "$c" = "200" ] && echo 0 || echo 1)"
check "  status=claimed" "$([ "$(dstat "$TID" "$TB")" = "claimed" ] && echo 0 || echo 1)"

c=$(codeof -X POST "$BASE/api/v1/tasks/$TID/submit" -H "Authorization: Bearer $TB" -H 'Content-Type: application/json' \
  -d '{"note":"first attempt","images":[],"submit_lat":22.3,"submit_lng":114.2}')
check "B submit #1 200" "$([ "$c" = "200" ] && echo 0 || echo 1)"
check "  status=submitted" "$([ "$(dstat "$TID" "$TB")" = "submitted" ] && echo 0 || echo 1)"

c=$(codeof -X POST "$BASE/api/v1/tasks/$TID/request-changes" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{"reason":"photo blurry"}')
check "A request-changes 200" "$([ "$c" = "200" ] && echo 0 || echo 1)"
check "  status=claimed(回退)" "$([ "$(dstat "$TID" "$TB")" = "claimed" ] && echo 0 || echo 1)"

c=$(codeof -X POST "$BASE/api/v1/tasks/$TID/submit" -H "Authorization: Bearer $TB" -H 'Content-Type: application/json' \
  -d '{"note":"second attempt","images":[],"submit_lat":22.3,"submit_lng":114.2}')
check "B submit #2 200" "$([ "$c" = "200" ] && echo 0 || echo 1)"
check "  status=submitted" "$([ "$(dstat "$TID" "$TB")" = "submitted" ] && echo 0 || echo 1)"

c=$(codeof -X POST "$BASE/api/v1/tasks/$TID/confirm" -H "Authorization: Bearer $TA")
check "A confirm 200" "$([ "$c" = "200" ] && echo 0 || echo 1)"
check "  status=completed" "$([ "$(dstat "$TID" "$TB")" = "completed" ] && echo 0 || echo 1)"

AB2=$(wbeans "$TA"); BB2=$(wbeans "$TB")
check "B beans credited (+7)" "$([ $((BB2 - BB0)) = "7" ] && echo 0 || echo 1)"
check "A balance unchanged" "$([ "$AB2" = "$AB1" ] && echo 0 || echo 1)"

echo "== C. dispute withdraw =="
PUB2=$(curl -s -X POST "$BASE/api/v1/tasks" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' \
  -d "{\"title\":\"full_v2_dw_$TS\",\"description\":\"v2 dispute\",\"bounty_beans\":6,\"target_lat\":22.3,\"target_lng\":114.2,\"target_addr\":\"Test Beijing\",\"radius\":5000,\"time_limit\":30}")
TID2=$(jqget "$PUB2" id)
check "A publish 2nd task (6 beans)" "$([ -n "$TID2" ] && echo 0 || echo 1)"
[ -z "$TID2" ] && exit 1
curl -s -o /dev/null -X POST "$BASE/api/v1/tasks/$TID2/claim" -H "Authorization: Bearer $TB" -H "Content-Type: application/json" -d '{"lat":22.3,"lng":114.2}'
curl -s -o /dev/null -X POST "$BASE/api/v1/tasks/$TID2/submit" -H "Authorization: Bearer $TB" -H 'Content-Type: application/json' -d '{"note":"evidence v2","submit_lat":22.3,"submit_lng":114.2}'
c=$(codeof -X POST "$BASE/api/v1/tasks/$TID2/dispute" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{"reason":"quality issue"}')
check "A dispute 200" "$([ "$c" = "200" ] && echo 0 || echo 1)"
check "  status=disputed" "$([ "$(dstat "$TID2" "$TA")" = "disputed" ] && echo 0 || echo 1)"
c=$(codeof -X POST "$BASE/api/v1/tasks/$TID2/request-changes" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{"reason":"withdraw dispute"}')
check "A withdraw dispute 200" "$([ "$c" = "200" ] && echo 0 || echo 1)"
check "  status=claimed(撤销)" "$([ "$(dstat "$TID2" "$TA")" = "claimed" ] && echo 0 || echo 1)"
c=$(codeof -X POST "$BASE/api/v1/tasks/$TID2/submit" -H "Authorization: Bearer $TB" -H 'Content-Type: application/json' -d '{"note":"redone","submit_lat":22.3,"submit_lng":114.2}')
check "B resubmit 200" "$([ "$c" = "200" ] && echo 0 || echo 1)"
check "  status=submitted" "$([ "$(dstat "$TID2" "$TA")" = "submitted" ] && echo 0 || echo 1)"
c=$(codeof -X POST "$BASE/api/v1/tasks/$TID2/confirm" -H "Authorization: Bearer $TA")
check "A confirm 2nd 200" "$([ "$c" = "200" ] && echo 0 || echo 1)"
check "  status=completed" "$([ "$(dstat "$TID2" "$TA")" = "completed" ] && echo 0 || echo 1)"
BB3=$(wbeans "$TB")
check "B cumulative credit (+6)" "$([ $((BB2 + 6)) = "$BB3" ] && echo 0 || echo 1)"

echo "=============================================="
echo "  v2 result: PASS=$pass FAIL=$fail"
echo "=============================================="
exit $([ "$fail" = "0" ] && echo 0 || echo 1)
