# Slice 040: make the L2 cases outdated/od1-table and outdated/od2-edges (tln outdated, R-CM6).
# The World class is the one of research/slice-039c-revert/gen-um.py, cut down: `outdated` needs no compiler, no package archive and no probe.
# Run: python3 -I research/slice-040-revert/gen-od.py
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/outdated')
rules_dir = os.path.join(root, 'research/slice-040-revert')
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
NOW = '2026-10-15T12:00:00Z'
FAKE_SHA = 'b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78'

# The compiler list D (R-EP11), oldest first. min-release-age (2 days) hides nothing of D here: `outdated` never picks a compiler.
NIGHTLIES = [
    ('n08', 'nightly-2026-10-08-8c8c8c8', '2026-10-08T15:00:00Z', 73800000),
    ('h0', 'nightly-2026-10-09-9d9d9d9', '2026-10-09T15:00:00Z', 73900000),
    ('n10', 'nightly-2026-10-10-0e0e0e0', '2026-10-10T15:00:00Z', 74000000),
    ('n11', 'nightly-2026-10-11-1f1f1f1', '2026-10-11T15:00:00Z', 74100000),
    ('n12', 'nightly-2026-10-12-2a2a2a2', '2026-10-12T15:00:00Z', 74200000),
    ('n14', 'nightly-2026-10-14-4c4c4c4', '2026-10-14T15:00:00Z', 74400000),
]
ID = {k: i for k, i, _, _ in NIGHTLIES}
H = ID['h0']
ALL = [k for k, _, _, _ in NIGHTLIES]


def b58(data):
    n = int.from_bytes(data, 'big')
    out = ''
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


def hash_of(repo, ver):
    return b58(hashlib.sha256(f'talon-040/{repo}/{ver}'.encode()).digest())


def url(repo, ver):
    return f'https://github.com/acme/{repo}/releases/download/{ver}/{hash_of(repo, ver)}.tar.zst'


def other_url(repo, ver):
    return f'https://example.org/{repo}/releases/download/{ver}/{hash_of(repo, ver)}.tar.zst'


def nightlies_json():
    items = []
    for _, i, published, size in reversed(NIGHTLIES):
        name = f'roc_nightly-linux_x86_64-{i[len("nightly-"):]}.tar.gz'
        items.append({'tag_name': i, 'draft': False, 'prerelease': False, 'published_at': published,
                      'assets': [{'name': name, 'size': size, 'digest': 'sha256:' + FAKE_SHA,
                                  'browser_download_url': f'https://github.com/roc-lang/nightlies/releases/download/{i}/{name}'}]})
    return '[\n' + ',\n'.join(json.dumps(x, separators=(',', ':')) for x in items) + '\n]\n'


class World:
    def __init__(self, name):
        self.name = name
        self.dst = os.path.join(cases, name)
        shutil.rmtree(self.dst, ignore_errors=True)
        os.makedirs(self.dst + '/fx/http/api.github.com/repos/acme')
        os.makedirs(self.dst + '/fx/http/api.github.com/repos/roc-lang/nightlies')
        os.makedirs(self.dst + '/given/project')
        self.repos = {}
        self.homes = {}
        self.cached = []

    def release(self, repo, ver, published):
        self.repos.setdefault(repo, []).append((ver, published))

    def home(self, name, rows=None, cached=(), nightlies_cached=False):
        """A home dir. `rows` are the facts of compat.db: (repo, version, compiler key, outcome). `cached` are repos with a page in the index cache (R-DI12)."""
        self.homes[name] = (rows or [], list(cached), nightlies_cached)

    def project(self, name, deps, toml=None, pin=H, base='project'):
        d = f'{self.dst}/given/{base}/{name}'
        os.makedirs(d, exist_ok=True)
        lines = ''.join(f'\t{a}: {"platform " if a == "pf" else ""}"{u}",\n' for a, u in deps)
        roc = f'\troc: "{pin}",\n' if pin else ''
        open(d + '/main.roc', 'w').write(f'app [main!] {{\n{lines}{roc}}}\n\nmain! = |_args| Ok({{}})\n')
        if toml is not None:
            open(d + '/talon.toml', 'w').write(toml)

    def repo_json(self, repo):
        items = []
        for ver, published in self.repos[repo]:
            h = hash_of(repo, ver)
            items.append({'tag_name': ver, 'draft': False, 'prerelease': False, 'published_at': published,
                          'assets': [{'name': h + '.tar.zst', 'size': 1000, 'browser_download_url': url(repo, ver)}]})
        return json.dumps(items, separators=(',', ':'))

    def finish(self, runs, env, rules, mtimes=''):
        for repo in self.repos:
            d = f'{self.dst}/fx/http/api.github.com/repos/acme/{repo}'
            os.makedirs(d, exist_ok=True)
            open(d + '/releases?per_page=100', 'w').write(self.repo_json(repo))
        open(f'{self.dst}/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100', 'w').write(nightlies_json())
        for name, (rows, cached, nightlies_cached) in self.homes.items():
            h = f'{self.dst}/given/{name}'
            os.makedirs(f'{h}/.config/talon', exist_ok=True)
            open(f'{h}/.config/talon/config.toml', 'w').write('[probe]\ntimeout = 9\n')
            if rows:
                os.makedirs(f'{h}/.cache/roc/talon', exist_ok=True)
                lines = ['format\t1'] + sorted(f'fact\t{hash_of(repo, ver)}\t{ID[key]}\tany\t{outcome}\t\t' for repo, ver, key, outcome in rows)
                open(f'{h}/.cache/roc/talon/compat.tsv', 'w').write('\n'.join(lines) + '\n')
            for repo in cached:
                d = f'{h}/.cache/roc/talon/index/github/acme/{repo}'
                os.makedirs(d, exist_ok=True)
                open(d + '/1.json', 'w').write(self.repo_json(repo))
                open(d + '/1.meta', 'w').write('etag "c1"\n')
            if nightlies_cached:
                d = f'{h}/.cache/roc/talon/index/github/roc-lang/nightlies'
                os.makedirs(d, exist_ok=True)
                open(d + '/1.json', 'w').write(nightlies_json())
                open(d + '/1.meta', 'w').write('etag "n1"\n')
        w = lambda p, t: open(f'{self.dst}/{p}', 'w').write(t)
        w('entry', 'commands\n')
        w('fx/commands', '\n'.join(runs) + '\n')
        w('fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\n' + env)
        w('fx/gitdirs', '.\n')
        w('fx/programs', 'roc\n')
        w('fx/mtimes', mtimes)
        w('rules', rules)


