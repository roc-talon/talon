#!/bin/bash
# Slice 244 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s). One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). L0=0 skips the l0-9 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-244-mut
. $ROOT/scripts/env.sh
ROC=${ROC244:-$HOME/.cache/roc/toolchains/nightly-2026-11-06-34f137a/roc}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="audit/"
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
AC=cli/lib/AuditCheck.roc; AF=cli/lib/AuditFlow.roc; AR=cli/lib/AuditReport.roc
# 1 R-AU13: a repo that is missing (by state) loses to release-missing
run a1 $AC 's/withdrawn == Ok("repo-missing") or state == Ok(Missing)/withdrawn == Ok("repo-missing") or (state == Ok(Missing) and withdrawn == Err(None))/'
# 1b R-AU13: yanked is not first (asset-replaced wins)
run a1b $AC 's/^\t\tif facts.row.yanked {/\t\tif facts.row.yanked and withdrawn != Ok("asset-replaced") {/'
# 2 the release of an entry is matched by hash only
run a2 $AC 's/r.hash == e.hash and r.group == e.group and r.version == e.version/r.hash == e.hash/'
# 2b matched by hash and version, not the URL form
run a2b $AC 's/r.hash == e.hash and r.group == e.group and r.version == e.version/r.hash == e.hash and r.version == e.version/'
# 3 ignore: the name is case-sensitive
run a3a $AC 's/p.name.with_ascii_lowercased() == f.entry.name.with_ascii_lowercased()/p.name == f.entry.name/'
# 3 ignore: the reason is not compared
run a3b $AC 's/ and p.reason == AuditReport.reason_text(f.reason)//'
# 3 ignore: the version is not compared
run a3c $AC 's/ and p.version == f.entry.version and p.reason/ and p.reason/'
# 4 exit 21 also for an ignored failing finding
run a4a $AC 's/f.ignored == Err(None) and AuditReport.fails(f.reason)/AuditReport.fails(f.reason)/'
# 4 exit 21 also for a warning that is not ignored
run a4b $AC 's/f.ignored == Err(None) and AuditReport.fails(f.reason)/f.ignored == Err(None)/'
# 5 via: only the alias of the row, not every header alias that reaches it
run a5 $AC 's/header_aliases(f.walked, f.row.id).fold(acc/[f.row.alias].fold(acc/'
# 6 one entry for each hash: the same hash of 2 members is 2 entries
run a6a $AC 's/if acc.contains(f.hash) acc else acc.append(f.hash)/acc.append(f.hash)/'
# 6 unused: the same item twice is listed twice
run a6b $AC 's/if acc.contains(i) acc else acc.append(i)/acc.append(i)/'
# 7 the tool hash is not in the query
run a7a $AF 's/\.concat(tools.map(|t| t.url))//'
# 7 the tool hash is not checked (no tool entry)
run a7b $AC 's/for t in tool_rows {/for t in tool_rows.keep_if(|_| Bool.False) {/'
# 8 checked counts an unindexed entry
run a8 $AC 's/Err(NotIndexed) => { ..acc, unindexed: acc.unindexed.append(entry) }/Err(NotIndexed) => { ..acc, checked: acc.checked + 1, unindexed: acc.unindexed.append(entry) }/'
# 9 a snapshot hides releases in audit (the walk gets Bool.True)
run a9 $AF 's/Ls.walk_loaded!(fx, { ..read, request }, Bool.False)/Ls.walk_loaded!(fx, { ..read, request }, Bool.True)/'
# 10 the flag is checked after the read of the project
run a10a $AF '/opts = AuditCheck.read(args)?/{h;d};/read = Ls.load_full!/{G}'
# 10 the talon.toml items are read after the query
run a10b $AF '/from_toml = root_items(read)?/{h;d};/^\trequest = /{G}'
# 10 --offline is accepted
run a10c $AF 's/if args.offline return/if Bool.False return/'
# the talon.toml items are not read
run a11 $AF 's/from_toml = root_items(read)?/from_toml = []/'
rm -rf $M
