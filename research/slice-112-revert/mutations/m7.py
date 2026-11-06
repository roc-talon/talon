# internal is public (only private is refused)
import sys
p = sys.argv[1] + '/lib/Ingest.roc'
s = open(p).read()
old = 'public: r.visibility == "public"'
new = 'public: r.visibility != "private"'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
