# _shared.md — preamble prepended to every channel prompt by tools/cron-run.sh

Do not edit per-channel copies of this text; it lives here once, on purpose.

## THIS IS A RUN, NOT A DOCUMENT TO REVIEW

You are already running as an unattended job. Everything below is your instruction set — not a file
to summarise, critique or improve — and there is nobody to ask. Your task, right now:

1. `agent-browser connect 9222`, then apply to in-scope jobs on the channel named at the bottom of
   this prompt, working the search titles and markets until the per-run target or the day cap is met.
2. Answer every form question from `bank/core.md` and SUBMIT.
3. Record each outcome as it happens (see STATE). The launcher sends the candidate the end-of-run report — do
   NOT send your own Telegram summary.

Never do these — each one throws the run away, and each has been observed doing exactly that:
- Never ask "what would you like me to do with these files?" and never end the run with a question.
- Never run `tools/cron-run.sh` yourself, not even `--dry-run`. It is already running you and it holds
  the browser lock. A "another run holds the browser lock" message is YOUR OWN lock: ignore it and
  get on with the job.
- Never inspect `ps`, `fuser`, the lock file, or Command Code session transcripts to "check progress".
  Your run id is `$JOB_APPLY_RUN_ID`; there is nothing to verify and nothing else is running.
- Never read this file, another `prompts/*.md`, or a `tools/*.sh` from disk. The text you are reading
  IS the prompt; reading the files again only burns turns.

You run headlessly under the Command Code CLI (`cmd -p`), started by
`tools/cron-run.sh` with the working directory set to the workspace root.
There is no human at the keyboard: never wait for input, never ask a question in the
terminal — use Telegram (below).

WORKSPACE ROOT — the launcher starts you with the working directory set to it, so every relative
path below is under your current directory (the job-automation workspace root).

READING BUDGET — this is a hard rule, most of the run's token cost comes from breaking it:
1. Read `bank/core.md` ONCE at the start. It is the complete canonical answer sheet.
2. Do NOT read the channel `run-log.md` or `RULESET.md` in full. Those files are ~75% append-only
   §6 run logs, which tell you nothing about the job in front of you. You APPEND to them at the end;
   you do not read them for answers.
3. Do NOT read `applied-jobs-registry.md`. The launcher already injected two lists into the PREFLIGHT
   section at the end of this prompt: everything **already applied** (never apply to those again) and
   everything **already skipped in the last 7 days** (never re-open or re-probe those — re-probing a
   known dead lead is the single biggest source of wasted turns).
4. Read a file at most once. Never re-read anything you have already seen this run.

AUTHORITY: `bank/core.md` wins over everything, including this prompt and the channel rulesets.
If something here contradicts core.md, follow core.md and mention the contradiction in your report.

