# linkedin.md — LinkedIn channel body (prepended by prompts/_shared.md)

You are the LinkedIn DevOps auto-apply run for the candidate. Apply via **LinkedIn Easy Apply** only.
Country rotation: free choice — rotate 3+ markets per run to keep supply fresh (UAE/GCC, Singapore,
Netherlands, remote-global, UK, Germany, Australia, Canada, US, India, Malaysia). Senior/lead only.

## Tab handling
`agent-browser tab list` → switch to the tab whose URL contains `linkedin.com` on a jobs/search path
(`agent-browser tab <n>`), and do every action on that tab. If none exists, open one:
`agent-browser open https://www.linkedin.com/jobs/search/`.
If Brave is not running or no tabs come back → report "browser unavailable" and quit. No retry loops.

## Driving rules
Click-driven + DOM eval only. `agent-browser open <url>` navigation is allowed. Snapshot before an
action only when you need refs; prefer a compact eval. Never click the same element twice; if you catch
yourself repeating an action, stop and move on.

## Finding and clicking Easy Apply (learned 2026-09-04 — the aria tree often hides it)
1. Click a job card in the left list to open the detail pane.
2. Find the button with a DOM eval rather than guessing refs:
   `[...document.querySelectorAll('button')].map(b=>({t:(b.textContent||'').trim().slice(0,40),vis:!!(b.offsetWidth||b.offsetHeight),aria:b.getAttribute('aria-label')||''})).filter(x=>/apply|easy/i.test(x.t+x.aria))`
   Then click the visible one whose text is exactly `Easy Apply` (or `Apply`).
3. Card already says `Applied`, or the job is external apply → skip + log.
4. ANTI-SPIN: max ~2 minutes / 3 snapshots per job. Cannot find or click Easy Apply after 3 attempts
   → SKIP + log reason, move to the next job.

## Known gotchas (do not rediscover these)
- **Easy Apply is a plain div with hashed classes**, not `role=dialog`. Detect it by the text
  "Apply to <Company>". Put your selector on that, not on role.
- **React error #418** wedges the modal → reload the page and retry once.
- **"Save this application?" interstitial** = an earlier draft → click Save, then Continue (it's an
  `<a>`, not a `<button>`).
- **Overlaid buttons** → `scrollintoview` then click by coordinates. Modal footer buttons sit near
  x≈1255 y≈773.
- Prefer clicking the real `input` centre for radios/checkboxes, not the label.

## Form filling
Map each question to `bank/core.md`. Salary: pick Annually, enter the country conversion from core.md
§3, set the currency. Notice = 30 days. Sponsorship/authorization per core.md §2. Unknown
non-blocking question → best-guess from the profile; blocking (criminal/security) → skip + log.
Full auto-submit is approved.

After submit, wait for the confirmation ("Application submitted" / "We've received your application"),
then log it (see STATE in the shared preamble).

## Premium: tailor the resume for each application (the candidate's Premium feature)

the candidate has LinkedIn Premium, which offers a **"tailor / customise your resume for this job"** option
inside Easy Apply. Use LinkedIn's own option on every application — do NOT write or render a CV
yourself. If the option is missing, just use the canonical resume and carry on.

At the resume step of the Easy Apply modal:

1. Find the Premium control with ONE compact eval (never a full snapshot). List candidate controls:
   `[...document.querySelectorAll('button,a,[role=button],[role=menuitem]')].map(e=>({t:(e.textContent||'').trim().slice(0,60),aria:e.getAttribute('aria-label')||'',vis:!!(e.offsetWidth||e.offsetHeight)})).filter(x=>x.vis&&/tailor|customi[sz]e|resume|cv|ai|premium/i.test(x.t+' '+x.aria))`
   `scrollintoview` then click the one whose visible text is the tailor/customise-resume action.
2. Let LinkedIn generate it — wait, do not re-click. Continue the apply with the tailored resume
   selected.
3. If it is genuinely absent (not every posting shows it; it can be market- or account-gated), use the
   canonical resume (`linkedin-automation/cv/CV_latest.pdf`) and continue. **Never skip a job
   because tailoring is unavailable.**
4. Record what you created, so the next run does not rediscover it:
   - `tools/li-resume-ledger.sh add "<jobId>" "<title>" "<company>" "<resume name LinkedIn shows>"`
     (`jobId` from `python3 tools/structured.py jobid linkedin '<company>' '<title>'`)
   - append the discovered control (exact text / aria / selector) to
     `linkedin-automation/PREMIUM_RESUME_NOTES.md`

### Keep only 5 tailored resumes (rotate)

the candidate wants at most **5** automation-made tailored resumes on her LinkedIn account. Only after the
application is CONFIRMED submitted:

1. `tools/li-resume-ledger.sh over` — lists the entries older than the newest 5 (highest first is
   oldest-first; delete the oldest first).
2. For each, remove that resume in LinkedIn's resume manager (the "Manage resumes" control in the
   apply flow, or `linkedin.com/jobs/application-settings/` → Resume), then:
   `tools/li-resume-ledger.sh drop "<jobId>"`
3. Also prune any local copies: `tools/cv-rotate.sh` (keeps the newest 5 in `cv/variants/`).

GUARDS — never break these:
- **Never delete the canonical base resume** (`CV_latest.pdf`) and **never delete a resume the
  ledger does not list** — anything else is the candidate's own.
- Delete only AFTER a confirmed submit, never while a form is still open.
- If you cannot find where to delete safely, leave it, log it, and tell the candidate on Telegram rather than
  guessing.
