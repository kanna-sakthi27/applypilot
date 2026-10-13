# bank/core.md — CANONICAL ANSWER CORE (the only bank a run needs to read)

> **This is a template.** Copy it to `bank/core.md` and fill in YOUR details:
>     cp bank/core.example.md bank/core.md
> `bank/core.md` is git-ignored, so your real answers are never committed. Every form answer a run
> gives comes from `bank/core.md`; if anything anywhere else disagrees with it, this file wins.
>
> The headings and the shape below are what the prompts and tools expect. Keep the section numbers
> (§1–§9) and the table columns — the runs read them by name. Delete the guidance blockquotes once
> you have filled it in.

---

## 1. Identity

| Field | Answer |
|---|---|
| Legal name | <Full legal name> (preferred: <nickname>) · <pronouns> · DOB <YYYY-MM-DD> |
| Email | <you@example.com> |
| Phone | <+country number> → forms that strip the country code: `<national number>`; full: `<e164>` |
| Address | <city>, <state>, <postcode>, <country> |
| Education | <degree> — <institution> (<years>) · <degree> — <institution> (<years>) |
| LinkedIn | linkedin.com/in/<your-handle> |
| GitHub | github.com/<your-handle> |
| CV to upload | `<channel>-automation/cv/<your-cv>.pdf` |
| Driver's licence | <Yes/No> |
| Personal site | <url or none> |

## 2. Work authorization — read carefully, this is the most-mistaken field

- **Nationality: <your nationality>.** State it truthfully; never tick a nationality you do not hold.
- **Passports held:** <which passports>. "Do you have a valid passport?" → **<Yes/No>**.
- **Current location and immigration status:** <e.g. "in <country> on an employer-tied pass">.
- **Sponsorship required for every country except <countries where you have the right to work>** —
  including your current country of residence if you are there on an employer-tied pass.
- Authorized to work without sponsorship: **<countries only>**.
- Open to relocation: **<worldwide / which regions>**.
- Security clearance ever held: **<Yes/No>** (if a posting demands an *active* clearance, answer
  truthfully and let the employer decide).

| Question shape | Answer |
|---|---|
| "Will you now or in the future require sponsorship?" | **<Yes/No>** |
| "Are you authorized/legally eligible to work in [country]?" | <home country> → Yes · anywhere else → **No, seeking sponsorship** |
| "Do you hold a work visa for [country]?" | <answer> |
| "Do you require sponsorship?" / current immigration status | <answer> |
| "Willing to relocate to [city]?" | **<Yes/No>** |
| US state-of-residence dropdown | If you are not a US resident → **skip the job + log** |

## 3. Compensation

| Item | Value |
|---|---|
| **Expected (always state this)** | **<currency amount>/month (~<currency amount>/yr)**, negotiable |
| **Apply-floor — skip postings below** | **<currency amount>/month** |
| Current | <amount> |
| Equity / bonus | <Yes/No> |
| Contracts | fixed-term ≥ 12 months OK · **skip hourly / day-rate / sub-12-month** |

**Expected converted (state these when the form asks in local currency):**

| Currency | Monthly | Annual |
|---|---|---|
| USD | <amount> | <amount> |
| EUR | <amount> | <amount> |
| GBP | <amount> | <amount> |
| SGD | <amount> | <amount> |
| AUD | <amount> | <amount> |
| CAD | <amount> | <amount> |
| AED | <amount> | <amount> |
| INR | <amount> | <amount> |
| MYR | <amount> | <amount> |

Other currencies → convert the USD figure at the current rate, or state USD + negotiable.

## 4. Experience — numeric screeners use exactly these numbers

Total professional **<n>** · <area> **<n>** · <area> **<n>** · <tool> **<n>** · <tool> **<n>** ·
<tool> **<n>** · <tool> **<n>**.

**Yes/No vs numeric — the rule that is easy to get wrong (example: Kubernetes):**
- *Numeric* "how many years of <tool>?" → **<n>** (be exact and truthful).
- *Yes/No* "do you have <tool> experience?" → **<Yes/No>**.
- Never write a number into a numeric field that you cannot defend.

