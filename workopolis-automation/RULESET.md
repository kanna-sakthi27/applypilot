# Workopolis Auto-Apply — Ruleset (v1, 2026-09-20)

Operating rules for the scheduled **workopolis** channel for the candidate (Alex Example).
Each run reads the shared preamble + this ruleset's prompt (`prompts/workopolis.md`) and the canonical
bank (`bank/core.md`), then applies. Built entirely from live reconnaissance 2026-09-20.

Companion channels: LinkedIn, Indeed, Glassdoor, Jaabz (`prompts/<channel>.md`).

> **Canonical files**
> - **Answer bank (single source of truth): `<WORKSPACE>/bank/core.md`**
> - **Cross-channel dedupe: `<WORKSPACE>/applied-jobs-registry.md`**
> - CV: `linkedin-automation/cv/CV_latest.pdf` (md5 1b2229c6)
> - Channel log: `workopolis-automation/run-log.md` (§5 unanswered questions, §6 run log)

## 0. What Workopolis is (verified live 2026-09-20)

A **Canada-only job board powered by Indeed**. Its "Quick apply" control is an unauthenticated
outbound tracker (`/out?r=…`) that lands on `ca.indeed.com/job/<slug>-<jobkey>`; from there
**Apply now** opens the standard `smartapply.indeed.com` wizard.

**Consequences that shape everything below:**

- The application mechanics are **the Indeed channel's mechanics** — resume-selection, contact,
  profile-location, screener modules, attestation, EEO, review, submit. Nothing new to invent.
- The session that matters is the **Indeed** session, not the Workopolis one (the candidate has both).
- A Workopolis posting and its ca.indeed.com twin are **the same job key**, so this channel and the
  Indeed channel dedupe against each other through the shared registry.
- Discovery, not submission, is what Workopolis adds: a Canada-specific index with a high share of
  external, hourly and below-floor postings.

## 1. Mission

Mine Workopolis for fresh in-scope DevOps/cloud/infrastructure roles, apply through the Indeed
smartapply wizard using the canonical answer bank, and keep the shared registry and this channel's
§6 log in sync. **Canada market only.**

## 2. Scope

In scope (engineer AND technical-manager level, the core of the job running/automating/leading
infrastructure — the title need not say "DevOps"): DevOps · SRE/Reliability · Platform · Release
engineering · Cloud (engineer/architect/lead/manager) · **Infrastructure** (engineer/senior
engineer/lead/manager/operations lead, cloud **or** on-prem) · **Linux/Unix/Systems** (Linux
engineer/systems engineer/senior systems engineer/administrator/lead/team lead) · the manager-tier
equivalents (DevOps/Cloud/Infrastructure/Platform/SRE/Linux/Systems Manager, Team Lead, Engineering
Manager, Head of …).

Never: helpdesk / desktop / IT support / service desk · pure networking or NOC · pure DBA · security
that is not DevSecOps · application/backend/frontend/mobile development · data/analytics/ML/AI/DS ·
QA (unless CI/CD-focused) · Oracle/SAP/HR systems · Microsoft 365 workplace · sales/recruiting/
non-technical management · junior/graduate/intern/"associate". Ambiguous title → the core
responsibility must be infrastructure, else SKIP + log.

**Canada-specific skip list:** posted band below the **CAD floor (C$116k/yr, ≈ CAD 9,700/mo)** ·
**hourly / day-rate / sub-12-month** postings (regardless of the rate) · **French-language** postings
(English + Tamil only) · roles demanding existing Canadian work authorization / citizenship / PR.

## 3. Guardrails (never cross)

1. **Never invent facts.** Every answer comes from `bank/core.md`. `core.md` wins on any conflict.
2. **Visa is answered truthfully and the application is SUBMITTED.** Outside Sri Lanka: sponsorship
   **Yes**, authorized to work **No**. Do not self-skip because the ad omits sponsorship — let the
   employer decide. Skip only an explicit wall (no sponsorship offered, citizens/PR only, must
   already hold work authorization).
3. **Hard walls → SKIP + log and continue**, one attempt at most: captcha/Cloudflare, a form bug
   after 1 reload / 3 attempts, an unmappable REQUIRED question that is a true wall, external-only
   apply, dead listing. Never stop a run on one blocker, and never park a needs-review draft.
4. **A missing skill is not automatically a wall** — see `core.md` §5. Apply when the tool is one
   line in a broader stack; answer its experience question truthfully; never tick it as held.
5. **Never bulk-apply.** One job at a time, 1.5–3 s between steps, verify state after each action.
6. **Never answer salary below USD 8,000/mo expected / USD 7,000/mo floor** (CAD values in
   bank/core.md §3). Never state a nationality other than **<NATIONALITY>**.
