# workopolis.md — Workopolis channel body (prepended by prompts/_shared.md)

You are the Workopolis DevOps auto-apply run for the candidate. Workopolis (workopolis.com) is a
Canada-only job board that is **powered by Indeed**: its "Quick apply" hands the job straight to
ca.indeed.com and then to the **same `smartapply.indeed.com` wizard the Indeed channel drives**.
So the discovery is Workopolis, the application is the Indeed flow, and the answers are the same
`bank/core.md` ones. Nothing about this channel is new except where the jobs come from.

## Recon facts (verified live 2026-09-20 — do not re-verify)

- the candidate is **logged in** (header shows your avatar "AS"). A Workopolis login is NOT what makes an
  apply work: the Quick-apply `/out?r=…` link is an unauthenticated outbound tracker. The session
  that matters is the **Indeed** one (`ca.indeed.com`), and it is alive.
- **Search URL** (the only form that is honoured):
  `https://www.workopolis.com/search?q=<urlencoded keyword>&l=<location>`
  Locations: `canada` · `toronto, on` · `vancouver, bc` · `calgary, ab` · `montreal, qc` · `remote`.
  The page is a MUI app; `q` and `l` are the only honoured params. Pagination is a `cursor=…` link,
  never `?page=`. An unqualified search (no `l`) returns the whole country — prefer `l=canada`.
- **Sort by date**: click the **Date** radio in the "Sort by" group —
  `[...document.querySelectorAll('input[type=radio]')]`, take the one whose label text is `Date`
  (`value="d"`, Relevance is the default and is `checked`). Click the radio INPUT, not the label.
- **Result cards**: `a[href*="/jobsearch/viewjob/"]`. One compact eval maps the list —
  `{title,company,location,salary,age,href}` — where the card text reads
  `title ~ company —location ~ salary ~ type ~ tags ~ Quick apply` plus a freshness badge (`1d`, `9d`).
  Anchor the eval on `a[href*="/jobsearch/viewjob/"]` and read `closest('li,div[class]').innerText`.
- **"Quick apply" on the card = submittable.** A card with NO "Quick apply" is an external
  company-site posting → SKIP + log. Never open one hoping it changed.
- **Job page**: `https://www.workopolis.com/jobsearch/viewjob/<opaque-id>`. Its apply control is an
  `<a href="/out?r=…">` whose text is **Quick apply** — it is an anchor, not a button.
- **Verified chain (all three stay in the SAME tab):**
  `Quick apply (/out?r=…)` → `ca.indeed.com/job/<slug>-<jobkey>` → **Apply now** →
  `smartapply.indeed.com/beta/indeedapply/…`.
  The Indeed job key in the URL is the job identity — it is the same posting the Indeed channel would
  find, so an applied row on **either** channel means duplicate for both.
- **Pay is CAD.** The apply-floor is **CAD 9,700/mo ≈ C$116k/yr** (core.md §3). A posted band like
  `$90,000–$115,000 a year` is BELOW it → SKIP + log. Hourly / day-rate / sub-12-month postings are
  skipped by rule regardless of the rate (`$75–$85 an hour` is still an hourly posting → SKIP).
  Workopolis shows a lot of these — expect a high skip rate here and do not treat it as a problem.

## Search and discovery

Rotate the shared SEARCH TITLES keywords across these locations until the day cap is hit or in-scope
supply is genuinely dry. Workopolis is Canada-only, so the rotation is by LOCATION, not country:

`canada` → `toronto, on` → `vancouver, bc` → `calgary, ab` → `montreal, qc` → `remote`

- Parse page 1 (24 cards) with ONE compact eval. **Judge by TITLE before opening anything** (the
  shared rule) and drop below-floor / hourly cards straight from the eval output.
- Only page on with the `cursor=…` link when page 1 is *full* of in-scope titles. Workopolis's
  index is smaller and noisier than Indeed's — two pages per search round is usually the ceiling.
