#!/bin/bash
# Slice 230 mutation check (manager). Each mutation gets its own mirror of cli/lib and tests/unit, then `roc test` of the named driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-230-revert
. $ROOT/scripts/env.sh
rm -rf $R/mut && mkdir -p $R/mut/cli $R/mut/tests $R/mut/packages
cp -r $ROOT/cli/lib $R/mut/cli/ && cp -r $ROOT/packages/records $ROOT/packages/resolve $R/mut/packages/ && cp -r $ROOT/tests/unit $R/mut/tests/ && mkdir -p $R/mut/worker && cp $ROOT/worker/wrangler.toml $R/mut/worker/ && { [ -d $ROOT/tests/fixtures ] && cp -r $ROOT/tests/fixtures $R/mut/tests/ || true; }
run() { # name file sed-expr driver
  n=$1; f=$2; e=$3; drv=$4
  d=$R/m-$n; rm -rf $d; cp -r $R/mut $d
  sed -i "$e" $d/$f
  if cmp -s $R/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  out=$("$ROC" test $d/tests/unit/$drv 2>&1 | grep -E "passed|failed|errors" | tail -3 | tr "\n" " ")
  echo "$n: $out"
}
# m0: the unchanged mirror must pass both drivers
for drv in l0-6.roc l0-3.roc; do echo "base $drv: $("$ROC" test $R/mut/tests/unit/$drv 2>&1 | grep -E "passed|failed|errors" | tail -3 | tr "\n" " ")"; done
# m1: one tools.json writer keeps an old literal format (the F9 risk)
run m1 cli/lib/BinRecord.roc 's/TalonFile.render({ format: ToolsJson.format,/TalonFile.render({ format: 2,/' l0-6.roc
# m2: the .talon.json reader of Link accepts a newer format
run m2 cli/lib/Link.roc 's/newest: TalonFile.record_format,/newest: TalonFile.record_format + 1,/' l0-6.roc
# m3: one manifest writer keeps an old literal format
run m3 cli/lib/XCache.roc '0,/format: TalonFile.manifest_format,/s//format: 2,/' l0-6.roc
# m4: the registry compiler list reader accepts a newer format
run m4 cli/lib/RegistryToolchains.roc 's/if n > format.to_i64_wrap() {/if n > format.to_i64_wrap() + 1 {/' l0-3.roc
rm -rf $R/mut $R/m-*
