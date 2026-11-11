#!/bin/bash
# Slice 238 mutation check (manager). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s).
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-241-revert
M=$ROOT/.tmp/slice-241-mut
. $ROOT/scripts/env.sh
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/packages $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages/records $ROOT/packages/resolve $M/mut/packages/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
sum() { grep -E 'passed|failed|errors|^FAIL|commands:|\[FAIL\]|FAIL ' | tail -${1:-6} | tr '\n' ' '; }
l2() { # name file sed-expr cases...
  n=$1; f=$2; e=$3; shift 3
  d=$M/m-$n; rm -rf $d; cp -r $M/mut $d
  sed -i "$e" $d/$f
  if cmp -s $M/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: BUILD FAILED"; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh "$@" 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
}
l0() { # name file sed-expr driver
  [ "${L0:-1}" = 1 ] || return
  n=$1; f=$2; e=$3; drv=$4
  d=$M/m-$n; rm -rf $d; cp -r $M/mut $d
  sed -i "$e" $d/$f
  if cmp -s $M/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  cap "$ROC" test $d/tests/unit/$drv > $d/l0.log 2>&1
  echo "$n: L0 exit=$? $(grep -E 'passed|failed|errors|FAIL|expect' $d/l0.log | head -8 | tr '\n' ' ')"
}
[ "${L0:-1}" = 1 ] && { cap "$ROC" test $M/mut/tests/unit/l0-9.roc > $M/base.log 2>&1; echo "base l0-9: exit=$? $(grep -E 'passed|failed|errors' $M/base.log | tail -3 | tr '\n' ' ')"; }
echo "base L2: $(cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 >/dev/null 2>&1; cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh channels 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
P=cli/lib/Pin.roc; C=cli/lib/Channel.roc; I=cli/lib/RocInstall.roc
# L0 and L2 both for a mutant that has tests in both layers: name file sed cases...
both() { n=$1; f=$2; e=$3; shift 3; l0 $n $f "$e" l0-9.roc; l2 $n $f "$e" "$@"; }
both m1 $P 's/Any => Channel.user_parts(facts.id).is_err()/Any => Bool.True/' channels/ch07
both m2 $P 's/and Channel.user_parts(facts.id).is_err() and Ranges.admits/and Ranges.admits/' channels/ch07
both m3 $C 's/(Ok(x), Ok(y)) if x.name == y.name => {/(Ok(x), Ok(y)) => {/' channels/ch07
both m4 cli/lib/Compiler.roc 's/(facts.nightly or !Pin.counts_as_nightly(id))/(facts.nightly or !Pin.is_nightly(id))/' channels/ch07
both m5 $I 's/base = if named_step {/base = if Bool.False {/' channels/ch08
both m6 $C 's/if facts.text == "nightly" {/if facts.text == "nightly-x" {/' channels/ch08
both m7 $C 's/Ok(Latest) | Ok(Step(_)) => Bool.True/Ok(_) => Bool.True/' channels/ch08
both m8 $C 's/Config(_) => if facts.project.any(|t| t.name == name) {/Config(_) => if Bool.False {/' channels/ch07
both m9 $C '/_ if held => Free/d' channels/ch07
both m10 cli/lib/Proxy.roc 's/^\tif !early {/\tif Bool.False {/' channels/ch07
both m11 cli/lib/ResolveSelect.roc '/^\tpin_trust!(fx, loaded, lists)?$/d' channels/ch06 channels/ch07
both m12 $I 's/^\t\tif user_table.is_ok() {/\t\tif Bool.False {/' channels/ch07
both m13 $I 's/GithubChannel(_) => Kept$/GithubChannel(_) => match set_default!(fx, ctx.roots, ctx.id) {\n\t\t\t\t\tOk(kind) => kind\n\t\t\t\t\tErr(fail) => return Err(fail)\n\t\t\t\t}/' channels
both m14 cli/lib/Nightlies.roc 's/(Bool.True, _) if Channel.user_parts(text).is_ok() =>/(Bool.True, _) if Bool.False =>/' channels/ch07 channels/ch08
rm -rf $M
