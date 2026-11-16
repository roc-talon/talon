#!/bin/bash
# Slice 250 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). Tests: the l0-1 driver, L2 `registry/ update/ install/ add/ x/ patch/ index/ tool/`. L0F restricts the L0 files; L2=0 skips L2.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-250-mut
. $ROOT/scripts/env.sh   # ROC: the CLI compiler (ROC_TAG)
ROC=${ROC250:-$ROC}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="registry/ update/ install/ add/ x/ patch/ index/ tool/"
l0() { # dir: runs l0-1; prints one summary
  local d=$1 out="" f
  # L0F: the files to run (default all). exit=124 is the 600 s limit (a loop counts as caught).
  for f in ${L0F:-tests/unit/l0-1.roc}; do
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
CI=cli/lib/ClosureIndex.roc; FN=cli/lib/FullName.roc; PK=cli/lib/Pick.roc; PF=cli/lib/PickFlow.roc; PX=cli/lib/PickIndex.roc; XC=cli/lib/XCmd.roc; PA=cli/lib/PatchApply.roc
# q1 live: a held yanked row stays without the hash matching
run q1a $CI 's/ and k.hash == ident.hash)/)/'
# q1b live: ... without the version matching
run q1b $CI 's/k.group.form == ident.group.form and k.version == ident.version and/k.group.form == ident.group.form and/'
# q1c live: ... without the URL form matching
run q1c $CI 's/k.group.form == ident.group.form and k.version == ident.version/k.version == ident.version/'
# q2 live drops nothing (the filter is off)
run q2 $CI 's/if !row.yanked {/if Bool.True {/'
# q3 dropped: the count is one too high
run q3 $CI 's/all.len() - kept.len()$/all.len() - kept.len() + 1/'
# q4 with_yanked: a count of 0 still prints ", 0 yanked"
run q4 $PK 's/if facts.yanked == 0 {/if Bool.False {/'
# q5 with_yanked: the total does not count the yanked rows
run q5 $PK 's/(n + facts.yanked).to_str()/n.to_str()/'
# q6 the offline count is lost (0)
run q6 $PF 's/Offline(_) => facts.yanked.find_first(.*$/Offline(_) => 0/'
# q7 closure_item falls back to the yanked rows for a version or a range
run q7 $FN 's/pool = if live.is_empty() and !named kept else live/pool = if live.is_empty() kept else live/'
# q8 each_yanked_check also fires with a selector
run q8 $PF '/^each_yanked_check = /,/^}/ s/_ => Bool.False/_ => Bool.True/'
# q9 the close versions of no_match include the yanked releases
run q9 $PF 's/releases.releases.keep_if(|r| !r.yanked).map(|r| r.version)/releases.releases.map(|r| r.version)/'
# q10 reuse_note prints the no-data note with a registry
run q10 $XC 's/Registry => Err(None)/Registry => Ok(no_data)/'
# q11 patch: the held URL is not given to the index
run q11 $PA 's/\[x.name\], \[x.entry.url\])?/[x.name], [])?/'
# q12 each_yanked_check: a withdrawn row is not "yanked" (only yanked counts)
run q12 $PF 's/rows.all(|r| r.yanked or r.withdrawn != Err(None))/rows.all(|r| r.yanked)/'
# q13 index!: the held URLs are not given to live for an answer (a header value on a yanked row is dropped)
run q13 $PX 's/ClosureIndex.live({ releases: a.answer.releases, held: known })/ClosureIndex.live({ releases: a.answer.releases, held: [] })/'
# q14 index!: the held URLs are not given to a kept copy (offline)
run q14 $PX 's/forms: forms_of(name, known), held: known })?/forms: forms_of(name, known), held: [] })?/'
rm -rf $M
