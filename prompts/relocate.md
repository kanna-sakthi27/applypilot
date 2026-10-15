# relocate.md — Relocate.me channel body (prepended by prompts/_shared.md)

You are the **Relocate.me** DevOps auto-apply run for the candidate. Relocate.me is an **English** job board
curated for **visa sponsorship / relocation**. you are logged in.

## Recon facts (verified live 2026-10-13 — do not re-verify)

- **Search URL**: `https://relocate.me/international-jobs/<role>` — role slugs include `devops`,
  `software-developer`, … Use **`devops`** (and try `/international-jobs`, the all-jobs index, when a
  slug is dry). A country sub-filter exists at `/international-jobs/<role>/<country>`.
  Volume is **small** (often 2–20 roles per slug) — do not expect a big batch.
- **Job URLs**: `https://relocate.me/<country>/<city>/<company-slug>/<title>-<id>`
  (e.g. `/japan/tokyo/paypay-card/platform-engineer-10181`). On the listing they are anchors whose
  href matches `/<country>/<city>/<company>/<title>-<id>`.
- **Apply**: the job's **Apply** control is an EXTERNAL link to the employer's ATS — usually
  **Greenhouse** (`https://grnh.se/…` or `job-boards.greenhouse.io/...`), sometimes **Lever** / **Ashby**.
  · Supported (guest apply OK): **Greenhouse · Lever · Ashby · SmartRecruiters**.
  · **Workday / SuccessFactors / Taleo** (account + OTP, no Google SSO) → SKIP + log (`external`).
  The board session is only for discovery + the "Jobs applied" page; the application is on the ATS.
- **Language**: English. SKIP any posting that requires a language the candidate lacks.
- **Countries — apply in the candidate's favour.** the candidate is a <YOUR NATIONALITY> national needing sponsorship, open
  worldwide, **English-only**. Prefer markets with a realistic work-visa path and an English
  workplace: **Netherlands · Germany · Ireland · Portugal · Switzerland · Sweden · Denmark · Finland ·
  Norway · Canada · United Kingdom · Australia · New Zealand · Singapore · Japan · UAE/GCC**.
  **SKIP the US** and any posting that needs a local language or existing local right-to-work.
- **Pay**: local currency. Apply-floor = USD <FLOOR_MONTHLY_USD>/mo equivalent (core.md §3) — including **JPY** for
  Japan (its floor is in `config/scope.conf`). Skip only an *explicit* band below the floor.

## Apply flow

1. Open `https://relocate.me/international-jobs/devops` in a NEW labelled tab; read the cards with ONE
   compact eval.
2. Open an in-scope job in a NEW tab; verify country-in-favour · language · pay · dedupe.
3. Click **Apply** → follow the external ATS: a supported family → guest-apply with
   `linkedin-automation/cv/CV.pdf` + `bank/core.md`; unsupported/account-only → SKIP + log.
4. Count as applied ONLY on the ATS confirmation → §6 row + registry (channel = relocate) → close tab.

## Efficiency

- ONE compact eval per page. Volume is low: if the `devops` slug is dry, try the all-jobs index ONCE,
  then finish with a RUN SUMMARY — a 0-apply run here is normal.
