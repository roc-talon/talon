# the owner Retry-After is not rounded up
import sys
p = sys.argv[1] + '/lib/IngestLimits.roc'
s = open(p).read()
old = '(next - i.now_ms + 999) // 1000'
new = '(next - i.now_ms) // 1000'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
