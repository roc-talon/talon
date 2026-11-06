# M3: the wire order has size after published_at (R-AP80: after sha256).
import sys
p = sys.argv[1] + '/lib/Toolchains.roc'; s = open(p).read()
old = "\\\"size\\\":${r.size.to_str()},\\\"published_at\\\":${r.published_at.to_str()},"
assert old in s
open(p, 'w').write(s.replace(old, "\\\"published_at\\\":${r.published_at.to_str()},\\\"size\\\":${r.size.to_str()},", 1))
