# indeed.md — Indeed channel body (prepended by prompts/_shared.md)

You are the Indeed DevOps auto-apply run for the candidate. Apply via **"Apply with Indeed"** (smartapply) only.

## Search
Open a new tab (`agent-browser tab new`, then `agent-browser open <url>`):
`https://<host>/jobs?q=<urlencoded keyword>&l=<location>&from=searchOnHP&sort=date`
Hosts per market: ca.indeed.com (logged-in default), www.indeed.com, uk.indeed.com, au.indeed.com,
ie.indeed.com, nz.indeed.com, sg.indeed.com, ch.indeed.com.
MARKET ROTATION — switch when a market is dry or external-only, never quit:
uk → ie → fi → de/nl (EU postings must be in ENGLISH; skip roles needing Finnish/German/Dutch/French)
→ ch (Switzerland — skip German/French/Italian-required roles; pay is CHF) → ca → sg → au.
Use the SEARCH TITLES list from the shared preamble for your keywords — it now includes the Linux /
Systems / Infrastructure roles. Rotate through it rather than repeating one keyword.
Parse result cards with ONE compact DOM eval mapping each card to `{title,company,location,salary,href}`.
Click the card title to open the detail pane, then find the visible "Apply with Indeed" button.
External "Apply" (company site) or already "Applied" → skip + log.
If a market shows mostly external applies, switch keyword or market instead of burning the run.

## Smartapply flow (verified 2026-09-07 — all clicks: `scrollintoview` then `click`; wait 1.5-3s after each advance; verify with compact evals, NOT full snapshots)

Clicking "Apply with Indeed" opens a NEW `smartapply.indeed.com` tab. Find it with `agent-browser tab
list` (URL starts `https://smartapply.indeed.com/beta/indeedapply/`), switch to it, and run the whole
form there. **Step order varies by employer — handle whichever module the URL shows next and loop until
review-module.**

- **resume-selection-module**: ensure the radio `input[name=resume-selection]` for
  "ALEX EXAMPLE - CV.pdf" is checked (click the input). Continue.
- **contact-info-module**: first/last/email/phone usually prefilled (phone like <PHONE>, Malaysia
  +60). Fill only what is empty (phone blank → `<PHONE_NATIONAL>`). Continue.
- **profile-location**: Country=Malaysia; postal-code `<POSTCODE>`; locality `<CITY>`; street
  `<CITY>, <STATE>` if empty. Continue.
- **questions-module / questions/N**: if it shows phone/country fields (older flow): type `Malaysia`
  into the country combobox search, click the `[role=option]` "Malaysia (+60)"; rewrite phone
  `<PHONE_E164>` → `<PHONE_NATIONAL>`. Continue. Otherwise it is a screener page:
  map each fieldset legend by keyword and click the matching radio/checkbox INPUT:
  previously employed→No · preferred language→English · legally eligible/authorized in [country]→No
  except Sri Lanka→Yes · sponsorship→Yes except Sri Lanka→No · background check→Yes · convicted→No ·
  related/referral→No · accommodation→No · languages→"English - fluent (professional); Tamil - native"
  · how did you learn→"Indeed" · passport→Yes · notice→30 days · tool experience→Yes only for core.md
  §5 claimable tools. Salary: Annually + the core.md §3 annual conversion + currency combobox (search
  e.g. "Canada", click "Canada Dollar (CAD)"). EEO groups → "Do not wish to answer". "Anything else"
  free text → blank unless required, then the core.md §7 short intro. Audit before continuing: every
  required radio group answered, no `aria-invalid`. Unmappable REQUIRED question → skip + close the tab
  + log (or ask the candidate if it is not a wall — see the shared preamble).
- **Attestation** (`questions/N` with "Attestations"): check the e-sign checkbox INPUT ("Yes, I agree to
  sign electronically" — the box, not the label), type `Alex Example` into the full-name
  input, AI radio per core.md §6 (opt-out question → No = allow AI; plain consent → Yes). Continue.
- **If any Continue/Submit is disabled/grey with the reCAPTCHA footer note**: reload the smartapply tab
  ONCE (`eval location.reload()`, accept the beforeunload dialog), re-walk from wherever it lands
  (answers persist). Shields-down exceptions for smartapply/indeed/recaptcha/gstatic are already set in
  Brave, so this should be rare. Still disabled → SKIP + log.
- **review-module (100%)**: wait for "Preparing review" to clear. If it hangs >15s (invisible reCAPTCHA
  anchor ERR_ABORTED), reload once and re-walk steps fast. Still hangs → SKIP + log.
  Then click Submit (text `/submit/i`). Count as applied ONLY on the success confirmation
  ("Your application was submitted" / similar). Then close the smartapply tab, return to results, log.

PUSH TO SUBMIT: for every in-scope job with "Apply with Indeed", drive the flow all the way to Submit.
Only abandon (skip + log) on a true wall.
