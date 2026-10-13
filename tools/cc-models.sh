#!/usr/bin/env bash
# cc-models.sh — which models are configured, and which actually WORK right now.
#
# `cmd --list-models` is the CLI's model catalogue, but it is STALE: on 2026-10-11 it still listed
#   inclusionai/ling-3.0-flash-sante:free   -> a live call returns 404 "unavailable for free"
#   meituan/longcat-2.0:free                -> a live call returns 403 "free tier has been retired"
# as available FREE models. A catalogue entry therefore does NOT prove a model is usable — only a
# live call does. `--probe` makes that call, so a retired slug is caught here instead of costing a
# turn (and a job) inside a real run.
#
# Usage:
#   cc-models.sh                 configured models (APPLY_MODELS) + whether the catalogue lists them
#   cc-models.sh --list          the full `cmd --list-models` catalogue
#   cc-models.sh --probe         live 1-turn probe of EVERY configured model (paid ones cost a little)
#   cc-models.sh --probe-free    live probe of only the FREE models (costs nothing)
#
# Never prints a secret. Reads APPLY_MODELS from the environment, else from this repo's .env.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD_BIN="${JOB_APPLY_CMD:-cmd}"
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

MODE="${1:-summary}"

if [ "$MODE" = "--list" ] || [ "$MODE" = "list" ]; then
  "$CMD_BIN" --list-models
  exit $?
fi

MODELS_RAW="${APPLY_MODELS:-}"
if [ -z "$MODELS_RAW" ] && [ -f "$ROOT/.env" ]; then
  MODELS_RAW="$(sed -n 's/^APPLY_MODELS=//p' "$ROOT/.env" | tail -1)"
fi
if [ -z "$MODELS_RAW" ]; then
  echo "cc-models: APPLY_MODELS is not set (and not in .env)" >&2
  exit 2
fi
IFS=',' read -ra MODELS <<< "$MODELS_RAW"
is_free() { case "$1" in *:free|*-free) return 0 ;; *) return 1 ;; esac; }

if [ "$MODE" = "--probe" ] || [ "$MODE" = "--probe-free" ]; then
  probe_paid=1
  [ "$MODE" = "--probe-free" ] && probe_paid=0
  TMPD="$(mktemp -d)"
  trap 'rm -rf "$TMPD"' EXIT
  printf '%-45s %-5s %s\n' "MODEL" "TIER" "PROBE RESULT"
  printf '%-45s %-5s %s\n' "-----" "----" "------------"
  for m in "${MODELS[@]}"; do
    m="$(printf '%s' "$m" | xargs)"; [ -n "$m" ] || continue
    tier=P; is_free "$m" && tier=F
    if [ "$probe_paid" -eq 0 ] && [ "$tier" = P ]; then
      printf '%-45s %-5s %s\n' "$m" "$tier" "skipped (paid — use --probe to test)"
      continue
    fi
    out="$(cd "$TMPD" && timeout 90 "$CMD_BIN" -p "Reply with exactly: OK" --model "$m" \
            --yolo --skip-onboarding --no-auto-update --max-turns 1 --no-session 2>&1)"
    case "$out" in
      *"unavailable for free"*|*"tier has been retired"*|*"model is unavailable"*|*"model not found"*|*"Unknown model"*)
        verdict="DEAD — retired / not available" ;;
      *"Rate limit exceeded"*|*"rate-limited"*|*"Rate limit"*)
        verdict="RATE-LIMITED" ;;
      *)
        if printf '%s' "$out" | grep -qiE '(^|[^A-Za-z])ok([^A-Za-z]|$)'; then verdict="WORKING"; else verdict="NO RESPONSE"; fi ;;
    esac
    printf '%-46s %-5s %s\n' "$m" "$tier" "$verdict"
  done
  exit 0
fi

CATALOG="$("$CMD_BIN" --list-models 2>/dev/null || true)"
printf '%-45s %-5s %s\n' "MODEL" "TIER" "IN CLI CATALOGUE?"
printf '%-45s %-5s %s\n' "-----" "----" "-----------------"
for m in "${MODELS[@]}"; do
  m="$(printf '%s' "$m" | xargs)"; [ -n "$m" ] || continue
  tier=P; is_free "$m" && tier=F
  if printf '%s' "$CATALOG" | grep -qF "$m"; then incat="yes"; else incat="NO — not listed"; fi
  printf '%-45s %-5s %s\n' "$m" "$tier" "$incat"
done
echo
echo "NOTE: the CLI catalogue is stale — a slug can be listed yet rejected with 404/403 on use."
echo "      Run 'tools/cc-models.sh --probe' to call each model for real and see which actually work."
echo "      'tools/cc-quota --json' still reports plan usage (5h / weekly / monthly) correctly."
