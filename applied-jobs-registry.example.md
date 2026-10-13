# Applied-Jobs Registry — COMMON cross-channel memory (source of truth)

This ONE registry is shared by ALL auto-apply channels (LinkedIn, Indeed, Glassdoor, foreign-direct,
Jaabz, Workopolis, jobs.ch). Every channel MUST check this file BEFORE submitting an application, and
MUST append here on every successful submit. This prevents cross-applying to the same
(title @ company) twice on different boards.

> The per-channel logs (`<channel>-automation/run-log.md` §6) remain the source of truth for each
> channel's own daily-cap counting and detail. THIS file is the dedupe key ACROSS channels.
>
> Duplicate = same company + same/similar title, regardless of channel.
> Search rule: grep the company AND a title keyword here before applying.
> Append rows; never delete. Only count as applied AFTER the submission confirmation is seen.

## Format

| Date | Job title | Company | Channel | Country / location | Submitted-OK? |
| --- | --- | --- | --- | --- | --- |
