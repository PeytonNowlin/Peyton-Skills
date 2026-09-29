---
name: work-issues
description: "Work a batch of open GitHub issues in the current repo into PRs, one worktree per branch, with a CodeRabbit review loop. Pass the issue budget as the argument."
argument-hint: "<max-issues>"
disable-model-invocation: true
---

Work open GitHub issues in this repo that are unassigned or assigned to me. Issues assigned to anyone else are out of scope.

**Issue budget for this run: $ARGUMENTS** (if empty, ask for a number before doing anything else).

## Select

1. List candidates: `gh issue list --state open --json number,title,assignees,labels,createdAt --limit 200`.
2. Order: issues already assigned to me first, then unassigned, oldest first.
3. Skip an issue when it is labeled `blocked`, references an unmerged dependency (another issue or PR), or needs a human decision. Record the reason for the summary. Skipped issues cost no budget.
4. Claim an issue with `gh issue edit <n> --add-assignee @me`. Claiming is what spends one unit of budget. Stop claiming once the budget is spent, even with eligible issues remaining.

## Branch

- Every branch starts from fresh `origin/main`: `git fetch origin && git worktree add ../<repo>-<issue#> -b <branch> origin/main`. The current working tree stays untouched.
- One issue per PR by default. Up to 3 issues share a PR only when they touch the same feature or files and a reviewer would read them together.
- Open PRs must not overlap: two PRs touching the same files, or one depending on the other, is a conflict. If issue B needs issue A merged first, finish A, stop, and record B as blocked.
- Check overlap against the live list, not memory: `for p in $(gh pr list --state open --json number -q '.[].number'); do gh pr diff $p --name-only | sed "s|^|#$p |"; done`. Files named in an issue body are often context, not the fix, so an apparent overlap is worth a second look before you skip the issue.

## Delegate

When a subagent implements an issue, it sees none of your memory or project notes, only its brief. Put in every brief:

- The worktree path and branch, and "edit only this worktree".
- The live overlap command above, with "run it before editing any file; if the fix needs a taken file, stop and report".
- Any local services the tests or evidence need (a container runtime, a database) and how to start them. Start them yourself before dispatching, and write "if it is not running, start it; never report it unavailable". A report that says a service was unavailable is a defect: start it and send the agent back for the evidence it skipped.
- The PR body template from the PR section below, because a subagent will not load the `pr` skill by itself.
- "Report once, at the end." An agent that reports every time it waits costs a turn per report.

## PR

- Write the body with the `pr` skill.
- The first section of every body is **TL;DR**: 2 to 4 plain-English sentences a non-engineer can read. The `pr` template follows it.
- Push the branch and open the PR. Merging and force-pushing are off the table for this skill.

## Review loop

CodeRabbit is the only reviewer. Every PR gets an automatic CodeRabbit review, and catching it is a core part of the run. Its reviews routinely take longer than 20 minutes, so a polling subagent per PR sees nothing and burns tokens. Instead:

1. **One watcher for the whole run.** As soon as the first PR opens, arm a single `Monitor` over all of your open PRs. Each poll, emit only lines not seen before, deduplicated through a seen-file keyed on the review or comment id: failed checks, CodeRabbit reviews, top-level inline comments, and merges. Re-arm it every time it expires until every PR from the run has merged or been handed over.
2. **Route each finding to the agent that wrote the PR.** `SendMessage` it with the specific findings. It keeps its context, so this is far cheaper than a fresh agent. Its brief: verify each finding; if real, fix it in the worktree with a test that fails when the fix is reverted, push, reply on the thread, resolve it, and re-request review with `@coderabbitai review`. If wrong or out of scope, reply explaining why and leave the code alone. Report once.
3. **Read the whole review.** CodeRabbit puts "outside diff range" and nitpick findings only in the review body, with no inline thread, so "0 unresolved threads" can hide a real finding. It can also post an approval seconds after posting findings, so an approval is not proof of no findings. Judge by the reviews on the head commit.
4. **A failed check is not automatically the PR's fault.** Read the failed job's log before acting (`gh api repos/<o>/<r>/actions/jobs/<id>/logs` works while the run is still going). A cancelled job reruns with `gh run rerun <id> --failed`. A known flaky test fixed on main is solved by merging main into the branch (a merge, never a force-push).

**Every PR needs a CodeRabbit review on its head commit.** No other reviewer substitutes for it; do not ask `@claude` or any other bot for a review. CodeRabbit has a small hourly review limit. A rate-limited PR gets a "Review limit reached" comment and is never reviewed later on its own, and a burst of `@coderabbitai review` comments only burns more of the limit. So request reviews one PR at a time. When CodeRabbit answers with its limit, note the wait time it gives, and have the watcher post a single `@coderabbitai review` on that PR once the window has passed. Keep a queue of rate-limited PRs and release them one at a time. A PR still unreviewed at the end of the run is listed in the summary as awaiting CodeRabbit.

## Stop

Done when the budget is spent or no eligible issues remain. Finish with a summary:

- PRs opened: link plus the issue numbers each closes.
- Issues skipped or blocked, each with its reason.
- Decisions waiting on the user that agents raised (behaviour changes, data cleanups, settings to confirm).
- PRs still awaiting a CodeRabbit review (rate-limited or pending).
- Count of eligible issues left for the next run.

Keep the watcher running after the summary. Reviews on the last PRs usually land after it.
