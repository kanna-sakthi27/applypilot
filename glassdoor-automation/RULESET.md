# Glassdoor Auto-Apply Automation — Ruleset

Operating rules for scheduled runs on **Glassdoor** for the candidate (Alex Example). Each run
reads THIS file + `bank/core.md` first and follows them exactly.
Built: 2026-09-07 (rev 1 — from live reconnaissance of the Glassdoor → Indeed smartapply flow).
Companion systems: LinkedIn (`linkedin-automation/`), Indeed (`indeed-automation/`), foreign-direct
(`foreign-jobs-automation/`).

> **Scope (inherited from the candidate's LinkedIn/Indeed rulesets):** apply ONLY to DevOps and cloud-related
> jobs, engineer AND technical-manager level. In-scope: DevOps Engineer/Lead/Manager/Team Lead, Cloud
> Engineer/Architect/Lead/Cloud Manager, Infrastructure Manager, Linux Team Lead, SRE Manager/Lead,
> Platform Manager/Engineer (cloud), Engineering Manager (cloud/infra/DevOps), Head of
> DevOps/Cloud/Infrastructure, DevSecOps, SRE/Reliability with clear cloud/DevOps focus.
> NEVER apply to: pure software/backend/web development, data engineering/analytics/DS, ML/AI,
> QA/test (unless DevOps/CI-CD), security (non-DevSecOps), pure networking, pure DBA, frontend/mobile,
> general software engineering, non-technical management, junior/mid-only, internships.
> Ambiguous title → judge by description; core responsibility must be DevOps/cloud/infrastructure
> automation else SKIP + log.

## 0. CRITICAL — driving model (learned from LinkedIn/Indeed; verified on Glassdoor 2026-09-07)

- **Drive the candidate's real Brave via direct CDP — browser profile `brave`** (port 9222, attach-only).
  Pass `profile:"brave"` on EVERY browser call.
- **Never `navigate`/`open` a URL on an already-attached tab** (wedges the debugger). Use `open` only
  for a brand-new tab with a search/job URL. Otherwise stay click-driven + DOM evaluate.
- Click-driven: read state via `act` evaluate returning compact JSON (NOT full snapshots — they churn),
  act on real elements. If a synthetic `el.click()` is ignored, `scrollIntoView({block:'center'})` then
  use a **real CDP click at coordinates** (`act` kind `clickCoords`, element center).
- Before clicking a button, ALWAYS `scrollIntoView` + read its fresh center coords. Never click a
  button whose center y > window.innerHeight.
- If the browser is not running / tabs fail → report "browser unavailable (is Brave running?)" and quit.
  No retry loops.

## 1. Mission

Find Senior/Lead/**Manager** DevOps / Cloud / Platform / SRE roles (DevOps and cloud ONLY) across
Glassdoor job markets and apply via Glassdoor **"Easy Apply"** — which opens the **same Indeed
smartapply.indeed.com wizard** (Glassdoor is owned by Recruit Holdings / Indeed; verified 2026-09-07:
clicking Easy Apply on glassdoor.com opened `smartapply.indeed.com/beta/indeedapply/...` with the candidate's
Indeed profile logged in and her resume "ALEX EXAMPLE - CV.pdf" preloaded).
**Daily budget: 30 applications max/day on Glassdoor — HIT 30 (the candidate 2026-09-07): do not stop early while supply remains** (each channel has its own 30/day budget — see guardrail 4), per-run max 15, across 1–3 runs/day. Report after each run.

## 2. Hard guardrails (never cross)

1. **Never invent facts.** Answers only from `bank/core.md` (this folder's copy + canonical
   `bank/core.md`). Unknown required question (salary, visa, notice, start-date,
   clearance) → skip + log.
2. **No money/visa guesswork.** Salary/current-comp/notice/start-date: only from bank/core.md §2–§3
   (currency conversions). Sponsorship: answer truthfully — <NATIONALITY> + <OTHER_NATIONALITY> dual national (NOT
   <COUNTRY_OF_RESIDENCE>), needs sponsorship outside SL/IN — answer Yes/needs-sponsorship and **SUBMIT anyway**
   (the candidate: don't self-skip on unclear sponsorship). Only skip when the posting/form explicitly requires
   existing right-to-work/citizenship ("must be eligible to work in US", "citizens/PR only", "no
   sponsorship offered").
3. **Title/scope filter.** Senior/Lead/Staff/Principal/Manager/Team Lead/Head + DevOps/SRE/Platform/
   Infrastructure/Reliability/Cloud/Linux (see Scope). No junior/mid-only. No hourly rate below floor.
3a. **Apply-floor USD 7,000/mo** (the candidate 2026-09-07); per-country floor equivalents in bank/core.md §3.
    Skip postings whose posted band is below the floor.
4. **Daily cap 30 on Glassdoor — HIT IT (the candidate 2026-09-07; each channel keeps its own separate
   30/day budget). Per-run cap 15. Before EACH submission, count applied rows dated today (Asia/Kuala_Lumpur) in
   `glassdoor-automation/run-log.md` §6 (Glassdoor's own log) AND check the common registry; STOP once
   30 for the day. Per run ≤15. Keep going until 30 or the fresh pool is exhausted.
4a. **Cross-apply guard (the candidate 2026-09-07): BEFORE applying to any job, check the COMMON registry
    `<WORKSPACE>/applied-jobs-registry.md`** — same company + same/similar title already
    applied on ANY channel (LinkedIn/Indeed/Glassdoor/foreign/jaabz) → SKIP + log §6. After EVERY
    successful submit, append a row to the registry (date | title | company | channel=glassdoor |
    location | yes).
4b. **Hard blockers → SKIP and CONTINUE:** unanswerable required question, ATS/form bug, captcha wall
    on a JOB → skip that job, log it in run-log.md §6, keep applying. Never stop a run on one blocker.
5. **Never submit with an unanswered required question** → **ASK the candidate (Telegram <TELEGRAM_CONV_ID>) with the exact question + job, then CONTINUE the run with other jobs** (per the candidate 2026-09-07: don't skip asking). Return to it if she answers mid-run.
6. **Never bulk-apply.** One job at a time; wait 1.5–3 s after each step.
7. **Anti-spin guardrail.** Max ~2 min / 3 attempts per job. Can't complete a step after 3 fresh
   attempts → SKIP + log, close the smartapply tab, move on. Never re-snapshot the same page >3×
   without a state change. Never click the same element twice.
8. **Never use the word "the candidate" in answers.** Answer as Alex Example / "I".
9. **Not logged in** (Glassdoor OR Indeed) → do NOT attempt login. Report "needs login", quit.
10. **Checkpoint/captcha wall** → stop, report, don't fight it.
11. **bank/core.md wins** over this file on conflict.

## 3. Search strategy

- Use a brand-new tab (`browser action=open`, label e.g. `gd-run`) with a search URL:
  - Keyword search: `https://www.glassdoor.com/Job/jobs.htm?sc.keyword=<URL-encoded kw>`
  - The results page redirects to a canonical URL like
    `https://www.glassdoor.com/Job/<country>-<kw>-jobs-SRCH_IL..._KO....htm?sc.keyword=...`
  - **Easy Apply only filter**: add `&filter.easyApply=true` — verified to keep jobs whose detail page
    shows an **"Easy Apply"** button (Indeed-powered). Jobs without it show "Apply on employer site"
    (external → v1 SKIP, same as Indeed's external-apply rule).
  - **Remote only**: add `&filter.remoteWorkType=REMOTE` when wanted. Date posted / salary filters
    exist in-page.
- MARKET ROTATION (the candidate 2026-09-07; ADJUSTED 2026-09-07 — US FIRST): start on www.glassdoor.com (US)
  and STAY there until the fresh Easy-Apply pool is exhausted across multiple keyword passes; US is the
  highest-volume Easy-Apply market. Only then rotate: glassdoor.co.uk (UK) → glassdoor.ie (IE) → EU
  (English-only postings; skip Finnish/German/Dutch/French — the candidate only speaks English) → ca → au → sg.
  If a market is dry, switch — never quit the run while budget remains.
- Keyword rotation (DevOps/cloud only; one per search): `DevOps Manager`, `DevOps Lead`,
  `Senior DevOps Engineer`, `Cloud Manager`, `Cloud Engineer`, `Infrastructure Manager`,
  `Linux Team Lead`, `Platform Engineer`, `Platform Manager`, `Site Reliability Engineer`,
  `SRE Manager`, `DevSecOps`, `Head of DevOps`.
- Read the results list via a compact DOM evaluate: map each `a[href*="/job-listing/"]` card →
  {title, company, location, salary, href}. Take the **newest 10–15**. Skip out-of-scope titles,
  below-floor bands, explicit right-to-work exclusions. Dedupe against the common registry (4a).
- **Click a job card** → job detail page (`/job-listing/...`). Read the apply button:
  - **"Easy Apply"** → in scope, proceed to §4.
  - **"Apply on employer site"** / "Apply now" that redirects externally → SKIP + log (v1 =
    Glassdoor-Easy-Apply only; employer-site applies belong to the foreign-direct automation).
  - "Applied"/"Submitted" state → SKIP (dup).

## 4. Runtime flow (in order)

1. Read `bank/core.md` (this folder) + this RULESET + the common registry
   `<WORKSPACE>/applied-jobs-registry.md`.
2. Browser attach: profile `brave`, `action=tabs`. Find a glassdoor.com tab OR `open` a fresh one to
   `https://www.glassdoor.com/`. Confirm Glassdoor loads (may be logged out — see guardrail 9; the candidate
   has NOT yet created a Glassdoor account as of 2026-09-07 — but **Easy Apply does not require a
   Glassdoor login**; it uses the Indeed session, which IS logged in). Confirm Indeed is logged in by
   the presence of the candidate's resume once the smartapply tab opens.
3. Search (see §3). For each candidate in order:
   a. Open the job detail (click card / open listing URL in a NEW tab).
   b. Read title/company/location/salary + description keywords. Apply scope/title/salary filters;
      skip+log if out.
   c. Find the apply button. "Apply on employer site" → skip+log. "Easy Apply" → click it.
4. **Clicking "Easy Apply" opens a NEW smartapply.indeed.com tab** (verified 2026-09-07: URL
   `https://smartapply.indeed.com/beta/indeedapply/form/...`; the Glassdoor job tab redirects back with
   `from=smart-apply&ea=1` params). Find the new tab via `tabs` (URL starts smartapply.indeed.com) and
   act on its targetId. **The flow from here is IDENTICAL to the Indeed automation** — follow
   indeed-automation/RULESET.md §4 mechanics and map answers from THIS folder's bank/core.md:
   - **resume-selection-module (38%)**: the candidate's resume "ALEX EXAMPLE - CV.pdf" is
     pre-selected (radio checked). Click **Continue**.
   - **contact-info-module / profile-location**: name/email/phone prefilled (Malaysia +60,
     <PHONE_NATIONAL>). Fix country combobox to Malaysia (+60) + phone to `<PHONE_NATIONAL>` if reset; postal
     `<POSTCODE>`, city `<CITY>`, street `<CITY>, <STATE>` if empty. Continue.
   - **questions-module/questions/N** (screener): map each `fieldset` legend → bank/core.md §2 keyword
     table; click matching radio/checkbox INPUT; text fields only if required+mappable. Salary:
     Annually + amount (annual conversion §3) + currency combobox. Audit before Continue: every
     required radio group checked; no `[aria-invalid=true]`. Unmappable required → SKIP job + log.
   - **Attestation**: e-sign checkbox (click the input box), full name `Alex Example`,
     AI-consent per bank/core.md §2. If Continue/Submit is DISABLED with the reCAPTCHA footer note:
     reload the smartapply tab ONCE (`location.reload()`, accept beforeunload), re-walk (answers
     persist). Still disabled → SKIP + log.
   - **demographic/EEO module**: all "prefer not to answer"/decline; privacy-notice "Agree" checkbox
     if REQUIRED → check; then Review.
   - **review-module (100%)**: wait for "Preparing review". Hangs >15 s (recaptcha ERR_ABORT) →
     reload once + re-walk. Verify summary → click **Submit application**.
   - Confirmation = "Your application was submitted" / "We've received your application".
5. **Count as applied ONLY on visible confirmation.** Then:
   - Append to run-log.md §6 run log (this folder): `date | title @ company, country | applied |
     submitted-OK (via Glassdoor Easy Apply → smartapply)`.
   - Append to the COMMON registry `<WORKSPACE>/applied-jobs-registry.md` (4a).
   - Close the smartapply tab (`window.close()` via evaluate; accept beforeunload), return to the
     Glassdoor results tab.
6. Rate-limit/429/soft-block: stop applying, report partial, quit cleanly.
7. Repeat until day cap 30 / run cap 10 / list exhausted. End with a RUN SUMMARY row (§6) + concise
   report (Telegram, <180 words): found/applied/skipped, why skips, blockers, manual steps needed.

## 5. Browser discipline (smartapply-specific — inherited from Indeed)

- **Shields fix:** Brave Shields per-site exceptions for `smartapply.indeed.com`, `indeed.com`,
  `glassdoor.com`, `recaptcha.net`, `gstatic.com` must be **shields-down (setting 1)** — verified
  present for the Indeed set (Preferences + Secure Preferences; backup /tmp/Preferences.bak-indeed).
  Add `glassdoor.com` to the exception list the same way if recaptcha/apply issues appear. If submits
  fail with the reCAPTCHA footer note, re-check the exceptions exist (Brave can rewrite Preferences on
  exit).
- Flow order VARIES by employer (same as Indeed) — identify each step by URL module + % progress;
  keep clicking Continue until review-module.
- Compact `act evaluate` probes over full snapshots. After every step change → re-probe.
- Do NOT close the candidate's original tabs; only close the smartapply tabs the automation opened.
- beforeunload dialogs: accept via `browser action=dialog accept=true`.
- Radio/checkbox real clicks: click the **input element's own center**; verify checked after.
- Two consecutive jobs hanging on recaptcha → report shields issue, finish run with what applied.

## 6. Idempotency & state

- `run-log.md` §6 run log (this folder) = source of truth for Glassdoor day cap.
- `applied-jobs-registry.md` (workspace root) = cross-channel dedupe (4a). Append; never overwrite.
- "applied" only on visible confirmation. Mid-form abandoned jobs → log `skipped` with the exact
  stop-point reason; do NOT leave a needs-review draft.
- Duplicate detection: check the results card for an "Applied" state + grep the registry for the same
  (title @ company).

## 7. Failure modes

| Symptom | Action |
|---|---|
| Browser attach fails | Report "browser unavailable (is Brave running?)" — no retry loop |
| Glassdoor authwall / Indeed not logged in | Report "needs login" — stop |
| Interactive captcha/checkpoint | Report "checkpoint — manual review needed" — stop |
| Review hangs "Preparing review" | Reload once (accept beforeunload), re-walk; persists → skip + log |
| Form cannot be completed per bank | Skip + log §6, continue |
| Repeated 429 / rate limit | Stop after 2 hits, report partial |
| "Apply on employer site" (no Easy Apply) | Skip + log (v1 scope = Glassdoor Easy Apply only) |
| smartapply tab never opens | Retry the Easy Apply click once; else skip + log |

## 8. Budget (token discipline)

- 1–2 keyword searches max per run; compact evaluate probes only. Runs use the pinned cheap model
  (GLM-5.3 Flash on commandcode, or as configured in the cron job). If a step explodes in tokens,
  stop and report.
