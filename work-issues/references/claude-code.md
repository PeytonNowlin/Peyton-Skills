# Running work-issues in Claude Code

Read this before Prepare. Shared policy lives in SKILL.md: use the same positive integer budget, ownership checks, verification gate, Codex-only automatic reviews, and no-merge/no-force-push boundary in every runtime.

## Run scripts

Read [scripts.md](scripts.md) before using the bundled helpers. They are available to every runtime. Initialize the run state with repository host, owner/name, login, and run ID before observations.

## Delegate

Use the available Agent tool when delegation helps; otherwise work sequentially. Limit concurrency to the repository's service and test capacity. Write `<run-dir>/common-brief.md` from [brief-template.md](brief-template.md), filling each placeholder. Give each worker its worktree, issue, acceptance checklist, reserved files, and the brief path.

Resume the implementing agent using a tool that starts a new turn; if unavailable, continue in its recorded worktree. Stop workers before releasing their reservations.

## Review observation

Read [monitoring.md](monitoring.md). Use `ONCE=1 bash <skill>/scripts/watch.sh <run-dir>` for one observation. Its output is a notification aid, not review-completion evidence: read full reviews and reports and verify both reviews against the current head. Use a supported Monitor only while the task remains active, with bounded waits and one watcher per run. At handoff, stop it and persist pending work unless the user explicitly requested supported continued monitoring.

Older run state may contain other reviewer requirements or trigger queues. Migrate it using the monitoring reference; only automatic Codex code and security reviews are required. Never post manual review triggers or enqueue a merge.
