#!/usr/bin/env bash
# tab-cleanup.sh — snapshot the open tabs before a run, then close the ones the run left behind.
#
#   tab-cleanup.sh snapshot <file>            record the current tabs (call BEFORE the run)
#   tab-cleanup.sh sweep    <file> [--dry-run] close run-created job tabs (call AFTER the run)
#   tab-cleanup.sh reclaim  [--dry-run]       close leftover ATS/apply tabs NOW (no snapshot needed)
#   tab-cleanup.sh list                       show what is open right now
#
# Safety rules, in order of importance:
#   * [hosts]   tabs: closed ONLY if they did NOT exist in the snapshot AND their host matches.
#   * [reclaim] tabs: closed EVEN IF they existed in the snapshot — company ATS / apply pages the candidate
#     never parks. This is what stops an already-leaked tab from living forever.
#   * Only http(s) tabs; chrome-extension://, file://, devtools:// pages are never touched.
#   * At most `max_close` per pass, looped a few times so a busy run is fully swept.
#
# Everything here is best-effort: a failure never fails the run, and a missing browser is a no-op.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="${JOB_APPLY_TAB_CONF:-$ROOT/config/tab-cleanup.conf}"
PORT="${BRAVE_CDP_PORT:-9222}"
AB_BIN="${JOB_APPLY_AGENT_BROWSER:-agent-browser}"

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

tabs_json() { "$AB_BIN" tab list --json 2>/dev/null; }

if ! command -v "$AB_BIN" >/dev/null 2>&1; then
  echo "tab-cleanup: "$AB_BIN" not on PATH — nothing to do" >&2
  exit 0
fi

# Don't drive a browser that is not there (and don't let "$AB_BIN" start its own).
if ! curl -s --max-time 3 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "tab-cleanup: no browser on CDP ${PORT} — nothing to do" >&2
  exit 0
fi
"$AB_BIN" connect "$PORT" >/dev/null 2>&1

CMD="${1:-}"; shift || true
SNAPSHOT=""
case "$CMD" in
  list|reclaim) ;;
  snapshot|sweep) SNAPSHOT="${1:-}" ;;
  *) usage ;;
esac

case "$CMD" in
  list)
    tabs_json | python3 -c '
import json,sys
try: d=json.load(sys.stdin)["data"]["tabs"]
except Exception: print("(could not read tabs)"); raise SystemExit(0)
for t in d:
    print(t.get("tabId"), "*" if t.get("active") else " ", (t.get("url") or "")[:110], sep="\t")'
    exit 0
    ;;

  snapshot)
    [ -n "$SNAPSHOT" ] || usage
    mkdir -p "$(dirname "$SNAPSHOT")"
    tabs_json | python3 -c '
import json,sys
try: tabs=json.load(sys.stdin)["data"]["tabs"]
except Exception: tabs=[]
json.dump({"ids":[t.get("tabId") for t in tabs],
           "urls":{t.get("tabId"): t.get("url","") for t in tabs}},
          open(sys.argv[1],"w"))' "$SNAPSHOT"
    echo "tab-cleanup: snapshotted $(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["ids"]))' "$SNAPSHOT" 2>/dev/null || echo '?') tab(s) -> $SNAPSHOT"
    exit 0
    ;;
esac

DRY=0
for a in "$@"; do [ "$a" = "--dry-run" ] && DRY=1; done
[ "${JOB_APPLY_CLOSE_TABS:-1}" = "0" ] && { echo "tab-cleanup: disabled by JOB_APPLY_CLOSE_TABS=0"; exit 0; }

if [ "$CMD" = sweep ]; then
  [ -f "$SNAPSHOT" ] || { echo "tab-cleanup: no snapshot at $SNAPSHOT — skipping (cannot tell yours from ours)"; exit 0; }
fi

# reclaim mode has no snapshot: it only ever touches [reclaim] hosts.
if [ "$CMD" = reclaim ]; then
  SNAPSHOT="${JOB_APPLY_EMPTY_SNAPSHOT:-/tmp/.ja-empty-snapshot.json}"
  printf '{"ids":[],"urls":{}}' > "$SNAPSHOT" 2>/dev/null || true
