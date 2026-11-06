#!/usr/bin/env python3
"""Slice 206i: writes the expected files of the 3 init cases by hand-edit of
the pre-change expect files of share/sh62-no-send-init (before/). No code of
cli/ is used. Run from the repo root. A record: it needs before/."""
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
CASES = os.path.join(ROOT, '..', '..', 'tests', 'commands', 'cases')
BEF = os.path.join(ROOT, 'before', 'sh62-no-send-init', 'expect')

IDX = '$HOME/.cache/roc/talon/index'
GET = IDX + '/registry/http_127.0.0.1_9/get'
HFILE = '00b27ed3b2bb44add4738fe2e9ae72af'  # sha256("/v1/packages/roc-lang/basic-cli/releases")[:32]
H24 = 'FYkF6rabRLDoRMfACo8DNmyXWcX7Kwh3NYCU2JghiZN8'
H25 = '4oYDdxXzoz3DnHac4i8rR1FuqumnXbDSy9qiN96z18K5'
GRP = 'github.com/roc-lang/basic-cli/releases/download/{v}/'
DB = '$HOME/.cache/roc/talon/compat.db busy_ms=5000 format=1'
TMP = '$HOME/.cache/roc/talon/tmp/0123456789abcdef'
N12 = 'nightly-2026-10-12-2a2a2a2'


def read(p):
    return open(p).read()


def lines(p):
    t = read(p).split('\n')
    if t and t[-1] == '':
        t.pop()
    return t


def start_block():
    return [
        f'read_files {IDX}/github/roc-lang/basic-cli/repo.json',
        'programs gh',
        'http_get https://api.github.com/repos/roc-lang/basic-cli',
        '  User-Agent: tln/0.0.1',
        f'write_atomic {IDX}/github/roc-lang/basic-cli/repo.json',
        f'list_dirs {GET}',
        'http_get http://127.0.0.1:9/v1/packages/roc-lang/basic-cli/releases',
        '  User-Agent: tln/0.0.1',
        f'write_atomic {GET}/{HFILE}.json {GET}/{HFILE}.meta',
    ]


def closure_block(hashh, groups, nfacts):
    body = ('{"compilers":{"from":"nightly-2026-10-08-8c8c8c8","to":"%s"},'
            '"groups":%s,"hashes":["%s"]}') % (N12, groups, hashh)
    return [
        f'read_files {IDX}/github/roc-lang/basic-cli/repo.json',
        'http_send POST http://127.0.0.1:9/v1/closure timeout=20',
        '  User-Agent: tln/0.0.1',
        '  Content-Type: application/json',
        '  <body> ' + body,
        f'db_query {DB} facts={nfacts}',
    ]


def queue_unit():
    return ['platform', f'db_query {DB} pinned=1', 'clock',
            f'db_write {DB} queue=1 cap=10000']


def tail_share(hashh):
    row = '{"hash":"%s","nightly":"%s","result":"pass","target":"%s"}'
    body = ('{"rows":[{"hash":"HA","nightly":"nightly-2026-10-14-38a3029","result":"pass","target":"any"},'
            + row % (hashh, N12, 'any') + ',' + row % (hashh, N12, 'x64musl')
            + '],"talon_version":"0.0.1"}')
    return [
        f'db_query {DB} smoke=1',
        'platform',
        f'db_query {DB} pinned=1',
        'random',
        f'make_dirs {TMP}',
        f'write_atomic {TMP}/main.roc',
        'probes 1',
        f'  probe {TMP} {N12} $HOME/.cache/roc/toolchains/{N12}/roc build --target=x64musl main.roc --output={TMP}/tln-probe.out --no-cache timeout=9',
        '    env XDG_CACHE_HOME=$HOME/.cache ROC_CACHE_DIR=$HOME/.cache/roc TALON_IN_PROXY=1',
        f'db_write {DB} smoke=1',
        f'delete {TMP}',
        'platform',
        f'db_query {DB} pinned=1',
        'clock',
        f'db_write {DB} queue=1 cap=10000',
        f'db_query {DB} queue_rows',
        'read_files $HOME/.local/share/talon/share.json',
        'clock',
        'http_send POST http://127.0.0.1:9/v1/compat timeout=5',
        '  User-Agent: tln/0.0.1',
        '  Content-Type: application/json',
        '  Talon-Contributor: 0123456789abcdeffedcba9876543210',
        '  <body> ' + body,
    ]


def make_calls(version, share):
    src = lines(os.path.join(BEF, 'calls.log'))
    hashh = H24 if version else H25
    groups = '[]' if version else '[{"group":"%s"}]' % GRP
    nfacts = 6 if version else 18
    out = []
    i = 0
    first_unit = True
    while i < len(src):
        l = src[i]
        if l == f'list_dirs {IDX}/github/roc-lang/basic-cli' and src[i + 1] == 'programs gh':
            out += start_block()
            i += 5  # list_dirs, programs gh, http_get, User-Agent, write_atomic
            continue
        if l == f'list_dirs {IDX}/github/roc-lang/basic-cli':
            # the later read of the kept list: read_files 1.meta 1.json, db_query facts=18
            out += closure_block(hashh, groups, nfacts)
            i += 3
            continue
        out.append(l.replace(H25, hashh))
        if (share and first_unit and l.startswith(f'db_write {DB} facts=1 existing=replace')):
            out += queue_unit()
            first_unit = False
        i += 1
    if share:
        out += tail_share(hashh)
    return '\n'.join(out) + '\n'


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w').write(text)


