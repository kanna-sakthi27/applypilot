#!/usr/bin/env bash
# run-stats.sh — token + cost accounting for auto-apply runs, read from the Command Code
# session transcripts.
#
#   run-stats.sh --recent [N]                     last N runs (default 12)
#   run-stats.sh --window <start_epoch> <end_epoch>
#   run-stats.sh --since <epoch>
#   run-stats.sh --files <t.jsonl>...             account for exactly these sessions  (what the
#                                                 launcher uses: it passes the sessions THIS run
#                                                 created, so an operator's own session sitting in
#                                                 the same project dir is never billed to the job)
#   --brief                                       print "<cents>|<turns>|<input tokens>" and nothing
#                                                 else, for a plain-English report
#
# A run = one session transcript (a model switch resumes the same session, so attempts do not
# fragment the accounting).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# the CLI names a project dir by lowercasing the cwd and turning every non-alphanumeric into '-'
# /home/user/Documents/Job_Automation -> home-user-documents-job-automation
SLUG="$(printf '%s' "$ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/^-\+//; s/-\+$//')"
PROJ="$HOME/.commandcode/projects/$SLUG"

BRIEF=0
ARGS=()
for a in "$@"; do
  if [ "$a" = "--brief" ]; then BRIEF=1; else ARGS+=("$a"); fi
done
MODE="${ARGS[0]:---recent}"

FILES=()
case "$MODE" in
  --window) S="${ARGS[1]:?start epoch}"; E="${ARGS[2]:?end epoch}" ;;
  --since)  S="${ARGS[1]:?epoch}";       E="$(date +%s)" ;;
  --recent) S=0;                          E="$(date +%s)" ;;
  --files)  shift_n=$(( ${#ARGS[@]} - 1 )); FILES=("${ARGS[@]:1}") ;;
  *) echo "usage: run-stats.sh [--recent [N] | --window <s> <e> | --since <s> | --files <f>...] [--brief]" >&2; exit 2 ;;
esac
N="${ARGS[1]:-12}"
[ "$MODE" = "--recent" ] && N="${ARGS[1]:-12}"

if [ "$MODE" = "--files" ] && [ "${#FILES[@]}" -eq 0 ]; then
  echo "no sessions in window"; exit 0
fi
if [ "$MODE" != "--files" ] && [ ! -d "$PROJ" ]; then
  echo "no session dir at $PROJ" >&2; exit 1
fi

python3 - "$PROJ" "${S:-0}" "${E:-0}" "$MODE" "$N" "$BRIEF" "${FILES[@]}" <<'PY'
import glob, json, os, sys
from datetime import datetime

proj, s, e, mode, n, brief = sys.argv[1:7]
explicit = sys.argv[7:]

def usage_of(path):
    tot = {"in": 0, "out": 0, "cacheRead": 0, "cost": 0.0}
    turns = 0
    for line in open(path, errors="ignore"):
        try:
            o = json.loads(line)
        except Exception:
            continue
        turns += 1
        u = o.get("usage") or (o.get("message") or {}).get("usage") or {}
        if u.get("inputTokens") is not None: tot["in"] += u["inputTokens"] or 0
        if u.get("outputTokens") is not None: tot["out"] += u["outputTokens"] or 0
        if u.get("cacheReadTokens") is not None: tot["cacheRead"] += u["cacheReadTokens"] or 0
        if u.get("costUsd") is not None: tot["cost"] += u["costUsd"] or 0
    return tot, turns

if explicit:
    paths = [p for p in explicit if os.path.exists(p)]
else:
    paths = [f for f in glob.glob(os.path.join(proj, "*.jsonl")) if not f.endswith("checkpoints.jsonl")]
    s, e = float(s), float(e)
    paths = [f for f in paths if s <= os.path.getmtime(f) <= e]

rows = []
for f in paths:
    tot, turns = usage_of(f)
    if turns:
        rows.append((os.path.getmtime(f), f, turns, tot))

rows.sort()
if mode == "--recent":
    rows = rows[-int(n):]

gi = go = gr = 0
gcost = 0.0
for _, _, _, t in rows:
    gi += t["in"]; go += t["out"]; gr += t["cacheRead"]; gcost += t["cost"]

if brief:
    print(f"{round(gcost * 100)}|{sum(r[2] for r in rows)}|{gi}")
    sys.exit(0)

if not rows:
    print("no sessions in window")
    sys.exit(0)

print(f"{'started':<17}{'turns':>6}{'input':>12}{'cacheRead':>12}{'output':>9}{'cost$':>9}  session")
for mt, f, turns, t in rows:
    print(f"{datetime.fromtimestamp(mt):%m-%d %H:%M:%S} {turns:>6}{t['in']:>12,}{t['cacheRead']:>12,}{t['out']:>9,}{t['cost']:>9.4f}  {os.path.basename(f)[:8]}")
print(f"{'TOTAL':<17}{'':>6}{gi:>12,}{gr:>12,}{go:>9,}{gcost:>9.4f}  {len(rows)} run(s)")
print(f"\ncache read = {gr:,}  (a run's context is re-sent every turn, so the static prompt and the")
print("bank size are the biggest levers on the input column.)")
PY
