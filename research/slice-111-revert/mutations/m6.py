# the body read stops at the first refusal (the hash does not read to the end)
import sys
d = sys.argv[1]
p = d + '/Archive.roc'
s = open(p).read()
old = '\t\t\t\tOk(Chunk(c)) => {\n'
new = '\t\t\t\tOk(Chunk(c)) if !$s.reading() => {\n\t\t\t\t\t$more = Bool.False\n\t\t\t\t}\n\n\t\t\t\tOk(Chunk(c)) => {\n'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
