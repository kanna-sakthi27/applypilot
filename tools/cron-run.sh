#!/usr/bin/env bash
# cron-run.sh <channel>  — run one job-application channel headlessly on Command Code.
#
#   * one browser at a time (flock mutex across all channels)
#   * zero-token pre-flight: browser up? logged in? budget left? what is already applied?
#   * one session per run — a model switch or a turn-cap hit RESUMES it instead of redoing the work
#   * free models first, in order; a paid model is only tried while the quota gate allows
#   * full log per run + Telegram report either way
#
# Channels: linkedin | indeed | jaabz | workopolis | jobs | thehub | itjobs | relocate
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

# --- branch guard: the automation runs from `master` only ---------------------
# cron invokes this script by absolute path from this folder. If the folder is
# left on another branch (e.g. after branch work), refuse rather than silently
# running that branch's engine. Do branch work in a separate `git worktree`
# (which keeps `master` checked out here), or set JOB_APPLY_ALLOW_BRANCH=1.
_branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ -n "$_branch" ] && [ "$_branch" != "master" ] && [ "${JOB_APPLY_ALLOW_BRANCH:-0}" != 1 ]; then
  echo "cron-run.sh: refusing to run — repo is on branch '$_branch', not 'master'." >&2
  echo "             Do branch work in a separate worktree, or set JOB_APPLY_ALLOW_BRANCH=1." >&2
  exit 2
fi

# Load .env values ONLY for variables not already present in the environment. That way an
# explicit override — e.g. the parameters the browser extension's native host exports — always
# beats the file, while a plain cron run (nothing pre-set) behaves exactly as it did before.
load_env_defaults() {
  local f="$1" line key
  [ -f "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"      # strip leading whitespace
    case "$line" in ''|'#'*) continue ;; esac
    key="${line%%=*}"
    case "$key" in ''|*[!A-Za-z0-9_]*) continue ;; esac
    [ -n "${!key+x}" ] || export "$line"
  done < "$f"
}
load_env_defaults "$ROOT/.env"

# --- provider plumbing: where usage/cost + the spend gate come from --------------------------
# Everything Command-Code-specific (the session transcripts that carry the REAL cost, the cost
# command, the spend gate) lives in config/provider.conf, so moving to another provider is an edit
# there — not in this launcher. The `:=` defaults reproduce the current behaviour if that file (or
# any one line) is missing.
[ -f "$ROOT/config/provider.conf" ] && . "$ROOT/config/provider.conf"
: "${PROVIDER_NAME:=commandcode}"
: "${USAGE_PROJECTS_DIR:=$HOME/.commandcode/projects}"
: "${USAGE_STATS_CMD:=$ROOT/tools/run-stats.sh}"
: "${QUOTA_CMD:=$ROOT/tools/cc-quota}"

CH=""
DRY_RUN=0
MODE="${JOB_APPLY_MODE:-auto}"
CANDIDATES="${JOB_APPLY_CANDIDATES:-}"
REUSE_RUN_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    DRY_RUN=1 ;;
    --mode)       MODE="${2:-}"; shift ;;
    --candidates) CANDIDATES="${2:-}"; shift ;;
    --run-id)     REUSE_RUN_ID="${2:-}"; shift ;;
    -*)           echo "unknown flag: $1" >&2; exit 2 ;;
    *)            [ -z "$CH" ] && CH="$1" ;;
  esac
  shift
done
[ "${JOB_APPLY_DRY_RUN:-}" = "1" ] && DRY_RUN=1
# Propagate to the pre-flight, which skips its intrusive deep login probe when it knows this is a
# dry run. It reads JOB_APPLY_DRY_RUN, so the value must be EXPORTED — a bare shell var here is
# invisible to the child, and a dry run would otherwise open a probe tab in the candidate's browser.
if [ "$DRY_RUN" = 1 ]; then export JOB_APPLY_DRY_RUN=1; fi
case "$MODE" in auto|scan|apply) ;; *) echo "bad --mode '$MODE' (auto|scan|apply)" >&2; exit 2 ;; esac
if [ -z "$CH" ] || [ ! -f "$ROOT/prompts/$CH.md" ]; then
  echo "usage: cron-run.sh <channel> [--dry-run] [--mode auto|scan|apply] [--candidates <file>] [--run-id <id>]" >&2
  echo "       (no prompt: prompts/${CH}.md)" >&2
  exit 2
fi
if [ "$MODE" = apply ] && [ ! -f "${CANDIDATES:-/nonexistent}" ]; then
  echo "cron-run.sh --mode apply needs --candidates <file> (got '${CANDIDATES:-}')" >&2
  exit 2
fi

# How the channel is named in the report the candidate reads.
case "$CH" in
  linkedin)          CHNAME="LinkedIn" ;;
  indeed)            CHNAME="Indeed" ;;
  jaabz)             CHNAME="Jaabz" ;;
  workopolis)        CHNAME="Workopolis" ;;
  jobs)              CHNAME="Jobs.ch" ;;
  thehub)            CHNAME="The Hub" ;;
  itjobs)            CHNAME="ITJobs.pt" ;;
  relocate)          CHNAME="Relocate.me" ;;
  *)                 CHNAME="$CH" ;;
esac

STAMP="$(date +%Y%m%d-%H%M%S)"
STAMP_EPOCH="$(date +%s)"
LOG="$ROOT/logs/${CH}-${STAMP}.log"
# Shared by cron and the browser extension so they never drive Brave at the same time.
# The env override exists so tests can run without contending with a live job.
LOCK="${JOB_APPLY_LOCK:-/tmp/job-automation-browser.lock}"
TIMEOUT="${APPLY_TIMEOUT_SECONDS:-2700}"
PER_MODEL="${APPLY_PER_MODEL_SECONDS:-1200}"
# Short leash for whichever model runs first. A free model that is throttled or simply stall does it
# for the whole slice, and 600s made that a ten-minute hole in every run. If it WAS working, the loop
# below resumes it on the remaining budget, so a shorter leash costs no work — only the wait.
FIRST_MODEL_CAP="${APPLY_FIRST_MODEL_SECONDS:-300}"
MAXTURNS="${APPLY_MAX_TURNS:-250}"
# Seconds held back for the guaranteed paid fallback (see the final-fallback block after the loop).
# Free models may not consume the whole slice while nothing has worked and a paid model is still
# queued — that is what left runs with no working model once the free slugs were retired (2026-10-11).
PAID_RESERVE="${APPLY_PAID_RESERVE_SECONDS:-420}"
# The model CLI and the browser driver are overridable so a harness can stub them, and so a
# user whose binaries are not on PATH can point at them explicitly.
CMD_BIN="${JOB_APPLY_CMD:-cmd}"
AB_BIN="${JOB_APPLY_AGENT_BROWSER:-agent-browser}"
MODELS="${APPLY_MODELS:-poolside/laguna-s-2.1-free,inclusionai/ling-3.0-flash-sante:free,deepseek/deepseek-v4-flash}"
SESSION="apply-$CH-$STAMP"
# Per-run application target: end the run as soon as this many are submitted, instead of grinding the
# whole time slice. A run that cannot reach it still stops at the time/turn cap.
RUN_TARGET="${APPLY_RUN_TARGET:-10}"
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export HOME="${HOME:?HOME is not set}"

