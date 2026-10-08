# Review monitoring and handoff

Read this when the first PR opens or when resuming pending review work. Monitor only PRs recorded for this run.

## Persisted state

Use `<git-common-dir>/work-issues/<run-id>/state.json`, as defined in the skill. Keep:

- The repository host and owner/name, authenticated login, run ID, issue budget, claimed issue numbers, outcomes, and blockers.
- Each PR's number, URL, issue numbers, branch, worktree, implementing agent, latest observed head SHA, and open/merged/closed state.
- Seen review/comment events, check outcomes, outstanding findings, and the review-request queue. Each queued request has a PR number, head SHA, reason, UTC `retryAfter`, and the last request's comment ID.
- Watcher status, runtime job ID, polling interval, next poll time, expiration time if applicable, and handoff instructions.

Write state atomically through a temporary file in the same directory followed by rename. The orchestrator owns state updates; a background watcher must use the same exclusive lock when updating it. Scope event keys by repository, PR, event type, and ID, including `updated_at` or a content hash for edited comments and the outcome for changing checks. An API failure is a monitoring error, not an empty review list or a successful check. Retain pending work for the next poll.

## One watcher

1. In the Codex desktop app, discover the `automation_update` tool and create or update one `heartbeat` automation attached to the current chat. Schedule it every five minutes, using the tool's supported schedule format. Reuse the saved automation ID; if none is saved, inspect existing automations for this run before creating one. Confirm creation and record its ID and next check time. Local follow-up requires the host and app to remain available. If the current Codex surface has no supported scheduling tool, check status once and use the handoff below; do not assume a background shell process can resume the agent after the response.
2. Fetch every page of reviews, review comments, and PR conversation comments, plus current check results and PR state. Read full review bodies as well as inline findings. Re-read the head SHA after collection; if it changed, refresh before judging review coverage. Record new findings before dispatching them and keep them pending until handled, so a restart does not lose an already-seen event. Keep polls quiet while nothing meaningful changes; report new actionable findings, failed checks, completion, or required user action.
3. On verified merge or closure, stop follow-up on that PR and release its reservations once no worker is still editing or pushing. If a worker was active at merge, stop it and report any work that missed the merge. When all PRs are merged, closed, or explicitly handed over, stop the heartbeat through the automation tool and record that status.
4. If the monitor expires while the session can re-arm it, renew the same run's watcher without losing state or creating a second watcher. If it cannot be renewed, or the runtime cannot continue after the response, use the handoff below.

Use a durable automation prompt with the actual repository and state-file path, such as:

> Use $work-issues to continue review follow-up for `<owner/repo>` from `<absolute state-file path>`. Claim no new issues. Read the skill's monitoring reference, reconcile tracked PRs with GitHub, handle new findings in their recorded worktrees, and process due Codex requests. Stay quiet while nothing actionable changes; notify on meaningful changes, completion, failure, or required user action. Stop this heartbeat when every tracked PR is merged, closed, or explicitly handed over. Do not merge or force-push.

## Review-request queue

Use [Codex GitHub review](https://learn.chatgpt.com/docs/third-party/github). If Codex review is unavailable for the repository, record the setup or access blocker and hand it over. Do not substitute another reviewer.

When resuming state created before the Codex-only policy, discard queued CodeRabbit requests and their cooldowns. Preserve outstanding findings, reassess Codex coverage on each current head, and update the existing heartbeat prompt to this policy before continuing.

- Observe whether automatic Codex review arrives. Queue a manual request when review is absent, a fix changes the head, or Codex reports a review limit. Persist a supplied wait window as an absolute UTC `retryAfter`; if no retry time is supplied, report the blocker rather than repeatedly guessing and posting.
- Request one PR at a time. Immediately before posting `@codex review`, confirm the PR is open, refresh its head and review coverage, and read the conversation for requests already posted. Drop requests already covered by a review on the current head; replace stale queued head SHAs with the current one and reassess whether review is needed.
- Record the posted comment ID and wait for a response or the next scheduled observation. Never post another request for the same head while a previous request remains pending. If the response is a rate limit, keep the request queued until its supplied window passes, then retry once and record that request. A further limit updates the next retry time; it does not trigger a burst of comments.
- A queued request becoming due is a meaningful event: the watcher must process it even if no new review or comment appeared. If a post's result is uncertain, read back the conversation before retrying. Resume only one watcher and one queue processor for a run.

## Handoff

Before ending without a persistent watcher, save all pending findings and requests, mark the watcher `handed_over`, and summarize the remaining PRs, blockers, retry times, and absolute state-file path. Include this follow-up instruction with the actual path:

> Use $work-issues to continue review follow-up from `<absolute state-file path>`; claim no new issues. Reconcile GitHub state before acting.

On resume, confirm the repository and authenticated account, reconcile every tracked PR against GitHub, retain active file reservations, and process the existing queue. Check for an existing live watcher before starting another. Keep unresolved PRs recorded until verified completion or an explicit handoff; awaiting review is not reviewed or merged.
