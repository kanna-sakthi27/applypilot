#!/usr/bin/env bash
# ==============================================================================
# jobapply.sh — ONE entry point for this job-apply engine.
#
#   ./jobapply.sh setup              install deps + create .env, bank and folders (resumable)
#   ./jobapply.sh resume             continue a setup that was stopped part-way
#   ./jobapply.sh add-site NAME [URL] [--cron]
#                                    add a new job site/channel and wire it in
#   ./jobapply.sh bank <list|show|edit|add|answer>
#                                    add / list / answer / edit the answer bank
#   ./jobapply.sh cron <install|remove|show>
#                                    manage the schedule
#   ./jobapply.sh status             show what is set up and which channels exist
#
# Everything reads the single answer bank (bank/core.md); nothing here invents answers.
# Linux + macOS. Safe to re-run: every step checks before it acts.
# ==============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SELF="$ROOT/$(basename "$0")"
cd "$ROOT" || exit 1
STATE="$ROOT/.jobapply-state"

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; N=$'\033[0m'
else B=; G=; Y=; R=; C=; N=; fi
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$*"; }
info() { printf '  %s·%s %s\n' "$C" "$N" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

mark_done() { [ -f "$STATE" ] || : >"$STATE"; grep -qx "$1" "$STATE" 2>/dev/null || echo "$1" >>"$STATE"; }
is_done()   { [ -f "$STATE" ] && grep -qx "$1" "$STATE" 2>/dev/null; }

usage() { sed -n '2,17p' "$SELF" | sed 's/^# \{0,1\}//'; }

channel_names() { # a channel = prompts/<name>.md (skips _shared/_scan/_apply/_tailor/selftest)
  local f n
  for f in prompts/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .md)"
    case "$n" in _*|selftest) continue ;; esac
    printf '%s\n' "$n"
  done
}

