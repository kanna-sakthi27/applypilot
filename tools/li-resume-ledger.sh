#!/usr/bin/env bash
# li-resume-ledger.sh — track the LinkedIn Premium per-application tailored resumes THIS automation
# creates, so a run can keep at most KEEP (default 5) of them on the candidate's LinkedIn account.
#
#   add <jobId> <title> <company> <linkedinResumeName>
#   list                 all entries, oldest first
#   count                how many are recorded
#   over [N]             entries older than the newest N (default 5) — the ones to delete
#   drop <jobId>         forget one after it has been deleted in LinkedIn
#
# Storage: state/li-tailored-resumes.jsonl (append-only, one JSON object per line). Never edit it by
# hand — use these subcommands, so a bad line can never wedge a run.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEDGER="$ROOT/state/li-tailored-resumes.jsonl"
KEEP="${LI_RESUME_KEEP:-5}"
mkdir -p "$(dirname "$LEDGER")"

cmd="${1:-}"; shift || true

case "$cmd" in
  add)
    job="${1:-}"; title="${2:-}"; company="${3:-}"; resume="${4:-}"
    if [ -z "$job" ] || [ -z "$resume" ]; then
      echo "usage: li-resume-ledger.sh add <jobId> <title> <company> <resumeName>" >&2; exit 2
    fi
    python3 - "$LEDGER" "$job" "$title" "$company" "$resume" <<'PY'
import json, sys, time
path, job, title, company, resume = sys.argv[1:6]
with open(path, "a") as fh:
    fh.write(json.dumps({"at": int(time.time()), "jobId": job, "title": title,
                         "company": company, "resume": resume}) + "\n")
print(f"ledger: added {job} ({resume})")
PY
    ;;
  list)
    python3 - "$LEDGER" <<'PY'
import json, sys, os
p = sys.argv[1]
if not os.path.exists(p):
    sys.exit(0)
for line in open(p):
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except ValueError:
        continue
    print("%s\t%s\t%s @ %s" % (d.get("jobId", "?"), d.get("resume", "?"),
                               d.get("title", ""), d.get("company", "")))
PY
    ;;
  count)
    n=0
    [ -f "$LEDGER" ] && n="$(grep -c . "$LEDGER" 2>/dev/null || true)"
    echo "${n:-0}"
    ;;
  over)
    keep="${1:-$KEEP}"
    python3 - "$LEDGER" "$keep" <<'PY'
import json, sys, os
p = sys.argv[1]
keep = int(sys.argv[2])
if not os.path.exists(p):
    sys.exit(0)
rows = [json.loads(l) for l in open(p) if l.strip()]
old = rows if keep <= 0 else rows[:-keep]
for d in old:
    print("%s\t%s\t%s @ %s" % (d.get("jobId", "?"), d.get("resume", "?"),
                               d.get("title", ""), d.get("company", "")))
PY
    ;;
  drop)
    job="${1:-}"
    [ -n "$job" ] || { echo "usage: li-resume-ledger.sh drop <jobId>" >&2; exit 2; }
    python3 - "$LEDGER" "$job" <<'PY'
import json, sys, os
p, job = sys.argv[1], sys.argv[2]
if not os.path.exists(p):
    sys.exit(0)
rows = [json.loads(l) for l in open(p) if l.strip()]
kept = [d for d in rows if d.get("jobId") != job]
with open(p, "w") as fh:
    for d in kept:
        fh.write(json.dumps(d) + "\n")
print("ledger: dropped %s (%d)" % (job, len(rows) - len(kept)))
PY
    ;;
  *)
    sed -n '2,12p' "$0" >&2
    exit 2
    ;;
esac