def read_rules(name):
    return open(os.path.join(rules_dir, name)).read()


# ---------------------------------------------------------------- od1-table
# One project (p1) with every kind of entry. The header values and the releases (NOW is 2026-10-15T12:00:00Z, min-release-age is 2 days):
#   pf   pfx 0.1.0: releases 0.1.0, 0.1.1, 0.2.0. No key: the implied range is ^0.1.0, so wanted 0.1.1 and latest 0.2.0 (a new series).
#   json 2.1.0: key ^2.1. Releases 2.0.0, 2.1.0, 2.2.0, 3.0.2: wanted 2.2.0, latest 3.0.2 (new series).
#   parser 1.0.0: no key. 1.1.0 is 1 day old (hidden by R-C7), 2.0.0 is old: wanted 1.0.0 (equal), latest 2.0.0 (new series).
#   lib 1.0.0: the newest release. No row.
#   util 1.0.0: key =1.0.0 (an anchor). 1.2.0 exists: wanted 1.0.0 (equal), latest 1.2.0 (the same series, no suffix).
#   ext: a URL on example.org (R-DI11): no row, one fixed line. loc: a path entry: not shown.
w = World('od1-table')
for ver, pub in (('0.1.0', '2026-07-01T12:00:00Z'), ('0.1.1', '2026-07-15T12:00:00Z'), ('0.2.0', '2026-09-01T12:00:00Z')):
    w.release('pfx', ver, pub)
for ver, pub in (('2.0.0', '2026-06-01T12:00:00Z'), ('2.1.0', '2026-07-01T12:00:00Z'), ('2.2.0', '2026-08-01T12:00:00Z'), ('3.0.2', '2026-09-20T12:00:00Z')):
    w.release('json', ver, pub)
for ver, pub in (('1.0.0', '2026-07-01T12:00:00Z'), ('1.1.0', '2026-10-14T12:00:00Z'), ('2.0.0', '2026-09-01T12:00:00Z')):
    w.release('parser', ver, pub)
w.release('lib', '1.0.0', '2026-07-01T12:00:00Z')
for ver, pub in (('1.0.0', '2026-07-01T12:00:00Z'), ('1.2.0', '2026-08-01T12:00:00Z')):
    w.release('util', ver, pub)
