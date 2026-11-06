# the IPv6 key is the full address text
import sys
p = sys.argv[1] + '/lib/Client.roc'
s = open(p).read()
old = 'Ok(g) => "${Str.join_with(g.take_first(4).map(|n| hex_of(n)), ":")}::/64"'
new = 'Ok(_) => text'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
