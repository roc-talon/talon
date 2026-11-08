#!/bin/bash
# Slice 232 mutation check (manager). Each mutation gets its own mirror, a private L2 build, and the named L2 cases, or `roc test` of an l0 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-232-revert
. $ROOT/scripts/env.sh
rm -rf $R/mut && mkdir -p $R/mut/cli $R/mut/tests $R/mut/packages $R/mut/worker
cp -r $ROOT/cli/lib $R/mut/cli/ && cp -r $ROOT/bot $R/mut/ && cp -r $ROOT/packages/records $ROOT/packages/resolve $R/mut/packages/
cp -r $ROOT/tests/commands $R/mut/tests/ && rm -rf $R/mut/tests/commands/cases && cp -r $ROOT/tests/unit $R/mut/tests/ && cp $ROOT/worker/wrangler.toml $R/mut/worker/
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
# m1: `tool update` with no operand gives no warning for an unknown item
l2 m1 cli/lib/ToolUpdateFlow.roc 's/Newer(n) => fx.err!("${ToolManage.newer_warning(n)}\\n")/Newer(_) => {}/' tool/tn3-newer-update-all tool/tn7-newer-only
# m2: `tool install` does not stop on an unknown item with the same key or name
l2 m2 cli/lib/ToolFlow.roc 's/Ok(n) => return Err(ToolsJson.newer_fail({ path: Roots.item(m.roots, Item.ToolsJson), item: n }))/Ok(_) => {}/' tool/tn2-newer-targets
# m3: `tool remove` does not stop on an unknown item
l2 m3 cli/lib/ToolManageFlow.roc 's/Ok(n) => return Err(ToolsJson.newer_fail({ path: tools_file, item: n }))/Ok(_) => {}/' tool/tn2-newer-targets tool/tn5-newer-kept-on-write
# m4: setup keeps the strict read of the talon entry
l2 m4 cli/lib/SetupFlow.roc 's/ToolsJson.talon_repair(/ToolsJson.talon(/g' setup/st7-talon-bad setup/st12-talon-newer-kind
# m5: "no tool is installed" also when the file has only unknown items
l2 m5 cli/lib/ToolUpdateFlow.roc 's/if machine.items.is_empty() {/if machine.tools.is_empty() {/' tool/tn7-newer-only
rm -rf $R/mut $R/m-*