# ------------------------------------------------------------------ setup / resume
verify_engine() {
  local fail=0 f
  step "Verifying the engine"
  for f in tools/*.sh; do
    [ -e "$f" ] || continue
    bash -n "$f" 2>/dev/null || { bad "syntax error: $f"; fail=1; }
  done
  [ "$fail" = 0 ] && ok "shell scripts parse"
  if have python3; then
    if python3 -c 'import glob,py_compile,sys
for p in glob.glob("tools/*.py"): py_compile.compile(p, doraise=True)' 2>/dev/null; then ok "python tools compile"; else bad "python syntax error in tools/"; fail=1; fi
  fi
  for t in cron-run.sh run-stats.sh new-channel.sh apply-preflight.sh prefilter.py; do
    [ -e "tools/$t" ] || { bad "missing tools/$t"; fail=1; }
  done
  [ "$fail" = 0 ] && ok "required tools present"
  return "$fail"
}

ensure_file() { # dest template label
  if [ -s "$1" ]; then ok "$1 exists"
  elif [ -f "$2" ]; then cp "$2" "$1" && ok "created $1 from $(basename "$2")"
  else bad "missing template $2"; return 1; fi
}

cmd_setup() {
  printf '%s\n' "${B}Job-apply setup${N} — resumable; re-run any time (setup == resume)."

  step "1/6  Dependencies (node · python3 · cmd · agent-browser · browser)"
  if is_done deps; then ok "already done (skipped)"
  elif have cmd && have agent-browser && have python3 && { have node || have nodejs; }; then
    ok "required tools already present"; mark_done deps
  elif [ -x "$ROOT/install.sh" ]; then
    "$ROOT/install.sh" "$@" && mark_done deps || { bad "installer failed — fix it, then './jobapply.sh resume'"; return 1; }
  else
    bad "install.sh not found and tools are missing — install node>=22, python3, cmd, agent-browser first"; return 1
  fi

  step "2/6  .env (secrets + model list)"
  if [ -s .env ]; then ok ".env exists"
  elif [ -f .env.example ]; then
    cp .env.example .env
    if [ -t 0 ]; then
      printf '  Telegram bot token (from @BotFather, blank to skip): '; read -r TK || true
      if [ -n "${TK:-}" ]; then
        printf '  Telegram chat id (message the bot, read /getUpdates): '; read -r CID || true
        [ -n "${CID:-}" ] || CID=0
        awk -v t="$TK" -v c="$CID" '
          /^TELEGRAM_BOT_TOKEN=/{print "TELEGRAM_BOT_TOKEN=" t; next}
          /^TELEGRAM_CHAT_ID=/{print "TELEGRAM_CHAT_ID=" c; next}
          {print}' .env > .env.tmp && mv .env.tmp .env
        ok ".env created with your Telegram details"
      else warn ".env created — set TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID in it"; fi
    else warn ".env created — edit it to set TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID"; fi
  else bad ".env.example missing"; return 1; fi
  chmod 600 .env 2>/dev/null || true

  step "3/6  The answer bank (bank/core.md)"
  ensure_file bank/core.md bank/core.example.md && mark_done bank
  ensure_file bank/OPEN-QUESTIONS.md bank/OPEN-QUESTIONS.example.md || true
  info "Fill bank/core.md with your real answers — every form answer is read from it."

  step "4/6  Cross-channel registry"
  ensure_file applied-jobs-registry.md applied-jobs-registry.example.md || true

  step "5/6  CV folder"
  mkdir -p linkedin-automation/cv cv/source cv/variants
  ok "folders ready — put your CV at linkedin-automation/cv/CV.pdf (the path named in the bank)"

  step "6/6  Verify"
  if verify_engine; then mark_done setup; else warn "fix the issues above, then run './jobapply.sh resume'"; fi

  printf '\n%sNext:%s\n' "$B" "$N"
  info "1. Edit bank/core.md            (real answers; salary/visa/notice are required)"
  info "2. Add your CV                  linkedin-automation/cv/"
  info "3. ./jobapply.sh cron install   (start the schedule)"
}

# ------------------------------------------------------------------ add-site
slug_ok() { case "$1" in ''|*[!a-z0-9-]*|-[0-9]*) return 1 ;; *) return 0 ;; esac; }

cmd_add_site() {
  local name="" url="" add_cron=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --cron) add_cron=1 ;;
      *) if [ -z "$name" ]; then name="$1"; elif [ -z "$url" ]; then url="$1"; fi ;;
    esac
    shift
  done
  [ -n "$name" ] || { bad "usage: ./jobapply.sh add-site <name> [https://site-url] [--cron]"; return 2; }
  slug_ok "$name" || { bad "name must be a lowercase slug (letters, digits, dashes)"; return 2; }

  step "Scaffold prompts/$name.md + $name-automation/"
  if [ -e "prompts/$name.md" ]; then warn "prompts/$name.md already exists — leaving it alone"
  else ./tools/new-channel.sh "$name" || return 1; fi

  if [ -n "$url" ]; then
    step "Login probe (tools/apply-preflight.sh)"
    if grep -qE "^[[:space:]]*$name\)" tools/apply-preflight.sh; then ok "already present"
    else
      awk -v n="$name" -v u="$url" '{print} /^[[:space:]]*selftest\)/ && !d {printf "  %s) SITES=\"%s|%s\" ;;\n", n, n, u; d=1}' \
        tools/apply-preflight.sh > tools/apply-preflight.sh.tmp && mv tools/apply-preflight.sh.tmp tools/apply-preflight.sh
      ok "added SITES for $name"
    fi
    local host; host="$(printf '%s' "$url" | sed -E 's#^https?://([^/]+).*#\1#' | sed 's/^www\.//')"
    step "Tab cleanup (config/tab-cleanup.conf)"
    if grep -qF "host: $host" config/tab-cleanup.conf; then ok "host already listed"
    else
      awk -v h="$host" '{print} /^\[hosts\]/ && !d {print "host: " h; d=1}' config/tab-cleanup.conf > config/tab-cleanup.conf.tmp && mv config/tab-cleanup.conf.tmp config/tab-cleanup.conf
      ok "added host: $host"
    fi
  fi

  step "Open-questions reminder (tools/bank-reminder.sh)"
  if grep -qE "^for ch in .*\b$name\b" tools/bank-reminder.sh; then ok "already listed"
  else sed -i.bak -E "s/^for ch in ([a-z ]+); do/for ch in \1 $name; do/" tools/bank-reminder.sh && rm -f tools/bank-reminder.sh.bak
    ok "added $name to the reminder loop"; fi

  local line="0  */2 * * * $ROOT/tools/cron-run.sh $name >> $ROOT/logs/cron.log 2>&1"
  step "Schedule"
  if [ "$add_cron" = 1 ] && have crontab; then
    { crontab -l 2>/dev/null; echo "$line"; } | crontab - && ok "crontab: added $name"
  else
    info "add this line to your crontab (or re-run with --cron):"
    printf '    %s\n' "$line"
  fi

  printf '\n%sTodo:%s open prompts/%s.md and fill in the search URL, the apply flow and the DOM notes.\n' "$B" "$N" "$name"
  info "Test it:  tools/cron-run.sh $name --dry-run"
}

