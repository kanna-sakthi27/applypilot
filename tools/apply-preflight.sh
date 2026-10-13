#!/usr/bin/env bash
# apply-preflight.sh <channel> [--no-login-probe]
#
# Zero-token pre-flight for one job-apply channel. Runs BEFORE the model starts, so anything
# it catches costs nothing instead of a 45-minute run.
#
#   stdout : a PREFLIGHT markdown block that cron-run.sh appends to the channel prompt
#            (today's count / remaining budget / already-applied digest / session state)
#   exit 0 : go
#   exit 3 : BLOCKED — do not start the model; the reason goes to stderr
#
# Everything here is shell only. No model, no tokens.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CH="${1:-}"
LOGIN_PROBE=1
[ "${2:-}" = "--no-login-probe" ] && LOGIN_PROBE=0
# Deep check = open ONE probe tab per site to get a positive "signed out". The browser extension
# leaves this OFF (see plugin/src/shared.js `deepLoginCheck`): a sold extension must never pop a job
# site's home page in front of someone who did not ask for it. A bare cron/CLI run keeps it on, which
# preserves the sign-out block that the launcher's report relies on.
DEEP="${JOB_APPLY_DEEP_LOGIN_CHECK:-1}"

[ -n "$CH" ] || { echo "usage: apply-preflight.sh <channel> [--no-login-probe]" >&2; exit 2; }

PORT="${BRAVE_CDP_PORT:-9222}"
AB_BIN="${JOB_APPLY_AGENT_BROWSER:-agent-browser}"
TODAY="$(date +%F)"

# Every probe tab is recorded here so an interrupt (Ctrl-C, timeout, the extension's Stop button)
# can never strand one in the user's browser.
PROBE_TABS=""
close_probe_tabs() {
  local t
  for t in $PROBE_TABS; do "$AB_BIN" tab close "$t" >/dev/null 2>&1 || true; done
  PROBE_TABS=""
}
trap 'close_probe_tabs' EXIT INT TERM
REG="$ROOT/applied-jobs-registry.md"
# The browser extension can lower or raise this per user; cron runs leave it unset.
DAILY_CAP="${JOB_APPLY_DAILY_CAP:-30}"

# SITES = which site(s) to probe the login state on (a "-" disables probing). CHLOG is derived from
# the channel name below, so a new site only needs <site>-automation/run-log.md + prompts/<site>.md.
case "$CH" in
  linkedin)   SITES="linkedin|https://www.linkedin.com/feed/" ;;
  indeed)     SITES="indeed|https://www.indeed.com/" ;;
  glassdoor)  SITES="indeed|https://www.indeed.com/" ;;
  jaabz)      SITES="jaabz|https://jaabz.com/ linkedin|https://www.linkedin.com/feed/" ;;
  # Workopolis is Indeed-powered: its "Quick apply" is an unauthenticated /out?r= redirect to
  # ca.indeed.com, so the session that decides whether an application can be submitted is the
  # INDEED one. Probing workopolis itself would only produce false "signed out" blocks — exactly
  # the failure mode this preflight was written to avoid. (Same reasoning as glassdoor.)
  workopolis) SITES="indeed|https://www.indeed.com/" ;;
  # jobs.ch — Easy apply is built for registered users (fields + CV pre-filled), so the jobs.ch
  # login IS what makes an apply work; a positive signed-out signal should block and tell the candidate.
  jobs)       SITES="jobs|https://www.jobs.ch/en/" ;;
  selftest)   SITES="" ;;
  *)          echo "unknown channel: $CH" >&2; exit 2 ;;
esac
# The channel's run log (this channel's daily-cap source). Falls back to the pre-rename name.
CHLOG="$ROOT/$CH-automation/run-log.md"
[ -f "$CHLOG" ] || CHLOG="$ROOT/$CH-automation/answers.md"
[ "$CH" = selftest ] && CHLOG="/dev/null"

# A site list of "-" disables login probing entirely (documented in config/channels.conf).
[ "$SITES" = "-" ] && LOGIN_PROBE=0
# A dry run must not touch the browser at all: its whole point is to prove the wiring without
# disturbing anything, and a probe tab is exactly the disturbance this avoids.
PROBE_SKIP=""
if [ "${JOB_APPLY_DRY_RUN:-}" = "1" ] && [ "$LOGIN_PROBE" = 1 ]; then
  LOGIN_PROBE=0
  PROBE_SKIP=" (dry run)"
fi

blocked() { echo "PREFLIGHT BLOCKED ($CH): $1"; echo "[preflight] BLOCKED: $1" >&2; exit 3; }

