#!/bin/bash
# Slice 236 mutation check (manager). Each mutation gets its own mirror, a private L2 build, and the named L2 cases, or `roc test` of an l0 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-236-revert
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
echo "base l0-9: $("$ROC" test $R/mut/tests/unit/l0-9.roc 2>&1 | grep -E 'passed|failed|errors' | tail -3 | tr '\n' ' ')"
# m1: a prerelease tln is compared with its suffix (strict semver)
l0 m1 cli/lib/TlnGate.roc 's/version: core })/version: facts.version })/' l0-9.roc
# m2: commands and the proxy do not check the gate
l2 m2 cli/lib/Intent.roc 's/if facts.role != Member TlnGate.gate({ path: facts.path, doc })?/if Bool.False TlnGate.gate({ path: facts.path, doc })?/' gate/tf10-install gate/tf10-proxy
# m3: `tln run` does not check the gate
l2 m3 cli/lib/ScriptsToml.roc '/TlnGate.gate({ path: facts.path, doc })?/d' gate/tf10-run
# m4: a bad range has no hint line
l0 m4 cli/lib/TlnGate.roc "s/Err(BadRange) => Err(Fail.with_hint(Fail.new(Input, \"\${at}toolchain.tln: '\${range}' is not a version range\")))/Err(BadRange) => Err(Fail.new(Input, \"\${at}toolchain.tln: '\${range}' is not a version range\"))/" l0-9.roc
# m5: the gate also checks a member file (R-WS5: only the root counts)
l0 m5 cli/lib/Intent.roc 's/if facts.role != Member TlnGate.gate(/if Bool.True TlnGate.gate(/' l0-9.roc
rm -rf $R/mut $R/m-*
