## candidate OVERRIDES 2026-09-07 (apply to every run)
1. HIT 30/DAY PER CHANNEL: daily target is 30 submitted applications per channel. Do NOT stop early while in-scope supply remains. Per-run attempt cap 15 (LinkedIn: 30). Keep rotating keywords/markets (US/UK/IE/EU-English/CA/SG/AU/remote) until 30/day is reached or the fresh pool is genuinely exhausted; then log a RUN SUMMARY with counts.
2. UNANSWERED QUESTION -> ASK, DON'T SKIP: if a required screening question has no answer in the bank, do NOT abandon/skip it silently. Send the candidate a Telegram message via conversations_send to <TELEGRAM_CONV_ID> (user <TELEGRAM_CHAT_ID>): job title @ company, the EXACT question text and options, note the application is paused on her answer, log it in the run-log section 5, then CONTINUE with other jobs. If she answers before the run ends, come back and complete it.

# Jaabz Auto-Apply Automation — Ruleset (v1, 2026-09-07)

Operating rules for scheduled runs on **Jaabz** (jaabz.com) for the candidate (Alex Example).
Each run reads THIS file + `bank/core.md` first and follows them exactly. Built 2026-09-07 from live
reconnaissance of jaabz.com (search UI, hub URLs, job pages, Apply-Now destinations, Mark-Applied API).
Companion systems: LinkedIn (`linkedin-automation/`), Indeed (`indeed-automation/`), Glassdoor
(`glassdoor-automation/`), foreign-direct (`foreign-jobs-automation/`).

> **Canonical files**
> - This ruleset + `bank/core.md`: `<WORKSPACE>/jaabz-automation/`
> - **Canonical answer bank (single source of truth): `<WORKSPACE>/bank/core.md`** —
>   reuse its answers verbatim (profile, salary conversions incl. floor equivalents, CTC, templates).
> - **Common cross-channel registry (dedupe): `<WORKSPACE>/applied-jobs-registry.md`** —
>   check BEFORE every submit; append AFTER every successful submit (channel = `jaabz`).
> - CV: `<WORKSPACE>/linkedin-automation/cv/CV_latest.pdf`.

> **Scope (inherited from the candidate's LinkedIn/Indeed rulesets):** apply ONLY to DevOps and cloud-related
> jobs, engineer AND technical-manager level. In-scope: DevOps Engineer/Lead/Manager/Team Lead, Cloud
> Engineer/Architect/Lead/Cloud Manager, Infrastructure Engineer/Manager, Linux Team Lead/Admin (senior),
> SRE/Reliability (clear cloud/DevOps focus), Platform Engineer/Manager (cloud), DevSecOps, Engineering
> Manager (cloud/infra/DevOps), Head of DevOps/Cloud/Infrastructure, Staff/Principal equivalents.
> NEVER: pure software/backend/web dev, data/ML/AI, QA (non-CI/CD), security (non-DevSecOps), pure
> networking, DBA, frontend/mobile, non-technical management, junior/mid-only, internships, and
> **entry-level-labelled listings (Jaabz labels experience like "Associate"/"Not Applicable" on cards —
> judge by the actual title/description; a listed "DevOps Engineer" with 2–5 yr expectation is mid →
> skip)**. Ambiguous → judge by description; core must be DevOps/cloud/infra automation else SKIP+log.

## 0. CRITICAL — driving model (inherited from LinkedIn/Indeed/foreign; verified on jaabz 2026-09-07)

- **Drive the candidate's real Brave via direct CDP — browser profile `brave`** (port 9222, attach-only).
  Pass `profile:"brave"` on EVERY browser call.
- **Never `navigate`/`open` a URL on an already-attached tab** (wedges the debugger). Use `open` only
  for a brand-new tab with a hub/job URL. Otherwise stay click-driven + DOM evaluate.
- Click-driven: read state via `act` evaluate returning compact JSON (NOT full snapshots — they churn),
  act on real elements. If a synthetic `el.click()` is ignored, `scrollIntoView({block:'center'})` then
  use a **real CDP click at coordinates** (`act` kind `clickCoords`, element center).
- Before clicking a button, ALWAYS `scrollIntoView` + read its fresh center coords. Never click a
  button whose center y > window.innerHeight.
- If Brave is not attached (`browser action=status profile=brave` → cdpReady false) → relaunch via
  `su - <USER> -c 'export DISPLAY=:0; nohup brave-browser --remote-debugging-port=9222 --restore-last-session >/tmp/brave-debug.log 2>&1 &'`, wait, re-check once. Still down → stop, report
  "browser unavailable (is Brave running?)". No retry loops.

## 1. Mission

Mine **Jaabz** (visa-sponsorship/relocation/remote DevOps+cloud board) for fresh in-scope roles, route
each to its real application surface (LinkedIn Easy Apply → employer ATS), submit truthfully from the
canonical answer bank, and keep the shared registry + Jaabz "Mark Applied" state in sync.
**Daily budget: 30 applications max/day on Jaabz** (the candidate 2026-09-07; each channel has its own 30/day
budget — see guardrail 4). Per-run soft target **8–10**. Report after each run (Telegram).

## 2. Hard guardrails (never cross)

1. **Never invent facts.** Answers only from `bank/core.md` (canonical) + this
   folder's `bank/core.md` + workspace `bank/core.md`. Unknown required question (salary, visa, notice,
   start-date, clearance) → skip + log §5.