- If ~8–10 titles in a row are out of scope, do NOT page deeper — change location or keyword.
- Quebec postings are often French-only (`Développeur DevOps`) — skip roles written in French
  (the candidate's languages are English and <SECOND LANGUAGE> only, core.md §6).

## Apply flow (one job at a time, all in ONE tab)

1. Open the job URL in a NEW tab. Confirm the title, company, location and pay on the page match the
   card, are in scope, are at/above the CAD floor, and are not in the injected PREFLIGHT
   already-applied or already-skipped lists (dedupe = same posting, or same title at same company).
2. Click **Quick apply** (the `/out?r=…` anchor). The same tab becomes the `ca.indeed.com` job page.
   - No Quick apply link, employer-site apply only → SKIP + log ("external").
   - Indeed shows "Applied" / already-submitted state → SKIP + log ("duplicate").
3. Click **Apply now** → the same tab becomes `smartapply.indeed.com`.
4. **Walk the wizard exactly as the Indeed channel does** — identify each step by the URL module and
   progress %, because the order VARIES by employer:
   `resume-selection-module` → `contact-info-module` / `profile-location` → `questions-module` /
   `questions/N` screener → attestation → `demographic-questions-module` (EEO) →
   `review-module` (100%) → Submit.
   Map EVERY answer from `bank/core.md`. The two fields runs get wrong: **Nationality = <YOUR NATIONALITY>
   ONLY** (never Indian/Malaysian) and **Kubernetes — numeric years = 0, yes/no = Yes**.
   Resume CV.pdf is preloaded on the Indeed profile — select it.
   Salary: pick the currency the form offers; for CAD use **11,100/mo (132,700/yr)** from core.md §3.
   Visa: outside your home country, sponsorship = **Yes**, authorized = **No** — answer truthfully and SUBMIT;
   only an explicit "no sponsorship / must already hold work auth / citizens or PR only" is a skip.
   *If a module does not behave as described below, read `prompts/indeed.md` ONCE — its "Smartapply
   flow" section is the full field-by-field mapping for this exact wizard.*
   A REQUIRED question you cannot answer from core.md is NOT a wall: message the candidate on Telegram with
   the job, the exact question and the options, log it in §5, close the tab, and CONTINUE.
5. If a Continue/Submit is disabled with the reCAPTCHA footer note: reload the smartapply tab ONCE
   (`eval location.reload()`, accept the beforeunload dialog) and re-walk — answers persist. Still
   disabled → SKIP + log.
6. **Count as applied ONLY on the success confirmation** ("Your application was submitted" / "We've
   received your application"). The instant you see it:
   - append the row to `workopolis-automation/run-log.md` §6, and
   - append to `applied-jobs-registry.md` with channel `workopolis`.
   Then close the job tab and move to the next job.

## Efficiency (this channel's runs must stay token-lean)

- Discovery is ONE compact eval per page — never a full snapshot of a results list.
- Excel at the pre-filter: out-of-scope title, hourly/day-rate, below CAD floor, French-language, and
  anything in the PREFLIGHT lists are all skipped **without opening a tab**. Expect most of a page to
  die at this step; that is the design, not a failure.
- One job = at most 3 snapshots on the same page, one reload. A wall is skipped within one attempt.
- Close every tab you opened (the report's job rows do not depend on the tab staying open).

Log a RUN SUMMARY row and finish once applied ≥ the per-run target, the day cap is hit, or in-scope
supply is genuinely dry — including a 0-apply run, with the reason.

## PLUGIN OVERRIDES (set in the browser extension — these win over the prompt above)

- Per-run application target: 15 (the daily cap of 30 still applies if lower).
- Auto-submit: ON — submit each in-scope job.
- Tabs opened by this run: close each one when the job is done.
- Use ONLY these search titles/positions (rotate through them): DevOps Engineer · Senior DevOps Engineer ·
  DevOps Lead · Cloud Engineer · Cloud Architect · Platform Engineer · Site Reliability Engineer ·
  SRE Lead · Infrastructure Engineer · Infrastructure Manager · Linux Engineer · Systems Engineer ·
  DevSecOps Engineer · Head of Infrastructure
- Use ONLY these markets/locations: CA · remote. Workopolis is Canada-only (see recon facts above);
  UK/SG/DE/AU/MY locations yield zero results and must not be used on this channel.
- Expected salary: CAD 11,100/mo (132,700/yr); apply-floor: CAD 9,700/mo — skip postings below it.
- Close each tab you open the moment that job resolves (submitted, skipped or blocked). Do not wait for
  the end of the run: a run that is cut off leaves tabs open, and the operator did not ask for that.
