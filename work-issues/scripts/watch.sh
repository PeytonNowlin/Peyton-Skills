#!/bin/bash
# Notification helper for one run; full review evidence is collected by the agent.
# ONCE=1 runs a single observation. Otherwise the owning runtime must stop the loop.
set -o pipefail
W="$1"; [ -d "$W" ] || { echo "usage: watch.sh <run-dir>"; exit 2; }
REPO=$(jq -er .repo "$W/state.json") || exit 1
HOST=$(jq -r '.host // "github.com"' "$W/state.json")
export GH_HOST="$HOST"
SEEN="$W/seen.txt"; touch "$SEEN"
emit() { grep -qxF "$1" "$SEEN" || { echo "$1" >> "$SEEN"; echo "$2"; }; }
while true; do
  for p in $(cat "$W/prs.txt" 2>/dev/null); do
    st=$(gh pr view "$p" --repo "$REPO" --json state,headRefOid --jq '"\(.state) \(.headRefOid)"' 2>/dev/null) \
      || { echo "PR#$p monitoring-error: pr view failed"; continue; }
    state=${st%% *}; head=${st##* }
    [[ $state == MERGED || $state == CLOSED ]] && { emit "state:$p:$state" "PR#$p is $state"; continue; }
    reviews=$(gh api --paginate "repos/$REPO/pulls/$p/reviews" \
      --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | "\(.id)\t\(.user.login)\t\(.state)\t\(.commit_id)"' 2>/dev/null) \
      || { echo "PR#$p monitoring-error: reviews failed"; continue; }
    printf '%s\n' "$reviews" |
      while IFS=$'\t' read -r id u s c; do
        [ -n "$id" ] || continue
        tag=""; [ "$c" != "$head" ] && tag=" [superseded: older commit]"
        emit "rev:$REPO:$p:$id:$s:$c" "PR#$p review by $u: $s on $c$tag"
      done
    findings=$(gh api --paginate "repos/$REPO/pulls/$p/comments" \
      --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | "\(.id):\(.updated_at)\t\(.user.login)\t\(.path):\(.line // .original_line)\t\(.body | gsub("\n";" ") | .[:140])"' 2>/dev/null) \
      || { echo "PR#$p monitoring-error: findings failed"; continue; }
    printf '%s\n' "$findings" |
      while IFS=$'\t' read -r id u loc b; do [ -n "$id" ] || continue; emit "rc:$p:$id" "PR#$p finding by $u at $loc: $b"; done
    # Notify on changed status rows; the agent verifies their head coverage.
    comments=$(gh api --paginate "repos/$REPO/issues/$p/comments" \
      --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | .body' 2>/dev/null) \
      || { echo "PR#$p monitoring-error: conversation failed"; continue; }
    rows=$(printf '%s' "$comments" | grep -oE '\*\*(Code|Security) Review\*\* \| [^|]*\| `[0-9a-f]+`' | sort | tr '\n' ';')
    [ -n "$rows" ] && emit "codex:$p:$(printf '%s' "$rows" | shasum | cut -c1-12)" "PR#$p Codex: $rows"
    checks=$(gh pr checks "$p" --repo "$REPO" --json name,bucket 2>/dev/null)
    check_status=$?
    if [ "$check_status" -ne 0 ] && [ "$check_status" -ne 8 ]; then
      echo "PR#$p monitoring-error: checks failed"; continue
    fi
    latest=$(gh pr view "$p" --repo "$REPO" --json headRefOid --jq .headRefOid) || { echo "PR#$p monitoring-error: head refresh failed"; continue; }
    [ "$latest" = "$head" ] || { echo "PR#$p head changed during observation; refresh required"; continue; }
    printf '%s' "$checks" | jq -r '.[] | select(.bucket=="fail" or .bucket=="cancel") | "\(.name)\t\(.bucket)"' |
      while IFS=$'\t' read -r n b; do emit "chk:$p:$head:$n:$b" "PR#$p check $b: $n (head $head)"; done
    all=$(printf '%s' "$checks" | jq -r 'if length>0 and all(.bucket!="pending") then (if any(.bucket=="fail" or .bucket=="cancel") then "done-with-failures" elif all(.bucket=="pass" or .bucket=="skipping") then "completed-without-failures" else "unknown" end) else "" end')
    [ -n "$all" ] && emit "all:$p:$head:$all" "PR#$p checks $all (head $head)"
  done
  [ -n "$ONCE" ] && break  # ONCE=1: a single pass, for testing
  sleep 30
done
