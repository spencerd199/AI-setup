---
status: active
project: career-search
type: log
---
# job-finder — run log

Weekdays 8:00 AM. Completion token: `SCREEN-COMPLETE`. **This job never submits** — every pass goes to [[Pending Approvals]].

One row per run, written by `run-job-finder.ps1`. A run that doesn't print its completion token is logged `FAILED` whatever its exit code.

| When | Status | Detail |
|---|---|---|
| 2026-09-09 08:00 | OK | 14 roles found, 2 passed, 12 screened out. 2 drafts written, awaiting approval. |
| 2026-09-10 08:00 | OK | 9 roles found, 0 passed. |
| 2026-09-11 08:01 | OK | 11 roles found, 1 passed. 1 draft written, awaiting approval. |
| 2026-09-14 08:00 | OK | 16 roles found, 1 passed (Northwind Capital, 8.2). 1 draft written. |
| 2026-09-15 08:00 | FAILED | Could not find the Target Companies list - searched job boards only, did not finish |
| 2026-09-15 08:52 | OK | Manual re-run after the link fix. 7 roles found, 1 passed. 1 draft written. |

> **The 2026-09-15 FAILED row is the design working.** The scheduler reported success and the process exited 0. The firm-list note had been renamed outside Obsidian, so the `[[Target Companies]]` link the job follows no longer resolved. The agent said so and correctly withheld its completion token. **That missing token is the only reason this was caught the same morning instead of weeks later.**