def hunk_new(path, content):
    n = content.count('\n') + (0 if content.endswith('\n') else 1)
    t = f'--- {path}\n+++ {path}\n@@ -0,0 +{"1" if n == 1 else "1,%d" % n} @@\n'
    for ln in content.split('\n'):
        t += '+' + ln + '\n'
    return t


def make_tree(version, share):
    src = read(os.path.join(BEF, 'tree.diff'))
    hunks = src.split('--- ')
    head, hunks = hunks[0], ['--- ' + h for h in hunks[1:]]
    keep = []
    for h in hunks:
        p = h.split('\n')[0][4:]
        if p.endswith('index/github/roc-lang/basic-cli/1.json'):
            continue
        keep.append(h)
    if version:
        keep = [h.replace(H25, H24).replace('basic-cli/releases/download/0.25.0/', 'basic-cli/releases/download/0.24.0/') for h in keep]
    guard = '{"id":5,"full_name":"roc-lang/basic-cli","private":false,"fork":false}'
    rel = read(os.path.join(CASES, 'registry', 'in1-init-version', 'fx', 'http',
                            '127.0.0.1%3A9', 'v1', 'packages', 'roc-lang', 'basic-cli', 'releases'))
    meta = 'url /v1/packages/roc-lang/basic-cli/releases\netag "r1"\nmax-age 60\n'
    new = {
        'home/.cache/roc/talon/index/github/roc-lang/basic-cli/repo.json': guard + '\n\\ No newline at end of file\n',
        f'home/.cache/roc/talon/index/registry/http_127.0.0.1_9/get/{HFILE}.json': rel + '\n\\ No newline at end of file\n',
        f'home/.cache/roc/talon/index/registry/http_127.0.0.1_9/get/{HFILE}.meta': meta,
    }
    def fmt(path, content):
        body = content.split('\n')
        nl = 0
        outl = []
        for ln in body:
            if ln == '':
                continue
            outl.append(ln if ln.startswith('\\') else '+' + ln)
        cnt = len([x for x in outl if not x.startswith('\\')])
        rng = '1' if cnt == 1 else '1,%d' % cnt
        return f'--- {path}\n+++ {path}\n@@ -0,0 +{rng} @@\n' + '\n'.join(outl) + '\n'
    newh = {p: fmt(p, c) for p, c in new.items()}
    # share files
    if share:
        q = ('+2\t%s\t%s\tany\tpass\t0.0.1\t2026-10-15T12:00:00Z\n'
             '+3\t%s\t%s\tx64musl\tpass\t0.0.1\t2026-10-15T12:00:00Z\n') % (H25, N12, H25, N12)
        newh['home/.cache/roc/talon/share_queue.tsv'] = (
            '--- home/.cache/roc/talon/share_queue.tsv\n+++ home/.cache/roc/talon/share_queue.tsv\n'
            '@@ -1 +1,3 @@\n 1\tHA\tnightly-2026-10-14-38a3029\tany\tpass\t0.0.1\t2026-10-19T10:00:00Z\n' + q)
        newh['home/.cache/roc/talon/smoke.tsv'] = (
            '--- home/.cache/roc/talon/smoke.tsv\n+++ home/.cache/roc/talon/smoke.tsv\n@@ -0,0 +1 @@\n+%s\t%s\tx64musl\tpass\n' % (H25, N12))
    items = [(h.split('\n')[0][4:], h) for h in keep] + list(newh.items())
    # LC_ALL=C order of the paths
    items.sort(key=lambda t: t[0].encode())
    return head + ''.join(h for _, h in items)


def make_stdout(version, text_run, ncmd):
    s = read(os.path.join(BEF, 'stdout'))
    s = s.replace('resolved at 2026-10-15T12:00:00Z, 4 probes', 'resolved at log:60, 4 probes')
    s = s.replace('== cwd:i1 init', '== ' + ncmd)
    return s


if __name__ == '__main__':
    a = os.path.join(CASES, 'share', 'sh62-no-send-init', 'expect')
    write(os.path.join(a, 'calls.log'), make_calls(False, True))
    write(os.path.join(a, 'tree.diff'), make_tree(False, True))
    write(os.path.join(a, 'stdout'), make_stdout(False, '', 'cwd:i1 init'))
    b = os.path.join(CASES, 'registry', 'in1-init-version', 'expect')
    write(os.path.join(b, 'calls.log'), make_calls(True, False))
    write(os.path.join(b, 'tree.diff'), make_tree(True, False))
    write(os.path.join(b, 'stdout'), make_stdout(True, '', 'cwd:i1 init --platform roc-lang/basic-cli@0.24.0'))
    write(os.path.join(b, 'exit'), '0\n')

    # in2: a version that the registry list does not have (R-IN9 (2)): exit 2, no closure query, no main.roc
    c = os.path.join(CASES, 'registry', 'in2-init-no-release', 'expect')
    pre = lines(os.path.join(BEF, 'calls.log'))[:8]
    calls = pre + start_block() + ['read_files $HOME/.config/talon/config.toml']
    write(os.path.join(c, 'calls.log'), '\n'.join(calls) + '\n')
    t = make_tree(True, False)
    keep = [h for h in t.split('--- ') if h]
    keep = ['--- ' + h for h in keep if ('basic-cli/repo.json' in h.split('\n')[0] or '/get/' in h.split('\n')[0])]
    write(os.path.join(c, 'tree.diff'), ''.join(keep))
    write(os.path.join(c, 'stdout'), '== cwd:i1 init --platform roc-lang/basic-cli@9.9.9\nexit 2\n')
    write(os.path.join(c, 'stderr'), 'tln: error[usage]: roc-lang/basic-cli has no release 9.9.9\n')
    write(os.path.join(c, 'exit'), '0\n')

