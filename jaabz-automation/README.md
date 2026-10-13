# Jaabz Auto-Apply Automation (the candidate / Alex Example)

Jaabz (jaabz.com) — visa-sponsorship/relocation/remote tech job board — as a **lead source + tracker**
in the candidate's job-application system. Built 2026-09-07 as a twin of the LinkedIn / Indeed / Glassdoor /
foreign-direct automations, from live reconnaissance.

## What Jaabz is (verified live 2026-09-07)

- **Job board of visa-sponsorship-friendly tech jobs only** (5,000+ jobs / 2,200+ companies / 50+
  countries). Every listing is inherently sponsor-open — a great fit for the candidate (SL/IN dual national
  needing sponsorship).
- Jaabz does **NOT host applications**. The "Apply Now" button on a job page is an **outbound cloaked
  link** to the real posting — most often the **same role on LinkedIn** (`*.linkedin.com/jobs/view/...`),
  sometimes the employer's own ATS/careers page. So:
  - **Jaabz = discovery + tracking.** The actual application reuses our existing LinkedIn Easy Apply /
    company-ATS / Indeed flows on the destination.
- Jaabz has its own lightweight **account tracker**: buttons **"Save"** (bookmark) and **"Mark
  Applied"** per job → `POST /jobs/{id}/applied` (Laravel, CSRF). the candidate's Jaabz account **is logged in**
  in Brave ("Alagartnam S…"). We use Mark Applied as an extra dedupe + courtesy tracker after a real
  submit.
- Premium jobs need an account (the candidate has one) and sometimes email verification to see full details;
  free jobs show details without login.

## The apply routing rule (core)

For each in-scope Jaabz job, click Apply Now → inspect the destination:

| Destination | Action | Follow mechanics |
|---|---|---|
| LinkedIn job page (`linkedin.com/jobs/view/...`) | If **Easy Apply** is offered → apply on LinkedIn (existing LinkedIn flow + answers bank). Else "Apply on company site" → foreign-direct mechanics | `linkedin-automation/RULESET.md` (skill `linkedin-job-apply-composio`) / `foreign-jobs-automation/ATS_PLAYBOOK.md` |
| Employer ATS (Greenhouse/Lever/Workday/…) | Apply per ATS family | `foreign-jobs-automation/ATS_PLAYBOOK.md` |
| Email application ("send CV to …") | Skip + log (v1) | — |
| Wall (captcha / needs account w/o Google SSO / explicit right-to-work-only) | Skip + log | playbook §Walls |

## Files

| File | Purpose |
|---|---|
| `RULESET.md` | Operating rules: mission, guardrails, search strategy, flow, routing, failure modes |
| `bank/core.md` | Jaabz answer bank (thin — reuses canonical bank) + **Jaabz run log (§6, own 30/day budget)** + unanswered-questions log (§5) |
| `../bank/core.md` | Workspace-root answer bank (compact profile/contact; **do not invent facts**) |
| `../bank/core.md` | **Canonical answer bank** (full §1–§6; salary conversions, CTC, templates) — single source of truth |
| `../applied-jobs-registry.md` | **COMMON cross-channel applied-jobs memory** (dedupe across linkedin/indeed/glassdoor/foreign/jaabz) |
| `../linkedin-automation/cv/CV_latest.pdf` | Canonical CV |

## Schedule (cron on gateway, Asia/Kuala_Lumpur)

- Pending the candidate confirmation after the E2E test. Intended: 1–2 runs/day (e.g. 11:30 + optionally
  17:30 MYT) so it never collides with LinkedIn 08:00 / Indeed 10:30,12:30,16:30,20:30 / foreign
  15:30,18:00,22:00 on the shared Brave browser.
- Model: cheap (DeepSeek V4 Flash on commandcode — same as LinkedIn). Telegram report to the candidate
  (announce delivery to `<TELEGRAM_CONV_ID>`, Telegram user <TELEGRAM_CHAT_ID>).

## To run manually

`openclaw cron run <jobId> --force` (or the automations tool `run` with `runMode: "force"`).
