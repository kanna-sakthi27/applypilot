#!/usr/bin/env python3
"""structured.py — the single source of truth for the run side-channel.

A run writes machine-readable records next to its human-readable log so the extension can build
the review queue, the dashboard and the digest without parsing prose. Everything that writes or
reads those records goes through this module.

    logs/runs/<runId>/run.json           run metadata + counts
    logs/runs/<runId>/candidates.jsonl   written by the SCAN phase
    logs/runs/<runId>/decisions.jsonl    written by the APPLY phase
    logs/runs/<runId>/applications.jsonl CONFIRMED submissions only

CLI
    structured.py new-run <workspace> --channel C [--mode scan|apply|auto] [--profile P]
    structured.py jobid <channel> <company> <title>
    structured.py append <kind> <file>            # JSON on stdin
    structured.py validate <kind> <file>
    structured.py read <kind> <file> [--strict]
    structured.py finalize <workspace> <runId>
    structured.py summarize <workspace> <runId>

Exit codes: 0 ok · 1 validation/read failure · 2 usage.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path

SCHEMA_VERSION = 1
RUNS_REL = "logs/runs"

KINDS = ("run", "candidate", "decision", "application")

FILE_FOR_KIND = {
    "candidate": "candidates.jsonl",
    "decision": "decisions.jsonl",
    "application": "applications.jsonl",
}

MODES = {"scan", "apply", "auto"}
RUN_STATUS = {"running", "finished", "blocked", "failed"}
SCOPE = {"in", "out", "ambiguous"}
GATE = {"pass", "fail", "warn"}
DEDUPE = {"new", "applied", "skipped-recent"}
DECISION = {"applied", "skipped", "needs-review", "pending"}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def _missing(obj, fields) -> list[str]:
    return [f"missing required field '{f}'" for f in fields if f not in obj or obj[f] is None]


def _enum(obj, field, allowed) -> list[str]:
    if field in obj and obj[field] is not None and obj[field] not in allowed:
        return [f"{field}={obj[field]!r} not one of {sorted(allowed)}"]
    return []


def _numeric(obj, field, lo=None, hi=None) -> list[str]:
    if field not in obj or obj[field] is None:
        return []
    if not isinstance(obj[field], (int, float)) or isinstance(obj[field], bool):
        return [f"{field} must be a number"]
    if lo is not None and not (lo <= obj[field] <= hi):
        return [f"{field}={obj[field]} outside {lo}..{hi}"]
    return []


def validate(kind: str, obj: dict) -> list[str]:
    """Return a list of human-readable problems. Empty list == valid."""
    if kind not in KINDS:
        return [f"unknown record kind {kind!r}"]
    if not isinstance(obj, dict):
        return ["record is not a JSON object"]

    errs: list[str] = []
    if obj.get("v") != SCHEMA_VERSION:
        errs.append(f"v must be {SCHEMA_VERSION} (got {obj.get('v')!r})")

    if kind == "run":
        errs += _missing(obj, ["runId", "mode", "status", "channels", "startedAt"])
        errs += _enum(obj, "mode", MODES)
        errs += _enum(obj, "status", RUN_STATUS)
        if "channels" in obj and not isinstance(obj["channels"], list):
            errs.append("channels must be a list")
        errs += _numeric(obj, "startedAt")

    elif kind == "candidate":
        errs += _missing(obj, ["runId", "jobId", "channel", "title", "company",
                               "gate", "dedupe", "discoveredAt"])
        errs += _enum(obj, "scope", SCOPE)
        errs += _enum(obj, "gate", GATE)
        errs += _enum(obj, "dedupe", DEDUPE)
        errs += _numeric(obj, "score", 0, 100)
        errs += _numeric(obj, "discoveredAt")
        if "gateReasons" in obj and not isinstance(obj["gateReasons"], list):
            errs.append("gateReasons must be a list")
        if "scoreReasons" in obj and not isinstance(obj["scoreReasons"], list):
            errs.append("scoreReasons must be a list")

    elif kind == "decision":
        errs += _missing(obj, ["runId", "jobId", "channel", "decision", "at"])
        errs += _enum(obj, "decision", DECISION)
        errs += _numeric(obj, "at")

    elif kind == "application":
        errs += _missing(obj, ["runId", "jobId", "date", "title", "company", "channel"])
        if "submittedOk" in obj and not isinstance(obj["submittedOk"], bool):
            errs.append("submittedOk must be a boolean")
        if obj.get("submittedOk") is False:
            errs.append("applications.jsonl holds CONFIRMED submissions only")

    return errs


def validate_or_raise(kind: str, obj: dict) -> None:
    errs = validate(kind, obj)
    if errs:
        raise ValueError(f"invalid {kind} record: " + "; ".join(errs))


# ---------------------------------------------------------------------------
# Reading / writing
# ---------------------------------------------------------------------------

def read_jsonl(path: Path, kind: str | None = None, strict: bool = False):
    """Return (records, problems).

    Tolerant by default: a truncated or malformed line is counted and skipped rather than
    killing the whole read. That matters because these files are written by a language model.
    """
    records, problems = [], []
    if not path or not Path(path).exists():
        return records, problems
    for i, line in enumerate(Path(path).read_text(errors="ignore").splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as exc:
            problems.append(f"{path.name}:{i} malformed JSON ({exc.msg})")
            if strict:
                break
            continue
        if kind:
            errs = validate(kind, obj)
            if errs:
                problems.append(f"{path.name}:{i} " + "; ".join(errs))
                if strict:
                    break
                continue
        records.append(obj)
    return records, problems


def append_record(path: Path, kind: str, obj: dict) -> None:
    validate_or_raise(kind, obj)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(obj, separators=(",", ":")) + "\n")


# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

_SLUG = re.compile(r"[^a-z0-9]+")


def _slug(s: str, maxlen: int = 40) -> str:
    return _SLUG.sub("-", (s or "").lower()).strip("-")[:maxlen] or "unknown"


def job_id(channel: str, company: str, title: str) -> str:
    """Stable across runs so dedupe works even when the extension was not watching."""
    key = f"{_slug(channel)}|{_slug(company)}|{_slug(title)}"
    return hashlib.sha1(key.encode()).hexdigest()[:16]


def new_run_id(channel: str, mode: str) -> str:
    # 3 bytes of randomness, not 2: at 2 bytes two runs starting in the same second collide often
    # enough to matter (~2% over 50 draws), and a colliding run id would merge two review cycles.
    stamp = time.strftime("%Y%m%d-%H%M%S")
    return f"{stamp}-{_slug(channel, 24)}-{mode}-{os.urandom(3).hex()}"


def run_dir(workspace: Path, run_id: str) -> Path:
    return Path(workspace) / RUNS_REL / run_id


def create_run(workspace: Path, channel: str, mode: str = "auto", profile: str = "default",
               channels: list[str] | None = None) -> tuple[str, Path]:
    """Create a fresh, collision-free run directory. Returns (runId, runDir)."""
    root = Path(workspace) / RUNS_REL
    root.mkdir(parents=True, exist_ok=True)
    for _ in range(20):
        rid = new_run_id(channel, mode)
        d = root / rid
        try:
            d.mkdir()                       # atomic: fails if it already exists
            break
        except FileExistsError:
            continue
    else:
        raise RuntimeError("could not allocate a unique run id")

    meta = {
        "v": SCHEMA_VERSION,
        "runId": rid,
        "mode": mode,
        "phases": [mode],
        "status": "running",
        "channels": channels or [channel],
        "startedAt": int(time.time() * 1000),
        "finishedAt": None,
        "counts": {"candidates": 0, "applied": 0, "skipped": 0, "needsReview": 0},
        "model": None,
        "costCents": 0,
        "profile": profile,
    }
    validate_or_raise("run", meta)
    (d / "run.json").write_text(json.dumps(meta, indent=2))
    return rid, d


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

def counts_for(d: Path) -> dict:
    cands, _ = read_jsonl(d / "candidates.jsonl", "candidate")
    decs, _ = read_jsonl(d / "decisions.jsonl", "decision")
    apps, _ = read_jsonl(d / "applications.jsonl", "application")
    return {
        "candidates": len(cands),
        "applied": sum(1 for x in decs if x.get("decision") == "applied") or len(apps),
        "skipped": sum(1 for x in decs if x.get("decision") == "skipped"),
        "needsReview": sum(1 for x in decs if x.get("decision") == "needs-review"),
        "pending": sum(1 for x in decs if x.get("decision") == "pending"),
        "submitted_confirmed": len(apps),
    }


def finalize(workspace: Path, run_id: str, model: str | None = None,
             cost_cents: int | None = None, status: str | None = None) -> dict:
    """Recompute run.json counts from the JSONL files. The model's own counts are never trusted.

    `status` overrides the running→finished promotion. A run stopped by the pre-flight never
    reaches the model loop, so without this it would sit at "running" for ever and the dashboard
    would show a run that is not happening.
    """
    d = run_dir(workspace, run_id)
    meta_path = d / "run.json"
    if not meta_path.exists():
        raise FileNotFoundError(f"no run.json in {d}")
    meta = json.loads(meta_path.read_text())
    c = counts_for(d)
    meta["counts"] = {k: c[k] for k in ("candidates", "applied", "skipped", "needsReview")}
    meta["pending"] = c["pending"]
    meta["submitted_confirmed"] = c["submitted_confirmed"]
    if model:
        meta["model"] = model
    if cost_cents is not None:
        meta["costCents"] = cost_cents
    if status in RUN_STATUS:
        meta["status"] = status
    elif meta.get("status") == "running":
        meta["status"] = "finished"
    if not meta.get("finishedAt"):
        meta["finishedAt"] = int(time.time() * 1000)
    meta_path.write_text(json.dumps(meta, indent=2))
    return meta


def summarize(workspace: Path, run_id: str) -> dict:
    d = run_dir(workspace, run_id)
    meta = json.loads((d / "run.json").read_text()) if (d / "run.json").exists() else {}
    cands, p1 = read_jsonl(d / "candidates.jsonl", "candidate")
    decs, p2 = read_jsonl(d / "decisions.jsonl", "decision")
    apps, p3 = read_jsonl(d / "applications.jsonl", "application")
    return {
        "run": meta,
        "candidates": cands,
        "decisions": decs,
        "applications": apps,
        "malformed": {"candidates": p1, "decisions": p2, "applications": p3},
    }


def set_phase(workspace: Path, run_id: str, mode: str) -> dict:
    """Reuse an existing run directory for the next phase of the same review cycle.

    A scan and the apply that follows it are ONE run: the apply appends to the same
    decisions.jsonl/applications.jsonl the dashboard already knows about.
    """
    d = run_dir(workspace, run_id)
    meta_path = d / "run.json"
    if not meta_path.exists():
        raise FileNotFoundError(f"no run {run_id} in {d.parent}")
    meta = json.loads(meta_path.read_text())
    phases = meta.setdefault("phases", [meta.get("mode", mode)])
    if not phases:
        phases.append(mode)
    if phases[-1] != mode:
        phases.append(mode)
    meta["mode"] = mode
    meta["status"] = "running"
    meta["finishedAt"] = None
    meta_path.write_text(json.dumps(meta, indent=2))
    return meta


def latest_runs(workspace: Path, limit: int = 20) -> list[str]:
    root = Path(workspace) / RUNS_REL
    if not root.is_dir():
        return []
    dirs = [p for p in root.iterdir() if p.is_dir() and (p / "run.json").exists()]
    dirs.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return [p.name for p in dirs[:limit]]


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _read_stdin_json() -> dict:
    data = sys.stdin.read().strip()
    if not data:
        raise SystemExit("expected a JSON object on stdin")
    return json.loads(data)


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, args = argv[0], argv[1:]

    if cmd == "new-run":
        if not args:
            raise SystemExit("usage: new-run <workspace> --channel C [--mode M] [--profile P]")
        ws = Path(args[0])
        channel = _flag(args, "--channel") or "unknown"
        mode = _flag(args, "--mode") or "auto"
        profile = _flag(args, "--profile") or "default"
        rid, d = create_run(ws, channel, mode, profile)
        print(json.dumps({"runId": rid, "runDir": str(d)}))
        return 0

    if cmd == "jobid":
        if len(args) < 3:
            raise SystemExit("usage: jobid <channel> <company> <title>")
        print(job_id(args[0], args[1], args[2]))
        return 0

    if cmd == "append":
        kind, path = args[0], Path(args[1])
        obj = _read_stdin_json()
        append_record(path, kind, obj)
        return 0

    if cmd == "validate":
        kind, path = args[0], Path(args[1])
        recs, problems = read_jsonl(path, kind, strict=True)
        for p in problems:
            print(p, file=sys.stderr)
        print(f"{len(recs)} valid, {len(problems)} problem(s)")
        return 0 if not problems else 1

    if cmd == "read":
        kind, path = args[0], Path(args[1])
        strict = "--strict" in args
        recs, problems = read_jsonl(path, kind, strict=strict)
        print(json.dumps({"records": recs, "problems": problems}))
        return 0

    if cmd == "finalize":
        ws, rid = Path(args[0]), args[1]
        model = _flag(args, "--model")
        cost = _flag(args, "--cost")
        status = _flag(args, "--status")
        print(json.dumps(finalize(ws, rid, model, int(cost) if cost else None, status)))
        return 0

    if cmd == "phase":
        ws, rid, mode = Path(args[0]), args[1], args[2]
        print(json.dumps(set_phase(ws, rid, mode)))
        return 0

    if cmd == "summarize":
        ws, rid = Path(args[0]), args[1]
        print(json.dumps(summarize(ws, rid)))
        return 0

    if cmd == "latest":
        print(json.dumps(latest_runs(Path(args[0]), int(args[1]) if len(args) > 1 else 20)))
        return 0

    print(f"unknown command {cmd!r}", file=sys.stderr)
    return 2


def _flag(args: list[str], name: str) -> str | None:
    if name in args:
        i = args.index(name)
        if i + 1 < len(args):
            return args[i + 1]
    return None


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
