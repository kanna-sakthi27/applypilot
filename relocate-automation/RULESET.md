> Deep-dive notes for this channel: site mechanics and hard-won history. The runbook that
> actually executes is `prompts/<channel>.md` + `prompts/_shared.md`, and **every form answer
> comes from `bank/core.md`** — where this file and the bank disagree, the bank wins.
>
> Some notes here come from earlier incarnations of this system: anything mentioning
> `browser action=…` or selecting a browser *profile* refers to a driver API that no longer
> exists. The runbook drives the browser with the `agent-browser` CLI.

# Relocate.me — Ruleset (v1, 2026-10-13)

Operating rules for the scheduled **relocate** channel for the candidate. Each run
reads the shared preamble + `prompts/relocate.md` + the canonical bank (`bank/core.md`), then applies.
Built from live reconnaissance 2026-10-13 (English visa-sponsorship board; applies via the employer's ATS).

Companion channels: LinkedIn, Indeed, Jaabz, Workopolis, jobs.ch, The Hub, ITJobs.pt (`prompts/<channel>.md`).

> **Canonical files**
> - **Answer bank (single source of truth): `bank/core.md`** — never duplicate answers here.
> - Mechanics, search URL and DOM notes: `prompts/relocate.md`.
> - This channel's run log / day-cap source / §5 questions: `relocate-automation/run-log.md`.

## 1. Mission
Apply to **senior/lead DevOps / Cloud / Platform / SRE / Infrastructure** roles on Relocate.me — a
curated **visa-sponsorship / relocation** board (English). The application is handled by the
employer's ATS (usually Greenhouse; sometimes Lever/Ashby), so this is discover-then-apply-on-the-ATS.

## 2. Guardrails
1. Answers ONLY from `bank/core.md`; never invent (hard-stop: salary, visa/sponsorship, notice, start).
2. Scope: DevOps/cloud/infra + technical-manager level (core.md §8). Never dev/data/ML/QA/security/support.
3. Language: English. SKIP any posting requiring a language the candidate lacks.
4. **Countries in the candidate's favour** (candidate policy needs sponsorship, English-only): NL · DE · IE · PT · CH · SE ·
   DK · FI · NO · CA · UK · AU · NZ · SG · JP · UAE/GCC. **SKIP the US** and any local-language /
   local-right-to-work posting.
5. Pay: floor = USD <FLOOR_MONTHLY_USD>/mo equivalent (core.md §3), including **JPY** for Japan. Skip only an
   *explicit* band below it.
6. Supported ATS (guest apply OK): Greenhouse · Lever · Ashby · SmartRecruiters. Workday / SuccessFactors
   / Taleo (account + OTP, no Google SSO) → SKIP + log `external`.
7. Dedupe: skip the same posting, or same title at same company, already applied (registry + PREFLIGHT).
8. Unanswered REQUIRED question → Telegram the candidate, log §5, close the tab, continue.

## 3. Search strategy
`https://relocate.me/international-jobs/devops` (+ the all-jobs index `/international-jobs` when the slug
is dry). Volume is **small** (2–20 roles) — finish with a RUN SUMMARY; a 0-apply run here is normal.
Judge by title before opening.

## 4. Runtime flow
Shared preamble applies: `agent-browser connect 9222` → search → screen (country-in-favour/language/pay)
→ open the job → click Apply → follow the external ATS (guest apply with
`linkedin-automation/cv/CV.pdf` + `bank/core.md`) → SUBMIT → §6 row + registry → close tab.

## 5. State
Append §6 rows (`| date | title @ company, country | applied/skipped/needs-review | reason |`), §5 for
unanswered questions, `applied-jobs-registry.md` (channel `relocate`) on every confirmed submit, and the
structured side-channel (`decisions.jsonl` / `applications.jsonl`).

## 6. Failure modes
| Symptom | Action |
|---|---|
| Not logged in | Report "needs login", stop |
| US / local-language posting | Skip + log `out of scope` / `language` |
| Unsupported ATS (Workday/SF/Taleo) | Skip + log `external` |
| Form cannot be completed per bank | Skip + log §5, continue |
