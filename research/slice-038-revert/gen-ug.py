# Slice 038: make the L2 cases upgrade/ug1-flow and upgrade/ug2-lag (tln upgrade for packages).
# Run: python3 -I research/slice-038-revert/gen-ug.py
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/upgrade')
src_foreign = os.path.join(root, 'tests/commands/cases/probe/un1-units/fx/unit-foreign.stderr')
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
NOW = '2026-10-15T12:00:00Z'
H = 'nightly-2026-10-14-38a3029'


def b58(data):
    n = int.from_bytes(data, 'big')
    out = ''
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


def hash_of(repo, ver):
    return b58(hashlib.sha256(f'talon-038{os.environ.get("SEED", "")}/{repo}/{ver}'.encode()).digest())


def url(repo, ver):
    return f'https://github.com/acme/{repo}/releases/download/{ver}/{hash_of(repo, ver)}.tar.zst'


PLATFORM = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'


def header(deps=None, pf=None):
    entries = []
    if pf:
        entries.append(f'\tpf: platform "{pf}",\n')
    for name, u in (deps or []):
        entries.append(f'\t{name}: "{u}",\n')
    return 'package [Lib] {\n' + ''.join(entries) + '}\n' if entries else 'package [Lib] {}\n'


class World:
    def __init__(self, name):
        self.name = name
        self.dst = os.path.join(cases, name)
        shutil.rmtree(self.dst, ignore_errors=True)
        os.makedirs(self.dst + '/fx/http/api.github.com/repos/acme')
        os.makedirs(self.dst + '/given/home/.cache/roc/packages')
        os.makedirs(self.dst + '/given/project')
        self.repos = {}

    def release(self, repo, ver, published, text=None, platform=False):
        self.repos.setdefault(repo, []).append((ver, published))
        d = f'{self.dst}/given/home/.cache/roc/packages/{hash_of(repo, ver)}'
        os.makedirs(d, exist_ok=True)
        open(d + '/main.roc', 'w').write(PLATFORM if platform else (text if text is not None else 'package [Lib] {}\n'))

    def finish(self, runs, env, rules, extra_fx=None):
        for repo, rels in self.repos.items():
            items = []
            for ver, published in rels:
                h = hash_of(repo, ver)
                u = f'https://github.com/acme/{repo}/releases/download/{ver}/{h}.tar.zst'
                items.append({'tag_name': ver, 'draft': False, 'prerelease': False, 'published_at': published,
                              'assets': [{'name': h + '.tar.zst', 'size': 1000, 'browser_download_url': u}]})
            d = f'{self.dst}/fx/http/api.github.com/repos/acme/{repo}'
            os.makedirs(d, exist_ok=True)
            open(d + '/releases?per_page=100', 'w').write(json.dumps(items, separators=(',', ':')))
        w = lambda p, t: open(f'{self.dst}/{p}', 'w').write(t)
        w('entry', 'commands\n')
        w('fx/commands', '\n'.join(runs) + '\n')
        w('fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\n' + env)
        w('fx/gitdirs', '.\n')
        w('fx/programs', 'roc\n')
        w('fx/jobs', f'version\t0\tRoc compiler version {H}\t-\t-\n')
        w('fx/path-roc', '# slice 022b: a tln of 5000 bytes and a roc of 1000 bytes. The sizes differ, so no file is hashed.\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
        w('rules', rules)
        for name, text in (extra_fx or {}).items():
            w('fx/' + name, text)

    def project(self, name, deps, toml=None, pin=H, files=None):
        d = f'{self.dst}/given/project/{name}'
        os.makedirs(d, exist_ok=True)
        lines = ''.join(f'\t{a}: {"platform " if a == "pf" else ""}"{u}",\n' for a, u in deps)
        open(d + '/main.roc', 'w').write(f'app [main!] {{\n{lines}\troc: "{pin}",\n}}\n\nmain! = |_args| Ok({{}})\n')
        if toml is not None:
            open(d + '/talon.toml', 'w').write(toml)


# ---------------------------------------------------------------- ug1-flow
w = World('ug1-flow')
for v, p in [('0.1.0', '2026-07-01'), ('0.1.1', '2026-09-20'), ('0.2.0', '2026-10-01'), ('0.2.1', '2026-10-05')]:
    w.release('pfx', v, p + 'T12:00:00Z', platform=True)
for v, p, t in [('2.0.0', '2026-08-16', None), ('2.1.0', '2026-09-25', None), ('2.2.0', '2026-10-01', None), ('3.0.0', '2026-10-03', None), ('3.0.2', '2026-10-08', None), ('3.1.0', '2026-10-14', None)]:
    w.release('json', v, p + 'T12:00:00Z', t)
w.release('parser', '1.0.0', '2026-07-17T12:00:00Z')
w.release('parser', '1.2.0', '2026-10-05T12:00:00Z')
# parser 2.0.0 still needs the series 2 of json: both series stay in the closure (R-UP3, R-C8)
w.release('parser', '2.0.0', '2026-10-09T12:00:00Z', header(deps=[('json', url('json', '2.1.0'))]))
PF0, J21, PA0 = url('pfx', '0.1.0'), url('json', '2.1.0'), url('parser', '1.0.0')
base = [('pf', PF0), ('json', J21), ('parser', PA0)]
TOML2 = '# the team intent\n[dependencies]\njson = "^2.1"   # stay on 2 for now\npf = "0.1.*"\nparser = "=1.0.0"\nlex = "acme/lex@^1"\n'
w.project('p1', base)
w.project('p2', base, TOML2)
w.project('p3', base, '[dependencies]\njson = "^2.1"\nparser = "=1.0.0"\npf = "0.1.*"\n')
w.project('p4', base, '[dependencies]\njson = "acme/json@^2.1"\npf = "0.1.*"\n')
w.project('p5', base, '[dependencies]\njson = "^2.1"\npf = "0.1.*"\n')
w.project('p6', base)
w.project('p7', base, TOML2)
w.project('p8', base, TOML2)
w.project('p9', base, '[dependencies]\njson = ">=2.1, <3.0"\n')
w.project('p11', base, '[dependencies]\njson = "^2.1"\nparser = "=1.0.0"\n')
w.project('p10', base, '[resolution]\nstrategy = "lowest"\n\n[dependencies]\njson = "^2.1"\n')
# a workspace: the root key `json` applies to the entry `json` of member a; member b has the same group as `j2` and no key
os.makedirs(w.dst + '/given/project/ws/apps/a')
os.makedirs(w.dst + '/given/project/ws/apps/b')
open(w.dst + '/given/project/ws/talon.toml', 'w').write('[workspace]\nmembers = ["apps/*/main.roc"]\n\n[dependencies]\njson = "^2.1"\n')
for m, alias in (('a', 'json'), ('b', 'j2')):
    open(f'{w.dst}/given/project/ws/apps/{m}/main.roc', 'w').write(
        f'app [main!] {{\n\tpf: platform "{PF0}",\n\t{alias}: "{J21}",\n\troc: "{H}",\n}}\n\nmain! = |_args| Ok({{}})\n')
runs1 = [
    'upgrade --file p1/main.roc',
    'upgrade --file p2/main.roc',
    'upgrade parser --file p3/main.roc',
    'upgrade json --file p4/main.roc',
    'upgrade --strategy lowest --file p1/main.roc',
    'upgrade --file ws/apps/a/main.roc',
    'update --file p7/main.roc',
    'update json@latest --file p5/main.roc',
    'update json@latest --file p6/main.roc',
    'upgrade --dry-run --json --file p8/main.roc',
    'upgrade json --file p9/main.roc',
    'upgrade json --file p10/main.roc',
    'update json@^2.1 parser@^1 --file p11/main.roc',
]
w.finish(runs1, '', open(os.path.join(root, 'research/slice-038-revert/ug1-rules.txt')).read())

# ---------------------------------------------------------------- ug2-lag (what did not get its newest release, R-UP2)
w = World('ug2-lag')
for v, p in [('0.1.0', '2026-07-01'), ('0.1.1', '2026-09-20'), ('0.2.0', '2026-10-01')]:
    w.release('pfx', v, p + 'T12:00:00Z', platform=True)
w.release('core', '1.0.0', '2026-07-01T12:00:00Z')
w.release('core', '1.2.0', '2026-10-01T12:00:00Z')
w.release('json', '2.0.0', '2026-08-16T12:00:00Z')
w.release('json', '2.2.0', '2026-10-01T12:00:00Z')
w.release('json', '3.0.0', '2026-10-03T12:00:00Z', header(deps=[('core', url('core', '1.2.0'))]))
w.release('text', '1.0.0', '2026-07-01T12:00:00Z')
w.release('text', '2.0.0', '2026-10-03T12:00:00Z', header(pf=url('pfx', '0.1.1')))
w.release('parser', '1.0.0', '2026-07-17T12:00:00Z')
w.release('parser', '1.1.0', '2026-10-05T12:00:00Z')
PF0 = url('pfx', '0.1.0')
deps = [('pf', PF0), ('json', url('json', '2.0.0')), ('core', url('core', '1.0.0')), ('text', url('text', '1.0.0')), ('parser', url('parser', '1.0.0'))]
w.project('q1', deps, '[dependencies]\ncore = "=1.0.0"\n')
w.project('q1j', deps, '[dependencies]\ncore = "=1.0.0"\n')
w.project('q1u', deps)
units = f'# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n{hash_of("parser", "1.1.0")}:{H}\t1\t-\tunit-foreign.stderr\n'
w.finish(['upgrade --file q1/main.roc', 'upgrade --dry-run --json --file q1j/main.roc', 'update --file q1u/main.roc'], 'CI=true\n', open(os.path.join(root, 'research/slice-038-revert/ug2-rules.txt')).read(), {'units': units})
shutil.copy(src_foreign, w.dst + '/fx/unit-foreign.stderr')

# ---------------------------------------------------------------- ug3-move (a held variable moves, R-UP4, R-SP25)
# Two cases: the worlds differ.
w = World('ug3-move')
for v, p in [('0.1.0', '2026-07-01')]:
    w.release('pfx', v, p + 'T12:00:00Z', platform=True)
w.release('core', '1.0.0', '2026-07-01T12:00:00Z')
w.release('core', '1.2.0', '2026-10-01T12:00:00Z')
# lib 1.0.0 (the header value) and 2.0.0 both need core 1.2.0: a header that was edited by hand (core 1.0.0) has no tuple with core held (R-SP16)
w.release('lib', '1.0.0', '2026-08-01T12:00:00Z', header(deps=[('core', url('core', '1.2.0'))]))
w.release('lib', '2.0.0', '2026-10-04T12:00:00Z', header(deps=[('core', url('core', '1.2.0'))]))
deps2 = [('pf', url('pfx', '0.1.0')), ('lib', url('lib', '1.0.0')), ('core', url('core', '1.0.0'))]
# q2 and q3 have the same start. core is held by the command only (not an anchor): it moves when every lib release needs core 1.2.0
w.project('q2', deps2, '[dependencies]\nlib = "^1.0"\ncore = "1.0.*"\n')
w.project('q3', deps2, '[dependencies]\nlib = "^1.0"\ncore = "1.0.*"\n')
w.finish(['upgrade lib --file q2/main.roc', 'upgrade lib --yes --file q3/main.roc'], 'CI=true\n', open(os.path.join(root, 'research/slice-038-revert/ug3-rules.txt')).read())
