# the header is the file whose key with the case fold (in choose and at the Content event) is main.roc (MAIN.ROC is read as the header)
import sys
d = sys.argv[1]
p = d + '/lib/ArchiveRead.roc'
s = open(p).read()
old = 'if (raw_key(entry.path) == "main.roc" and entry.kind == File)'
new = 'if (ArchiveRead.path_key(entry.path) == "main.roc" and entry.kind == File)'
assert s.count(old) == 1, old
s = s.replace(old, new)
old2 = '\t\t\t\t\t\t\tif raw_key(e.path) == "main.roc" {'
assert s.count(old2) == 1, old2
open(p, 'w').write(s.replace(old2, '\t\t\t\t\t\t\tif ArchiveRead.path_key(e.path) == "main.roc" {'))
