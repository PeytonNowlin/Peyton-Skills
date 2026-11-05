# Review monitoring and handoff

Read this when the first PR opens or when resuming pending review work. Monitor only PRs recorded for this run.

## Persisted state

Use `<git-common-dir>/work-issues/<run-id>/state.json`, as defined in the skill. Keep:

- The repository host and owner/name, authenticated login, run ID, issue budget, claimed issue numbers, outcomes, and blockers.
- Each PR's number, URL, issue numbers, branch, worktree, implementing agent, latest observed head SHA, and open/merged/closed state.
- Seen review/comment events, check outcomes, and outstanding findings. Track code review and security review separately for each head SHA, including status and completion evidence or blockers.
- Watcher status, runtime job ID, polling interval, next poll time, expiration time if applicable, and handoff instructions.

Write state atomically through a temporary file in the same directory followed by rename. The orchestrator owns state updates; a background watcher must use the same exclusive lock when updating it. Scope event keys by repository, PR, event type, and ID, including `updated_at` or a content hash for edited comments and the outcome for changing checks. An API failure is a monitoring error, not an empty review list or a successful check. Retain pending work for the next poll.

## One watcher

1. Check the runtime's supported observation tools. Keep one watcher while this task is active, using bounded waits that permit progress updates. Do not create a recurring automation to track a specific run to completion. If continued observation is unsupported, check once and use the handoff below; a background shell process cannot resume the agent after the response. Persist the observer status and next action. Read [scripts.md](scripts.md) before using the bundled notification helpers.
2. Fetch every page of reviews, review comments, and PR conversation comments, plus current check results and PR state. Read full code and security review bodies, available security reports, and inline findings. Re-read the head SHA after collection; if it changed, refresh before judging review coverage. Record new findings before dispatching them and keep them pending until handled, so a restart does not lose an already-seen event. Keep polls quiet while nothing meaningful changes; report new actionable findings, failed checks, completion, or required user action.
3. On verified merge or closure, stop follow-up on that PR and release its reservations once no worker is still editing or pushing. If a worker was active at merge, stop it and report any work that missed the merge. When all PRs are merged, closed, or explicitly handed over, stop the watcher through its runtime tool and record that status.
4. If the monitor expires while the session can re-arm it, renew the same run's watcher without losing state or creating a second watcher. If it cannot be renewed, or the runtime cannot continue after the response, use the handoff below.

## Automatic reviews

The repositories already run Codex code review and security review on every push. Observe both on the current head; never post manual review triggers, including after fixes or when a review is delayed.

- After a push, mark both reviews pending for the new head. Earlier reviews do not cover it. Record completion separately for each review using evidence tied to that head. Acknowledgments, missing findings, or a passing code review alone do not prove both reviews completed.
- If a review is missing, fails, or reports a limit, retain its pending or blocked status and report the concrete blocker. Continue supported observations or hand over the remaining work. Do not trigger a review or push an empty commit to restart one.
- When resuming older state, discard all manual review-request queues and cooldowns, for every reviewer. Preserve outstanding findings, reassess both automatic reviews on each current head, retire obsolete run-specific heartbeat automations, and continue with supported observation.

## Handoff

Before ending without a persistent watcher, save all pending findings and automatic review statuses, mark the watcher `handed_over`, and summarize the remaining PRs, blockers, next observation time, and absolute state-file path. Include this follow-up instruction with the actual path:

> Use $work-issues to continue review follow-up from `<absolute state-file path>`; claim no new issues. Reconcile GitHub state before acting.

On resume, confirm the repository and authenticated account, reconcile every tracked PR against GitHub, retain active file reservations, and reconcile both automatic review statuses. Check for an existing live watcher before starting another. Keep unresolved PRs recorded until verified completion or an explicit handoff; awaiting review is not reviewed or merged.