2. **No money/visa guesswork.** Salary expected **USD 8,000/mo**; apply-floor **USD 7,000/mo**
   (the candidate 2026-09-07). Per-country conversions/floor equivalents in canonical bank §2–§3. Nationality:
   **<NATIONALITY> + <OTHER_NATIONALITY> dual national** (NOT <COUNTRY_OF_RESIDENCE>); needs sponsorship outside SL/IN. Answer
   visa/sponsorship truthfully (Yes/needs-sponsorship) and **SUBMIT anyway** — only skip when the
   posting explicitly requires existing right-to-work/citizenship ("citizens/PR only", "must already
   hold work auth", "no sponsorship offered", "EU passport required", "SC clearance/5-yr UK residency").
3. **Title/scope filter.** See Scope. Skip below-floor bands (posted salary range under the country
   floor). Skip any listing demanding a stack not in the bank when the question is REQUIRED
   (ArgoCD/GitOps = never tick Yes; Python/Go = No — willing-to-learn only as free text; see canonical
   §2 experience mapping). Jaabz "AI SUMMARY" tags on premium jobs are a quick filter aid but ALWAYS
   read the real description fields before deciding.
4. **Daily cap 30 on Jaabz** (own budget — the candidate 2026-09-07). Before EACH submission, count applied
   rows dated today (Asia/Kuala_Lumpur) in `jaabz-automation/run-log.md` §6; STOP once 30. Per run ≤10.
4a. **Cross-apply guard (the candidate 2026-09-07): BEFORE applying to any job, check the COMMON registry
    `<WORKSPACE>/applied-jobs-registry.md`** — same company + same/similar title already
    applied on ANY channel (linkedin/indeed/glassdoor/foreign/jaabz) → SKIP + log §6. **Also check the
    Jaabz page's own state**: if the job shows "Applied" (Mark Applied active) → skip (dup from an
    earlier run). After EVERY successful submit: append a registry row (channel=jaabz) + click
    **Mark Applied** on the Jaabz job page (see §4 step 7).
4b. **Hard blockers → SKIP and CONTINUE** (the candidate 2026-09-07): unanswerable required question, ATS/form
    bug, captcha wall on a JOB → skip that job, log §6, keep going. Never stop a run on one blocker.
    Only stop at run cap (10), day cap (30), or exhausted fresh list.
5. **Never submit with an unanswered required question** → skip + log.
6. **Never bulk-apply.** One job at a time; wait 1.5–3 s after each step. Never open many job tabs at
   once.
7. **Anti-spin guardrail.** Max ~2 min / 3 attempts per job. Can't complete a step after 3 fresh
   attempts → SKIP + log, close tabs you opened, move on. Never re-snapshot the same page >3× without
   a state change. Never click the same element twice.
8. **Never use the word "the candidate" in answers.** Answer as Alex Example / "I".
9. **Not logged in / authwall** (Jaabz account needed only for premium jobs + Mark Applied; LinkedIn /
   Indeed / Google sessions needed for the actual apply) → check which session is missing. If a role
   REQUIRES an account we don't have + no Google SSO → skip + log ("needs account"). Do NOT attempt
   password logins we don't own. Report "needs login" + quit only if EVERYTHING is walled.
10. **Captcha / Cloudflare / OTP / checkpoint** → stop that application, log, move on. Never fight.
11. **Never touch other people's/live tabs.** Work ONLY in tabs this run opened (label
    `jb-<country-or-cat>-<n>`); never navigate/act on the candidate's existing tabs (human may be mid-flow —
    e.g. the crashed Glassdoor session left live Glassdoor tabs; don't disturb them). Close your own
    tabs when done with a job. Never close hers.
