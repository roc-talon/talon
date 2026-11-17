#!/bin/bash
# Slice 253 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). Tests: the l0-4 driver, L2 `publish/ move/`. L0F restricts the L0 files; L2=0 skips L2.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-253-mut
. $ROOT/scripts/env.sh   # ROC: the CLI compiler (ROC_TAG)
ROC=${ROC253:-$ROC}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="publish/ move/"
l0() { # dir: runs l0-4; prints one summary
  local d=$1 out="" f
  # L0F: the files to run (default all). exit=124 is the 600 s limit (a loop counts as caught).
  for f in ${L0F:-tests/unit/l0-6.roc tests/unit/l0-4.roc}; do
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
  _once() { if [ "${2#PY:}" != "$2" ]; then PYE="${2#PY:}" python3 -I $ROOT/research/slice-253-revert/pyrep.py $1; else sed -i "$2" $1; fi; }
  _once $d/$f "$e"; [ -n "${4:-}" ] && _once $d/$4 "$5"
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
RG=cli/lib/Registry.roc; PU=cli/lib/Publish.roc
# w1 operator_text ignores the type: any problem with issues_url gets the text
run w1 $RG 's/IssuesUrl(url) if body.type_text == Problem.type_uri(RepositoryChanged) => {/IssuesUrl(url) => {/'
# w2 operator_text with no issues_url still gives a text
run w2 $RG '/operator_text = /,/^\t}/ s/^\t\t_ => Err(None)$/\t\t_ => if body.type_text == Problem.type_uri(RepositoryChanged) Ok("${body.detail}. Only the registry operator can change this.") else Err(None)/'
# w3 Publish.failure calls operator_text before `forbidden` (alone: the type check of operator_text keeps the types apart)
run w3 $PU 'PY:\t\t\t\t\t} else if type == "/errors/forbidden" {@@@\t\t\t\t\t} else if Registry.operator_text(body).is_ok() {\n\t\t\t\t\t\tRegistry.operator_text(body)\n\t\t\t\t\t} else if type == "/errors/forbidden" {'
# w3b the same, and operator_text has no type check: a forbidden with issues_url gets the operator text
run w3b $PU 'PY:\t\t\t\t\t} else if type == "/errors/forbidden" {@@@\t\t\t\t\t} else if Registry.operator_text(body).is_ok() {\n\t\t\t\t\t\tRegistry.operator_text(body)\n\t\t\t\t\t} else if type == "/errors/forbidden" {' $RG 's/IssuesUrl(url) if body.type_text == Problem.type_uri(RepositoryChanged) => {/IssuesUrl(url) => {/'
# w4 the message drops the issues_url
run w4 $RG 's/Open an issue: ${url}")/Open an issue.")/'
rm -rf $M
