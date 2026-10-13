#!/usr/bin/env bash
# cc-quota-guard verification: proves the plugin is loaded and enforcing.
# Read-only. Safe to run any time.
set -uo pipefail
STATE="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
LOG="$STATE/logs/cc-quota-guard.jsonl"
WS="/root/.openclaw/workspace"

echo "== gateway process"
PID=$(systemctl show -p MainPID --value openclaw-gateway.service 2>/dev/null)
UP=$(ps -o etimes= -p "$PID" 2>/dev/null | tr -d ' ')
echo "pid=$PID uptime_s=$UP"
if [ -n "$UP" ]; then echo "uptime_h=$(awk -v s="$UP" 'BEGIN{printf "%.2f", s/3600}')"; fi

echo
echo "== plugin loaded"
openclaw plugins inspect cc-quota-guard --json 2>/dev/null \
  | python3 -c "import json,sys; p=json.load(sys.stdin)['plugin']; print('enabled=%s status=%s activated=%s' % (p.get('enabled'), p.get('status'), p.get('activated')))" 2>/dev/null \
  || echo "inspect failed"

echo
echo "== hook registrations in gateway log"
journalctl -u openclaw-gateway.service --since "-20 min" --no-pager 2>/dev/null | grep -i "cc-quota-guard" | tail -20

echo
echo "== decision log (last 5)"
[ -f "$LOG" ] && tail -5 "$LOG" || echo "no decisions logged yet at $LOG"

echo
echo "== live quota"
"$WS/tools/cc-quota" 2>&1

echo
echo "== gated cron jobs (model pinning)"
openclaw automations list --json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for j in d.get('jobs',[]):
    p=j.get('payload',{})
    print('%-34s target=%-9s model=%s' % (j.get('name'), j.get('sessionTarget'), p.get('model')))
"
