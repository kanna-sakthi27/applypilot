# Open questions — answers still missing (fill in the blank line under each)

When a run hits a **required** form question that `bank/core.md` does not cover, it skips that job and
logs it in the channel's `run-log.md` §5. This file is the human side of that log: **one block per
question, each with a blank `Your answer:` line for you to fill in.**

How to use it:

1. Write your answer after `Your answer:` (any wording is fine).
2. Tell the assistant, or fold it into the matching section of `bank/core.md` yourself — that is the
   file the runs actually read.
3. Delete the block once it is in `bank/core.md`.

`tools/bank-reminder.sh` re-sends the open items to Telegram once a day, pointing at this file.

---

## 1. <Company> — <short description of the question>

- **Where:** <channel> · <job title> @ <company>, <location> — <form step>
- **Seen:** <YYYY-MM-DD>
- **Question:** "<exact question text and options>"
- **Why it blocks:** <which section of core.md is missing this answer>
- **Your answer:** *<fill me in>*