# --- 1. browser: reach Brave, then make sure "$AB_BIN" is attached to IT -----
# "$AB_BIN" SILENTLY launches its own bundled Chrome (~/."$AB_BIN"/browsers/chrome-*) when it
# is not connected to a CDP endpoint. That browser has none of the candidate's logins, so a run that forgets
# to attach sees "Sign In" everywhere and reports "the candidate is signed out" — burning the whole run on a
# false diagnosis. Verify the attachment by CDP target-id overlap before believing any login state.
cdp_up() { curl -s --max-time 4 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; }
if ! cdp_up; then
  blocked "Brave is not reachable on CDP ${PORT}. Relaunch Brave (or let the launcher do it) and re-run."
fi

attached_to_brave() {
  python3 - "$PORT" "$AB_BIN" <<'PY'
import json, subprocess, sys, urllib.request
port = sys.argv[1]
ab = sys.argv[2] if len(sys.argv) > 2 else "agent-browser"
try:
    cdp = json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list", timeout=4))
except Exception:
    sys.exit(1)
ids = {t.get("id") for t in cdp if t.get("type") == "page"}
r = subprocess.run([ab, "tab", "list", "--json"], capture_output=True, text=True)
try:
    ab = {t["targetId"] for t in json.loads(r.stdout)["data"]["tabs"]}
except Exception:
    sys.exit(1)
sys.exit(0 if ids & ab else 1)
PY
}
# `connect` returns before the daemon has necessarily finished switching browsers — it can still be
# tearing down a bundled Chrome it launched earlier (the extension's own UI touches agent-browser,
# so this happens on UI-driven runs). One immediate check therefore blocked runs that were about to
# be fine. Re-connect and re-check for a few seconds before believing a miss.
ATTACH_TRIES="${JOB_APPLY_ATTACH_TRIES:-6}"
attached=0
attempt=0
while [ "$attempt" -lt "$ATTACH_TRIES" ]; do
  attempt=$((attempt + 1))
  "$AB_BIN" connect "$PORT" >/dev/null 2>&1
  if attached_to_brave; then attached=1; break; fi
  [ "$attempt" -lt "$ATTACH_TRIES" ] && sleep 1
done
if [ "$attached" != "1" ]; then
  blocked ""$AB_BIN" is NOT attached to the candidate's Brave on ${PORT} — it is driving its own bundled Chrome, which has no logins. This is a WRONG-BROWSER problem, not a logout. Fix the attachment ("$AB_BIN" connect ${PORT}) and re-run."
fi

# --- 2. login state -------------------------------------------------------------
# Deliberately NON-INTRUSIVE, and biased AGAINST a false "signed out":
#   reuse : a tab that is already open on an authenticated page proves you are signed in. Nothing is
#           opened and nothing is navigated — this answers the common case without disturbing anyone.
#   deep  : only with JOB_APPLY_DEEP_LOGIN_CHECK=1 — open ONE probe tab, switch "$AB_BIN" to it (it
#           acts on the ACTIVE tab, so switching is not optional), read it, close it, and restore the
#           tab that was active. Every probe tab is tracked so an interrupt cannot strand it.
# Without the deep check, a site with no reusable tab is reported "unknown", and only a POSITIVE
# logged-out signal ever blocks a run.
tabs_json() { "$AB_BIN" tab list --json 2>/dev/null; }

tab_ids() {
  tabs_json | python3 -c 'import json,sys;print(" ".join(t["tabId"] for t in json.load(sys.stdin)["data"]["tabs"]))' 2>/dev/null
}
active_tab() {
  tabs_json | python3 -c 'import json,sys
ts=json.load(sys.stdin)["data"]["tabs"]
print(next((t["tabId"] for t in ts if t.get("active")),""))' 2>/dev/null
}
open_tab_for() { # name -> tabId of a tab that looks like an AUTHENTICATED page for that site
  tabs_json | python3 -c '
import json,sys
name=sys.argv[1]
strong={
 "linkedin": ("linkedin.com", ("/feed","/mynetwork","/jobs")),
 "indeed":   ("indeed.com",   ("/notifications","/myjobs","/account","/settings")),
 "jaabz":    ("jaabz.com",    ("/dashboard","/my-jobs","/profile")),
 "jobs":     ("jobs.ch",     ("/en/applications","/en/account","/en/my-jobs","/en/profile","/en/dashboard")),
}.get(name)
if not strong:
    raise SystemExit(0)
host, paths = strong
for t in json.load(sys.stdin)["data"]["tabs"]:
    u=(t.get("url") or "").lower()
    if host in u and not any(x in u for x in ("/login","/signin","authwall","checkpoint","/logout")):
        if any(p in u for p in paths):
            print(t["tabId"]); break' "$1" 2>/dev/null
}

