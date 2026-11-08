#!/bin/bash
# Slice 231 mutation check (manager). Each mutation gets its own mirror, a private L2 build, and the named L2 cases, or `roc test` of an l0 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-231-revert
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
echo "base l0-9: $("$ROC" test $R/mut/tests/unit/l0-9.roc 2>&1 | grep -E 'passed|failed|errors' | tail -3 | tr '\n' ' ')"
# m1: the hint helper adds nothing
l2 m1 cli/lib/Fail.roc 's/message: "${fail.message}\\n${Fail.newer_hint}"/message: fail.message/' resolve/th1-config-unknown-value resolve/th2-talon-unknown-value
# m2: `tool update talon` reads config.toml strictly
l2 m2 cli/lib/TalonUpdateFlow.roc 's/ToolManageFlow.machine_lenient!(fx)/ToolManageFlow.machine!(fx)/' tool/th3-self-update-bad-config
# m3: text that is not TOML also gets the hint
l0 m3 cli/lib/ConfigToml.roc 's/Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))/Err(TomlErr(e)) => Err(Fail.with_hint(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML")))/' l0-9.roc
# m4: the bad registry text of config.toml has no hint
l2 m4 cli/lib/IndexQuery.roc 's/return Err(Fail.with_hint(Fail.new(Input, "${c.at}: registry: \(.*\)")))/return Err(Fail.new(Input, "${c.at}: registry: \1"))/' registry/cv1-proxy-range-bad-registry
# m5: the lenient read drops the warnings of the bad values (it still unsets them)
l0 m5 cli/lib/ConfigToml.roc 's/warnings: shown(facts.path, ignored.concat(found.warnings)) }/warnings: shown(facts.path, found.warnings) }/' l0-9.roc
rm -rf $R/mut $R/m-*
