> Deep-dive notes for this channel: site mechanics and hard-won history. The runbook that
> actually executes is `prompts/<channel>.md` + `prompts/_shared.md`, and **every form answer
> comes from `bank/core.md`** — where this file and the bank disagree, the bank wins.
>
> Some notes here come from earlier incarnations of this system: anything mentioning
> `browser action=…` or selecting a browser *profile* refers to a driver API that no longer
> exists. The runbook drives the browser with the `agent-browser` CLI.

# The Hub (thehub.io) Auto-Apply — Ruleset (v1, 2026-10-13)

Operating rules for the scheduled **thehub** channel for the candidate. Each run
reads the shared preamble + `prompts/thehub.md` + the canonical bank (`bank/core.md`), then applies.
Built from live reconnaissance 2026-10-13.

Companion channels: LinkedIn, Indeed, Jaabz, Workopolis, jobs.ch, ITJobs.pt, Relocate.me (`prompts/<channel>.md`).

> **Canonical files**
> - **Answer bank (single source of truth): `bank/core.md`** — never duplicate answers here.
> - Mechanics, search URL and DOM notes: `prompts/thehub.md`.
> - This channel's run log / day-cap source / §5 questions: `thehub-automation/run-log.md`.

## 1. Mission
Apply to **senior/lead DevOps / Cloud / Platform / SRE / Infrastructure** roles on The Hub. The market
is Nordic + EU + remote startups, in English. Apply through The Hub's own apply; skip postings whose
application is "handled outside of The Hub".

## 2. Guardrails
1. Answers ONLY from `bank/core.md`; never invent (hard-stop: salary, visa/sponsorship, notice, start).
2. Scope: DevOps/cloud/infra + technical-manager level (core.md §8). Never dev/data/ML/QA/security/support.
3. Language: English only (candidate policy: <LANGUAGES>). Skip Finnish/Swedish/Danish/Norwegian/German roles.
4. Pay: floor = USD <FLOOR_MONTHLY_USD>/mo equivalent (core.md §3). Skip only an *explicit* band below it.
5. Dedupe: skip the same posting, or same title at same company, already applied (registry + PREFLIGHT).
6. External ("handled outside of The Hub") → SKIP + log `external`; never chase the company site.
7. Unanswered REQUIRED question → Telegram the candidate, log §5, close the tab, continue.
8. A hard blocker → SKIP + continue; never park a needs-review draft.

## 3. Search strategy
`https://thehub.io/jobs?roles=devops&countryCode=EU&sorting=newJobs` — rotate `countryCode`
(EU / REMOTE / DK / FI / IS / NO / SE) and the shared SEARCH TITLES keywords. Judge by title before
opening anything; 2 search rounds max per run.

## 4. Runtime flow
Shared preamble applies: `agent-browser connect 9222` → search → screen (title/language/pay) → apply →
SUBMIT → §6 row + registry → close the tab. The Hub form autofills from the saved applicant profile;
complete anything missing from `bank/core.md`.

## 5. State
Append §6 rows (`| date | title @ company, country | applied/skipped/needs-review | reason |`), §5 for
unanswered questions, `applied-jobs-registry.md` (channel `thehub`) on every confirmed submit, and the
structured side-channel (`decisions.jsonl` / `applications.jsonl`).

## 6. Failure modes
| Symptom | Action |
|---|---|
| Not logged in / login prompt | Report "needs login", stop |
| Bot wall / captcha | Skip + log, no retry loop |
| "handled outside of The Hub" | Skip + log `external` |
| Form cannot be completed per bank | Skip + log §5, continue |
