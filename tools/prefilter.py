#!/usr/bin/env python3
"""prefilter.py — deterministic, zero-token pre-filter for discovered jobs.

Its verdict is AUTHORITATIVE: it overwrites the scope/gate/dedupe a scan phase guessed, then
returns the annotated set. Running this before anything else is scored is what keeps the
two-phase model affordable.

    prefilter.py <workspace> --in <candidates.jsonl> [--out <file>] [--no-dedupe]
    prefilter.py <workspace> --raw              # JSON array on stdin, annotated JSON on stdout
    prefilter.py --rules <workspace>            # dump the parsed rule table (debugging)

Exit codes: 0 ok · 2 usage.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import structured  # noqa: E402

CURRENCY_ALIASES = {
    "usd": "USD", "$": None, "us$": "USD", "usd$": "USD",
    "gbp": "GBP", "£": "GBP",
    "eur": "EUR", "€": "EUR",
    "sgd": "SGD", "s$": "SGD",
    "cad": "CAD", "c$": "CAD", "ca$": "CAD",
    "aud": "AUD", "a$": "AUD", "au$": "AUD",
    "aed": "AED", "sar": "SAR", "qar": "QAR",
    "inr": "INR", "₹": "INR", "rs": "INR",
    "myr": "MYR", "rm": "MYR",
    "hkd": "HKD", "nzd": "NZD", "chf": "CHF",
    "ron": "RON", "lei": "RON", "jpy": "JPY", "yen": "JPY", "¥": "JPY",
}

# A bare "$" is resolved by the job's country.
DOLLAR_BY_COUNTRY = {
    "canada": "CAD", "australia": "AUD", "singapore": "SGD",
    "united states": "USD", "usa": "USD", "us": "USD",
    "hong kong": "HKD", "new zealand": "NZD",
}

PERIOD_MONTHLY = {"month", "mo", "pm", "pcm", "monthly"}
PERIOD_ANNUAL = {"year", "yr", "pa", "p.a", "annum", "annual", "annually", "p.a."}
PERIOD_HOURLY = {"hour", "hr", "hourly"}
PERIOD_DAILY = {"day", "daily"}


# ---------------------------------------------------------------------------
# Rule parsing
# ---------------------------------------------------------------------------

class Rules:
    def __init__(self, path: Path):
        self.path = path
        self.sections: dict[str, list[tuple[re.Pattern, str]]] = {}
        self.scalars: dict[str, float] = {}
        self.floors: dict[str, float] = {}
        self.fx: dict[str, float] = {}
        self._parse()

    def _parse(self):
        section = None
        for raw in self.path.read_text().splitlines():
            if raw.strip().startswith("#"):
                continue
            line = raw.strip()
            if not line:
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1].strip()
                self.sections.setdefault(section, [])
                continue
            if section is None:
                continue

            # `pattern:` lines first — their `=>` reason separator also contains `=`, so the
            # scalar branch below must not see them.
            if line.lower().startswith("pattern"):
                body = line.split(":", 1)[1].strip() if ":" in line else ""
                reason = ""
                if "=>" in body:
                    body, reason = body.split("=>", 1)
                rx = body.strip()
                if not rx:
                    continue
                try:
                    self.sections.setdefault(section, []).append(
                        (re.compile(rx, re.I), reason.strip() or section))
                except re.error as exc:
                    print(f"bad regex in [{section}]: {rx} ({exc})", file=sys.stderr)
                continue

            # scalars (floors / fx / settings), with optional inline comment
            if "=" in line:
                k, v = line.split("=", 1)
                k, v = k.strip(), v.split("#", 1)[0].strip()
                key = k if section == "settings" else k.upper()
                target = {"floors": self.floors, "fx": self.fx}.get(section, self.scalars)
                if section not in ("floors", "fx", "settings"):
                    target = self.scalars
                try:
                    target[key] = float(v)
                except ValueError:
                    pass

    def match(self, section: str, text: str) -> list[str]:
        if not text:
            return []
        return [r for rx, r in self.sections.get(section, []) if rx.search(text)]


def load_rules(workspace: Path) -> Rules:
    p = Path(workspace) / "config" / "scope.conf"
    if not p.exists():
        # A missing rule file must not crash a run — fall back to no rules.
        return _empty_rules()
    return Rules(p)


def _empty_rules() -> Rules:
    class _Empty(Rules):
        def __init__(self):  # bypass file parsing
            self.path = Path("/dev/null")
            self.sections = {}
            self.scalars = {"hours_per_month": 160.0, "days_per_month": 21.7}
            self.floors = {}
            self.fx = {"USD": 1.0}
    return _Empty()


# ---------------------------------------------------------------------------
# Salary
# ---------------------------------------------------------------------------

_NUM = re.compile(r"(\d[\d,\.]*)\s*([kK])?")


def _numbers(text: str) -> list[float]:
    """Extract the numbers in a salary string, applying Indian lakh / million notation.

    A bare small number only gets scaled when the text carries a unit word, so "INR 15-18 L/yr"
    becomes 1.5M-1.8M while "70,000" is left alone.
    """
    mult = 1.0
    if re.search(r"\b(lakhs?|lacs?|lpa)\b", text, re.I):
        mult = 100_000.0
    elif re.search(r"\d[\d,\.]*\s*L\b", text) and re.search(r"\b(yr|year|annum|pa|mo|month)", text, re.I):
        mult = 100_000.0
    elif re.search(r"\d[\d,\.]*\s*M\b", text) and re.search(r"\b(yr|year|annum|pa)\b", text, re.I):
        mult = 1_000_000.0

    out = []
    for raw, k in _NUM.findall(text):
        raw = raw.replace(",", "").rstrip(".")
        try:
            v = float(raw)
        except ValueError:
            continue
        if k:
            v *= 1000
        elif v < 1000 and mult > 1.0:
            v *= mult
        if v >= 1000:
            out.append(v)
    return out


def parse_salary(text: str, country: str, rules: Rules) -> dict:
    """Best-effort parse of a posted salary string. Returns {raw, currency, monthly, usdMonthly, belowFloor}."""
    res = {"raw": text or "", "currency": None, "monthly": None, "usdMonthly": None, "belowFloor": False}
    if not text:
        return res

    low = text.lower()
    currency = None
    for alias, code in CURRENCY_ALIASES.items():
        if alias in ("$",):
            if "$" in text:
                currency = currency or DOLLAR_BY_COUNTRY.get((country or "").strip().lower(), "USD")
            continue
        if re.search(rf"(?<![a-z]){re.escape(alias)}(?![a-z])", low):
            currency = code
            break
    res["currency"] = currency or "USD"

    period = None
    if re.search(r"(per|/|a)\s*(hour|hr)\b|\bhourly\b", low):
        period = "hour"
    elif re.search(r"(per|/|a)\s*day\b|\bdaily\b|\bday ?rate\b", low):
        period = "day"
    elif re.search(r"(per|/|a)\s*(month|mo)\b|\bmonthly\b|\bpcm\b", low):
        period = "month"
    elif re.search(r"(per|/|a)\s*(year|yr|annum)\b|\bannual(ly)?\b|\bp\.?a\.?\b", low):
        period = "year"

    nums = _numbers(text)
    if not nums:
        return res
    high = max(nums)

    if period == "hour":
        monthly = high * rules.scalars.get("hours_per_month", 160.0)
    elif period == "day":
        monthly = high * rules.scalars.get("days_per_month", 21.7)
    elif period == "year":
        monthly = high / 12.0
    elif period == "month":
        monthly = high
    else:
        # no period stated: guess by magnitude
        monthly = high / 12.0 if high > 40000 else high

    res["monthly"] = round(monthly, 2)
    rate = rules.fx.get(res["currency"], 1.0)
    usd = monthly * rate
    res["usdMonthly"] = round(usd, 2)
    floor_usd = rules.floors.get("USD", 7000.0)
    res["belowFloor"] = usd < floor_usd
    res["floorUsd"] = floor_usd
    return res


# ---------------------------------------------------------------------------
# Dedupe
# ---------------------------------------------------------------------------

def _key(company: str, title: str) -> str:
    return f"{structured._slug(company)}|{structured._slug(title)}"


def load_applied(workspace: Path) -> set[str]:
    """Every (company, title) already submitted, from the cross-channel registry."""
    keys: set[str] = set()
    reg = Path(workspace) / "applied-jobs-registry.md"
    if not reg.exists():
        return keys
    for line in reg.read_text(errors="ignore").splitlines():
        if not line.startswith("|") or line.startswith("|---") or "Submitted" in line:
            continue
        parts = [p.strip() for p in line.split("|")]
        parts = [p for p in parts if p != ""]
        if len(parts) >= 3 and re.match(r"^\d{4}-\d{2}-\d{2}$", parts[0]):
            keys.add(_key(parts[2], parts[1]))
    return keys


def load_recent_skips(workspace: Path, days: int = 7) -> set[str]:
    """Jobs skipped in the last N days, from every channel's §6 log."""
    keys: set[str] = set()
    cutoff = datetime.now() - timedelta(days=days)
    cutoff_str = cutoff.strftime("%Y-%m-%d")
    for log in (*Path(workspace).glob("*-automation/run-log.md"),
                *Path(workspace).glob("*-automation/bank/core.md")):
        for line in log.read_text(errors="ignore").splitlines():
            if not line.startswith("|") or "| skipped |" not in line:
                continue
            parts = [p.strip() for p in line.split("|") if p.strip()]
            if len(parts) < 3 or not re.match(r"^\d{4}-\d{2}-\d{2}$", parts[0]):
                continue
            if parts[0] < cutoff_str or "RUN SUMMARY" in parts[1]:
                continue
            cell = parts[1]
            title, _, company = cell.partition("@")
            company = company.split(",")[0].strip()
            if title and company:
                keys.add(_key(company, title))
    return keys


