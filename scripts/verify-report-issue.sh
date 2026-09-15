#!/usr/bin/env bash
# SeekerHub payment report-issue e2e verification
# Usage: bash /opt/bountyapp/scripts/verify-report-issue.sh
API=http://localhost:8080/api/v1
DB=/var/lib/docker/volumes/deploy_appdata/_data/seekerdb.sqlite
EMAIL=dannamax@163.com

echo "== 1. login ops account =="
curl -s -X POST $API/auth/send-code -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\"}" > /dev/null
sleep 1
CODE=$(docker logs bountyapp --tail 5 2>&1 | grep -o "${EMAIL} code=[0-9]*" | tail -1 | grep -o '[0-9]*$')
echo "code=$CODE"
TOKEN=$(curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"device_id\":\"e2e-report\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])")
echo "token_len=${#TOKEN}"

echo "== 2. create order =="
ORDER=$(curl -s -X POST $API/wallet/quota/order -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"package_id":"pkg_usd_2","channel":"apple"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['id'])")
echo "order_id=$ORDER"

echo "== 3. report user_cancelled =="
curl -s -X POST $API/wallet/quota/report-issue -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"order_id\":\"$ORDER\",\"stage\":\"purchase\",\"code\":\"user_cancelled\",\"message\":\"User cancelled the Apple payment sheet\"}"
echo
echo "== 4. DB state (expect failed / purchase / user_cancelled) =="
sqlite3 -header -column "$DB" "SELECT status, fail_stage, fail_code, fail_reason FROM recharge_orders WHERE id='$ORDER';"

echo "== 5. guard: report someone else's PAID order (expect 400, untouched) =="
PAID=$(sqlite3 "$DB" "SELECT id FROM recharge_orders WHERE status='paid' AND user_id != (SELECT id FROM users WHERE email='$EMAIL') LIMIT 1")
curl -s -X POST $API/wallet/quota/report-issue -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"order_id\":\"$PAID\",\"stage\":\"purchase\",\"code\":\"user_cancelled\",\"message\":\"tamper\"}"
echo
sqlite3 -header -column "$DB" "SELECT status, fail_stage, fail_code, fail_reason FROM recharge_orders WHERE id='$PAID';"

echo "== 6. cleanup test order =="
sqlite3 "$DB" "DELETE FROM recharge_orders WHERE id='$ORDER';"
echo "done"
