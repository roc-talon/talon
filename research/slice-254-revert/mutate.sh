#!/bin/bash
# Slice 254 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all; `base` runs the unchanged mirror). Tests: the l0-5 driver, L2 `registry/oc registry/sa` and the groups that a mutant can touch (TT).
# A mutant is a literal text replacement (exactly one occurrence, else "DID NOT APPLY"), so no sed escapes.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-254-mut
. $ROOT/scripts/env.sh   # ROC: the CLI compiler (ROC_TAG)
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf "$M" && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="registry/oc registry/sa registry/yf5 registry/su registry/au7"
rep() { # file old new: replace exactly one occurrence
  OLD="$2" NEW="$3" python3 -I -c '
import os,sys
p=sys.argv[1]; s=open(p).read(); o=os.environ["OLD"]; n=os.environ["NEW"]
if s.count(o)!=1: sys.exit(1)
open(p,"w").write(s.replace(o,n))' "$1"
}
summ() { grep -E '^(FAIL|commands:)' | sed 's/^FAIL registry\//F:/' | tr '\n' ' '; }
run() { # name file old new
  n=$1; f=$2
  want $n || return
  d=$M/m-$n; rm -rf "$d"; cp -r $M/mut "$d"
  rep $d/$f "$3" "$4" || { echo "$n: DID NOT APPLY"; rm -rf "$d"; return; }
  cap "$ROC" test $d/tests/unit/l0-5.roc > $d/l0.log 2>&1
  echo "$n: L0 exit=$? $(grep -E 'passed|failed|errors' $d/l0.log | tail -3 | tr '\n' ' ')"
  cap "$ROC" build $d/tests/commands/main.roc --no-cache --opt=dev --output=$d/l2 > $d/build.log 2>&1
  [ -x $d/l2 ] || { echo "$n: L2 BUILD FAILED"; rm -rf "$d"; return; }
  echo "$n: L2 $(cd $ROOT && L2BIN=$d/l2 cap tests/commands/run.sh ${TT:-$T} 2>&1 | summ)"
  rm -rf "$d"
}
if want base; then
  cap "$ROC" test $M/mut/tests/unit/l0-5.roc > $M/base.log 2>&1; echo "base l0-5: exit=$? $(grep -E 'passed|failed|errors' $M/base.log | tail -3 | tr '\n' ' ')"
  cap "$ROC" build $M/mut/tests/commands/main.roc --no-cache --opt=dev --output=$M/base-l2 > $M/base-build.log 2>&1
  echo "base L2: $(cd $ROOT && L2BIN=$M/base-l2 cap tests/commands/run.sh $T update/ 2>&1 | summ)"
fi
ON=cli/lib/OwnerNote.roc; AR=cli/lib/AuditResolve.roc; IF=cli/lib/InstallFlow.roc; PF=cli/lib/PickFlow.roc
# m1 the same ms counts as "after" (Q254-1: `at > published_at`)
run m1 $ON 'Ok(r) => o.at <= r.published_at' 'Ok(r) => o.at < r.published_at'
# m2 the date is one day late (the day number)
run m2 $ON 'z = ms // 86400000 + 719468' 'z = ms // 86400000 + 719469'
# m3 January and February get the year of the March before (the leap-year edge)
run m3 $ON 'year = yoe + era * 400 + (if month <= 2 1 else 0)' 'year = yoe + era * 400 + (if month < 2 1 else 0)'
# m4 no dedupe of the same (alias, name) (Q254-8)
run m4 $ON 'seen = $found.any(|n| n.alias == e.alias and n.name == e.name)' 'seen = Bool.False'
# m5 no sort by alias (Q254-8)
run m5 $ON '$found.sort_with(|a, b| Text.compare(a.alias, b.alias))' '$found'
# m6 a transfer never names the owner (always "another GitHub account", Q254-3)
run m6 $ON 'Ok({ before: who, .. }) => Ok(who)' 'Ok({ before: _who, .. }) => Err(None)'
# m7 a recreate also gets the owner of the successor (Q254-3: only a transfer)
run m7 $ON 'owner = if o.action == Transfer {' 'owner = if Bool.True {'
# m8 --offline gives the note (Q254-6)
run m8 $AR 'Answer(a) if !request.offline => {' 'Answer(a) => {'
# m9 install gives the note (Q254-5)
TT="$T install/ registry/" run m9 $IF 'owners = if request.command == Install [] else' 'owners = if Bool.False [] else'
# m10 the T1 sentence also with no successor
run m10 $PF '	Err(None) => FullName.each_yanked({ name: f.name })
}' '	Err(None) => FullName.each_yanked_moved({ name: f.name, successor: "" })
}'
# m11 the T2 hint is dropped
run m11 $PF 'Ok(s) => { ..base, message: "${base.message}${FullName.successor_hint(s)}" }' 'Ok(_s) => base'
# m12 the --json member is written also when empty (T7)
TT="$T update/ registry/" run m12 $AR 'Obj(members) if !owners.is_empty() => Obj(members.append(("owner_changes", Arr(owners))))' 'Obj(members) => Obj(members.append(("owner_changes", Arr(owners))))'
# m13 an unknown header value gives no note (Q254-2)
run m13 $ON '							Err(_) => Bool.False
						}
						if !before {' '							Err(_) => Bool.True
						}
						if !before {'
# m14 another release of the answer decides, not the release of the header value (Q254-7)
run m14 $ON 'facts.releases.find_first(|r| r.hash == e.hash)' 'facts.releases.find_first(|r| r.hash != e.hash)'
rm -rf "$M"