probe_site() { # name url -> echoes in|out|unknown
  local name="$1" url="$2" host tid prev out before after

  # Reuse first: an already-open authenticated tab is proof, and costs the user nothing.
  local reuse
  reuse="$(open_tab_for "$name")"
  if [ -n "$reuse" ]; then echo in; return; fi

  # No reusable tab. Opening one is the intrusive part, so it only happens when the operator asked
  # for the deep check; otherwise report "unknown", which never blocks.
  [ "$DEEP" = "1" ] || { echo unknown; return; }

  host="$(printf '%s' "$url" | sed -E 's#^https?://([^/]+).*#\1#' | sed 's/^www\.//')"

  prev="$(active_tab)"
  before="$(tab_ids)"
  "$AB_BIN" tab new >/dev/null 2>&1
  after="$(tab_ids)"
  tid="$(python3 -c '
import sys
b=set(sys.argv[1].split()); a=set(sys.argv[2].split())
n=sorted(a-b)
print(n[0] if n else "")
' "$before" "$after" 2>/dev/null)"
  [ -n "$tid" ] || { echo unknown; return; }
  PROBE_TABS="$PROBE_TABS $tid"

  "$AB_BIN" tab "$tid" >/dev/null 2>&1
  "$AB_BIN" open "$url" >/dev/null 2>&1
  "$AB_BIN" wait 3500 >/dev/null 2>&1
  out="$("$AB_BIN" eval "JSON.stringify({u:location.href,t:(document.body?document.body.innerText:'').slice(0,1200)})" 2>/dev/null)"
  "$AB_BIN" tab close "$tid" >/dev/null 2>&1
  PROBE_TABS="${PROBE_TABS/ $tid/}"
  [ -n "$prev" ] && "$AB_BIN" tab "$prev" >/dev/null 2>&1

  local u="${out,,}" verdict=unknown
  # A bot wall is NOT a login problem — signing in will never clear it, so it must be reported as
  # its own thing instead of being lumped in with "signed out".
  if [[ "$out" == *"Additional Verification Required"* || "$out" == *"Troubleshooting Cloudflare"* \
     || "$out" == *"You have been blocked"* || "$out" == *"Just a moment"* \
     || "$out" == *"Enable JavaScript and cookies to continue"* ]]; then
    echo wall; return
  fi
  case "$name" in
    linkedin)
      if [[ "$u" == *authwall* || "$u" == *"/login"* ]]; then verdict=out
      elif [[ "$out" == *"My Network"* || "$out" == *"Start a post"* ]]; then verdict=in; fi ;;
    indeed)
      if [[ "$out" == *"My Jobs"* || "$out" == *"Sign out"* ]]; then verdict=in
      elif [[ "$out" == *"Sign in"* || "$out" == *"Log in"* ]]; then verdict=out; fi ;;
    jaabz)
      if [[ "$out" == *"Sign Out"* || "$out" == *"My Profile"* ]]; then verdict=in
      elif [[ "$out" == *"Sign In"* ]]; then verdict=out; fi ;;
    jobs)
      # jobs.ch header shows "Login" when signed out and an account/name control when signed in.
      if [[ "$out" == *"My applications"* || "$out" == *"Sign out"* || "$out" == *"Log out"* \
         || "$out" == *"My account"* || "$out" == *"My profile"* ]]; then verdict=in
      elif [[ "$u" == *"/login"* || "$out" == *"Register now"* ]]; then verdict=out; fi ;;
  esac

  # A live authenticated TAB outranks a "signed out" probe: the probe can land on a different
  # country host (Indeed serves www/malaysia/ca separately) than the one she is actually signed in on.
  if [ "$verdict" = out ]; then
    local st; st="$(open_tab_for "$name")"
    [ -n "$st" ] && verdict=in
  fi
  echo "$verdict"
}

SESSION_LINES=""
SIGNED_OUT=""
WALLED=""
if [ "$LOGIN_PROBE" = 1 ]; then
  for spec in $SITES; do
    name="${spec%%|*}"; url="${spec#*|}"
    st="$(probe_site "$name" "$url")"
    SESSION_LINES="${SESSION_LINES}- ${name}: ${st}"$'\n'
    case "$st" in
      out)  SIGNED_OUT="${SIGNED_OUT}${SIGNED_OUT:+, }${name}" ;;
      wall) WALLED="${WALLED}${WALLED:+, }${name}" ;;
    esac
  done
fi

