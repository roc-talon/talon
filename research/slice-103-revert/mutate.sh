#!/usr/bin/env bash
# The revert check of slice 103: hand mutations of the private reference (gen-ref.mjs MUTATE=<name>). Each must make a W1 case fail.
#   research/slice-103-revert/mutate.sh [name ...]      default: the names below
# leaf-agg and or-ignore are mutations of the cases, not of the reference: the aggregate form of the leaf statement, and INSERT OR IGNORE in the release statement (R-SG8, Q86). They run the reference on a changed copy of the cases.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
names=("$@")
[ ${#names[@]} -eq 0 ] && names=(leaf-agg or-ignore leaf-check-before no-skip window-gt window-edge-1 order-t-id first-min last-new withdrawn-eq0 or-replace author-counts crash-is-2 day-seconds cap-ge label-no-text)
for m in "${names[@]}"; do
  cases=""
  if [ "$m" = leaf-agg ] || [ "$m" = or-ignore ]; then
    rm -rf "$here/cases-mut"; cp -r "$root/sql/tests/cases" "$here/cases-mut"
    M="$m" python3 - "$here/cases-mut" <<'PY'
import sys, glob, os
mode = os.environ["M"]
n = 0
for f in glob.glob(sys.argv[1] + '/triggers/*/steps.sql'):
    s = open(f).read()
    if mode == "leaf-agg":
        t = s.replace("SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4\nWHERE", "SELECT COALESCE(MAX(idx), 0) + 1, ?1, ?2, ?3, ?4 FROM log\nWHERE")
    else:
        t = s.replace("INSERT INTO releases (log_index", "INSERT OR IGNORE INTO releases (log_index")
    n += s != t
    open(f, 'w').write(t)
assert n > 0
PY
    cases="$here/cases-mut"
    node "$here/gen-ref.mjs" "$here/ws-mutant.sql"
  else
    MUTATE="$m" node "$here/gen-ref.mjs" "$here/ws-mutant.sql"
  fi
  out=$(CASES="$cases" "$here/run-ref.sh" "$here/ws-mutant.sql" triggers/ 2>&1 | grep '^FAIL' | awk '{print $3}' | sort -u | tr '\n' ' ')
  if [ -n "$out" ]; then echo "CAUGHT  $m -> $out"; else echo "MISSED  $m"; fi
done
rm -rf "$here/ws-mutant.sql" "$here/cases-mut" "$here/ws"
