# _scan.md — SCAN mode. Appended LAST by tools/cron-run.sh, so it wins over the channel body above.

You are running in **SCAN mode**. This mode **discovers and scores jobs. It never applies to anything.**

## Hard rules for this mode

1. **NEVER submit, never fill an application form, never open an apply flow.** Do not click
   "Easy Apply", "Apply", "Apply with Indeed", "Quick apply" or any equivalent. Do not open the
   `smartapply` wizard. If a page auto-opens an application form, close the tab and move on.
2. You are allowed to: search, read result lists, open job detail pages to read the description and
   pay, and read the posting text. Nothing else.
3. Judge by TITLE first from the results list. Only open a card whose title is plausibly in scope —
   opening an out-of-scope card wastes the run.
4. Keep discovery cheap: ONE compact `eval` per results page mapping cards to
   `{title,company,location,salary,href}`. Never a full snapshot of a results list.

## The only output that matters: `candidates.jsonl`

`$JOB_APPLY_RUN_DIR` holds this run's directory. For **every** job you judge to be in scope, append
exactly one line to `$JOB_APPLY_RUN_DIR/candidates.jsonl` by piping JSON to the validator:

```
echo '<json>' | python3 tools/structured.py append candidate "$JOB_APPLY_RUN_DIR/candidates.jsonl"
```

The validator rejects a malformed record with a non-zero exit and a reason — fix the JSON and
re-send. **Do not hand-append to the file**, and do not batch: write each candidate as you find it,
so a cut-off run still reports what it saw.

Record shape (required fields marked ·):

```json
{"v":1,
 "runId":"<from $JOB_APPLY_RUN_ID>",
 "jobId":"<python3 tools/structured.py jobid <channel> '<company>' '<title>'>",
 "channel":"linkedin",
 "title":"Senior DevOps Engineer",
 "company":"Acme Ltd",
 "location":"London, Hybrid",
 "country":"United Kingdom",
 "url":"https://www.linkedin.com/jobs/view/123456",
 "postedAt":"2026-09-19",
 "salaryRaw":"GBP 70,000 - 80,000 a year",
 "description":"<first ~600 chars of the posting that mention requirements>",
 "language":"en",
 "source":"linkedin-easyapply",
 "score":82,
 "scoreReasons":["IaC/Terraform core","senior/lead level","sponsorship not excluded"],
 "discoveredAt":1758429000000}
```

- `salaryRaw` is the **verbatim** pay text as shown, or `null` if the posting shows none. Do not
  normalise or convert it — a deterministic pass does that afterwards.
- `description` is the posting text you actually read (the requirements/scope part). This is what
  the deterministic wall/language checks read, so include the sentences that state eligibility,
  sponsorship, language and contract type **verbatim**. Do not paraphrase.
- `score` is 0-100 and `scoreReasons` explains it.

## Scoring — grounded, never invented

Score **fit**, using only `bank/core.md` (scope §8, skills §5, compensation §3):

- 80-100: core is exactly her remit (DevOps / SRE / Platform / Cloud / Infra / Linux), senior or
  lead level, no wall, pay at or above the floor.
- 50-79: in scope but weaker — one skill line she does not hold appears as a plus, or the level is
  borderline, or pay is near the floor.
- 0-49: out of scope, or the core requirement is something she genuinely does not have
  (Python/Go/Java development, ArgoCD/GitOps as the main remit, expert Helm/OpenShift,
  the language, the clearance, the citizenship wall).

**Never infer experience that is not in `bank/core.md`.** If a posting wants a tool she does not
have, say so in `scoreReasons` and lower the score — never write that she has it.

Do **not** drop a job because of a missing skill unless that skill *is* the job; per `core.md` a tool
line she lacks is not automatically a wall. Record it and let the score reflect it.

You do **not** need to decide scope=out jobs: don't record them at all. Record only what you judge
in scope, plus borderline cases, and let the deterministic pass and the user's threshold decide.

## Finishing

Stop when you have recorded the run target worth of candidates, the day's supply is genuinely dry,
or the turn budget is nearly spent. Then post the short end-of-run summary as usual
(found / recorded / why anything was excluded). **No applications were submitted in this mode — say
so explicitly in the summary.**