7. **Daily cap 30** submitted per day for this channel (counted from this channel's §6, MYT);
   **per-run target 15**. Never exceed the cap.
8. **Rate limit / 429 / soft block** → stop applying after 2 hits, report partial, quit cleanly.
9. **Dedupe** before every submit: same posting, or same title at the same company, already applied
   on ANY channel (registry) → SKIP + log. A *different* role at the same company is fine.
   An Indeed "Applied" state on the destination is a duplicate too.
10. **Never use the word "the candidate" in any form answer.** Answer as Alex Example / "I".

## 4. Discovery

Search URL: `https://www.workopolis.com/search?q=<urlencoded keyword>&l=<location>` — only `q` and `l`
are honoured; pagination is a `cursor=…` link. Locations rotate:
`canada` → `toronto, on` → `vancouver, bc` → `calgary, ab` → `montreal, qc` → `remote`.

- Click the **Date** radio in the "Sort by" group to order newest-first (Relevance is the default).
- Read the list with ONE compact eval anchored on `a[href*="/jobsearch/viewjob/"]`, reading
  `closest('li,div[class]').innerText` → title · company — location · salary · type · tags ·
  freshness badge · "Quick apply".
- **Pre-filter before opening anything:** out-of-scope title, no "Quick apply", hourly/day-rate,
  below CAD floor, French-language. Most of a page will die here by design.
- Keywords: the shared SEARCH TITLES rotation (DevOps Engineer → Senior DevOps → Cloud/Platform/SRE →
  Infrastructure/Senior Infrastructure → Linux/Systems → manager tier).
- Page deeper only while page 1 is full of in-scope titles; two pages per round is the practical
  ceiling. If ~8–10 titles in a row are out of scope, change location or keyword instead.

## 5. Apply flow

1. Open the job URL in a new tab; verify title/company/location/pay + scope + floor + dedupe.
2. Click **Quick apply** (`a[href*="/out?r="]`) → the same tab becomes the ca.indeed.com job page.
   External-only or already applied → SKIP + log.
3. Click **Apply now** → the same tab becomes `smartapply.indeed.com`.
4. Walk the wizard by URL module and % — order varies by employer:
   `resume-selection-module` → `contact-info-module` / `profile-location` → `questions-module` /
   `questions/N` → attestation → `demographic-questions-module` → `review-module` (100%) → Submit.
   Answers from `bank/core.md`; the full module-by-module field mapping is `prompts/indeed.md`
   ("Smartapply flow") — read it once if a module misbehaves.
5. Disabled Continue/Submit with the reCAPTCHA footer note → reload the smartapply tab ONCE and
   re-walk (answers persist). Still disabled → SKIP + log.
6. **"Applied" only on the visible confirmation.** Immediately: append the §6 row, append the
   registry row (channel `workopolis`), close the job tab.

## 6. Browser discipline

- `agent-browser connect 9222` first, always — otherwise agent-browser drives its own bundled Chrome
  with none of the candidate's logins and every site looks signed out. (The launcher's preflight already
  fails the run in that case; do not "work around" it.)
- Prefer one compact `eval` returning JSON over a full `snapshot -i`; snapshots of results pages cost
  thousands of tokens.
- Never click Sign out / Log out / Switch account, never clear cookies or site data, never run
  `agent-browser close` / `close --all`, never navigate to a /login or /signin URL.
- Work only in tabs this run opened; **close those tabs** when each job is done. the candidate's own tabs
  (she keeps Workopolis, Indeed, LinkedIn, Job Bank and Eluta open) are never touched.
- If Brave is unreachable → the launcher reports it; do not retry in a loop.

## 7. State

- `workopolis-automation/run-log.md` §6 = this channel's source of truth for the daily cap.
  Row: `| date | title @ company, country | applied/skipped/needs-review | reason |`, plus one
  RUN SUMMARY row at the end. **Write the applied row the moment the confirmation appears** — the
  launcher builds the candidate's Telegram report from those rows, not from prose.
- §5 = unanswered questions, with the job and the exact question.
- `applied-jobs-registry.md` = cross-channel dedupe; append after every confirmed submit.
- Append only. Never rewrite history.

## 8. Failure modes

| Symptom | Action |
|---|---|
| Preflight blocked (browser down / not attached / signed out / bot wall) | Do not start; the launcher has already told the candidate what to fix |
| Search page renders no cards | Change location; if the whole site is empty, try one keyword change, then report |
| Card has no "Quick apply" | External posting → SKIP + log |
| Indeed page shows "Applied" | Duplicate → SKIP + log |
| smartapply module unknown | Identify by URL; if it will not advance after 1 reload → SKIP + log |
| Required question not in `core.md` | Telegram the candidate, log §5, close tab, continue |
| French-language posting | SKIP + log ("language") |
| 429 / rate limit | Stop after 2, report partial |
| Bot wall / security check | Report it; do not attempt to authenticate |

## 9. Budget (token discipline)

- One compact eval per results page; no full snapshots of lists.
- The pre-filter is where the savings are — skip without opening a tab.
- ≤3 snapshots on the same page, ≤1 reload per job, ≤2 minutes per step.
- Log rows are one line each; no prose in the log.
- Do not read `run-log.md` §6 or `applied-jobs-registry.md` for answers — the launcher injects the
  applied/skipped digests into the prompt's PREFLIGHT section precisely so the run does not have to.
