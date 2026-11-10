#!/bin/bash
# Slice 238 mutation check (manager). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s).
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-240-revert
M=$ROOT/.tmp/slice-240-mut
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
echo "base L2: $(cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 >/dev/null 2>&1; cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh channels roc 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
N=cli/lib/Nightlies.roc; I=cli/lib/RocInstall.roc
l2 m1 $N 's/source_for = |source, name| if name == "nightly" source else Direct/source_for = |source, name| source/' channels
l2 m3 $I 's/project: RocInstall.project_tables!(fx, run.env) })/project: [] })/' channels
l2 m4 $I 's/Ok(id) => Ok(Installed(id))/Ok(_id) => Err(Fail.new(Usage, unknown))/' channels
l2 m5 $I 's/GithubChannel(_) => Kept$/GithubChannel(_) => match set_default!(fx, ctx.roots, ctx.id) {\n\t\t\t\t\tOk(kind) => kind\n\t\t\t\t\tErr(fail) => return Err(fail)\n\t\t\t\t}/' channels
l2 m5b $I 's/if Channel.parse_id(found.id).map_ok(|parts| parts.name != "nightly") == Ok(Bool.True) Kept else/if Bool.False Kept else/' channels
l2 m6 cli/lib/Toolchain.roc 's/Ok(c) => \[("channel", JsonDoc.Text(c.name)), ("source", JsonDoc.Text(c.source))\]/Ok(_) => []/' channels
l2 m8 $I 's/published_at: ctx.published_at }, ctx.source)$/published_at: ctx.published_at, channel: { name: "nightly", source: "roc-lang\/nightlies" } }, ctx.source)/' channels roc
l2 m9 $I 's/auto: if facts.nightly shown.map(|r| r.id) else \[\] }/auto: shown.map(|r| r.id) }/' channels
l2 m10 $I 's/min_age: facts.min_age, snapshot: Err(None), keep: \[\], exclude: facts.exclude, channels/min_age: 0, snapshot: Err(None), keep: [], exclude: facts.exclude, channels/' channels
l2 m15 $I 's/(Empty, Ok(table)) if !facts.switch.nightly =>/(Empty, Ok(table)) if Bool.False =>/' channels
l0 m13 cli/lib/Channel.roc 's/ and !text.to_utf8().all(is_hex)//' l0-9.roc
l0 m16 cli/lib/Channel.roc 's/(Ok(Config(t)), _) => Latest(t)/(Ok(Project(t)), _) => ProjectOnly(t)\n\t\t\t(Ok(Config(t)), _) => Latest(t)/' l0-9.roc
rm -rf $M
