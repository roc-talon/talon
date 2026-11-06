import os, sys
root = sys.argv[1]; m = os.environ["ROC_MUT"]
p = root + "/lib/Daily.roc"; q = root + "/DailyCrons.roc"
s = open(p).read(); c = open(q).read()
def sub(t, a, b):
    assert t.count(a) == 1, (m, a, t.count(a)); return t.replace(a, b)
if m == "order-by-id": s = sub(s, '"ORDER BY t.oldest, t.nightly"', '"ORDER BY t.nightly"')
elif m == "edge-le": s = sub(s, "t.oldest < ?1", "t.oldest <= ?1")
elif m == "stop-on-failure": c = sub(c, 'Err(e) => Log.warn!("trim failed", { nightly, error: Str.inspect(e) })', 'Err(e) => {\n\t\t\t\t\t\t\tLog.warn!("trim failed", { nightly, error: Str.inspect(e) })\n\t\t\t\t\t\t\tbreak\n\t\t\t\t\t\t}')
elif m == "smoke-as-bot": s = sub(s, "AND c.source = 0)", "AND c.source IN (0, 1))")
elif m == "days-edge-le": s = sub(s, "day < ?1 / 86400000 - 2", "day <= ?1 / 86400000 - 2")
elif m == "last-time-min": s = sub(s, "last_time = MAX(contributor_totals.last_time", "last_time = MIN(contributor_totals.last_time")
elif m == "delete-fail-silent": c = sub(c, "Err(e) => Log.warn!(msg, { error: Str.inspect(e) })", "Err(_) => {}")
open(p, "w").write(s); open(q, "w").write(c)
