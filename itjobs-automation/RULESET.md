> Deep-dive notes for this channel: site mechanics and hard-won history. The runbook that
> actually executes is `prompts/<channel>.md` + `prompts/_shared.md`, and **every form answer
> comes from `bank/core.md`** — where this file and the bank disagree, the bank wins.
>
> Some notes here come from earlier incarnations of this system: anything mentioning
> `browser action=…` or selecting a browser *profile* refers to a driver API that no longer
> exists. The runbook drives the browser with the `agent-browser` CLI.

# ITJobs.pt — Ruleset (v1, 2026-10-13)

Operating rules for the scheduled **itjobs** channel for the candidate. Each run
reads the shared preamble + `prompts/itjobs.md` + the canonical bank (`bank/core.md`), then applies.
Built from live reconnaissance 2026-10-13 (Portuguese IT board; applies via the employer's CVWarehouse ATS).

Companion channels: LinkedIn, Indeed, Jaabz, Workopolis, jobs.ch, The Hub, Relocate.me (`prompts/<channel>.md`).

> **Canonical files**
> - **Answer bank (single source of truth): `bank/core.md`** — never duplicate answers here.
> - Mechanics, search URL and DOM notes: `prompts/itjobs.md`.
> - This channel's run log / day-cap source / §5 questions: `itjobs-automation/run-log.md`.

## 1. Mission
Apply to **senior/lead DevOps / Cloud / Platform / SRE / Infrastructure** roles advertised on ITJobs.pt.
The board is Portuguese; many ads are Portuguese-only. Applications are handled by the employer's
**CVWarehouse** ATS (external), so this is a discover-then-apply-on-the-destination channel.

## 2. Guardrails
1. Answers ONLY from `bank/core.md`; never invent (hard-stop: salary, visa/sponsorship, notice, start).
2. Scope: DevOps/cloud/infra + technical-manager level (core.md §8). A "Programador"/"Developer" title
   is application-dev → out of scope. Never dev/data/ML/QA/security/support.
3. Language: the candidate speaks **<LANGUAGES> only** → read the ad; SKIP anything requiring Portuguese
   (the UI language alone is fine).
4. Pay: **EUR floor 6,000/mo** (core.md §3). Portuguese bands are often below the floor — a high skip
   rate is expected and is not a failure.
5. Dedupe: skip the same posting, or same title at same company, already applied (registry + PREFLIGHT).
6. External CVWarehouse that cannot be completed (account-only / unknown module) → SKIP + log `external`.
7. Unanswered REQUIRED question → Telegram the candidate, log §5, close the tab, continue.
8. Portugal only — do NOT cross over to itjobs.es (Spain).

## 3. Search strategy
`https://www.itjobs.pt/emprego?q=<keyword>` — rotate `devops`, `sre`, `platform`, `cloud`,
`kubernetes`, `infraestrutura`, `site reliability`. Judge by title before opening; 2 pages max per
keyword, then rotate the keyword rather than paging deep.

## 4. Runtime flow
Shared preamble applies: `agent-browser connect 9222` → search → screen (title/language/pay) → open the
job → apply (CVWarehouse guest form, or in-page "Candidatar-me") → SUBMIT → §6 row + registry → close tab.
CV for the ATS: `linkedin-automation/cv/CV.pdf`.

## 5. State
Append §6 rows (`| date | title @ company, country | applied/skipped/needs-review | reason |`), §5 for
unanswered questions, `applied-jobs-registry.md` (channel `itjobs`) on every confirmed submit, and the
structured side-channel (`decisions.jsonl` / `applications.jsonl`). Record the exact CVWarehouse DOM in
§5 on the first supervised run.

## 6. Failure modes
| Symptom | Action |
|---|---|
| Not logged in | Report "needs login", stop |
| pt-only ad | Skip + log `language` |
| CVWarehouse account-only / unknown module | Skip + log `external` |
| Form cannot be completed per bank | Skip + log §5, continue |
