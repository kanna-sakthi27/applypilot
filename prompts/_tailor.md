# _tailor.md — tailor a CV variant to one job posting.

You are producing a **tailored CV variant** for one specific posting. You are not inventing a
career. A deterministic guard audits your output, and if it finds a single claim that is not already
in the source CV, the whole variant is **discarded**.

## The rule that matters more than any other

You may only **reorder, re-emphasise and reword existing content**. You may **never**:

- add an employer, job title, or date that is not in the source
- add a certification that is not in the source, or change a grade
  (an "Associate" cert must never become "Professional")
- add a skill that is not in the source skills list
- change any number — no "60%" becoming "70%", no "5 engineers" becoming "20"
- claim a tool on the `neverClaim` list

Rewording is welcome: you can say *"cut AWS spend by 60% through Auto Scaling"* for
*"achieved 60% cost reduction via Auto Scaling optimization"*. You can lead with the bullets that
match this posting and drop ones that do not. You can reorder skills to put the posting's
priorities first.

If the posting wants something the candidate does not have, **leave it out silently**. Do not
apologise for it in the CV and do not claim it.

## Inputs

- **Source CV (authoritative):** `$JOB_APPLY_CV_SOURCE`
- **Job description:** `$JOB_APPLY_JD`
- **Posting title / company:** `$JOB_APPLY_JOB_TITLE` at `$JOB_APPLY_JOB_COMPANY`

Read both files once. Do not read anything else.

## Output — exactly this, and nothing else

Write **one JSON object** to `$JOB_APPLY_VARIANT_OUT`, using the Write tool. No prose around it, no
markdown fence, no commentary in the file.

```json
{
  "summary": "2-3 sentences leading with the experience this posting cares about, reworded from the source summary.",
  "skills": ["Terraform", "AWS", "..."],
  "certifications": ["..."],
  "roles": [
    { "company": "...", "title": "...", "location": "...", "start": "...", "end": "...",
      "bullets": ["reordered and reworded bullets, most relevant first"] }
  ],
  "education": [ { "institution": "...", "qualification": "...", "year": "..." } ]
}
```

Rules for the JSON:

- Keep every `company`, `title`, `start`, `end` **exactly** as the source has them. The guard
  compares them.
- `skills` must be a subset of the source skills, reordered so the posting's priorities come first.
- `certifications` must match the source certifications. Keep the grade word.
- `roles` must be the same set of roles (you may reorder them, and reorder/drop bullets within one,
  but do not drop a whole role).
- Keep the numbers that are already in the bullets. Do not introduce new ones.
- `summary` must be built from facts in the source summary and bullets only.

When you are done, write the file and stop. Do not print the JSON to the terminal, do not run any
other command, and do not create any other file.
