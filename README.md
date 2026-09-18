# Peyton-Skills

Claude Code skills I use day to day, one folder per skill. Each folder holds a `SKILL.md` that Claude Code loads when you invoke the skill by name.

## Install

Clone once, then symlink whichever skills you want into your personal skills folder:

```sh
git clone https://github.com/PeytonNowlin/Peyton-Skills.git ~/GitHub/Peyton-Skills
ln -s ~/GitHub/Peyton-Skills/work-issues ~/.claude/skills/work-issues
```

To share a skill with everyone on one repo instead, copy its folder into that repo's `.claude/skills/`.

Pull the repo to pick up updates. Symlinked skills update in place.

## Skills

### `work-issues`

Works a batch of open GitHub issues into pull requests, then babysits each PR through its AI review.

```
/work-issues 3
```

The number is the issue budget for the run. For each issue it:

1. Picks issues assigned to you first, then unassigned oldest-first, and assigns each one to you as it claims it.
2. Creates a fresh `git worktree` off `origin/main` per branch, so your current checkout is untouched.
3. Opens one PR per issue (up to 3 related issues per PR) with a plain-English TL;DR at the top. It never merges or force-pushes.
4. Spawns a subagent per PR that polls the review for 20 minutes, pushes fixes, and pushes back on comments that are wrong or out of scope.
5. Ends with a summary: PRs opened, issues skipped and why, and how many eligible issues remain.

Requires the `gh` CLI, and Matt Pocock's [`pr`](https://github.com/mattpocock/skills) skill for the PR body template.

## Adding a skill

Create `<skill-name>/SKILL.md` with frontmatter (`name`, `description`, optionally `argument-hint` and `disable-model-invocation`) and the instructions below it. Add a row to this README.
