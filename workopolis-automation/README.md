# Workopolis Auto-Apply Automation (the candidate / Alex Example)

Workopolis (workopolis.com) — a **Canada-only, Indeed-powered** job board — as the **6th application
channel** in the candidate's job-application system. Built 2026-09-20 from live reconnaissance.

## What Workopolis is (verified live 2026-09-20)

A Canada-only job board whose applications run on **Indeed's** infrastructure. you are logged in
(header avatar "AS"), and you keeps Workopolis, Indeed, LinkedIn, Job Bank and Eluta tabs open in
Brave.

**The apply chain, verified end to end:**

```
workopolis.com/search?q=…&l=…          discovery (MUI app, Canada only)
  → /jobsearch/viewjob/<id>            job page; apply control = <a href="/out?r=…"> "Quick apply"
  → ca.indeed.com/job/<slug>-<jobkey>  the same posting on Indeed (identical job key)
  → smartapply.indeed.com/beta/…       the standard Indeed apply wizard
```

Because the destination is Indeed, this channel **reuses the Indeed mechanics and the canonical
answer bank wholesale** — it is a discovery channel first, an application channel second. Two
consequences worth remembering:

- A Workopolis posting and its ca.indeed.com twin share a job key, so **this channel and the Indeed
  channel dedupe against each other** through `applied-jobs-registry.md`.
- The session that matters is the **Indeed** session. A Workopolis login is not required to apply —
  the "Quick apply" `/out?r=…` link is an unauthenticated outbound tracker.

## What Workopolis adds (and what makes it noisy)

Its own Canada-centric index, with a high share of postings that are **not submittable**:

- cards **without** "Quick apply" are external company-site applies → skip;
- many postings are **hourly / day-rate** ("$75–$85 an hour") → skipped by rule;
- many posted bands are **below the CAD floor** (C$116k/yr, ≈ CAD 9,700/mo) → skip;
- Quebec postings are often **French-only** → skip (only the languages in `bank/core.md`).

A high skip rate here is normal and by design; the pre-filter is what keeps the runs cheap.

## Files

| File | Purpose |
|---|---|
| `bank/core.md` | Channel answer bank (thin — `bank/core.md` is canonical) + §5 unanswered questions + §6 run log (this channel's 30/day budget) |
| `RULESET.md` | Operating rules: what Workopolis is, scope incl. the Canada skip list, guardrails, discovery, apply flow, browser discipline, state, failure modes, budget |
| `../prompts/workopolis.md` | The task text each scheduled run executes (prepended by `prompts/_shared.md`) |
| `../.commandcode/skills/workopolis-job-apply/SKILL.md` | Skill wrapper for running/repairing the channel by hand |
| `../bank/core.md` | **Canonical answer bank — single source of truth** |
| `../applied-jobs-registry.md` | Cross-channel dedupe (append after every confirmed submit) |
| `../linkedin-automation/cv/CV_latest.pdf` | Canonical CV (preloaded on the Indeed profile) |

## Schedule (the candidate's crontab, Asia/Kuala_Lumpur)

Three slots a day — **10:00, 15:00, 20:00 MYT** — chosen to sit in the gaps between the existing
channels and never collide on the shared Brave browser:

| Channel | Slots (MYT) |
|---|---|
| glassdoor | 06 · 11 · 16 |
| linkedin | 07 · 12 · 17 |
| indeed | 08 · 13 · 18 |
| jaabz | 09 · 14 · 19 |
| **workopolis** | **10 · 15 · 20** |
| school-calendar | every 2h (separate automation, no browser) |

The launcher holds one exclusive browser lock, so even an overrunning run can only cause the next
slot to skip — never two runs on Brave at once.

## How to run

```bash
tools/cron-run.sh workopolis            # the real run (free models first, Telegram report)
tools/cron-run.sh workopolis --dry-run  # compose the prompt + run the preflight, no model, no tokens
tools/jobs-status.sh                    # all channels, slots, next run, last result
```

## Model & budget

Free Command Code models first (`APPLY_MODELS` in `.env`), with the paid DeepSeek fallback only while
`tools/cc-quota --gate` allows. Per-run target 15 applications, 30/day cap for this channel.
