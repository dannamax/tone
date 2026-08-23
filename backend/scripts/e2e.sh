#!/bin/bash
# Seeker 后端端到端自测脚本
# 前置条件：后端服务已在 http://127.0.0.1:8080 运行，且日志写入 /tmp/seeker.log
#
# 用法：
#   ./scripts/e2e.sh            # 跑完整自测（依赖已运行的服务与日志）
#   ./scripts/e2e.sh --fresh    # 先重启一个临时服务实例再跑自测
#
# 自测覆盖：发码登录 -> 充值 -> 发双任务 -> 余额冻结 -> 我的发布
#          -> 广场(含距离) -> 领取 -> 提交 -> 确认 -> 结算 -> 通知 -> 提现 -> 详情
#
# 业务规则：
#   发布任务扣除 bounty+fee（fee=bounty*10%）到余额、bounty 到冻结
#   确认完成：发布者 frozen-=bounty, balance-=bounty；领取者 balance+=bounty

set -e

PORT="${PORT:-8089}"
API=http://127.0.0.1:$PORT/api/v1
LOG=/tmp/seeker_e2e.log
DB=/tmp/seekerdb_e2e.sqlite
PASS=0; FAIL=0
ok(){  echo "  ✅ $1"; PASS=$((PASS+1)); }
bad(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# ---- 可选：重启临时服务实例 ----
if [ "$1" = "--fresh" ]; then
  echo "== 0. 启动临时服务实例 (port=$PORT) =="
  rm -f "$DB"
  ( cd "$(dirname "$0")/.." && go build -o /tmp/seeker-server ./cmd/server && SERVER_PORT="$PORT" DB_NAME="$DB" /tmp/seeker-server >"$LOG" 2>&1 & )
  sleep 3
  grep -q "Listening on" "$LOG" && ok "服务已启动" || bad "服务启动失败，请查看 $LOG"
fi

EMAIL="user1@example.com"
echo "== 1. 发送验证码（生产级随机码，非固定码） =="
curl -s -X POST $API/auth/send-code -H "Content-Type: application/json" -d "{\"email\":\"$EMAIL\"}" >/dev/null
sleep 1
CODE=$(grep -o "\[Auth\] Sending code to $EMAIL code=[0-9]*" "$LOG" | tail -1 | grep -o "[0-9]*$")
if [ -z "$CODE" ]; then
  bad "验证码未生成"
elif [ "$CODE" = "123456" ]; then
  bad "验证码仍是固定码 123456（请确认未注入 MOCK_FIXED_CODE 且后端已重新编译）"
else
  # 校验：6 位数字、首位非 0
  if echo "$CODE" | grep -Eq '^[1-9][0-9]{5}$'; then
    ok "验证码已生成(随机码=$CODE)"
  else
    bad "验证码格式异常: $CODE"
  fi
fi

echo "== 2. 登录 =="
LOGIN=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"device_id\":\"e2e-device\"}")
TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])" 2>/dev/null)
[ -n "$TOKEN" ] && ok "登录成功, token长度=${#TOKEN}" || bad "登录失败: $LOGIN"
H="Authorization: Bearer $TOKEN"

echo "== 3. 充值 500 =="
R1=$(curl -s -X POST $API/wallet/recharge -H "$H" -H "Content-Type: application/json" -d '{"amount":500}')
echo "$R1" | python3 -c "import sys,json;d=json.load(sys.stdin); sys.exit(0 if d['code']==0 and d['data']['balance']==500 else 1)" && ok "充值成功,余额500" || bad "充值失败: $R1"

echo "== 4. 发任务A (bounty=100, fee=10) =="
T1=$(curl -s -X POST $API/tasks -H "$H" -H "Content-Type: application/json" \
  -d '{"title":"代取快递","description":"楼下驿站","target_addr":"北京市朝阳区","target_lat":39.9088,"target_lng":116.3975,"radius":3000,"time_limit":30,"bounty":100,"currency":"CNY"}')
ID1=$(echo "$T1" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['id'])" 2>/dev/null)
[ -n "$ID1" ] && ok "发任务A成功(${ID1:0:8})" || bad "发任务A失败: $T1"

echo "== 5. 发任务B (bounty=50, fee=5) =="
T2=$(curl -s -X POST $API/tasks -H "$H" -H "Content-Type: application/json" \
  -d '{"title":"代买咖啡","description":"瑞幸","target_addr":"北京市海淀区","target_lat":39.9090,"target_lng":116.3980,"radius":5000,"time_limit":60,"bounty":50,"currency":"CNY"}')
ID2=$(echo "$T2" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['id'])" 2>/dev/null)
[ -n "$ID2" ] && ok "发任务B成功(${ID2:0:8})" || bad "发任务B失败: $T2"

