# Peyton-Skills

Shared skills for Codex, one folder per skill. Each folder holds a `SKILL.md` that Codex loads when you invoke the skill by name. Instructions use the invoking user's GitHub account and the current repository's setup, so teammates can use the same skill.

## Install

Clone once, then symlink whichever skills you want into your personal skills folder:

```sh
git clone https://github.com/PeytonNowlin/Peyton-Skills.git ~/GitHub/Peyton-Skills
mkdir -p ~/.agents/skills
ln -s ~/GitHub/Peyton-Skills/work-issues ~/.agents/skills/work-issues
```

To share a skill with everyone on one repo instead, copy its entire folder into that repo's `.agents/skills/`. Use one installation location per skill to avoid duplicate entries. Existing installations already discovered by Codex can keep their current symlink.

Pull the repo to pick up updates. Symlinked skills update in place.

## Skills

### `work-issues`

Works a batch of open GitHub issues into pull requests, then babysits each PR through its CodeRabbit review.

```
$work-issues 3
```

The number is the issue budget for the run. For each issue it:

1. Fetches the complete issue inventory, picks issues assigned only to you first, then unassigned oldest-first, and verifies ownership as it claims each one.
2. Creates a fresh `git worktree` off the repository's target branch per branch. Checks all open PRs and reserves files locally before agents edit them, so unpublished work in another active worktree is accounted for.
3. Verifies the issue's acceptance criteria and required checks, then opens one PR per issue (up to 3 related issues per PR) with a plain-English TL;DR. Incomplete verification is reported in a draft PR or as a blocker. It never merges or force-pushes.
4. Uses one scheduled follow-up in the current Codex chat when the automation tool is available, with persisted findings and CodeRabbit retry times. Rechecks PR state before review fixes. In surfaces without scheduling, leaves an explicit handoff.
5. Ends with PR links, skipped issues and reasons, remaining eligible issues, and watcher or handoff status.

Requires authenticated `gh` access, Git worktrees, and Matt Pocock's [`pr`](https://github.com/mattpocock/skills) skill for the PR body template. Uses the repository's own service and test setup; no particular person's machine or private configuration is required. File reservations coordinate runs sharing a Git directory; other machines' work becomes visible through published PRs.

The skill stays explicitly invoked through `agents/openai.yaml`. It uses Codex subagents when available and works sequentially otherwise. Review monitoring details are in [work-issues/references/monitoring.md](work-issues/references/monitoring.md); local scheduled follow-up requires the host and desktop app to remain available. Copy the whole skill folder when installing so its metadata and reference are available.

To resume pending reviews without claiming more issues, ask: `Use $work-issues to continue review follow-up from <state-file path>; claim no new issues.`

See the official [Codex skill documentation](https://learn.chatgpt.com/docs/build-skills) and [scheduled-task documentation](https://learn.chatgpt.com/docs/automations) for installation and runtime capabilities.

## Adding a skill

Create `<skill-name>/SKILL.md` with `name` and `description` frontmatter and the instructions below it. Put Codex UI metadata and invocation policy in `agents/openai.yaml` when needed. Add the skill to this README.
