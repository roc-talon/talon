#!/usr/bin/env bash
# TW12 revert check of the 104k code (not the reference): each mutant edits the package file, runs roc test, and restores it.
set -u
cd "$(dirname "$0")/../../.."
. scripts/env.sh

D=packages/records
K=research/slice-104k-revert/code-check
mut() { # <label> <file> <python replace old> <new>
  python3 -c "import sys;p,o,n=sys.argv[1:];s=open(p).read();assert o in s,o;open(p,'w').write(s.replace(o,n,1))" "$D/$2" "$3" "$4"
  if "$ROC" test $D/tests/w0.roc > /dev/null 2>&1; then echo "MISSED $1"; else echo "caught $1"; fi
  cp $K/$2 $D/$2
}
mut "W1 decode swaps log_size and members" Work.roc "log_size: w.log_size, members: w.members" "log_size: w.members, members: w.log_size"
mut "W2 encode drops missing order" Work.roc "missing: answer.missing }" "missing: answer.missing.rev() }"
mut "W3 decode reads sweep always none" Work.roc "sweep: Nullable.read(w.sweep)" "sweep: Err(None)"
mut "A1 decode drops last pair" Audit.roc "Ok(a) => Ok(a)" "Ok(a) => Ok({ pairs: a.pairs.drop_last(1) })"
mut "A2 encode adds white space" Audit.roc "Json.to_str(answer)" "Json.to_str(answer).replace_each(\",\", \", \")"
mut "A3 decode swaps pass and fail" Audit.roc "Ok(a) => Ok(a)" "Ok(a) => Ok({ pairs: a.pairs.map(|p| { ..p, pass_count: p.fail_count, fail_count: p.pass_count }) })"