SLUG="$(printf '%s' "$ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/^-\+//; s/-\+$//')"
PROJ="$HOME/.commandcode/projects/$SLUG"

# --- model health ---------------------------------------------------------------
# A model that hit its daily cap, got rate-limited, or twice failed to finish inside the attempt
# cap is not going to behave differently on the next run an hour later. Remember that here so we
# stop burning 10 minutes of wall clock (and a run slot) rediscovering it on every channel.
STATE_DIR="$ROOT/state"; MODEL_STATE="$STATE_DIR/models.state"; STRIKES="$STATE_DIR/model-strikes"
# Compensation ledger: how many applies this channel owes from earlier skips (candidate policy wants 0 skipped —
# every skipped job must be paid for by an applied one). Carried across runs, capped so a genuinely
# dry or external-only board can't build an impossible demand.
DEBT_FILE="$STATE_DIR/apply-debt-$CH"
mkdir -p "$STATE_DIR"
DEBT=0
[ -f "$DEBT_FILE" ] && DEBT="$(cat "$DEBT_FILE" 2>/dev/null)"
case "$DEBT" in ''|*[!0-9]*) DEBT=0 ;; esac

cool_remaining() { # model -> seconds it is out for (0 = usable now)
  [ -f "$MODEL_STATE" ] || { echo 0; return; }
  python3 - "$MODEL_STATE" "$1" <<'PY'
import sys, time
now = int(time.time()); worst = 0
for line in open(sys.argv[1]):
    p = line.rstrip("\n").split("\t")
    if len(p) >= 2 and p[0] == sys.argv[2]:
        try: until = int(p[1])
        except ValueError: continue
        worst = max(worst, until - now)
print(max(worst, 0))
PY
}
cool_model() { printf '%s\t%s\t%s\n' "$1" "$(( $(date +%s) + $2 ))" "${3:-}" >>"$MODEL_STATE"; }
secs_until_8am() {
  python3 -c '
import datetime, time
n = datetime.datetime.now()
t = n.replace(hour=8, minute=0, second=0, microsecond=0)
if t <= n: t += datetime.timedelta(days=1)
print(int(t.timestamp() - time.time()))'
}
strike_count_today() {
  [ -f "$STRIKES" ] || { echo 0; return; }
  grep -c "^$(date +%F)	$1	" "$STRIKES" 2>/dev/null || true
}

mkdir -p "$ROOT/logs"
exec 9>"$LOCK"
say() { echo "[$(date '+%F %T')] $*"; }
# Housekeeping: sweep the throwaway per-run breadcrumbs (.preflight-* / .tabs-before-*) older than a
# week. They are recreated every run and had accumulated to 1000+ files. Shell-only, best-effort,
# and never touches the structured run dirs (those are the dashboard's history). Opt out with
# JOB_APPLY_PRUNE=0.
if [ "${JOB_APPLY_PRUNE:-1}" = 1 ]; then
  "$ROOT/tools/prune-logs.sh" >>"$LOG" 2>&1 || true
fi
# Every message is kept on disk (logs/.last-report-<channel>.txt) so it can be reviewed without
# digging through a run log; the selftest channel stops there instead of messaging the candidate.
notify() {
  local f="$ROOT/logs/.last-report-${CH}.txt"
  cat >"$f"
  [ "$CH" = selftest ] && return 0
  "$ROOT/tools/tg-notify.sh" <"$f"
}

# How many CONFIRMED applications this run has recorded so far (the structured side-channel).
applied_so_far() {
  [ -n "${RUN_DIR:-}" ] && [ -f "$RUN_DIR/applications.jsonl" ] \
    && wc -l <"$RUN_DIR/applications.jsonl" 2>/dev/null || echo 0
}

# Should this channel's slot be skipped? A channel that applied 0 in its last 3 runs is throttled to
# roughly every 6h until it yields again — dry boards (workopolis/jaabz) otherwise burn a
# full AI session every 2h for nothing. Returns 0 = skip this slot, 1 = run.
throttle_skip() {
  [ "${JOB_APPLY_THROTTLE:-1}" = 1 ] || return 1
  local hist n zeros last last_epoch
  hist="$(grep -a "run end channel=$CH " "$ROOT/logs/cron.log" 2>/dev/null | tail -3)"
  n="$(printf '%s\n' "$hist" | grep -c . || true)"
  [ "${n:-0}" -ge 3 ] || return 1
  # Only runs where a model DID work (worked=1) count — a run that applied 0 because every model
  # failed or no-opped is not evidence of a dry channel.
  zeros="$(printf '%s\n' "$hist" | grep 'worked=1' | grep -c 'applied=0 ' || true)"
  [ "${zeros:-0}" -eq 3 ] || return 1
  # Throttled (applied 0 in its last 3 productive runs): allow ONE run per 6h. Measure against the
  # channel's LAST ACTUAL run, not the wall-clock hour — the old `h % 6 == 0` test was never true for
  # a channel scheduled on odd hours (jobs, workopolis), so those were throttled off permanently.
  last="$(grep -a "run end channel=$CH " "$ROOT/logs/cron.log" 2>/dev/null | tail -1 \
          | sed -n 's/^\[\([0-9-]\{10\} [0-9:]\{8\}\)\].*/\1/p')"
  [ -n "$last" ] || return 1
  last_epoch="$(date -d "$last" +%s 2>/dev/null || echo 0)"
  [ "$(( $(date +%s) - last_epoch ))" -ge 21600 ] && return 1
  return 0
}

