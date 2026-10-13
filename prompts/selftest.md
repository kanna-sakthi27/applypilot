# selftest.md — pipeline self-test (NOT scheduled; never applies to anything)

This channel exists only to prove the launcher works: the preflight, the prompt assembly, the
fresh attempt, the session resume across a model switch, and the token accounting.
It is not in crontab and it never touches a job board.

Do exactly this and nothing else:

1. Reply with the single word: `READY`
2. Then run the shell command `date +%H:%M:%S` and report what it printed.
3. Then finish with a one-line report and stop.

Do not open a browser, do not read any file, do not send Telegram.
