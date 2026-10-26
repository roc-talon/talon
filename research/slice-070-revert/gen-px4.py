# Slice 070: make the L2 case proxy/px4-patch-early (the proxy reads [patch] for every rank: R-PX5, R-PD6, R-PD7, R-WS5, R-PA6, R-PX7).
# Run: python3 -I research/slice-070-revert/gen-px4.py
# It writes only tests/commands/cases/proxy/px4-patch-early (without `expect/`). The expected files come from `UPDATE=1 tests/commands/run.sh proxy/px4-patch-early`, read by hand (TW21).
import os, shutil, hashlib

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
src = os.path.join(root, 'tests/commands/cases/proxy/px1-flow')
dst = os.path.join(root, 'tests/commands/cases/proxy/px4-patch-early')
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
PIN = 'nightly-2026-10-09-258ab27'
NT = 'nightly-2026-10-14-38a3029'


def b58(data):
    n = int.from_bytes(data, 'big')
    out = ''
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


def hash_of(repo, ver):
    return b58(hashlib.sha256(f'talon-043-px/{repo}/{ver}'.encode()).digest())


def url(repo, ver):
    return f'https://github.com/acme/{repo}/releases/download/{ver}/{hash_of(repo, ver)}.tar.zst'


shutil.rmtree(dst, ignore_errors=True)
os.makedirs(dst + '/given/project')
shutil.copytree(src + '/given/home', dst + '/given/home', symlinks=True)
os.makedirs(dst + '/fx')
for f in ('env', 'gitdirs', 'jobs', 'path-roc'):
    shutil.copy(f'{src}/fx/{f}', f'{dst}/fx/{f}')
open(dst + '/fx/exec', 'w').write('# every child ends with 0\n')


def put(rel, text):
    p = os.path.join(dst, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w').write(text)


def header(path):
    put(path, f'app [main!] {{\n\tpf: platform "{url("pf", "0.1.0")}",\n\tjson: "{url("json", "2.1.0")}",\n\tparser: "{url("parser", "1.0.0")}",\n\troc: "{PIN}",\n}}\n\nmain! = |_args| Ok({{}})\n')


def entry(alias, base, name=None):
    return f'{alias} = {{ path = "./.talon/patches/{name or alias}/main.roc", base = "{base}" }}\n'


HJ = hash_of('json', '2.1.0')
header('given/project/p1/main.roc')
put('given/project/p1/talon.toml', '[patch]\n' + entry('json', HJ))
header('given/project/p2/main.roc')
header('given/project/p3/main.roc')
put('given/project/p3/talon.toml', '[patch]\n' + entry('json', hash_of('json', '2.0.0')))
put('given/project/w/talon.toml', '[workspace]\nmembers = ["apps/*/main.roc"]\n\n[patch]\n' + entry('json', HJ, 'root'))
header('given/project/w/apps/a/main.roc')
put('given/project/w/apps/a/talon.toml', '[patch]\n' + entry('json', HJ, 'mine'))
header('given/project/w/apps/b/main.roc')
runs = [
    '# R-PX5: roc +<id> (rank 1) reads the [patch] table of the talon.toml of the target file: the flag is added. Only the project file and the talon.toml are read (no config.toml, no .roc-version)',
    f'@roc +{NT} check p1/main.roc',
    '# ROC_TOOLCHAIN (rank 2): the same',
    f'@roc check p1/main.roc env:ROC_TOOLCHAIN={NT}',
    '# R-PA6: a stale patch stops the proxy for rank 1 as for the other ranks: exit 14, no compiler, no .last-use',
    f'@roc +{NT} check p3/main.roc',
    '# no talon.toml: no patch, so no read at all (the calls are the calls of an early run before the slice) and the arguments are as they are (R-PX3)',
    f'@roc +{NT} check p2/main.roc',
    '# a member that has a talon.toml of its own (apps/a): the nearest file (R-PD6) holds the patch that counts, for the header pin (rank 3), which reads the root file too ([toolchain]) and the nearest file',
    '@roc check w/apps/a/main.roc',
    '# the same member with roc +<id>: only the file and its own talon.toml are read, the root file is not (R-WS5: no merge)',
    f'@roc +{NT} check w/apps/a/main.roc',
    '# a member with no talon.toml of its own (apps/b): the nearest file is the root file, and its patch is used',
    f'@roc +{NT} check w/apps/b/main.roc',
    '# R-PX7: TALON_PROXY=0 does no extra work, also for rank 1: no project, no read, no flag',
    f'@roc +{NT} check p1/main.roc env:TALON_PROXY=0',
]
put('fx/commands', '\n'.join(runs) + '\n')
put('entry', 'commands\n')
rules = os.path.join(root, 'research/slice-070-revert/px4-rules.txt')
put('rules', open(rules).read() if os.path.exists(rules) else 'R-PX5 R-PA6 R-PD6 R-PD7 R-WS5 R-PX7\n')
print('written', dst)