w.release('solo', '1.0.0', '2026-07-01T12:00:00Z')
w.release('solo', '1.1.0', '2026-07-02T12:00:00Z')
PF, JSON1, PARSER0, LIB, UTIL0 = url('pfx', '0.1.0'), url('json', '2.1.0'), url('parser', '1.0.0'), url('lib', '1.0.0'), url('util', '1.0.0')
EXT = other_url('ext', '1.0.0')
base = [('pf', PF), ('json', JSON1), ('parser', PARSER0), ('lib', LIB), ('util', UTIL0), ('ext', EXT), ('loc', './loc/main.roc')]
w.project('p1', base, '[dependencies]\njson = "^2.1"\nutil = "=1.0.0"\n')
# p2: only packages at their newest release (and the fixed host): no row, and no compiler list, no db query.
w.project('p2', [('lib', LIB), ('ext', EXT)])
# p3: json (cached in the home of the run) and solo (no page: it acts as an anchor, R-DI12). Offline.
w.project('p3', [('json', JSON1), ('solo', url('solo', '1.0.0'))], '[dependencies]\njson = "^2.1"\n')
# p4: the same as p3. Run in a home with no page of the compiler list: the nightly range is `-` (unread).
w.project('p4', [('json', JSON1)], '[dependencies]\njson = "^2.1"\n')
# Facts of the current releases (R-EF1 rank 1, target any). json 2.1.0: pass on h0, n10, n11; fail on n08 and n12 (both ends real). parser 1.0.0: pass on n10 only (both ends unknown).
# util 1.0.0: pass everywhere (both ends are the ends of D). pf: no row.
rows = [('json', '2.1.0', 'h0', 'pass'), ('json', '2.1.0', 'n10', 'pass'), ('json', '2.1.0', 'n11', 'pass'), ('json', '2.1.0', 'n08', 'fail'), ('json', '2.1.0', 'n12', 'fail'),
        ('parser', '1.0.0', 'n10', 'pass')] + [('util', '1.0.0', k, 'pass') for k in ALL]
w.home('home', rows=rows)
w.home('home2', rows=rows, cached=['json'], nightlies_cached=True)
w.home('home3', rows=rows, cached=['json'])
runs = [
    'outdated --file p1/main.roc',
    'outdated --file p1/main.roc --json',
    'outdated --file p1/main.roc --quiet',
    'outdated --file p2/main.roc',
    'env:HOME={w}/home2 outdated --file p3/main.roc --offline',
    'env:HOME={w}/home3 outdated --file p4/main.roc --offline',
    'outdated json --file p1/main.roc',
    'outdated --file p1/main.roc --snapshot 2026-10-01T00:00:00Z',
]
w.finish(runs, '', read_rules('od1-rules.txt'), mtimes='acme/json/1.meta 1792000000\nroc-lang/nightlies/1.meta 1792050000\n')

# ---------------------------------------------------------------- od2-edges
# A workspace: the members a and b are under one talon.toml. Run from the workspace root there is no current member: both members are shown (R-PD5).
# json 2.1.0 (key ^2.1 in the root talon.toml, releases 2.1.0, 2.2.0, 3.0.0), the same group in both members. a also has lex 1.0.0 (newest 1.0.1), b also has parser 1.0.0 (newest: no row).
w = World('od2-edges')
for ver, pub in (('2.1.0', '2026-07-01T12:00:00Z'), ('2.1.5', '2026-07-20T12:00:00Z'), ('2.2.0', '2026-08-01T12:00:00Z'), ('3.0.0', '2026-09-01T12:00:00Z')):
    w.release('json', ver, pub)
w.release('parser', '1.0.0', '2026-07-01T12:00:00Z')
w.release('lex', '1.0.0', '2026-07-01T12:00:00Z')
w.release('lex', '1.0.1', '2026-07-05T12:00:00Z')
JSON1 = url('json', '2.1.0')
os.makedirs(w.dst + '/given/project/apps/a', exist_ok=True)
os.makedirs(w.dst + '/given/project/apps/b', exist_ok=True)
open(w.dst + '/given/project/talon.toml', 'w').write('[workspace]\nmembers = ["apps/*/main.roc"]\n\n[dependencies]\njson = "^2.1"\n')
w.project('apps/a', [('json', JSON1), ('lex', url('lex', '1.0.0'))])
w.project('apps/b', [('json', JSON1), ('parser', url('parser', '1.0.0'))])
# ws2: a second workspace. The key `json = "~2.1"` is in the talon.toml of member a only. R-WS7: it limits the group in member b too, so b has wanted 2.1.5, not 2.2.0.
os.makedirs(w.dst + '/given/project/ws2', exist_ok=True)
open(w.dst + '/given/project/ws2/talon.toml', 'w').write('[workspace]\nmembers = ["apps/*/main.roc"]\n')
w.project('ws2/apps/a', [('json', JSON1)], '[dependencies]\njson = "~2.1"\n')
w.project('ws2/apps/b', [('json', JSON1)])
rows2 = [('json', '2.1.0', 'h0', 'pass'), ('json', '2.1.0', 'n10', 'pass'), ('lex', '1.0.0', 'n12', 'pass')]
w.home('home', rows=rows2)
runs = [
    'outdated',
    'outdated --file apps/a/main.roc',
    'outdated --file apps/b/main.roc --json',
    'outdated --file ws2/apps/b/main.roc',
]
w.finish(runs, '', read_rules('od2-rules.txt'))
print('ok')
