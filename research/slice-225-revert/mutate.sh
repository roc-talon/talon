#!/bin/bash
# Slice 225 mutation check (manager). Each mutation gets its own mirror, a private build, and the named cases.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-225-revert
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
# m1: a registry that the user set also falls back
run m1 cli/lib/Registry.roc 's/if source == Help.default_source {/if Bool.True {/' registry/rg9-set-down
# m2: a 4xx (429) also stops as a 5xx, so the default falls back on it
run m2 cli/lib/Registry.roc 's/stops = status >= 500 and/stops = status >= 400 and/' registry/rg9-closure-429
# m3: a later full-name read also falls back (first request only)
run m3 cli/lib/PickFlow.roc '213s/if !first or !\$items.is_empty() return Err(fail)/if Bool.False return Err(fail)/' registry/rg9-later-down
# m4: a fall back of the compiler list does not route the run to direct
run m4 cli/lib/ResolveBase.roc 's/Ok(f) => { ..request, registry: Fell(f), index: Direct }/Ok(_) => request/' registry/rg9-list-then-closure registry/rg9-upgrade-list-then-closure
# m5: registry-only commands get the direct fix sentence
run m5 cli/lib/Registry.roc 's/stop_text = |facts| if facts.needs {/stop_text = |facts| if Bool.False {/' registry/rg9-logout-down share/sh27-login-no-answer