# ---------------------------------------------------------------------------
# Annotate
# ---------------------------------------------------------------------------

def annotate(workspace: Path, cand: dict, rules: Rules, applied: set[str],
             skips: set[str], use_dedupe: bool = True) -> dict:
    title = str(cand.get("title") or "")
    company = str(cand.get("company") or "")
    country = str(cand.get("country") or "")
    salary_raw = str(cand.get("salaryRaw") or (cand.get("salary") or {}).get("raw") or "")
    # The pay text is part of the text every rule sees: "GBP 100 per hour" is how an hourly
    # contract announces itself, and it lives in the salary field, not the description.
    text = " ".join(str(cand.get(k) or "") for k in
                    ("title", "company", "location", "description", "snippet", "requirements"))
    if salary_raw:
        text = f"{text} {salary_raw}"

    out = dict(cand)
    reasons: list[str] = []

    # 1. Title scope — out wins over in.
    out_hits = rules.match("title_out", title)
    in_hits = rules.match("title_in", title)
    if out_hits:
        out["scope"] = "out"
        reasons += [f"out of scope: {r}" for r in out_hits]
    elif in_hits:
        out["scope"] = "in"
    else:
        out["scope"] = "ambiguous"

    # 2. Hard walls.
    walls = rules.match("wall", text)
    reasons += [f"wall: {r}" for r in walls]

    # 3. Language.
    langs = rules.match("language", text)
    reasons += [f"language: {r}" for r in langs]

    # 4. Contract shape.
    contracts = rules.match("contract", text)
    reasons += [f"contract: {r}" for r in contracts]

    # 5. Salary.
    salary = parse_salary(salary_raw, country, rules)
    out["salary"] = salary
    if salary.get("belowFloor"):
        reasons.append(f"salary below floor (USD {salary['usdMonthly']:,.0f}/mo < "
                       f"USD {salary.get('floorUsd', 7000):,.0f}/mo)")

    # 6. Dedupe.
    k = _key(company, title)
    if use_dedupe and k in applied:
        out["dedupe"] = "applied"
    elif use_dedupe and k in skips:
        out["dedupe"] = "skipped-recent"
    else:
        out["dedupe"] = "new"

    # Verdict: scope=out, any wall/language/contract, below-floor or a dedupe hit all fail.
    if out["scope"] == "out":
        out["gate"] = "fail"
    elif reasons:
        out["gate"] = "fail"
    elif out["scope"] == "ambiguous":
        out["gate"] = "warn"
    else:
        out["gate"] = "pass"

    if out["dedupe"] != "new":
        out["gate"] = "fail"
        reasons.append("already applied" if out["dedupe"] == "applied" else "skipped in the last 7 days")

    out["gateReasons"] = list(dict.fromkeys(reasons))   # dedupe, keep order
    out["jobId"] = cand.get("jobId") or structured.job_id(
        cand.get("channel", ""), company, title)
    return out


