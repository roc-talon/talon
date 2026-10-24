# Compare the old and the new expect/ dir of one case (slice 036c, TW21). Allowed added lines:
#  calls.log: the read of the compiler list D (`platform`, the `list_dirs`, `programs gh`, `http_get` of roc-lang/nightlies with its header line, `read_files` of its cache, `db_query` or `db_write` with `pinned=`, the `db_query` with `facts=` that loads the rows of D, `write_atomic` of the list cache)
#  stderr: the lines of `Explain.lines`: a cause line (2 spaces, `<label> fails|hangs|crashes on ...`), `  fix: ...`, `       or ...`
# Any removed line, and any other added line, is listed as CHECK.
import collections, os, re, sys
old, new, name = sys.argv[1:4]
D_READ = [
    r'^platform$',
    r'^list_dirs \$HOME\d*/\.cache/roc/talon/index/github/roc-lang/nightlies$',
    r'^programs gh$',
    r'^http_get https://api\.github\.com/repos/roc-lang/nightlies/releases\?per_page=100$',
    r'^  User-Agent: tln/\S+$',
    r'^read_files \$HOME\d*/\.cache/roc/talon/index/github/roc-lang/nightlies/1\.meta \$HOME\d*/\.cache/roc/talon/index/github/roc-lang/nightlies/1\.json$',
    r'^write_atomic \$HOME\d*/\.cache/roc/talon/index/github/roc-lang/nightlies/1\.json \S+$',
    r'^db_(query|write) \S+ busy_ms=\d+ format=\d+ pinned=\d+$',
    r'^db_query \S+ busy_ms=\d+ format=\d+ facts=\d+$',
]
FIX = [r'^  \S.* (fails|hangs|crashes) on \S+( \.\. \S+)?( \(inferred on .*\))?$', r'^  fix: tln roc use \S+( \(the oldest nightly that works\))?$', r'^       or (tln upgrade roc|stop using \S+)$']
def lines(d, f):
    p = os.path.join(d, f)
    return open(p).read().splitlines() if os.path.exists(p) else []
changed, bad = [], []
for f in sorted(set(os.listdir(new)) | set(os.listdir(old))):
    a, b = lines(old, f), lines(new, f)
    if a == b:
        continue
    changed.append(f)
    ca, cb = collections.Counter(a), collections.Counter(b)
    for l in cb - ca:
        ok = (f == 'calls.log' and any(re.search(p, l) for p in D_READ)) or (f == 'stderr' and any(re.search(p, l) for p in FIX))
        if not ok:
            bad.append((f, '+' + l))
    for l in ca - cb:
        bad.append((f, '-' + l))
print(name, 'changed:', ','.join(changed), 'OK' if not bad else 'CHECK')
for f, line in bad:
    print('   ', f, line[:200])
