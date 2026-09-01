#!/bin/bash
BASE=http://127.0.0.1:8080
EMAIL=edit_smoke_$(date +%s)@gotseeker.com
DB=/var/lib/docker/volumes/deploy_appdata/_data/seekerdb.sqlite
curl -s -o /dev/null -X POST $BASE/api/v1/auth/send-code -H "Content-Type: application/json" -d "{\"email\":\"$EMAIL\",\"device_id\":\"smoke\"}"
sleep 2
CODE=$(docker exec bountyapp-redis redis-cli GET "seeker:code:$EMAIL" | tr -d "\r\n" | sed 's/.*"code":"\([0-9]*\)".*/\1/')
TOKEN=$(curl -s -X POST $BASE/api/v1/auth/login -H "Content-Type: application/json" -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"device_id\":\"smoke\"}" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['access_token'])")
ME=$(curl -s $BASE/api/v1/me -H "Authorization: Bearer $TOKEN")
PUID=$(echo "$ME" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
sqlite3 $DB "UPDATE users SET beans_purchased=beans_purchased+50 WHERE id='$PUID';"
B0=$(curl -s $BASE/api/v1/wallet -H "Authorization: Bearer $TOKEN" | grep -o '"beans_total":[0-9]*' | head -1 | cut -d: -f2)
PUB=$(curl -s -X POST $BASE/api/v1/tasks -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"edit smoke","description":"before edit","bounty_beans":7,"target_lat":22.3,"target_lng":114.2,"target_addr":"Beijing test","radius":5000,"time_limit":30}')
TID=$(echo "$PUB" | grep -o '"id":"[a-f0-9-]*"' | head -1 | cut -d'"' -f4)
B1=$(curl -s $BASE/api/v1/wallet -H "Authorization: Bearer $TOKEN" | grep -o '"beans_total":[0-9]*' | head -1 | cut -d: -f2)
echo "1) publish: task=$TID beans $B0->$B1 (expect -7)"
E1=$(curl -s -X PATCH $BASE/api/v1/tasks/$TID -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"edit smoke v2","description":"after edit","bounty_beans":12,"target_lat":22.31,"target_lng":114.21,"target_addr":"Beijing test v2","radius":10000,"time_limit":60}')
B2=$(curl -s $BASE/api/v1/wallet -H "Authorization: Bearer $TOKEN" | grep -o '"beans_total":[0-9]*' | head -1 | cut -d: -f2)
echo "2) increase to 12: beans $B1->$B2 (expect -5); title=$(echo "$E1" | grep -o '"title":"[^"]*"' | head -1)"
E2=$(curl -s -X PATCH $BASE/api/v1/tasks/$TID -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"edit smoke v3","description":"refund case","bounty_beans":8,"target_lat":22.31,"target_lng":114.21,"target_addr":"Beijing test v2","radius":10000,"time_limit":60}')
B3=$(curl -s $BASE/api/v1/wallet -H "Authorization: Bearer $TOKEN" | grep -o '"beans_total":[0-9]*' | head -1 | cut -d: -f2)
echo "3) decrease to 8: beans $B2->$B3 (expect +4)"
C=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE/api/v1/tasks/$TID/claim -H "Authorization: Bearer $TOKEN")
E3=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH $BASE/api/v1/tasks/$TID -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"x","description":"y","bounty_beans":9,"target_lat":22.3,"target_lng":114.2,"target_addr":"x","radius":5000,"time_limit":30}')
echo "4) claim own=$C (expect 400); edit-after-claim=$E3 (expect 400)"
TX=$(sqlite3 $DB "SELECT type, beans_delta, substr(remark,1,45) FROM transactions WHERE task_id='$TID' ORDER BY created_at;")
echo "5) audit logs for task:"
echo "$TX"
