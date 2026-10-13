#!/usr/bin/env bash
# jobs-status.sh — where the auto-apply jobs live, when they run, and on which model.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
[ -f "$ROOT/.env" ] && set -a && . "$ROOT/.env" && set +a

echo "Job_Automation — auto-apply status"
echo "  as of     $(date '+%F %H:%M:%S %Z')"
echo
echo "  runner    Command Code CLI  →  cmd -p \"<channel prompt>\" --yolo --skip-onboarding --no-auto-update"
echo "  models    ${APPLY_MODELS:-<unset>}"
echo "            (free models primary; deepseek paid fallback only while the quota gate allows)"
echo "  browser   agent-browser → Brave CDP 127.0.0.1:${BRAVE_CDP_PORT:-9222}"
echo "  reports   Telegram chat ${TELEGRAM_CHAT_ID:-<unset>}"
echo "  schedule  your crontab  (edit with: crontab -e)"
echo "  prompts   $ROOT/prompts/<channel>.md"
echo "  logs      $ROOT/logs/<channel>-<stamp>.log   +  logs/cron.log"
echo

crontab -l 2>/dev/null | grep -oE '^[^#]*cron-run\.sh [a-z-]+' >/tmp/.ja_cronlines 2>/dev/null
if [ ! -s /tmp/.ja_cronlines ]; then
  echo "  ⚠ no job-automation entries found in crontab"
fi

python3 - "$ROOT" <<'PY'
import os, re, subprocess, sys, time, glob
from datetime import datetime, timedelta

ROOT = sys.argv[1]
TZ = "Asia/Kuala_Lumpur"

def crontab_jobs():
    out = subprocess.run(["crontab","-l"], capture_output=True, text=True).stdout
    jobs = []
    for line in out.splitlines():
        if "cron-run.sh" not in line or line.strip().startswith("#"):
            continue
        m = re.match(r"\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+.*cron-run\.sh\s+([a-zA-Z0-9_-]+)", line)
        if m:
            jobs.append((m.group(6), [m.group(1),m.group(2),m.group(3),m.group(4),m.group(5)]))
    return jobs

def field_match(field, value, lo, hi):
    if field == "*":
        return True
    for part in field.split(","):
        if part.isdigit() and int(part) == value:
            return True
    return False

def next_run(fields, now):
    minute, hour, dom, month, dow = fields
    t = now.replace(second=0, microsecond=0) + timedelta(minutes=1)
    for _ in range(60*24*8):
        if (field_match(minute,t.minute,0,59) and field_match(hour,t.hour,0,23)
            and field_match(dom,t.day,1,31) and field_match(month,t.month,1,12)
            and field_match(dow,(t.weekday()+1)%7,0,6)):
            return t
        t += timedelta(minutes=1)
    return None

def human(delta):
    s = int(delta.total_seconds())
    if s < 3600: return f"in {s//60}m"
    if s < 86400: return f"in {s//3600}h{(s%3600)//60:02d}m"
    return f"in {s//86400}d{(s%86400)//3600}h"

now = datetime.now()
rows = []
for ch, fields in crontab_jobs():
    nxt = next_run(fields, now)
    slots = f"{fields[1].replace(',',':00 ')}:00" if fields[1] != "*" else "every hour"
    logs = sorted(glob.glob(os.path.join(ROOT,"logs",f"{ch}-*.log")), key=os.path.getmtime)
    if logs:
        last = logs[-1]
        when = datetime.fromtimestamp(os.path.getmtime(last)).strftime("%m-%d %H:%M")
        tail = ""
        for ln in reversed(open(last, errors="ignore").read().splitlines()):
            if ln.strip():
                tail = ln.strip()[:46]; break
        result = "cmd failed" if "failed" in tail.lower() else "ok"
    else:
        when, result, tail = "never", "—", "no run yet"
    rows.append((ch, slots, (human(nxt-now) if nxt else "?"), when, result, tail))

print(f"  {'CHANNEL':<19}{'SLOTS (MYT)':<28}{'NEXT':<13}{'LAST':<13}{'RESULT':<10}LAST OUTPUT")
print(f"  {'-'*18} {'-'*27} {'-'*12} {'-'*12} {'-'*9} {'-'*20}")
for r in rows:
    print(f"  {r[0]:<19}{r[1]:<28}{r[2]:<13}{r[3]:<13}{r[4]:<10}{r[5]}")
PY

echo
echo "  Also scheduled (separate automation, not job-apply):"
echo "    school-calendar   every 2h   runner: school-calendar/run.sh"
echo "                      reads the school Telegram channel → creates Google Calendar events"
echo "                      Telegram only when an event was actually created or deleted"
echo
echo "  See the exact schedule :  crontab -l"
echo "  See the models         :  grep APPLY_MODELS $ROOT/.env"
echo "  Run a channel by hand  :  $ROOT/tools/cron-run.sh <channel>"
echo "  Latest report          :  Telegram chat ${TELEGRAM_CHAT_ID:-}"
