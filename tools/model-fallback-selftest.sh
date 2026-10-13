#!/usr/bin/env bash
# model-fallback-selftest.sh — regression test for the two ways a run used to die "nothing submitted".
#
# Scenario A (2026-10-11 outage): the FREE slugs in APPLY_MODELS were retired (404/403) and the paid
#   fallback (deepseek) was cooling down -> no model did work. Expect: retired slugs detected, and the
#   guaranteed paid fallback still records work.
#
# Scenario B (immediate escalation): a FREE model "works" but never finishes and times out. Expect: it
#   is NOT resumed; the run escalates to the paid model AT ONCE in the same run, which then records work.
#
# Both run the REAL tools/cron-run.sh in throw-away sandboxes with STUBBED model + browser binaries
# (JOB_APPLY_CMD / JOB_APPLY_AGENT_BROWSER), so they spend no model tokens and never touch a job board.
# Pre-flight needs Brave on the CDP port; the whole test SKIPS if it is not up.
#
# Usage: tools/model-fallback-selftest.sh
set -uo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${BRAVE_CDP_PORT:-9222}"

if ! curl -s --max-time 3 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "model-fallback-selftest: no browser on CDP ${PORT} — SKIP (start Brave and re-run)"
  exit 0
fi

ALLFAIL=0

# make_sandbox <dir> — engine copy + stubs. STUB_FREE_MODE (dead|slow) selects free-model behaviour.
make_sandbox() {
  local sb="$1"
  mkdir -p "$sb/logs" "$sb/state" "$sb/stubbin"
  tar -C "$SRC" --exclude=logs --exclude=state --exclude=scratchpad --exclude=cv --exclude=bank \
      -cf - . | tar -C "$sb" -xf -
  printf '#!/usr/bin/env bash\nexit 0\n' > "$sb/tools/tg-notify.sh"; chmod +x "$sb/tools/tg-notify.sh"

  cat > "$sb/stubbin/agent-browser" <<'AB'
#!/usr/bin/env bash
case "${1:-}" in
  connect) exit 0 ;;
  tab) case "${2:-}" in
    list) python3 - <<'PY'
import json,urllib.request
try:
    d=json.load(urllib.request.urlopen("http://127.0.0.1:9222/json/list",timeout=4))
except Exception:
    d=[]
pages=[t for t in d if t.get("type")=="page"]
print(json.dumps({"data":{"tabs":[{"tabId":t["id"],"targetId":t["id"],"active":(i==0),"url":t.get("url","")}
      for i,t in enumerate(pages)]}}))
PY
      exit 0 ;;
  esac; exit 0 ;;
esac
exit 0
AB
  chmod +x "$sb/stubbin/agent-browser"

  cat > "$sb/stubbin/cmd" <<'CMD'
#!/usr/bin/env bash
model=""; prev=""
for a in "$@"; do [ "$prev" = "--model" ] && model="$a"; prev="$a"; done
case "$model" in
  *:free|*-free)
    if [ "${STUB_FREE_MODE:-dead}" = "slow" ]; then
      [ -n "${STUB_SESSION_DIR:-}" ] && head -c 6000 /dev/zero | tr '\0' x > "$STUB_SESSION_DIR/stub-session.jsonl"
      sleep 2; exit 124   # emulate a timeout (rc=124) after real session growth
    fi
    echo "Error: 404 This model is unavailable for free. The paid version is available now - use this slug instead: ${model%:*}"
    exit 1 ;;
esac
if [ -n "${JOB_APPLY_RUN_DIR:-}" ]; then
  printf '{"v":1,"runId":"%s","jobId":"stub-1","channel":"jobs","decision":"applied","reason":"stub","at":%s}\n' \
    "${JOB_APPLY_RUN_ID:-}" "$(date +%s)000" >> "$JOB_APPLY_RUN_DIR/decisions.jsonl"
fi
# Deliberately write the row WITHOUT the leading/trailing pipe — the shape the model actually
# produces sometimes, which used to make the Telegram report print "• applied" instead of the title.
d="$(date +%F)"
printf '%s | Stub DevOps Engineer @ Stub AG, Switzerland | applied | stub paid model\n' "$d" \
  >> "$STUB_LOGROOT/jobs-automation/run-log.md"
# Skipped rows with four DIFFERENT causes, to check the report categorises them truthfully
# (external / right-to-work / contract / out-of-scope) instead of lumping them into "wrong role".
{
  printf '%s | Stub Ext @ Co A, Country | skipped | external-only apply (Apply on company site)\n' "$d"
  printf '%s | Stub Clear @ Co B, Country | skipped | requires active Secret clearance + US citizenship\n' "$d"
  printf '%s | Stub Rate @ Co C, Country | skipped | day-rate contract A$850/day\n' "$d"
  printf '%s | Stub Scope @ Co D, Country | skipped | out of scope: MSP client support\n' "$d"
} >> "$STUB_LOGROOT/jobs-automation/run-log.md"
echo "stub paid model recorded work"
exit 0
CMD
  chmod +x "$sb/stubbin/cmd"
}

