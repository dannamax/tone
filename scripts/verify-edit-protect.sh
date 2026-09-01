#!/bin/bash
DB=/var/lib/docker/volumes/deploy_appdata/_data/seekerdb.sqlite
TID=ff22f6d2-1a39-4608-9bbe-5b1f5f88a0e2
BASE=http://127.0.0.1:8080
PEMAIL=$(sqlite3 $DB "SELECT email FROM users WHERE id=(SELECT publisher_id FROM tasks WHERE id='$TID');")
echo "publisher email: $PEMAIL"
curl -s -o /dev/null -X POST $BASE/api/v1/auth/send-code -H "Content-Type: application/json" -d "{\"email\":\"$PEMAIL\",\"device_id\":\"s5\"}"
sleep 2
CODE=$(docker exec bountyapp-redis redis-cli GET "seeker:code:$PEMAIL" | tr -d "\r\n" | sed 's/.*"code":"\([0-9]*\)".*/\1/')
TOKEN=$(curl -s -X POST $BASE/api/v1/auth/login -H "Content-Type: application/json" -d "{\"email\":\"$PEMAIL\",\"code\":\"$CODE\",\"device_id\":\"s5\"}" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['access_token'])")
echo "=== edit as publisher, published -> expect 200 ==="
sqlite3 $DB "UPDATE tasks SET status='published' WHERE id='$TID';"
curl -s -o /dev/null -w "edit-published=%{http_code}\n" -X PATCH $BASE/api/v1/tasks/$TID -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"final check","description":"status test","bounty_beans":10,"target_lat":22.31,"target_lng":114.21,"target_addr":"x","radius":10000,"time_limit":60}'
echo "=== force claimed, edit as publisher -> expect 400 ==="
sqlite3 $DB "UPDATE tasks SET status='claimed' WHERE id='$TID';"
curl -s -o /dev/null -w "edit-claimed=%{http_code}\n" -X PATCH $BASE/api/v1/tasks/$TID -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"no","description":"no","bounty_beans":11,"target_lat":22.31,"target_lng":114.21,"target_addr":"x","radius":10000,"time_limit":60}'
echo "=== restore ==="
sqlite3 $DB "UPDATE tasks SET status='published', title='edit smoke v3', bounty_beans=8 WHERE id='$TID';"
sqlite3 $DB "SELECT title, status, bounty_beans FROM tasks WHERE id='$TID';"
