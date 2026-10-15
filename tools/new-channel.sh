#!/usr/bin/env bash
# new-channel.sh <site> — scaffold a new job-site channel.
#
# Creates prompts/<site>.md, <site>-automation/RULESET.md and <site>-automation/run-log.md.
# Answers are NEVER copied — every channel reads the single bank `bank/core.md`. The launcher and
# pre-flight resolve the channel by name, so no code edit is needed. It does NOT touch crontab.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
site="${1:-}"
if [ -z "$site" ]; then
  echo "usage: new-channel.sh <site>   (lowercase slug, e.g. dice, ziprecruiter, xing)" >&2
  exit 2
fi
case "$site" in
  *[!a-z0-9-]*|-[0-9]*) echo "site must be a lowercase slug (letters, digits, dashes)" >&2; exit 2 ;;
esac

dir="$ROOT/$site-automation"
if [ -e "$dir" ] || [ -e "$ROOT/prompts/$site.md" ]; then
  echo "already exists: $dir or prompts/$site.md" >&2
  exit 1
fi

mkdir -p "$dir"

cat > "$dir/run-log.md" <<EOF
# $site — run log

This channel holds ONLY its logs. **Every form answer comes from the single bank \`bank/core.md\`**.
§5 = unanswered questions (candidate policy fills \`bank/OPEN-QUESTIONS.md\`); §6 = this channel run log (the
source of the per-day submission cap). Channel mechanics live in \`RULESET.md\`.

---

## 5. Unanswered questions log (append-only, newest first)

| Date | Job | Question | Status |
|---|---|---|---|
| | | | |

## 6. Run log (append-only)

| Date | Job (title @ company, country) | Action (applied/skipped/needs-review) | Result |
|---|---|---|---|
EOF

cat > "prompts/$site.md" <<EOF
# $site.md — channel body (prepended by prompts/_shared.md)

You are the $site auto-apply run for the candidate. Apply via **$site**'s own apply flow only.

## TODO — fill this in before enabling the channel
- The search URL(s) and query parameters that actually work on $site.
- How to tell an in-page apply from an external "apply on company site" (skip external).
- The step-by-step apply flow and any DOM notes (learn them with one supervised run).
- Where the confirmation appears, so a submission is counted only when it is real.

Everything else — scope, dedupe, answers from \`bank/core.md\`, the STATE contract, caps — comes from
the shared preamble above; do not repeat it here.
EOF

cat > "$dir/RULESET.md" <<EOF
# $site — ruleset (scaffold)

Operating rules for the $site channel. Mirror the structure of the other channels' RULESET.md
(mission, guardrails, search strategy, runtime flow, browser discipline, state, failure modes).

- Answers: only from \`bank/core.md\` (never invent).
- Log: append to \`$site-automation/run-log.md\` §6; registry row on every confirmed submit.
- Caps: 30/channel/day, per-run target 15.
EOF

echo "Created:"
echo "  prompts/$site.md"
echo "  $site-automation/RULESET.md"
echo "  $site-automation/run-log.md"
echo
echo "Next:"
echo "  1. Fill in prompts/$site.md and the RULESET (search URL + apply flow)."
echo "  2. If the site needs a login probe, add it to SITES in tools/apply-preflight.sh."
echo "  3. Add a crontab line:  <min> */2 * * * $ROOT/tools/cron-run.sh $site >> $ROOT/logs/cron.log 2>&1"
echo "  4. Test with: JOB_APPLY_DEEP_LOGIN_CHECK=0 $ROOT/tools/cron-run.sh $site --dry-run"
