---
name: work-issues
description: "Work a bounded batch of open GitHub issues into PRs, with isolated worktrees and Codex follow-up. Invoke with an issue budget or resume an existing run's review follow-up."
---

Work open GitHub issues in this repo that are unassigned or assigned to the authenticated GitHub user. Issues with any other assignee are out of scope.

**In Claude Code**, read [references/claude-code.md](references/claude-code.md) before Prepare. It replaces the parts below that name Codex tools: budget, delegation, reviewers and monitoring.

For a new batch, read the issue budget from the user's request, for example `$work-issues 3`. Require a positive integer; if missing or invalid, ask before claiming any issues. For an explicit request to resume review follow-up, load the supplied run-state file and continue the Review loop without claiming new issues or asking for a new budget.

## Prepare

- Read the repository's agent and setup instructions. Resolve its GitHub host, repository, authenticated login (`gh api user --jq .login`), and target branch. Use the documented target branch, otherwise the remote's default branch. For GitHub Enterprise, include `--hostname <host>` in every API command below.
- Load the installed `pr` skill before claiming issues. Use this repository's services and verification commands; do not assume a particular person's machine, installed software, or credentials.
- Store local coordination in `<git-common-dir>/work-issues/`, using the absolute path from `git rev-parse --path-format=absolute --git-common-dir`. Keep a shared `reservations.json` and a unique `<run-id>/state.json` for this run. Serialize coordination updates using an exclusive `coordination.lock` in that directory, releasing it after each update. These files stay outside tracked project files; store no credentials.

## Select

1. Fetch every page before selecting or counting issues:

   ```sh
   gh api --paginate --slurp 'repos/{owner}/{repo}/issues?state=open&per_page=100'
   ```

   Save the response in the run directory and process it only after the command succeeds. It is an array of page arrays: flatten the pages, then exclude entries with a `pull_request` field because this endpoint also returns PRs. If any page fails, report the incomplete inventory instead of selecting from it or reporting an exact remaining count.
2. Filter to issues assigned only to the authenticated user or to no one. Order assigned issues first, then unassigned, oldest first within each group (`created_at`, then issue number).
3. Read each candidate's body and dependencies. Skip issues labeled `blocked`, with an unresolved dependency, needing a human decision, already being addressed by an open PR, or reserved by another active run. Record the reason. Skipped issues cost no budget.
4. Re-read the issue immediately before claiming; skip it if it has closed or gained another assignee. Claim with `gh issue edit <n> --add-assignee @me`, then verify its state and assignees. Record each successfully claimed issue once in the run state; that spends one unit of budget, including issues already assigned to the user. Stop claiming when the budget is spent, and finish the work already claimed.

## Branch

- Every branch starts from the freshly fetched target branch: `git fetch <remote> && git worktree add "../<repo>-<issue#>" -b <branch> <remote>/<base>`. Follow repository branch conventions. The current working tree stays untouched.
- One issue per PR by default. Up to 3 issues share a PR only when they touch the same feature or files and a reviewer would read them together.
- Open PRs must not overlap: two PRs touching the same files, or one depending on the other, is a conflict. If issue B needs issue A merged first, finish A, stop, and record B as blocked.
- Check overlap against every live open PR:

  ```sh
  gh api --paginate 'repos/{owner}/{repo}/pulls?state=open&per_page=100' --jq '.[].number'
  ```

  For each number, run `gh pr diff <n> --name-only`. Exclude only the PR for the branch currently being updated. If the listing or any diff fails, treat the overlap check as incomplete and resolve that before editing. Files named in an issue body are often context, not the fix, so investigate before skipping an apparent overlap.
- Reserve planned files in `reservations.json` before editing or dispatching implementation. Record the run, issue, branch, worktree, worker, repository-relative file paths, and status. The orchestrator owns updates; concurrent local runs must serialize the check-and-reserve operation with an exclusive lock. Check both live PR files and reservations from other active worktrees before granting ownership. Workers may investigate read-only, but must request any additional files before editing them.
- Keep reservations while work is active or its PR is open. Release them after verified merge, closure, or confirmed abandonment; a handoff retains ownership. Verify an old reservation's PR and worktree status before reclaiming it. Local reservations coordinate runs sharing this Git directory; work on another machine is visible only once published on GitHub.

## Delegate

Use Codex's available subagent tools when delegation helps. Keep implementation agents within this task; creating separate user-owned chats is not part of delegation. If subagents are unavailable, perform the same workflow sequentially. Give each agent a self-contained brief rather than relying on inherited memory or project notes. Include:

