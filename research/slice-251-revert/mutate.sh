#!/bin/bash
# Slice 251 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). Tests: the l0-4 driver, L2 `move/ yank/ publish/`. L0F restricts the L0 files; L2=0 skips L2.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-251-mut
. $ROOT/scripts/env.sh   # ROC: the CLI compiler (ROC_TAG)
ROC=${ROC251:-$ROC}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="move/ yank/ publish/"
l0() { # dir: runs l0-4; prints one summary
  local d=$1 out="" f
  # L0F: the files to run (default all). exit=124 is the 600 s limit (a loop counts as caught).
  for f in ${L0F:-tests/unit/l0-4.roc}; do
    cap "$ROC" test $d/$f > $d/l0-$(basename $f).log 2>&1
    rc=$?
    out="$out $(basename $f .roc): exit=$rc $(grep -E 'passed|failed|errors' $d/l0-$(basename $f).log | tail -1 | sed 's/ in .*//')$([ $rc -ge 124 ] && tail -2 $d/l0-$(basename $f).log | tr '\n' ' ')."
  done
  echo "$out"
}
run() { # name file sed-expr
  n=$1; f=$2; e=$3
  want $n || return
  d=$M/m-$n; rm -rf $d; cp -r $M/mut $d
  if [ "${e#PY:}" != "$e" ]; then PYE="${e#PY:}" python3 -I $ROOT/research/slice-251-revert/pyrep.py $d/$f; else sed -i "$e" $d/$f; fi
  [ -n "${4:-}" ] && { sed -i "$5" $d/$4; cmp -s $M/mut/$4 $d/$4 && { echo "$n: SED2 DID NOT APPLY"; return; }; }
  if cmp -s $M/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  echo "$n: L0$(l0 $d)"
  [ "${L2:-1}" = 1 ] || { rm -rf $d; return; }
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; rm -rf $d; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh $T 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
  rm -rf $d
}
if want base && [ "${L2:-1}" = 1 ]; then
  echo "base: L0$(l0 $M/mut)"
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $T 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
fi
MC=cli/lib/MoveCheck.roc; MF=cli/lib/MoveFlow.roc
# v1 order: the job is checked before the value of --to (a second job line is put before the --to name check)
run v1 $MF 'PY:\tto = match to_text {@@@\tjob = MoveCheck.job(env)?\n\tto = match to_text {'
# v2 order: the OIDC variables are checked before the job
run v2 $MF 'PY:\tjob = MoveCheck.job(env)?@@@\toidc = MoveCheck.oidc(env)?\n\tjob = MoveCheck.job(env)?'
# v3 plan: the old name's job with --to sets (no offer)
run v3 $MC 's/Ok(Offer(target))/Ok(Set(target))/'
# v4 plan: another job with --to different from itself is accepted
run v4 $MC 's/} else if who == target {/} else if Bool.True {/'
# v5 holder: --undo from any job is accepted
run v5 $MC 's/Successor(s) => if s == who {/Successor(s) => if Bool.True {/'
# v6 an offer reads R-AP1 too (Q251-4: none for an offer)
run v6 $MF 's/Offer(_) => Unknown/Offer(_) if Bool.False => Unknown/'
# v7 the privacy guard also asks for --undo (R-MV3: none)
run v7 $MC 's/Remove => \[\]/Remove => ["acme\/guard-test"]/'
# v8 unchanged for a set: the status 200 is not needed
run v8 $MC 's/if input.status == 200 and item.successor == Ok(s) Unchanged/if item.successor == Ok(s) Unchanged/'
# v8b unchanged for a removal: always when there was no successor
run v8b $MC 's/NoSuccessor => if input.status == 200 Unchanged else Removed/NoSuccessor => Unchanged/'
# v9 a 404 read gives NoSuccessor (so a removal is "unchanged")
run v9 $MC 'PY:\t\tif input.status == 404 {\n\t\t\tOk(Unknown)@@@\t\tif input.status == 404 {\n\t\t\tOk(NoSuccessor)'
# v10 a 202 is not Done (goes to Publish.next)
run v10 $MF 's/Ok(answer) if answer.status == 202 => Done/Ok(answer) if Bool.False => Done/'
# v11 the old name keeps its case
run v11 $MC '0,/Ok({ owner: owner.with_ascii_lowercased(), repo: repo.with_ascii_lowercased() })/s//Ok({ owner: owner, repo: repo })/'
# v12 repository-changed gets the generic refusal text
run v12 $MC 's/IssuesUrl(url) if body.type_text == Problem.type_uri(RepositoryChanged) =>/IssuesUrl(url) if Bool.False =>/'
# v13 the "may be done" word of an offer is "move"
run v13 $MC 's/Offer(_) => "offer"/Offer(_) => "move"/'
rm -rf $M
