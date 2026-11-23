#!/bin/bash
# Slice 260 mutation check (test agent, TW12, Design Q639: the age of a cached GitHub release list page uses the real clock, not TALON_NOW).
# Mirror under .tmp/ (not /tmp). Each build and run is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time. No OPT=speed.
# Usage: mutate.sh [names...]   (no argument: base and all mutants). Tests: the L2 cases of T and the L3 case tools/tx1-x-run.
# A mutant is one literal text replacement in one file (it must occur exactly once, else "DID NOT APPLY").
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-260-mut
. $ROOT/scripts/env.sh
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf "$M" && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp $ROOT/cli/*.roc $M/mut/cli/ && cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
# L2: the gap cases of this slice (gc260) and the old cases of the touched flows.
T="${T:-upgrade/ur10 upgrade/ur11 audit/ad17 registry/ad35-add upgrade/ur3 upgrade/ur4 upgrade/ug6 outdated/od1 init/it1 tool/ts1 audit/ad1}"
L3="tools/tx1-x-run"
rep() { # file old new
  O1="$2" N1="$3" python3 -I -c '
import os,sys
p=sys.argv[1]; s=open(p).read(); o=os.environ["O1"]; n=os.environ["N1"]
if s.count(o)!=1: sys.exit(1)
open(p,"w").write(s.replace(o,n))' "$1"
}
summ() { grep -E '^(FAIL|commands:|scenarios:)' | sed 's/^FAIL //' | tr '\n' ' '; }
test_dir() { # name dir
  local n=$1 d=$2
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build-l2.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; tail -5 $d/build-l2.log; return; }
  mkdir -p $d/bin; cap "$ROC" build $d/cli/main.roc --no-cache --opt=dev --output=$d/bin/tln > $d/build-tln.log 2>&1
  [ -x $d/bin/tln ] || { echo "$n: TLN BUILD FAILED"; tail -5 $d/build-tln.log; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh $T 2>&1 | summ)"
  echo "$n: L3 $(cd $ROOT && TLN=$d/bin/tln JOBS=1 cap tests/run.sh $L3 2>&1 | summ)"
}
run() { # name file old new
  local n=$1 f=$2; shift 2
  want $n || return
  local d=$M/m-$n; rm -rf "$d"; cp -r $M/mut "$d"
  rep $d/$f "$@" || { echo "$n: DID NOT APPLY"; rm -rf "$d"; return; }
  test_dir $n $d
  rm -rf "$d"
}
if want base; then test_dir base $M/mut; fi
# m1 ToolFlow (tool install, x): the release list of a tool uses TALON_NOW again
run m1 cli/lib/ToolFlow.roc 'owner, repo, now: facts.?real ?? facts.now, offline: args.offline })?' 'owner, repo, now: facts.now, offline: args.offline })?'
# m2 PickIndex (the package lists of install, update, upgrade, outdated, probe): TALON_NOW
run m2 cli/lib/PickIndex.roc 'owner, repo, now: request.?real ?? request.now, offline: request.offline })?' 'owner, repo, now: request.now, offline: request.offline })?'
# m3 FullName.read_real! (the GitHub read behind a registry full name): `now` (the registry clock), not `real`
run m3 cli/lib/FullName.roc 'owner, repo, now: facts.real, offline: facts.offline })?' 'owner, repo, now: facts.now, offline: facts.offline })?'
# m4 NightlyFlow (the compiler list of upgrade): TALON_NOW for the nightlies list
run m4 cli/lib/NightlyFlow.roc 'now: request.?real ?? request.now, offline: request.offline, host, source: ResolveBase.list_first(request) })?' 'now: request.now, offline: request.offline, host, source: ResolveBase.list_first(request) })?'
# m5 Install.begin_loose! (install, add, update): real is TALON_NOW
run m5 cli/lib/Install.roc 'real: times.real, cwd,' 'real: now, cwd,'
# m6 AuditFlow (audit direct): TALON_NOW
run m6 cli/lib/AuditFlow.roc 'repo: r.repo, now: request.?real ?? request.now })?' 'repo: r.repo, now: request.now })?'
rm -rf "$M"
