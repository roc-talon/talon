# Slice 039c: make the L2 case upgrade/ur6-moves (tln upgrade: the held move of the nightly R-RP4, a held move with a free nightly, --no-probe with a free nightly).
# The World class is the one of research/slice-039b-revert/gen-uo.py, with db rows for a home.
# Run: python3 -I research/slice-039c-revert/gen-um.py
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/upgrade')
rules_dir = os.path.join(root, 'research/slice-039c-revert')
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
NOW = '2026-10-15T12:00:00Z'
FAKE_SHA = 'b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78'  # sha256 of the text `fake`, the file that the fake curl writes
UNIT_FAIL = 'unit-foreign.stderr'  # a hard fail (no module of the package is named), copied from probe/un1-units

# The compiler list. id, published_at, size. H is the compiler of the headers (h0). n14 is too new for min-release-age (2 days) at NOW.
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


def b58(data):
    n = int.from_bytes(data, 'big')
    out = ''
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


def hash_of(repo, ver):
    return b58(hashlib.sha256(f'talon-039c/{repo}/{ver}'.encode()).digest())


def url(repo, ver):
    return f'https://github.com/acme/{repo}/releases/download/{ver}/{hash_of(repo, ver)}.tar.zst'


PLATFORM = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'


def nightlies_json():
    items = []
    for _, i, published, size in reversed(NIGHTLIES):
        name = f'roc_nightly-linux_x86_64-{i[len("nightly-"):]}.tar.gz'
        items.append({'tag_name': i, 'draft': False, 'prerelease': False, 'published_at': published,
                      'assets': [{'name': name, 'size': size, 'digest': 'sha256:' + FAKE_SHA,
                                  'browser_download_url': f'https://github.com/roc-lang/nightlies/releases/download/{i}/{name}'}]})
    return '[\n' + ',\n'.join(json.dumps(x, separators=(',', ':')) for x in items) + '\n]\n'


def talon_json(key, published):
    i = ID[key]
    return json.dumps({'format': 1, 'id': i, 'url': f'http://127.0.0.1:1/dl/{i}', 'sha256': '00', 'sha256_source': 'github-digest', 'typed': i,
                       'compat': None, 'installed_at': '2026-10-12T12:00:00Z', 'published_at': published}, separators=(',', ':')) + '\n'


