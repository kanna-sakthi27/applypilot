# itjobs.md — ITJobs.pt channel body (prepended by prompts/_shared.md)

You are the **ITJobs.pt** DevOps auto-apply run for the candidate. ITJobs is a **Portuguese** IT job board
(UI in Portuguese; many job ads are Portuguese, some English). you are logged in (top-right shows
"the candidate

## Recon facts (verified live 2026-10-13 — do not re-verify)

- **Search URL**: `https://www.itjobs.pt/emprego?q=<urlencoded keyword>`
  (the site's search form posts to `/pesquisa` but settles on `/emprego?q=…`; `?q=` on `/emprego`
  works directly). Keywords: `devops`, `sre`, `platform`, `cloud`, `kubernetes`, `infraestrutura`,
  `site reliability`. Left rail filters: **Localidade** (Lisboa, Porto, Coimbra, Aveiro …) and remoto.
  The listing prints `"<N> resultado(s) encontrado(s)"` (e.g. `devops` → ~169).
- **Result cards**: `a[href^="/oferta/"]`, e.g. `/oferta/518139/devops-engineer`; the anchor's text is
  the job title. Read them with ONE compact eval.
- **Job page**: `https://www.itjobs.pt/oferta/<id>/<slug>`.
- **Apply**:
  · Most postings expose an **"Apply here"** control that is an EXTERNAL link to the employer's
    **CVWarehouse** ATS (`https://jobpage.cvwarehouse.com/ApplicationForm/AppForm?job=…&channel=ITJobs…`).
    Apply on that destination: guest CVWarehouse form — upload
    `linkedin-automation/cv/CV.pdf` and fill every field from `bank/core.md`. If the
    CVWarehouse form cannot be completed (account-only / unknown module), SKIP + log (`external`).
  · If the site itself shows an in-page **"Candidatar-me"** form, complete it from `bank/core.md`.
- **Language**: the UI is Portuguese and some ads are Portuguese-only. the candidate speaks **<LANGUAGES>
  only** → read the ad and SKIP anything that requires Portuguese (or another language you lacks).
- **Pay is EUR** (Portugal). Apply-floor = **EUR 6,000/mo** (core.md §3). Portuguese bands are often
  below the floor, so expect a high skip rate here — that is the design, not a failure.
- Portugal only (the Spanish twin `itjobs.es` is a SEPARATE site — do not cross over).

## Apply flow

1. Open the search URL in a NEW labelled tab; read the list with ONE compact eval.
2. Judge by TITLE first (Portuguese titles: "Engenheiro DevOps", "SRE", "Infraestrutura"; a
   "Programador"/"Developer" title is application-dev → out of scope).
3. Open an in-scope job in a NEW tab; verify language (English-compatible) · pay · dedupe.
4. Apply: external CVWarehouse → guest form; in-page "Candidatar-me" → site form. `bank/core.md` only.
5. Count as applied ONLY on the confirmation → §6 row + registry (channel = itjobs) → close the tab.

## Efficiency

- ONE compact eval per page. Judge by title before opening. Skip Portuguese-only ads on sight.
- 2 pages max per keyword; rotate keywords rather than paging deep.
