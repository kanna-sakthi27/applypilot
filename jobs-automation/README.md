# jobs.ch Auto-Apply Automation (the candidate / Alex Example)

jobs.ch (jobs.ch) — the leading **Swiss** job portal (JobCloud) — as the **7th application channel**
in the candidate's job-application system. Built 2026-10-10 from live reconnaissance.

## What jobs.ch is (verified live 2026-10-10)

The leading Swiss job board, operated by JobCloud. Its own in-platform application flow is
**"Easy apply"**: candidates submit **directly on jobs.ch with no redirect** to the employer's ATS.
For **registered users the fields and CV are pre-filled / attached**, and JobCloud states the form
carries the **standard fields only (name, email, phone, CV) with no custom screening questions** —
which makes each submission short and cheap.

**The chain:**

```
jobs.ch/en/vacancies/?term=…&page=…     discovery (Swiss market, English UI)
  → /en/vacancies/detail/<uuid>/        job page; submittable iff it shows the "Easy apply" badge
  → Easy apply (jobs.ch form)           pre-filled for a logged-in user → Submit → confirmation
```

Two consequences worth remembering:

- **A jobs.ch login is what makes an apply work** (Easy apply is built for registered users). The
  preflight probes jobs.ch login state; a signed-out run is blocked with a plain instruction to sign
  in rather than silently doing nothing.
- **The Swiss market is German/French/Italian-first.** the candidate speaks only the languages in `bank/core.md`, so a large
  share of postings is skipped on language. A high skip rate here is normal and by design.

## What jobs.ch adds (and what makes it noisy)

- cards/badges **without** "Easy apply" are external company-site applies → skip;
- many postings **require German (or French/Italian)** → skip (only the languages in `bank/core.md`);
- many ads **hide the salary band** behind login — judge from the ad text and skip only an *explicit*
  band below the CHF floor (5,700/mo);
- some postings are **hourly / day-rate** → skipped by rule.

## Files

| File | Purpose |
|---|---|
| `run-log.md` | §5 unanswered questions + §6 run log (this channel's 30/day budget); answers are NOT here |
| `RULESET.md` | Operating rules: what jobs.ch is, scope incl. the Swiss skip list, guardrails, discovery, apply flow, browser discipline, state, failure modes, budget |
| `../prompts/jobs.md` | The task text each scheduled run executes (prepended by `prompts/_shared.md`) |
| `../bank/core.md` | **Canonical answer bank — single source of truth** |
| `../applied-jobs-registry.md` | Cross-channel dedupe (append after every confirmed submit) |
| `../linkedin-automation/cv/CV_latest.pdf` | Canonical CV (attached on the Easy apply form) |

## Schedule (the candidate's crontab, Asia/Kuala_Lumpur)

Every 2 hours on the **odd** hours at minute **:00** (a slot free on the existing stagger), so runs
never stand on the shared Brave browser:

| Channel | Minute | Hours |
|---|---|---|
| glassdoor | :00 | even |
| linkedin | :24 | even |
| indeed | :48 | even |
| **jobs** | **:00** | **odd** |
| jaabz | :12 | odd |
| workopolis | :36 | odd |

The launcher holds one exclusive browser lock, so if a run overruns, the next slot **waits** for it to
finish rather than skipping.

## How to run

```bash
tools/cron-run.sh jobs            # the real run (free models first, Telegram report)
tools/cron-run.sh jobs --dry-run  # compose the prompt + run the preflight, no model, no tokens
tools/jobs-status.sh              # all channels, slots, next run, last result
```

## Model & budget

Free Command Code models first (`APPLY_MODELS` in `.env`), with the paid DeepSeek fallback only while
`tools/cc-quota --gate` allows. Per-run target 15 applications, 30/day cap for this channel.

## First supervised run

The discovery and gating are fully wired from verified recon. The **exact Easy-apply form internals**
(field selectors, button labels, confirmation text) are learned on the first supervised run and
recorded in `RULESET.md` §5. Run it once by hand with Brave open and logged in to jobs.ch, then note
what the form looked like.
