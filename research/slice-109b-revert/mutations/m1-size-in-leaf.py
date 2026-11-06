# M1: the size is in the leaf hash (R-AP80: size stays out of the leaf).
import sys
p = sys.argv[1] + '/lib/Toolchains.roc'; s = open(p).read()
old = "leaf: leaf_of({ target: p.target, tag: a.tag, sha256: p.sha256, now_ms: a.now_ms })"
assert old in s
open(p, 'w').write(s.replace(old, "leaf: leaf_of({ target: p.target, tag: a.tag, sha256: \"${p.sha256}${p.size.to_str()}\", now_ms: a.now_ms })", 1))
