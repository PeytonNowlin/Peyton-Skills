# Agent brief template

Copy to `<run-dir>/common-brief.md` and fill every `<...>`. Each agent's own prompt names its issue, worktree, branch and reserved files, then says "read the common brief in full first".

---

## Ground rules

Repository: `<owner/repo>`; `gh` is authenticated as `<login>`. Edit only your worktree. Other agents work in sibling worktrees. Hold work in progress as a WIP commit: `git stash` is one stack shared by every worktree.

Read first: the repository's agent instructions (`<CLAUDE.md / AGENTS.md>`), its testing guide (`<path>`), and the issue in full including comments (`gh issue view <n> --comments`). An issue's suggested remedy is a direction; verify its claims against the code.

Setup: `<setup command>`. Services: `<how to start them>`.

## Verification

Run locally: `<unit tests>`, `<static analysis>`, `<JS tests>`, `<lint>`, then `<pre-push hook command>` before the PR, with the hooks running. **The exit code is the verdict.** A summary line reading OK above a non-zero exit is a failure. Under heavy machine load, a timeout in a file your change never touched is load: re-run that file alone and report what you saw.

`<repository-specific rules: browser tests off locally, line-ending traps, baseline files, ...>`

A new test executes the code under test, and you show it fails with the fix reverted (`git show origin/<base>:<path>` restores the old file).

## File ownership

Ledger: `<absolute path to reservations.json>`, which you only read. Run state: `<absolute path to state.json>`. Before editing, list the open PRs and each one's files:

```sh
gh api --paginate 'repos/<owner/repo>/pulls?state=open&per_page=100' --jq '.[].number'
# for each: gh pr diff <n> --name-only
```

When a fix needs a file outside your reservation, ask for it and wait for the grant before editing.

## Commit and PR

Commit messages end with `<attribution lines>`. Push, open a ready PR against `<base>`, then `gh pr edit <n> --add-assignee @me`. The body opens with `## TL;DR` (2-4 plain sentences), then the `pr` skill template. Put each `Closes #N` on its own line as plain text. End the body with `<attribution lines>`. Merging and force-pushing stay with the user.

## Review findings

Answer a finding with the smallest fix that closes it, plus a test that fails on the current head. A new capability you notice while fixing goes in your report as a follow-up, outside this PR. Then:

1. Re-read the PR state and head.
2. Push without force.
3. Reply on the thread and resolve it.
4. Post `Cursor review this`.

## Reporting

Report at once for a blocker or a file request; otherwise report once at the end:

- the PR URL;
- per issue, what changed and how you verified it, including the revert proof;
- suite totals;
- what you deliberately left unfixed;
- every decision the user must make.
