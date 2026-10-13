## candidate OVERRIDES 2026-09-07 (apply to every run)
1. HIT 30/DAY PER CHANNEL: daily target is 30 submitted applications per channel. Do NOT stop early while in-scope supply remains. Per-run attempt cap 15 (LinkedIn: 30). Keep rotating keywords/markets (US/UK/IE/EU-English/CA/SG/AU/remote) until 30/day is reached or the fresh pool is genuinely exhausted; then log a RUN SUMMARY with counts.
2. UNANSWERED QUESTION -> ASK, DON'T SKIP: if a required screening question has no answer in the bank, do NOT abandon/skip it silently. Send the candidate a Telegram message via conversations_send to <TELEGRAM_CONV_ID> (user <TELEGRAM_CHAT_ID>): job title @ company, the EXACT question text and options, note the application is paused on her answer, log it in the run-log section 5, then CONTINUE with other jobs. If she answers before the run ends, come back and complete it.

# LinkedIn Auto-Apply Automation — Ruleset

Operating rules for the twice-daily scheduled runs. Each run reads THIS file + `bank/core.md` first and follows them exactly.
Last updated: 2026-09-07 (rev 5).

> **Scope (the candidate, 2026-09-06): apply ONLY to DevOps and cloud-related jobs.**
> In-scope: DevOps Engineer/Lead/Manager, Cloud Engineer/Architect/Lead, SRE with a clear DevOps/cloud focus, Platform Engineer with a cloud/DevOps focus, Infrastructure Engineer (cloud), DevSecOps, Site Reliability (cloud/DevOps), roles that are clearly cloud/DevOps in nature (e.g. AWS/Azure/GCP engineer).
> Out-of-scope — NEVER apply: pure backend/software/web/application development (e.g. Software Engineer/Developer), data engineering/analyst/data science, QA/test automation (unless explicitly a DevOps/CI-CD quality role), security engineer (non-DevSecOps), networking (non-cloud), database administrator (pure), frontend/mobile, ML/AI engineer, product/management non-technical, or any role whose title/language centers on general software engineering rather than DevOps/cloud.
> When a title is ambiguous, judge by the job description: apply only if the core responsibility is DevOps/cloud/infrastructure automation; otherwise skip + log in §6.

## 0. CRITICAL — driving model (learned the hard way)