# ------------------------------------------------------------------ bank
bank_file() { printf '%s\n' "$ROOT/bank/core.md"; }
cmd_bank() {
  local sub="${1:-list}"; shift 2>/dev/null || true
  case "$sub" in
    list)
      step "Sections in bank/core.md"
      if [ -s "$(bank_file)" ]; then grep -nE '^#{1,3} ' "$(bank_file)" | sed 's/^/  /'; else warn "no bank/core.md — run './jobapply.sh setup'"; fi
      step "Open questions (bank/OPEN-QUESTIONS.md)"
      if [ -s bank/OPEN-QUESTIONS.md ]; then grep -nE '^\s*[-*] ' bank/OPEN-QUESTIONS.md | sed 's/^/  /'; else info "none"; fi ;;
    show)
      [ -s "$(bank_file)" ] || { bad "no bank/core.md — run './jobapply.sh setup'"; return 1; }
      if [ -n "${1:-}" ]; then awk -v s="$1" 'BEGIN{p=0} /^#{1,3} /{p=($0 ~ s)} p' "$(bank_file)"; else cat "$(bank_file)"; fi ;;
    edit)  ${EDITOR:-${VISUAL:-vi}} "$(bank_file)" ;;
    add)
      [ -n "${1:-}" ] || { bad 'usage: ./jobapply.sh bank add "<question> (options if any)"'; return 2; }
      printf -- '- %s\n' "$1" >> bank/OPEN-QUESTIONS.md
      ok "added an open question — answer it in the bank ('bank edit')" ;;
    answer)
      [ -n "${1:-}" ] && [ -n "${2:-}" ] || { bad 'usage: ./jobapply.sh bank answer "<question>" "<answer>"'; return 2; }
      { printf '\n### Q: %s\n%s\n' "$1" "$2"; } >> "$(bank_file)"
      ok "recorded the answer in bank/core.md" ;;
    *) bad "bank <list|show [section]|edit|add \"Q\"|answer \"Q\" \"A\">"; return 2 ;;
  esac
}

# ------------------------------------------------------------------ cron
cron_block() { # every_hours [stagger_minutes]
  local every="${1:-2}" stagger="${2:-12}" i=0 n m slots
  slots=$(( 60 / stagger )); [ "$slots" -lt 1 ] && slots=1
  printf '# jobapply.sh — managed schedule (every %sh, staggered %sm)\n' "$every" "$stagger"
  for n in $(channel_names); do
    m=$(( (i % slots) * stagger + (i / slots) ))
    printf '%d */%d * * * %s/tools/cron-run.sh %s >> %s/logs/cron.log 2>&1\n' "$m" "$every" "$ROOT" "$n" "$ROOT"
    i=$(( i + 1 ))
  done
  printf '# end jobapply\n'
}
cmd_cron() {
  local sub="" every=2 stagger=12
  while [ $# -gt 0 ]; do
    case "$1" in
      install|remove|show) sub="$1" ;;
      --every)   every="${2:-2}";  shift ;;
      --stagger) stagger="${2:-12}"; shift ;;
    esac
    shift
  done
  have crontab || { bad "no crontab on this system"; return 1; }
  case "$sub" in
    install)
      { crontab -l 2>/dev/null | sed '/# jobapply.sh — managed schedule/,/^# end jobapply/d'; cron_block "$every" "$stagger"; } | crontab -
      ok "installed the schedule ($(channel_names | wc -l | tr -d ' ') channels, every ${every}h, staggered ${stagger}m)" ;;
    remove)
      crontab -l 2>/dev/null | sed '/# jobapply.sh — managed schedule/,/^# end jobapply/d' | crontab -
      ok "removed the managed schedule" ;;
    show) crontab -l 2>/dev/null | sed -n '/# jobapply.sh — managed schedule/,/^# end jobapply/p' ;;
    *) bad "cron <install|remove|show> [--every H] [--stagger M]"; return 2 ;;
  esac
}

# ------------------------------------------------------------------ status
cmd_status() {
  step "Setup state"
  if [ -f "$STATE" ]; then sed 's/^/  ✓ /' "$STATE"; else warn "not set up yet — run './jobapply.sh setup'"; fi
  step "Key files"
  for f in .env bank/core.md applied-jobs-registry.md linkedin-automation/cv/CV.pdf; do
    [ -s "$f" ] && ok "$f" || warn "$f missing"
  done
  step "Channels ($(channel_names | wc -l | tr -d ' '))"
  channel_names | sed 's/^/  • /'
  step "Schedule"
  if have crontab; then printf '  cron-run lines: %s\n' "$(crontab -l 2>/dev/null | grep -c 'cron-run.sh')"; fi
}

# ------------------------------------------------------------------ dispatch
case "${1:-}" in
  setup|resume) shift; cmd_setup "$@" ;;
  add-site)     shift; cmd_add_site "$@" ;;
  bank)         shift; cmd_bank "$@" ;;
  cron)         shift; cmd_cron "$@" ;;
  status)       cmd_status ;;
  ""|-h|--help) usage ;;
  *) bad "unknown command: $1"; echo; usage; exit 2 ;;
esac
