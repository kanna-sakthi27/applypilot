# AGENTS.md — guidance for AI coding agents working in this repo

This repository is a **self-contained job-application automation engine** that drives a real,
already-logged-in browser over the Chrome DevTools Protocol (CDP) via the `agent-browser` CLI, with a
model (Command Code `cmd`) deciding what to click and fill, and a local answer bank supplying every
form answer.

## Ground rules when editing this repo

- **Analyse first, don't break the running system.** The engine is working; prefer additive, minimal
  changes over rewrites. Read the code before changing it.
- **Every path is relative to the repo root.** `tools/*.sh` resolve `ROOT="$(cd "$(dirname "$0")/.." && pwd)"`.
  Never hardcode an absolute workspace path into a tool.
- **No personal data in commits.** `.env`, `bank/core.md`, `applied-jobs-registry.md`, per-channel
  `run-log.md`/`answers.md`, `cv/*.pdf`, `logs/` and `state/` are git-ignored on purpose. Keep it that
  way; never commit secrets or the candidate's real details.
- **Follow the existing patterns.** New job sites are added as a `<site>-automation/` directory plus
  `prompts/<site>.md` (see `tools/new-channel.sh`), not with a new framework.
- **Prefer shell + the installed tooling.** The engine is bash + Python 3 + the `cmd`/`agent-browser`
  CLIs. Avoid adding new runtime dependencies.
- **Cost discipline.** Model calls are metered. Batch reads/searches, look things up with grep/glob
  before reading whole files, and route routine work to free models where possible.
- **Clean up after yourself.** Runs must close only the browser tabs they opened (never the user's),
  and must clean up on error/stuck/timeout paths too, not just success.

## Where things live

| Path | What |
| --- | --- |
| `tools/cron-run.sh` | The launcher: lock → pre-flight → `cmd -p` → records → report |
| `tools/prefilter.py` | Deterministic scope / salary / wall / dedupe gate (runs before any model tokens) |
| `tools/structured.py` | The machine-readable run side-channel (`run.json`, `*.jsonl`) |
| `tools/cc-quota` | The spend gate (free models bypass it) |
| `prompts/` | `_shared.md` preamble + one body per channel (+ `_scan` / `_apply` / `_tailor`) |
| `bank/core.md` | The answer sheet (git-ignored; template in `bank/core.example.md`) |
| `config/scope.conf` | Scope, salary floors, hard walls, language/contract rules |
| `config/tab-cleanup.conf` | Which leftover tabs the post-run sweep may close |
| `<channel>-automation/` | Per-channel `RULESET.md` + `run-log.md` (the §6 run log) |

See `README.md` for the full setup and usage guide.
