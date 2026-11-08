#!/bin/bash
# Slice 233 mutation check (manager). Each mutation gets its own mirror, a private L2 build, and the named L2 cases, or `roc test` of an l0 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-233-revert
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
echo "base l0-4: $("$ROC" test $R/mut/tests/unit/l0-4.roc 2>&1 | grep -E 'passed|failed|errors' | tail -3 | tr '\n' ' ')"
# m1: `put` drops the unknown keys of the entry
l0 m1 cli/lib/ToolsToml.roc 's/Dict.from_list(new_fields.concat(old_keys(doc, facts.key)))/Dict.from_list(new_fields)/' l0-4.roc
l2 m1b cli/lib/ToolsToml.roc 's/Dict.from_list(new_fields.concat(old_keys(doc, facts.key)))/Dict.from_list(new_fields)/' ptool/pt16-keep-subkey ptool/pt15-keep-unknown
# m2: `put` keeps the `bin` table at a new url
l0 m2 cli/lib/ToolsToml.roc '/Value.Boolean(_) => Bool.True/{n;s/_ => Bool.False/_ => Bool.True/}' l0-4.roc
# m3: `put_bin` drops the unknown `bin` keys
l2 m3 cli/lib/ToolsToml.roc 's/bin_value(facts.bin, unknown)/bin_value(facts.bin, [])/' ptool/pt15-keep-unknown
# m4: no warning for an unknown `bin` target
l0 m4 cli/lib/ToolsToml.roc 's/warnings: unknown.concat(bin_warnings) }/warnings: unknown }/' l0-4.roc
rm -rf $R/mut $R/m-*
