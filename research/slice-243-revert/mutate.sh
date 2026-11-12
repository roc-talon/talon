#!/bin/bash
# Slice 243 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s). One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). L0=0 skips the l0-9 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-243-mut
. $ROOT/scripts/env.sh
ROC=${ROC243:-$HOME/.cache/roc/toolchains/nightly-2026-11-06-34f137a/roc}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="channels/ gc/ upgrade/ roc/"
run() { # name file sed-expr
  n=$1; f=$2; e=$3
  want $n || return
  d=$M/m-$n; rm -rf $d; cp -r $M/mut $d
  sed -i "$e" $d/$f
  if cmp -s $M/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  if [ "${L0:-1}" = 1 ]; then
    cap "$ROC" test $d/tests/unit/l0-9.roc > $d/l0.log 2>&1
    echo "$n: L0 exit=$? $(grep -E 'passed|failed|errors' $d/l0.log | tail -2 | tr '\n' ' ')"
  fi
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; rm -rf $d; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh $T 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
  rm -rf $d
}
if want base; then
  [ "${L0:-1}" = 1 ] && { cap "$ROC" test $M/mut/tests/unit/l0-9.roc > $M/base.log 2>&1; echo "base l0-9: exit=$? $(grep -E 'passed|failed|errors' $M/base.log | tail -2 | tr '\n' ' ')"; }
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $T 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
fi
P=cli/lib/Pin.roc; CH=cli/lib/Channel.roc; MG=cli/lib/Manage.roc; RU=cli/lib/RocUse.roc; RM=cli/lib/RocManage.roc; GC=cli/lib/Gc.roc; CG=cli/lib/CacheGc.roc; RI=cli/lib/RocInstall.roc
# C1: an existing =<user id> / >=<user id> pin stops `roc use` (it must be replaced)
run c1a $P 's/if !replaced and !Pin.admits/if !Pin.admits/'
# C1: another range does not stop `roc use`
run c1b $P 's/if !replaced and !Pin.admits/if Bool.False and !Pin.admits/'
# C2: an empty [toolchain] stays after the key goes
run c2 $CH 's/if empty Ok(Set(without_table_header/if Bool.False Ok(Set(without_table_header/'
# C3: moving to another channel keeps [channels.<old>]
run c3a $CH 's/dropped = if old_channel != "" and old_channel != facts.table.name {/dropped = if Bool.False {/'
# C3: back to a nightly keeps [channels.<name>]
run c3b $CH 's/dropped = without_table(facts.text, channel_of_range(range))/dropped = facts.text/'
# C5: a missing talon.toml is an error, not created
run c5 $RU 's/Err(NotFound) if is_toml => ""/Err(NotFound) if Bool.False => ""/'
# U1: roc update <user name> with an unset default moves the default
run u1a $MG '/update_move_to = /,/^\t}/ s/Err(Unset) => Stay/Err(Unset) => Move/'
# U1: roc update <user name> with a nightly or release default moves the default
run u1b $MG '/update_move_to = /,/^\t}/ s/Err(_) => Stay/Err(_) => Move/'
# R-RU2: the default moves to a build of another channel
run ru2 $MG 's/Ok(old) => if old.name == new.name Move else Stay/Ok(old) => Move/'
# R-RU2: a user default moves to a new nightly
run ru2b $MG 's/Ok(current) if Channel.user_parts(current).is_ok() => Stay/Ok(current) if Channel.user_parts(current).is_err() => Stay/'
# R1: the next default of a removed user default is any build (another channel, a nightly)
run r1a $MG 's/same = |id| id != facts.removed and Channel.user_order(id, facts.removed, facts.times).is_ok()/same = |id| id != facts.removed/'
# R1: no note when the default is unset
run r1b $RM '/match Manage.unset_note/,/Err(None) => {}/ s/Ok(note) => fx.err!("note: ${note}\\n")/Ok(_) => {}/'
# U4: a project-only table of roc update is unknown (2), not the trust stop (19)
run u4 $RI 's/NoTable(name) => match Channel.named_ref({ text: run.text, config: run.config, project: RocInstall.project_tables!(fx, run.env) })/NoTable(name) => match Channel.named_ref({ text: run.text, config: run.config, project: [] })/'
# G1: GC ignores the pin of the root talon.toml
run g1a $GC 's/ or (facts.?pinned ?? \[\]).any(|id| Pin.same_id(id, row.id))//'
# G1: GC reads no pin from the root talon.toml
run g1b $CG 's/Ok(Exactly(id)) => Ok(id)/Ok(Exactly(id)) => Err(None)/'
# G1: GC reads the nearest talon.toml of a member, not the workspace root
run g1c $RI '/root_toml! = /,/^\t}/ s/Ok(dir) => found.walk.find_first(|d| d.dir == dir)/Ok(dir) => found.walk.find_first(|d| d.toml.is_ok())/'
# upgrade: a candidate with a new error stops the command (no next candidate)
run up1 $RU 's/Err(fail) => if fail.kind.code() == 11 {/Err(fail) => if fail.kind.code() == 9999 {/'
# upgrade: when no candidate passes, say "is the newest"
run up2 $RU 's/return Ok(Kept({ note: Err(None) }))/return Ok(Newest(run.held))/'
# upgrade: min-release-age does not hide a young build
run up3 $RU '/^\t\tallowed = /s/min_age: settings.min_age/min_age: 0/'
# upgrade: the nightly switch does not hide a user build
run up4 $RU '/^\t\tpicked = /s/nightly: settings.nightly/nightly: Bool.True/'
# upgrade: the switch is ignored in the list of candidates only (EQUIVALENT: `picked` stops first when the switch is off)
run up4b $RU '/^\t\tallowed = /s/nightly: settings.nightly/nightly: Bool.True/'
# upgrade: a project-only table is accepted (the trust stop is skipped)
run up5 $RU 's/^\t\t\tProject(t) => {$/\t\t\tProject(t) => if Bool.True { return Ok(Ok(t)) } else {/'
rm -rf $M
