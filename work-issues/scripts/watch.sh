#!/bin/bash
# One watcher over a run's PRs. Emits only lines worth acting on: new bot reviews and
# inline findings (a review on an older commit is labelled superseded), Codex status
# changes, failed checks, all-green, merges and closes. Quiet on the user's own
# account (agents reply as the user), Bugbot notices, and Codex edits that change no status.
# USE: Monitor command `watch.sh <run-dir>`; PR numbers live in <run-dir>/prs.txt.
W="$1"; [ -d "$W" ] || { echo "usage: watch.sh <run-dir>"; exit 2; }
REPO=$(jq -r .repo "$W/state.json"); ME=$(jq -r .login "$W/state.json")
SEEN="$W/seen.txt"; touch "$SEEN"
emit() { grep -qxF "$1" "$SEEN" || { echo "$1" >> "$SEEN"; echo "$2"; }; }
while true; do
  for p in $(cat "$W/prs.txt" 2>/dev/null); do
    st=$(gh pr view "$p" --repo "$REPO" --json state,headRefOid --jq '"\(.state) \(.headRefOid[:8])"' 2>/dev/null) \
      || { echo "PR#$p monitoring-error: pr view failed"; continue; }
    state=${st%% *}; head=${st##* }
    [[ $state == MERGED || $state == CLOSED ]] && { emit "state:$p:$state" "PR#$p is $state"; continue; }
    gh api --paginate "repos/$REPO/pulls/$p/reviews" \
      --jq ".[] | select(.user.login != \"$ME\") | \"\(.id)\t\(.user.login)\t\(.state)\t\(.commit_id[:8])\t\(.user.login == \"cursor[bot]\" and (.body | test(\"👍\")))\"" 2>/dev/null |
      while IFS=$'\t' read -r id u s c up; do
        tag=""; [ "$c" != "$head" ] && tag=" [superseded: older commit]"
        [ "$up" = true ] && s="$s 👍"
        emit "rev:$p:$id" "PR#$p review by $u: $s on $c$tag"
      done
    gh api --paginate "repos/$REPO/pulls/$p/comments" \
      --jq ".[] | select(.user.login != \"$ME\" and .in_reply_to_id == null) | \"\(.id)\t\(.user.login)\t\(.path):\(.line // .original_line)\t\(.body | gsub(\"<!--[^>]*-->\";\"\") | gsub(\"\\n\";\" \") | .[:140])\"" 2>/dev/null |
      while IFS=$'\t' read -r id u loc b; do emit "rc:$p:$id" "PR#$p finding by $u at $loc: $b"; done
    # Codex: emit only when a status row changes for this head.
    rows=$(gh api --paginate "repos/$REPO/issues/$p/comments" \
      --jq '.[] | select(.user.login | test("codex")) | .body' 2>/dev/null |
      grep -oE '\*\*(Code|Security) Review\*\* \| [^|]*\| `[0-9a-f]+`' | sed -E 's/<[^>]*>[^<]*<\/[^>]*>//g; s/ +/ /g' | sort | tr '\n' ';')
    [ -n "$rows" ] && emit "codex:$p:$(printf '%s' "$rows" | shasum | cut -c1-12)" "PR#$p Codex: $rows"
    checks=$(gh pr checks "$p" --repo "$REPO" --json name,bucket 2>/dev/null) || continue
    printf '%s' "$checks" | jq -r '.[] | select(.bucket=="fail" or .bucket=="cancel") | "\(.name)\t\(.bucket)"' |
      while IFS=$'\t' read -r n b; do emit "chk:$p:$head:$n:$b" "PR#$p check $b: $n (head $head)"; done
    all=$(printf '%s' "$checks" | jq -r 'if length>0 and all(.bucket!="pending") then (if any(.bucket=="fail") then "done-with-failures" else "all-green" end) else "" end')
    [ -n "$all" ] && emit "all:$p:$head:$all" "PR#$p checks $all (head $head)"
  done
  [ -n "$ONCE" ] && break  # ONCE=1: a single pass, for testing
  sleep 90
done
