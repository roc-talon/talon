#!/usr/bin/env bash
# Slice 110 revert check (TW12): break the code in one small way, run only the test that must see it, put the code back. Prints one line for each mutation.
set -u
cd "$(dirname "$0")/../.."
R=cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc
keep=$(mktemp -d)
cp -r worker/sql/closure "$keep/sql"; cp worker/lib/ClosureQuery.roc "$keep/"
w1() { node sql/tests/run.mjs closure 2>&1 | grep -c '^FAIL'; }
w0() { $R test worker/tests/unit/w0.roc --no-cache 2>&1 | grep '✗ fail' | grep -c ClosureQueryTest; }
mut() { # name file python-old python-new test
  python3 - "$2" "$3" "$4" <<'PY'
import sys; p, a, b = sys.argv[1:]; s = open(p).read(); assert s.count(a) >= 1, a; open(p, 'w').write(s.replace(a, b, 1))
PY
  n=$($5); echo "$1: $5 failures $n"
  cp "$keep/sql/"*.sql worker/sql/closure/; cp "$keep/ClosureQuery.roc" worker/lib/
}
mut order-t worker/sql/closure/prefix.sql "ORDER BY nightly >> 28, t, nightly) AS ord" "ORDER BY t, nightly) AS ord" w1
mut order-id worker/sql/closure/prefix.sql "ORDER BY nightly >> 28, t, nightly) AS ord" "ORDER BY nightly) AS ord" w1
mut nomerge worker/sql/closure/nearest.sql "AND NOT (c.source = 1" "AND 0 AND NOT (c.source = 1" w1
mut no-previous worker/sql/closure/prefix.sql "AND x.previous = d.prev " "" w1
mut unknown-dup worker/sql/closure/unknown.sql "MIN(idx) AS idx FROM hx WHERE id NOT IN (SELECT artifact FROM artifacts) GROUP BY id" "idx FROM hx WHERE id NOT IN (SELECT artifact FROM artifacts)" w1
mut checked-bounded worker/sql/closure/checked.sql "FROM releases WHERE form IN (SELECT form FROM grp)" "FROM rel WHERE form IN (SELECT form FROM grp)" w1
mut no-held-hash worker/lib/ClosureQuery.roc "query.hash_texts.contains(release.hash) or " "" w0
mut limits-after-values worker/lib/ClosureQuery.roc "		if req.groups.len() > group_limit {" "		_ = req.groups.map_try(group_item)?
		if req.groups.len() > group_limit {" w0
mut digest-empty worker/lib/ClosureQuery.roc "		error_digest: r.error_digest.map_err(|_| None),
		from: r.from," "		error_digest: Ok(r.error_digest ?? \"\"),
		from: r.from," w0
mut range-ignored worker/lib/ClosureQuery.roc "		lo = I64.max(series.lo, range.lo)" "		lo = I64.max(series.lo, series.lo + 0 * range.lo)" w0
diff -r "$keep/sql" worker/sql/closure && diff "$keep/ClosureQuery.roc" worker/lib/ClosureQuery.roc && echo "code restored: same as before"
rm -rf "$keep"
