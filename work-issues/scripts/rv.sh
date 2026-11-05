#!/bin/bash
# rv.sh <run-dir> <pr>... : head, Codex status rows, each reviewer's LATEST review (by
# submitted_at), and unresolved thread count. A review on an older commit is marked old.
set -euo pipefail
W="$1"; shift; REPO=$(jq -r .repo "$W/state.json"); OWNER=${REPO%/*}; NAME=${REPO#*/}
export GH_HOST=$(jq -r '.host // "github.com"' "$W/state.json")
for p in "$@"; do
  head=$(gh pr view "$p" -R "$REPO" --json headRefOid --jq '.headRefOid[:7]')
  echo "#$p head $head"
  comments=$(gh api --paginate "repos/$REPO/issues/$p/comments" --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | .body')
  rows=$(printf '%s' "$comments" | grep -oE '\*\*(Code|Security) Review\*\* \| [^|]*\| `[0-9a-f]+`' || true)
  if [ -n "$rows" ]; then printf '  codex %s\n' "$rows"; else echo '  Codex status rows unavailable; inspect full reports'; fi
  gh api --paginate "repos/$REPO/pulls/$p/reviews" --jq '.[]' | jq -rs --arg h "$head" '
    map(select(.user.login == "chatgpt-codex-connector[bot]")) | group_by(.user.login)[] | sort_by(.submitted_at) | last |
    "  \(.user.login) \(.state) on \(.commit_id[:7])\(if .commit_id[:7] != $h then " (old)" else "" end)"'
  gh api graphql -f query="{repository(owner:\"$OWNER\",name:\"$NAME\"){pullRequest(number:$p){reviewThreads(first:100){nodes{isResolved} pageInfo{hasNextPage}}}}}" \
    --jq 'if .data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage then error("Thread list incomplete; paginate before judging readiness") else "  unresolved threads: \([.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved|not)]|length)" end'
done
