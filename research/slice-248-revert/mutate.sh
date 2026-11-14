#!/bin/bash
# Slice 248 mutation check (test agent, TW12). Mirror under .tmp/ (not /tmp). Each run is capped (16G, no swap, 600 s) and holds the shared heavy lock. One mutant at a time.
# Usage: mutate.sh [mutant names...]   (no argument: all). Tests: l0-2 driver, the 4 packages/resolve tests, L2 `upgrade/ur9 probe/ resolve/`. The l0-9 driver is not used (packages/records of another session does not compile).
set -u
ROOT=/home/george/dev/Karakatiza666/talon
M=$ROOT/.tmp/slice-248-mut
. $ROOT/scripts/env.sh   # ROC: the CLI compiler (ROC_TAG)
export TMPDIR=$ROOT/.tmp/tmp; mkdir -p $TMPDIR
cap() { flock $ROOT/.tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 "$@"; }
rm -rf $M && mkdir -p $M/mut/cli $M/mut/tests $M/mut/worker
cp -r $ROOT/cli/lib $M/mut/cli/ && cp -r $ROOT/bot $M/mut/ && cp -r $ROOT/packages $M/mut/
cp -r $ROOT/tests/commands $M/mut/tests/ && rm -rf $M/mut/tests/commands/cases && cp -r $ROOT/tests/unit $M/mut/tests/ && cp $ROOT/worker/wrangler.toml $M/mut/worker/ && cp -r $ROOT/tests/fixtures $M/mut/tests/
WANT=" $* "
want() { [ $# -eq 0 ] || [ "$WANT" = "  " ] || case "$WANT" in *" $1 "*) return 0;; *) return 1;; esac; }
T="upgrade/ur9 probe/ resolve/"
l0() { # dir: runs l0-2 and the resolve package tests; prints one summary
  local d=$1 out="" f
  # L0F: the files to run (default all). exit=124 is the 600 s limit (a loop counts as caught).
  for f in ${L0F:-tests/unit/l0-2.roc packages/resolve/tests/conflicts.roc packages/resolve/tests/domain.roc packages/resolve/tests/moves.roc packages/resolve/tests/solver.roc}; do
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
EX=cli/lib/Explain.roc; OC=cli/lib/OracleCause.roc; SO=packages/resolve/Solver.roc; SB=packages/resolve/SolverBase.roc; SW=packages/resolve/SolverWhy.roc; OR=cli/lib/OracleRequest.roc
# M1 a run of H alone gets a cause line
run m1 $EX 's/ or c.from != x.held)/ or Bool.True)/'
# M2 B11 reverted: a run of one compiler that is not H gets no line
run m2 $EX 's/ or c.from != x.held)/)/'
# M3 B12 reverted: the kind of a fault from the row of H, not of p.from
run m3 $OC 's/OracleDomain.row_of(compat.checks, p.from, p.id)/OracleDomain.row_of(compat.checks, compat.compiler ?? "", p.id)/'
# M4 var_of keeps a candidate whose version does not parse
run m4 $SO 's/vals: fits.keep_oks(|c| Semver.parse(c.version).map_ok(|v| { c, ver: Ok(v) }))/vals: fits.map(|c| { c, ver: Semver.parse(c.version).map_err(|_| NoVer) })/'
# M5 var_of: the compiler slot in the order of D for both strategies
run m5 $SO 's/ordered = if req.rules.strategy == Highest req.compat.domain.rev() else req.compat.domain/ordered = req.compat.domain/'
# M6 asks_of: probes together with the missing headers
run m6 $SO 's/^\t\theads.map(|id| Header(id))$/\t\theads.map(|id| Header(id)).concat(if compat.probes == Allowed SolverBase.dedupe(rels).map(|id| Probe({ id, nightly: "" })) else [])/'
# M7 pf_incs: R-C3 with 2 or more platform slots
run m7 $SO 's/(Ok(url), \[pl\]) =>/(Ok(url), [pl, .. as _rest]) =>/'
# M8 request_of: drop same_group
run m8 $OR 's/conflicts: same_group(slots).concat(given(compat.conflicts))/conflicts: given(compat.conflicts)/'
# M9 norm keeps a term that holds all values of its slot
run m9 $SB 's/Ok(joined.keep_if(|l| l.set.len() != (sizes.get(l.v) ?? 0)).sort_with/Ok(joined.sort_with/'
# M10 B8 reverted: terms in the order of the search
run m10 $SW 's/terms: row.lits.map(|l| (order.get(l.v) ?? l.v, term_of(vars, l))).sort_with(|p, q| p.0.order_relative_to(q.0)).map(|p| p.1),/terms: row.lits.map(|l| term_of(vars, l)),/'
# M11 blame_text: a fault gives (no module is named)
run m11 $OC 's/Hang => "hangs"/Hang => "no module is named"/; s/Crash => "crashes"/Crash => "no module is named"/'
# M12 the ids of a term are reversed (a strategy order instead of the order of the search)
run m12 $SW 's/ids: l.set.keep_oks(/ids: l.set.rev().keep_oks(/'
rm -rf $M
