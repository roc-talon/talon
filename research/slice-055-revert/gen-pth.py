# Slice 055: make the L2 cases path/pt1-entry (tln path: R-PTH1 to R-PTH5, R-CM25, R-PD14) and init/it2-platform (tln init --platform: R-IN8, R-TG6, R-IN1).
# Run: python3 -I research/slice-055-revert/gen-pth.py
# It writes only these 2 dirs (without `expect/`). The expected files come from `UPDATE=1 tests/commands/run.sh <case>` (TW21), read by hand.
# The world of it2-platform is the world of init/it1-app (slice 041, gen-it.py: the compilers n08 to n14, the basic-cli list), with other platforms.
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases')
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
NOW = '2026-10-15T12:00:00Z'
FAKE_SHA = 'b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78'

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
    return b58(hashlib.sha256(f'talon-055/{owner}/{repo}/{ver}'.encode()).digest())


def url(owner, repo, ver):
    return f'https://github.com/{owner}/{repo}/releases/download/{ver}/{hash_of(owner, repo, ver)}.tar.zst'


def put(base, rel, data):
    p = os.path.join(base, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w').write(data)


def common_fx(dst, runs, env, rules, programs, jobs, extra=None):
    put(dst, 'entry', 'commands\n')
    put(dst, 'fx/commands', '\n'.join(runs) + '\n')
    put(dst, 'fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\n' + env)
    put(dst, 'fx/gitdirs', '.\n')
    put(dst, 'fx/programs', programs)
    put(dst, 'fx/jobs', jobs)
    put(dst, 'fx/path-roc', '# a tln of 5000 bytes and a roc of 1000 bytes (no file is hashed)\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
    put(dst, 'rules', rules)
    for rel, text in (extra or {}).items():
        put(dst, rel, text)


# ======================================================================================================================
# path/pt1-entry: `tln path <alias>` (R-CM25, R-PTH1 to R-PTH5, R-PD14, R-PD9, R-FL6, R-FE7, R-EC2).
dst = os.path.join(cases, 'path/pt1-entry')
shutil.rmtree(dst, ignore_errors=True)
PF = url('acme', 'pf', '0.2.0')
JSON = url('acme', 'json', '2.1.0')
HP, HJ = hash_of('acme', 'pf', '0.2.0'), hash_of('acme', 'json', '2.1.0')
# The package pf is in the cache (run 1). The package json is not: run 2 is offline (exit 15), run 3 fetches it.
put(dst, f'given/home/.cache/roc/packages/{HP}/main.roc', 'platform "acme-pf"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n')
put(dst, 'given/project/p1/main.roc',
    f'app [main!] {{\n\tpf: platform "{PF}",\n\tjson: "{JSON}",\n\tlib: "../shared/lib/main.roc",\n\todd: "https://example.com/pkg/{{v}}/x.tar.zst",\n\troc: "nightly-2026-10-14-38a3029",\n}}\n\nmain! = |_args| Ok({{}})\n')
# The directory of the path entry does not exist: tln path never reads it (R-PTH5).
# run 9 (Q1, answer of the review): a workspace root with no current member (the root dir has no member file): exit 2 that lists the members, as `add`
put(dst, 'given/project/ws/talon.toml', '[workspace]\nmembers = ["*/main.roc"]\n')
for m in ('a', 'b'):
    put(dst, f'given/project/ws/{m}/main.roc', f'app [main!] {{\n\tpf: platform "{PF}",\n}}\n\nmain! = |_args| Ok({{}})\n')
put(dst, 'given/project/p5/main.roc', f'app [main!] {{\n\tother: "{JSON}",\n}}\n\nmain! = |_args| Ok({{}})\n')
runs = [
    'cwd:p1 path pf',
    'cwd:p1 path json --offline',
    'cwd:p1 path json',
    'path json --file p1/main.roc --json',
    'cwd:p1 path lib',
    'cwd:p1 path odd',
    'cwd:p5 path pf',
    'cwd:p1 path',
    'cwd:ws path pf',
]
rules = ('R-CM25 R-PTH1 R-PTH2 R-PTH3 R-PTH4 R-PTH5 R-PD14 R-PD9 R-FL6 R-FE2 R-FE3 R-FE7 R-EC2 R-J1 (slice 055, `tln path <alias>`): 9 runs, one home. The project p1 has the entries pf (a platform release URL, the package is in the cache), json (a release URL, the package is NOT in the cache), lib (a path entry `../shared/lib/main.roc`, that directory does not exist), odd (a foreign URL: no hash, no version) and the pin `roc:`. The project p5 has one entry `other`.\n'
         'Run 1 (`path pf`): the directory `packages/<hash>` on stdout, one line (R-PTH1). The call list has the one read of the project file and the packages listing (`Present`), no other read: the run reads and runs no file of the package (R-PTH5). The project is recorded in `projects.json` (R-PTH4, R-PD9).\n'
         'Run 2 (`path json --offline`, the package is missing): exit 15, no download (R-PTH2, R-FE7). Run 3 (`path json`): the fetch of the closure step: download, `roc unbundle`, rename (R-FE2, R-FE3). The package is in the tree afterwards, stdout is its directory, and no project file changes (R-PTH2: nothing is resolved, nothing is written).\n'
         'Run 4 (`path json --file p1/main.roc --json`, the package is in the cache now, the cwd is the project root): the envelope with `data` `{ alias, kind: url, dir }` (R-PTH1, a proposal, R-OUT2). `--file` is a flag of `path` (R-FL6, R-PD14).\n'
         'Run 5 (`path lib`): a path entry: the directory of the file, `$PROJECT/shared/lib`, with no `..` and no fetch call (no `random` call). The directory is never read (R-PTH5).\n'
         'Run 6 (`path odd`): a foreign URL: exit 2, no fetch (R-PTH3). Run 7 (`path pf` in p5): an alias that is not in the header: exit 2, the message lists the entries (R-PTH3); the project p5 is recorded all the same (R-PTH4: a run that found a project records it, also when it fails later). Run 8 (`path`, no alias): exit 2 before any call except `args` (R-PTH1, R-EC2). Run 9 (`path pf` at the root of a workspace with 2 members and no current member, answer Q1): exit 2 that lists the members, as `add` and `remove` do (R-WS12, R-PD5); nothing is fetched.\n')
common_fx(dst, runs, '', rules, 'curl\nwget\n',
          '# R-DA3 the download, R-FE2 `roc unbundle` (as fetch/fe-flow). The first rule whose needle is in the arguments answers.\n'
          f'unbundle {HJ}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{HJ};file:{{cwd}}/{HJ}/main.roc\n'
          f'{HJ}.tar.zst\t0\t-\t-\tfile:{{w}}/home/.cache/roc/packages/{HJ}.0123456789abcdef.tmp/{HJ}.tar.zst\n')
print('written', dst)

# ======================================================================================================================
# init/it2-platform: `tln init --platform <name>` (R-IN8, answer OP8, R-TG6, R-IN1).
dst = os.path.join(cases, 'init/it2-platform')
shutil.rmtree(dst, ignore_errors=True)
P_BASIC = 'platform ""\n\trequires {\n\t\t## The entry point gets the arguments { and gives the result: a comment, with : and , in it\n\t\tmain! : List([Utf8(Str), UnixBytes(List(U8))]) => Try({}, [Exit(I32), ..])\n\t}\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'
P_OLD = 'platform "acme-mpf"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'
P_WEB = ('platform "acme-web"\n\trequires {\n\t\t[Context : context] for program : {\n\t\t\tinit! : () => Try(context, Str),\n\t\t\trespond! : Request, context => Try(Response, Str),\n'
         '\t\t\tshutdown! : context => {},\n\t\t}\n\t}\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n')
P_CNST = 'platform "acme-cnst"\n\trequires {} { main! : { go! : () => {}, port : U16 } }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'


def targets(names):
    return '\ttargets: {\n\t\tinputs_dir: "targets/",\n' + ''.join(f'\t\t{t}: {{ inputs: ["host.o", app] }},\n' for t in names) + '\t}\n'


P_MOV_OLD = 'platform "acme-mov"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n' + targets(['wasm32', 'x64musl'])
P_MOV_NEW = 'platform "acme-mov"\n\trequires {\n\t\t[Model : model] for program : {\n\t\t\tinit! : () => model,\n\t\t\tupdate! : model, Str => model,\n\t\t}\n\t}\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n' + targets(['x64musl'])
PLATFORMS = [
    ('roc-lang', 'basic-cli', '0.25.0', '2026-07-01T12:00:00Z', P_BASIC),
    ('acme', 'wpf', '0.1.0', '2026-07-01T12:00:00Z', P_BASIC + targets(['wasm32'])),
    ('acme', 'mpf', '0.1.0', '2026-07-01T12:00:00Z', P_OLD + targets(['wasm32', 'x64musl'])),
    ('acme', 'web', '0.1.0', '2026-07-01T12:00:00Z', P_WEB),
    ('acme', 'cnst', '0.1.0', '2026-07-01T12:00:00Z', P_CNST),
    ('acme', 'mov', '0.1.0', '2026-07-01T12:00:00Z', P_MOV_OLD),
    ('acme', 'mov', '0.2.0', '2026-08-01T12:00:00Z', P_MOV_NEW),
]
HOMES = ['home', 'home2', 'home3', 'home4', 'home5', 'home6', 'home7']
for h in HOMES:
    for owner, repo, ver, published, text in PLATFORMS:
        if h == 'home6' and repo == 'wpf':
            continue  # run 6: --offline, the platform release is not in the package cache
        put(dst, f'given/{h}/.cache/roc/packages/{hash_of(owner, repo, ver)}/main.roc', text)
    for key in ('n10', 'n11', 'n12'):
        i = ID[key]
        pub = [p for k, _, p, _ in NIGHTLIES if k == key][0]
        put(dst, f'given/{h}/.cache/roc/toolchains/{i}/roc', 'fake roc\n')
        put(dst, f'given/{h}/.cache/roc/toolchains/{i}/.talon.json', json.dumps({'format': 1, 'id': i, 'url': f'http://127.0.0.1:1/dl/{i}', 'sha256': '00', 'sha256_source': 'github-digest', 'typed': i, 'compat': None, 'installed_at': '2026-10-12T12:00:00Z', 'published_at': pub}, separators=(',', ':')) + '\n')
    put(dst, f'given/{h}/.config/talon/config.toml', '[probe]\ntimeout = 9\n')
for owner, repo in sorted({(o, r) for o, r, _, _, _ in PLATFORMS}):
    items = [{'tag_name': ver, 'draft': False, 'prerelease': False, 'published_at': published,
              'assets': [{'name': hash_of(owner, repo, ver) + '.tar.zst', 'size': 1000, 'browser_download_url': url(owner, repo, ver)}]}
             for o, r, ver, published, _ in PLATFORMS if (o, r) == (owner, repo)]
    put(dst, f'fx/http/api.github.com/repos/{owner}/{repo}/releases?per_page=100', json.dumps(items, separators=(',', ':')))
nightlies = []
for _, i, published, size in reversed(NIGHTLIES):
    name = f'roc_nightly-linux_x86_64-{i[len("nightly-"):]}.tar.gz'
    nightlies.append({'tag_name': i, 'draft': False, 'prerelease': False, 'published_at': published,
                      'assets': [{'name': name, 'size': size, 'digest': 'sha256:' + FAKE_SHA, 'browser_download_url': f'https://github.com/roc-lang/nightlies/releases/download/{i}/{name}'}]})
nightlies_text = '[\n' + ',\n'.join(json.dumps(x, separators=(',', ':')) for x in nightlies) + '\n]\n'
put(dst, 'fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100', nightlies_text)
# run 6 (--offline): the cached release lists of acme/wpf and of the compilers (a cache of an earlier online run), as `init/it1-app` run 15
for owner, repo, text in (('acme', 'wpf', None), ('roc-lang', 'nightlies', nightlies_text)):
    d = f'given/home6/.cache/roc/talon/index/github/{owner}/{repo}'
    src = open(f'{dst}/fx/http/api.github.com/repos/{owner}/{repo}/releases?per_page=100').read()
    put(dst, d + '/1.json', src)
    put(dst, d + '/1.meta', '')
runs = [
    'cwd:t1 init --platform acme/wpf',
    'cwd:t2 env:HOME={w}/home2 init --platform acme/mpf',
    'cwd:t3 env:HOME={w}/home3 init --platform acme/web',
    'cwd:t4 env:HOME={w}/home4 init --platform acme/cnst',
    'cwd:t5 env:HOME={w}/home5 init --platform roc-lang/basic-cli',
    'cwd:t6 env:HOME={w}/home6 init --platform acme/wpf --offline',
]
rules = ('R-IN8 R-SM2 R-TG6 R-TG1 R-IN1 R-IN2 R-IN7 R-PD9 R-FE7 R-EC2 (slice 055, `tln init --platform`): 6 runs, each in its own home and its own directory. All compilers n10 to n12 are installed, so no prompt and no download. The platforms are in the package cache of each home (the fetch finds them: `Present`).\n'
         'Run 1 (`acme/wpf`: `targets` has wasm32 only, `requires` is a function of one argument, with a doc comment that has `{`, `:` and `,`): `main.roc` is the stub app, `main! = |_| crash "write the app"` (R-IN8). The ladder builds for the target of R-TG1 rule 3: `build --target=wasm32` (R-TG6: there is no talon.toml). Run 2 (`acme/mpf`: wasm32 and x64musl, the old form `requires {} { main! : () => {} }`): `main! = || crash "write the app"`, and the build is `--target=x64musl` (R-TG1 rule 2, the host target of the fake machine). Run 3 (`acme/web`: an alias with a record of 3 functions): `Context : {}` and the record `program` with `||`, `|_, _|` and `|_|` stubs, no `targets` so the build has no `--target`. Run 4 (`acme/cnst`: `requires {} { main! : { go! : () => {}, port : U16 } }`, a field in a record): `U16` has no stub (R-SM2 "any other type"): exit 2, the message names the type, nothing is written (no main.roc, no CI file, no `projects.json`, OP8). Run 5 (`roc-lang/basic-cli` by name): the hello world template of R-IN1, not a stub, and no call that fetches or reads the platform. Run 6 (`acme/wpf --offline`, the platform release is not in the cache): exit 15, no `main.roc` (R-FE7). The case `init/it3-platform-moved` has the run for the move of the platform (answer Q4).\n')
common_fx(dst, runs, '', rules, 'roc\ncurl\ntar\n',
          '# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod (as slice 021). The first rule whose needle is in the arguments answers.\n'
          'curl --fail\t0\t-\t-\tfile:{out}\n'
          'tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details\n'
          'chmod 0755\t0\t-\t-\t-\n'
          f'version\t0\tRoc compiler version {H}\t-\t-\n',
          {'fx/mtimes': 'roc-lang/basic-cli/1.meta 1792065590\nacme/wpf/1.meta 1792065590\nacme/mov/1.meta 1792065590\nroc-lang/nightlies/1.meta 1792065590\n',
           'fx/tty': 'stdin=true\nstderr=true\n',
           'fx/units': '# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n'})
print('written', dst)

# ======================================================================================================================
# init/it3-platform-moved (answer Q4 of the review): the resolve moves the platform to an older release whose `requires` clause differs, so `init` makes the stub again.
# The world is the world of it2-platform (home7, acme/mov: 0.2.0 has an alias and a record, 0.1.0 has `main! : () => {}`). The member has `[build] target = "wasm32"` (a `talon.toml` in the directory, read as `upgrade` reads it: slice 041 Q7), and 0.2.0 has the target x64musl only, so R-C10 makes it no candidate.
dst3 = os.path.join(cases, 'init/it3-platform-moved')
shutil.rmtree(dst3, ignore_errors=True)
shutil.copytree(dst, dst3, ignore=shutil.ignore_patterns('expect', 'given'), symlinks=True)
shutil.copytree(os.path.join(dst, 'given/home7'), os.path.join(dst3, 'given/home'), symlinks=True)
put(dst3, 'fx/commands', 'cwd:t7 init --platform acme/mov\n')
put(dst3, 'given/project/t7/talon.toml', '[build]\ntarget = "wasm32"\n')
put(dst3, 'rules', 'R-IN8 R-IN2 R-IN7 R-SM2 R-C10 R-TG1 (slice 055, answer Q4 of the review): `tln init --platform acme/mov`. The platform has 2 releases. 0.2.0 (the start release: the highest version) has a `requires` clause with an alias and a record (`[Model : model] for program : { init!, update! }`). 0.1.0 has `requires {} { main! : () => {} }`. The directory has a `talon.toml` with `[build] target = "wasm32"`, and 0.2.0 has the target x64musl only: R-C10 makes it no candidate, so the resolve moves the platform to 0.1.0 (wasm32, x64musl). `init` then makes the stub again from the header of 0.1.0 and writes `main.roc` again with the `pf` URL of 0.1.0 and the pin: `main! = || crash "write the app"`, with no `Model` and no `program` (a stub of 0.2.0 would not build for 0.1.0). `init` made the file, so this is no overwrite of a file of a user (R-IN7).\n')
print('written', dst3)
