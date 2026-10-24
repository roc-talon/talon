# Compare the old and the new expect/ dir of one case. Print each line that only one side has and that is not of an allowed kind (slice 036b).
# The loop probes the changed releases first, so the calls move: the lines are compared as a count of each text, not as a sequence.
import collections, os, re, sys
old, new, name = sys.argv[1:4]
touch = r'^write_atomic \$HOME\d*/\.cache/roc/toolchains/\S+/\.last-use$'
probe_line = r'^  probe \S+ \S+ \S+ (check|build) main\.roc( --output=\S+)?( --replace-dep \S+ \S+)* timeout=\d+$'
env = r'^    env XDG_CACHE_HOME=\S+ ROC_CACHE_DIR=\S+ TALON_IN_PROXY=1$'
allowed_calls = [r'^probes \d+( pool=\d+)?$', probe_line, env, touch, r'^db_query \S+ busy_ms=5000 format=1 facts=\d+$', r'^db_write \S+ busy_ms=5000 format=1 facts=\d+ existing=replace$',
                 r'^list_dirs \$HOME\d*/\.cache/roc/toolchains$', r'^canonical \$HOME\d*/\.cache \$HOME\d*/\.cache/roc$', r'^random$', r'^list_dirs \$HOME\d*/\.cache/roc/packages$',
                 r'^read_files \$HOME\d*/\.cache/roc/packages/\S+/main\.roc( \S+/main\.roc)*$', r'^list_dirs \$HOME\d*/\.cache/roc/talon/tmp/\S+$', r'^copy_tree ', r'^write_atomic \$HOME\d*/\.cache/roc/talon/tmp/\S+$']
allowed = {'calls.log': {'+': allowed_calls, '-': allowed_calls}}
def lines(d, f):
    p = os.path.join(d, f)
    return open(p).read().splitlines() if os.path.exists(p) else []
bad = []
changed = []
for f in sorted(set(os.listdir(new)) | set(os.listdir(old))):
    a, b = lines(old, f), lines(new, f)
    if a == b:
        continue
    changed.append(f)
    if f not in allowed:
        bad += [(f, '? changed')]
        continue
    ca, cb = collections.Counter(a), collections.Counter(b)
    for sign, cnt in (('+', cb - ca), ('-', ca - cb)):
        for l in cnt:
            if not any(re.search(p, l) for p in allowed[f][sign]):
                bad.append((f, sign + l))
print(name, 'changed:', ','.join(changed), 'OK' if not bad else 'CHECK')
for f, line in bad:
    print('   ', f, line[:200])
