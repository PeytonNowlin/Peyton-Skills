#!/bin/bash
# rv.sh <run-dir> <pr>... : head, Codex status rows, each reviewer's LATEST review (by
# submitted_at), and unresolved thread count. A review on an older commit is marked old.
W="$1"; shift; REPO=$(jq -r .repo "$W/state.json"); OWNER=${REPO%/*}; NAME=${REPO#*/}
for p in "$@"; do
  head=$(gh pr view "$p" -R "$REPO" --json headRefOid --jq '.headRefOid[:7]')
  echo "#$p head $head"
  gh api "repos/$REPO/issues/$p/comments" --jq '.[] | select(.user.login|test("codex")) | .body' |
    grep -oE '\*\*(Code|Security) Review\*\* \| [^|]*\| `[0-9a-f]+`' | sed -E 's/<[^>]*>[^<]*<\/[^>]*>//g; s/^/  codex /'
  gh api --paginate "repos/$REPO/pulls/$p/reviews" --jq '.[]' | jq -rs --arg h "$head" '
    group_by(.user.login)[] | sort_by(.submitted_at) | last |
    "  \(.user.login) \(.state)\(if (.user.login=="cursor[bot]" and (.body|test("👍"))) then " 👍" else "" end) on \(.commit_id[:7])\(if .commit_id[:7] != $h then " (old)" else "" end)"'
  gh api graphql -f query="{repository(owner:\"$OWNER\",name:\"$NAME\"){pullRequest(number:$p){reviewThreads(first:100){nodes{isResolved}}}}}" \
    --jq '"  unresolved threads: \([.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved|not)]|length)"'
done
