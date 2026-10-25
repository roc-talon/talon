# Slice 041: make the L2 case init/it1-app (tln init). Run: python3 -I research/slice-041-revert/gen-it.py
# It writes only tests/commands/cases/init/it1-app. The expected files come from `UPDATE=1 tests/commands/run.sh init/it1-app` (TW21), read by hand.
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/init')
rules_dir = os.path.join(root, 'research/slice-041-revert')
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
NOW = '2026-10-15T12:00:00Z'
FAKE_SHA = 'b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78'  # sha256 of the text `fake`, the file that the fake curl writes
UNIT_FAIL = 'unit-foreign.stderr'

# The compiler list, as in slice 039 (gen-ur.py). The roc on PATH is H = h0. n14 is too new for min-release-age (2 days) at NOW.
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


def hash_of(owner, repo, ver):
    return b58(hashlib.sha256(f'talon-041/{owner}/{repo}/{ver}'.encode()).digest())


def url(owner, repo, ver):
    return f'https://github.com/{owner}/{repo}/releases/download/{ver}/{hash_of(owner, repo, ver)}.tar.zst'


PLATFORM = 'platform "x"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'


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
    def __init__(self, name):
        self.name = name
        self.dst = os.path.join(cases, name)
        shutil.rmtree(self.dst, ignore_errors=True)
        os.makedirs(self.dst + '/fx/http/api.github.com/repos/roc-lang/nightlies')
        os.makedirs(self.dst + '/given/project')
        self.repos = {}
        self.pkgs = []
        self.homes = {}

    def release(self, owner, repo, ver, published):
        self.repos.setdefault((owner, repo), []).append((ver, published))
        self.pkgs.append((hash_of(owner, repo, ver), PLATFORM))

    def home(self, name, installed, config_top=''):
        self.homes[name] = (installed, config_top)

    def write(self, rel, text):
        p = f'{self.dst}/given/project/{rel}'
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, 'w').write(text)

    def finish(self, runs, env, rules, answers='', units=''):
        for (owner, repo), rels in self.repos.items():
            items = []
            for ver, published in rels:
                h = hash_of(owner, repo, ver)
                items.append({'tag_name': ver, 'draft': False, 'prerelease': False, 'published_at': published,
                              'assets': [{'name': h + '.tar.zst', 'size': 1000, 'browser_download_url': url(owner, repo, ver)}]})
            d = f'{self.dst}/fx/http/api.github.com/repos/{owner}/{repo}'
            os.makedirs(d, exist_ok=True)
            open(d + '/releases?per_page=100', 'w').write(json.dumps(items, separators=(',', ':')))
        open(f'{self.dst}/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100', 'w').write(nightlies_json())
        for name, (installed, config_top) in self.homes.items():
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
            open(f'{h}/.config/talon/config.toml', 'w').write(config_top + '[probe]\ntimeout = 9\n')
        w = lambda p, t: open(f'{self.dst}/{p}', 'w').write(t)
        w('entry', 'commands\n')
        w('fx/commands', '\n'.join(runs) + '\n')
        w('fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\n' + env)
        w('fx/gitdirs', '.\n')
        w('fx/programs', 'roc\ncurl\ntar\n')
        w('fx/mtimes', 'roc-lang/basic-cli/1.meta 1792065590\nacme/pfx/1.meta 1792065590\nroc-lang/nightlies/1.meta 1792065590\n')
        w('fx/tty', 'stdin=true\nstderr=true\n')
        if answers:
            w('fx/answers', answers)
        w('fx/jobs', '# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod (as slice 021). The first rule whose needle is in the arguments answers.\n'
          + 'curl --fail\t0\t-\t-\tfile:{out}\n'
          + 'tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details\n'
          + 'chmod 0755\t0\t-\t-\t-\n'
          + f'version\t0\tRoc compiler version {H}\t-\t-\n')
        w('fx/path-roc', '# a tln of 5000 bytes and a roc of 1000 bytes (no file is hashed)\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
        w('fx/units', '# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n' + units)
        w('rules', rules)
        shutil.copy(os.path.join(root, 'tests/commands/cases/probe/un1-units/fx/unit-foreign.stderr'), self.dst + '/fx/' + UNIT_FAIL)


def unit_fail(owner, repo, ver, key):
    return f'{hash_of(owner, repo, ver)}:{ID[key]}\t1\t-\t{UNIT_FAIL}\n'


def read_rules(name):
    return open(os.path.join(rules_dir, name)).read()


# ---------------------------------------------------------------- it1-app
w = World('it1-app')
# roc-lang/basic-cli: 0.26.0 is 1 day old at NOW, so min-release-age (2 days) hides it (R-C7). acme/pfx is another platform: 0.2.0 fails the unit check on n12.
w.release('roc-lang', 'basic-cli', '0.24.0', '2026-06-01T12:00:00Z')
w.release('roc-lang', 'basic-cli', '0.25.0', '2026-07-01T12:00:00Z')
w.release('roc-lang', 'basic-cli', '0.26.0', '2026-10-14T12:00:00Z')
w.release('acme', 'pfx', '0.1.0', '2026-07-01T12:00:00Z')
w.release('acme', 'pfx', '0.2.0', '2026-08-01T12:00:00Z')
w.release('acme', 'young', '0.1.0', '2026-10-14T12:00:00Z')  # gap: 1 day old, hidden by min-release-age (2 days)
w.home('home', [])  # run 1: only H (the roc on PATH). N = n12 is the one download, a person says Enter
w.home('home2', [])  # run 2: CI, TALON_AUTO_INSTALL=no, --ci none
w.home('home3', [])  # run 3: --yes
w.home('home4', ['n10', 'n11', 'n12'], 'min-release-age = "0d"\n\n')  # run 4: CI, min-release-age 0d: N = n14 is the download
w.home('home5', ['n10', 'n11', 'n12'])  # run 5: --platform acme/pfx
w.home('home6', ['n10', 'n11', 'n12'])  # run 6: package
w.home('home7', [])  # run 7: main.roc exists
w.home('home8', ['n10', 'n11', 'n12'])  # run 8: a workspace above
w.home('home9', ['n10', 'n11', 'n12'])  # run 9: --json
w.home('home10', [])  # run 10: a bad template name
w.home('home11', [])  # run 11: the person says n: exit 13, main.roc is removed
w.home('home12', ['n10', 'n11', 'n12'])  # run 12: a CI file exists
w.home('home14', ['n10', 'n11', 'n12'])  # run 15: --offline, the index is cached
w.home('home13', [])  # run 13: CI, --allow-downloads, ROC_TOOLCHAIN names a compiler that is not installed
w.write('i7/main.roc', 'app [main!] {\n\tpf: platform "https://example.com/pf.tar.zst",\n}\n\nmain! = |_args| Ok({})\n')
w.write('i8/main.roc', 'app [main!] {\n\tpf: platform "https://example.com/pf.tar.zst",\n}\n\nmain! = |_args| Ok({})\n')
w.write('i8/talon.toml', '[workspace]\nmembers = ["apps/*/main.roc"]\n')
w.home('home15', ['n10', 'n11', 'n12'])  # run 14: no release old enough
w.write('i12/.github/workflows/ci.yml', 'name: mine\n')
units = unit_fail('acme', 'pfx', '0.2.0', 'n12')
runs = [
    'cwd:i1 init',
    'cwd:i2 env:CI=true env:TALON_AUTO_INSTALL=no env:HOME={w}/home2 init --ci none',
    'cwd:i3 env:HOME={w}/home3 init app --yes',
    'cwd:i4 env:CI=true env:HOME={w}/home4 init',
    'cwd:i5 env:HOME={w}/home5 init --platform acme/pfx',
    'cwd:i6 env:HOME={w}/home6 init package',
    'cwd:i7 env:HOME={w}/home7 init',
    'cwd:i8/sub env:HOME={w}/home8 init',
    'cwd:i9 env:HOME={w}/home9 init --json',
    'cwd:i10 env:HOME={w}/home10 init lib',
    'cwd:i11 env:HOME={w}/home11 init',
    'cwd:i12 env:HOME={w}/home12 init',
    'cwd:i13 env:CI=true env:ROC_TOOLCHAIN=' + ID['n10'] + ' env:HOME={w}/home13 init --allow-downloads',
    'cwd:i14 env:HOME={w}/home15 init --platform acme/young',
    'cwd:i15 env:HOME={w}/home14 init --offline',
]
w.finish(runs, '', read_rules('it1-rules.txt'), answers='\nn\n', units=units)

# Gap rows (slice 041, gap step): the home of run 15 has the cached release lists of basic-cli and of the compilers (a cache of an earlier online run).
for owner, repo in [('roc-lang', 'basic-cli'), ('roc-lang', 'nightlies')]:
    src = f'{w.dst}/fx/http/api.github.com/repos/{owner}/{repo}/releases?per_page=100'
    d = f'{w.dst}/given/home14/.cache/roc/talon/index/github/{owner}/{repo}'
    os.makedirs(d, exist_ok=True)
    shutil.copy(src, d + '/1.json')
    open(d + '/1.meta', 'w').write('')
