#!/bin/bash
# Slice 244d mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s). One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). L0=0 skips the l0-9 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-244d-mut
. $ROOT/scripts/env.sh
ROC=${ROC244:-$ROC}  # the CLI compiler of scripts/env.sh (ROC_TAG)
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="audit/ update/au7 registry/au7 registry/fe10 fetch/ verify/au7"
TX="$T install/ update/ resolve/ moves/ index/"
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
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh ${TT:-$T} 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
  rm -rf $d
}
if want base; then
  [ "${L0:-1}" = 1 ] && { cap "$ROC" test $M/mut/tests/unit/l0-9.roc > $M/base.log 2>&1; echo "base l0-9: exit=$? $(grep -E 'passed|failed|errors' $M/base.log | tail -2 | tr '\n' ' ')"; }
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $TX 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
fi
AR=cli/lib/AuditReport.roc; AF=cli/lib/AuditFlow.roc; RS=cli/lib/AuditResolve.roc; WK=cli/lib/Walk.roc; FE=cli/lib/Fetch.roc; PF=cli/lib/PickFlow.roc; PI=cli/lib/PickIndex.roc; IF=cli/lib/InstallFlow.roc; VF=cli/lib/VerifyFlow.roc; AC=cli/lib/AuditCheck.roc
# d1 direct: no warning at all (the feed is cut)
run e1 $RS 's/Direct => if request.offline {/Direct => if Bool.True {/'
# d2 direct: asset-replaced with a new hash gives a line
run e2 $AC 's/if f.new_hash != Err(None) Err(None) else Ok(f)/Ok(f)/'
# d3 a leaf in every command (shared walk)
TT="$TX" run e3 $WK 's/leaf: facts.?leaf ?? Bool.False/leaf: Bool.True/'
# d4 the gone note is missing from --json
run e4 $AR 's/\.concat(not_indexed)\.concat(deps_gone)/.concat(not_indexed)/'
# d5 the gone note is missing from the human text
run e5 $AR 's/\.concat(not_checked)\.concat(gone_lines)/.concat(not_checked)/'
# d6 any status of a download makes a leaf
run e6 $FE 's/split_first(" failed: 404 (")/split_first(" (")/'
# d7 the second-search pages are dropped (held move)
TT="$TX" run e7 $PF 's/found: moved.found, moves:/found: ready.found, moves:/'
# d8 the pages of a fetched list are not kept by the pick
TT="$TX" run e8 $PI 's/pages: fetched.pages/pages: []/'
# d9 verify: the lists are not fed
TT="$TX" run e9 $VF 's/found: listed }/found: [] }/'
# d10 install/update: the lists are not fed
TT="$TX" run e10 $IF 's/found: after.found }/found: [] }/'
# d11 --offline (kept pages) prints direct warnings
run e11 $RS 's/Direct => if request.offline {/Direct => if Bool.False {/'
# d12 the gone note names the other entries
run e12 $AF 's/entries.keep_if(|e| urls.contains(e.url))/entries.keep_if(|e| !urls.contains(e.url))/'
rm -rf $M
