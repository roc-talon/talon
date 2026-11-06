#!/usr/bin/env bash
# Revert check of slice 107: each mutation changes the private reference (overlay/), runs W0, and the shorts W2 cases when W0 passes. It must fail one.
#   research/slice-107-revert/reference/mutate.sh [name ...]
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
. "$root/scripts/env.sh"
ROCW=$root/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
rm -rf "$here/overlay.orig"; cp -r "$here/overlay" "$here/overlay.orig"
mutate() { python3 - "$1" "$2" "$3" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p).read()
assert old in s, 'pattern not found: '+old
open(p,'w').write(s.replace(old,new,1))
PY
}
run_one() {
  name=$1
  rm -rf "$here/overlay"; cp -r "$here/overlay.orig" "$here/overlay"
  S=$here/overlay/lib/Shorts.roc; R=$here/overlay/ShortRoutes.roc
  case $name in
    strip-twice)    mutate $S 'repo.drop_prefix("roc-")]' 'repo.drop_prefix("roc-").drop_prefix("roc-")]' ;;
    missing-out)    mutate $S 'and r.first_log_index.is_ok())' 'and r.first_log_index.is_ok() and r.state != 1)' ;;
    first-end)      mutate $S 'first_log_index: if (end_first < first) end_first else first' 'first_log_index: end_first' ;;
    moved-keep)     mutate $S 'if state == Moved {' 'if state == Moved and Bool.False {' ;;
    chain-3)        mutate $S 'links < 4 and' 'links < 3 and' ;;
    no-dedup)       mutate $S 'Ok(prev) if prev.name == it.name =>' 'Ok(prev) if prev.name == it.name and Bool.False =>' ;;
    unsorted)       mutate $S 'sorted = items.sort_with(|a, b| Artifact.compare(a.name, b.name))' 'sorted = items' ;;
    first-max)      mutate $R 'SELECT min(r.log_index) FROM releases r WHERE r.repo = p.repo) AS first_log_index FROM (SELECT DISTINCT' 'SELECT max(r.log_index) FROM releases r WHERE r.repo = p.repo) AS first_log_index FROM (SELECT DISTINCT' ;;
    q-repeat)       mutate $S 'searches.len() > 1' 'searches.len() > 2' ;;
    rank-rev)       mutate $S 'if (ra < rb) Before else if (ra > rb) After' 'if (ra > rb) Before else if (ra < rb) After' ;;
  esac
  "$here/mk-ref.sh"
  w0=$(cd "$here/worker" && "$ROCW" test tests/unit/w0.roc --no-cache 2>&1 | grep -a "ShortsTest.roc" | wc -l)
  w2="not run"
  if [ "$w0" = 0 ] || [ -n "${ALWAYS_W2:-}" ]; then w2=$("$here/run-ref.sh" shorts 2>&1 | grep -a "^w2:\|^FAIL" | tr '\n' ' '); fi
  echo "$name: W0 ShortsTest failures: $w0; W2: $w2"
}
names=${*:-strip-twice missing-out first-end moved-keep chain-3 no-dedup unsorted first-max q-repeat rank-rev}
for n in $names; do run_one "$n"; done
rm -rf "$here/overlay"; mv "$here/overlay.orig" "$here/overlay"; "$here/mk-ref.sh"
