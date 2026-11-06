import sys
d = sys.argv[1]
f = d + '/lib/Publish.roc'
s = open(f).read()
old = "json_extract(j.value, '$.target'), 1, json_extract(j.value, '$.result')"
new = "json_extract(j.value, '$.target'), 0, json_extract(j.value, '$.result')"
assert s.count(old) == 1, (s.count(old), old)
open(f, 'w').write(s.replace(old, new))