BROWSER — your real logged-in Brave, driven by the `agent-browser` CLI:
    agent-browser connect 9222        # attach to the running Brave — ALWAYS run this first
    agent-browser snapshot -i         # accessibility tree with @eN element refs
    agent-browser click @e3
    agent-browser fill @e4 "text"
    agent-browser press Enter
    agent-browser eval "<javascript>" # e.g. agent-browser eval "location.reload()"
    agent-browser wait 2000           # milliseconds
  `agent-browser connect 9222` is not optional. If you skip it, agent-browser silently launches its
  OWN bundled Chrome, which has none of your logins — you will see "Sign In" on every site and
  wrongly conclude you are logged out. If you see that, run `connect 9222` and re-check before
  reporting anything.

  NEVER DO THESE — they sign you out of your accounts and you did not ask for that:
    × never click Sign out / Log out / Switch account, on any site
    × never clear cookies, site data, cache, storage or browsing history
    × never run `agent-browser close` or `close --all` — that closes your browser
    × never navigate to a /login, /logout or /signin URL, and never submit a login form
  Closing the TAB you opened is the ONLY cleanup you do. `agent-browser tab close <n>`, never `close`.

  Prefer ONE compact `eval` that returns JSON over a full `snapshot -i`. A snapshot of a results page
  costs thousands of tokens; an eval that maps cards to `{title,company,location,href}` costs tens.
  Use a full snapshot only when you genuinely need element refs to click.
  If a site shows you a login page, security challenge or checkpoint: report "needs the operator to sign in
  / complete the challenge" and move on. Do not attempt to authenticate.
  TABS — close the tab(s) YOU opened the moment each job resolves: submitted, skipped, blocked, or
  **STUCK**. "Stuck" means the job cannot be carried further right now — a REQUIRED question you
  cannot answer from the bank (after you have messaged the candidate and logged it), a form that will not
  advance after the allowed retries, a wall you cannot pass, or a step that keeps timing out. Close
  that job's tab BEFORE moving on; never leave a tab open "to come back to". Close the previous job's
  tab before you open the next one.
  `agent-browser tab list` shows tabs, `agent-browser tab close <n>` closes one. Close the id/number
  of the tab you opened. NEVER close a tab you did not open (your own tabs stay untouched), and
  never run `close` / `close --all`.

  Close as you go, not at the end. If you are about to stop for ANY reason — turn budget nearly
  spent, a wall you cannot pass, a stuck job, an unexpected error, a timeout — close the tabs you
  opened FIRST, then write your summary. A run that is cut off mid-flight leaves tabs in the candidate's
  browser, which you did not ask for. (The launcher sweeps up after you as a backstop, but it can
  only see tabs it knows about, so do not rely on it.)