- The worktree path and branch, and "edit only this worktree".
- The issue's acceptance criteria, relevant repository instructions, reserved files, and absolute paths to the reservation ledger and run state. Other agents may be working in the repository: preserve their changes and request ownership before editing additional files.
- The complete live overlap procedure above, with "run it before editing; if the fix needs a taken file, stop and report".
- Required services, setup commands, and verification commands. Start the required services before dispatching when possible. If a service is stopped, try the documented startup procedure; if software, credentials, or a working environment are missing, report the specific blocker and the evidence still needed.
- The actual body template loaded from the `pr` skill, preceded by the TL;DR requirement below, and the verification gate.
- "Report immediately for a blocker or additional file reservation; otherwise report once, at the end."

## Verify

- Check the implemented behavior against the issue's acceptance criteria in its own worktree. For bug fixes, reproduce the failure when practical and add meaningful regression coverage when tests fit the change.
- Run the repository's required checks and the tests relevant to the changed behavior. For visible UI changes, inspect the rendered result and capture a screenshot or clip for the PR.
- Open a ready-for-review PR only when the acceptance criteria are verified and required checks pass. If verification is blocked or fails, investigate the cause and record the exact limitation; use a draft PR with the missing evidence clearly stated, or report the issue as blocked. A check that was not run is not a pass.

## PR

- Write the body with the `pr` skill.
- The first section of every body is **TL;DR**: 2 to 4 plain-English sentences a non-engineer can read. The `pr` template follows it.
- Push the branch and open the PR. Merging and force-pushing are off the table for this skill.
- When Codex provides an artifact attachment tool, attach each created PR to the current task.

## Review loop

Codex is the only reviewer. The repositories are configured to run Codex code review and security review automatically on every push. Monitor both reviews without posting manual review triggers. Use one watcher rather than a polling subagent per PR:

1. **One watcher for this run.** As soon as the first PR opens, read [references/monitoring.md](references/monitoring.md) and start one supported background monitor over this run's PRs. Persist its state and the status of both automatic reviews there. If the runtime cannot keep it alive after the response, hand over pending work with that state file; do not claim monitoring is active.
2. **Route each finding to the agent that wrote the PR.** Use the available Codex subagent follow-up tool; an idle agent needs a call that starts another turn, not just a queued notification. If the agent is no longer available, continue in its recorded worktree. Before editing and again before pushing, re-read the PR's state and head commit. If it has merged or closed, stop and report the remaining finding rather than pushing to the old branch. Reconcile unexpected head changes before proceeding. Verify each finding; if real, fix it with regression coverage appropriate to the change, repeat the verification gate, push, reply on the thread, resolve it, and wait for automatic code and security reviews on the new head. If wrong or out of scope, reply explaining why and leave the code alone. Answer a finding with the smallest fix that closes it: a new capability noticed while fixing is a follow-up issue, never part of this PR, because each added behaviour draws its own review round. Report once.
3. **Read the whole review.** Read all Codex code and security review bodies, inline findings, reports, and completion responses. Zero unresolved threads alone does not prove that the head commit was reviewed. Record the reviewed head and completion evidence separately for code review and security review; if coverage is uncertain, keep the PR awaiting Codex.
4. **A failed check is not automatically the PR's fault.** Read the job's log before acting (`gh api repos/<o>/<r>/actions/jobs/<id>/logs`). If logs are not yet available, record that and check on the next scheduled poll. Inspect the cause before rerunning failed or cancelled jobs. A known flaky test fixed on the target branch is solved by fetching and merging that branch into the PR branch (a merge, never a force-push).

**Every PR needs completed Codex code and security reviews on its head commit.** Do not post manual review requests or substitute another reviewer. If either automatic review is pending, failed, unavailable, or has uncertain coverage, report that status and follow the monitoring reference.

## Stop

Stop claiming when the budget is spent or no eligible issues remain. Finish each claimed issue with a PR or a recorded blocker, then summarize:

- PRs opened: link plus the issue numbers each closes.
- Issues skipped or blocked, each with its reason.
- Decisions waiting on the user that agents raised (behaviour changes, data cleanups, settings to confirm).
- PRs still awaiting Codex code or security review, identifying which review is pending or blocked.
- Count of eligible issues left for the next run, based on a complete refreshed inventory; if unavailable, state that the count is unknown.
- Watcher status (active or handed over), the absolute run-state path, and the next observation time or remaining action.

Keep the watcher running after the summary only when the runtime supports it. Otherwise hand over pending review work as described in the monitoring reference. Neither a summary nor a Codex approval authorizes merging.
