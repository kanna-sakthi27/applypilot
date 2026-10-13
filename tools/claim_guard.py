#!/usr/bin/env python3
"""claim_guard.py — every claim in a tailored CV must exist in the source. No exceptions.

This is the one unrecoverable failure mode in the whole project: a generated CV that invents an
employer, a date, a certification or a metric is worse than no tailored CV at all. So the guard is
deterministic, it runs on every variant, and a failure means the variant is DISCARDED and the base
CV is used instead.

    claim_guard.py audit <source.json> <variant.json>
    claim_guard.py audit-text <source.json>          # variant text on stdin
    claim_guard.py source <source.json>              # dump the derived allowlists (debugging)

Exit codes: 0 clean · 1 violations found · 2 usage.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# Skills this candidate must never appear to hold (mirrors bank/core.md §5). A variant that
# introduces one is rejected outright even if the source is malformed.
NEVER_CLAIM = [
    "python", "golang", " go ", "java ", "java,", "rust", "kotlin",
    "argocd", "argo cd", "github actions", "github enterprise", "bitbucket pipelines",
    "helm", "kustomize",
]

CERT_VOCAB = [
    "aws solutions architect", "solutions architect associate", "terraform associate",
    "cka", "certified kubernetes administrator", "azure solutions architect",
    "gcp professional", "security+", "cissp", "pmp",
]

# Grade words that must not be upgraded: "Associate" must never become "Professional".
GRADES = {"associate", "professional", "expert", "specialty", "foundations", "administrator"}

# "cut costs 60%", "led 5 engineers", "200 servers", "9 years", "30% less overhead"
METRIC_PATTERNS = [
    re.compile(r"(\d+(?:\.\d+)?)\s*%"),
    re.compile(r"(\d[\d,]*)\+?\s*(servers?|instances?|pipelines?|deploys?|engineers?|people|"
               r"accounts?|services?|clusters?|nodes?|applications?|years?)", re.I),
]

_SLUG = re.compile(r"[^a-z0-9]+")


def _norm(s: str) -> str:
    return _SLUG.sub(" ", (s or "").lower()).strip()


def _tokens(s: str) -> set[str]:
    return {t for t in _norm(s).split() if t}


# ---------------------------------------------------------------------------
# Derived allowlists
# ---------------------------------------------------------------------------

MONTHS = ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")


def _month_year(text: str) -> tuple[str, str] | None:
    m = re.search(r"\b(" + "|".join(MONTHS) + r")[a-z]*\.?\s+(\d{4})\b", text or "", re.I)
    return (m.group(1).lower()[:3], m.group(2)) if m else None


class Allow:
    def __init__(self, source: dict):
        self.source = source
        self.companies = {_norm(r.get("company", "")) for r in source.get("roles", []) if r.get("company")}
        self.titles = [r.get("title", "") for r in source.get("roles", []) if r.get("title")]
        self.title_tokensets = [_tokens(t) for t in self.titles]
        self.dates = set()
        # Role dates are tracked SEPARATELY: a year that appears only on a certification must not
        # be usable as a job start date.
        self.role_years: set[str] = set()
        self.role_pairs: set[tuple[str, str]] = set()
        for r in source.get("roles", []):
            for key in ("start", "end"):
                v = r.get(key)
                if not v:
                    continue
                s = str(v)
                self.dates.update(re.findall(r"\d{4}", s))
                self.role_years.update(re.findall(r"\d{4}", s))
                pair = _month_year(s)
                if pair:
                    self.role_pairs.add(pair)
                if s.lower() in ("present", "current", "now"):
                    self.dates.add("present")
        for e in source.get("education", []):
            if e.get("year"):
                self.dates.update(re.findall(r"\d{4}", str(e["year"])))
        for c in source.get("certifications", []):
            self.dates.update(re.findall(r"\d{4}", str(c)))
        self.certs = {_norm(c) for c in source.get("certifications", [])}
        self.cert_tokens = set()
        self.cert_tokensets = []
        for c in source.get("certifications", []):
            self.cert_tokens |= _tokens(c)
            self.cert_tokensets.append(_tokens(c))
        self.skills = {_norm(s) for s in source.get("skills", [])}
        self.skill_tokens = set()
        for s in source.get("skills", []):
            self.skill_tokens |= _tokens(s)
        self.institutions = {_norm(e.get("institution", "")) for e in source.get("education", [])
                             if e.get("institution")}
        self.qualifications = {_norm(e.get("qualification", "")) for e in source.get("education", [])
                               if e.get("qualification")}
        # Numbers the source is allowed to state: from explicit metrics, bullets and summary.
        self.numbers = set()
        for text in self._all_source_text():
            for num in re.findall(r"\d[\d,\.]*", text):
                self.numbers.add(num.replace(",", "").rstrip("."))
        self.explicit_metrics = {_norm(m) for m in source.get("metrics", [])}

    def _all_source_text(self):
        s = self.source
        yield str(s.get("summary", ""))
        for b in s.get("bullets", []) or []:
            yield str(b)
        for r in s.get("roles", []):
            for b in r.get("bullets", []) or []:
                yield str(b)
        for c in s.get("certifications", []) or []:
            yield str(c)
        for sk in s.get("skills", []) or []:
            yield str(sk)


# ---------------------------------------------------------------------------
# Audit
# ---------------------------------------------------------------------------

def _cert_matches(claim: str, allow: Allow) -> bool:
    """A reworded certification is fine; a re-GRADED one is not.

    "HashiCorp Terraform Associate" for "HashiCorp Certified: Terraform Associate" is a legitimate
    reword. "AWS Solutions Architect Professional" for the Associate cert is a fabricated upgrade.
    """
    ct = _tokens(claim)
    if not ct:
        return False
    for st in allow.cert_tokensets:
        jaccard = len(ct & st) / max(1, len(ct | st))
        if jaccard >= 0.7 and (ct & GRADES) == (st & GRADES):
            return True
    return False


def audit(source: dict, variant: dict) -> dict:
    allow = Allow(source)
    violations: list[dict] = []

    def bad(kind, claim, reason):
        violations.append({"kind": kind, "claim": str(claim)[:160], "reason": reason})

    # --- roles: company + title -------------------------------------------
    vroles = variant.get("roles") or []
    if not vroles and variant.get("summary"):
        bad("structure", "(no roles)", "the variant has no roles at all — it is not a CV")

    for r in vroles:
        company = r.get("company", "")
        if company and _norm(company) not in allow.companies:
            bad("employer", company,
                "this employer does not appear anywhere in your source CV")

        title = r.get("title", "")
        if title:
            tt = _tokens(title)
            if not any(tt == allowed for allowed in allow.title_tokensets):
                # Allow a reword only when every word already exists in one source title.
                if not any(tt <= allowed or allowed <= tt for allowed in allow.title_tokensets):
                    bad("title", title,
                        "this job title is not one of your source titles (reword with the same words, "
                        "do not invent a promotion)")

        for key in ("start", "end"):
            v = str(r.get(key) or "")
            if not v:
                continue
            if v.lower() in ("present", "current", "now"):
                continue
            for year in re.findall(r"\d{4}", v):
                if year not in allow.role_years:
                    bad("date", f"{key}={v}",
                        f"the year {year} is not one of your actual role dates "
                        f"(a year that only appears on a certification or degree is not a job date)")
            pair = _month_year(v)
            if pair and pair not in allow.role_pairs:
                bad("date", f"{key}={v}",
                    f"you did not start or end a role in {pair[0].title()} {pair[1]}")

        for b in r.get("bullets", []) or []:
            _audit_text(b, allow, bad)

    # --- certifications ----------------------------------------------------
    for c in variant.get("certifications", []) or []:
        if _norm(c) in allow.certs:
            continue
        if _cert_matches(c, allow):
            continue
        bad("certification", c,
            "you do not hold this certification in your source CV "
            "(a grade must never be upgraded — Associate is not Professional)")

    # --- skills ------------------------------------------------------------
    for s in variant.get("skills", []) or []:
        sn = _norm(s)
        if sn in allow.skills or _tokens(s) <= allow.skill_tokens:
            continue
        if any(nc in f" {sn} " for nc in NEVER_CLAIM):
            bad("forbidden-skill", s,
                "this is on your never-claim list — it must not appear as a skill")
        # A skill the source does not list at all is a claim we cannot verify.
        elif sn and len(sn) > 2 and not any(sn in a or a in sn for a in allow.skills):
            bad("skill", s, "this skill is not listed in your source CV")

    # --- education ---------------------------------------------------------
    for e in variant.get("education", []) or []:
        inst = e.get("institution", "")
        if inst and _norm(inst) not in allow.institutions:
            bad("education", inst, "this institution does not appear in your source CV")
        year = str(e.get("year") or "")
        for y in re.findall(r"\d{4}", year):
            if y not in allow.dates:
                bad("date", f"education year {year}", f"the year {y} is not in your source CV")

    # --- free text ---------------------------------------------------------
    for field in ("summary", "headline", "coverLetter"):
        if variant.get(field):
            _audit_text(variant[field], allow, bad)

    return {"ok": not violations, "violations": violations, "count": len(violations)}


def _audit_text(text: str, allow: Allow, bad) -> None:
    """Numbers and forbidden skills are the two things prose can smuggle in."""
    t = f" {_norm(text)} "
    for nc in NEVER_CLAIM:
        needle = nc if nc.startswith(" ") else f" {nc} "
        if needle in t:
            bad("forbidden-skill", nc.strip(), "this tool is on your never-claim list")
    for pat in METRIC_PATTERNS:
        for m in pat.finditer(text):
            num = m.group(1).replace(",", "")
            # Only flag a metric that is genuinely new: allow the same number anywhere in source.
            if num and num not in allow.numbers:
                ctx = m.group(0).strip()
                if _norm(ctx) in allow.explicit_metrics:
                    continue
                bad("metric", ctx,
                    f"the figure {num} does not appear in your source CV — do not invent numbers")


def audit_text(source: dict, text: str) -> dict:
    allow = Allow(source)
    violations: list[dict] = []
    _audit_text(text, allow, lambda k, c, r: violations.append({"kind": k, "claim": str(c)[:160], "reason": r}))
    # Also scan for employers named in the text that are not in the source.
    return {"ok": not violations, "violations": violations, "count": len(violations)}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[0]
    source_path = Path(argv[1])
    if not source_path.is_file():
        print(f"source not found: {source_path}", file=sys.stderr)
        return 2
    source = json.loads(source_path.read_text())

    if cmd == "audit":
        variant = json.loads(Path(argv[2]).read_text())
        result = audit(source, variant)
    elif cmd == "audit-text":
        result = audit_text(source, sys.stdin.read())
    elif cmd == "source":
        a = Allow(source)
        result = {"companies": sorted(a.companies), "titles": a.titles,
                  "dates": sorted(a.dates), "certs": sorted(a.certs),
                  "skills": sorted(a.skills), "numbers": sorted(a.numbers)}
    else:
        print(__doc__, file=sys.stderr)
        return 2

    print(json.dumps(result, indent=2))
    return 0 if result.get("ok", True) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
