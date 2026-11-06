import os, sys
root = sys.argv[1]
m = os.environ["ROC_MUT"]
p = root + "/lib/Daily.roc"
s = open(p).read()
q = root + "/DailyCrons.roc"
c = open(q).read()
def sub(t, a, b):
    assert a in t, (m, a)
    return t.replace(a, b)
if m == "order-by-id":
    s = sub(s, "ORDER BY MIN(t.published_at), t.nightly", "ORDER BY t.nightly")
elif m == "edge-le":
    s = sub(s, "MIN(t.published_at) < ?1 - 31536000000", "MIN(t.published_at) <= ?1 - 31536000000")
elif m == "pair-with-version-and-smoke":
    s = sub(s, "AND b.source = 0)\"", "AND b.source IN (0, 1))\"")
elif m == "stop-on-failure":
    c = sub(c, 'Err(e) => Log.warn!("trim failed", { nightly: row.nightly, error: Str.inspect(e) })', 'Err(e) => { Log.warn!("trim failed", { nightly: row.nightly, error: Str.inspect(e) })\n\t\t\t\t\tbreak\n\t\t\t\t}')
elif m == "last-time-keep":
    s = sub(s, "last_time = MAX(contributor_totals.last_time, excluded.last_time)", "last_time = contributor_totals.last_time")
elif m == "no-after-delete-order":
    s = sub(s, '\t\t"DELETE FROM contributions WHERE nightly = CAST(?1 AS INTEGER)",\n\t\t"DELETE FROM compat_hints', '\t\t"DELETE FROM compat_hints')
    s = sub(s, 'WHERE nightly = CAST(?1 AS INTEGER)",\n\t]', 'WHERE nightly = CAST(?1 AS INTEGER)",\n\t\t"DELETE FROM contributions WHERE nightly = CAST(?1 AS INTEGER)",\n\t]')
open(p, "w").write(s); open(q, "w").write(c)
