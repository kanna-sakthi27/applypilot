# Glassdoor Auto-Apply Automation (the candidate)

Glassdoor DevOps/cloud auto-apply — the fourth channel in the candidate's job-application system, built
2026-09-07 as a twin of the LinkedIn/Indeed automations.

## How Glassdoor applies work (verified by live recon 2026-09-07)

- **Glassdoor "Easy Apply" opens the SAME Indeed smartapply wizard** in a new tab:
  `https://smartapply.indeed.com/beta/indeedapply/...` (Glassdoor is owned by Recruit Holdings, the
  same group as Indeed).
- the candidate's **Indeed session is used automatically** — her resume "ALEX EXAMPLE - CV.pdf"
  is preloaded and pre-selected at the resume-selection step (38%).
- The rest of the wizard (contact → screener → attestation → EEO → review → submit) is **identical to
  the Indeed flow** → all Indeed mechanics and answer-bank mappings transfer directly.
- Jobs whose Glassdoor page shows **"Apply on employer site"** are external-apply → v1 skips them
  (they belong to the foreign-direct automation).
- the candidate does NOT need a Glassdoor account for Easy Apply (the Indeed session powers it). A Glassdoor
  login would only be needed for saved searches / "My Jobs" tracking (optional).

## Files

| File | Purpose |
|---|---|
| `RULESET.md` | Operating rules: scope, guardrails, search strategy, flow, browser discipline, failure modes |
| `bank/core.md` | Answer bank + Glassdoor run log (day-cap source) + unanswered-questions log |
| `../applied-jobs-registry.md` | COMMON cross-channel applied-jobs memory (dedupe across LinkedIn/Indeed/Glassdoor/foreign) |
| `../indeed-automation/RULESET.md` | Reference mechanics for the smartapply wizard (identical flow) |
| `../bank/core.md` | Canonical answer bank (salary conversions, templates) |

## Channel rules (inherited)

- Scope: DevOps/cloud ONLY, engineer + technical-manager level (DevOps/Cloud/Infra/SRE/Platform
  Manager, Team Lead, Head…). No software-dev/data/ML/AI/QA/security/non-cloud.
- Nationality truth: <NATIONALITY> + <OTHER_NATIONALITY> dual national, NOT <COUNTRY_OF_RESIDENCE>; sponsorship needed outside
  SL/IN — answer truthfully and SUBMIT (skip only explicit right-to-work/no-sponsorship language).
- Expected salary USD 8,000/mo; **apply-floor USD 7,000/mo**; per-country conversions in bank/core.md §3.
- Daily cap 30 (Glassdoor's own budget) / per-run ≤10. Cross-apply guard: check
  `applied-jobs-registry.md` before every submit.
- Markets: rotate Glassdoor country sites (US → UK → IE → EU English-only → CA → SG → AU) to follow
  the Indeed rotation. English-only for EU.

## Schedule

Runs on a cron (see `openclaw cron list` → `glassdoor-devops-auto-apply`), isolated agentTurn, cheap
model (GLM-5.3 Flash on commandcode — same as Indeed), delivery announce to Telegram (the candidate).

## Run cadence

1. Read RULESET.md + bank/core.md + applied-jobs-registry.md.
2. Browser: profile `brave` (CDP 9222). Open a fresh Glassdoor search tab (Easy Apply filter).
3. For each candidate: detail page → "Easy Apply" → smartapply tab → walk wizard → Submit.
4. On confirmation: log to run-log.md §6 + applied-jobs-registry.md; close smartapply tab.
5. End: RUN SUMMARY + concise Telegram report (<180 words).
