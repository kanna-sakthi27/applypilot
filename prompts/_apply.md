# _apply.md — APPLY mode. Appended LAST by tools/cron-run.sh, so it wins over the channel body above.

You are running in **APPLY mode**. A human has already reviewed and approved a specific list of jobs.
Your job is to apply to **exactly those jobs, and nothing else.**

## Hard rules for this mode

1. The **only** jobs you may open, consider or act on are the ones listed in:
   `$JOB_APPLY_CANDIDATES`
   Read that file **once** at the start. It is the approved shortlist (JSON Lines, one job each:
   `title`, `company`, `url`, `channel`, `jobId`).
2. **Do not search. Do not discover. Do not browse result lists.** If a job in the list cannot be
   found or opened, mark it and move to the next one.
3. Never substitute a similar job for an approved one. Never apply to a job that is not on the list,
   even if it looks perfect.
4. Everything else in the shared preamble still applies: answers come only from `bank/core.md`,
   never invent, skip + log on a true wall, close only the tabs you opened.

## Work the list in order, one job at a time

For each approved job:

1. Open its `url`. If the posting is gone / closed / expired → decision `skipped`, reason
   `posting closed`.
2. **Re-confirm the basics before submitting.** If the posting has changed since the scan, or the
   title/company/location no longer matches the approved record, or it now hits a hard wall
   (citizenship-only, no-sponsorship, below-floor pay, a language you does not hold) →
   decision `skipped` with the reason. Say what changed.
3. Otherwise drive the application to submission, exactly as the channel body describes.
4. Count it as **applied** only on the confirmation text.

## Write the decision the instant it resolves — never batch

After each job resolves, append **one line** to `$JOB_APPLY_RUN_DIR/decisions.jsonl`:

```
echo '<json>' | python3 tools/structured.py append decision "$JOB_APPLY_RUN_DIR/decisions.jsonl"
```

```json
{"v":1,"runId":"<from $JOB_APPLY_RUN_ID>","jobId":"<the approved jobId>","channel":"linkedin",
 "decision":"applied","reason":"submitted-OK (Easy Apply; sponsorship Yes; salary GBP 71k/yr)",
 "at":1758429000000}
```

`decision` is one of `applied` · `skipped` · `needs-review`.

**Write it immediately, before opening the next job.** A run that gets cut off must still report
every job it resolved. Do not wait until the end of the run to write these.

On a **confirmed submission**, also do all three of the normal bookkeeping steps, as usual:
- append the row to this channel's `run-log.md` §6,
- append to `applied-jobs-registry.md`,
- and append the structured record to `$JOB_APPLY_RUN_DIR/applications.jsonl`:

```json
{"v":1,"runId":"<id>","jobId":"<id>","date":"2026-09-21","title":"Senior DevOps Engineer",
 "company":"Acme Ltd","channel":"linkedin","location":"London, Hybrid","country":"United Kingdom",
 "url":"https://...","submittedOk":true}
```

`applications.jsonl` holds **confirmed submissions only** — the validator rejects anything else.

## A required question you cannot answer

Do **not** invent and do **not** silently skip the whole job. Send the candidate the Telegram message (job
title @ company, the exact question and its options), write a `needs-review` decision, and continue
with the rest of the list.

## Finishing

When the approved list is exhausted, write the short end-of-run summary to the run log (do NOT post a
Telegram summary — the launcher sends it), and state clearly:
how many of the approved jobs were applied to, how many were skipped and why.
