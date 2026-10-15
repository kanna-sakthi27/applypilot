#!/usr/bin/env bash
# tab-cleanup-selftest.sh — regression test for the tab sweep rules (stubbed agent-browser).
#
# Locks down the 2026-10-12 fix:
#   * a run-created [hosts] tab is closed;
#   * a PRE-EXISTING [hosts] tab is PROTECTED (candidate policy keeps job-board tabs herself);
#   * a [reclaim] tab (company ATS / apply page) is closed EVEN IF pre-existing — this is what stops
#     an already-leaked apply tab from living forever;
#   * `reclaim` mode touches ONLY [reclaim] hosts;
#   * chrome-extension:// pages are never touched.
#
# No real browser is driven — the CDP reachability check is the only thing that needs Brave up, so the
# test SKIPS if Brave is not listening.
set -uo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${BRAVE_CDP_PORT:-9222}"

if ! curl -s --max-time 3 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "tab-cleanup-selftest: no browser on CDP ${PORT} — SKIP (start Brave and re-run)"
  exit 0
fi

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
CONF="$T/tab.conf"; SNAP="$T/snap.json"

cat > "$CONF" <<'EOF'
[settings]
max_close = 60
dry_run = no
[hosts]
host: linkedin.com
host: jaabz.com
host: accounts.google.com
[reclaim]
host: greenhouse.io
host: myworkdayjobs.com
EOF

cat > "$T/bin/agent-browser" <<'AB'
#!/usr/bin/env bash
case "${1:-}" in
  connect) exit 0 ;;
  tab) case "${2:-}" in
      list) cat <<'JSON'
{"data":{"tabs":[
 {"tabId":"k1","active":false,"url":"https://www.linkedin.com/feed/"},
 {"tabId":"k2","active":false,"url":"https://web.whatsapp.com/"},
 {"tabId":"n1","active":false,"url":"https://jaabz.com/jobs/1"},
 {"tabId":"r1","active":false,"url":"https://job-boards.greenhouse.io/anthropic/jobs/9"},
 {"tabId":"n2","active":false,"url":"https://acme.myworkdayjobs.com/Careers/job/1"},
 {"tabId":"n3","active":false,"url":"https://accounts.google.com/signin/oauth"},
 {"tabId":"x1","active":false,"url":"chrome-extension://abcdefg/page.html"}
]}}
JSON
        exit 0 ;;
      close) echo "${3:-}" >> "$STUB_CLOSED"; exit 0 ;;
    esac ;;
esac
exit 0
AB
chmod +x "$T/bin/agent-browser"

# Before-snapshot: k1,k2 = the candidate's own; r1 = an ATS tab leaked by a previous run; x1 = extension page.
python3 -c 'import json,sys;json.dump({"ids":["k1","k2","r1","x1"],"urls":{}},open(sys.argv[1],"w"))' "$SNAP"

run() { # <mode> [snapshot]
  export STUB_CLOSED="$T/closed.$1"; : > "$STUB_CLOSED"
  JOB_APPLY_TAB_CONF="$CONF" JOB_APPLY_AGENT_BROWSER="$T/bin/agent-browser" \
    "$SRC/tools/tab-cleanup.sh" "$@" >"$T/out.$1" 2>&1
}
run sweep "$SNAP"
run reclaim

fail=0
has(){ grep -q "$1" "$T/out.$2" && echo "  PASS: $3" || { echo "  FAIL: $3"; fail=1; }; }
absent(){ grep -q "$1" "$T/out.$2" && { echo "  FAIL: $3"; fail=1; } || echo "  PASS: $3"; }
echo "sweep:"
has "closed n1" sweep       "closes run-created board tab"
has "closed r1" sweep       "reclaims pre-existing ATS tab"
has "closed n2" sweep       "closes run-created ATS tab"
has "closed n3" sweep       "closes run-created sign-in tab"
absent "closed k1" sweep    "protects pre-existing the candidate board tab"
absent "closed k2" sweep    "protects the candidate's non-job tab"
absent "closed x1" sweep    "never touches chrome-extension"
echo "reclaim:"
has "closed r1" reclaim     "closes ATS tab"
has "closed n2" reclaim     "closes ATS tab"
absent "closed n1" reclaim  "does NOT touch board tabs"
absent "closed k1" reclaim  "protects the candidate board tab"

echo
echo "tab-cleanup-selftest: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
exit "$fail"
