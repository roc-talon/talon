#!/bin/bash
# Slice 255 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each step is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all; `base` runs the unchanged mirror). Tests: L2 of the affected groups (T). No L0 (the L0 change of the slice is one text expect).
# A mutant is one or two literal text replacements in one file (each must occur exactly once, else "DID NOT APPLY").
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-255-mut
. $ROOT/scripts/env.sh
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf "$M" && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="registry/au7 update/au7 moves/ registry/sa registry/yf5 verify/ patch/"
rep() { # file old new [old2 new2]
  O1="$2" N1="$3" O2="${4:-}" N2="${5:-}" python3 -I -c '
import os,sys
p=sys.argv[1]; s=open(p).read()
for o,n in [(os.environ["O1"],os.environ["N1"]),(os.environ["O2"],os.environ["N2"])]:
    if not o: continue
    if s.count(o)!=1: sys.exit(1)
    s=s.replace(o,n)
open(p,"w").write(s)' "$1"
}
summ() { grep -E '^(FAIL|commands:)' | sed 's/^FAIL //' | tr '\n' ' '; }
run() { # name file old new [old2 new2]
  n=$1; f=$2; shift 2
  want $n || return
  d=$M/m-$n; rm -rf "$d"; cp -r $M/mut "$d"
  rep $d/$f "$@" || { echo "$n: DID NOT APPLY"; rm -rf "$d"; return; }
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; tail -5 $d/build.log; rm -rf "$d"; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh $T 2>&1 | summ)"
  rm -rf "$d"
}
if want base; then
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $T 2>&1 | summ)"
fi
IF=cli/lib/InstallFlow.roc; VF=cli/lib/VerifyFlow.roc
SHOW='	# Slice 255 (Design Q635, D1 strict): the audit lines after every step that can fail, before the lines of the files.
	AuditResolve.show!(fx, x.found_audit)
'
# n1 the audit lines before the ladder again (slice 249 place)
run n1 $IF 'settle! = |fx, request, loaded, x| {
' 'settle! = |fx, request, loaded, x| {
	AuditResolve.show!(fx, x.found_audit)
' "$SHOW" ''
# n2 the audit lines after the ladder, before the consent of the held moves (the first fix of slice 255)
run n2 $IF '	InstallWrite.confirm_moves!(fx, request, x.moves)?
' '	AuditResolve.show!(fx, x.found_audit)
	InstallWrite.confirm_moves!(fx, request, x.moves)?
' "$SHOW" ''
# n3 the audit lines after the consent, before the writes
run n3 $IF '	written = InstallWrite.write!(' '	AuditResolve.show!(fx, x.found_audit)
	written = InstallWrite.write!(' "$SHOW" ''
# n4 verify: the audit lines before Ladder.verify!
run n4 $VF '	audit = AuditResolve.warn_docs(found_audit)
' '	audit = AuditResolve.warn_docs(found_audit)
	AuditResolve.show!(fx, found_audit)
' '	# Slice 255 (Design Q635, D1 strict): the audit lines only after the whole command succeeded.
	AuditResolve.show!(fx, found_audit)
	Ok({ outcome' '	Ok({ outcome'
# n5 the lines of the files (InstallWrite.report!) are dropped
run n5 $IF '	InstallWrite.report!(fx, loaded, x.edits, x.pairs, x.renames, written)
' ''
# n6 the rebased lines of the patches (PatchApply.report!) are dropped
run n6 $IF '	PatchApply.report!(fx, x.patch)
' ''
rm -rf "$M"
