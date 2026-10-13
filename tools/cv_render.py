#!/usr/bin/env python3
"""cv_render.py — render a CV variant (or the base) to ATS-friendly HTML, then PDF.

The layout is OURS, not the model's: the tailoring step only decides content, this decides
presentation. That keeps the output single-column, table-free and image-free — the shape an ATS
parser can actually read — and means the PDF always looks the same.

PDF generation reuses the Chromium the project already depends on:
    chromium --headless=new --user-data-dir=<temp> --print-to-pdf=out.pdf file.html
It runs on its own throwaway profile, so the operator's browser is never touched.

    cv_render.py html <source.json> <out.html> [--variant variant.json]
    cv_render.py pdf  <source.json> <out.pdf>  [--variant variant.json] [--browser PATH]
    cv_render.py check                     # report which PDF engines are available
"""

from __future__ import annotations

import html as htmlmod
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

BROWSERS = [
    # Order matters: try the ones known to support --print-to-pdf reliably first. Brave is last
    # because some builds hang on headless printing.
    "/usr/bin/chromium", "/usr/bin/chromium-browser", "/snap/bin/chromium",
    "/usr/bin/google-chrome", "/usr/bin/google-chrome-stable",
    "/usr/bin/brave-browser-stable", "/usr/bin/brave-browser",
]

CSS = """
@page { size: A4; margin: 14mm 16mm; }
* { box-sizing: border-box; }
body { font-family: Calibri, Carlito, Arial, Helvetica, sans-serif; font-size: 10.5pt;
       line-height: 1.34; color: #111; margin: 0; }
h1 { font-size: 19pt; margin: 0 0 2px; letter-spacing: .3px; }
.sub { font-size: 10pt; color: #333; margin: 0 0 6px; }
.contact { font-size: 9.5pt; color: #222; margin: 0 0 12px; }
h2 { font-size: 10.5pt; text-transform: uppercase; letter-spacing: .8px; margin: 12px 0 5px;
     border-bottom: 1px solid #999; padding-bottom: 2px; }
p { margin: 0 0 6px; }
ul { margin: 0 0 6px 0; padding-left: 15px; }
li { margin: 0 0 2px; }
.role { margin-bottom: 8px; }
.role .head { font-weight: bold; font-size: 10.8pt; }
.role .meta { font-size: 9.5pt; color: #333; margin-bottom: 3px; }
.skills { margin: 0 0 4px; }
.cert { margin: 0 0 2px; padding-left: 15px; }
"""


def esc(s) -> str:
    return htmlmod.escape(str(s or ""))


def build_html(source: dict, variant: dict | None) -> str:
    v = variant or {}
    c = source.get("contact", {})
    name = v.get("name") or c.get("name") or "Candidate"
    headline = v.get("headline") or c.get("headline") or ""
    links = c.get("links", {})

    parts = ["<!DOCTYPE html><html><head><meta charset='utf-8'>",
             f"<title>{esc(name)} — CV</title><style>{CSS}</style></head><body>"]
    parts.append(f"<h1>{esc(name)}</h1>")
    if headline:
        parts.append(f"<div class='sub'>{esc(headline)}</div>")

    contact = [x for x in [c.get("location"), c.get("phone"), c.get("email"),
                           links.get("linkedin"), links.get("github")] if x]
    parts.append("<div class='contact'>" + " &nbsp;|&nbsp; ".join(esc(x) for x in contact) + "</div>")

    summary = v.get("summary") or source.get("summary")
    if summary:
        parts.append("<h2>Professional Summary</h2>")
        parts.append(f"<p>{esc(summary)}</p>")

    skills = v.get("skills") or source.get("skills") or []
    if skills:
        parts.append("<h2>Key Skills</h2>")
        parts.append("<p class='skills'>" + esc(", ".join(skills)) + "</p>")

    certs = v.get("certifications") or source.get("certifications") or []
    if certs:
        parts.append("<h2>Certifications</h2>")
        for c2 in certs:
            parts.append(f"<p class='cert'>{esc(c2)}</p>")

    roles = v.get("roles") or source.get("roles") or []
    if roles:
        parts.append("<h2>Professional Experience</h2>")
        for r in roles:
            parts.append("<div class='role'>")
            parts.append(f"<div class='head'>{esc(r.get('title'))} — {esc(r.get('company'))}</div>")
            meta = " | ".join(x for x in [r.get("location"),
                                          _range(r.get("start"), r.get("end"))] if x)
            if meta:
                parts.append(f"<div class='meta'>{esc(meta)}</div>")
            bullets = r.get("bullets") or []
            if bullets:
                parts.append("<ul>" + "".join(f"<li>{esc(b)}</li>" for b in bullets) + "</ul>")
            parts.append("</div>")

    education = v.get("education") or source.get("education") or []
    if education:
        parts.append("<h2>Education</h2>")
        for e in education:
            parts.append(f"<p>{esc(e.get('qualification'))}, {esc(e.get('institution'))}"
                         f"{' (' + esc(e.get('year')) + ')' if e.get('year') else ''}</p>")

    projects = v.get("projects") or source.get("projects") or []
    if projects:
        parts.append("<h2>Projects</h2>")
        for p in projects:
            parts.append(f"<p>{esc(p.get('name'))}: {esc(p.get('url'))}</p>")

    parts.append("</body></html>")
    return "\n".join(parts)


