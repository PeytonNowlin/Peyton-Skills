# Local helpers

These helpers work in either runtime and require Python 3, Bash, `gh`, and `jq`. Invoke them from the installed skill directory; copying them is unnecessary.

For every JSON mutation, use:

```sh
python3 <skill>/scripts/coord.py <file> '<trusted Python using d>' --lock <git-common-dir>/work-issues/coordination.lock
```

All runs must pass the same absolute lock path, including mutations to their own state files. Initialize missing files by assigning `d`. Put ownership checks and the reservation update inside the same locked expression; a read followed by a separately locked write is not a reservation transaction. Expressions are trusted local code, never issue/comment text. Failed expressions leave the previous JSON intact.

`ONCE=1 bash <skill>/scripts/watch.sh <run-dir>` emits notifications for the PR numbers in `prs.txt` (one per line). State needs `repo` (`owner/name`), `login`, and `host` (defaults to github.com). Only one observer may use a run directory. `seen.txt` deduplicates notifications; it does not track completed findings. On resume, always reconcile full GitHub results regardless of seen notifications. Persist outstanding findings in state before dispatch, as required by monitoring.md.

`rv.sh <run-dir> <pr>...` is a diagnostic summary, not a readiness gate. Missing status rows or incomplete thread results require full collection. Neither helper's check summary proves automatic code and security reviews completed. The agent must collect full paginated reviews, comments, reports, and threads, and verify the head after collection.

`merged.sh <run-dir> <pr>...` records an externally merged PR and releases reservations. Invoke only after all its workers have stopped. It never merges a PR. If interrupted, rerun after reconciling GitHub and local state.

Run helper regression checks with `python3 -m unittest discover -s work-issues/tests -v` from the skill repository root. These use temporary directories and mocked GitHub responses.
