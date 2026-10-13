#!/usr/bin/env bash
# cv-rotate.sh [dir] [keep] [--dry-run]
#
# Keep the newest N files in a directory, delete the older ones. Default: cv/variants, keep 5.
# The local half of the "keep only 5 custom CVs" rule (the LinkedIn-stored half is handled in the
# browser by prompts/linkedin.md, using tools/li-resume-ledger.sh to know which are ours).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/cv/variants"
KEEP=5
DRY=0
args=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    *) args+=("$a") ;;
  esac
done
[ "${#args[@]}" -ge 1 ] && DIR="${args[0]}"
[ "${#args[@]}" -ge 2 ] && KEEP="${args[1]}"

[ -d "$DIR" ] || exit 0
[ "$KEEP" -ge 1 ] || exit 0

# newest first by mtime; everything after the first KEEP is a deletion candidate.
mapfile -t OLD < <(ls -1t "$DIR" 2>/dev/null | tail -n +$((KEEP + 1)))
[ "${#OLD[@]}" -eq 0 ] && exit 0

for f in "${OLD[@]}"; do
  if [ "$DRY" = 1 ]; then
    echo "would delete $DIR/$f"
  else
    rm -f "$DIR/$f" && echo "deleted $DIR/$f"
  fi
done
