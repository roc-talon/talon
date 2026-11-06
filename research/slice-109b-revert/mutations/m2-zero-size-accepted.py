# M2: a size of 0 is an asset (R-AP80: above 0).
import sys
p = sys.argv[1] + '/lib/Toolchains.roc'; s = open(p).read()
old = "Ok(size) if size > 0 => Ok("
assert old in s
open(p, 'w').write(s.replace(old, "Ok(size) => Ok(", 1))
