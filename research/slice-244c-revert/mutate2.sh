#!/bin/bash
# Slice 244c mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s). One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). L0=0 skips the l0-9 driver.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-244c-mut
. $ROOT/scripts/env.sh
ROC=${ROC244:-$HOME/.cache/roc/toolchains/nightly-2026-11-06-34f137a/roc}
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="audit/ registry/au7-install-warnings registry/fe10-install-404"
TX="audit/ registry/au7 registry/fe10 install/ update/ verify/"
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
AR=cli/lib/AuditReport.roc; AC=cli/lib/AuditCheck.roc; RS=cli/lib/AuditResolve.roc
# c1 a held move: the first answer is searched before the second
run c1 $RS 's/\[other, a.answer\]/[a.answer, other]/'
# c2 resolve_findings: the last answer with the row wins, not the first
run c2 $AC '/resolve_findings = /,/^\t}/ s/\.first()/.last()/'
# c3a an ignored finding still gives a line
run c3a $AC '/resolve_findings = /,/^\t}/ s/\.findings\.keep_if(|f| f.ignored == Err(None))/.findings/'
# c3b a bad item of [audit] ignore drops all items (strict parse)
run c3b $RS 's/Ok(t) => lenient_items(t.text)/Ok(t) => AuditCheck.toml_items({ path: t.path, text: t.text }) ?? []/'
# c4 moved of a header entry with a successor: no R-PU28 line (the warning form)
run c4 $AR '/(Moved, Header(alias), Ok(to), Bool.False) =>/d'
# c5 direct: asset-replaced with a new hash gives a line
run c5 $AC 's/if f.new_hash != Err(None) Err(None) else Ok(f)/Ok(f)/'
# c6 the warnings go to stdout, not stderr
run c6 $RS 's/fx.err!("warning: /fx.out!("warning: /'
# c7 404 text for any reason (a prerelease too)
run c7 $AR 's/^\t\t\t\t\t_ => Err(None)$/\t\t\t\t\t_ => Ok("it changed")/'
# c8 a transitive entry with an unknown via gets the fix of a project tool
run c8 $AR 's/base = "update the package that needs it (tln why ${f.entry.why}), or use \[overrides\]"/base = "tln update --tool ${f.entry.edge}"/'
# c9 moved gets a fix again (before P3)
run c9 $AR '/if f.reason == Moved and !from_p3({}) return ""/d'
# c10 the fix: line lists a finding that does not fail (successor)
run c10 $AR 's/AuditReport.fails(f.reason) or (from_p3({}) and f.successor != Err(None))/AuditReport.fails(f.reason) or f.successor != Err(None) or f.reason == Prerelease/'
# c11 --json: an empty audit_warnings is added to every run (leak into runs with no finding)
TT="$TX" run c11 $RS 's/if !found.audit.is_empty() => Obj/if Bool.True => Obj/'
rm -rf $M
