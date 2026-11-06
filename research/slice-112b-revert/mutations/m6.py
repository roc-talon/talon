# an IPv4-mapped IPv6 is not its IPv4 address
import sys
p = sys.argv[1] + '/lib/Client.roc'
s = open(p).read()
old = 'if parts.len() == 1 or last.contains(".")'
new = 'if parts.len() == 1'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