class World:
    def __init__(self, name, nightlies=True):
        self.name = name
        self.nightlies = nightlies
        self.dst = os.path.join(cases, name)
        shutil.rmtree(self.dst, ignore_errors=True)
        os.makedirs(self.dst + '/fx/http/api.github.com/repos/acme')
        os.makedirs(self.dst + '/fx/http/api.github.com/repos/roc-lang/nightlies')
        os.makedirs(self.dst + '/given/project')
        self.repos = {}
        self.pkgs = []
        self.homes = {}

    def release(self, repo, ver, published, text=None, platform=False):
        self.repos.setdefault(repo, []).append((ver, published))
        self.pkgs.append((hash_of(repo, ver), PLATFORM if platform else (text if text is not None else 'package [Lib] {}\n')))

    def home(self, name, installed, default=None, config='', rows=None):
        """A home dir with the packages of the world and the toolchains `installed` (keys of NIGHTLIES). `rows` are the facts of compat.db: (repo, version, compiler key, outcome)."""
        # 039b: a home that has H has it as the default compiler, so no download makes a new default (R-SO15). A home with no H has none.
        self.homes[name] = (installed, default or ('h0' if 'h0' in installed else None), config, rows or [])

    def project(self, name, deps, toml=None, pin=H):
        d = f'{self.dst}/given/project/{name}'
        os.makedirs(d, exist_ok=True)
        lines = ''.join(f'\t{a}: {"platform " if a == "pf" else ""}"{u}",\n' for a, u in deps)
        roc = f'\troc: "{pin}",\n' if pin else ''
        open(d + '/main.roc', 'w').write(f'app [main!] {{\n{lines}{roc}}}\n\nmain! = |_args| Ok({{}})\n')
        if toml is not None:
            open(d + '/talon.toml', 'w').write(toml)

    def workspace(self, name, members, toml='[workspace]\nmembers = ["apps/*/main.roc"]\n'):
        """A workspace: `members` are (dir, deps, pin) rows."""
        d = f'{self.dst}/given/project/{name}'
        os.makedirs(d, exist_ok=True)
        open(d + '/talon.toml', 'w').write(toml)
        for m, deps, pin in members:
            md = f'{d}/apps/{m}'
            os.makedirs(md, exist_ok=True)
            lines = ''.join(f'\t{a}: {"platform " if a == "pf" else ""}"{u}",\n' for a, u in deps)
            roc = f'\troc: "{pin}",\n' if pin else ''
            open(md + '/main.roc', 'w').write(f'app [main!] {{\n{lines}{roc}}}\n\nmain! = |_args| Ok({{}})\n')

    def finish(self, runs, env, rules, path_id=H, answers='', units='', probes='', jobs_extra=''):
        for repo, rels in self.repos.items():
            items = []
            for ver, published in rels:
                h = hash_of(repo, ver)
                items.append({'tag_name': ver, 'draft': False, 'prerelease': False, 'published_at': published,
                              'assets': [{'name': h + '.tar.zst', 'size': 1000, 'browser_download_url': url(repo, ver)}]})
            d = f'{self.dst}/fx/http/api.github.com/repos/acme/{repo}'
            os.makedirs(d, exist_ok=True)
            open(d + '/releases?per_page=100', 'w').write(json.dumps(items, separators=(',', ':')))
        if self.nightlies:
            open(f'{self.dst}/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100', 'w').write(nightlies_json())
        for name, (installed, default, config, rows) in self.homes.items():
            h = f'{self.dst}/given/{name}'
            for hh, text in self.pkgs:
                os.makedirs(f'{h}/.cache/roc/packages/{hh}', exist_ok=True)
                open(f'{h}/.cache/roc/packages/{hh}/main.roc', 'w').write(text)
            os.makedirs(f'{h}/.cache/roc/toolchains', exist_ok=True)
            for key in installed:
                i = ID[key]
                pub = [p for k, _, p, _ in NIGHTLIES if k == key][0]
                os.makedirs(f'{h}/.cache/roc/toolchains/{i}', exist_ok=True)
                open(f'{h}/.cache/roc/toolchains/{i}/roc', 'w').write('fake roc\n')
                open(f'{h}/.cache/roc/toolchains/{i}/.talon.json', 'w').write(talon_json(key, pub))
            if rows:
                os.makedirs(f'{h}/.cache/roc/talon', exist_ok=True)
                lines = ['format\t1'] + sorted(f'fact\t{hash_of(repo, ver)}\t{ID[key]}\tany\t{outcome}\t\t' for repo, ver, key, outcome in rows)
                open(f'{h}/.cache/roc/talon/compat.tsv', 'w').write('\n'.join(lines) + '\n')
            os.makedirs(f'{h}/.config/talon', exist_ok=True)
            open(f'{h}/.config/talon/config.toml', 'w').write(('default-roc = "%s"\n\n' % ID[default] if default else '') + '[probe]\ntimeout = 9\n' + config)
        w = lambda p, t: open(f'{self.dst}/{p}', 'w').write(t)
        w('entry', 'commands\n')
        w('fx/commands', '\n'.join(runs) + '\n')
        w('fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\n' + env)
        w('fx/gitdirs', '.\n')
        w('fx/programs', 'roc\ncurl\ntar\n')
        w('fx/mtimes', 'acme/json/1.meta 1792065590\nacme/lib/1.meta 1792065590\nroc-lang/nightlies/1.meta 1792065590\n')
        w('fx/tty', 'stdin=true\nstderr=true\n')
        if answers:
            w('fx/answers', answers)
        w('fx/jobs', '# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod (as slice 021). The first rule whose needle is in the arguments answers.\n'
          + jobs_extra
          + 'curl --fail\t0\t-\t-\tfile:{out}\n'
          + 'tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details\n'
          + 'chmod 0755\t0\t-\t-\t-\n'
          + f'version\t0\tRoc compiler version {path_id}\t-\t-\n')
        w('fx/path-roc', '# a tln of 5000 bytes and a roc of 1000 bytes (no file is hashed)\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
        w('fx/units', '# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n' + units)
        if probes:
            w('fx/probes', probes)
        w('rules', rules)
        shutil.copy(os.path.join(root, 'tests/commands/cases/probe/un1-units/fx/unit-foreign.stderr'), self.dst + '/fx/' + UNIT_FAIL)


def unit_fail(repo, ver, key):
    return f'{hash_of(repo, ver)}:{ID[key]}\t1\t-\t{UNIT_FAIL}\n'




def read_rules(name):
    return open(os.path.join(rules_dir, name)).read()


def header(deps=None):
    entries = ''.join(f'\t{name}: "{u}",\n' for name, u in (deps or []))
    return 'package [Lib] {\n' + entries + '}\n' if entries else 'package [Lib] {}\n'


# ---------------------------------------------------------------- ur6-moves
# The roc on PATH is n08 (older than H). H = h0 is the pin of each header. The compilers: n10, n11, n12 (N), n14 (hidden by min-release-age, R-C7). All 4 (h0, n10, n11, n12) are installed in most homes.
# 3 families of a held move (a header that was edited by hand, as in slice 038 `ug3-move`: libX 1.0.0 needs coreX 1.2.0, and the header holds coreX 1.0.0, so no tuple exists with coreX held and the second search moves it):
#   (lib, core): core 1.2.0 fails on H (a unit probe) and passes elsewhere: the move of core needs the nightly to move too.
#   (libd, cored): cored 1.2.0 fails on every compiler: no tuple in the second search.
#   (libp, corep): corep 1.2.0 passes everywhere: the nightly stays H.
# jb 1.0.0 is the header value of the package that `upgrade jb` frees, and it has 1.1.0 (it passes everywhere).
w = World('ur6-moves')
w.release('pfx', '0.1.0', '2026-07-01T12:00:00Z', platform=True)
w.release('jb', '1.0.0', '2026-08-01T12:00:00Z')
w.release('jb', '1.1.0', '2026-08-15T12:00:00Z')
w.release('jc', '1.0.0', '2026-08-01T12:00:00Z')
w.release('ja', '1.0.0', '2026-08-01T12:00:00Z')
for lib, core in (('lib', 'core'), ('libd', 'cored'), ('libp', 'corep')):
    w.release(core, '1.0.0', '2026-07-01T12:00:00Z')
    w.release(core, '1.2.0', '2026-10-01T12:00:00Z')
    w.release(lib, '1.0.0', '2026-08-01T12:00:00Z', header(deps=[(core, url(core, '1.2.0'))]))
PF = url('pfx', '0.1.0')
JB0, JC, JA = url('jb', '1.0.0'), url('jc', '1.0.0'), url('ja', '1.0.0')
ALL4 = ['h0', 'n10', 'n11', 'n12']


def held_project(name, fam='lib', core_ver='1.0.0'):
    lib, core = {'lib': ('lib', 'core'), 'd': ('libd', 'cored'), 'p': ('libp', 'corep')}[fam]
    w.project(name, [('pf', PF), (lib, url(lib, '1.0.0')), (core, url(core, core_ver)), ('jb', JB0)])


for n in (1, 2, 3, 4, 5, 6, 7, 8):
    w.home('home%d' % n, ALL4)
    held_project('p%d' % n)
# 9: cored 1.2.0 fails on every compiler: no tuple in the second search
w.home('home9', ALL4)
held_project('p9', 'd')
# 10: a workspace, member a has the pin H, member b has no pin
w.home('home10', ALL4)
w.workspace('p10', [('a', [('pf', PF), ('lib', url('lib', '1.0.0')), ('core', url('core', '1.0.0')), ('jb', JB0)], H), ('b', [('pf', PF), ('lib', url('lib', '1.0.0')), ('core', url('core', '1.0.0'))], None)])
# 11: no conflict (the header has corep 1.2.0): no second search, the list of compilers is not read
w.home('home11', ALL4)
held_project('p11', 'p', '1.2.0')
# 12: a held move of corep, and corep 1.2.0 passes on H: the nightly stays H
w.home('home12', ALL4)
held_project('p12', 'p')
# 13 to 15: `--no-probe` with a free nightly
w.home('home13', ['h0', 'n11', 'n12'], rows=[('ja', '1.0.0', 'n12', 'fail')])
w.project('p13', [('pf', PF), ('ja', JA)])
w.home('home14', ['h0', 'n12'])
w.project('p14', [('pf', PF), ('jc', JC)])
w.home('home15', ['h0', 'n10', 'n12'], rows=[('ja', '1.0.0', 'n10', 'pass'), ('ja', '1.0.0', 'n11', 'fail'), ('ja', '1.0.0', 'n14', 'fail')])
w.project('p15', [('pf', PF), ('ja', JA)])
ci = 'env:CI=true '
runs = [
    ci + 'env:HOME={w}/home1 upgrade jb --file p1/main.roc',
    ci + 'env:HOME={w}/home2 upgrade jb --allow-moves --file p2/main.roc',
    'env:HOME={w}/home3 upgrade jb --file p3/main.roc',
    'env:HOME={w}/home4 upgrade jb --file p4/main.roc',
    ci + 'env:HOME={w}/home5 upgrade jb --dry-run --file p5/main.roc',
    ci + 'env:HOME={w}/home6 upgrade jb --json --file p6/main.roc',
    ci + 'env:HOME={w}/home7 update jb --file p7/main.roc',
    ci + 'env:HOME={w}/home8 upgrade jb roc --allow-moves --file p8/main.roc',
    ci + 'env:HOME={w}/home9 upgrade jb --file p9/main.roc',
    ci + 'env:HOME={w}/home10 upgrade jb --allow-moves --file p10/apps/a/main.roc',
    ci + 'env:HOME={w}/home11 upgrade jb --file p11/main.roc',
    ci + 'env:HOME={w}/home12 upgrade jb --allow-moves --file p12/main.roc',
    ci + 'env:HOME={w}/home13 upgrade roc --no-probe --file p13/main.roc',
    ci + 'env:HOME={w}/home14 upgrade roc --no-probe --file p14/main.roc',
    ci + 'env:HOME={w}/home15 upgrade roc --no-probe --file p15/main.roc',
]
units = unit_fail('core', '1.2.0', 'h0') + ''.join(unit_fail('cored', '1.2.0', k) for k in ALL4)
rules = read_rules('ur6-rules.txt') if os.path.exists(os.path.join(rules_dir, 'ur6-rules.txt')) else 'todo\n'
w.finish(runs, '', rules, path_id=ID['n08'], answers='\ny\n', units=units)
