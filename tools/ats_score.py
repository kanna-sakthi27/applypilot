#!/usr/bin/env python3
"""ats_score.py — deterministic keyword + format score for a CV against a job posting.

No model involved: this is the number the operator sees next to a tailored variant, so it has to
be reproducible and explainable.

    ats_score.py <source.json> <job-description.txt> [--variant <variant.json>] [--html <file.html>]

Output JSON: { score, matched[], missing[], format{...}, advice[] }
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

STOPWORDS = set("""
a an the and or but if then than that this these those for with without within from into onto over
under about above below you your we our they their he you it its is are was were be been being do
does did doing have has had having will would shall should can could may might must not no nor so
as at by in of on to up out off per via etc ie eg plus role job work working experience
years year strong good excellent ability able across using use used help helps support supported
team teams candidate ideal successful including include includes required requirement requirements
responsibilities responsibility duties position opportunity company companies please apply
looking seeking join new who what when where why how all any both each few more most other some
such only own same very too also well
""".split())

# Technology vocabulary worth matching even when the posting does not capitalise it.
TECH = {
    "terraform", "cloudformation", "ansible", "saltstack", "puppet", "jenkins", "sonarqube",
    "aws", "azure", "gcp", "ec2", "rds", "dms", "lambda", "s3", "iam", "vpc", "eks", "ecs",
    "kubernetes", "k8s", "docker", "containers", "helm", "kustomize", "argocd", "gitops",
    "grafana", "elk", "kibana", "filebeat", "zabbix", "nagios", "icinga", "prometheus",
    "datadog", "splunk", "opensearch", "linux", "unix", "windows", "bash", "powershell",
    "python", "golang", "java", "node", "sql", "postgresql", "mysql", "mongodb", "redis",
    "jenkins", "gitlab", "github", "bitbucket", "azure devops", "ci/cd", "cicd", "pipeline",
    "pipelines", "iac", "infrastructure as code", "automation", "observability", "sre",
    "reliability", "incident", "on-call", "scaling", "autoscaling", "networking", "firewall",
    "pfSense", "opnsense", "f5", "iso 27001", "sox", "pci", "security", "patching", "migration",
    "cost optimization", "finops", "monitoring", "logging", "deployment", "release",
    "vmware", "opennebula", "n8n", "sonar", "agile", "scrum", "saFe", "itil",
}

_WORD = re.compile(r"[A-Za-z][A-Za-z0-9+#/\.\-]{1,}")


def _normalise(w: str) -> str:
    return w.lower().strip(".,;:()[]/").replace("cicd", "ci/cd")


def keywords(text: str, limit: int = 40) -> list[str]:
    """Pull the terms an ATS would care about out of a posting, most-salient first."""
    found: dict[str, int] = {}

    # 1. known tech vocabulary, including multi-word forms
    low = text.lower()
    for term in TECH:
        if term in low:
            found[term] = found.get(term, 0) + 3

    # 2. capitalised words / acronyms that are not sentence starters
    for i, line in enumerate(text.splitlines()):
        for m in _WORD.finditer(line):
            w = m.group(0)
            if len(w) < 3 or w.lower() in STOPWORDS:
                continue
            if w.isupper() and len(w) >= 2:
                found[_normalise(w)] = found.get(_normalise(w), 0) + 2
            elif w[0].isupper() and m.start() > 0:
                found[_normalise(w)] = found.get(_normalise(w), 0) + 1

    ranked = sorted(found.items(), key=lambda kv: (-kv[1], kv[0]))
    return [k for k, _ in ranked[:limit]]


def cv_text(variant: dict | None, source: dict) -> str:
    """The text an ATS would extract from the variant (or the base CV)."""
    v = variant or {}
    parts: list[str] = []
    parts.append(str(v.get("summary") or source.get("summary") or ""))
    parts += [str(s) for s in (v.get("skills") or source.get("skills") or [])]
    parts += [str(c) for c in (v.get("certifications") or source.get("certifications") or [])]
    for r in (v.get("roles") or source.get("roles") or []):
        parts.append(f"{r.get('title','')} {r.get('company','')} {r.get('location','')}")
        parts += [str(b) for b in (r.get("bullets") or [])]
    for e in (v.get("education") or source.get("education") or []):
        parts.append(f"{e.get('qualification','')} {e.get('institution','')}")
    return " \n".join(parts)


def format_checks(html: str | None) -> dict:
    """ATS-hostile formatting an ATS parser trips over."""
    if html is None:
        return {"checked": False}
    low = html.lower()
    return {
        "checked": True,
        "tables": "<table" in low,
        "images": "<img" in low,
        "multiColumn": "column-count" in low or "grid-template-columns: repeat(2" in low,
        "textInHeaderFooter": bool(re.search(r"<header|<footer", low)),
        "ok": not any(x in low for x in ("<table", "<img")),
    }


def score(source: dict, jd_text: str, variant: dict | None = None,
          html: str | None = None) -> dict:
    kws = keywords(jd_text)
    haystack = " " + _normalise(cv_text(variant, source)) + " "
    haystack = haystack.replace("ci/cd", "cicd")

    matched, missing = [], []
    for k in kws:
        # Normalise BOTH sides the same way, or "CI/CD" in the posting never matches the CV.
        needle = _normalise(k).replace("ci/cd", "cicd")
        if needle in haystack or needle.replace(" ", "") in haystack.replace(" ", ""):
            matched.append(k)
        else:
            missing.append(k)

    total = len(kws) or 1
    base = round(100 * len(matched) / total)

    fmt = format_checks(html)
    if fmt.get("checked") and not fmt.get("ok"):
        base = max(0, base - 20)

    advice = []
    if fmt.get("tables"):
        advice.append("Remove tables — many ATS parsers drop their contents entirely.")
    if fmt.get("images"):
        advice.append("Remove images — text inside them is invisible to an ATS.")
    if fmt.get("multiColumn"):
        advice.append("Use a single column — multi-column layouts are read out of order.")
    if missing:
        advice.append("Missing keywords: " + ", ".join(missing[:12]) +
                      ("…" if len(missing) > 12 else ""))
    if not missing:
        advice.append("Covers every keyword this posting emphasises.")

    return {"score": base, "matched": matched, "missing": missing,
            "keywordCount": len(kws), "format": fmt, "advice": advice}


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    source = json.loads(Path(argv[0]).read_text())
    jd = Path(argv[1]).read_text(errors="ignore")
    variant = None
    if "--variant" in argv:
        variant = json.loads(Path(argv[argv.index("--variant") + 1]).read_text())
    html = None
    if "--html" in argv:
        html = Path(argv[argv.index("--html") + 1]).read_text(errors="ignore")
    print(json.dumps(score(source, jd, variant, html), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
