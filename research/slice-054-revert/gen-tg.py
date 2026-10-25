# Slice 054: make the L2 cases target/tg1-ladder, target/tg2-workspace, target/tg3-constraint, proxy/tg4-proxy and the L3 scenario update/tg1-wasm-platform (the build target: R-TG1 to R-TG6, R-C10).
# Run: python3 -I research/slice-054-revert/gen-tg.py
# It writes only these 5 dirs (without `expect/`). The expected files come from `UPDATE=1 tests/commands/run.sh <case>` and `UPDATE=1 tests/run.sh <case>` (TW21), read by hand.
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
NOW = '2026-10-15T12:00:00Z'
H = 'nightly-2026-10-14-38a3029'
PIN = 'nightly-2026-10-09-258ab27'


def b58(data):
    n = int.from_bytes(data, 'big')
    out = ''
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


def hash_of(repo, ver):
    return b58(hashlib.sha256(f'talon-054/{repo}/{ver}'.encode()).digest())


def url(repo, ver):
    return f'https://github.com/acme/{repo}/releases/download/{ver}/{hash_of(repo, ver)}.tar.zst'


def pf_header(targets):
    # `targets` is a list of names, or None for a platform with no `targets` section.
    h = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'
    if targets is not None:
        h += '\ttargets: {\n\t\tinputs_dir: "targets/",\n' + ''.join(f'\t\t{t}: {{ inputs: ["host.o", app] }},\n' for t in targets) + '\t}\n'
    return h


class Case:
    def __init__(self, rel, base_dst=None):
        self.dst = os.path.join(root, rel)
        shutil.rmtree(self.dst, ignore_errors=True)
        self.releases = {}

    def put(self, rel, data):
        p = os.path.join(self.dst, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, 'wb' if isinstance(data, bytes) else 'w').write(data)

    def release(self, repo, ver, day, text, cached=True, kind='main.roc'):
        h = hash_of(repo, ver)
        if cached:
            self.put(f'given/home/.cache/roc/packages/{h}/main.roc', text)
        self.releases.setdefault(repo, []).append((ver, day, h))

    def finish_index(self, prefix='fx/http/api.github.com'):
        for repo, rels in self.releases.items():
            items = [{'tag_name': ver, 'draft': False, 'prerelease': False, 'published_at': day + 'T12:00:00Z',
                      'assets': [{'name': h + '.tar.zst', 'size': 1000, 'browser_download_url': url(repo, ver)}]} for ver, day, h in rels]
            self.put(f'{prefix}/repos/acme/{repo}/releases?per_page=100', json.dumps(items, separators=(',', ':')))


def app(pf_repo, pf_ver, extra=''):
    return f'app [main!] {{\n\tpf: platform "{url(pf_repo, pf_ver)}",\n{extra}\troc: "{H}",\n}}\n\nmain! = |_args| Ok({{}})\n'