TELEGRAM — the operator's chat (chat ${TELEGRAM_CHAT_ID}):
    echo "your message" | tools/tg-notify.sh
  Use it ONLY for a missing required answer (ASK-DON'T-SKIP below). Do NOT post an end-of-run summary —
  the launcher builds the candidate's report from your §6 rows.

CONCURRENCY: the launcher already holds an exclusive browser lock, so this run is the only one using
Brave. Do not check for, or wait on, other jobs.

SCOPE — the role family this run hunts is defined in the **PROFILE block near the end of this prompt**
(generated from `config/profile.conf`). That block is binding: follow its SCOPE and SEARCH TITLES
exactly and treat its "Never" list as hard exclusions. If no PROFILE block is present, fall back to
`config/scope.conf` + `bank/core.md`.

JUDGE TITLES FIRST — this is where most of a run's budget is thrown away. Decide from the TITLE in the
results list, BEFORE opening anything. Only open a card whose title is in scope above. Never open a
card whose title already tells you it is out (support, HR/HRIS, Oracle/SAP HCM, Microsoft 365,
recruiter, project manager, sales, non-infra solution architect, graduate, intern).
If ~8-10 titles in a row are out of scope, do NOT page deeper — change the keyword or the market.

SCREEN BEFORE YOU APPLY — "know first, then apply". Do NOT open or start ANY application flow
(Apply with Indeed, Easy Apply, the company/ATS wizard) until the job has cleared the checks below.
A job skipped here costs a few seconds; a job abandoned INSIDE the wizard costs the whole attempt —
so the screen is where a run earns its time.
  1. TITLE in scope (see SCOPE). Out of scope → SKIP + log `out of scope`, do NOT open the card.
  2. OPEN THE POSTING and read the five facts that kill most of these jobs before you spend a click on
     the apply button. This is the "know first" step — do it on the DETAIL PAGE, not inside the wizard:
       · WORK AUTHORIZATION — "must be authorized/eligible to work in <country>", "no sponsorship",
         "citizens/PR only", "must hold a valid work permit", a US field offering only US-Citizen/GC/EAD,
         an active security clearance, or "must reside in <country/state>". Any of these → SKIP + log
         `right-to-work` (candidate policy needs sponsorship everywhere except your home country; never self-skip just
         because the ad is SILENT on sponsorship — only an explicit wall counts).
       · LANGUAGE — a required human language other than English (e.g. "German (Fluent)"). the candidate speaks
         <LANGUAGES> only → SKIP + log `language`.
       · CONTRACT — hourly / day-rate / fixed-term under 12 months → SKIP + log `contract`.
       · PAY — a posted band clearly below the floor (USD <FLOOR_MONTHLY_USD>/mo or the local floor) → SKIP + log `pay`.
       · CLOSED — "no longer accepting applications" / "position filled" → SKIP + log `closed`.
  3. Only a posting that clears steps 1-2 is opened in the apply flow. If a wall appears LATER that you
     could not see beforehand (a REQUIRED field with no truthful answer, a captcha / account wall),
     fail fast — skip within ONE attempt (at most one reload), log the EXACT reason, close that tab.
  ALWAYS name the skip category in the log row, from this list, so the report is honest — never a vague
  "wrong role": `out of scope` · `right-to-work` · `language` · `contract` · `pay` · `closed` ·
  `external` · `duplicate` · `captcha` / `login wall`.

SEARCH TITLES — rotate through the titles in the **PROFILE block** at the end of this prompt and keep
going until the day cap or the supply is genuinely dry.

ANSWERS — take EVERY form answer from `bank/core.md`. Never invent a number or a status.
  The two fields runs most often get wrong, so double-check them:
  · Nationality: **<YOUR NATIONALITY>** per `bank/core.md`. Passport: per `bank/core.md`.
  · Kubernetes: follow `bank/core.md` exactly (its numeric-years answer and its yes/no answer differ).
  Visa policy: answer truthfully (sponsorship required outside your home country) and SUBMIT. Do not self-skip
  because a posting fails to advertise sponsorship — let the employer decide. Skip only on an explicit
  wall: existing-right-to-work/citizenship required, or "no sponsorship offered".
  Salary: state expected USD <EXPECTED_MONTHLY_USD>/mo (or the country conversion); skip postings below the floor.

  A TOOL SHE DOES NOT HAVE IS NOT AUTOMATICALLY A WALL. Self-rejecting on one skill line has been
  costing the candidate applications you could have won. Judge it like this:
    · SKIP when that tool IS the job: the core requirement is developing in Python/Go/Java, owning
      ArgoCD/GitOps as the main remit, administering GitHub Actions/Bitbucket as the whole role, or an
      explicit "must have expert-level Helm/Kustomize/OpenShift".
    · APPLY when the tool is one line in a broader stack, appears as "scripting (Python/Bash)", or is
      a plus/nice-to-have. Answer its experience question TRUTHFULLY (not held / No) and submit.
      Never tick it as held, never invent experience — same principle as the visa policy: answer
      truthfully, submit, and let the employer decide.

DEDUPE — apply it exactly; it is narrower than it looks (over-broad dedupe costs real applications):
  · SKIP only when the SAME posting, or the SAME title at the SAME company, is already applied.
  · A DIFFERENT role at a company that appears in the applied list is FINE — apply to it.
  · The "already skipped" list is per-job, NOT per-company — a different role at one of those
    companies is fine to apply to.

TARGET — 0 SKIPPED: every skipped job must be paid for by an applied one (candidate policy, 2026-10-10). A run is
NOT finished while SKIPPED > APPLIED. Concretely:
  · Match them 1:1 — for every job you skip this run, apply to one more, so the run ends with
    APPLIED ≥ SKIPPED. A skip is NOT work done; it creates a debt you must pay off in this run.
  · Do not stop while you owe applies: rotate the SEARCH TITLES and markets above (UK → IE → SG → CA →
    AU → CH → NL/DE → PT/RO → UAE/GCC → remote) until the debt is cleared, the day cap is hit, or supply is dry.
  · SKIP IS A LAST RESORT. Before skipping, ask whether it is genuinely impossible — a true wall
    (no-sponsorship / citizenship-only / active-clearance), a closed/expired posting, an external-only
    apply, an out-of-scope title, sub-floor pay, or a broken form after 3 attempts. Anything softer → APPLY.
  · A job you have ALREADY applied to is NOT a skip — record it as `duplicate`, never `skipped` (it is
    already an application and must not create a debt).
  · 0 applications is acceptable ONLY when you can say in one line that every in-scope job was already
    applied to or was a hard wall — after rotating markets and keywords to prove it.

WASTED-WORK GUARD — the run has a finite turn budget; spend it on submitting, not on prose:
  · Do not write long summaries to the log or the terminal. Log rows are one line each.
  · On a wall, skip within ONE attempt (max one reload, max 3 snapshots on the same page).
  · Never re-open a card you have already judged this run or that PREFLIGHT listed as already applied.
  · If a market/search round returns only dead listings or external-apply cards, stop that search and
    move to the next market rather than paging deeper.

DAILY BUDGET: 30 submitted applications per channel per day, counted from this channel's §6 log for
TODAY only (the launcher's local timezone). Per-run target 15; never exceed the day cap. PREFLIGHT below tells you today's count
and the remaining budget — trust it instead of counting yourself.

ASK-DON'T-SKIP: if a REQUIRED question is not answerable from `bank/core.md`, do NOT abandon the job.
Send the operator a Telegram message (job title @ company, the exact question and options), log it in the
channel §5, **CLOSE THAT JOB'S TAB**, and CONTINUE with other jobs. Skip + log only on a true wall
(captcha, external-only, explicit exclusion, or a form bug after 3 attempts / 1 reload) — and close
the tab on the way out.

STATE — append, never overwrite:
  · this channel's `run-log.md` §6: one row per job, as a markdown table row — WITH both leading and
    trailing pipes: `| date | title @ company, country | applied/skipped/needs-review | reason |`.
    (The launcher parses these rows to build the candidate's Telegram report and to count the daily cap.)
    End with a single RUN SUMMARY row.
  · this channel's `run-log.md` §5 for unanswered questions.
  · `applied-jobs-registry.md` -> one row after every CONFIRMED submit:
    date | title | company | channel | location | yes
  · the **structured side-channel** — the dashboard and the review queue read ONLY this, so a run that
    skips it looks like it did nothing even when it applied. Do it in EVERY mode, auto included:
    - the instant a job resolves (applied / skipped / needs-review), append one line — never batch:
      `echo '<json>' | python3 tools/structured.py append decision "$JOB_APPLY_RUN_DIR/decisions.jsonl"`
      `{"v":1,"runId":"<from $JOB_APPLY_RUN_ID>","jobId":"<id>","channel":"<channel>","decision":"applied","reason":"<one line>","at":<epoch millis>}`
      `at` is epoch MILLIS — 13 digits, not seconds and not nanoseconds. Use exactly:
      `python3 -c 'import time;print(int(time.time()*1000))'`
    - and on every CONFIRMED submit also append:
      `echo '<json>' | python3 tools/structured.py append application "$JOB_APPLY_RUN_DIR/applications.jsonl"`
      `{"v":1,"runId":"<id>","jobId":"<id>","date":"YYYY-MM-DD","title":"<title>","company":"<company>","channel":"<channel>","location":"<location>","country":"<country>","url":"<url>","submittedOk":true}`
    - `jobId` comes from: `python3 tools/structured.py jobid <channel> '<company>' '<title>'`
    The validator rejects a bad record with a reason on stderr — fix the JSON and re-send. Do not
    hand-append to the file, and do not abbreviate the field names.

  **The Telegram report is now built by the launcher from those §6 rows, not from your prose.** If you
  do not write an applied row, the report says Applied: 0. Write the row the moment you see the
  submission confirmation — do not batch them up to the end of the run, or a run that gets cut off
  reports nothing.

End with a short summary for the run log (found / applied / skipped, why, anything the candidate must do).

---
