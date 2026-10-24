# Slice 039: make the L2 cases upgrade/ur1-roc and upgrade/ur2-consent (tln upgrade with a free nightly).
# Run: python3 -I research/slice-039-revert/gen-ur.py
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/upgrade')
rules_dir = os.path.join(root, 'research/slice-039-revert')
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
    return b58(hashlib.sha256(f'talon-039/{repo}/{ver}'.encode()).digest())


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

    def home(self, name, installed, default=None, config=''):
        """A home dir with the packages of the world and the toolchains `installed` (keys of NIGHTLIES)."""
        self.homes[name] = (installed, default, config)

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
        for name, (installed, default, config) in self.homes.items():
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


# ---------------------------------------------------------------- ur1-roc (the free nightly, R-SP8, R-SP9, R-SP12, R-SP13, R-UP6, R-UP9, R-RP1)
w = World('ur1-roc')
w.release('pfx', '0.1.0', '2026-07-01T12:00:00Z', platform=True)
for v in ['1.0.0', '1.2.0', '1.3.0']:
    w.release('json', v, '2026-08-01T12:00:00Z')
for v in ['1.0.0', '1.1.0']:
    w.release('lib', v, '2026-08-01T12:00:00Z')
PF = url('pfx', '0.1.0')
J10, J12, J13 = url('json', '1.0.0'), url('json', '1.2.0'), url('json', '1.3.0')
L10 = url('lib', '1.0.0')
# homes: only the roc on PATH (H) is installed, or also some of n10, n11, n12. The default compiler is H, so no download makes a new default.
w.home('home', [])  # run 1: only H (path). N is the one download. U5: n10 and n11 are not installed, and nobody asks for them
w.home('home2', [])  # run 2 (CI)
w.home('home3', ['n10', 'n11'])  # run 3: n10, n11 installed, N is the download
w.home('home4', ['n10', 'n11'])  # run 4: nothing passes on a newer compiler
w.home('home5', ['n10', 'n11', 'n12'])  # run 5: upgrade lib roc
w.home('home6', ['n10', 'n11', 'n12'])  # run 6: upgrade roc, packages held
w.home('home7', ['n10', 'n11', 'n12'])  # run 7: range
w.home('home8', [])  # run 8: min-release-age 0d
w.home('home9', [])  # run 9: nightly = false
w.home('home10', ['n10', 'n11', 'n12'])  # run 10: --dry-run --json
w.home('home11', [])  # run 17: --json, N is the download
w.project('p1', [('pf', PF), ('json', J10)])
w.project('p2', [('pf', PF), ('json', J10)])
w.project('p3', [('pf', PF), ('json', J12)])
w.project('p4', [('pf', PF), ('json', J13)])
w.project('p5', [('pf', PF), ('lib', L10)])
w.project('p6', [('pf', PF), ('lib', L10)])
w.project('p7', [('pf', PF), ('json', J10)], '[toolchain]\nroc = ">=%s"\n' % ID['n10'])
w.project('p8', [('pf', PF), ('json', J10)], '[resolution]\nmin-release-age = "0d"\n')
w.project('p9', [('pf', PF), ('json', J10)])
w.project('p10', [('pf', PF), ('json', J10)])
w.project('p11', [('pf', PF), ('json', J10)])
w.project('pu', [('pf', PF), ('lib', L10)], pin=None)  # run 16: a member with no roc entry
w.project('p12', [('pf', PF), ('json', J10)])
N10 = ID['n10']
w.workspace('ws2', [('a', [('pf', PF), ('json', J10)], H), ('b', [('pf', PF), ('json', J10)], N10)])
w.workspace('ws3', [('a', [('pf', PF), ('json', J12)], H), ('b', [('pf', PF), ('json', J12)], ID['n11'])])
units = (unit_fail('json', '1.2.0', 'n12')
         + unit_fail('json', '1.3.0', 'n10') + unit_fail('json', '1.3.0', 'n11') + unit_fail('json', '1.3.0', 'n12')
         + unit_fail('lib', '1.1.0', 'n12'))
runs = [
    'upgrade roc --file p1/main.roc',
    'env:CI=true env:HOME={w}/home2 upgrade roc --file p2/main.roc',
    'env:HOME={w}/home3 upgrade roc --yes --file p3/main.roc',
    'env:CI=true env:HOME={w}/home4 upgrade roc --file p4/main.roc',
    'env:HOME={w}/home5 upgrade lib roc --file p5/main.roc',
    'env:HOME={w}/home6 upgrade roc --file p6/main.roc',
    'env:HOME={w}/home7 upgrade roc --file p7/main.roc',
    'env:CI=true env:HOME={w}/home8 upgrade roc --file p8/main.roc',
    'env:CI=true env:TALON_NIGHTLY=0 env:HOME={w}/home9 upgrade roc --file p9/main.roc',
    'env:HOME={w}/home10 upgrade roc --dry-run --json --file p10/main.roc',
    'env:HOME={w}/home6 upgrade json --no-check --file p11/main.roc',
    'upgrade --no-check --file p1/main.roc',
    'upgrade roc --no-check --file p1/main.roc',
    'env:HOME={w}/home6 upgrade roc --file ws2/apps/a/main.roc',
    'env:HOME={w}/home6 upgrade roc --file ws3/apps/a/main.roc',
    'env:HOME={w}/home6 upgrade --file pu/main.roc',
    'env:CI=true env:HOME={w}/home11 upgrade roc --json --file p12/main.roc',
]
w.finish(runs, '', read_rules('ur1-rules.txt'), answers='\n', units=units)


