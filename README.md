# Job_Applying_Cron — an autonomous job-application engine

A self-contained engine that runs **unattended job-application sessions** on job boards, driving a
real, already-logged-in browser and answering every application-form question from a local answer
bank. It is bash + Python, it is relocatable (every path is resolved relative to this folder), and it
is model-agnostic: a headless LLM agent decides what to click and fill, while deterministic gates run
first so no tokens are spent on jobs that are out of scope.

It is designed to run from `cron`, one channel at a time, with a shared browser lock, a per-model
budget governor, and a machine-readable record of everything it does.

> **This repository ships templates, not personal data.** The answer bank, CV, applied-jobs registry,
> run logs and `.env` are all git-ignored and must be created by you from the `*.example` files (see
> [Setup](#setup)). Nothing about the original operator is included.

---

## What it does

For each configured **channel** (job board), a run:

1. Takes a cross-channel browser lock, so only one session drives the browser at a time.
2. Runs a **zero-token pre-flight**: is the browser up? is the site session logged in? is there model
   budget left? which jobs are already applied to / recently skipped?
3. Composes a prompt (a shared preamble + the pre-flight digest + the channel body) and hands it to a
   headless model via the Command Code CLI (`cmd -p`).
4. The model searches the board, judges each title against the scope rules, reads each posting's
   "kill facts" **before** opening an apply flow, answers the form from `bank/core.md`, and submits.
5. Every outcome is recorded as a one-line row in the channel's run log **and** as structured JSONL in
   `logs/runs/<runId>/`, and a human-readable summary is sent over Telegram.
6. On exit (success, error, stuck or timeout) the launcher sweeps only the browser tabs the run opened.

The deterministic **pre-filter** (`tools/prefilter.py`) is authoritative: it re-checks every candidate
against `config/scope.conf` (scope, salary floors, hard walls, required languages, contract shape,
dedupe) and overwrites whatever the model guessed.

## Features

- **Relocatable & self-contained** — move the whole directory, no absolute paths to edit.
- **Free-first models with automatic paid fallback** — a free model that fails, submits nothing, or
  burns its slice is dropped and the paid model picks up the same session, in the same run.
- **Quota governor** — respects 5-hour / weekly / monthly spend windows; drops the paid model and runs
  free-only as a window nears its cap, and skips rather than overspends.
- **0-skipped compensation ledger** — skips that *could* have been applications are carried forward as
  a debt so the next run compensates; genuine walls never build an impossible debt.
- **Tab hygiene** — closes only the tabs a run opened, with a backstop sweep and a regression test.
- **Structured side-channel** — `run.json` plus `candidates / decisions / applications.jsonl` for a
  dashboard or review queue.
- **Deterministic scope gate** — pure-Python pre-filter with an editable rule file.
- **Self-tests** — model-fallback and tab-cleanup regression tests are included.
- **Ask, don't skip** — a required question the bank cannot answer is sent to Telegram; the run closes
  that tab and continues with other jobs.

## Requirements

| Requirement | Why it is needed |
| --- | --- |
| **Linux** (or WSL/macOS with `flock`+`timeout`) | the engine uses `flock` for the browser lock and `timeout` for per-model slices |
| **`node` ≥ 22** | the Command Code CLI `cmd` is `#!/usr/bin/env node`; without node every run dies |
| **`cmd` (Command Code CLI), signed in** | the headless model driver (`~/.commandcode/auth.json`) |
| **`python3`** (3.8+) | the pre-filter, the structured side-channel, the quota gate |
| **`agent-browser` CLI** | drives the browser over CDP |
| **A Chromium-family browser running with `--remote-debugging-port=9222`, logged in to the boards** | the sites the engine applies on |
| **`curl`** | Telegram notifications |
| **`flock` (util-linux) and coreutils `timeout`** | the single-browser lock and the per-model caps |
| **A Telegram bot** (optional) | run reports and mid-run questions |
| **A model provider** | either the Command Code plan (default) or another CDP/CLI provider |

CPU/RAM are modest — the heavy lifting happens in the browser and in the hosted model.

## Quick install

On a fresh Linux machine the bundled installer detects your distribution, installs everything
listed under [Requirements](#requirements) (git, curl, python3, `flock`/`timeout`, Node.js >= 22,
the Command Code CLI `cmd`, `agent-browser`, and a Chromium-family browser), then **verifies each
one** and exits non-zero if anything is still missing.

```bash
./install.sh               # install anything missing, then verify
./install.sh --check       # verify only - install nothing, change nothing
./install.sh --no-browser  # skip the browser install
```

When it finishes it prints the remaining manual steps (`cmd login`, start the browser with
`--remote-debugging-port=9222`, and create your `.env` / `bank` / `cv` from the templates).

---

## Installation

```bash
git clone <your-fork-url> Job_Applying_Cron
cd Job_Applying_Cron
chmod +x tools/*.sh tools/cc-quota
```

Then create your private config from the templates:

```bash
cp .env.example .env                                   # then edit: bot token, chat id, models
cp bank/core.example.md bank/core.md                   # then fill in your real answers
cp bank/OPEN-QUESTIONS.example.md bank/OPEN-QUESTIONS.md
cp applied-jobs-registry.example.md applied-jobs-registry.md
cp cv/source/default.example.json cv/source/default.json && $EDITOR cv/source/default.json
# put your CV PDF where the channel expects it, e.g.:
cp ~/my-cv.pdf linkedin-automation/cv/CV_latest.pdf
# create each channel's run log from its template as you enable that channel:
cp linkedin-automation/run-log.example.md linkedin-automation/run-log.md
```

Verify the engine sees everything:

```bash
./tools/cron-run.sh linkedin --dry-run     # composes the prompt, prints the plan, sends nothing
```

## Setup

### 1. Browser

The engine **attaches** to your real, logged-in browser — it never launches its own, and it never logs
in for you. Start your Chromium-family browser with the DevTools port open and sign in to the boards
you want to automate:

```bash
# example: Brave with the debugging port open
brave-browser --remote-debugging-port=9222 --restore-last-session &
```

The browser is detected at `BRAVE_CDP_PORT` (default `9222`). Keep the same profile you use normally so
the site sessions are present.

### 2. Models

Set `APPLY_MODELS` in `.env` to a comma-separated preference list. Free model ids end in `:free` or
`-free`; paid ids have no suffix. The launcher tries them in order and escalates to the first paid
model when a free one fails or records nothing (subject to the quota gate). Example:

```
APPLY_MODELS=poolside/laguna-s-2.1-free,deepseek/deepseek-v4-flash
```

Check which configured models actually work with a live probe (the CLI's model list can be stale):

```bash
./tools/cc-models.sh --probe-free   # free models only (costs nothing)
./tools/cc-models.sh --probe        # every configured model (paid ones cost a little)
./tools/cc-quota --json             # current plan usage across the three windows
```

### 3. Answer bank

`bank/core.md` is the single source of truth for **every** form answer. Section numbers (§1–§9) and the
table shapes are what the prompts and tools read — keep them. The full structure lives in
`bank/core.example.md`.

### 4. Scope and walls

- `config/scope.conf` — title in/out patterns, salary **floors** per currency, hard walls
  (citizenship-only, no-sponsorship, security clearance, residency), required-language rules, contract
  shapes and FX rates. The pre-filter applies this before any model runs. Edit freely; no code change
  is needed to add a rule.
- `config/tab-cleanup.conf` — which leftover tabs the post-run sweep may close, split into job boards
  (`[hosts]`, closed only if they appeared during the run) and company ATS pages (`[reclaim]`, closed
  even if they pre-date it). Your own tabs are never touched.

### 5. Schedule (cron)

Run each channel on its own staggered minutes so runs never fight over the browser lock. Example:

```cron
# every 2 hours, staggered by channel
0  */2 * * *  cd /path/to/Job_Applying_Cron && ./tools/cron-run.sh glassdoor  >>logs/cron.log 2>&1
24 */2 * * *  cd /path/to/Job_Applying_Cron && ./tools/cron-run.sh linkedin   >>logs/cron.log 2>&1
48 */2 * * *  cd /path/to/Job_Applying_Cron && ./tools/cron-run.sh indeed     >>logs/cron.log 2>&1
0  1-23/2 * * * cd /path/to/Job_Applying_Cron && ./tools/cron-run.sh jobs       >>logs/cron.log 2>&1
12 1-23/2 * * * cd /path/to/Job_Applying_Cron && ./tools/cron-run.sh jaabz      >>logs/cron.log 2>&1
36 1-23/2 * * * cd /path/to/Job_Applying_Cron && ./tools/cron-run.sh workopolis >>logs/cron.log 2>&1
```

If you move the folder, update the paths — nothing else needs editing.

## Usage

```bash
./tools/cron-run.sh <channel>              # run one channel (linkedin|indeed|glassdoor|jaabz|workopolis|jobs)
./tools/cron-run.sh <channel> --dry-run    # compose the prompt, print the plan, invoke no model
./tools/cron-run.sh <channel> --mode scan  # find + gate candidates, don't apply
./tools/cron-run.sh <channel> --mode apply --candidates <file>   # apply to an approved shortlist
./tools/cron-run.sh <channel> --run-id <id>  # resume/extend an existing structured run
```

Useful helpers:

| Command | Does |
| --- | --- |
| `./tools/apply-preflight.sh <channel>` | prints the pre-flight digest (browser/session/budget/dedupe) |
| `./tools/prefilter.py . --in <candidates.jsonl>` | applies the deterministic gate to a candidate list |
| `./tools/structured.py` | the structured run side-channel (`new-run`, `append`, `finalize`, `jobid`) |
| `./tools/tab-cleanup.sh list\|reclaim\|sweep <snapshot>` | inspect / reclaim / sweep browser tabs |
| `./tools/bank-reminder.sh` | Telegram nudge for unanswered bank questions |
| `./tools/jobs-status.sh` | quick status summary across channels |
| `./tools/run-stats.sh --recent 1` | token + cost accounting for a run |
| `./tools/new-channel.sh <site>` | scaffold a new channel (dir + prompt stub + run log) |
| `./tools/cv-rotate.sh` | keep only the newest N generated CV variants |
| `./tools/tailor.sh` | tailor a CV for a specific posting from `cv/source/default.json` |

Regression tests:

```bash
./tools/model-fallback-selftest.sh    # asserts the paid fallback recovers a free-model outage
./tools/tab-cleanup-selftest.sh       # asserts only run-opened tabs are swept
./tools/cc-quota-verify.sh            # sanity-checks the quota gate
```

## Directory layout

```
Job_Applying_Cron/
  tools/                  the engine (bash + Python); see the table in Usage
  prompts/                _shared.md preamble + one body per channel (+ _scan/_apply/_tailor)
  bank/core.md            THE answer sheet (git-ignored; template at core.example.md)
  config/                 scope.conf (scope/floor/walls) · tab-cleanup.conf
  <channel>-automation/   per-channel RULESET.md + run-log.md (§5 questions, §6 run log)
  cv/                     CV source JSON + PDFs (git-ignored; template + README shipped)
  logs/                   per-run logs + logs/runs/<runId>/ structured records (git-ignored)
  state/                  model cool-down / strike state, compensation ledger (git-ignored)
  .env                    model list + timeouts + Telegram (git-ignored; template .env.example)
  applied-jobs-registry.md  cross-channel dedupe source of truth (git-ignored; .example shipped)
```

## How a run decides (guardrails)

- **Know first, apply second.** Titles are judged from the results list without opening a card. A
  posting's kill-facts (work-authorization / no-sponsorship, required language, contract type, pay
  floor, closed/filled, external-only) are read on the detail page **before** an apply flow begins.
- **Truthful answers, then submit.** The engine answers visa/skills questions truthfully and submits;
  it skips only on an explicit wall. It never ticks a skill as held that is not, and never invents a
  number or a status.
- **Narrow dedupe.** Skip only the *same posting* or the *same title at the same company* already
  applied. A different role at a company already in the lists is fine.
- **Anti-spin.** A form that will not advance after a bounded number of attempts is skipped + logged,
  and its tab is closed — never left open "to come back to".
- **Bounded, self-cleaning artefacts.** Tailored CVs and tab snapshots are rotated to a fixed ceiling.

## Configuration reference

All runtime knobs live in `.env` (see `.env.example` for the annotated list). The most important:

| Variable | Meaning |
| --- | --- |
| `APPLY_MODELS` | comma-separated model preference list (free first, paid fallback) |
| `APPLY_TIMEOUT_SECONDS` | total wall-clock budget for one run |
| `APPLY_PER_MODEL_SECONDS` / `APPLY_FIRST_MODEL_SECONDS` | per-model slice / short leash for the first model |
| `APPLY_MAX_TURNS` | max agent turns per model attempt |
| `APPLY_RUN_TARGET` | end the run once this many applications are confirmed |
| `APPLY_DEBT_CAP` | max unpaid skips a channel may carry forward |
| `APPLY_PAID_RESERVE_SECONDS` | seconds reserved so the paid model always gets an attempt |
| `APPLY_{5H,WEEKLY,MONTHLY}_STOP_PCT` | quota-window % at which the run goes free-only |
| `JOB_APPLY_LOCK_WAIT_SECONDS` | how long to wait for another run to release the browser |
| `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` | bot + chat for reports and questions |
| `BRAVE_CDP_PORT` | the browser's DevTools port (default 9222) |

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "browser not reachable" | start your browser with `--remote-debugging-port=<BRAVE_CDP_PORT>` |
| Every site shows "Sign In" | the browser profile isn't logged in, or `agent-browser connect` didn't attach |
| "another run holds the browser lock" | a run is genuinely in progress; the next run waits, then starts |
| Run reports "no model" | every configured model is cooled/capped — check `tools/cc-models.sh --probe` |
| Run records 0 applications but "succeeded" | the model answered the prompt as a document; check `logs/` and re-probe models |
| Telegram silent | verify `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`; test with `echo hi \| ./tools/tg-notify.sh` |

## Adding a new job site

```bash
./tools/new-channel.sh <site>          # creates <site>-automation/{RULESET.md,run-log.md} + prompts/<site>.md
# fill in the RULESET with the site's apply mechanics, then add the channel to your crontab
```

The launcher derives a channel's run log from its name, so a new site needs only
`<site>-automation/run-log.md` and `prompts/<site>.md` — no edits to `cron-run.sh`.

## Safety & etiquette

Automating a job board is your responsibility: comply with each site's Terms of Service, rate limits
and robots guidance, keep submission volumes human-plausible (the per-channel daily caps exist for
exactly this), never evade an interactive captcha or checkpoint, and never submit an application whose
claims you cannot stand behind. The engine is built to *answer truthfully and let the employer decide*.
