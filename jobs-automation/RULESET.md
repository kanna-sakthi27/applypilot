# jobs.ch Auto-Apply — Ruleset (v1, 2026-10-10)

Operating rules for the scheduled **jobs** channel for the candidate (Alex Example). Each run
reads the shared preamble + `prompts/jobs.md` and the canonical bank (`bank/core.md`), then applies.
Built from live reconnaissance of jobs.ch's search and detail pages on 2026-10-10.

Companion channels: LinkedIn, Indeed, Glassdoor, Jaabz, Workopolis (`prompts/<channel>.md`).

> **Canonical files**
> - **Answer bank (single source of truth): `<WORKSPACE>/bank/core.md`**
> - **Cross-channel dedupe: `<WORKSPACE>/applied-jobs-registry.md`**
> - CV: `linkedin-automation/cv/CV_latest.pdf` (md5 1b2229c6dc7f348e8a9e890d3af09746)
> - Channel log: `jobs-automation/run-log.md` (§5 unanswered questions, §6 run log)

## 0. What jobs.ch is (verified live 2026-10-10)

The leading **Swiss** job portal, operated by **JobCloud** (which also runs jobup.ch for
French-speaking Switzerland and jobscout24.ch). Its own in-platform application flow is called
**"Easy apply"**.

**Facts that shape everything below:**

- **Easy apply is jobs.ch's own form — there is NO redirect to the employer's site** (JobCloud). The
  form asks only the **standard fields (name, email, phone) plus the CV** and, per JobCloud,
  **does not include custom screening questions**. That makes each submission short and cheap.
- For **registered (logged-in) users** the fields and the CV are **pre-filled / already attached**.
  So the session that matters *is* the candidate's jobs.ch login. A run must not attempt to log in.
- Postings **with the "Easy apply" badge** are submittable here; postings **without it** are
  external/company-site applies → SKIP + log.
- **Swiss market = German/French/Italian first.** the candidate speaks **English + Tamil only** (core.md §6),
  so German/French/Italian-required postings are a hard skip. Expect a high skip rate by design.
- **Pay is CHF** (`core.md` §3): apply-floor **CHF 5,700/mo**, expected **CHF 6,500/mo**.

## 1. Mission

Mine jobs.ch for fresh in-scope DevOps / cloud / infrastructure / Linux / systems roles (engineer AND
technical-manager level), apply through **Easy apply** using the canonical answer bank, and keep the
shared registry and this channel's §6 log in sync. **Switzerland only.**

## 2. Scope

In scope (the core of the job is running / automating / leading infrastructure — the title need not
say "DevOps"): DevOps · SRE / Reliability · Platform · Release engineering · Cloud
(engineer/architect/lead/manager) · **Infrastructure** (engineer/senior/lead/manager/operations) ·
**Linux / Unix / Systems** (Linux engineer/systems engineer/senior systems engineer/administrator/
lead/team lead) · the manager tier (DevOps/Cloud/Infrastructure/Platform/SRE/Linux/Systems Manager,
Team Lead, Engineering Manager, Head of …).

Never: helpdesk / desktop / IT support / service desk · pure networking or NOC · pure DBA · security
that is not DevSecOps · application/backend/frontend/mobile development · data / analytics / ML / AI /
DS · QA (unless CI/CD-focused) · Oracle/SAP/HR systems · Microsoft 365 workplace · sales / recruiting
/ non-technical management · junior / graduate / intern / "associate". Ambiguous title → the core
responsibility must be infrastructure, else SKIP + log.

**Swiss-specific skip list:** a **German / French / Italian** language requirement beyond beginner
(English + Tamil only) · an *explicit* posted band below the **CHF floor (5,700/mo)** ·
**hourly / day-rate / sub-12-month** postings (regardless of rate) · external postings (no Easy apply
badge) · roles demanding existing Swiss/EU work authorization or citizenship.

## 3. Guardrails (never cross)

1. **Never invent facts.** Every answer comes from `bank/core.md`. `core.md` wins on any conflict.
2. **Visa is answered truthfully and the application is SUBMITTED.** Outside Sri Lanka: sponsorship
   **Yes**, authorized to work **No**. Do not self-skip because the ad omits sponsorship — let the
   employer decide. Skip only an explicit wall (no sponsorship offered, citizens/PR only, must already
   hold work authorization).
3. **Hard walls → SKIP + log and continue**, one attempt at most: captcha/Cloudflare, a form bug after
   1 reload / 3 attempts, an unmappable REQUIRED question that is a true wall, external-only apply,
   dead listing. Never stop a run on one blocker, and never park a needs-review draft.
4. **A missing skill is not automatically a wall** — see `core.md` §5. Apply when the tool is one line
   in a broader stack; answer its experience question truthfully; never tick it as held.
5. **Never bulk-apply.** One job at a time, 1.5–3 s between steps, verify state after each action.
6. **Never answer salary below USD 8,000/mo expected / the CHF 5,700/mo floor** (CHF values in
   `core.md` §3). Never state a nationality other than **<NATIONALITY>**.
