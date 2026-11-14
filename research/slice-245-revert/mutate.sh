#!/bin/bash
# Slice 245 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s). One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). L0=0 skips the l0-3 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-245-mut
. $ROOT/scripts/env.sh
ROC=${ROC244:-$ROC}  # the CLI compiler of scripts/env.sh (ROC_TAG)
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="roc/gi channels/ch08"
TX="$T"
run() { # name file sed-expr
  n=$1; f=$2; e=$3
  want $n || return
  d=$M/m-$n; rm -rf $d; cp -r $M/mut $d
  sed -i "$e" $d/$f
  if cmp -s $M/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  if [ "${L0:-1}" = 1 ]; then
    cap "$ROC" test $d/tests/unit/l0-3.roc > $d/l0.log 2>&1
    echo "$n: L0 exit=$? $(grep -E 'passed|failed|errors' $d/l0.log | tail -2 | tr '\n' ' ')"
  fi
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; rm -rf $d; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh ${TT:-$T} 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
  rm -rf $d
}
if want base; then
  [ "${L0:-1}" = 1 ] && { cap "$ROC" test $M/mut/tests/unit/l0-3.roc > $M/base.log 2>&1; echo "base l0-3: exit=$? $(grep -E 'passed|failed|errors' $M/base.log | tail -2 | tr '\n' ' ')"; }
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $TX 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
fi
GR=cli/lib/GitRef.roc; SE=cli/lib/Selector.roc
# M1 git_source: a form that is not Full (deadbeef, github.com/..., a name with no owner) is accepted
run m1 $GR 's/if parsed.form != Full {/if Bool.False {/'
# M2 ref_of: a name with no selector gets the ref main
run m2 $GR '/^ref_of = /,$ s/_ => Err(NoRef)/_ => Ok("main")/'
# M3 sha_source: a bare hex word with no @ is read as @<word>
run m3 $GR 's/parsed = match Ref.parse(text, Scope.Roc, Bool.False) {/parsed = match Ref.parse(if text.contains("@") text else "@${text}", Scope.Roc, Bool.False) {/'
# M4 is_sha: 6 digits are enough
run m4a $SE 's/text.count_utf8_bytes() >= 7 and text.to_utf8().all(is_hex)/text.count_utf8_bytes() >= 6 and text.to_utf8().all(is_hex)/'
# M4 is_sha: 8 digits are needed
run m4b $SE 's/text.count_utf8_bytes() >= 7 and text.to_utf8().all(is_hex)/text.count_utf8_bytes() > 7 and text.to_utf8().all(is_hex)/'
# M5 read: 2 or more operands take the first one
run m5 $GR 's/many => Err(.*/many => git_source(many.first() ?? "").map_ok(|source| Ok(source))/'
# M6 sha_source: a bad selector is not a usage failure (the gi5 fix is reverted)
run m6 $GR 's/Err(fail) => return if is_repo_or_short(text) Err(fail) else Ok(Err(NotGit))/Err(_) => return Ok(Err(NotGit))/'
# M7a a nightly tag with no @ gets the old text (has no ref)
run m7a $GR 's/Ok(Nightly(tag)) if text == tag =>/Ok(Nightly(tag)) if Bool.False =>/'
# M7b every name with no @ref gets the nightly text
run m7b $GR "s/\"'\${text}' has no ref: use owner\/repo@ref or @ref\"/\"--git takes owner\/repo@ref or @ref; for a nightly use tln roc install \${text}\"/"
# M8 the short-hex stop also applies to a channel name with no / (must break channels/ch08-bad-selector)
run m8 $GR 's/return if is_repo_or_short(text) Err(fail) else Ok(Err(NotGit))/return if Bool.True Err(fail) else Ok(Err(NotGit))/'
rm -rf $M
