#!/bin/bash
# Slice 238 mutation check (manager). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s).
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-238-revert
M=$ROOT/.tmp/slice-238-mut
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
[ "${L0:-1}" = 1 ] && cap "$ROC" test $M/mut/tests/unit/l0-9.roc > $M/base.log 2>&1; echo "base l0-9: exit=$? $(grep -E 'passed|failed|errors' $M/base.log | tail -3 | tr '\n' ' ')"
echo "base L2: $(cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 >/dev/null 2>&1; cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh channels 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
L=cli/lib/Channel.roc
l0 m1 $L 's/bytes.len() <= 24/bytes.len() <= 25/' l0-9.roc
l0 m2 $L "s/Ok(b) => b != '-'/Ok(b) => b != '_'/" l0-9.roc
l0 m3 $L 's/"debug", "local", "compat"\]/"debug", "local"]/' l0-9.roc
l0 m4 $L 's/a.shape == b.shape and a.source == b.source and/a.shape == b.shape and/' l0-9.roc
l2 m4b $L 's/a.shape == b.shape and a.source == b.source and/a.shape == b.shape and/' channels
l0 m5 $L 's/ or message.ends_with("is not a channel name")//' l0-9.roc
l0 m6 $L 's/ or message.contains(": missing key ")//' l0-9.roc
l0 m7 cli/lib/Intent.roc 's/member_tables = \["dependencies"/member_tables = ["channels", "dependencies"/' l0-9.roc
l0 m8 $L 's/issues: not_tables(doc).concat(rows.join_map(|r| r.issues))/issues: rows.join_map(|r| r.issues)/' l0-9.roc
l0 m9 $L 's/warnings: unknown,/warnings: [],/' l0-9.roc
l0 m10 $L 's/bytes.len() >= 2 and/bytes.len() >= 1 and/' l0-9.roc
l2 m11 cli/lib/Base.roc 's/(Read, \[path\]) => match/(Given, [path]) => match/' channels
rm -rf $M
