# Agent brief template

Copy to `<run-dir>/common-brief.md` and fill every `<...>`. Each agent's own prompt names its issue, worktree, branch and reserved files, then says "read the common brief in full first".

---

## Ground rules

Repository: `<owner/repo>`; `gh` is authenticated as `<login>`. Edit only your worktree. Other agents work in sibling worktrees. Hold work in progress as a WIP commit: `git stash` is one stack shared by every worktree.

Read first: the repository's agent instructions (`<CLAUDE.md / AGENTS.md>`), its testing guide (`<path>`), and the issue in full including comments (`gh issue view <n> --comments`). An issue's suggested remedy is a direction; verify its claims against the code.

Read and apply the Strategic programming section in `<absolute path to work-issues/SKILL.md>` during implementation and review fixes.

Setup: `<setup command>`. Services: `<how to start them>`.

## Verification

Run locally: `<unit tests>`, `<static analysis>`, `<JS tests>`, `<lint>`, then `<pre-push hook command>` before the PR, with the hooks running. **The exit code is the verdict.** A summary line reading OK above a non-zero exit is a failure. For timeouts, inspect logs and reproduce in isolation before attributing the failure to machine load.

`<repository-specific rules: browser tests off locally, line-ending traps, baseline files, ...>`

When regression coverage fits the change, demonstrate failure before the fix and success after it using a disposable copy or a reversible patch; preserve all working changes.

## File ownership

Ledger: `<absolute path to reservations.json>`, which you only read. Run state: `<absolute path to state.json>`. Before editing, list the open PRs and each one's files:

```sh
gh api --paginate 'repos/<owner/repo>/pulls?state=open&per_page=100' --jq '.[].number'
# for each: gh pr diff <n> --name-only
```

When a fix needs a file outside your reservation, ask for it and wait for the grant before editing.

## Commit and PR

Commit messages end with `<attribution lines>`. Repeat the full overlap check before pushing. Open or update the PR against `<base>`; keep it draft until the shared verification gate passes, then `gh pr edit <n> --add-assignee @me`. The body opens with `## TL;DR` (2-4 plain sentences), then the `pr` skill template. Put each `Closes #N` on its own line as plain text. End the body with `<attribution lines>`. Merging and force-pushing stay with the user.

## Review findings

Answer a finding with the smallest coherent fix that closes it under Strategic programming, plus a test that fails on the current head. A new capability you notice while fixing goes in your report as a follow-up, outside this PR. Then:

1. Re-read the PR state and head.
2. Push without force.
3. Reply on the thread and resolve it.
4. Observe automatic Codex code and security reviews on the new head; follow the shared monitoring reference.

## Reporting

Report at once for a blocker or a file request; otherwise report once at the end:

- the PR URL;
- per issue, what changed and how you verified it, including before/after evidence where practical;
- suite totals;
- what you deliberately left unfixed;
- every decision the user must make.

Stop and verify teardown of resources you started; preserve shared resources and evidence. Report any cleanup blocker.