def filter_set(workspace: Path, raw: list[dict], use_dedupe: bool = True) -> dict:
    rules = load_rules(Path(workspace))
    applied = load_applied(Path(workspace)) if use_dedupe else set()
    skips = load_recent_skips(Path(workspace)) if use_dedupe else set()
    kept, dropped = [], []
    for c in raw:
        a = annotate(Path(workspace), c, rules, applied, skips, use_dedupe)
        (kept if a["gate"] != "fail" else dropped).append(a)
    stats = {
        "in": sum(1 for k in kept if k["scope"] == "in"),
        "warn": sum(1 for k in kept if k["gate"] == "warn"),
        "dropped": len(dropped),
        "dropReasons": _tally(r for d in dropped for r in d["gateReasons"]),
    }
    return {"kept": kept, "dropped": dropped, "stats": stats}


def _tally(items) -> dict[str, int]:
    out: dict[str, int] = {}
    for i in items:
        out[i] = out.get(i, 0) + 1
    return out


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    ws = Path(argv[0]) if not argv[0].startswith("--") else Path(".")
    flags = argv[1:] if not argv[0].startswith("--") else argv

    if "--rules" in flags:
        r = load_rules(ws)
        for sec, pats in r.sections.items():
            print(f"[{sec}] {len(pats)} rule(s)")
            for rx, reason in pats:
                print(f"   {rx.pattern}   -> {reason}")
        print(f"floors: {r.floors}")
        return 0

    if "--raw" in flags:
        raw = json.loads(sys.stdin.read() or "[]")
        print(json.dumps(filter_set(ws, raw, use_dedupe="--no-dedupe" not in flags), indent=2))
        return 0

    src = None
    if "--in" in flags:
        src = Path(flags[flags.index("--in") + 1])
    if not src or not src.exists():
        print("nothing to filter (no --in file)", file=sys.stderr)
        return 0

    recs, problems = structured.read_jsonl(src, None)
    result = filter_set(ws, recs, use_dedupe="--no-dedupe" not in flags)
    for p in problems:
        print(p, file=sys.stderr)

    out = Path(flags[flags.index("--out") + 1]) if "--out" in flags else src
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as fh:
        for rec in result["kept"]:
            fh.write(json.dumps(rec, separators=(",", ":")) + "\n")

    # Keep the rejects: the dashboard's "why was this skipped" insights are built from them.
    dropped_path = out.with_suffix(out.suffix + ".dropped")
    with dropped_path.open("w", encoding="utf-8") as fh:
        for rec in result["dropped"]:
            fh.write(json.dumps(rec, separators=(",", ":")) + "\n")

    print(json.dumps({"kept": len(result["kept"]), "dropped": len(result["dropped"]),
                      "stats": result["stats"], "out": str(out), "droppedOut": str(dropped_path)}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
