# M4: a size with a fraction is cut to a whole number and accepted (R-AP80: whole numbers only).
import sys
p = sys.argv[1] + '/lib/Toolchains.roc'; s = open(p).read()
old = "if f >= 0 and n.to_f64() == f Ok(n) else Err(Missing)"
assert old in s
open(p, 'w').write(s.replace(old, "if f >= 0 Ok(n) else Err(Missing)", 1))