fi

python3 - "$CONF" "$SNAPSHOT" "$DRY" "$AB_BIN" "$CMD" <<'PY'
import json, re, subprocess, sys

conf_path, snap_path, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
ab = sys.argv[4] if len(sys.argv) > 4 else "agent-browser"
mode = sys.argv[5] if len(sys.argv) > 5 else "sweep"

def load_conf(path):
    hosts, reclaim, settings, section = [], [], {}, None
    try:
        for raw in open(path):
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1].strip().lower(); continue
            if section == "hosts" and line.lower().startswith("host:"):
                hosts.append(line.split(":", 1)[1].strip().lower())
            elif section == "reclaim" and line.lower().startswith("host:"):
                reclaim.append(line.split(":", 1)[1].strip().lower())
            elif section == "settings" and "=" in line:
                k, v = line.split("=", 1)
                settings[k.strip().lower()] = v.strip()
    except FileNotFoundError:
        pass
    return hosts, reclaim, settings

HOSTS, RECLAIM, SETTINGS = load_conf(conf_path)
MAX_CLOSE = int(SETTINGS.get("max_close", "60") or 60)
if SETTINGS.get("dry_run", "no").lower() in ("yes", "true", "1"):
    dry = True

def relist():
    try:
        r = subprocess.run([ab, "tab", "list", "--json"], capture_output=True, text=True)
        return json.loads(r.stdout)["data"]["tabs"]
    except Exception:
        return None

def host_of(url):
    try:
        return re.sub(r"^https?://([^/]+).*$", r"\1", url).split(":")[0]
    except Exception:
        return ""

def matches(host, lst):
    return any(host == h or host.endswith("." + h) for h in lst)

def closable(tab, before):
    u = (tab.get("url") or "").lower()
    if not u.startswith(("http://", "https://")):
        return None                       # never touch chrome://, extension, file, devtools
    h = host_of(u)
    if not h:
        return None
    if matches(h, RECLAIM):
        return "reclaim"                  # company ATS/apply page — safe even if pre-existing
    if mode == "sweep" and tab.get("tabId") not in before and matches(h, HOSTS):
        return "host"
    return None

try:
    before = set(json.load(open(snap_path)).get("ids", []))
except Exception:
    if mode == "sweep":
        print("tab-cleanup: unreadable snapshot — refusing to guess"); raise SystemExit(0)
    before = set()

if mode == "reclaim" and not RECLAIM:
    print("tab-cleanup: no [reclaim] hosts configured — nothing to do")
    raise SystemExit(0)

tabs = relist()
if tabs is None:
    print("tab-cleanup: could not list tabs"); raise SystemExit(0)

total = 0
for _ in range(6):                        # a busy run can leave many; loop until clean (bounded)
    cands = [t for t in tabs if closable(t, before)]
    if not cands:
        break
    if len(cands) > MAX_CLOSE:
        print(f"tab-cleanup: {len(cands)} candidates exceeds max_close={MAX_CLOSE}; closing the first {MAX_CLOSE}")
        cands = cands[:MAX_CLOSE]
    closed = 0
    for t in cands:
        tid, url = t.get("tabId"), (t.get("url") or "")[:100]
        if dry:
            print(f"tab-cleanup: WOULD close {tid}  {url}")
            closed += 1
            continue
        r = subprocess.run([ab, "tab", "close", str(tid)], capture_output=True, text=True)
        if r.returncode == 0:
            print(f"tab-cleanup: closed {tid}  {url}")
            closed += 1
        else:
            print(f"tab-cleanup: could not close {tid}  {url} — {(r.stderr or r.stdout).strip()[:120]}")
    total += closed
    if closed == 0 or dry:
        break
    tabs = relist() or []

if total == 0:
    print("tab-cleanup: nothing left behind")
else:
    print(f"tab-cleanup: {'would close' if dry else 'closed'} {total} tab(s)")
PY
rc=$?
exit $rc
