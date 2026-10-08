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

1. In the Codex desktop app, discover the `automation_update` tool and create or update one `heartbeat` automation attached to the current chat. Schedule it every five minutes, using the tool's supported schedule format. Reuse the saved automation ID; if none is saved, inspect existing automations for this run before creating one. Confirm creation and record its ID and next check time. Local follow-up requires the host and app to remain available. If the current Codex surface has no supported scheduling tool, check status once and use the handoff below; do not assume a background shell process can resume the agent after the response.
2. Fetch every page of reviews, review comments, and PR conversation comments, plus current check results and PR state. Read full code and security review bodies, available security reports, and inline findings. Re-read the head SHA after collection; if it changed, refresh before judging review coverage. Record new findings before dispatching them and keep them pending until handled, so a restart does not lose an already-seen event. Keep polls quiet while nothing meaningful changes; report new actionable findings, failed checks, completion, or required user action.
3. On verified merge or closure, stop follow-up on that PR and release its reservations once no worker is still editing or pushing. If a worker was active at merge, stop it and report any work that missed the merge. When all PRs are merged, closed, or explicitly handed over, stop the heartbeat through the automation tool and record that status.
4. If the monitor expires while the session can re-arm it, renew the same run's watcher without losing state or creating a second watcher. If it cannot be renewed, or the runtime cannot continue after the response, use the handoff below.

Use a durable automation prompt with the actual repository and state-file path, such as:

> Use $work-issues to continue review follow-up for `<owner/repo>` from `<absolute state-file path>`. Claim no new issues. Read the skill's monitoring reference, reconcile tracked PRs with GitHub, handle new findings in their recorded worktrees, and observe automatic Codex code and security reviews on each current head without posting review triggers. Stay quiet while nothing actionable changes; notify on meaningful changes, completion, failure, or required user action. Stop this heartbeat when every tracked PR is merged, closed, or explicitly handed over. Do not merge or force-push.

## Automatic reviews

The repositories already run Codex code review and security review on every push. Observe both on the current head; never post manual review triggers, including after fixes or when a review is delayed.

- After a push, mark both reviews pending for the new head. Earlier reviews do not cover it. Record completion separately for each review using evidence tied to that head. Acknowledgments, missing findings, or a passing code review alone do not prove both reviews completed.
- If a review is missing, fails, or reports a limit, retain its pending or blocked status and report the concrete blocker. Continue supported observations or hand over the remaining work. Do not trigger a review or push an empty commit to restart one.
- When resuming older state, discard all manual review-request queues and cooldowns, including Codex and CodeRabbit requests. Preserve outstanding findings, reassess both automatic reviews on each current head, and update the existing heartbeat prompt before continuing.

## Handoff

Before ending without a persistent watcher, save all pending findings and automatic review statuses, mark the watcher `handed_over`, and summarize the remaining PRs, blockers, next observation time, and absolute state-file path. Include this follow-up instruction with the actual path:

> Use $work-issues to continue review follow-up from `<absolute state-file path>`; claim no new issues. Reconcile GitHub state before acting.

On resume, confirm the repository and authenticated account, reconcile every tracked PR against GitHub, retain active file reservations, and reconcile both automatic review statuses. Check for an existing live watcher before starting another. Keep unresolved PRs recorded until verified completion or an explicit handoff; awaiting review is not reviewed or merged.