# --- guard: exactly one browser run at a time -----------------------------
# The lock fd (9) is closed with `9>&-` on every child we spawn that can outlive us — the model, the
# pre-flight and the tab sweep all talk to agent-browser, which keeps a session daemon alive. A child
# that inherited fd 9 would keep the flock held after this script exits, so ONE leftover daemon wedged
# every channel all day ("another run holds the browser lock"). Closing the fd is the real fix.
lock_holders() { # PIDs with $LOCK open (our own included)
  local pid fd
  for pid in /proc/[0-9]*; do
    pid="${pid#/proc/}"
    [ -d "/proc/$pid" ] || continue
    for fd in /proc/"$pid"/fd/*; do
      [ "$(readlink "$fd" 2>/dev/null)" = "$LOCK" ] && { echo "$pid"; break; }
    done
  done
}
LEGIT_HOLDER=0
if ! flock -n 9; then
  # Someone holds the lock. Two very different cases:
  #   (a) a stale leftover child from a PREVIOUS run holds it (the fd-inheritance bug) — no run is
  #       actually in progress, so clear it and carry on;
  #   (b) a REAL run is in progress (a cron-run.sh holds it) — do NOT throw the slot away: wait for it
  #       to finish, then start. the candidate does not want a channel skipped just because another was busy.
  stale_pids=""
  for pid in $(lock_holders); do
    [ "$pid" = "$$" ] && continue
    [ -r "/proc/$pid/cmdline" ] || continue
    case "$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)" in
      *cron-run.sh*) LEGIT_HOLDER=1 ;;
      *) stale_pids="$stale_pids $pid" ;;
    esac
  done
  if [ "$LEGIT_HOLDER" = 0 ] && [ -n "$stale_pids" ]; then
    for pid in $stale_pids; do
      [ -r "/proc/$pid/cmdline" ] || continue
      cmd="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)"
      case "$cmd" in
        *agent-browser*|*command-code/dist/index.mjs*)
          say "clearing stale browser lock held by leftover pid=$pid (${cmd%% *})"
          kill "$pid" 2>/dev/null || true ;;
      esac
    done
    sleep 1
  fi
  # A real run is still going: queue behind it. The wait is capped so a wedged run cannot block the
  # channel forever; the run's own time budget only starts once the lock is in hand.
  if [ "$LEGIT_HOLDER" = 1 ] && ! flock -n 9 2>/dev/null; then
    WAIT="${JOB_APPLY_LOCK_WAIT_SECONDS:-1500}"
    say "another run is still using the browser — waiting up to ${WAIT}s for it to finish, then starting $CH"
    flock -w "$WAIT" 9 2>/dev/null || true
  fi
fi
if ! flock -n 9; then
  say "SKIP $CH — browser lock still held after waiting ${JOB_APPLY_LOCK_WAIT_SECONDS:-1500}s"
  printf 'Job hunt — %s — skipped (browser busy)\n' "$CHNAME" \
    | notify >/dev/null 2>&1 || true
  exit 0
fi
say "browser lock acquired (fd 9)"

# --- yield-based throttle: don't spend a session on a channel that keeps yielding nothing ----------
if throttle_skip; then
  say "SKIP $CH — throttled (applied 0 in its last 3 runs); runs every 6h until it yields again"
  exit 0
fi

# --- per-run model order (provider picker) --------------------------------------------------
# Free models come and go. Rather than a fixed list, ask the provider (config/provider.conf:
# MODELS_PICK_CMD) for TODAY's order — a working free model first, then a cheaper paid model, then
# the final fallback (deepseek latest). If the picker is absent or prints nothing, keep APPLY_MODELS,
# so this is purely additive.
if [ -n "${MODELS_PICK_CMD:-}" ]; then
  PICKED="$(timeout "${APPLY_PICK_TIMEOUT:-180}" $MODELS_PICK_CMD 2>/dev/null || true)"
  # The picker must return ONLY a comma-separated list of model slugs. If it returns anything else
  # (a misconfigured picker, a catalogue dump, an error), reject it and keep APPLY_MODELS — junk must
  # never reach MODELS.
  case "$PICKED" in ''|*[!A-Za-z0-9._,:/-]*) PICKED="" ;; esac
  if [ -n "$PICKED" ]; then MODELS="$PICKED"; say "model order (picked): $MODELS"
  else say "model picker returned nothing usable — using APPLY_MODELS ($MODELS)"; fi
fi

# --- budget governor: near the plan limit → FREE models only, so a scheduled run can never push us
# over. These thresholds are self-imposed and stricter than the hard gate (which only trips at 95/100%).
BUDGET_FREE_ONLY=0
if [ "${JOB_APPLY_BUDGET_GOVERNOR:-1}" = 1 ]; then
  # Read all THREE windows (the hard gate only knows weekly+monthly; the 5-hour burst window matters too).
  gov="$("$QUOTA_CMD" --json 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("ALLOW "); raise SystemExit
def pct(w):
    u, c = w.get("used"), w.get("cap")
    return None if (u is None or not c) else u / c * 100
lim = {"5-hour": float(sys.argv[1]), "weekly": float(sys.argv[2]), "monthly": float(sys.argv[3])}
wins = {"5-hour": d.get("five_hour", {}), "weekly": d.get("weekly", {}), "monthly": d.get("monthly", {})}
hit = [n for n in lim if pct(wins[n]) is not None and pct(wins[n]) >= lim[n]]
print(("BLOCK " + ",".join(hit)) if hit else "ALLOW ")
' "${APPLY_5H_STOP_PCT:-90}" "${APPLY_WEEKLY_STOP_PCT:-95}" "${APPLY_MONTHLY_STOP_PCT:-98}" 2>/dev/null)"
  case "${gov:-ALLOW}" in
    BLOCK*)
      BUDGET_FREE_ONLY=1
      FREE="$(printf '%s' "$MODELS" | tr ',' '\n' | grep -E '(:free|-free)$' | paste -sd, -)"
      if [ -n "$FREE" ]; then
        MODELS="$FREE"
        say "budget governor: ${gov#BLOCK } window(s) near the limit — paid dropped, FREE models only ($MODELS)"
      else
        say "budget governor: near the plan limit and no free models — skipping to protect the budget"
        printf 'Job hunt — %s — skipped (budget)\n' "$CHNAME" \
          | notify >/dev/null 2>&1 || true
        exit 0
      fi ;;
  esac
fi

say "run start channel=$CH models=$MODELS timeout=${TIMEOUT}s maxturns=$MAXTURNS mode=$MODE"
say "log=$LOG session=$SESSION"

# Once a day, nudge the candidate on Telegram about any still-open bank questions (§5), so you can fold the
# answers into bank/core.md. Shell-only and cheap, and independent of how this run turns out.
[ "$CH" != selftest ] && "$ROOT/tools/bank-reminder.sh" >/dev/null 2>&1 || true

# --- structured side-channel ------------------------------------------------
# Every run gets a machine-readable directory alongside its human log. A scan and the apply that
# follows it share ONE directory (--run-id), so the dashboard sees one review cycle, not two runs.
RUN_ID=""
RUN_DIR=""
if [ -n "$REUSE_RUN_ID" ] && [ -d "$ROOT/logs/runs/$REUSE_RUN_ID" ]; then
  RUN_ID="$REUSE_RUN_ID"
  RUN_DIR="$ROOT/logs/runs/$RUN_ID"
  "$ROOT/tools/structured.py" phase "$ROOT" "$RUN_ID" "$MODE" >/dev/null 2>&1 || true
  say "reusing run dir $RUN_DIR (phase=$MODE)"
else
  if RUN_JSON="$("$ROOT/tools/structured.py" new-run "$ROOT" --channel "$CH" --mode "$MODE" \
        --profile "${JOB_APPLY_PROFILE:-default}" 2>>"$LOG")"; then
    RUN_ID="$(printf '%s' "$RUN_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["runId"])' 2>/dev/null)"
    RUN_DIR="$ROOT/logs/runs/$RUN_ID"
    say "run dir $RUN_DIR"
  else
    say "WARNING: could not create a run dir — carrying on without the structured side-channel"
  fi
fi
export JOB_APPLY_RUN_ID="${RUN_ID}" JOB_APPLY_RUN_DIR="${RUN_DIR}"
export JOB_APPLY_MODE="$MODE"
[ -n "$CANDIDATES" ] && export JOB_APPLY_CANDIDATES="$CANDIDATES"

# --- pre-flight (shell only, no model tokens) -----------------------------
PREFLIGHT_FILE="$ROOT/logs/.preflight-$CH-$STAMP.md"
PREFLIGHT_ERR="$ROOT/logs/.preflight-$CH-$STAMP.err"
"$ROOT/tools/apply-preflight.sh" "$CH" >"$PREFLIGHT_FILE" 2>"$PREFLIGHT_ERR" 9>&-
PFRC=$?
if [ "$PFRC" -ne 0 ]; then
  reason="$(head -3 "$PREFLIGHT_ERR" 2>/dev/null)"
  say "PREFLIGHT blocked (exit $PFRC): $reason"
  if [ "$DRY_RUN" = 1 ]; then
    cat "$PREFLIGHT_FILE" 2>/dev/null
    rm -f "$PREFLIGHT_ERR"
    # Same reason as below: a blocked dry run still created a run directory.
    if [ -n "$RUN_DIR" ] && [ -d "$RUN_DIR" ]; then
      "$ROOT/tools/structured.py" finalize "$ROOT" "$RUN_ID" --status blocked >/dev/null 2>&1 || true
    fi
    exit 3
  fi
  # Short reason — ONE line, no dump. the candidate wants to know what happened, not the reasoning.
  case "$reason" in
    *"logged out of:"*)
      who="$(printf '%s' "$reason" | sed -n 's/.*logged out of: *\([^.]*\).*/\1/p' \
        | sed -e 's/indeed/Indeed/g' -e 's/linkedin/LinkedIn/g' -e 's/jaabz/Jaabz/g' -e 's/, / and /g')"
      PLAIN="signed out of ${who}" ;;
    *"NOT attached"*)  PLAIN="browser not attached" ;;
    *"not reachable"*) PLAIN="browser not running" ;;
    *"bot wall"*)
      who="$(printf '%s' "$reason" | sed -n 's/.*bot wall) on: *\([^—]*\).*/\1/p' | sed 's/[[:space:]]*$//')"
      PLAIN="bot wall on ${who}" ;;
    *) PLAIN="$reason" ;;
  esac
  printf "Job hunt — %s — didn't run: %s\n" "$CHNAME" "$PLAIN" | notify >/dev/null 2>&1 || true
  cp "$PREFLIGHT_FILE" "$LOG" 2>/dev/null || true
  rm -f "$PREFLIGHT_ERR"
  # The run directory was created before the pre-flight, so close it out here. Without this it stays
  # at status "running" for ever and the dashboard shows a run that never happened.
  if [ -n "$RUN_DIR" ] && [ -d "$RUN_DIR" ]; then
    "$ROOT/tools/structured.py" finalize "$ROOT" "$RUN_ID" --status blocked >/dev/null 2>&1 || true
  fi
  say "run end channel=$CH verdict=blocked-at-preflight duration=$(( $(date +%s) - STAMP_EPOCH ))s"
  exit 3
