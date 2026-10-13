#!/usr/bin/env bash
# tailor.sh — produce a tailored, claim-guarded CV variant for one posting.
#
#   tailor.sh <jobId> --jd <file> [--title T] [--company C] [--profile P]
#              [--model M] [--variant <file.json>]   # skip the model, use this variant (tests)
#              [--no-render]                          # JSON only, no PDF
#
# Pipeline: build a constrained prompt → model writes a variant JSON → claim_guard audits it →
# render HTML/PDF → ATS-score before/after. If the audit FAILS the variant is discarded and the
# base CV is used, with the rejection recorded. A rejection is a safe outcome, never a crash.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

load_env_defaults() {
  local f="$1" line key
  [ -f "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in ''|'#'*) continue ;; esac
    key="${line%%=*}"
    case "$key" in ''|*[!A-Za-z0-9_]*) continue ;; esac
    [ -n "${!key+x}" ] || export "$line"
  done < "$f"
}
load_env_defaults "$ROOT/.env"

JOB_ID="${1:-}"
shift || true
JD=""; TITLE=""; COMPANY=""; PROFILE="default"; MODEL=""
VARIANT_IN=""; NO_RENDER=0
while [ $# -gt 0 ]; do
  case "$1" in
    --jd)        JD="${2:-}"; shift ;;
    --title)     TITLE="${2:-}"; shift ;;
    --company)   COMPANY="${2:-}"; shift ;;
    --profile)   PROFILE="${2:-}"; shift ;;
    --model)     MODEL="${2:-}"; shift ;;
    --variant)   VARIANT_IN="${2:-}"; shift ;;
    --no-render) NO_RENDER=1 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -n "$JOB_ID" ] || { echo "usage: tailor.sh <jobId> --jd <file> [...]" >&2; exit 2; }
[ -n "$JD" ] && [ -f "$JD" ] || { echo "tailor.sh: --jd <file> is required" >&2; exit 2; }

SOURCE="cv/source/$PROFILE.json"
[ -f "$SOURCE" ] || { echo "tailor.sh: no CV source at $SOURCE" >&2; exit 2; }

OUTDIR="cv/variants"
mkdir -p "$OUTDIR"
VARIANT_OUT="$OUTDIR/$JOB_ID.variant.json"
RESULT="$OUTDIR/$JOB_ID.json"
PDF="$OUTDIR/$JOB_ID.pdf"
LOG="$ROOT/logs/tailor-$JOB_ID.log"

say() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
jqget() { python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('$1',''))"; }

say "tailor start jobId=$JOB_ID profile=$PROFILE source=$SOURCE"

# ---------------------------------------------------------------------------
# 1. Get a variant: either supplied (tests) or produced by the model.
# ---------------------------------------------------------------------------
rm -f "$VARIANT_OUT"
if [ -n "$VARIANT_IN" ]; then
  cp "$VARIANT_IN" "$VARIANT_OUT"
  say "using supplied variant $VARIANT_IN"
else
  export JOB_APPLY_CV_SOURCE="$SOURCE"
  export JOB_APPLY_JD="$JD"
  export JOB_APPLY_JOB_TITLE="$TITLE"
  export JOB_APPLY_JOB_COMPANY="$COMPANY"
  export JOB_APPLY_VARIANT_OUT="$VARIANT_OUT"

  PROMPT="$(cat "$ROOT/prompts/_tailor.md")"
  MODELS="${MODEL:-${APPLY_MODELS:-poolside/laguna-s-2.1-free,deepseek/deepseek-v4-flash}}"
  RC=1
  IFS=',' read -ra ARR <<< "$MODELS"
  for m in "${ARR[@]}"; do
    m="$(echo "$m" | xargs)"; [ -n "$m" ] || continue
    case "$m" in
      *:free|*-free) : ;;
      *) "$ROOT/tools/cc-quota" --gate >/dev/null 2>&1 || { say "quota gate blocks paid $m"; continue; } ;;
    esac
    say "--- tailoring with $m ---"
    if timeout 600 cmd -p "$PROMPT" --yolo --skip-onboarding --no-auto-update \
         --max-turns 40 -n "tailor-$JOB_ID" --model "$m" >>"$LOG" 2>&1; then
      RC=0; break
    fi
    say "model $m failed rc=$?"
  done
  [ "$RC" -eq 0 ] || say "WARNING: no model produced a variant (will fall back to the base CV)"
fi

