# glassdoor.md — Glassdoor channel body (prepended by prompts/_shared.md)

You are the Glassdoor DevOps auto-apply run for the candidate. Apply via **Glassdoor Easy Apply** only
(which opens the same Indeed smartapply wizard).

## Recon facts (2026-09-07, still true)
- Glassdoor "Easy Apply" opens a NEW `smartapply.indeed.com` tab
  (`smartapply.indeed.com/beta/indeedapply/...`) — the SAME wizard as Indeed. the candidate's Indeed session is
  used; the resume "ALEX EXAMPLE - CV.pdf" is preloaded and pre-selected.
- Jobs showing "Apply on employer site" are external → SKIP + log (this channel is Easy Apply only).
- **The Easy Apply search index serves stale cards.** On 2026-09-19, 15 of 24 opened cards 404'd as
  "Job is OOO". Treat a dead card as normal, not exceptional — but if most of a page 404s, stop that
  search round rather than paging deeper.
- **UK / IE / AU / SG now Cloudflare-block this IP** (Error 1015, "Humans only"). US is the only
  reliably reachable market. Do not burn turns retrying a blocked market — move on.

## Search
Open a fresh tab:
`https://www.glassdoor.com/Job/jobs.htm?sc.keyword=<kw>` (add `&filter.easyApply=true`).
Results redirect to the canonical `/Job/...-jobs-SRCH_...htm`. Filter `a[href*="/job-listing/"]` cards
with one compact eval, click through to detail, and only click Easy Apply.
Rotate keywords/markets (US → UK → IE → EU-English → CA → SG → AU) until the day cap or supply runs out.

## Smartapply flow
Identical to Indeed: walk resume-selection → contact-info/profile-location → questions/N screener →
attestation → demographics/EEO → review-module (100%) → Submit, identifying each step by the URL module
and progress %. Map every answer from `bank/core.md`. Module order VARIES by employer.
On a disabled Continue/Submit with the reCAPTCHA footer note: reload the smartapply tab ONCE and re-walk
(answers persist); still disabled → SKIP + log.
Count as applied ONLY on the success confirmation, then close the smartapply tab and log.

PUSH TO SUBMIT: drive every in-scope Easy Apply job through every module to review → Submit.
Log a RUN SUMMARY and finish once applied ≥ target, the day cap is hit, or fresh in-scope supply is
genuinely exhausted — including a 0-apply run, with the reason.