fi
rm -f "$PREFLIGHT_ERR"
say "preflight OK (budget/session/dedupe digest built)"

# --- tab hygiene -------------------------------------------------------------
# The prompt asks the agent to close each tab it opens, but a run that is cut off, times out or is
# killed never gets the chance. So: snapshot what is open now, and sweep the leftovers on the way
# out — including via the SIGTERM that `timeout` and the extension's Stop button send.
# The extension's host takes the snapshot before it spawns us and passes the path, so both layers
# sweep against the same baseline. On a plain cron run we take our own.
TABS_BEFORE="${JOB_APPLY_TABS_SNAPSHOT:-$ROOT/logs/.tabs-before-$SESSION.json}"
cleanup_tabs() {
  [ "${JOB_APPLY_CLOSE_TABS:-1}" = "0" ] && return 0
  [ -f "$TABS_BEFORE" ] || return 0
  "$ROOT/tools/tab-cleanup.sh" sweep "$TABS_BEFORE" >>"$LOG" 2>&1 9>&- || true
}
if [ "$DRY_RUN" -eq 0 ]; then
  [ -f "$TABS_BEFORE" ] || "$ROOT/tools/tab-cleanup.sh" snapshot "$TABS_BEFORE" >>"$LOG" 2>&1 9>&- || true
  trap cleanup_tabs EXIT INT TERM
  say "tab snapshot: $TABS_BEFORE; leftovers swept on exit (JOB_APPLY_CLOSE_TABS=${JOB_APPLY_CLOSE_TABS:-1})"
fi

# --- compose the prompt: shared preamble + preflight digest + channel body + mode contract --
# The mode part is appended AFTER the channel body so its rules win: in scan mode the channel's
# apply half must be overridden, and in apply mode only the approved shortlist may be touched.
MODE_PART=""
case "$MODE" in
  scan)  MODE_PART="$ROOT/prompts/_scan.md" ;;
  apply) MODE_PART="$ROOT/prompts/_apply.md" ;;
esac
# Company-ATS channels share a contract of their own (accounts, long forms, the target list).
PROMPT="$(cat "$ROOT/prompts/_shared.md" "$PREFLIGHT_FILE" "$ROOT/prompts/$CH.md" \
          ${MODE_PART:+"$MODE_PART"})"

# Parameters the browser-extension UI set for this run, rendered as a trailing override block so
# they win over the channel body above. Absent for a normal cron run.
if [ -n "${JOB_APPLY_PROMPT_EXTRA:-}" ] && [ -f "${JOB_APPLY_PROMPT_EXTRA}" ]; then
  PROMPT="${PROMPT}

$(cat "$JOB_APPLY_PROMPT_EXTRA")"
  say "plugin overrides applied from ${JOB_APPLY_PROMPT_EXTRA}"
fi

# Hard per-run target, appended after everything else so it wins over the channel body's softer wording.
PROMPT="${PROMPT}

## RUN TARGET — stop when you reach it
Submit **at most ${RUN_TARGET}** applications this run. The moment you reach that number, stop and send
the end-of-run report — do not keep applying. Reaching the target and stopping costs far less than
grinding to the end of the time slice, so do not overrun it."
if [ "${DEBT:-0}" -gt 0 ]; then
  PROMPT="${PROMPT}

## COMPENSATION OWED — ${DEBT} application(s)
Earlier runs skipped ${DEBT} job(s) here without a matching apply. Every skipped job must be paid for by
an applied one: submit at least **${DEBT}** application(s) THIS run, on top of the target above, and do
not stop while you still owe applications and in-scope supply remains."
fi
CONTINUE_PROMPT="Continue this run from exactly where you left off — the browser is still on the page you were working on. Do not re-read any file you have already read. Pick up the next unfinished job and carry it to submit. Finish with the short Telegram report and stop."

