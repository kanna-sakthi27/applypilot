#!/usr/bin/env bash
# Send a Telegram message to the operator. Text on stdin (or after the flags). Never fails the caller.
#   tg-notify.sh [--html|--markdown] [text]   (text on stdin if not given)
# Default is plain text — existing callers are unaffected. --html lets the caller bold headings
# (<b>…</b>) so the message is scannable on mobile instead of one wrapped paragraph. The caller is
# responsible for escaping &, < and > in --html mode.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$HERE/.env" ] && set -a && . "$HERE/.env" && set +a
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN missing}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID missing}"

MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --html)     MODE="HTML"; shift ;;
    --markdown) MODE="Markdown"; shift ;;
    *)          break ;;
  esac
done

TEXT="${1-$(cat)}"
[ -n "$TEXT" ] || exit 0
# Telegram caps messages at 4096 chars.
TEXT="${TEXT:0:4000}"

ARGS=(-s --max-time 25 -X POST
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
  -d chat_id="${TELEGRAM_CHAT_ID}"
  --data-urlencode "text=${TEXT}")
[ -n "$MODE" ] && ARGS+=(-d "parse_mode=${MODE}")

resp=$(curl "${ARGS[@]}" 2>&1) || true

case "$resp" in
  *'"ok":true'*) echo "telegram: sent" ;;
  *) echo "telegram: FAILED ($resp)" >&2; exit 1 ;;
esac
