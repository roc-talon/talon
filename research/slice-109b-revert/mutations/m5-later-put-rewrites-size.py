# M5: a later PUT for a tag with rows reads GitHub again and the row is replaced (R-PU10, R-AP80: the recorded row keeps its size).
import sys
p = sys.argv[1] + '/ToolchainRoutes.roc'; s = open(p).read()
old = "Answer(found) => Ok(json_answer(200, Toolchains.put_body(found)))"
assert old in s
s = s.replace(old, "Answer(_) => publish!(tag, nightly)", 1)
old2 = "\"INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) SELECT ?, ?, ?, ?, ?, ?, ?, (SELECT MAX(idx) FROM log) WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ? AND target = ?)\""
assert old2 in s
s = s.replace(old2, "\"INSERT OR REPLACE INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) SELECT ?, ?, ?, ?, ?, ?, ?, (SELECT MAX(idx) FROM log)\"", 1)
old3 = "(w.nightly, w.target, w.tag, w.asset_name, w.sha256, w.size, w.published_at, w.nightly, w.target),"
assert old3 in s
open(p, 'w').write(s.replace(old3, "(w.nightly, w.target, w.tag, w.asset_name, w.sha256, w.size, w.published_at),", 1))
