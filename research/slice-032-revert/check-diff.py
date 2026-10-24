# Compare the old and the new expect/ dir of one case. Print each line that only one side has and that is not of an allowed kind (slice 032).
# A recorded build pass and a skip change the calls, so the lines are compared as a count of each text, not as a sequence.
import collections, os, re, sys
old, new, name = sys.argv[1:4]
touch = r'^write_atomic \$HOME\d*/\.cache/roc/toolchains/\S+/\.last-use$'
build_probe = r'^  probe \S+ \S+ \S+ build main\.roc --output=\S+( --replace-dep \S+ \S+)* timeout=\d+$'
env = r'^    env XDG_CACHE_HOME=\S+ ROC_CACHE_DIR=\S+ TALON_IN_PROXY=1$'
scan = r'^read_files \$(HOME\d*/\.cache/roc/packages|PROJECT\d*)/\S+\.roc( \S+\.roc)*$'
allowed = {
    'calls.log': {
        '+': [r'^platform$', r'^db_query \S+ busy_ms=5000 format=1 facts=1$', r'^db_write \S+ busy_ms=5000 format=1 facts=1 existing=replace$', scan, r'^probes 1( pool=\d+)?$', build_probe, env, touch],
        '-': [r'^probes 1( pool=\d+)?$', build_probe, env, touch],
    },
    'stdout': {'+': [r'^(\S+: )?build: skipped \(recorded pass\)$', r'^resolved at \S+, \d+ probes$', r'"probes":\d+', r'"build":"skipped"'], '-': [r'^(\S+: )?build: passed$', r'^resolved at \S+, \d+ probes$', r'"probes":\d+', r'"build":"passed"']},
    'stderr': {'+': [r'^(\S+: )?build: skipped \(recorded pass\)$', r'^resolved at \S+, \d+ probes$'], '-': [r'^(\S+: )?build: passed$', r'^resolved at \S+, \d+ probes$']},
}
def lines(d, f):
    p = os.path.join(d, f)
    return open(p).read().splitlines() if os.path.exists(p) else []
bad = []
for f in sorted(set(os.listdir(new)) | set(os.listdir(old))):
    a, b = lines(old, f), lines(new, f)
    if a == b:
        continue
    if f == 'tree.diff':
        ca, cb = collections.Counter(a), collections.Counter(b)
        for l in (cb - ca):
            if not (l.startswith('@@') or re.match(r'^\+fact\t\S+\t\S+\t(x64musl)\t(pass|fail|hang|crash)\t[^\t]*\t[0-9a-f]{64}$', l) or l.startswith(('+format',)) or l in ('--- home/.cache/roc/talon/compat.tsv', '+++ home/.cache/roc/talon/compat.tsv')):
                bad.append((f, '+' + l))
        for l in (ca - cb):
            if not l.startswith('@@'):
                bad.append((f, '-' + l))
        continue
    if f not in allowed:
        bad += [(f, '? changed')]
        continue
    ca, cb = collections.Counter(a), collections.Counter(b)
    for sign, cnt in (('+', cb - ca), ('-', ca - cb)):
        for l in cnt:
            if not any(re.search(p, l) for p in allowed[f][sign]):
                bad.append((f, sign + l))
print(name, 'OK' if not bad else 'CHECK')
for f, line in bad:
    print('   ', f, line[:200])
