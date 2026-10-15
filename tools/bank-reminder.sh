#!/usr/bin/env bash
# bank-reminder.sh [--force] [--print]
#
# Periodic Telegram nudge: lists the still-open questions in each channel's §5 log so the candidate can fold
# the answers into bank/core.md. Sends at most ONCE PER DAY (marker in logs/), so a launcher that
# calls it on every 2-hour run still messages your only once. Shell-only — costs no model tokens.
#
#   --force : send even if it already sent today
#   --print : print the message instead of sending (for testing)
#
# The message is sent as Telegram HTML (bold headings, one bullet per question) so it stays readable
# on a phone instead of collapsing into one wrapped paragraph.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARK="$ROOT/logs/.bank-reminder-last"
TODAY="$(date +%F)"
FORCE=0; PRINT=0
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    --print) PRINT=1 ;;
  esac
done

if [ "$FORCE" = 0 ] && [ "$PRINT" = 0 ] \
   && [ -f "$MARK" ] && [ "$(cat "$MARK" 2>/dev/null)" = "$TODAY" ]; then
  exit 0
fi

# One TSV line (date \t job \t question) per still-open row in a file's §5 table. A row counts only
# when its Status cell asks for an answer (⏳ / needs-answer / needs the candidate / needs-review / open /
# unanswered) and is not ✅ resolved — so a "blocked (security checkpoint)" row is left out.
# Layout: | Date | Job | Question | Status |
collect() {
  [ -f "$1" ] || return 0
  awk '
    /^##[[:space:]]*5\./ { inb=1; next }
    /^##[[:space:]]*6\./ { inb=0 }
    !inb { next }
    /^[[:space:]]*\|/ {
      if ($0 ~ /✅/) next
      if ($0 ~ /^[[:space:]]*\|[[:space:]]*-+/) next
      if ($0 ~ /Date[[:space:]]*\|[[:space:]]*Job/) next
      n = split($0, c, "|")
      if (n < 6) next
      d = c[2]; j = c[3]; q = c[4]; st = c[5]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", d)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", j)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", q)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", st)
      if (j == "" || q == "") next
      if (tolower(st) !~ /needs-answer|needs the candidate|needs-review|needs review|unanswered|⏳|open/) next
      printf "%s\t%s\t%s\n", d, j, q
    }
  ' "$1"
}

# §5 lives in the channel's run-log.md; fall back to the old bank/core.md during/after the rename.
chlog() { local f="$ROOT/$1-automation/run-log.md"; [ -f "$f" ] && { echo "$f"; return; }
          f="$ROOT/$1-automation/bank/core.md"; [ -f "$f" ] && echo "$f"; }

esc()   { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
title() { awk '{print toupper(substr($0,1,1)) substr($0,2)}'; }

BODY=""
for ch in linkedin indeed jaabz workopolis jobs thehub itjobs relocate; do
  f="$(chlog "$ch")"; [ -n "$f" ] || continue
  rows="$(collect "$f" | head -8 | esc)"
  [ -n "$rows" ] || continue
  items="$(printf '%s\n' "$rows" | awk -F'\t' '{printf "• [%s] %s\n    %s\n", $1, $2, $3}')"
  BODY="${BODY}<b>$(printf '%s' "$ch" | title)</b>
${items}

"
done

# Nothing open — stay quiet.
[ -n "$BODY" ] || exit 0

MSG="<b>Job hunt — question bank needs answers</b>

These screening questions aren't in bank/core.md yet, so jobs that ask them are skipped:

${BODY}<b>Add them here:</b> bank/OPEN-QUESTIONS.md (a blank 'Your answer:' line per question).
Or just reply here and I'll fold them into bank/core.md, which the runs read."

if [ "$PRINT" = 1 ]; then
  printf '%s\n' "$MSG"
  exit 0
fi

printf '%s\n' "$MSG" | "$ROOT/tools/tg-notify.sh" --html >/dev/null 2>&1 || exit 0
printf '%s\n' "$TODAY" >"$MARK"
