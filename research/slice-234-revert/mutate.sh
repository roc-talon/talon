#!/bin/bash
# Slice 234 mutation check (manager). Each mutation gets its own mirror, a private L2 build, and the named L2 cases, or `roc test` of an l0 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-234-revert
. $ROOT/scripts/env.sh
rm -rf $R/mut && mkdir -p $R/mut/cli $R/mut/tests $R/mut/packages $R/mut/worker
cp -r $ROOT/cli/lib $R/mut/cli/ && cp -r $ROOT/bot $R/mut/ && cp -r $ROOT/packages/records $ROOT/packages/resolve $R/mut/packages/
cp -r $ROOT/tests/commands $R/mut/tests/ && rm -rf $R/mut/tests/commands/cases && cp -r $ROOT/tests/unit $R/mut/tests/ && cp $ROOT/worker/wrangler.toml $R/mut/worker/ && cp -r $ROOT/tests/fixtures $R/mut/tests/
l2() { # name file sed-expr cases...
  n=$1; f=$2; e=$3; shift 3
  d=$R/m-$n; rm -rf $d; cp -r $R/mut $d
  sed -i "$e" $d/$f
  if cmp -s $R/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  "$ROC" build $d/tests/commands/main.roc --no-cache --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: BUILD FAILED"; return; }
  echo "$n: $(cd $ROOT && L2BIN=$d/l2 tests/commands/run.sh "$@" 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
}
l0() { # name file sed-expr driver
  n=$1; f=$2; e=$3; drv=$4
  d=$R/m-$n; rm -rf $d; cp -r $R/mut $d
  sed -i "$e" $d/$f
  if cmp -s $R/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  echo "$n: $("$ROC" test $d/tests/unit/$drv 2>&1 | grep -E 'passed|failed|errors' | tail -3 | tr '\n' ' ')"
}
# m1: the record step stops on kind input again (R-TF6 before Q607)
l2 m1 cli/lib/Known.roc 's/if fail.kind != Input return Err(fail)/return Err(fail)/' proxy/pd1-record-newer proxy/pd2-record-garbage install/pd3-record-newer install/pd4-record-garbage
# m2: no warning
l2 m2 cli/lib/Known.roc '/fx.err!("warning: Talon does not record this project. ${fail.message}\\n")/d' proxy/pd1-record-newer install/pd4-record-garbage
rm -rf $R/mut $R/m-*