# Where this channel records what it did. Snapshot the line count now so the report can say what
# THIS run did rather than re-reading the whole log at the end.
# The channel's run log. Derived from the channel name, so a NEW site only needs
# <site>-automation/run-log.md + prompts/<site>.md — no edit here. (bank/core.md is the pre-rename
# name; selftest and unknown channels have no log.)
CHLOG="$ROOT/$CH-automation/run-log.md"
[ -f "$CHLOG" ] || CHLOG="$ROOT/$CH-automation/bank/core.md"
[ -f "$CHLOG" ] || CHLOG=""
ROWS_BEFORE=0
if [ -n "$CHLOG" ] && [ -f "$CHLOG" ]; then ROWS_BEFORE="$(wc -l <"$CHLOG")"; fi

# Which session transcripts existed BEFORE this run? Anything new is ours. (Testing "modified after
# the marker" instead would match every other session in the project dir — including whichever
# session is driving the run from a terminal — and send us off resuming a session that is not ours.)
BASELINE_SESSIONS="$(ls -1 "$PROJ"/*.jsonl 2>/dev/null | xargs -r -n1 basename | sort | tr '\n' ' ')"
session_exists() {
  local cur
  cur="$(ls -1 "$PROJ"/*.jsonl 2>/dev/null | xargs -r -n1 basename | sort | tr '\n' ' ')"
  [ "$cur" != "$BASELINE_SESSIONS" ]
}