# --- 3. budget ------------------------------------------------------------------
APPLIED_TODAY=0
if [ -f "$CHLOG" ]; then
  # grep -c prints 0 AND exits 1 when there are no matches — never add "|| echo 0" here.
  # The leading pipe is OPTIONAL: the model writes §6 rows both ways ("| date | … |" and "date | … |").
  APPLIED_TODAY="$(grep -cE "^[[:space:]]*\|?[[:space:]]*${TODAY}[[:space:]]*\|.*\|[[:space:]]*applied[[:space:]]*\|" "$CHLOG" 2>/dev/null)"
  APPLIED_TODAY="${APPLIED_TODAY:-0}"
fi
REMAINING=$(( DAILY_CAP - APPLIED_TODAY ))
[ "$REMAINING" -lt 0 ] && REMAINING=0

RUNS_TODAY="$(ls -1 "$ROOT/logs/${CH}-${TODAY//-/}"*.log 2>/dev/null | wc -l | tr -d ' ')"

# --- 4. already-applied digest --------------------------------------------------
# Rows may carry the leading/trailing pipe or not, so strip one of each first — then $1=date,
# $2=title, $3=company for BOTH shapes.
DIGEST="$(grep -E "^[[:space:]]*\|?[[:space:]]*20[0-9]{2}-" "$REG" 2>/dev/null \
  | sed -E 's/^[[:space:]]*\|//; s/\|[[:space:]]*$//' \
  | awk -F'|' '{t=$2; c=$3; gsub(/^[ \t]+|[ \t]+$/,"",t); gsub(/^[ \t]+|[ \t]+$/,"",c); if(t!=""&&c!="") print t" @ "c}' \
  | awk '!seen[$0]++' | tail -150)"

# Recently SKIPPED jobs. Without this the model re-opens the same dead leads every run — on
# 2026-09-19 the jaabz run spent 22 M tokens re-probing duplicates it had already skipped.
# Only the last 7 days, deduped and capped, because this goes into the prompt.
SKIPS="$(grep -E "^[[:space:]]*\|?[[:space:]]*20[0-9]{2}-[0-9]{2}-[0-9]{2}[[:space:]]*\|" "$CHLOG" 2>/dev/null \
  | grep -v "RUN SUMMARY" \
  | sed -E 's/^[[:space:]]*\|//; s/\|[[:space:]]*$//' \
  | awk -F'|' -v cutoff="$(date -d '7 days ago' +%F)" '{d=$1; gsub(/[ \t]/,"",d); act=$3; gsub(/^[ \t]+|[ \t]+$/,"",act); if (act=="skipped" && d>=cutoff) {t=$2; gsub(/^[ \t]+|[ \t]+$/,"",t); sub(/,( *[A-Za-z].*)?$/,"",t); if(t!="") print t}}' \
  | awk '!seen[$0]++' | tail -100)"

# --- 5. report ------------------------------------------------------------------
echo "## PREFLIGHT (generated by tools/apply-preflight.sh — shell only, costs no tokens)"
echo
echo "- Now: ${TODAY} $(date +%H:%M) MYT · channel: **${CH}**"
echo "- Brave CDP ${PORT}: up"
if [ "$LOGIN_PROBE" = 1 ]; then
  printf '%s' "$SESSION_LINES"
else
  echo "- session probe: skipped${PROBE_SKIP}"
fi
echo "- Submitted today on **this channel**: ${APPLIED_TODAY}/${DAILY_CAP} → **remaining budget ${REMAINING}**"
echo "- Runs started today for this channel: ${RUNS_TODAY}"
echo "- Start the run with **${REMAINING}** submissions as the ceiling; do not exceed it."
echo
echo "### Already applied — do NOT apply to these again (any channel, dedupe key: company + similar title)"
echo
if [ -n "$DIGEST" ]; then
  printf '%s\n' "$DIGEST" | sed 's/^/- /'
else
  echo "- (registry empty)"
fi

echo
echo "### Already skipped in the last 7 days — do NOT re-open or re-probe these (wasted work)"
echo
if [ -n "$SKIPS" ]; then
  printf '%s\n' "$SKIPS" | sed 's/^/- /'
else
  echo "- (nothing skipped recently)"
fi

if [ -n "$WALLED" ]; then
  blocked "security check (bot wall) on: ${WALLED} — the site is refusing automated access from this browser/IP. This is NOT a login problem, so signing in will not clear it; it usually lifts on its own after a few hours of quiet."
fi
if [ -n "$SIGNED_OUT" ]; then
  blocked "logged out of: ${SIGNED_OUT}. Nothing can be submitted until the candidate signs back in in Brave."
fi

exit 0
