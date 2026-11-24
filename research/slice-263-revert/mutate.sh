#!/bin/bash
# Slice 263 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each step is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all; `base` runs the unchanged mirror). Tests: L2 of the groups in T, and L0 l0-5 (IndexTest) for the Index mutants.
# A mutant is one or two literal text replacements in one file (each must occur exactly once, else "DID NOT APPLY").
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-263-mut
. $ROOT/scripts/env.sh
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf "$M" && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="registry/op registry/ix6 registry/of registry/ad37 registry/sa6 registry/yf moves/hm1 resolve/rs-unmanaged fetch/ update/au7"
rep() { # file old new [old2 new2]
  O1="$2" N1="$3" O2="${4:-}" N2="${5:-}" python3 -I -c '
import os,sys
p=sys.argv[1]; s=open(p).read()
for o,n in [(os.environ["O1"],os.environ["N1"]),(os.environ["O2"],os.environ["N2"])]:
    if not o: continue
    if s.count(o)!=1: sys.exit(1)
    s=s.replace(o,n)
open(p,"w").write(s)' "$1"
}
summ() { grep -E '^(FAIL|commands:)' | sed 's/^FAIL //' | tr '\n' ' '; }
l0() { cap "$ROC" test $1/tests/unit/l0-5.roc --no-cache 2>&1 | grep -E '^\s+[0-9]+ (passed|failed)|All \(' | tr -s ' \n' ' '; }
run() { # name file old new [old2 new2]
  n=$1; f=$2; shift 2
  want $n || return
  d=$M/m-$n; rm -rf "$d"; cp -r $M/mut "$d"
  rep $d/$f "$@" || { echo "$n: DID NOT APPLY"; rm -rf "$d"; return; }
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; tail -5 $d/build.log; rm -rf "$d"; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh $T 2>&1 | summ)"
  case $f in cli/lib/Index.roc) echo "$n: L0 $(l0 $d)";; esac
  rm -rf "$d"
}
if want base; then
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $T 2>&1 | summ)"
fi
IX=cli/lib/Index.roc; PI=cli/lib/PickIndex.roc; PL=cli/lib/PickLoop.roc
# m1 newest_admitted ignores the range (the old code: the newest of the form when any candidate is admitted)
run m1 $IX 'match facts.list.keep_if(|c| Ranges.admits({ ranges: [facts.range], version: c.ident.version })) {' 'match (if facts.list.any(|c| Ranges.admits({ ranges: [facts.range], version: c.ident.version })) facts.list else []) {'
# m2 a tie on published_at takes the last one
run m2 $IX 'Ok(rest.fold(first, |best, c| if (c.published_at > best.published_at) c else best))
	}

	## The order' 'Ok(rest.fold(first, |best, c| if (c.published_at >= best.published_at) c else best))
	}

	## The order'
# m3 read_admitted! skips online too
run m3 $PI 'if request.offline and fail.missing == Ok(c.url) {' 'if fail.missing == Ok(c.url) {'
# m4 read_admitted! does not skip offline
run m4 $PI 'if request.offline and fail.missing == Ok(c.url) {' 'if Bool.False and fail.missing == Ok(c.url) {'
# m5 all skipped in add: the failure of the last skipped candidate, not the first (Q643-1)
run m5 $PI 'Ok(skipped ?? fail))' 'Ok(fail))'
# m6 all skipped in the pick loop: the failure of the last skipped candidate
run m6 $PL 'fail: all_skipped.first() ?? fail,' 'fail: all_skipped.last() ?? fail,'
# m7 the pick loop skips the current header value too
run m7 $PL ' and !input.slots.any(|s| s.current == Ok(url)) => Ok(url)' ' => Ok(url)'
# m8 read_admitted! skips any offline failure (for example an archive dir with no readable main.roc)
run m8 $PI 'if request.offline and fail.missing == Ok(c.url) {' 'if request.offline {'
# m9 outdated skips too: the offline index (used by outdated) drops a candidate with no archive (Q643-2)
run m9 $PI '					$found = $found.append({ name, list: got.list, missing: got.missing,' '					present = match fx.list_dirs!([request.roots.pkgs]) {
						[Ok(es)] => es.map(|e| e.name)
						_ => []
					}
					$found = $found.append({ name, list: got.list.keep_if(|c| present.contains(c.ident.hash)), missing: got.missing,'
# m10 the skipped candidate stays in the rows of the new name
run m10 $PI '$rows = $rows.append({ fresh: f, list: got.list })' '$rows = $rows.append({ fresh: f, list })'
# m11 the pick loop never stops early when a range has no candidate left (the solver gives its own failure)
run m11 $PL '						if left {' '						if Bool.False and left {'
rm -rf "$M"