run_case() { # <sb> <out> <models> <free_mode> [timeout] [per_model] [first] [reserve]
  local sb="$1" out="$2" models="$3" fmode="$4"
  local tmo="${5:-300}" per="${6:-30}" first="${7:-10}" res="${8:-60}"
  sed -i "s#^APPLY_MODELS=.*#APPLY_MODELS=${models}#" "$sb/.env"
  local slug proj
  slug="$(printf '%s' "$sb" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/^-\+//; s/-\+$//')"
  proj="$sb/home/.commandcode/projects/$slug"; mkdir -p "$proj"
  ( cd "$sb" && HOME="$sb/home" STUB_FREE_MODE="$fmode" STUB_LOGROOT="$sb" STUB_SESSION_DIR="$proj" \
    JOB_APPLY_CMD="$sb/stubbin/cmd" JOB_APPLY_AGENT_BROWSER="$sb/stubbin/agent-browser" \
    JOB_APPLY_DEEP_LOGIN_CHECK=0 JOB_APPLY_CLOSE_TABS=0 JOB_APPLY_THROTTLE=0 JOB_APPLY_BUDGET_GOVERNOR=0 \
    JOB_APPLY_LOCK="$sb/tmp.lock" \
    APPLY_TIMEOUT_SECONDS="$tmo" APPLY_PER_MODEL_SECONDS="$per" APPLY_FIRST_MODEL_SECONDS="$first" APPLY_PAID_RESERVE_SECONDS="$res" \
    bash tools/cron-run.sh jobs ) >"$out" 2>&1
}

check() { local name="$1" out="$2" pat="$3"; if grep -q "$pat" "$out"; then echo "  PASS: $name"; else echo "  FAIL: $name"; ALLFAIL=1; echo "    ---- $out ----"; sed 's/^/    /' "$out"; fi; }
check_not() { local name="$1" out="$2" pat="$3"; if grep -q "$pat" "$out"; then echo "  FAIL: $name"; ALLFAIL=1; echo "    ---- $out ----"; sed 's/^/    /' "$out"; else echo "  PASS: $name"; fi; }

# ---------- Scenario A: dead free slugs + cooled paid model -> guaranteed fallback ----------
echo "Scenario A — retired free slugs + cooled paid model:"
SA="$(mktemp -d)"; OA="$(mktemp)"
make_sandbox "$SA"
printf 'deepseek/deepseek-v4-flash\t%s\tpre-seeded cool-down\n' "$(( $(date +%s) + 3600 ))" > "$SA/state/models.state"
run_case "$SA" "$OA" "poolside/laguna-s-2.1-free,inclusionai/ling-3.0-flash-sante:free,deepseek/deepseek-v4-flash" dead
check     "retired free slug detected and cooled"        "$OA" "retired/unavailable"
check     "guaranteed paid fallback attempted"           "$OA" "final paid fallback model=deepseek/deepseek-v4-flash"
check     "run still applied"                            "$OA" "run end channel=jobs verdict=.*applied=1"
check     "report lists the job TITLE (pipe-less row)"   "$SA/logs/.last-report-jobs.txt" "Stub DevOps Engineer @ Stub AG"
check_not "report does not print the action as title"    "$SA/logs/.last-report-jobs.txt" "• applied"
# Skip reasons are categorised by their TRUE cause, not lumped into "wrong role".
RA="$SA/logs/.last-report-jobs.txt"
check     "skip: external categorised"                   "$RA" "only accept applications on the company site"
check     "skip: right-to-work categorised"              "$RA" "require existing work authorization"
check     "skip: contract categorised"                   "$RA" "were hourly / day-rate contracts"
check     "skip: out-of-scope categorised"               "$RA" "were out of scope"
check_not "no vague 'wrong kind of role' label"          "$RA" "wrong kind of role"
rm -rf "$SA" "$OA"

# ---------- Scenario B: free model works but times out -> immediate escalation ----------
echo "Scenario B — free model works then times out (no resume, escalate now):"
SB="$(mktemp -d)"; OB="$(mktemp)"
make_sandbox "$SB"
run_case "$SB" "$OB" "poolside/laguna-s-2.1-free,deepseek/deepseek-v4-flash" slow 900 60 10 120
check     "escalates to paid immediately"                "$OB" "escalating to paid deepseek/deepseek-v4-flash now"
check_not "free model is NOT resumed"                    "$OB" "resuming it on the remaining budget"
check     "paid model then applied"                      "$OB" "run end channel=jobs verdict=.*applied=1"
rm -rf "$SB" "$OB"

echo
echo "model-fallback-selftest: $([ "$ALLFAIL" -eq 0 ] && echo PASS || echo FAIL)"
exit "$ALLFAIL"
