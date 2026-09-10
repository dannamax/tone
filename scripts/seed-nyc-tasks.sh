#!/usr/bin/env bash
# SeekerHub NYC seed tasks seeder — publishes 5 demo tasks via the public API.
# Usage: bash /opt/bountyapp/scripts/seed-nyc-tasks.sh
set -e
API=http://localhost:8080/api/v1
DB=/var/lib/docker/volumes/deploy_appdata/_data/seekerdb.sqlite
OPS_EMAIL=dannamax@163.com

echo "== 1. Top up ops account beans (data seeding, not user recharge) =="
sqlite3 "$DB" "UPDATE users SET beans_purchased = beans_purchased + 50 WHERE email='$OPS_EMAIL'; SELECT 'ops beans now: '||beans_purchased FROM users WHERE email='$OPS_EMAIL';"

echo "== 2. Login ops account =="
curl -s -X POST $API/auth/send-code -H 'Content-Type: application/json' -d "{\"email\":\"$OPS_EMAIL\"}" > /dev/null
sleep 1
CODE=$(docker logs bountyapp --tail 5 2>&1 | grep -o "${OPS_EMAIL} code=[0-9]*" | tail -1 | grep -o '[0-9]*$')
echo "code=$CODE"
TOKEN=$(curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$OPS_EMAIL\",\"code\":\"$CODE\",\"device_id\":\"ops-seeder\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])")
echo "token_len=${#TOKEN}"

pub() {
  R=$(curl -s -X POST $API/tasks -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "$1")
  echo "$R" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('code') == 0:
    t = d['data']
    print('  OK  |', t['title'][:46], '| beans:', t['bounty_beans'], '| status:', t['status'])
else:
    print('  FAIL|', d.get('message'), '|', sys.argv[1] if len(sys.argv)>1 else '')
" "$1"
}

echo "== 3. Publish 5 NYC pain-point tasks =="
pub '{"title":"Pick up my Amazon package from the lobby","description":"Stuck at work until 7pm. Package is sitting in the lobby of my walk-up on 28th St. Just bring it up to 4F, takes 2 min. Beans appreciated 🙏","target_lat":40.7470,"target_lng":-73.9880,"target_addr":"W 28th St, Chelsea, Manhattan","radius":1000,"time_limit":60,"bounty_beans":5}'

pub '{"title":"Help carry 2 IKEA boxes to 4th floor (walk-up)","description":"Two flat boxes from IKEA Brooklyn sitting in my lobby. 4th floor walk-up, no elevator — boxes are light but bulky. 10 min of work, beans well earned 💪","target_lat":40.7143,"target_lng":-73.9613,"target_addr":"Bedford Ave, Williamsburg, Brooklyn","radius":3000,"time_limit":120,"bounty_beans":10}'

pub '{"title":"Wait for Spectrum installer at my apartment","description":"Spectrum can only come 2-4pm and I cannot leave work. Just be at my place, let the tech in, confirm wifi works, done. Installation already paid.","target_lat":40.7750,"target_lng":-73.9500,"target_addr":"E 79th St, Upper East Side, Manhattan","radius":3000,"time_limit":120,"bounty_beans":8}'

pub '{"title":"Ride share from JFK Terminal 4 to Manhattan","description":"Landing at JFK T4 Friday 6pm. Uber alone is $65+. Split a car to Midtown East — I cover the beans AND my half of the fare. Meet at arrivals, easy ride.","target_lat":40.6413,"target_lng":-73.7781,"target_addr":"JFK Terminal 4, Queens","radius":10000,"time_limit":60,"bounty_beans":10}'

pub '{"title":"Walk my corgi after work today (15 min loop)","description":"Working late tonight. Momo is a 2yo corgi, friendly and leash trained. Leash and treats are by the door. Just one loop around the block and back 🐕","target_lat":40.7644,"target_lng":-73.9235,"target_addr":"30th Ave, Astoria, Queens","radius":1000,"time_limit":30,"bounty_beans":5}'

echo "== 4. Verify square (from Times Square, 10km) =="
curl -s "$API/tasks/square?lat=40.7580&lng=-73.9855&radius=10000&sort=newest" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys, json
d = json.load(sys.stdin)['data']
items = d if isinstance(d, list) else d.get('items', [])
total = d.get('total', len(items)) if isinstance(d, dict) else len(items)
print('square total:', total)
for t in items[:8]:
    print('  -', t['title'][:48], '| beans:', t['bounty_beans'], '| status:', t['status'])"
