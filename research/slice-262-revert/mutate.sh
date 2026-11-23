#!/bin/bash
# Slice 262 mutation check (test agent, TW12, Design Q642, G-C272): 8 mutants of the tricky decisions of 262a and 262b (mutants.py).
# Mirror under .tmp/slice-262-mut (not /tmp). Each build and run is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time. No OPT=speed.
# Each mutant runs only its L0 driver(s) and its L2 cases (no full sweep). A mutant is killed when a test fails. "base" (no change) must pass, else the result means nothing.
# Usage: research/slice-262-revert/mutate.sh [names...]   (no argument: base and all mutants). The result lines go to stdout; RESULT.md is written by hand from them.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
HERE=$ROOT/research/slice-262-revert
M=$ROOT/.tmp/slice-262-mut
. $ROOT/scripts/env.sh
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf "$M" && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp $ROOT/cli/*.roc $M/mut/cli/ && cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
# The L0 drivers and the L2 cases of each mutant.
declare -A L0 L2
HELP="help/hp1 help/hp2 help/hp3 channels/ch12 channels/ch13 gaps/g1-slice009"
L0[m1-table-not-first]=5;            L2[m1-table-not-first]="$HELP"
L0[m2-limit-length-off-by-one]=5;    L2[m2-limit-length-off-by-one]="$HELP"
L0[m3-ignore-not-repeatable]=5;      L2[m3-ignore-not-repeatable]="$HELP audit/"
L0[m4-repeat-before-not-for]=5;      L2[m4-repeat-before-not-for]="$HELP"
L0[m5-anchor-note-for-upgrade]=5;    L2[m5-anchor-note-for-upgrade]="upgrade/ closure/cl2 workspace/ws1 moves/hm registry/sp24 registry/au7 registry/ap30"
L0[m6-held-line-for-override]=2;     L2[m6-held-line-for-override]="upgrade/ update/ closure/cl2 workspace/ws1 remove/rm1 resolve/rs-unmanaged ladder/ld-ladder probe/dm1 probe/lp1"
L0[m7-pinned-mark-not-behind]=1;     L2[m7-pinned-mark-not-behind]="outdated/"
L0[m8-line-b-with-roc-toolchain]=9;  L2[m8-line-b-with-roc-toolchain]="roc/up share/sh62 channels/ch15 registry/rg9-toolchains registry/ix6-roc"
summ() { grep -E '^(FAIL|commands:)' | sed 's/^FAIL //' | tr '\n' ' '; }
test_dir() { # name dir drivers cases
  local n=$1 d=$2 drivers=$3 cases=$4 k out
  for k in $drivers; do
    out=$(cd $d && cap "$ROC" test tests/unit/l0-$k.roc 2>&1)
    if echo "$out" | grep -qE 'All \([0-9]+\) tests passed'; then echo "$n: L0 l0-$k passed"; else echo "$n: L0 l0-$k FAILED: $(echo "$out" | grep -oE '[0-9]+ failed' | head -1) $(echo "$out" | grep -E '^(-- |── )' | sort | uniq -c | head -3 | tr '\n' ' ')"; fi
  done
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build-l2.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; tail -5 $d/build-l2.log; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh $cases 2>&1 | summ)"
}
if want base; then test_dir base $M/mut "1 2 5 9" "$HELP audit/ upgrade/ update/ outdated/ roc/up closure/cl2 workspace/ws1 moves/hm registry/sp24 registry/au7 registry/ap30 remove/rm1 resolve/rs-unmanaged ladder/ld-ladder probe/dm1 probe/lp1 share/sh62 channels/ch15 registry/rg9-toolchains registry/ix6-roc"; fi
for n in $(python3 $HERE/mutants.py --list); do
  want $n || continue
  d=$M/m-$n; rm -rf "$d"; cp -r $M/mut "$d"
  python3 $HERE/mutants.py $n $d || { echo "$n: DID NOT APPLY"; rm -rf "$d"; continue; }
  test_dir $n $d "${L0[$n]}" "${L2[$n]}"
  rm -rf "$d"
done
rm -rf "$M"
