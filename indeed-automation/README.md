# Indeed Auto-Apply Automation (the candidate / Alex Example)

Twice-daily automated job applications on **Indeed** for the candidate, mirroring the LinkedIn auto-apply
automation (`<WORKSPACE>/linkedin-automation/`). Drive the candidate's real Brave (direct CDP),
same answers bank, same policies — but for the Indeed "Apply with Indeed" (smartapply) flow.

## Files

- `RULESET.md` — operating rules for each scheduled run (read first, follow exactly).
- `bank/core.md` — answer bank (topic → canonical answer, salary conversion table, run log).
- `cv/CV.pdf` — canonical CV (copy of linkedin-automation CV_latest.pdf).
- This README.

## Cron

- Job name: `indeed-devops-auto-apply` (full UUID in `openclaw cron list --all --json`).
- Schedule: 08:00 & 20:00 Asia/Kuala_Lumpur (same cadence as LinkedIn). Isolated agentTurn,
  model commandcode/deepseek/deepseek-v4-flash, delivery WhatsApp announce (<PHONE_E164>) bestEffort.
- Each run: read RULESET.md + bank/core.md, drive Brave profile `brave`, search Indeed, apply via
  smartapply, log to run-log.md §6, report.

## Key learned facts (2026-09-07 reconnaissance)

- Apply flow opens in a **new smartapply.indeed.com tab** (not an iframe).
- Steps: resume-selection (38%) → questions/1 contact phone (50%) → questions/N screener + attestation
  → review-module (100%) → submit.
- Resume already uploaded ("ALEX EXAMPLE - CV.pdf") and pre-selectable; phone number
  prefilled as `<PHONE_E164>` — must set country combobox to Malaysia (+60) and strip the 60 → `<PHONE_NATIONAL>`.
- The screener pages contain fieldset questions (radios), text inputs, checkbox groups, and a currency
  combobox; match by normalized question text.
- Attestation step: e-sign checkbox + full-name text + AI-consent radio.
- Invisible reCAPTCHA (recaptcha.net) sometimes ERR_ABORTs the anchor on first load → review hangs on
  "Preparing review". Reload the tab (accept beforeunload) to retry; usually recovers.
- Always read a job's detail pane for the "Apply with Indeed" button; external "Apply" (company site)
  → skip (v1 = Apply-with-Indeed only).
