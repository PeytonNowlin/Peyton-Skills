# Running work-issues in Claude Code

Read this before Prepare when the runtime is Claude Code. Each section replaces the same-named part of SKILL.md; everything else in SKILL.md applies unchanged.

## Budget

A positive integer, or "all eligible" when the user asks for as many as possible. Record the budget as given in `state.json`. Ask only when the request names no amount at all.

## Run scripts

Copy `scripts/` from this skill into the run directory at the start of a run, then use the copies. `coord.py` is the locked JSON updater that SKILL.md's `coordination.lock` rule refers to.

| Script | Use |
| --- | --- |
| `coord.py <file> '<python using d>'` | Every `state.json` / `reservations.json` update. |
| `watch.sh <run-dir>` | The single watcher (below). Reads `prs.txt`, one PR number per line. |
| `rv.sh <run-dir> <pr>...` | One-glance review status per PR: head, Codex rows, each bot's latest review sorted by time, unresolved threads. |
| `merged.sh <run-dir> <pr>...` | After a verified merge: mark it in state, drop it from `prs.txt`, release its reservations. |

Each script reads `repo` and `login` from `state.json`, so write those first.

## Delegate

Dispatch with the Agent tool, `subagent_type: general-purpose`, at most 10 at once, and at most 6 when the units run JavaScript tests. A Vitest run under heavy machine load times out on files the branch never touched. That wastes reruns and tempts an agent to skip a hook, so a lower cap is cheaper than the retries.

Write one shared brief per run to `<run-dir>/common-brief.md`, start it from `references/brief-template.md`, and give each agent a short unit-specific prompt that points at the brief. Continue an agent with SendMessage, never a fresh Agent call: the author keeps its context. Stop an agent whose PR is merged or fully green with TaskStop when it keeps waking on leftover background work.

## Reviewers

Three bots review every PR, and each needs different handling:

- **Codex** (`chatgpt-codex-connector[bot]`): reviews code and security automatically on every push. Its tracking comment's status table and embedded `headSha` are the completion evidence. Findings are inline comments with a P0-P3 badge.
- **Cursor** (`cursor[bot]`, the automation): reviews when a PR opens and when the user's account comments. It does not review on a push alone. After a fix push, post `Cursor review this` once. A 👍 body is its pass. Ignore the separate "Skipping Bugbot" reply.
- **CodeRabbit** (`coderabbitai[bot]`): reviews automatically while its allowance lasts. "Rate limited" means it skipped that PR, never that the PR passed. Read its review body: findings outside the diff live only there. Never post a comment to request it.

A finding can arrive labelled with the new head but describe the code before the fix. Read the code at the head before routing a finding. When the head already fixes it, reply with the line and the test that prove it, and resolve the thread yourself.

## Superseded change requests

A bot's CHANGES_REQUESTED stays on the PR after its finding is fixed, and it blocks merging. Dismiss it only when it is **superseded**:

1. it sits on an older commit than the head;
2. every review thread is resolved;
3. the same bot's latest review of the head is an approval or a 👍.

A repository may ship a script for this (PACE-2: `tools/agent/dismiss_stale_bot_reviews.py`). Prefer it over hand dismissal.

## Watcher

One Monitor over `watch.sh`, `timeout_ms: 1800000`, re-armed on every expiry until every PR has merged, closed, or been handed over. Add each PR to `prs.txt` as it opens. `watch.sh` stays quiet on the user's own account (agents reply as the user), on Bugbot notices, and on Codex summary edits that change no status. It labels a review on an older commit as superseded.

## Merge queue

Queue a PR only when the user asked for it in this session. A PR is ready when all of these hold:

- every check passes on the head;
- every thread is resolved;
- Codex code and security reviews are complete on the head;
- Cursor's latest review of the head is a pass;
- no current CHANGES_REQUESTED remains.

Enqueue with GraphQL `enqueuePullRequest(input:{pullRequestId, expectedHeadOid})`, so that a push after the check cannot slip in. `mergeStateStatus: CLEAN` before enqueue is the final gate.
