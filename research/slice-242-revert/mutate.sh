#!/bin/bash
# Slice 242 mutation check (test agent). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s).
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-242-revert
M=$ROOT/.tmp/slice-242-mut
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
echo "base L2: $(cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 >/dev/null 2>&1; cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh channels/ch12 channels/ch13 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
X=cli/lib/ChannelCmd.roc; C=cli/lib/Channel.roc
both() { n=$1; f=$2; e=$3; shift 3; l0 $n $f "$e" l0-9.roc; l2 $n $f "$e" "$@"; }
T="channels/ch12 channels/ch13"
# m1: the conflict (19) is after --offline (15): the order of the local checks
both m1 $X '/match Channel.source_conflict/,/^\t}/ { s/Err(Conflict(recorded)) => return Err(/Err(Conflict(recorded)) if !args.offline => return Err(/; s/Ok({}) => {}/_ => {}/ }' $T
# m2: the same source is not "already added": the flow goes on to the network
both m2 $X '/Same => {/,/Other(existing)/ s/return Ok({})/{}/' $T
# m3: the prefix derivation counts drafts and prereleases (Q618)
both m3 $X 's/tags = listed.keep_if(|(_, skipped)| !skipped).map(|(tag, _)| tag)/tags = listed.map(|(tag, _)| tag)/' $T
# m4: an invalid derived prefix counts
both m4 $C 's/ and Channel.tag_prefix_check(prefix).is_ok() => Ok(prefix)/ => Ok(prefix)/' $T
# m5: more than page 1
both m5 $X 's/offline: Bool.False, pages: 1 })/offline: Bool.False, pages: 3 })/' $T
# m6, m7: --tag-prefix allowed for rm / for list
both m6 $X '/^\tno_prefix_flag(args, "rm")?$/d' $T
both m7 $X '/^\tno_prefix_flag(args, "list")?$/d' $T
# m8: add <name>, an unequal table is not exit 19
both m8 $X 's/^\t\t\t\tErr(fail) => Err(fail)$/\t\t\t\tErr(fail) => Ok({})/' $T
# m9, m10: rm of a built-in / of a name with no table in config.toml goes on
both m9 $X 's/^\t\tBuiltin => return Err(.*$/\t\tBuiltin => {}/' $T
both m10 $X 's/^\t\tMissing => return Err(.*$/\t\tMissing => {}/' $T
# m11: roc list has no (channel removed) mark
both m11 cli/lib/Manage.roc 's/Ok(if u.removed "${text} (channel removed)" else text)/Ok(text)/' $T
# m12: list shows a project-only table as added
both m12 $C 's/from: "talon.toml (not added)", origin: "project"/from: "config.toml", origin: "config"/' $T
# m13: the conflict check does not read the recorded source
both m13 $X 's/Ok((_, JsonDoc.Text(source))) => Ok(source)/Ok((_, JsonDoc.Text(source))) => Err(Unset)/' $T
# m14: another source is not refused (existing table)
both m14 $X 's/^\t\tOther(existing) => return Err(.*$/\t\tOther(_) => {}/' $T
# m15: page 1 with no build is not refused (Q618)
both m15 $X 's/return Err(Fail.new(Usage, Channel.no_build_text(run.source)))/{}/' $T
rm -rf $M
