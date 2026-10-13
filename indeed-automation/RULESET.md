## candidate OVERRIDES 2026-09-07 (apply to every run)
1. HIT 30/DAY PER CHANNEL: daily target is 30 submitted applications per channel. Do NOT stop early while in-scope supply remains. Per-run attempt cap 15 (LinkedIn: 30). Keep rotating keywords/markets (US/UK/IE/EU-English/CA/SG/AU/remote) until 30/day is reached or the fresh pool is genuinely exhausted; then log a RUN SUMMARY with counts.
2. UNANSWERED QUESTION -> ASK, DON'T SKIP: if a required screening question has no answer in the bank, do NOT abandon/skip it silently. Send the candidate a Telegram message via conversations_send to <TELEGRAM_CONV_ID> (user <TELEGRAM_CHAT_ID>): job title @ company, the EXACT question text and options, note the application is paused on her answer, log it in the run-log section 5, then CONTINUE with other jobs. If she answers before the run ends, come back and complete it.

# Indeed Auto-Apply Automation — Ruleset

Operating rules for the scheduled runs on **Indeed** for the candidate (Alex Example). Each run
reads THIS file + `bank/core.md` first and follows them exactly.
Last updated: 2026-09-07 (rev 1 — built from live reconnaissance of the ca.indeed.com smartapply flow).