12. **Rate limits / 429s** → stop after 2 hits, report partial, quit cleanly.
13. **bank/core.md wins** over this file on conflict. Report ≤ ~180 words (unless a blocker needs detail).

## 3. Search strategy (Jaabz discovery surfaces — verified 2026-09-07)

Jaabz = Laravel app; query-string filters on `/jobs` are NOT reliably honored by the SPA, but the
**server-rendered hub URLs ARE** (they show "Showing 1-24 of N jobs" with real filtered cards). Use the
hubs + the on-page search form:

- **Category + visa hub:** `https://jaabz.com/jobs/devops/visasponsorship` — "Showing 1-24 of ~214 jobs"
  (DevOps + visa sponsorship). Also: `/jobs/devops/relocation`, `/jobs/devops/remote`.
- **Country + visa hub:** `https://jaabz.com/jobs/in/<country-slug>/visasponsorship`
  (verified: united-kingdom, canada, germany, united-arab-emirates …). Country slugs from the
  Countries menu / hub page footer links.
- **All-category visa hub:** `https://jaabz.com/jobs/visasponsorship` (then filter by category in the
  page, or scan titles — but prefer the devops hub for signal).
- **On-page search form** (when a specific keyword is wanted): fill the search textbox (ref the
  snapshot), set the category combobox to **Devops**, optionally tick Visa/Remote, click **Search
  jobs**. Do NOT try to force filters via URL query params — they silently fall back to "All Jobs".
- Pagination: `?page=2` style links at the bottom ("2 3 4 … Next »"). Stay on pages 1–2 per hub.
- MARKET ROTATION (mirrors Indeed/foreign, English-only — the candidate 2026-09-07): the visa hubs are
  worldwide; prefer remote + the rotation's current country. Cycle countries: CA → SG → UK → IE → DE/NL
  → AU → UAE → remote-global. Skip roles needing Finnish/German/Dutch/French/etc.
- Read the results list via a compact DOM evaluate: each job card links to `/jobs/<id>-<slug>`; map to
  {title, company, country, job-type, exp-level, visa/relocation/remote tags, href}. Take the newest
  10–15. Skip out-of-scope titles, below-floor bands, explicit right-to-work exclusions, dups.

## 4. Runtime flow (in order)

1. Read `bank/core.md` (this folder) + this RULESET + the canonical bank
   (`bank/core.md`) + the common registry (`applied-jobs-registry.md`).
2. Browser attach: profile `brave`, `action=tabs`. Count today's `applied` rows in this folder's
   `run-log.md` §6 → remaining budget = 30 − count. **If ≤ 0 → report and stop.**
3. Open ONE new tab to the rotation's hub URL (§3). Confirm it renders job cards ("Showing X of Y
   jobs"). If the hub is empty/walled → try the on-page search form, else switch country hub.
4. For each candidate job (newest first, max ~15 reviewed):
   a. Open its job page in a NEW tab (`https://jaabz.com/jobs/<id>-<slug>`).
   b. Read title / company / country / tags / salary-if-shown / AI-summary / description (compact
      evaluate probe). Apply scope/title/salary/dedupe filters (guardrails 2–4a). Skip+log if out.
   c. **Read the Apply Now link** (`a[title="Apply now"]`, `.btn-apply-sidebar`) → decide routing:
      - href contains `linkedin.com/jobs/view/` → LinkedIn destination. Open in a new tab.
      - href is an employer ATS / careers URL → foreign-direct mechanics.
      - href cloaked to `/go/...` → follow it once and inspect the real destination.
      - no Apply Now / "email us" only → skip + log.
5. **Apply on the destination** per the matching existing flow:
   - LinkedIn Easy Apply: follow `linkedin-automation/RULESET.md` + the LinkedIn skill's gotchas
     (React #418 → reload; modal div detect via "Apply to <Company>"; Save-draft interstitial →
     Save then Continue; scrollIntoView + clickCoords). Answers from canonical bank.
   - Employer ATS: follow `foreign-jobs-automation/ATS_PLAYBOOK.md` (Greenhouse/Lever/Ashby guest +
     Google SSO OK; Workday/SuccessFactors/Taleo account+OTP → skip unless Google SSO; captcha → skip).
   - If the destination job is NOT the same role (mismatched title/company) → do not apply; skip+log.