**Leadership:** "3+ years managing teams?" → **<Yes/No>**. Detail: <team size, responsibilities>.

**Scale:** <e.g. "~N servers, ~<amount>/month cloud spend">.

## 5. Skills — claim / never claim

**Source of truth for qualifications:** `cv/source/default.json` (which mirrors your CV PDF).
If the two ever disagree, the CV wins.

**Claim:** <comma-separated list of skills you can truthfully claim>.

**Never claim:** <comma-separated list of skills you must never tick as held>.

**A tool you do not have is not automatically a wall.**
- **Skip** only when that tool *is* the job — the core requirement is developing in it, owning it as
  the main remit, or an explicit "must have expert-level" line.
- **Apply anyway** when it is one line in a broader stack, appears as "scripting (X/Y)", or is a
  plus/nice-to-have. Answer its experience question truthfully (No / not held) and submit. Never tick
  it as held and never invent experience — same principle as the visa policy: answer truthfully and
  let the employer decide.

**Dedupe (narrower than it looks):** skip only on the *same posting*, or the *same title at the same
company*, already applied. A **different** role at a company already in the applied/skipped lists is
fine — apply to it.

**Other flags:** FinTech experience <Yes/No> · shipped AI/LLM automations <Yes/No> ·
SRE practice ownership <Yes/No> · Certifications: <list all, with years>.

## 6. Preferences & compliance

| Field | Answer |
|---|---|
| Notice period | **<n> days** |
| Earliest start | <date or "one month from today"> |
| Travel | <n>% |
| Shifts / follow-the-sun on-call | <Yes/No> |
| Work style | Remote-first / hybrid / on-site |
| Reason for leaving | "<standard reason>" |
| Languages | English (<level>); <other> (<level>) — **only these** |
| Job-search status (recruiter dropdown) | "Application stage" — never blank |
| Prior employee of [company] | No · Criminal record: No · Referral: No · Accommodation: No |
| Background check | <Yes/No> · Drug screening: <Yes/No> |
| References | <Yes/No — how many> |
| 18 or older | <Yes/No> |
| EEO / demographic / veteran / disability | Decline — "Do not wish to answer" |
| AI-screening consent | <Yes/No> · Opt-out: <No/Yes> · E-sign: <Yes/No> + type full legal name |

**Skip + log (do not ask):** clearance-required roles you cannot pass · residency-gated roles ·
citizenship-only / no-sponsorship / explicit right-to-work walls · below-floor pay ·
hourly/day-rate/sub-12-month · out-of-scope title.

## 7. Free text

**Short intro ("tell us about yourself"):**
> <2–4 sentence professional summary you are happy to reuse verbatim.>

**"Why this role":**
> <one-sentence template, e.g. "I'm excited by this role because it combines … and [Company]'s
> [industry/scale] is where I want to apply that experience next.">

**Cover letter:** skip by default. Attach only when the posting requires one:
> Dear Hiring Team, I'm applying for [Role] at [Company]. … Sincerely, <Full legal name>.

**"Anything else":** blank unless required, then the short intro.

## 8. Scope, budgets, escalation

**In scope:** <the kinds of roles/job families you want>. A title does not have to match literally —
judge by whether the core job is in your target area.

**Out of scope — never apply:** <list of roles to skip>.

**Caps:** <n> submitted applications per channel per day; per-run target <n>; never exceed the cap.
Count only *this channel's* log for this channel's cap.

**Unanswered required question:** never invent. Ask the operator on Telegram
(`tools/tg-notify.sh`) with the job + exact question, log it, and continue with other jobs.
Only skip when it is a true wall.

## 9. Open questions — answers still missing (fill these)

Required form questions not answered anywhere above get skipped. The **live list** — with **where**
each was seen (channel · job @ company · form step · exact field text), plus a blank line to fill in —
lives in:

> **`bank/OPEN-QUESTIONS.md`**

Runs append new gaps to each channel's run log §5; `tools/bank-reminder.sh` re-sends the open items to
Telegram once a day, pointing at that file. Once an answer is added there, fold it into the matching
section above (that is what the runs read) and delete the block.
