#!/bin/bash
# merged.sh <run-dir> <pr>... : after a verified merge, mark it merged in state.json,
# drop it from prs.txt, and release its reservations.
W="$1"; shift; C="$(dirname "$W")"
for p in "$@"; do
  [ "$(gh pr view "$p" -R "$(jq -r .repo "$W/state.json")" --json state --jq .state)" = MERGED ] || { echo "#$p not merged; skipped"; continue; }
  sed -i '' "/^$p\$/d" "$W/prs.txt" 2>/dev/null || sed -i "/^$p\$/d" "$W/prs.txt"
  python3 "$W/coord.py" "$W/state.json" "[x for x in d['prs'] if x['number']==$p][0]['state']='merged'"
  python3 "$W/coord.py" "$C/reservations.json" "
for x in d:
  if x.get('pr')==$p and str(x.get('status','')).startswith('active'): x['status']='released (PR $p merged)'"
  echo "#$p released"
done
