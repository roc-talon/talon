#!/bin/bash
# Slice 238 mutation check (manager). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s).
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-239-revert
M=$ROOT/.tmp/slice-239-mut
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
if [ "${L2BASE:-1}" = 1 ]; then
echo "base L2: $(cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 >/dev/null 2>&1; cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh install roc tool channels 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
fi
C=cli/lib/Channel.roc
l0 m1 $C 's/{ names: name == "nightly" }/{ names: Bool.True }/' l0-9.roc
l0 m2 $C 's/name.starts_with("${word}-"))/name.starts_with(word))/' l0-9.roc
l0 m3 $C 's/bytes.len() <= 40 and/bytes.len() <= 41 and/' l0-9.roc
l0 m4 $C "s/bytes.first() != Ok('.') and //" l0-9.roc
l0 m5 $C 's/ and !repo.ends_with(".git")//' l0-9.roc
l0 m6 $C "s/bytes.last() == Ok('-') and //" l0-9.roc
l0 m7 cli/lib/Pin.roc 's/Pin.is_nightly(id) or Channel.parse_id(id).is_ok()/Pin.is_nightly(id)/' l0-9.roc
l0 m8 cli/lib/ClosureRequest.roc 's/and (Pin.is_nightly(r.id) or !Pin.counts_as_nightly(r.id))/and Bool.True/' l0-9.roc
l0 m9 cli/lib/Age.roc 's/Ok(table) => Ok(table.source)/Ok(table) => match facts.recorded { Ok(s) => Ok(s), Err(_) => Ok(table.source) }/' l0-9.roc
l0 m11 cli/lib/Nightlies.roc 's/else Ok("${facts.name}-${facts.tag.drop_prefix(facts.tag_prefix)}")/else Ok(facts.tag)/' l0-9.roc
l0 m12 cli/lib/Manage.roc 's/} else if Pin.counts_as_nightly(id) {/} else if Pin.is_nightly(id) {/' l0-9.roc
l0 m13 cli/lib/TalonRemove.roc 's/} else if Pin.counts_as_nightly(id) {/} else if Bool.False {/' l0-9.roc
l0 m14 cli/lib/Toolchain.roc 's/!Pin.counts_as_nightly(r.id)/!Pin.is_nightly(r.id)/' l0-9.roc
l0 m15 cli/lib/Pin.roc 's/if Pin.counts_as_nightly(facts.id) and !facts.nightly/if Pin.is_nightly(facts.id) and !facts.nightly/' l0-9.roc
l2 m10 cli/lib/Nightlies.roc 's/"roc_${facts.tag_prefix}${Nightlies.target/"roc_x${facts.tag_prefix}${Nightlies.target/' install roc
l2 m13b cli/lib/TalonRemove.roc 's/} else if Pin.counts_as_nightly(id) {/} else if Bool.False {/' tool remove
rm -rf $M
