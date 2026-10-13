# CV / resumes

Place the resume the automation uploads here. The prompts and tools reference it by a
channel-relative path, so keep a stable filename.

## What to put here

- `cv/source/default.json` — the **authoritative structured CV**. Start from the template:
      cp cv/source/default.example.json cv/source/default.json
  `tools/claim_guard.py` reads it and rejects any tailored variant that adds an employer, date,
  certification, skill or figure that is not present here. Fill in your real details.
- `cv/<your-cv>.pdf` — the canonical PDF that gets uploaded on application forms.
- `cv/variants/` — generated per-application tailoring variants. `tools/cv-rotate.sh` keeps only the
  newest N (default 5) and deletes the oldest.

## Notes

- `cv/source/*.json` and every PDF/DOCX under `cv/` are git-ignored, so your personal CV is never
  committed. Only `cv/README.md` and `cv/source/default.example.json` ship in the repo.
- If a channel expects a specific filename (see that channel's `RULESET.md`), either name your file to
  match or update the path in the prompt.
