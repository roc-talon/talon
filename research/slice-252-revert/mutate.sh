#!/bin/bash
# Slice 252 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). Tests: the l0-4 driver, L2 `registry/ update/ upgrade/ outdated/`. L0F restricts the L0 files; L2=0 skips L2.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-252-mut
. $ROOT/scripts/env.sh   # ROC: the CLI compiler (ROC_TAG)
ROC=${ROC252:-$ROC}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="registry/ update/ upgrade/ outdated/"
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
  sed -i "$e" $d/$f
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
SU=cli/lib/Successor.roc; SF=cli/lib/SuccessorFlow.roc; RB=cli/lib/ResolveBase.roc; OU=cli/lib/Outdated.roc
# s1 decide: a run with no named alias follows too
run s1 $SU 's/if facts.named {/if Bool.True {/'
# s2 decide: an item with no successor follows too
run s2 $SU 's/match item.successor {/match Ok(item.name) {/'
# s3 walk: the limit is 5 links (off by one)
run s3 $SU 's/if \$links >= 4 {/if $links >= 5 {/'
# s4 walk: the names are case sensitive
run s4 $SU 's/find_first(|p| p.name.with_ascii_lowercased() == name)/find_first(|p| p.name == name)/'
# s5 walk: a cycle is not detected
run s5 $SU 's/} else if \$seen.contains(next) {/} else if Bool.False {/'
# s6 check: a followed slot that kept its old value does not stop the command
run s6 $SF 's/Ok(f) => Err(SuccessorFlow.no_release(f))/Ok(_) => Ok({})/'
# s7 read!: --offline with no kept copy does not stop (exit 15)
run s7 $SF 's/^\tgot = FullName.read_via!(\(.*\))?$/\tgot = FullName.read_via!(\1) ?? NoMatch/'
# s8 outdated: a moved row at the newest release is not shown
run s8 $OU 's/Outdated.behind(row) or Outdated.successor_of(row, moved).is_ok()/Outdated.behind(row)/'
# s9 outdated --json: the successor member is always there (null)
run s9 $OU 's/Err(None) => \[\]$/Err(None) => [("successor", JsonDoc.Null)]/'
# s10 set_edits: the old repo name is not named
run s10 $RB 's/from = name_of(u.url)/from = to/'
# s11 upgrade does not follow
run s11 $SF 's/Update | Upgrade => Bool.True/Update => Bool.True\n\t\tUpgrade => Bool.False/'
# s12 the followed variable loses its series
run s12 $SF 's/group: { form, series: s.variable.group.series }/group: { form, series: "" }/'
# s13 a missing start with a successor does not follow (state not forced to moved)
run s13 $SF 's/{ ..p, state: Moved } else p/{ ..p, state: p.state } else p/'
rm -rf $M