- **PRIMARY (since 2026-09-06): drive the candidate's real Brave via direct CDP — browser profile `brave`** (Brave runs with `--remote-debugging-port=9222`; attach-only, sees all tabs since the candidate granted full access). Pass `profile:"brave"` on every browser call, find the `linkedin.com` tab via `tabs`, and act on that tab's targetId.
- **FALLBACK ONLY: the OpenClaw Browser Relay extension** (`chrome` extension profile, relay ws://127.0.0.1:18799) — use it only if `brave` tabs fails and a `chrome` tabs call actually succeeds. The relay frequently wedges after extension re-pairing or access-mode changes.
- **Never `navigate`/`open` a URL on an already-attached tab** — it wedges the debugger session ("Invalid InterceptionId" storm, then "Playwright page target identities are temporarily unavailable" until a manual detach/re-attach in Brave).
- **Click-driven only**: read the page (tabs/snapshot), then act on in-page elements (clicks, typing into the existing LinkedIn search UI). Use `open` only for a brand-new tab, and only if the attach mode allows it; if new-tab open fails, do everything in the existing LinkedIn tab.
- If `tabs`/`snapshot` on the `chrome` extension profile returns "Playwright page target identities are temporarily unavailable", the relay is wedged → stop, report "needs manual re-attach in Brave (click OpenClaw icon off/on)", and quit. Do NOT retry-loop. (The `brave` direct-CDP profile is NOT affected by extension wedges.)

---

## 1. Mission

Find **Senior/Lead DevOps / Cloud / Platform / SRE** roles — **DevOps and cloud-related jobs ONLY** (the candidate's explicit scope, 2026-09-06; see §2 guardrail 3a) — worldwide and **apply via LinkedIn Easy Apply** in the candidate's Brave browser (browser profile `brave` — direct CDP; see §0), using only the answer bank in `bank/core.md`. Report results after each run.

## 2. Hard guardrails (never cross)

1. **Never invent facts.** Answers come only from `bank/core.md`. If a question's answer is not there and `best-guess from profile` cannot derive it safely (salary, visa/sponsorship, notice period, start date, criminal/security clearance), **skip the job** and log it under "Unanswered questions" in bank/core.md.
2. **No money/visa guesswork.** Salary expectations, sponsorship needs, notice periods, availability dates: if not in bank/core.md → skip + log. These are the only hard-stop categories; everything else may use profile best-guess (per the candidate's policy choice).
3. **Title filter (EXPANDED by the candidate 2026-09-07).** In-scope titles: Senior/Lead/Staff/Principal/Manager/Team Lead/Head + DevOps/SRE/Platform/Infrastructure/Reliability/Cloud/Linux — INCLUDING: **DevOps Manager, Cloud Manager, Infrastructure Manager, Linux Team Lead, SRE Manager, Platform Manager, DevOps Team Lead, Engineering Manager (over DevOps/cloud/infra), Head of DevOps/Cloud/Infrastructure**, and clearly equivalent senior roles (e.g. "Lead Cloud Engineer"). Technical manager/team-lead roles over DevOps/cloud/infra teams are IN SCOPE; non-technical management (product/people-only without engineering scope) is out. No internships/junior/mid-only titles. No contract-to-hire without approval. Skip "entry level".
3a. **Scope filter — DevOps/cloud ONLY (the candidate, 2026-09-06; EXPANDED 2026-09-07).** Apply ONLY to **DevOps and cloud-related** roles — engineer AND technical-manager level. In scope: DevOps, Cloud Engineer/Architect, SRE/Reliability with a clear cloud/DevOps focus, Platform Engineer (cloud/DevOps), Infrastructure Engineer (cloud), DevSecOps, plus **DevOps/Cloud/Infrastructure Manager, Linux Team Lead, SRE/Platform Manager, DevOps Team Lead, Eng Manager (cloud/infra), Head of DevOps/Cloud**. **NEVER apply to**: pure software/backend/web development, data engineering/analytics/DS, ML/AI, QA/test automation (unless DevOps/CI-CD), security (non-DevSecOps), pure networking or pure DBA roles, frontend/mobile, or any role whose core is general software engineering. Ambiguous title → judge by description; core responsibility must be DevOps/cloud/infrastructure automation or skip + log §6.
4. **Daily budget: 30 applications/day on LinkedIn (the candidate 2026-09-07; separate 30/day budgets exist for Indeed and for foreign-direct).** Count rows with today's date (Asia/Kuala_Lumpur) and Action=applied in run-log.md §6 (LinkedIn's own log) before/during the run; STOP once 30 for the day. Per-run soft target 8–10 apps; never exceed 10 in one run (rate-limit safety). Lower if LinkedIn starts rate-limiting.
5. **Never submit a job where a required Easy-Apply question was left unanswered by the ruleset** → skip + log.
6. **Never bulk-apply.** One job at a time, wait for each form to settle. Slow = safe.
7. **Anti-spin guardrail (learned 2026-09-04):** a run MUST NOT spend more than ~2 minutes / ~6 snapshot attempts on one job without acting. If the Easy Apply button or form can't be found after 3 fresh snapshots, **SKIP the job, log it with reason in §6** ("could not find Easy Apply / could not complete form"), and move to the next candidate. Never re-snapshot the same page more than 3× without a state change. Never click the same element twice.
7. **Never use the word "the candidate" in answers** — answer as Alex Example / "I" unless the form explicitly asks for a first name (then use the profile name as shown on LinkedIn).
8. **If the browser session is not logged in** → do NOT attempt login/password. Stop, report "needs login", and quit. (Login is the candidate's one-time manual step.)
9. **If LinkedIn shows a checkpoint / "Verify" / captcha / 2FA wall** → stop immediately, report it, do not fight it.
10. **The answers file always wins.** If this file and bank/core.md conflict, bank/core.md wins.
10a. **Tools (the candidate 2026-09-07):** claim GitLab CI/CD (yes), Bash/Shell (yes). NEVER claim: ArgoCD/GitOps (willing to learn — may note that only in free-text), Python, Go, Java, Rust, Kotlin. Screening "Do you have X?" → Yes only for bank tools; required non-bank tool → skip + log.
10b. **Hard blockers → SKIP and CONTINUE (the candidate 2026-09-07):** never stop a run or leave a needs-review draft on a single hard blocker (unanswerable required question, ATS form bug, etc.). Skip the job, log it, and keep applying to the next candidates until the run budget or day cap (30) is reached.
11. **If the extension debugger is wedged** ("Playwright page target identities are temporarily unavailable" or tab reads fail after a drive attempt) → stop, report "needs manual re-attach in Brave", quit. Never retry-loop or URL-navigate an attached tab.

## 3. Search strategy (worldwide)

- **Click-driven search in the existing LinkedIn tab** (do NOT navigate to a jobs-search URL):
  - The LinkedIn tab is on `linkedin.com` (feed or jobs). Use the in-page **Jobs** nav item (top bar) or the search box → type the keyword → select "Jobs" → apply filters.
  - Filters to set in-page: **Easy Apply** toggle ("Easy Apply" filter) + **Date posted** (Past 24 hours / Past week) + **Location** (omit for worldwide, or set per bank/core.md §1).
  - Read the results list via snapshot (job titles, companies, locations, "Easy Apply" vs "Apply" buttons).
- If the tab is not on LinkedIn (e.g. feed), click the **Jobs** icon in the nav bar (not a URL navigate).
- Keyword sets (rotate, one per run — **all DevOps/cloud-scoped per the candidate; EXPANDED 2026-09-07**): "Senior DevOps Engineer", "DevOps Lead", "DevOps Manager", "DevOps Team Lead", "Cloud Engineer", "Senior Cloud Engineer", "Cloud Manager", "Cloud Infrastructure Engineer", "Infrastructure Manager", "Linux Team Lead", "Senior Platform Engineer", "Platform Manager", "SRE Manager", "Lead Site Reliability Engineer", "Staff DevOps", "Head of DevOps", "AWS Cloud Engineer", "Engineering Manager DevOps". Drop any generic keyword that surfaces mostly non-DevOps/cloud results in favor of scoped ones.  
- Per run: 1–2 keyword searches, look at **newest** postings (last ~2 days), skip anything already in the run log (run-log.md §6) or applied previously.
- **Location/filter strategy (the candidate 2026-09-06): free country choice** — run searches across any country/region; rotate through different job markets each run (e.g. UAE/GCC, Singapore, Netherlands, UK, Germany, Australia, Canada, US, India, remote-global). On-site roles are welcome anywhere; answer visa questions truthfully (needs sponsorship) and SUBMIT — do NOT skip on unclear sponsorship (the candidate: "visa required… use your brain"). Only skip when a posting explicitly requires existing right-to-work/citizenship ("EU passport required", "must have UK settled status") or states no sponsorship is offered. Remote-global roles also OK. Always set the Easy Apply filter; set location to the country searched.
- **Salary (the candidate 2026-09-06; floor lowered 2026-09-07):** EXPECTED base stays USD 8,000/mo (~96k/yr); when a form asks in local currency use the conversion table in bank/core.md §2. **APPLY-FLOOR = USD 7,000/mo** — skip postings whose band is below ≈ S$8.9k/mo · C$9.7k/mo (~C$116k/yr) · £5.2k/mo (~£62k/yr) · €6k/mo (~€72k/yr) · AED 25.7k/mo · A$9.7k/mo · RM 28.3k/mo. Never undercut the floor when deciding to apply; never answer expected below 8k.
- **Nationality (the candidate 2026-09-06): <NATIONALITY> + <OTHER_NATIONALITY> dual national — NOT <COUNTRY_OF_RESIDENCE>.** Visa sponsorship required for every role outside Sri Lanka/India, including Malaysia (current pass is employer-tied). Answer "authorized to work in [X]" → Yes only for Sri Lanka/India; elsewhere No + seeking sponsorship, and only proceed when the job signals sponsorship.
- **CV:** bank/core.md §1 + linkedin-automation/cv/CV_latest.pdf is the canonical CV for tailoring and uploads.

## 4. Runtime flow (in order)

1. Read `bank/core.md` + this ruleset. (Both live in `<WORKSPACE>/linkedin-automation/`.)
2. **Browser attach**: profile `brave` (direct CDP, port 9222) FIRST. `action="tabs"` → find the LinkedIn tab (feed/jobs/profile URL). If none → report "no LinkedIn tab open" + quit. If `brave` tabs fails entirely, try profile `chrome` (extension relay) once; if that also fails or returns "target identities unavailable" → report "needs manual re-attach" + quit (guardrail 11).
3. **Login check**: snapshot the LinkedIn tab; if it shows authwall/login/guest → report "needs login" + quit (guardrail 8).
4. Open the candidate's profile first (click her avatar/"Me" → View profile, or click the profile link in the top bar if present) to confirm the session is the right account. This is also the "open my LinkedIn profile" step the candidate asked for. Do NOT URL-navigate.
5. Run search via in-page Jobs UI (see §3). For each candidate job: click it in the list, read title/location/seniority; if pass, hit **Easy Apply** (in-page button). Work the form: map each question to bank/core.md §2 by topic; unknown → best-guess from profile facts (never salary/visa/notice — skip those jobs per guardrail 2).
   - **Yes/No questions**: answer only from the bank. If a yes/no maps to nothing → treat as unknown → skip.
   - **Dropdowns/text**: choose the closest bank answer; free text questions with no bank answer and no safe profile guess → skip + log.
7. **Submit** when all required questions are answered per bank/guess. (the candidate approved full auto-submit 2026-09-04.)
8. After submit: note the "Application submitted" confirmation (do NOT close the LinkedIn tab — it's the candidate's tab; use the in-page back/close of the apply modal). Log to run-log.md §6: `date | job @ company, country | applied | submitted-OK`.
9. **Rate-limit/429 handling**: if hit, stop applying, report partial results, quit cleanly.
10. Repeat for next candidate until the day's budget (30, per §2.4) or list exhausted.
11. **Report** (to the candidate's WhatsApp + Telegram, under 180 words): how many found/applied/skipped, why skips, any unanswered questions logged (and ask her on WhatsApp to provide answers → she replies → agent updates bank/core.md next run), any manual steps needed (login/checkpoint/re-attach). One compact list of applied jobs (title @ company — country).

## 5. Browser discipline (extension-aware)

- Snapshot the tab before each action; use refs from the latest snapshot only.
- After any click that changes the page or opens a modal → snapshot again before the next action.
- **Never URL-navigate** an attached tab (wedges debugger — see §0). Stay click-driven.
- Do NOT close the candidate's LinkedIn tab. Work within it; close only apply-modals/dialogs in-page.
- If a ref goes stale → snapshot same targetId again, find the control, retry once, then report blocker.
- If "Easy Apply" is missing (external "Apply" redirect) → skip + log (only LinkedIn Easy Apply in v1).
- Prefer click/type via refs from the latest snapshot; avoid coordinate clicks.
- On modal/dialog changes → snapshot before next action.
- If "target identities are temporarily unavailable" appears → report "needs manual re-attach (click OpenClaw icon off/on in Brave)" + quit. No retry loop.
- Always use profile `brave` (direct CDP) for this flow; the `chrome` extension-relay profile is fallback-only (§0).

## 6. Idempotency & state

- The run log (run-log.md §6) is the source of truth for "already applied". Always append, never overwrite other rows.
- The "Unanswered questions" log (§5) is append-only — new rows at top.
- A job is "applied" only when the submission confirmation was seen; a job left mid-form is logged as `needs-review` with the exact stop point (so a human/the candidate can finish it) and NOT resubmitted blindly.

## 7. Failure modes

| Symptom | Action |
|---|---|
| Browser attach fails | Report "browser unavailable (is Brave running?)" — no retry loop |
| authwall / not logged in | Report "needs login" — stop |
| Checkpoint / captcha / 2FA | Report "checkpoint — manual review needed" — stop |
| Billing/auth 403 on the run itself | Report exact error — that's a gateway/plan issue, not LinkedIn |
| Form cannot be completed per bank | Skip + log to §5, continue with next job |
| Repeated 429 / rate limit | Stop after 2 hits, report partial |

## 8. Budget (token discipline per run)

- One keyword search set max, 2 searches.
- Cap page reads; jq/slice not applicable (browser text) but read only what the step needs via snapshot query/filters.
- Keep the run lean: this runs twice daily on a cheap model (DeepSeek V4 Flash default). If a step explodes in tokens, stop and report.