6. **Count as applied ONLY on visible confirmation** ("Your application was submitted" / "We've
   received your application" / thank-you page). Then:
   a. Append to this folder's `run-log.md` §6 run log: `date | title @ company, country | applied |
      submitted-OK (via Jaabz → <destination>)`.
   b. Append to the COMMON registry `applied-jobs-registry.md` (guardrail 4a) with channel `jaabz`.
   c. On the Jaabz job tab, click **Mark Applied** (`button.applied-toggle[data-job-id]`) so Jaabz
      itself shows the job as applied for future runs; verify the button turns active (" Applied").
      If the click fails (not logged in / JS error) → note it, do not fight it.
   d. Close the destination + job tabs you opened (evaluate `window.close()` after accepting
      beforeunload; keep the hub tab).
7. Mid-form abandoned jobs → log `skipped` with the exact stop-point reason; NEVER leave a needs-review
   draft behind (per 4b). If a LinkedIn draft was saved by the flow, discard/close it per the LinkedIn
   gotchas (do not leave a parked draft).
8. Rate-limit/429/soft-block → stop applying, report partial, quit cleanly.
9. Repeat until day cap 30 / run cap 10 / fresh list exhausted. End with a RUN SUMMARY row (§6) +
   concise report (Telegram, <180 words): applied list, skipped count + top reasons, walls, day total.

## 5. Browser discipline (Jaabz-specific + inherited)

- Jaabz is a Laravel/jQuery app; the job cards + buttons are plain DOM — compact evaluate probes work
  well. Full-page snapshots churn — avoid.
- The header shows the logged-in account ("Alagartnam S…"). If the header shows Sign In only →
  premium job details + Mark Applied are unavailable: free jobs still show enough to apply; log
  "Jaabz not logged in" if a needed action is blocked.
- **Premium jobs** show an AI SUMMARY + full description only when logged in (the candidate's account is
  logged in). If a premium detail is still blurred/blocked by an email-verification wall → skip + log
  ("premium locked: email verify").
- **Job-card clicks**: cards have a whole-card click handler (`.job-card-professional[data-job-url]`)
  → clicking anywhere except links/bookmark opens the job. Prefer clicking the title link.
- beforeunload dialogs (dirty apply forms): accept via `browser action=dialog accept=true`.
- Refs/coords go stale after every navigation → re-probe before each action.
- Never close the candidate's original tabs; only close tabs this run opened.
- Brave Shields: keep the existing shields-down exceptions for smartapply/indeed/recaptcha (needed by
  the LinkedIn/Indeed-side apply). If LinkedIn/Indeed recaptcha issues recur → per those rulesets.

## 6. Idempotency & state

- `jaabz-automation/run-log.md` §6 = source of truth for the Jaabz day cap.
- `applied-jobs-registry.md` (workspace root) = cross-channel dedupe (guardrail 4a). Append; never
  overwrite. Rows: `| date | title | company | jaabz | country | yes |`.
- Jaabz "Mark Applied" state = secondary dedupe (job page shows Applied on later visits).
- "applied" only on visible confirmation. Mid-form abandonment → log `skipped` + reason. Duplicate
  detection: grep the registry (company + title) + check the Jaabz job page state.

## 7. Failure modes

| Symptom | Action |
|---|---|
| Browser attach fails | Relaunch once (guardrail 0); else report "browser unavailable" |
| Hub page renders 0 jobs / wrong market | Try on-page search form; else switch country hub; else report |
| Jaabz authwall on premium/Mark-Applied | Free jobs still applyable; log "Jaabz not logged in" if blocked |
| Apply Now → LinkedIn/ATS wall (captcha/OTP/account) | Skip that job + log, continue (guardrail 10) |
| Required Q not in bank | Skip + log to §5, continue |
| 429 / rate limit | Stop after 2, report partial |
| Destination role ≠ Jaabz role (title/company mismatch) | Skip + log, continue |
| Apply Now missing / email-only | Skip + log, continue |
| Glassdoor/other live tabs wedged | Don't touch them; open your own tabs |

## 8. Budget (token discipline)

- 1 hub + at most a second keyword/hub per run; compact evaluate probes only. Runs use the pinned
  cheap model (DeepSeek V4 Flash on commandcode — same as LinkedIn; set in the cron job). If a step
  explodes in tokens, stop and report. One job at a time; slow = safe.