# How many bytes this run's session transcript holds. This is the only trustworthy "did it do
# anything?" signal: when `timeout` kills an attempt, `cmd` is SIGTERMed and never flushes its
# response to stdout, so stdout size is ~empty for a productive run AND a useless one alike.
run_session_bytes() {
  local total=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case " $BASELINE_SESSIONS " in
      *" $(basename "$f") "*) ;;
      *) total=$(( total + $(wc -c <"$f" 2>/dev/null || echo 0) )) ;;
    esac
  done < <(ls -1 "$PROJ"/*.jsonl 2>/dev/null)
  echo "$total"
}

# Did this attempt actually do anything? When `timeout` kills an attempt, or a model answers a
# question and stops, stdout says nothing either way — so count the two signals that persist: lines
# in this run's structured records, and rows in the channel's own log. A model that reads the prompt
# as a document to review leaves every one of them unchanged.
work_count() {
  local n=0 f
  if [ -n "$RUN_DIR" ]; then
    for f in "$RUN_DIR/candidates.jsonl" "$RUN_DIR/decisions.jsonl" "$RUN_DIR/applications.jsonl"; do
      [ -f "$f" ] && n=$(( n + $(wc -l <"$f" 2>/dev/null || echo 0) ))
    done
  fi
  if [ -n "$CHLOG" ] && [ -f "$CHLOG" ]; then
    n=$(( n + $(wc -l <"$CHLOG" 2>/dev/null || echo 0) ))
  fi
  echo "$n"
}

# The first configured PAID model (no :free / -free suffix). Used to hold back a time slice and to run
# the guaranteed fallback when every other model failed.
first_paid() {
  local x
  for x in $(printf '%s' "$MODELS" | tr ',' ' '); do
    case "$x" in ''|*:free|*-free) continue ;; *) printf '%s' "$x"; return ;; esac
  done
}
is_free_model() { case "$1" in *:free|*-free) return 0 ;; *) return 1 ;; esac; }

if [ "$DRY_RUN" = 1 ]; then
  echo "--- dry run: $CH ---"
  echo "prompt bytes : $(printf '%s' "$PROMPT" | wc -c)  (was ~110 KB when it read the bank + ruleset)"
  echo "prompt parts : shared+preflight+channel${MODE_PART:+ +mode_contract}${JOB_APPLY_PROMPT_EXTRA:+ +ui_overrides}"
  echo "run dir      : ${RUN_DIR:-<none>}"
  echo "models       : $MODELS"
  echo "caps         : first=${FIRST_MODEL_CAP}s others=${PER_MODEL}s total=${TIMEOUT}s turns=${MAXTURNS}"
  echo "session name : $SESSION"
  echo "preflight    : $(head -c 200 "$PREFLIGHT_FILE")"
  echo "command      : $CMD_BIN -p <prompt> --yolo --skip-onboarding --no-auto-update --max-turns $MAXTURNS -n $SESSION --model <first model>"
  echo "no model was invoked, nothing was sent."
  rm -f "$PREFLIGHT_ERR" "$PREFLIGHT_FILE"
  # This dry run created its own run dir above (structured.py new-run). Leaving it behind pollutes
  # the dashboard with a run stuck at status "running" for ever, so drop it — but only the one WE
  # made (never a --run-id handed in for reuse), and only under this workspace's logs/runs.
  if [ -z "$REUSE_RUN_ID" ] && [ -n "$RUN_DIR" ]; then
    case "$RUN_DIR" in
      "$ROOT"/logs/runs/*) rm -rf "$RUN_DIR" ;;
    esac
  fi
  exit 0
fi

# Does "no records" mean anything for THIS channel? A channel whose §6 log is /dev/null (selftest)
# records nothing by design — it submits nothing, so it has nothing to record — and condemning it
# for that would fail a run that did exactly what it was asked. Only judge channels that write a log.
guard_applies=1
if [ -z "$CHLOG" ] || [ "$CHLOG" = /dev/null ]; then
  guard_applies=0
fi
# A test can ask to be judged anyway (its stub writes records but has no channel log).
[ "${JOB_APPLY_EXPECT_RECORDS:-}" = "1" ] && guard_applies=1

# --- run: first model fresh, every retry RESUMES the same session ---------
#
# `timeout --foreground` below is load-bearing, not cosmetic. This box's timeout is uutils coreutils
# (0.8.0), and by default on expiry it signals its child AND its own process group:
#
#     kill(child, SIGTERM)   # what you want
#     kill(0, SIGTERM)       # the group — which is OURS when it fails to move the child into a new one
#
# That second call is a race, and when it loses, the run dies at its FIRST attempt cap: no next
# model, no report, run.json left half-written and the run stuck "running" forever. Verified with
# strace: `timeout --foreground` emits only `kill(child, SIGTERM)`, so the cap kills the model and
# nothing else. `-k 10` is the backstop for a model that ignores SIGTERM — SIGKILL it 10s later
# instead of blocking the run on a child that will not die.
RC=1; USED=""; WORKED=0; TRIED=""
START=$(date +%s)
WORK0="$(work_count)"
IFS=',' read -ra ARR <<< "$MODELS"
i=0
while [ "$i" -lt "${#ARR[@]}" ]; do
  m="$(echo "${ARR[$i]}" | xargs)"; i=$((i+1))
  [ -n "$m" ] || continue

  # Skip a model we already know is dead today — no point paying the wall-clock to find out again.
  cool="$(cool_remaining "$m")"
  if [ "$cool" -gt 0 ]; then
    say "skip model=$m — cooling down another $(( cool / 60 ))m (see $MODEL_STATE)"
    continue
  fi

  # Free models ($0) always run. A paid model is only allowed while the quota gate says OK,
  # so a budget-exhausted week ends the run instead of spending.
  case "$m" in
    *:free|*-free) : ;;
    *)
      if ! "$QUOTA_CMD" --gate >/dev/null 2>&1; then
        say "quota gate BLOCKED paid model $m — skipping it for the free fallbacks"
        continue
      fi
      say "paid model $m permitted by quota gate"
      ;;
  esac

  elapsed=$(( $(date +%s) - START ))
  remaining=$(( TIMEOUT - elapsed ))
  if [ "$remaining" -le 90 ]; then
    say "time budget exhausted ($elapsed/${TIMEOUT}s) — skipping $m"
    break
  fi
  # Only a FIRST *free* model gets the short leash, so a throttled free model cannot eat the whole
  # run. A paid model that actually works (deepseek, now first) must get the full slice — leashing
  # it at FIRST_MODEL_CAP would cut the run's real work short.
  attempt="$PER_MODEL"
  case "$m" in
    *:free|*-free) [ "$i" -eq 1 ] && attempt="$FIRST_MODEL_CAP" ;;
  esac
  [ "$attempt" -gt "$remaining" ] && attempt="$remaining"

  # Hold back a slice for the guaranteed paid fallback while nothing has worked yet, so a slow or
  # rate-limited free model cannot consume the whole run and leave the paid model unused. Without
  # this, a run whose free slugs are retired ends "nothing submitted" with the paid model never tried.
  if [ "$WORKED" -eq 0 ]; then
    fp_early="$(first_paid)"
    case "$m" in
      *:free|*-free)
        if [ -n "$fp_early" ]; then
          free_left=$(( TIMEOUT - PAID_RESERVE - ( $(date +%s) - START ) ))
          [ "$free_left" -lt 0 ] && free_left=0
          if [ "$free_left" -le 90 ]; then
            say "free budget spent — reserving ${PAID_RESERVE}s for the paid fallback ($fp_early); moving on"
            continue
          fi
          [ "$attempt" -gt "$free_left" ] && attempt="$free_left"
        fi ;;
    esac
  fi

  sz_before="$( [ -f "$LOG" ] && wc -c <"$LOG" || echo 0 )"
  sess_before="$(run_session_bytes)"
  work_before="$(work_count)"
  # Ignore TERM/INT for the duration of the attempt. Two things send a process-GROUP signal at the
  # cap, and neither is aimed at this script:
  #   * uutils `timeout` sends kill(0, SIGTERM) as well as signalling the child, and when it fails
  #     to move the child into its own group (a race) that group is OURS;
  #   * `cmd` cleans up its own process group on shutdown, and under `--foreground` it shares ours.
  # The result either way is a run that dies at its first attempt cap and never reaches the model
  # that works. The cap must kill the model, not the run. Stop still works: the host escalates to
  # SIGKILL after a few seconds, and sweeps the run's tabs itself.
  trap '' TERM INT
  if [ -n "$USED" ] || session_exists; then
    # Resume the SAME session so the new model inherits everything already done.
    say "--- resume model=$m (cap ${attempt}s) ---"
    timeout --foreground -k 10 "$attempt" "$CMD_BIN" -p "$CONTINUE_PROMPT" \
        --resume "$SESSION" --yolo --skip-onboarding --no-auto-update \
        --max-turns "$MAXTURNS" \
        --model "$m" >>"$LOG" 2>&1 9>&-
    RC=$?
    if [ "$RC" -ne 0 ] && [ "$RC" -ne 8 ] && [ "$RC" -ne 124 ]; then
      # Resume itself may have failed — fall back to a clean start on this model.
      say "resume failed rc=$RC — starting fresh on $m"
      timeout --foreground -k 10 "$attempt" "$CMD_BIN" -p "$PROMPT" \
          --yolo --skip-onboarding --no-auto-update \
          --max-turns "$MAXTURNS" \
          -n "$SESSION" --model "$m" >>"$LOG" 2>&1 9>&-
      RC=$?
    fi
  else
    say "--- attempt model=$m (fresh, cap ${attempt}s) ---"
    timeout --foreground -k 10 "$attempt" "$CMD_BIN" -p "$PROMPT" \
        --yolo --skip-onboarding --no-auto-update \
        --max-turns "$MAXTURNS" \
        -n "$SESSION" --model "$m" >>"$LOG" 2>&1 9>&-
    RC=$?
  fi
  # Restore the real handlers for the rest of the run (the tab sweep lives on EXIT/INT/TERM).
  trap cleanup_tabs EXIT INT TERM
  USED="$m"
  case " $TRIED " in *" $m "*) ;; *) TRIED="${TRIED:+$TRIED }$m" ;; esac

  # Read only what THIS attempt wrote, and learn from it so the next run does not repeat it.
  chunk="$(tail -c +$(( sz_before + 1 )) "$LOG" 2>/dev/null)"
  case "$chunk" in
    # Retired / no-longer-free slugs (e.g. ling-3.0-flash-sante:free -> 404 "unavailable for free",
    # longcat-2.0:free -> 403 "free tier has been retired"). `cmd --list-models` still advertises
    # them, so trust the live error: cool the slug until the next day so it stops eating a turn every
    # run, and fall through to the next model (ultimately the guaranteed paid fallback below).
    *"unavailable for free"*|*"tier has been retired"*|*"model is unavailable"*|*"model not found"*|*"Unknown model"*)
      cool_model "$m" "$(secs_until_8am)" "retired or unavailable"
      say "model=$m is retired/unavailable — cooling it until 08:00 (stops wasting a turn each run)" ;;
    *"reached today's limit"*)
      cool_model "$m" "$(secs_until_8am)" "daily limit"
      say "model=$m is daily-capped — cooling it until 08:00" ;;
    *"Rate limit exceeded"*)
      cool_model "$m" 900 "rate limited"
      say "model=$m rate-limited — cooling it for 15m" ;;
  esac

  work_after="$(work_count)"
  [ "$work_after" -gt "$work_before" ] && WORKED=1

  # Stop the moment the run has reached its application target — the rest of the slice would only
  # spend budget for nothing.
  if [ "$(applied_so_far)" -ge "$RUN_TARGET" ]; then
    say "run target reached ($(applied_so_far) applications) — ending the run early"
    break
  fi

  if [ "$RC" -eq 0 ]; then
    if [ "$work_after" -gt "$work_before" ] || [ "$guard_applies" -eq 0 ]; then
      WORKED=1
      say "model=$m ok"
      break
    fi
    # Exit 0 with nothing to show for it is not a success. A model that reads the prompt as a
    # document to review, or that stalls, ends exactly like this: clean exit, zero applications.
    # Record it as a strike and let the next model try, rather than reporting a run that "completed"
    # while applying to nothing — that silent success is what made the dashboard look dead.
    printf '%s\t%s\tnoop\n' "$(date +%F)" "$m" >>"$STRIKES"
    say "model=$m exited 0 but recorded no work (no §6 rows, no structured records) — trying the next model"
    if [ "$(strike_count_today "$m")" -ge 2 ]; then
      cool_model "$m" 21600 "exits 0 without doing any work"
      say "model=$m did nothing useful twice today — cooling it for 6h"
    fi
    continue
  fi
  if [ "$RC" -eq 8 ]; then
    # A FREE model that hit the turn cap without submitting gets NO resume: hand the rest of the run
    # to the paid fallback now, rather than spending more budget on the free model (candidate policy 2026-10-11:
    # "if free models fail, immediately try deepseek in the same run").
    if is_free_model "$m" && [ "$WORKED" -eq 0 ] && [ -n "$(first_paid)" ]; then
      say "model=$m (free) hit the ${MAXTURNS}-turn cap without submitting — escalating to paid $(first_paid) now"
    elif [ $(( $(date +%s) - START )) -lt $(( TIMEOUT - 300 )) ]; then
      # Turn cap, not a failure: it was doing real work. Resume it to finish the job rather than
      # throwing that work away — but only while the run budget still allows it.
      say "model=$m hit the ${MAXTURNS}-turn cap — resuming the same session to finish"
      # Retry THIS model next (insert at the current position), not the next one in the list.
      ARR=("${ARR[@]:0:$i}" "$m" "${ARR[@]:$i}")
    else
      say "model=$m hit the ${MAXTURNS}-turn cap and the time budget is spent — stopping"
      break
    fi
  elif [ "$RC" -eq 124 ]; then
    sess_growth=$(( $(run_session_bytes) - sess_before ))
    if [ "$sess_growth" -lt 4000 ]; then
      # It genuinely did nothing with its whole slice, so stop paying for it.
      printf '%s\t%s\tattemptcap\n' "$(date +%F)" "$m" >>"$STRIKES"
      if [ "$(strike_count_today "$m")" -ge 2 ]; then
        cool_model "$m" 21600 "no progress inside the attempt cap"
        say "model=$m did nothing twice today (session grew ${sess_growth}B) — cooling it for 6h"
      else
        say "model=$m did nothing in ${attempt}s (session grew ${sess_growth}B) — trying the next model"
      fi
    elif [ $(( $(date +%s) - START )) -lt $(( TIMEOUT - 300 )) ]; then
      if is_free_model "$m" && [ "$WORKED" -eq 0 ] && [ -n "$(first_paid)" ]; then
        # A FREE model that used its whole slice without submitting gets NO resume — escalate to the
        # paid fallback immediately instead of spending the rest of the run on the free model.
        say "model=$m (free) used its ${attempt}s slice without submitting — escalating to paid $(first_paid) now"
      else
        # It WAS working, it just ran out of its slice. Resume it on the leftover budget rather than
        # ending the run with time unspent — this is where the extra applications come from.
        say "model=$m was working (session grew ${sess_growth}B) but hit the ${attempt}s cap — resuming it on the remaining budget"
        # Retry THIS model next, not the next in the list — appending put it at the END, so the resumed
        # session was handed to a no-op free model and the rest of the budget was wasted.
        ARR=("${ARR[@]:0:$i}" "$m" "${ARR[@]:$i}")
      fi
    else
      say "model=$m hit the ${attempt}s cap and the run budget is spent — stopping"
    fi
  else
    say "model=$m failed rc=$RC"
  fi
done

# --- guaranteed paid fallback -------------------------------------------------
# A run must never end "nothing submitted" merely because the free models were unavailable or
# rate-limited AND the paid model happened to be cooling down. If nothing recorded any work, give the
# first configured PAID model ONE attempt regardless of its cooldown — a model we skip is a guaranteed
# failure, so the cooldown is not worth honouring here. The quota gate is still respected: if paid
# spending is blocked, we do not run it (and the run correctly reports "no model"), so this can never
# push the plan past its limit.
if [ "$WORKED" -eq 0 ]; then
  fp="$(first_paid)"
  if [ -n "$fp" ] && [ $(( $(date +%s) - START )) -lt $(( TIMEOUT - 120 )) ]; then
    if ! "$QUOTA_CMD" --gate >/dev/null 2>&1; then
      say "final paid fallback skipped — quota gate blocks paid spending"
    else
      att=$(( TIMEOUT - ( $(date +%s) - START ) )); [ "$att" -gt "$PER_MODEL" ] && att="$PER_MODEL"
      say "--- final paid fallback model=$fp (cap ${att}s, ignoring cooldown) ---"
      trap '' TERM INT
      if [ -n "$USED" ] || session_exists; then
        timeout --foreground -k 10 "$att" "$CMD_BIN" -p "$CONTINUE_PROMPT" \
            --resume "$SESSION" --yolo --skip-onboarding --no-auto-update \
            --max-turns "$MAXTURNS" --model "$fp" >>"$LOG" 2>&1 9>&-
      else
        timeout --foreground -k 10 "$att" "$CMD_BIN" -p "$PROMPT" \
            --yolo --skip-onboarding --no-auto-update \
            --max-turns "$MAXTURNS" -n "$SESSION" --model "$fp" >>"$LOG" 2>&1 9>&-
      fi
      RC=$?
      trap cleanup_tabs EXIT INT TERM
      USED="$fp"
      case " $TRIED " in *" $fp "*) ;; *) TRIED="${TRIED:+$TRIED }$fp" ;; esac
      [ "$(work_count)" -gt "$WORK0" ] && WORKED=1
      if [ "$WORKED" -eq 1 ]; then
        say "final paid fallback model=$fp recorded work"
      else
        say "final paid fallback model=$fp recorded no work either"
      fi
    fi
  fi
fi
DUR=$(( $(date +%s) - START ))

# --- structured side-channel: annotate + finalize -----------------------------
# A scan's candidates get the DETERMINISTIC gate applied here (scope / salary floor / walls /
# language / contract / dedupe), overwriting whatever the model guessed. The model's own counts are
# never trusted: finalize recomputes them from the files.
if [ -n "$RUN_DIR" ] && [ -d "$RUN_DIR" ]; then
  if [ "$MODE" = scan ] && [ -f "$RUN_DIR/candidates.jsonl" ]; then
    if PF="$("$ROOT/tools/prefilter.py" "$ROOT" --in "$RUN_DIR/candidates.jsonl" 2>>"$LOG")"; then
      say "prefilter: $PF"
    else
      say "prefilter failed — candidates left exactly as the scan wrote them"
    fi
  fi
  if FIN="$("$ROOT/tools/structured.py" finalize "$ROOT" "$RUN_ID" --model "${USED:-}" 2>>"$LOG")"; then
    say "run finalized: $(printf '%s' "$FIN" | python3 -c 'import json,sys;d=json.load(sys.stdin);c=d["counts"];print("candidates=%s applied=%s skipped=%s needsReview=%s"%(c["candidates"],c["applied"],c["skipped"],c["needsReview"]))' 2>/dev/null)"
  fi
fi

# No model at all: every one is either daily-capped, rate-limited or benched. Say that plainly —
# "FAILED (exit 1)" tells the candidate nothing and is not a failure of the automation.
if [ -z "$USED" ]; then
  say "no model was available for this run (all cooled/limited)"
  printf "Job hunt — %s — didn't run: no model available\n" "$CHNAME" \
    | notify >/dev/null 2>&1 || true
  say "run end channel=$CH verdict=no-model duration=${DUR}s"
  exit 4
fi

# Every model ran to a clean exit and not one recorded a decision: they are reachable but not doing
# the job. That is the silent failure the operator used to see as "it ran and applied to nothing",
# so name it and make it visible instead of reporting a successful run.
if [ "$WORKED" -eq 0 ]; then
  # No model recorded a single decision: this is a MODEL problem, NOT a dry market.
  say "no model did any work (models=$USED rc=$RC free_only=$BUDGET_FREE_ONLY)"
  printf "Job hunt — %s — didn't run: models produced nothing\n" "$CHNAME" \
    | notify >/dev/null 2>&1 || true
  say "run end channel=$CH verdict=no-work models=$USED duration=${DUR}s applied=0 skipped=0 worked=0"
  exit 4
fi

case "$RC" in
  0)   VERDICT="completed" ;;
  8)   VERDICT="completed — hit the ${MAXTURNS}-turn cap" ;;
  124) VERDICT="stopped at the time slice (partial)" ;;
  *)   VERDICT="FAILED (exit $RC)" ;;
esac

# --- token accounting (kept in the log for the operator, not sent to the candidate) --------
STATS="$("$USAGE_STATS_CMD" --recent 1 2>/dev/null | tail -4)"
[ -n "$STATS" ] && echo "$STATS" >>"$LOG"

# --- report: written for a human. No log paths, no raw token dumps. ----------------
# §6 rows are written by the MODEL and it is NOT consistent about the leading/trailing pipe: some
# arrive as `| date | title | applied | reason |` and some as `date | title | applied | reason`.
# Strip one pipe from each end so BOTH shapes split identically — then $1=date, $2=title,
# $3=action, $4=reason. (Without this a pipe-less row landed the action in $3 and the report printed
# "• applied" instead of the job title — seen on 2026-10-12.)
NEW_ROWS=""; ROWS_NORM=""; APPLIED=0; SKIPPED=0; APPLIED_LIST=""
norm_rows() { sed -E 's/^[[:space:]]*\|//; s/\|[[:space:]]*$//'; }
if [ -n "$CHLOG" ] && [ -f "$CHLOG" ]; then
  NEW_ROWS="$(tail -n +$(( ROWS_BEFORE + 1 )) "$CHLOG" 2>/dev/null)"
  ROWS_NORM="$(printf '%s\n' "$NEW_ROWS" | norm_rows)"
  APPLIED="$(printf '%s\n' "$ROWS_NORM" | awk -F'|' '
    { act=$3; gsub(/^[ \t]+|[ \t]+$/,"",act); if (act=="applied") n++ } END{ print n+0 }')"
  SKIPPED="$(printf '%s\n' "$ROWS_NORM" | awk -F'|' '
    { act=$3; gsub(/^[ \t]+|[ \t]+$/,"",act); if (act=="skipped") n++ } END{ print n+0 }')"
  APPLIED_LIST="$(printf '%s\n' "$ROWS_NORM" | awk -F'|' '
    { act=$3; gsub(/^[ \t]+|[ \t]+$/,"",act); if (act!="applied") next
      t=$2; gsub(/^[ \t]+|[ \t]+$/,"",t); sub(/ \([^)]*\)$/,"",t); if (t!="") print t }' | head -12)"
fi

COSTLINE=""
RUN_SESSIONS=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case " $BASELINE_SESSIONS " in *" $(basename "$f") "*) ;; *) RUN_SESSIONS+=("$f") ;; esac
done < <(ls -1 "$PROJ"/*.jsonl 2>/dev/null)
if [ "${#RUN_SESSIONS[@]}" -gt 0 ]; then
  # REAL cost for THIS run: run-stats sums usage.costUsd from the sessions this run created (field 4
  # is exact USD; field 1 is rounded cents, kept for compatibility).
  BRIEF="$("$USAGE_STATS_CMD" --brief --files "${RUN_SESSIONS[@]}" 2>/dev/null)"
  IFS='|' read -r _CENTS _TURNS _TOKENS USD <<<"$BRIEF"
  [ -n "${USD:-}" ] && COSTLINE="$(printf 'Cost: $%.4f' "$USD")"
fi

# Short and plain (candidate policy 2026-10-15): counts + real cost, then the applied list. No explanations.
MSG="Job hunt — ${CHNAME}
Applied: ${APPLIED} · Skipped: ${SKIPPED}"
[ -n "${USED:-}" ] && MSG="${MSG}
Model: ${USED}"
[ -n "$COSTLINE" ] && MSG="${MSG}
${COSTLINE}"
if [ "$APPLIED" -gt 0 ]; then
  [ -n "$APPLIED_LIST" ] || APPLIED_LIST="(see the channel run log)"
  MSG="${MSG}

Applied to:
$(printf '%s\n' "$APPLIED_LIST" | sed 's/^/• /')"
fi

# --- compensation ledger: carry what this run still owes (only skips that COULD have been applies) ---
# "Already applied / duplicate / closed / external-only" skips are excluded — nothing can turn those
# into an application here, so they must not build an impossible debt.
CONV_SKIPPED=0
if [ -n "${ROWS_NORM:-}" ]; then
  CONV_SKIPPED="$(printf '%s\n' "$ROWS_NORM" | awk -F'|' '
    { act=$3; gsub(/^[ \t]+|[ \t]+$/,"",act); if (act!="skipped") next
      r=tolower($4)
      if (r ~ /already|duplicate|closed|expired|no longer|external|company site|employer site/) next
      # true walls a harder apply cannot convert — must not build an impossible debt
      if (r ~ /sponsor|visa|citizen|right.to.work|authoris|authoriz|clearance|work permit|resid|language|german|french|dutch|hourly|day.rate|per.hour|per.day|fixed.term|below floor|captcha|recaptcha|account|login/) next
      n++ } END{ print n+0 }')"
fi
OWED=$(( ${DEBT:-0} + CONV_SKIPPED - APPLIED ))
[ "$OWED" -lt 0 ] && OWED=0
[ "$OWED" -gt "${APPLY_DEBT_CAP:-20}" ] && OWED="${APPLY_DEBT_CAP:-20}"
printf '%s\n' "$OWED" >"$DEBT_FILE" 2>/dev/null || true
# Debt is carried silently — the Applied/Skipped counts above already show it; no prose (candidate policy 2026-10-15).

printf '%s\n' "$MSG" | notify >/dev/null 2>&1 || true
say "run end channel=$CH verdict=$VERDICT model=$USED duration=${DUR}s applied=$APPLIED skipped=$SKIPPED worked=$WORKED debt=$OWED"
exit "$RC"
