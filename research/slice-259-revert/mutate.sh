#!/bin/bash
# Slice 259 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each step is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all; `base` runs the unchanged mirror). Tests: L2 of the affected groups (T). No L0 (no L0 test calls ClosureIndex.dropped or dropped_groups).
# A mutant is one or two literal text replacements in one file (each must occur exactly once, else "DID NOT APPLY").
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-259-mut
. $ROOT/scripts/env.sh
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf "$M" && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="registry/of registry/yf registry/su9 registry/oc7"
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
run() { # name file old new [old2 new2]
  n=$1; f=$2; shift 2
  want $n || return
  d=$M/m-$n; rm -rf "$d"; cp -r $M/mut "$d"
  rep $d/$f "$@" || { echo "$n: DID NOT APPLY"; rm -rf "$d"; return; }
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; tail -5 $d/build.log; rm -rf "$d"; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh $T 2>&1 | summ)"
  rm -rf "$d"
}
if want base; then
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $T 2>&1 | summ)"
fi
PF=cli/lib/PickFlow.roc; CI=cli/lib/ClosureIndex.roc
# m1 the group match compares the form only (the series is ignored: the old total of the name)
run m1 $PF 'y.groups.keep_if(|g| g.form == s.variable.group.form and g.series == s.variable.group.series)' 'y.groups.keep_if(|g| g.form == s.variable.group.form)'
# m2 an any_series slot uses the group filter too
run m2 $PF 'Ok(s) if !s.any_series => y.groups' 'Ok(s) => y.groups'
# m3 the group match compares the series only (another URL form of the same series counts)
run m3 $PF 'y.groups.keep_if(|g| g.form == s.variable.group.form and g.series == s.variable.group.series)' 'y.groups.keep_if(|g| g.series == s.variable.group.series)'
# m4 the R-AP1 copy (step 2 of offline!, the repository copy) gives no groups
run m4 $CI '					$dropped = $dropped.concat(if facts.filter ClosureIndex.dropped_groups({ releases: rows, artifacts: [], name: facts.name, held: facts.held }) else [])
' ''
# m5 the online path (Answer) uses the group sum of the slot too
run m5 $PF '					Answer(a) => ClosureIndex.dropped({ releases: a.answer.releases, artifacts: a.answer.artifacts, name: n, held: facts.known })' '					Answer(a) => match slot {
						Ok(s) if !s.any_series => ClosureIndex.dropped_groups({ releases: a.answer.releases, artifacts: a.answer.artifacts, name: n, held: facts.known }).keep_if(|g| g.form == s.variable.group.form and g.series == s.variable.group.series).fold(0, |sum, g| sum + g.count)
						_ => ClosureIndex.dropped({ releases: a.answer.releases, artifacts: a.answer.artifacts, name: n, held: facts.known })
					}'
rm -rf "$M"
