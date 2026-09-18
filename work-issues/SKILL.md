---
name: work-issues
description: "Work a batch of open GitHub issues in the current repo into PRs, one worktree per branch, with an AI review loop. Pass the issue budget as the argument."
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

## PR

- Write the body with the `pr` skill.
- The first section of every body is **TL;DR**: 2 to 4 plain-English sentences a non-engineer can read. The `pr` template follows it.
- Push the branch and open the PR. Merging and force-pushing are off the table for this skill.

## Review loop

Every PR gets an automatic AI review. After opening each PR, spawn one subagent per PR with this brief:

> Poll PR #<n> every 2 minutes for up to 20 minutes. On requested changes: fix in worktree `<path>`, push, re-request review. When a comment is wrong or out of scope, reply on the thread explaining why and leave the code alone. Report back what changed and what was pushed back on.

Subagents run in parallel while you continue to the next issue.

## Stop

Done when the budget is spent or no eligible issues remain. Finish with a summary:

- PRs opened: link plus the issue numbers each closes.
- Issues skipped or blocked, each with its reason.
- Count of eligible issues left for the next run.
