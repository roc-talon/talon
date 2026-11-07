#!/bin/bash
# Slice 226 mutation check (manager). Each mutation gets its own mirror, a private build, and the named cases.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-226-revert
. $ROOT/scripts/env.sh
rm -rf $R/mut && mkdir -p $R/mut/cli $R/mut/tests $R/mut/packages
cp -r $ROOT/cli/lib $R/mut/cli/ && cp -r $ROOT/bot $R/mut/ && cp -r $ROOT/packages/records $ROOT/packages/resolve $R/mut/packages/
cp -r $ROOT/tests/commands $R/mut/tests/ && rm -rf $R/mut/tests/commands/cases && cp -r $ROOT/tests/unit $R/mut/tests/
run() { # name file sed-expr cases...
  n=$1; f=$2; e=$3; shift 3
  d=$R/m-$n; rm -rf $d; cp -r $R/mut $d
  sed -i "$e" $d/$f
  if cmp -s $R/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  "$ROC" build $d/tests/commands/main.roc --no-cache --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: BUILD FAILED"; return; }
  echo "$n: $(cd $ROOT && L2BIN=$d/l2 tests/commands/run.sh "$@" 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
}
# m1: a bundle falls back to the no-project path on any search failure (a bad talon.toml too)
run m1 cli/lib/ProbeFlow.roc 's/if plan.range or !fail.no_project Err(fail)/if plan.range Err(fail)/' probe/pb3-bundle-no-project
# m2: "no project file found" is not marked, so a bundle never falls back
run m2 cli/lib/Project.roc 's/, no_project: Bool.True })/, no_project: Bool.False })/' probe/pb3-bundle-no-project
# m3: the no-project path ignores ROC_TOOLCHAIN (R-SO2 rank 2)
run m3 cli/lib/ProbeFlow.roc 's/argument: Err(Unset), env: toolchain,/argument: Err(Unset), env: Err(Unset),/' probe/pb3-bundle-no-project probe/sm1-url-targets probe/sm2-json-order