> Scope (inherited from the candidate's LinkedIn ruleset, 2026-09-06; EXPANDED 2026-09-07): apply ONLY to DevOps and cloud-related
> jobs, engineer AND technical-manager level. In-scope: DevOps Engineer/Lead/Manager/Team Lead, Cloud Engineer/Architect/Lead/
> Cloud Manager, Infrastructure Manager, Linux Team Lead, SRE Manager, Platform Manager, DevOps Team Lead, Engineering Manager
> (cloud/infra/DevOps), Head of DevOps/Cloud/Infrastructure, SRE/Reliability with a
> clear cloud/DevOps focus, Platform Engineer (cloud/DevOps), Infrastructure Engineer (cloud),
> DevSecOps. NEVER apply to pure software/backend/web development, data engineering/analytics/DS,
> ML/AI, QA/test automation (unless a DevOps/CI-CD role), security (non-DevSecOps), pure networking,
> pure DBA, frontend/mobile, general software engineering. Ambiguous title → judge by description;
> core responsibility must be DevOps/cloud/infrastructure automation else SKIP + log §6.

## 0. Critical driving model (learned the hard way on LinkedIn — applies here)

- **Drive the candidate's real Brave via direct CDP — browser profile `brave`** (port 9222, attach-only).
  Pass `profile:"brave"` on EVERY browser call. Find the `indeed.com` tab via `tabs`, act on that
  tab's targetId.
- **Never `navigate`/`open` a URL on an already-attached tab** (wedges the debugger). Use `open` only
  for a brand-new tab with a search URL. Otherwise stay click-driven + DOM evaluate.
- Click-driven: read state via `act` evaluate returning compact JSON (NOT full snapshots — they churn),
  act on real elements. If a synthetic `el.click()` is ignored, `scrollIntoView({block:'center'})` then
  use a **real CDP click at coordinates** (`act` kind `clickCoords`, element center).
- Before clicking a button, ALWAYS `scrollIntoView` + read its fresh center coords (pages re-render,
  coordinates go stale/offscreen). Never click a button whose center y > window.innerHeight.
- If the browser is not running / tabs fail → report "browser unavailable (is Brave running?)" and quit.
  No retry loops.

## 1. Mission

Find Senior/Lead/**Manager** DevOps / Cloud / Platform / SRE roles — incl. DevOps Manager, Cloud Manager, Infrastructure Manager, Linux Team Lead, SRE/Platform Manager, Eng Manager (cloud/infra) (DevOps and cloud ONLY — §Scope) and apply via
**"Apply with Indeed"** (smartapply) in the candidate's Brave. **Daily budget: 30 applications max/day**
(the candidate 2026-09-07), per-run max 10 (rate-limit safety), across 1–3 runs/day. Report after each run.

## 2. Hard guardrails (never cross)

1. **Never invent facts.** Answers only from `bank/core.md`. Unknown required question (salary, visa,
   notice, start date, criminal/security clearance not mappable) → skip + log §5/§6.
2. **No money/visa guesswork.** Salary/current-comp/notice/start-date: only from bank/core.md §2–§3
   (currency conversions). Sponsorship: answer truthfully (Yes needs sponsorship outside SL/IN; No for
   SL/IN). **Submit anyway** — do NOT self-skip on unclear sponsorship (the candidate: "visa required… use your
   brain"). Only skip when the posting/form explicitly requires existing right-to-work/citizenship
   ("must be eligible to work in Canada", "Canadian citizens/PR only", "no sponsorship offered").
3. **Title filter (EXPANDED by the candidate 2026-09-07).** Senior/Lead/Staff/Principal/**Manager/Team Lead/Head** + DevOps/SRE/Platform/Infrastructure/Reliability/
   Cloud/Linux — INCLUDING DevOps Manager, Cloud Manager, Infrastructure Manager, Linux Team Lead, SRE/Platform Manager, DevOps Team Lead, Eng Manager (cloud/infra). No junior/mid-only titles. No contracts unless clearly senior/manager+ and no hourly-rate floor
   violation (below the USD 7,000/mo apply-floor → skip; floor lowered by the candidate 2026-09-07).
3a. **Scope filter.** DevOps/cloud ONLY (see §Scope). Judge ambiguous titles by description.
4. **Daily cap 30 on Indeed (the candidate 2026-09-07; LinkedIn and foreign-direct keep their own separate 30/day budgets).** Before EACH submission, count applied rows dated today (Asia/Kuala_Lumpur) in indeed-automation/run-log.md §6 (Indeed's own log); STOP once 30. Per run ≤10.
4a. **Hard blockers → SKIP and CONTINUE (the candidate 2026-09-07):** unanswerable required question, ATS/form bug, captcha/recaptcha wall on a JOB → skip that job, log it in run-log.md §6, and keep applying. Never stop a run or park a needs-review draft on one hard blocker. Only stop at run cap (10), day cap (30), or an exhausted fresh list.
5. **Never submit with an unanswered required question.** If a required field/radio/checkbox is
   unanswered and not mappable → skip + log.
6. **Never bulk-apply.** One job at a time; wait for each step to settle (1.5–3 s after clicks).
7. **Anti-spin guardrail.** Max ~2 min / 3 attempts per job. If a form step can't be completed after
   3 fresh attempts → SKIP + log §6 ("could not complete form at step X"), close the smartapply tab,
   move on. Never re-snapshot the same page more than 3× without a state change. Never click the same
   element twice.
8. **Never use the word "the candidate" in answers.** Answer as Alex Example / "I".
9. **Not logged in** → do NOT attempt login. Report "needs login", quit.
10. **Checkpoint/captcha wall** → if a real interactive captcha challenge blocks (not the invisible
    recaptcha note), stop, report, don't fight it.
11. **bank/core.md wins** over this file on conflict.

## 3. Search strategy

- Use a brand-new tab (`browser action=open`, label e.g. `indeed-run`) with a search URL:
  `https://<host>/jobs?q=<URL-encoded keyword>&l=<location>&from=searchOnHP&sort=date`
  (location blank = country-wide; `sort=date` = newest first). Hosts: ca.indeed.com,
  www.indeed.com (US), uk.indeed.com, au.indeed.com, ie.indeed.com, sg.indeed.com, fi.indeed.com,
  de.indeed.com, nl.indeed.com, ch.indeed.com (Switzerland).
  MARKET ROTATION (the candidate 2026-09-07): prefer uk.indeed.com → ie.indeed.com → fi.indeed.com →
  de/nl.indeed.com (EU postings MUST be English — the candidate only speaks English; skip roles needing
  Finnish/German/Dutch/French) → ch.indeed.com (Switzerland — skip German/French/Italian-required
  roles; pay is CHF, floor CHF 5,700/mo) → ca.indeed.com → sg.indeed.com → au.indeed.com. When a
  market is logged-out, dry, or mostly external "Apply on company site", switch market — do not quit
  the run. Do NOT log in to region-split markets.
- Keyword rotation (one per search, DevOps/cloud only; EXPANDED 2026-09-07 incl. manager/lead
  titles): `Senior DevOps Engineer`, `DevOps Lead`, `DevOps Manager`, `DevOps Team Lead`,
  `Cloud Engineer`, `Senior Cloud Engineer`, `Cloud Manager`, `Infrastructure Manager`,
  `Linux Team Lead`, `Platform Engineer`, `Platform Manager`, `Site Reliability Engineer`,
  `SRE Manager`, `AWS DevOps Engineer`, `DevSecOps`. If a market yields mostly external "Apply on
  company site" results, switch keyword or market — do not burn the run on external-only lists.
- PUSH TO SUBMIT (the candidate 2026-09-07): she wants SUCCESSFUL SUBMISSIONS. For every in-scope job with
  "Apply with Indeed", drive smartapply through every module to review → Submit (answers truthfully
  per bank/core.md; eligibility No + seeking sponsorship is fine). Abandon (skip+log) only on a true
  wall: unanswerable required question, captcha, or external-only.
- LEARNED 2026-09-07 (CA market): most senior DevOps roles at big employers (Deloitte, KPMG, Citi,
  Intact, Sun Life) are external apply; Apply-with-Indeed senior roles are fewer. Rotate keywords
  (DevSecOps, Cloud Engineer, SRE) and markets to find them. Review the newest 10–15 results.
- Read the results list: cards carry a job link + title; parse with a DOM evaluate that maps each card
  → {jk, title, company, location, salary}. Take the **newest 10–15**.
- Skip titles out of scope (§2.3/3a); skip postings whose salary band is far below the floor; skip
  explicit right-to-work/no-sponsorship postings; skip "Remote in US only"-type location restrictions
  that exclude the candidate's work-auth reality only when they demand existing right-to-work.
- Click a job card (the title link) to open the detail pane; then find the **"Apply with Indeed"**
  button in the pane. If the button says "Apply" (external / company site) → skip + log (v1 =
  Apply-with-Indeed only). If it says "Applied" → skip (dup).
- The "Apply with Indeed" click opens a **new smartapply.indeed.com tab** — find it via `tabs` and
  switch to its targetId.

## 4. Runtime flow (in order)

1. Read `bank/core.md` + this RULESET (both in `<WORKSPACE>/indeed-automation/`).
2. Browser attach: profile `brave`, `action=tabs`. Find an Indeed tab (any indeed.com/smartapply page).
   If none → `open` a fresh tab to `https://ca.indeed.com/`. Verify logged-in (body shows
   "Welcome, ALAGARATNAM" or a profile/account control; if authwall → report "needs login" + quit).
3. Search (see §3). For each candidate in order:
   a. Click the job card → detail pane loads (vjk in URL).
   b. Read title/company/location/salary + description keywords. Apply scope/title filters; skip+log if out.
   c. Find "Apply with Indeed" (visible button). Not present (external apply / applied) → skip + log.
   d. Click it → **new smartapply tab opens** (`tabs` → targetId whose URL starts
      `https://smartapply.indeed.com/beta/indeedapply/...`).
4. **Smartapply flow** (all on the smartapply tab; each click = real CDP click at fresh coords after
   scrollIntoView; wait 1.5–3 s after advancing). **Steps appear in VARIED ORDER by employer — handle
   whichever module the URL shows next.** Loop: read `location.href` module + page body → dispatch:
   a. **resume-selection-module/resume-selection**: ensure the resume radio
      (`input[name=resume-selection]`) for "ALEX EXAMPLE - CV.pdf" is checked (click its
      input box center if not). Click **Continue**.
   b. **contact-info-module**: first/last name + email usually prefilled (ALEX EXAMPLE /
      candidate@example.com); phone often prefilled with country Malaysia (+60) and number like
      `<PHONE>` (or blank → set `<PHONE_NATIONAL>`; if the country combobox shows "Select an option",
      set Malaysia like the older questions/1 flow). Fill only what is empty. Click **Continue**.
   b2. **profile-location**: Country = Malaysia (profile). Fill postal code `<POSTCODE>`, city/locality
      `<CITY>`, street `<CITY>, <STATE>` (bank/core.md §1) if empty. Click **Continue**.
   c. **questions-module/questions/N** (contact phone page OR screener pages, several possible):
      - If it shows the phone/country fields (older flow): country combobox → Malaysia (+60) via its
        search input; phone prefilled `<PHONE_E164>` → rewrite to `<PHONE_NATIONAL>`; Continue.
      - Else it is a screener page: for EACH `fieldset` map its `legend` text → bank/core.md §2 keyword
        table → click the matching radio/checkbox INPUT. Text fields: fill only if required/mappable
        (languages → "English — fluent (professional); Tamil — native", "how did you learn" →
        "Indeed"). Salary: Annually + amount (annual conversion §3) + currency combobox (search
        country, click option). **Audit before Continue**: every radio group in a required fieldset
        has a checked radio; no `[aria-invalid=true]`/`[class*=error]`. Unmappable required → SKIP job
        (close tab) + log §5/§6. Click **Continue** per page.
   d. **Attestation page** (questions/N containing "Attestations"): check the e-sign checkbox ("Yes,
      I agree to sign electronically" — click the input box itself, NOT the label text), fill the
      full-name text input with `Alex Example`, answer the AI radio per bank/core.md §2
      (opt-out question → "No" = allow AI; plain consent → "Yes"), click Continue.
      **If Continue/Submit is DISABLED/grey** on any step with the reCAPTCHA footer note: invisible
      recaptcha failed to init. FIX: reload the smartapply tab ONCE (evaluate `location.reload()`;
      accept any beforeunload dialog), re-walk from wherever it lands (answers persist) → the button
      should enable (shields-down exceptions now in place). Still disabled after reload → SKIP + log.
   e. **review-module (100%)**: wait for "Preparing review" to finish. If it hangs >15 s (recaptcha
      anchor ERR_ABORTED): reload the tab (`location.reload()` via evaluate; accept the beforeunload
      dialog if one appears), the app returns to resume-selection with answers retained → re-walk steps
      4a–4d (fast, answers persist) → review again. If it still hangs after one reload → SKIP + log.
   f. On review page: verify the summary (resume + contact + answers), click **Submit application**
      (find button text /Submit/i). Then look for the success confirmation ("Your application was
      submitted" / "We've received your application" / redirect to a thank-you page).
   g. Only count as **applied** when the confirmation is seen. Close the smartapply tab
      (`act` evaluate `window.close()` after accepting any beforeunload), return to the results tab.
5. Rate-limit/429/soft-block: if Indeed starts returning "something went wrong" or rate pages, stop
   applying, report partial, quit cleanly.
6. Repeat for next candidate until day cap 30 / run cap 10 / list exhausted.

## 5. Browser discipline (smartapply-specific)

- **Shields fix (2026-09-07):** Brave Shields per-site exceptions for `smartapply.indeed.com`,
  `indeed.com`, `recaptcha.net`, `www.recaptcha.net`, `gstatic.com` were set to **setting 1
  (shields down)** in Brave Preferences + Secure Preferences (backed up to
  /tmp/Preferences.bak-indeed) — invisible reCAPTCHA anchor was ERR_ABORTing, which disabled
  Continue/Submit on the smartapply flow. If submits start failing again with a recaptcha note,
  re-check those exceptions exist (they can be dropped if Brave rewrites Preferences on exit).
- **Flow order VARIES by employer** (verified 2026-09-07): Empire Life order was resume-selection →
  contact → screener → attestation → review; Altitude order was contact-info (10%) → profile-location
  (30%) → resume-selection (40%) → review (100%), no screener. Do NOT assume a fixed step order —
  each step is identified by its URL module (`contact-info-module`, `profile-location`,
  `resume-selection-module`, `questions-module/questions/N`, `review-module`) and % progress; handle
  whichever appears next. Keep clicking Continue until review-module appears.
- **profile-location step** (when present): Country already = Malaysia (profile); fill postal code
  `<POSTCODE>`, city/locality `<CITY>`, street/address `<CITY>, <STATE>` (bank/core.md §1)
  if empty; Continue.
- **contact-info-module step** (when present): first/last name + email + phone are usually prefilled
  from the Indeed profile (phone as `<PHONE>` with +60) — verify, fill only what's empty, Continue.
- The rest of the discipline below applies as before.

- Prefer compact `act evaluate` JSON probes over full snapshots (full-page snapshots churn the page).
- After every navigation/step change → re-probe before next action. Refs/coords go stale.
- Do NOT close the candidate's original Indeed tab; only close the smartapply tabs the automation opened.
- If the smartapply tab is stuck on "loading" >10 s → reload once (accept beforeunload).
- Radio/checkbox real clicks: click the **input element's own center** (labels may span wide and the
  visual box is at the input). Verify `checked` after click; re-click the input if unchanged.
- `beforeunload` dialogs: appear on reload/close of a dirty apply form. Accept via
  `browser action=dialog accept=true` (the dialog id from the `blockedByDialog` state).
- reCAPTCHA: if the review hangs on "Preparing review", reload once (see 4e). If two consecutive jobs
  hang the same way, report the recaptcha/shields issue to the candidate (suggest shields off for
  smartapply.indeed.com) and finish the run with what was applied.

## 6. Idempotency & state

- run-log.md §6 run log is the source of truth. Append rows; never overwrite.
- "applied" only on visible confirmation. Mid-form abandoned jobs → log as `skipped` with the exact stop-point reason (per §2.4a skip-and-continue; do not leave a needs-review draft behind).
- Duplicate detection: before applying to a job, check the results card for an "Applied" state and check
  §6 for the same (title @ company) today.
- Log a RUN SUMMARY row at the end of each run: date, markets searched, applied/skipped counts + why.

## 7. Failure modes

| Symptom | Action |
|---|---|
| Browser attach fails | Report "browser unavailable (is Brave running?)" — no retry loop |
| authwall / not logged in | Report "needs login" — stop |
| Interactive captcha/checkpoint | Report "checkpoint — manual review needed" — stop |
| Review hangs "Preparing review" | Reload once (accept beforeunload), re-walk; if persists skip + log; report if repeated |
| Form cannot be completed per bank | Skip + log §5/§6, continue |
| Repeated 429 / rate limit | Stop after 2 hits, report partial |
| External "Apply" (not Apply with Indeed) | Skip + log (v1 scope) |

## 8. Budget (token discipline)

- 1–2 keyword searches max per run; compact evaluate probes only; jq-style slicing of results.
- Keep the run lean: cheap model (DeepSeek V4 Flash), twice daily. If a step explodes in tokens, stop
  and report.
