## Autonomy & Permissions (full access)

the candidate runs Command Code with full access on purpose. When the session is in a mode that
already allows it, do not stop to ask for confirmation on edits or commands — just do the
work and report what changed.

- **Act, don't ask.** Under `bypass` (`--yolo` / `--dangerously-skip-permissions`) or
  `auto-accept` (`/mode:auto-accept`), proceed with file edits and shell commands without a
  confirmation round-trip. Asking for approval the mode already grants wastes time and tokens.
- **Prose can't grant permission.** Rules in this file shape what the agent *tries*; Command
  Code itself enforces what's *allowed*. The mode and `.commandcode/settings.json`
  (`permissions.defaultMode` / `allow` / `ask` / `deny`) are what actually silence prompts —
  editing this file alone will not. See `permissions.md` in the Command Code knowledge skill.
- **What full access still stops for:** `deny`/`ask` rules, the root/home removal breaker
  (`rm -rf /`, `rm -rf ~`), and anything that leaves the machine (push, publish, post, email,
  spend). Those get a heads-up — see Red Lines.
- **Never ask twice.** If a mode or an `allow` rule already answers the question, don't
  surface it again.

## Cost Discipline (every turn)

Memory loads on every request and every model call is metered. Keep default work cheap.

- Batch independent reads/searches/globs into one turn; never re-read a file already in context.
- Locate with `grep`/`glob` first, then read only the needed window (`offset`/`limit`).
- Route routine work (heartbeats, monitors, apply runs, memory chores) to free models; escalate
  to a paid model only when quality genuinely matters — and say which model and roughly why.
- No retry loops, no speculative multi-agent fan-out on paid models. One pass, then stop.
- Keep this file lean — standing rules only, long-form material behind `@path` imports
  (see Memory). Check the gate before expensive work: `tools/cc-quota` (see Quota Governor).

## Model Usage (planning vs coding vs plugin)

Three different places pick a model, and they follow different rules:

| Where | Rule |
| --- | --- |
| **Planning / architecture / design work** | Use a high-capacity model (e.g. **Kimi**). Plan first, then implement. |
| **Implementation / coding of this project** | Use **DeepSeek**. |
| **The plugin at runtime** | The plugin's own settings decide. It defaults to `deepseek/deepseek-v4-flash` (`DEFAULT_MODELS` in `plugin/src/shared.js`) — the free models the `.env` lists first answer the prompt as a document instead of driving the browser. The operator can change the order in **Settings → Run on — model preference order**; the host passes it to the engine as `APPLY_MODELS`. Never hardcode a model into the native host. |

Free ids (`:free` / `-free`) cost nothing and bypass the budget gate; a run falls through to the
next model when one is rate-limited or does nothing. See the Quota Governor below.

## Quota Governor (top rule - applies before every run)

Command Code is the only model provider here, and the plan has three metered
windows. Every run is metered work; spend it deliberately.

| Window | What it meters | Gate |
| --- | --- | --- |
| 5-hour | burst guard, cap ~$14 | not a gate (free models bypass it) |
| weekly | rolling allowance, cap ~$35 | block at 95% |
| monthly | plan credit pool, cap ~$70 | block at 100% |

**Free models cost nothing from any window.** Free model ids end in `:free` or
`-free` (e.g. `meituan/LongCat-2.0:free`, `poolside/laguna-s-2.1-free`,
`inclusionai/ling-3.0-flash-sante:free`). They have their own daily caps
(LongCat: 100 requests/day, resets 00:00 UTC) and can be briefly unavailable.

## Test after every change (hard rule)

A change to the engine, prompts, config or cron wiring is **not done until it has been exercised**.
`bash -n` and a passing unit check are NOT enough — a sourced config line, a shell quote, or a
one-word command string can look perfect and still break **every** run silently.

1. **Wire check (fast, every change):** `tools/cron-run.sh <channel> --dry-run` — composes the prompt,
   runs the pre-flight, prints the plan and the model order. No model is invoked. Do this for prompt /
   config edits.
2. **Real run (launcher / model order / report / schedule changes):** `tools/cron-run.sh <channel>`,
   then read `logs/cron.log` and the channel's `run-log.md`. Confirm the run actually started, picked
   its models, and produced a report.
3. **Targeted guards:** `tools/tab-cleanup-selftest.sh` (tab sweep), `tools/model-fallback-selftest.sh`
   (model fallback), `tools/prefilter.py "$PWD" --rules` (scope/salary rules). Run the relevant one
   when you touch that area.
4. **Scheduling:** after editing the crontab, `crontab -l` and confirm each channel runs
   `tools/cron-run.sh <channel>` and nothing is left pointing at a removed/renamed path.

When in doubt after a change, do the real run — a silent break costs a whole day of applications.


