# the IP rate limit runs after D1 call 1 (the pre-read)
import sys, re
p = sys.argv[1] + '/IngestRoutes.roc'
s = open(p).read()
i = s.index('\t\tmatch rl.limit!(')
j = s.index('\t\tsession = db.with_session!', i)
block = s[i:j]
s = s[:i] + s[j:]
k = s.index('\t\tfirst = pre.first()')
s = s[:k] + block + s[k:]
open(p, 'w').write(s)
