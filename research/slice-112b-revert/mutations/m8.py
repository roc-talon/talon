# no drop of the series key
import sys
p = sys.argv[1] + '/lib/IngestLimits.roc'
s = open(p).read()
old = '\t\t\t"${i.origin}/v1/releases?group=${g}&series=${query_value(i.series)}",\n'
new = ''
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
