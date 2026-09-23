---
status: active
project: meta
type: index
---
# Agents & Jobs

Recurring tasks the AI runs on a schedule — one folder per job. **The folders hold the instructions; the operating system pulls the trigger.** Because the instructions live in the vault, a job is changed by editing its `SKILL.md` in Obsidian. Nothing is redeployed; the next run simply reads the new version.

## Jobs in this folder

| Job | Schedule | What it does | Can it act on its own? |
|---|---|---|---|
| **shop-manager/** | Daily, 12:00 PM | Checks the [[Online Shop]]: messages, orders, listing status, stats. Answers routine buyer questions from approved product facts | **Reports only.** Never edits a listing, price or setting |
| **job-finder/** | Weekdays, 8:00 AM | Searches listings, screens each against `criteria.md`, drafts applications for the ones that pass | **Never submits.** Every draft goes to [[Pending Approvals]] |

Each job folder holds three files:
- `SKILL.md` — the instructions the run follows
- `run-<job>.ps1` — the runner that starts Claude Code and checks the result
- `run-log.md` — the heartbeat: one row per run, whatever happened

## How a scheduled run works

```
Windows Task Scheduler
  -> run-hidden.vbs                 (launches the runner with no console window)
  -> run-<job>.ps1                  (starts in the Chronos (AGENT) folder, like a manual session)
  -> claude -p                      (prompt piped in through stdin, model pinned, vault access granted)
  -> reads SKILL.md, does the work
  -> prints SUMMARY + completion token
  -> runner writes one row to run-log.md: OK or FAILED
```

The runner starts in the same `Chronos (AGENT)` folder a manual session does, so a scheduled job loads the same `CLAUDE.md` and follows the same rules as an interactive one.

## The design rules, and why each exists

- **Every run writes a heartbeat row, even when nothing happened.** A missed run and a quiet run otherwise look identical. The log is the only place a silent failure becomes visible.
- **An exit code of 0 doesn't prove the work was done.** It only means the process ended. Each job must print a completion token (`CHECKS-COMPLETE`, `SCREEN-COMPLETE`) as its final line, and only if every step genuinely ran. No token means the runner logs `FAILED`, whatever the exit code.
- **Log the reason, not the number.** `exited 1` is the CLI's generic failure code: an expired login, a usage limit and a network drop all produce it. The runner pulls the actual error line out of the output and logs that. *(shop-manager does this; job-finder still needs the fix — on [[Active Priorities]].)*
- **The prompt goes in through stdin, never as a command-line argument.** Windows PowerShell mangles arguments containing double quotes, which silently truncates the prompt. The model answers a fragment and exits 0.
- **Pin an explicit model ID and effort level.** A job that passes neither silently inherits the global default, usually the most expensive setting. An alias can also move to a different model without anyone choosing that.
- **Grant vault access explicitly (`--add-dir`).** The runner's working folder is `Chronos (AGENT)`, so every vault file sits outside it and needs explicit permission to read.
- **Paths are derived, not hardcoded.** A runner that finds its own location can't be broken by a folder rename. A hardcoded path can.
- **Report, don't act.** Anything irreversible — submitting, publishing, paying, sending — goes to the approval queue and waits for a human.

## Diagnosing a FAILED row

1. **Check the blast radius first.** If every job failed at the same time, the cause is shared (a usage limit, an expired login), not a defect in one job.
2. **Read the run's transcript, not just the log.** The last message carries the real error verbatim.
3. **Check the calendar.** A weekday job writes no row on Saturday, and that's correct.

## Adding a job

1. Copy an existing job folder and rename it.
2. Rewrite `SKILL.md`: the steps, the hard limits, and the completion token.
3. Update the token and prompt in the runner.
4. Register it in Task Scheduler, pointing at `run-hidden.vbs` with the runner as its argument.
5. **Run it once by hand** and confirm an `OK` row lands in `run-log.md` before trusting the schedule.
6. Add it to the table above.