7. **Daily cap 30** submitted per day for this channel (counted from this channel's §6, MYT);
   **per-run target 15** (inherited from the shared preamble). Never exceed the cap.
8. **Rate limit / 429 / soft block** → stop applying after 2 hits, report partial, quit cleanly.
9. **Dedupe** before every submit: same posting, or same title at the same company, already applied on
   ANY channel (registry) → SKIP + log. A *different* role at the same company is fine.
10. **Never use the word "the candidate" in any form answer.** Answer as Alex Example / "I".

## 4. Discovery

Search URL: `https://www.jobs.ch/en/vacancies/?term=<urlencoded keyword>&page=<n>` (English UI);
an optional `location=` narrows to a canton/city. Locations rotate:
`zürich` → `bern` → `basel` → `zug` → `lausanne` → `geneva` → `winterthur` → `switzerland`.

- Read the list with **ONE compact eval** anchored on `a[href*="/en/vacancies/detail/"]`, mapping each
  card to `{title,company,location,workload,contract,href,easyApply}`.
- **Pre-filter before opening anything:** out-of-scope title, German/French/Italian-required,
  *explicit* sub-floor CHF, hourly/day-rate, and **no Easy apply badge**. Most of a page dies here —
  that is the design.
- Keywords: the shared SEARCH TITLES rotation (DevOps Engineer → Senior DevOps → Cloud/Platform/SRE →
  Infrastructure/Senior Infrastructure → Linux/Systems → manager tier).
- Page deeper only while page 1 is full of in-scope titles; two pages per round is the practical
  ceiling. If ~8–10 titles in a row are out of scope, change city or keyword instead.

## 5. Apply flow

1. Open the job URL (`https://www.jobs.ch/en/vacancies/detail/<uuid>/`) in a new tab; verify
   title/company/location + scope + language + floor + dedupe.
2. Click **Easy apply**. No Easy apply control (external posting) → SKIP + log ("external"). An
   "already applied" state → SKIP + log ("duplicate").
3. **Login state:** Easy apply is designed for logged-in users (fields + CV pre-filled). If jobs.ch
   presents a **login/register page instead of the form**, do NOT attempt to authenticate — report
   "needs the candidate to sign in to jobs.ch" and stop. (The launcher's preflight probes this too.)
4. Complete the form: name / email / phone from `bank/core.md` §1; confirm the CV is the canonical
   `CV_latest.pdf`; answer any screener from `bank/core.md`. Never invent an answer; a REQUIRED
   question not in core.md → Telegram the candidate + log §5 + continue.
   - **Form specifics (DOM selectors, exact button labels, module order)** are learned on the **first
     supervised run** and appended here as a §5.1 note. Do not guess them; if the form does not behave
     as above, take ONE snapshot to read it, then either complete it or SKIP + log.
5. Submit; **count as applied ONLY on the visible confirmation** ("Application sent" / "Your
   application has been submitted" / similar). Disabled Submit after 1 reload → SKIP + log.
6. On a confirmed submit: append the §6 row, append the registry row (channel `jobs`), close the tab,
   move to the next job.

## 6. Browser discipline

- `agent-browser connect 9222` first, always — otherwise agent-browser drives its own bundled Chrome
  with none of the candidate's logins and every site looks signed out. (The launcher's preflight already fails
  the run in that case; do not "work around" it.)
- Prefer one compact `eval` returning JSON over a full `snapshot -i`; snapshots of results pages cost
  thousands of tokens.
- Never click Sign out / Log out / Switch account, never clear cookies or site data, never run
  `agent-browser close` / `close --all`, never navigate to a /login or /signin URL.
- Work only in tabs this run opened; **close those tabs** when each job is done. the candidate's own tabs are
  never touched.
- If Brave is unreachable → the launcher reports it; do not retry in a loop.

## 7. State

- `jobs-automation/run-log.md` §6 = this channel's source of truth for the daily cap.
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
| jobs.ch login page instead of Easy apply | Report "needs the candidate to sign in to jobs.ch" — stop, do not authenticate |
| Card has no "Easy apply" | External posting → SKIP + log |
| Detail page shows "already applied" | Duplicate → SKIP + log |
| German/French/Italian posting | SKIP + log ("language") |
| Required question not in `core.md` | Telegram the candidate, log §5, close tab, continue |
| Submit disabled after 1 reload | SKIP + log |
| 429 / rate limit | Stop after 2, report partial |
| Bot wall / security check | Report it; do not attempt to authenticate |

## 9. Budget (token discipline)

- One compact eval per results page; no full snapshots of lists.
- The pre-filter is where the savings are — skip without opening a tab.
- ≤3 snapshots on the same page, ≤1 reload per job, ≤2 minutes per step.
- Log rows are one line each; no prose in the log.
- Do not read `run-log.md` §6 or `applied-jobs-registry.md` for answers — the launcher injects the
  applied/skipped digests into the prompt's PREFLIGHT section precisely so the run does not have to.