# ---------------------------------------------------------------- ur2-consent (the one prompt for N and H, R-NI12, R-BL3, R-NI5, R-DL1, R-DL3 to R-DL5)
# The roc on PATH is n08 (older than H), so H = h0 is installed only where the home has it.
w = World('ur2-consent')
w.release('pfx', '0.1.0', '2026-07-01T12:00:00Z', platform=True)
w.release('json', '1.0.0', '2026-08-01T12:00:00Z')
PF = url('pfx', '0.1.0')
J10 = url('json', '1.0.0')
w.home('home', [])  # run 1: H and N missing, a person
w.home('home2', [])  # run 2: H and N missing, CI
w.home('home3', [])  # run 3: H and N missing, --allow-downloads
w.home('home4', [])  # run 4: H and N missing, the person answers n
w.home('home5', [])  # run 5: H and N missing, TALON_AUTO_INSTALL=no
w.home('home6', ['n12'])  # run 6: N installed, H missing
w.home('home7', ['h0'])  # run 7: H installed, N missing, the person answers n
w.home('home8', ['h0'])  # run 8: H installed, N missing, CI and TALON_AUTO_INSTALL=no
w.home('home9', ['h0'])  # run 9: H installed, N missing, a person, Enter
for n in range(1, 10):
    w.project('p%d' % n, [('pf', PF), ('json', J10)])
runs = [
    'upgrade roc --file p1/main.roc',
    'env:CI=true env:HOME={w}/home2 upgrade roc --file p2/main.roc',
    'env:CI=true env:HOME={w}/home3 upgrade roc --allow-downloads --file p3/main.roc',
    'env:HOME={w}/home4 upgrade roc --file p4/main.roc',
    'env:CI=true env:TALON_AUTO_INSTALL=no env:HOME={w}/home5 upgrade roc --file p5/main.roc',
    'env:HOME={w}/home6 upgrade roc --file p6/main.roc',
    'env:HOME={w}/home7 upgrade roc --file p7/main.roc',
    'env:CI=true env:TALON_AUTO_INSTALL=no env:HOME={w}/home8 upgrade roc --file p8/main.roc',
    'env:HOME={w}/home9 upgrade roc --file p9/main.roc',
]
w.finish(runs, '', read_rules('ur2-rules.txt'), path_id=ID['n08'], answers='\nn\n\nn\n\n')


# ---------------------------------------------------------------- ur3-list (Q1: the list of compilers cannot be read, R-UP6)
# There is no route for the list of the nightlies, so the fake http answers 404 (the failure of `Nightlies.list!`).
w = World('ur3-list', nightlies=False)
w.release('pfx', '0.1.0', '2026-07-01T12:00:00Z', platform=True)
for v in ['1.0.0', '1.2.0']:
    w.release('json', v, '2026-08-01T12:00:00Z')
PF = url('pfx', '0.1.0')
J10 = url('json', '1.0.0')
w.home('home', [])
for n in range(1, 7):
    w.project('p%d' % n, [('pf', PF), ('json', J10)])
runs = [
    'upgrade --file p1/main.roc',
    'upgrade roc --file p2/main.roc',
    'upgrade json roc --file p3/main.roc',
    'upgrade json --file p4/main.roc',
    'upgrade --dry-run --json --file p5/main.roc',
    'upgrade --no-check --file p6/main.roc',
]
w.finish(runs, '', read_rules('ur3-rules.txt'))


# ---------------------------------------------------------------- ur4-candidate (gap A7: the header of the candidate copy has one pin when the pin moves)
# `fx/probe-text` shows the header of the copy of each check probe in the log. Member `pu` has no `roc:` entry and has package changes, so `Pin.decide` writes H; the move writes the new pin instead.
w = World('ur4-candidate')
w.release('pfx', '0.1.0', '2026-07-01T12:00:00Z', platform=True)
for v in ['1.0.0', '1.1.0']:
    w.release('lib', v, '2026-08-01T12:00:00Z')
PF = url('pfx', '0.1.0')
L10 = url('lib', '1.0.0')
w.home('home', ['n10', 'n11', 'n12'])
w.project('pu', [('pf', PF), ('lib', L10)], pin=None)
w.project('pp', [('pf', PF), ('lib', L10)])
units = unit_fail('lib', '1.1.0', 'n12')
runs = [
    'upgrade --file pu/main.roc',
    'upgrade --file pp/main.roc',
]
w.finish(runs, '', read_rules('ur4-rules.txt'), units=units)
open(f'{w.dst}/fx/probe-text', 'w').write('1\n')
