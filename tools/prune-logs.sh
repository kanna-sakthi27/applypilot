#!/usr/bin/env bash
# prune-logs.sh [--dry-run] [--ephemeral DAYS] [--runs DAYS] [--logs DAYS]
#
# Housekeeping for the workspace. Three independent jobs:
#
#   ephemeral  (ON by default, 7 days): the throwaway per-run breadcrumbs the launcher writes and
#              never cleans up — logs/.preflight-<ch>-<stamp>.md, logs/.preflight-*.err and
#              logs/.tabs-before-*.json. These are recreated on every run, so removing the old ones
#              is always safe. They had accumulated to 1000+ files.
#   --runs N   (OFF unless asked): logs/runs/<id>/ directories older than N days. OFF by default
#              because they are the dashboard's history — pass a number to prune them deliberately.
#   --logs N   (OFF unless asked): logs/<channel>-<stamp>.log files older than N days.
#
# AGE IS READ FROM THE FILENAME, NOT THE MTIME. Every run name embeds a YYYYMMDD stamp, and a fresh
# `git clone`/copy resets every mtime to "now" — pruning by mtime would either delete nothing or (on
# a copy made mid-history) delete everything. The embedded date is the one trustworthy signal.
#
# Safety: only ever touches files under this workspace's logs/ dir, never follows symlinks, skips
# anything whose name carries no parseable date, and a missing logs/ dir is a no-op. Best-effort: it
# never fails the caller (cron-run.sh calls it on every run).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="$ROOT/logs"
DRY=0
EPH="${JOB_APPLY_PRUNE_EPHEMERAL_DAYS:-7}"
RUNS=""
CHLOGS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY=1 ;;
    --ephemeral) EPH="${2:-7}"; shift ;;
    --runs)      RUNS="${2:-}"; shift ;;
    --logs)      CHLOGS="${2:-}"; shift ;;
    -*)          echo "unknown flag: $1" >&2; exit 2 ;;
    *)           shift ;;
  esac
  shift
done

[ -d "$LOGS" ] || exit 0

run() { if [ "$DRY" = 1 ]; then echo "would: $*"; else "$@"; fi; }

# The first 8-digit run in a basename is its YYYYMMDD stamp (channel names carry no digits, so the
# stamp is always the first match). Empty when there is none — such an item is never pruned.
name_date() { basename "$1" | grep -oE '[0-9]{8}' | head -1; }
cutoff()    { date -d "-$1 days" +%Y%m%d; }

prune_older_than() { # <days> <rm-flags...> ; paths on stdin
  local days="$1"; shift
  local cut f d
  cut="$(cutoff "$days")" || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    d="$(name_date "$f")"
    [ -n "$d" ] || continue
    [ "$d" -lt "$cut" ] || continue
    run rm "$@" "$f"; n=$((n + 1))
  done
}

n=0
prune_older_than "$EPH" -f < <(find "$LOGS" -maxdepth 1 -type f \
  \( -name '.preflight-*' -o -name '.tabs-before-*' \) 2>/dev/null)

if [ -n "$RUNS" ]; then
  prune_older_than "$RUNS" -rf < <(find "$LOGS/runs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
fi

if [ -n "$CHLOGS" ]; then
  prune_older_than "$CHLOGS" -f < <(find "$LOGS" -maxdepth 1 -type f -name '*-*.log' 2>/dev/null)
fi

DETAIL="ephemeral>${EPH}d"
[ -n "$RUNS" ]   && DETAIL="$DETAIL, runs>${RUNS}d"
[ -n "$CHLOGS" ] && DETAIL="$DETAIL, logs>${CHLOGS}d"
if [ "$DRY" = 1 ]; then
  echo "prune-logs: would remove ${n} item(s) ($DETAIL)"
else
  echo "prune-logs: removed ${n} item(s) ($DETAIL)"
fi
exit 0