# ---------------------------------------------------------------------------
# 2. Audit — the veto.
# ---------------------------------------------------------------------------
AUDIT_JSON='{"ok":false,"violations":[],"count":0}'
VERDICT="base"
if [ -f "$VARIANT_OUT" ]; then
  if AUDIT_JSON="$(python3 "$ROOT/tools/claim_guard.py" audit "$SOURCE" "$VARIANT_OUT" 2>>"$LOG")"; then
    VERDICT="tailored"
  else
    VERDICT="rejected"
  fi
else
  AUDIT_JSON='{"ok":false,"violations":[{"kind":"missing","claim":"(no variant)","reason":"the model produced no variant file"}],"count":1}'
  VERDICT="rejected"
fi

VIOLATIONS="$(printf '%s' "$AUDIT_JSON" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(json.dumps(d.get("violations",[])))' 2>/dev/null || echo '[]')"
COUNT="$(printf '%s' "$AUDIT_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("count",0))' 2>/dev/null || echo 0)"

if [ "$VERDICT" != "tailored" ]; then
  say "CLAIM GUARD vetoed the variant ($COUNT violation(s)) — falling back to the base CV"
  printf '%s' "$AUDIT_JSON" | python3 -c '
import json,sys
for v in json.load(sys.stdin).get("violations", []):
    print(f"  - {v[\"kind\"]}: {v[\"claim\"]} ({v[\"reason\"]})")
' 2>/dev/null | tee -a "$LOG"
fi

# ---------------------------------------------------------------------------
# 3. Score + render.
# ---------------------------------------------------------------------------
VARIANT_ARG=""
if [ "$VERDICT" = "tailored" ]; then VARIANT_ARG="$VARIANT_OUT"; fi

BASE_HTML="$OUTDIR/.$JOB_ID.base.html"
TARGET_HTML="$OUTDIR/.$JOB_ID.html"
python3 "$ROOT/tools/cv_render.py" html "$SOURCE" "$BASE_HTML" >>"$LOG" 2>&1
if [ -n "$VARIANT_ARG" ]; then
  python3 "$ROOT/tools/cv_render.py" html "$SOURCE" "$TARGET_HTML" --variant "$VARIANT_ARG" >>"$LOG" 2>&1
else
  cp "$BASE_HTML" "$TARGET_HTML"
fi

BASE_SCORE="$(python3 "$ROOT/tools/ats_score.py" "$SOURCE" "$JD" --html "$BASE_HTML" 2>/dev/null | jqget score)"
TARGET_SCORE="$(python3 "$ROOT/tools/ats_score.py" "$SOURCE" "$JD" ${VARIANT_ARG:+--variant "$VARIANT_ARG"} --html "$TARGET_HTML" 2>/dev/null | jqget score)"

PDF_OK="false"
if [ "$NO_RENDER" -eq 0 ]; then
  if python3 "$ROOT/tools/cv_render.py" pdf "$SOURCE" "$PDF" ${VARIANT_ARG:+--variant "$VARIANT_ARG"} >>"$LOG" 2>&1; then
    PDF_OK="true"
  else
    say "WARNING: PDF rendering failed — the variant JSON is still usable"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Result record.
# ---------------------------------------------------------------------------
python3 - "$RESULT" <<PY
import json
base = int("$BASE_SCORE" or 0)
targ = int("$TARGET_SCORE" or 0)
verdict = "$VERDICT"
# A tailored CV that scores no better is not worth using — say so rather than pretending.
recommend = "tailored" if (verdict == "tailored" and targ > base) else "base"
json.dump({
  "v": 1, "jobId": "$JOB_ID", "profile": "$PROFILE",
  "verdict": verdict,
  "violations": json.loads('''$VIOLATIONS'''),
  "violationCount": int("$COUNT" or 0),
  "ats": {"base": base, "tailored": targ},
  "recommend": recommend,
  "pdf": "$PDF" if "$PDF_OK" == "true" else None,
  "pdfOk": "$PDF_OK" == "true",
  "variant": "$VARIANT_OUT" if verdict == "tailored" else None,
  "source": "$SOURCE",
  "jobTitle": "$TITLE", "jobCompany": "$COMPANY",
}, open("$RESULT", "w"), indent=2)
PY

rm -f "$BASE_HTML" "$TARGET_HTML"

say "tailor done jobId=$JOB_ID verdict=$VERDICT ats=${BASE_SCORE}->${TARGET_SCORE} pdf=$PDF_OK"
cat "$RESULT"
[ "$VERDICT" = "tailored" ]
