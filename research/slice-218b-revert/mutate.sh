#!/bin/bash
# Slice 218b mutation check (manager). Each mutation gets its own mirror (cli/lib, bot, packages, tests/commands, tests/unit), a private build, and the named cases.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-218b-revert
. $ROOT/scripts/env.sh
rm -rf $R/mut && mkdir -p $R/mut/cli $R/mut/tests $R/mut/packages
cp -r $ROOT/cli/lib $R/mut/cli/ && cp -r $ROOT/bot $R/mut/ && cp -r $ROOT/packages/records $ROOT/packages/resolve $R/mut/packages/
cp -r $ROOT/tests/commands $R/mut/tests/ && rm -rf $R/mut/tests/commands/cases && cp -r $ROOT/tests/unit $R/mut/tests/
run() { # name file sed-expr cases... (l0: run l0-2)
  n=$1; f=$2; e=$3; shift 3
  d=$R/m-$n; rm -rf $d; cp -r $R/mut $d
  sed -i "$e" $d/$f
  if cmp -s $R/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  if [ "$1" = l0 ]; then
    echo "$n: l0 -> $("$ROC" test $d/tests/unit/l0-2.roc 2>&1 | tail -3 | tr '\n' ' ')"; return
  fi
  "$ROC" build $d/tests/commands/main.roc --no-cache --output=$d/l2 > $d/build.log 2>&1 || { echo "$n: BUILD FAILED"; return; }
  echo "$n: $(cd $ROOT && L2BIN=$d/l2 tests/commands/run.sh "$@" 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
}
run s1 cli/lib/ProbeSmoke.roc 's/if found.contains(name) found else/if Bool.False found else/' l0 &
run s2 cli/lib/ProbeSmokeFlow.roc '112s/result: NoSmokeApp/result: Machine/' probe/sm7-no-smoke-app &
wait
run s3 cli/lib/ProbeSmokeFlow.roc '200s/NoFact => Bool.True/NoFact => Bool.False/' probe/sm6-no-fact &
run s4 cli/lib/ProbeSmokeFlow.roc 's/if rows.is_empty() return Ok({})/if Bool.False return Ok({})/' probe/sm6-no-fact probe/sm7-no-smoke-app &
wait
