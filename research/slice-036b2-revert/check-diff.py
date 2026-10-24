# Compare the old and the new expect/ dir of one case. Slice 036b2: the loop scans the used modules, so
#  + calls.log: a read_files of module files (not main.roc) comes first, in the loop (allowed)
#  - stdout: the line `note: tuple dropped: ...` (the loop drops the tuple, the ladder does not run) (allowed)
#  - calls.log: the calls of the ladder that no longer runs (listed, read by hand)
import collections, os, re, sys
old, new, name = sys.argv[1:4]
module_read = r'^read_files (\$HOME\d*/\.cache/roc/packages/\S+|\$PROJECT\d*/\S+)/\S+\.roc( \S+\.roc)*$'
def lines(d, f):
    p = os.path.join(d, f)
    return open(p).read().splitlines() if os.path.exists(p) else []
changed, bad, gone = [], [], []
for f in sorted(set(os.listdir(new)) | set(os.listdir(old))):
    a, b = lines(old, f), lines(new, f)
    if a == b:
        continue
    changed.append(f)
    ca, cb = collections.Counter(a), collections.Counter(b)
    for l in cb - ca:
        if not (f == 'calls.log' and re.search(module_read, l)):
            bad.append((f, '+' + l))
    for l in ca - cb:
        if f == 'stdout' and l.startswith('note: tuple dropped:'):
            continue
        if f == 'calls.log':
            gone.append((f, '-' + l))
        else:
            bad.append((f, '-' + l))
print(name, 'changed:', ','.join(changed), 'OK' if not bad else 'CHECK', '(%d calls of the ladder that no longer runs)' % len(gone))
for f, line in bad:
    print('   ', f, line[:200])