def common_fx(c, commands, rules):
    c.put('entry', 'commands\n')
    c.put('fx/commands', '\n'.join(commands) + '\n')
    c.put('fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\nCI=true\n')
    c.put('fx/gitdirs', '.\n')
    c.put('fx/programs', 'roc\n')
    c.put('fx/jobs', f'version\t0\tRoc compiler version {H}\t-\t-\n')
    c.put('fx/path-roc', '# slice 022b: a tln of 5000 bytes and a roc of 1000 bytes. The sizes differ, so no file is hashed.\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
    c.put('rules', rules)


# ======================================================================================================================
# target/tg1-ladder: the build target of one app project file (R-TG1 rules 1 to 3 and exit 2, R-TG2, R-TG3, R-TG4, R-LD5, R-BS1 key).
c = Case('tests/commands/cases/target/tg1-ladder')
for repo, targets in (('fpf', ['wasm32']), ('wpf', ['wasm32']), ('mpf', ['wasm32', 'x64musl', 'x64glibc']), ('gpf', ['wasm32', 'x64glibc']), ('npf', ['wasm32', 'x64mac'])):
    c.release(repo, '0.1.0', '2026-08-01', pf_header(targets))
    c.release(repo, '0.1.1', '2026-09-01', pf_header(targets))
c.release('json', '2.0.0', '2026-08-01', 'package [Json] {}\n')
c.release('json', '2.1.0', '2026-09-01', 'package [Json] {}\n')
c.finish_index()


def p(name, repo, build=None):
    c.put(f'given/project/{name}/main.roc', app(repo, '0.1.0'))
    toml = f'[dependencies]\npf = "acme/{repo}@=0.1.1"\n'
    if build is not None:
        toml += f'\n[build]\ntarget = "{build}"\n'
    c.put(f'given/project/{name}/talon.toml', toml)


p('p1', 'fpf')                 # run 1: a build that fails for the target wasm32
p('p2', 'wpf')                 # run 2: rule 3, the one target
p('p3', 'mpf')                 # run 3: rule 2, the host target (the fake machine is linux x64)
p('p4', 'mpf', 'wasm32')       # run 4: rule 1, the key; a pass for x64musl of run 3 is no skip for wasm32
p('p5', 'mpf', 'wasm32')       # run 5: the same key and digest as run 4: the build is skipped
p('p6', 'gpf')                 # run 6: rule 2, no musl target: glibc
p('p7', 'npf')                 # run 7: exit 2, 2 targets and none is the host
p('p8', 'mpf', 'wasm64')       # run 8: exit 19
# run 9: a package project file has no build. `[build]` has no effect (R-TG4).
c.put('given/project/p9/main.roc', f'package [Lib] {{\n\tjson: "{url("json", "2.0.0")}",\n}}\n')
c.put('given/project/p9/talon.toml', '[dependencies]\njson = "acme/json@=2.1.0"\n\n[build]\ntarget = "wasm32"\n')
# run 10 (Q3, manager answer): a bad value in the `[build]` of a package project file has no effect either: no exit 19 (R-TG4). The same file with an app gives exit 19 (run 8).
c.put('given/project/p10/main.roc', f'package [Lib] {{\n\tjson: "{url("json", "2.0.0")}",\n}}\n')
c.put('given/project/p10/talon.toml', '[dependencies]\njson = "acme/json@=2.1.0"\n\n[build]\ntarget = "wasm64"\n')
runs = [
    ('update pf --file p1/main.roc', 'R-TG1 R-TG2 R-LD5: one target (rule 3); the build fails for it: the text names the target and the platform'),
    ('update pf --file p2/main.roc', 'R-TG1 rule 3: the one target, wasm32'),
    ('update pf --file p3/main.roc', 'R-TG1 rule 2: the host target x64musl (3 targets)'),
    ('update pf --file p4/main.roc', 'R-TG1 rule 1: [build] target = wasm32 (the host x64musl is there too). The pass of run 3 is for x64musl: no skip (R-TG2: the key has the target)'),
    ('update pf --file p5/main.roc', 'R-TG2 R-BS1: the key and the digest of run 4: the build is skipped'),
    ('update pf --file p6/main.roc', 'R-TG1 rule 2: no musl target, so the glibc target'),
    ('update pf --file p7/main.roc', 'R-TG1: 2 targets and none is the host: exit 2, the message lists the targets and names [build] target'),
    ('update pf --file p8/main.roc', 'R-TG3: a value that is no Roc target: exit 19'),
    ('update json --file p9/main.roc', 'R-TG4: a package project file has no build; [build] has no effect'),
    ('update json --file p10/main.roc', 'R-TG4 R-TG3: a package project file: a [build] target that is no Roc target has no effect: no exit 19'),
]
rules = 'R-TG1 R-TG2 R-TG3 R-TG4 R-LD5 R-BS1 R-P4 R-EC2 R-EC19 R-EC10 R-LD7 (slice 054): the build target of one app project file. `update pf` on 10 projects that move the platform acme/<repo> from 0.1.0 to 0.1.1 (anchored by `=0.1.1` in `talon.toml`, so no other tuple exists, R-PH13). The fake machine is linux x64 (the host targets are x64musl, then x64glibc). Runs 1 to 6 change a header, so each runs the ladder: the baseline, the candidate check, the build. The build probe has `--target=<t>` before the file (R-LD5, R-TG2).\nRun 1 (platform fpf, target wasm32, the build fails with the fixture `build-target`): the tuple is dropped and the failure text names the target (exit 10). Run 2 (wpf, one target): `--target=wasm32` (rule 3). Run 3 (mpf, targets wasm32, x64musl, x64glibc): `--target=x64musl` (rule 2). Run 4 (mpf, `[build] target = "wasm32"`): `--target=wasm32` (rule 1), and the build runs although run 3 passed: the key has the target. Run 5 (the same as run 4): the build is skipped (`build: skipped (recorded pass)`). Run 6 (gpf, wasm32 and x64glibc): `--target=x64glibc`. Run 7 (npf, wasm32 and x64mac): exit 2 after the check, the message lists the targets, nothing is written. Run 8 (`[build] target = "wasm64"`): exit 19 at the read of `talon.toml`, before any call of a probe. Run 9 (a package project file with `[build] target = "wasm32"`): the check only, no build and no `--target` (R-TG4, R-LD7). Run 10 (a package project file with `[build] target = "wasm64"`): the same as run 9, and no exit 19: R-TG4, a package has no build, so its `[build]` is not checked. The facts of the builds are in `compat.tsv` (`tree.diff`): the column `target` has wasm32, x64musl and x64glibc.\n'
common_fx(c, [r for r, _ in runs], rules)
# The rows of `probes` are counted over all runs. Run 1 starts at row 0: baseline, check (pass), build (fails for the target).
c.put('fx/probes', '# run 1\n0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n1\t../fixtures/check/out/build-target.stdout\t../fixtures/check/out/build-target.stderr\n')
print('written', c.dst)

# ======================================================================================================================
# target/tg2-workspace: each member has its own build target (R-TG5, R-WS5).
c = Case('tests/commands/cases/target/tg2-workspace')
c.release('mpf', '0.1.0', '2026-08-01', pf_header(['wasm32', 'x64musl', 'x64glibc']))
c.release('mpf', '0.1.1', '2026-09-01', pf_header(['wasm32', 'x64musl', 'x64glibc']))
c.finish_index()
c.put('given/project/talon.toml', '[workspace]\nmembers = ["apps/*/main.roc"]\n\n# For the members whose nearest talon.toml is this file (R-WS5, R-TG5)\n[build]\ntarget = "x64glibc"\n')
for name in ('a', 'b', 'd'):
    c.put(f'given/project/apps/{name}/main.roc', app('mpf', '0.1.0'))
c.put('given/project/apps/b/talon.toml', '[build]\ntarget = "wasm32"\n')
c.put('given/project/apps/d/talon.toml', '# no [build]: the rules 2 and 3 of R-TG1 decide\n[dependencies]\n')
runs = [
    ('verify', 'R-TG5: a (root file: x64glibc), b (its own file: wasm32), d (its own file, no key: the host x64musl)'),
    ('verify --file apps/b/main.roc', 'R-TG5: one member, its own key. The pass of the first run is recorded: the build is skipped'),
]
rules = 'R-TG5 R-TG1 R-TG2 R-WS5 R-PD6 R-LD5 R-BS1 (slice 054): `verify` on a workspace of 3 members that name the platform mpf 0.1.0 (targets wasm32, x64musl, x64glibc). The root `talon.toml` has `[build] target = "x64glibc"`: it is the file of member a only (the nearest talon.toml, R-PD6). Member b has its own `talon.toml` with `target = "wasm32"`: it does not read the root key (Talon does not merge two files). Member d has its own `talon.toml` with no `[build]`: the root key has no effect on it, so rule 2 gives the host target x64musl. Run 1 builds a, b and d with `--target=x64glibc`, `--target=wasm32` and `--target=x64musl` (the platform of the candidate tuple: mpf 0.1.1). Run 2 (`--file apps/b/main.roc`): the pass of run 1 is recorded for (mpf 0.1.1, wasm32), so the build is skipped (R-BS1).\n'
common_fx(c, [r for r, _ in runs], rules)
print('written', c.dst)

# ======================================================================================================================
# target/tg3-constraint: R-C10, OP10.
c = Case('tests/commands/cases/target/tg3-constraint')
for ver, day, targets in (('0.1.0', '2026-08-01', ['x64musl', 'wasm32']), ('0.1.1', '2026-09-01', ['x64musl', 'wasm32']), ('0.1.2', '2026-09-10', ['x64musl'])):
    c.release('pf', ver, day, pf_header(targets))
for ver, day in (('0.1.0', '2026-08-01'), ('0.1.1', '2026-09-01')):
    c.release('hpf', ver, day, pf_header(['x64musl']))
c.finish_index()
c.put('given/project/p1/main.roc', app('pf', '0.1.0'))
c.put('given/project/p1/talon.toml', '[build]\ntarget = "wasm32"\n')
c.put('given/project/p2/main.roc', app('pf', '0.1.0'))
c.put('given/project/p3/main.roc', app('pf', '0.1.2'))
c.put('given/project/p3/talon.toml', '[build]\ntarget = "wasm32"\n')
c.put('given/project/p4/main.roc', app('hpf', '0.1.1'))
c.put('given/project/p4/talon.toml', '[build]\ntarget = "wasm32"\n')
# run 5 (gap test C3): the member wants wasm32, the header has pf 0.1.0 (it has wasm32), `talon.toml` anchors pf at `=0.1.2` (it has no wasm32). Some read releases pass the gate, so the failure text is the text of the solver, not the text of R-C10.
c.put('given/project/p5/main.roc', app('pf', '0.1.0'))
c.put('given/project/p5/talon.toml', '[dependencies]\npf = "acme/pf@=0.1.2"\n\n[build]\ntarget = "wasm32"\n')
runs = [
    ('update --file p1/main.roc', 'R-C10: the free platform moves to 0.1.1: 0.1.2 has no wasm32 and is no candidate'),
    ('update --file p2/main.roc', 'no [build]: the newest release, 0.1.2, and the host target x64musl'),
    ('install --file p3/main.roc', 'R-C10 OP10: the held platform 0.1.2 has no wasm32: exit 10, nothing is written'),
    ('update --file p4/main.roc', 'R-C10: no release of hpf has wasm32: exit 10'),
    ('update --file p5/main.roc', 'C3: the only candidate (=0.1.2) has no wasm32, but the header release has: the text is the text of the solver'),
]
rules = 'R-C10 R-TG1 R-TG3 R-C4 R-SP19 R-EC10 R-AL8 (slice 054, OP10): the release of a platform has the build target. The platform pf has 3 releases: 0.1.0 and 0.1.1 have the targets x64musl and wasm32, 0.1.2 has x64musl only. Run 1 (`[build] target = "wasm32"`, the header has pf 0.1.0, `update`): pf is free and moves, but 0.1.2 is no candidate, so it moves to 0.1.1 (the build is `--target=wasm32`). Run 2 (no `[build]`): rule 2 of R-TG1 takes the target from the release, so 0.1.2 is a candidate, and the build is `--target=x64musl`. Run 3 (`install` with no names holds the platform: R-SP19; the header has pf 0.1.2 and `[build] target = "wasm32"`): no tuple exists, exit 10, no probe, nothing written (the answer OP10 of the user: exit 10, not 2). Run 4 (`update`, the platform hpf has only x64musl in both releases): no release is a candidate, exit 10. Run 5 (gap test C3, `pf = "acme/pf@=0.1.2"`, `[build] target = "wasm32"`): the one candidate has no wasm32, but the release of the header has it, so a platform release passes the gate: the failure keeps the text of the solver, and `no_release` is not used. The text of the failure is a proposal (TW24).\n'
common_fx(c, [r for r, _ in runs], rules)
print('written', c.dst)

# ======================================================================================================================
# proxy/tg4-proxy: the proxy does not use the build target (R-TG6, R-PX3).
src = os.path.join(root, 'tests/commands/cases/proxy/px1-flow')
c = Case('tests/commands/cases/proxy/tg4-proxy')
shutil.copytree(src + '/given/home', c.dst + '/given/home', symlinks=True)
for f in ('env', 'gitdirs', 'jobs', 'path-roc'):
    os.makedirs(c.dst + '/fx', exist_ok=True)
    shutil.copy(f'{src}/fx/{f}', f'{c.dst}/fx/{f}')
c.put('fx/exec', '# every child ends with 0\n')
c.put('given/project/p1/main.roc', f'app [main!] {{\n\tpf: platform "{url("wpf", "0.1.0")}",\n\troc: "{PIN}",\n}}\n\nmain! = |_args| Ok({{}})\n')
c.put('given/project/p1/talon.toml', '[build]\ntarget = "wasm32"\n')
runs = ['@roc build p1/main.roc', '@roc check p1/main.roc --opt=speed']
c.put('entry', 'commands\n')
c.put('fx/commands', '\n'.join(runs) + '\n')
c.put('rules', 'R-TG6 R-PX3 R-PX7 (slice 054): the proxy does not use the build target. The project has `[build] target = "wasm32"`, and `roc build p1/main.roc` and `roc check p1/main.roc --opt=speed` pass the arguments with no change: no `--target`. The build of a tool (CLI 6.4, R-T8) and `tln init --platform` are in slices 046 and 055.\n')
print('written', c.dst)

# ======================================================================================================================
# The L3 scenario update/tg1-wasm-platform: the real `tln` and the fake roc (R-TG1, R-TG2, R-TG3).
sc = Case('tests/scenarios/update/tg1-wasm-platform')
sc.put('given/env', 'TALON_NOW=2026-10-15T12:00:00Z\n')
sc.put('given/roc.tsv', 'version\t0\tversion.stdout\t-\ncheck *\t0\tpass.stdout\t-\nbuild *\t0\tbuild-pass.stdout\t-\n')
for f in ('pass.stdout', 'build-pass.stdout'):
    shutil.copy(f'{root}/tests/scenarios/update/bs2-build-fail-replaced/given/{f}', f'{sc.dst}/given/{f}')
shutil.copy(f'{root}/tests/scenarios/update/bs2-build-fail-replaced/given/version.stdout', f'{sc.dst}/given/version.stdout')
for repo, targets in (('wpf', ['wasm32']), ('wpf2', ['wasm32'])):
    sc.release(repo, '0.1.0', '2026-08-01', pf_header(targets))
    sc.release(repo, '0.1.1', '2026-09-01', pf_header(targets))
sc.finish_index('given/http/api')


def sp(name, repo, build=None):
    sc.put(f'given/project/{name}/main.roc', app(repo, '0.1.0'))
    toml = f'[dependencies]\npf = "acme/{repo}@=0.1.1"\n'
    if build is not None:
        toml += f'\n[build]\ntarget = "{build}"\n'
    sc.put(f'given/project/{name}/talon.toml', toml)


sp('p1', 'wpf')
sp('p2', 'wpf2', 'wasm64')
sc.put('cmd', '''st() { echo "== $*"; if "$@"; then echo "exit 0"; else echo "exit $?"; fi; }
# R-TG1 rule 3, R-TG2: the platform has one target, wasm32. The build for it: `build --target=wasm32 main.roc --output=...` (the host target would fail). The real Fx reads the header of the platform in the package cache.
st tln update pf --dry-run --file p1/main.roc
# R-TG3: a value that is no Roc target: exit 19 with the file and the line. The real Fx reads `talon.toml`. (The exit 2 of R-TG1 names the host targets, so it has no L3 case: the text depends on the machine. L2 `target/tg1-ladder` run 7 has it.)
st tln update pf --dry-run --file p2/main.roc
''')
open(os.path.join(sc.dst, 'rules'), 'w').write('') if False else None
print('written', sc.dst)