def _range(start, end) -> str:
    if start and end:
        return f"{start} – {end}"
    return start or end or ""


def find_browser(explicit: str | None = None) -> str | None:
    if explicit and Path(explicit).is_file():
        return explicit
    env = os.environ.get("JOB_APPLY_BROWSER")
    if env and Path(env).is_file():
        return env
    cached = Path(os.environ.get("JOB_APPLY_PDF_RENDERER", "")) if os.environ.get("JOB_APPLY_PDF_RENDERER") else None
    if cached and cached.is_file():
        return str(cached)
    for b in BROWSERS:
        if Path(b).is_file():
            return b
    return shutil.which("chromium") or shutil.which("google-chrome") or None


def _render_once(exe: str, html_path: Path, pdf_path: Path, timeout: int) -> tuple[bool, str]:
    # The profile and the staging HTML live next to the output, not in /tmp: a snap-confined
    # browser cannot read /tmp or the hidden home directory.
    stage_dir = pdf_path.parent
    stage_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".cvrender-", dir=str(stage_dir)) as profile:
        cmd = [
            exe, "--headless=new", "--disable-gpu", "--no-sandbox", "--no-first-run",
            "--no-default-browser-check", "--disable-background-networking",
            "--disable-component-update", "--disable-sync",
            f"--user-data-dir={profile}",
            f"--print-to-pdf={pdf_path.resolve()}",
            "--no-pdf-header-footer",
            html_path.resolve().as_uri(),
        ]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            return False, f"{Path(exe).name} timed out after {timeout}s"
        if pdf_path.exists() and pdf_path.stat().st_size > 0:
            return True, Path(exe).name
        out = (r.stderr or "") + (r.stdout or "")
        if "bytes written to file" in out:
            # The browser reported success but the file is not where we can see it. That is
            # snap/AppArmor confinement: the browser wrote into its own private /tmp.
            return False, (f"{Path(exe).name} reported writing the PDF but it is not visible at "
                           f"{pdf_path} — a snap-confined browser cannot write outside $HOME. "
                           f"Render into a path under your home directory instead.")
        return False, out[-300:] or "renderer produced no PDF"


def html_to_pdf(html_path: Path, pdf_path: Path, browser: str | None = None,
                timeout: int = 60) -> tuple[bool, str]:
    """Render with the first engine that actually produces a PDF. Returns (ok, detail)."""
    pdf_path.parent.mkdir(parents=True, exist_ok=True)

    if browser:
        return _render_once(browser, html_path, pdf_path, timeout)

    tried = []
    for exe in BROWSERS:
        if not Path(exe).is_file():
            continue
        pdf_path.unlink(missing_ok=True)
        ok, detail = _render_once(exe, html_path, pdf_path, timeout)
        if ok:
            return True, detail
        tried.append(f"{Path(exe).name}: {detail}")
    env = os.environ.get("JOB_APPLY_BROWSER")
    if env and Path(env).is_file() and env not in BROWSERS:
        ok, detail = _render_once(env, html_path, pdf_path, timeout)
        if ok:
            return True, detail
        tried.append(f"{Path(env).name}: {detail}")
    return False, ("no browser produced a PDF — " + " | ".join(tried)) if tried \
        else "no Chromium-based browser found for PDF rendering"


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[0]

    if cmd == "check":
        exe = find_browser()
        print(json.dumps({"browser": exe, "available": bool(exe),
                          "candidates": BROWSERS}, indent=2))
        return 0 if exe else 1

    if cmd in ("html", "pdf"):
        if len(argv) < 3:
            print("usage: cv_render.py html|pdf <source.json> <out> [--variant v.json]",
                  file=sys.stderr)
            return 2
        source = json.loads(Path(argv[1]).read_text())
        out = Path(argv[2])
        variant = None
        if "--variant" in argv:
            variant = json.loads(Path(argv[argv.index("--variant") + 1]).read_text())
        doc = build_html(source, variant)

        if cmd == "html":
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(doc, encoding="utf-8")
            print(json.dumps({"html": str(out), "bytes": len(doc)}))
            return 0

        out.parent.mkdir(parents=True, exist_ok=True)
        # Stage the HTML next to the PDF, not in /tmp: a snap-confined browser cannot read /tmp.
        staging = out.parent / f".{out.stem}.staging.html"
        staging.write_text(doc, encoding="utf-8")
        try:
            browser = argv[argv.index("--browser") + 1] if "--browser" in argv else None
            ok, detail = html_to_pdf(staging, out, browser)
            print(json.dumps({"ok": ok, "pdf": str(out) if ok else None, "detail": detail}))
            return 0 if ok else 1
        finally:
            staging.unlink(missing_ok=True)

    print(f"unknown command {cmd!r}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