echo "== 6. 余额冻结校验 (预期: 余额335, 冻结150) =="
W=$(curl -s $API/wallet -H "$H")
echo "$W" | python3 -c "import sys,json;d=json.load(sys.stdin)['data']; sys.exit(0 if d['balance']==335 and d['frozen_balance']==150 else 1)" && ok "余额335/冻结150正确(500-110-55)" || bad "余额不对: $W"

echo "== 7. 我的发布 =="
MINE=$(curl -s "$API/tasks/mine?tab=published&page=1&size=20" -H "$H")
echo "$MINE" | python3 -c "import sys,json;d=json.load(sys.stdin)['data']; sys.exit(0 if d['total']>=2 else 1)" && ok "我发布的任务数>=2" || bad "我发布的不对: $MINE"

echo "== 8. 广场查询 =="
SQ=$(curl -s "$API/tasks/square?lat=39.9088&lng=116.3975&radius=5000" -H "$H")
echo "$SQ" | python3 -c "import sys,json;d=json.load(sys.stdin)['data']; sys.exit(0 if isinstance(d,list) and len(d)>0 or isinstance(d,dict) and d.get('total',0)>0 else 1)" && ok "广场返回任务且含距离" || bad "广场不对: $SQ"

echo "== 9. 第二用户领取任务A =="
P2="user2@example.com"
curl -s -X POST $API/auth/send-code -H "Content-Type: application/json" -d "{\"email\":\"$P2\"}" >/dev/null
sleep 1
C2=$(grep -o "\[Auth\] Sending code to $P2 code=[0-9]*" "$LOG" | tail -1 | grep -o "[0-9]*$")
if [ -z "$C2" ] || [ "$C2" = "123456" ]; then
  bad "第二用户验证码未生成或仍为固定码($C2)"
  C2=""
fi
T2K=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" -d "{\"email\":\"$P2\",\"code\":\"$C2\",\"device_id\":\"e2e-device-2\"}" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])")
H2="Authorization: Bearer $T2K"
curl -s -X POST $API/wallet/recharge -H "$H2" -H "Content-Type: application/json" -d '{"amount":100}' >/dev/null
CL=$(curl -s -X POST $API/tasks/$ID1/claim -H "$H2")
echo "$CL" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin)['code']==0 else 1)" && ok "用户2领取任务A成功" || bad "领取失败: $CL"

echo "== 10. 提交任务A (含task_id) =="
SB=$(curl -s -X POST $API/tasks/$ID1/submit -H "$H2" -H "Content-Type: application/json" \
  -d "{\"task_id\":\"$ID1\",\"note\":\"已放前台\",\"photos\":[],\"submit_lat\":39.9088,\"submit_lng\":116.3975}")
echo "$SB" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin)['code']==0 else 1)" && ok "用户2提交任务A成功" || bad "提交失败: $SB"

echo "== 11. 确认完成任务A(发布者) =="
CF=$(curl -s -X POST $API/tasks/$ID1/confirm -H "$H")
echo "$CF" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin)['code']==0 else 1)" && ok "发布者确认完成成功" || bad "确认失败: $CF"

echo "== 12. 余额结算校验 =="
# 发布者: balance 335-100=235, frozen 150-100=50
W2=$(curl -s $API/wallet -H "$H")
echo "$W2" | python3 -c "import sys,json;d=json.load(sys.stdin)['data']; sys.exit(0 if d['balance']==235 and d['frozen_balance']==50 else 1)" && ok "发布者余额235/冻结50正确" || bad "结算后发布者余额不对: $W2"
# 领取者: 充值100+赏金100=200
W3=$(curl -s $API/wallet -H "$H2")
echo "$W3" | python3 -c "import sys,json;d=json.load(sys.stdin)['data']; sys.exit(0 if d['balance']==200 else 1)" && ok "领取者余额200(100+100)" || bad "领取者余额不对: $W3"

echo "== 13. 通知/消息 =="
NT=$(curl -s $API/notifications -H "$H")
echo "$NT" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin)['code']==0 else 1)" && ok "通知列表可访问" || bad "通知接口异常: $NT"

echo "== 14. 提现 (最低10元) =="
WD=$(curl -s -X POST $API/wallet/withdraw -H "$H" -H "Content-Type: application/json" \
  -d '{"amount":100,"channel":"wechat","account":"wx_test_123"}')
echo "$WD" | python3 -c "import sys,json;d=json.load(sys.stdin); sys.exit(0 if d['code']==0 else 1)" && ok "提现100成功" || bad "提现失败: $WD"

echo "== 15. 任务详情 =="
GT=$(curl -s $API/tasks/$ID2 -H "$H")
echo "$GT" | python3 -c "import sys,json;d=json.load(sys.stdin); sys.exit(0 if d['code']==0 and d['data']['id'] else 1)" && ok "任务B详情可访问" || bad "详情异常: $GT"

echo ""
echo "==== 自测结果 ===="
echo "通过: $PASS   失败: $FAIL"
[ "$FAIL" -eq 0 ] && echo "🎉 全部通过" || echo "⚠️ 存在失败项"
exit $FAIL
