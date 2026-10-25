# Slice 043: make the L2 case proxy/px3-patch (the proxy and the patches: R-PX5, R-PA6, R-PA10, R-PX7).
# Run: python3 -I research/slice-043-revert/gen-px3.py
# It writes only tests/commands/cases/proxy/px3-patch (without `expect/`). The expected files come from `UPDATE=1 tests/commands/run.sh proxy/px3-patch` (TW21), read by hand.
import os, shutil, hashlib

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
src = os.path.join(root, 'tests/commands/cases/proxy/px1-flow')
dst = os.path.join(root, 'tests/commands/cases/proxy/px3-patch')
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
PIN = 'nightly-2026-10-09-258ab27'


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


def project(name, toml):
    put(f'given/project/{name}/main.roc', f'app [main!] {{\n\tpf: platform "{url("pf", "0.1.0")}",\n\tjson: "{url("json", "2.1.0")}",\n\tparser: "{url("parser", "1.0.0")}",\n\troc: "{PIN}",\n}}\n\nmain! = |_args| Ok({{}})\n')
    if toml is not None:
        put(f'given/project/{name}/talon.toml', toml)


def entry(alias, base):
    return f'{alias} = {{ path = "./.talon/patches/{alias}/main.roc", base = "{base}" }}\n'


HJ, HP = hash_of('json', '2.1.0'), hash_of('parser', '1.0.0')
project('p1', '[patch]\n' + entry('json', HJ))
project('p2', '[patch]\n' + entry('parser', HP) + entry('json', HJ))
project('p3', '[patch]\n' + entry('json', hash_of('json', '2.0.0')))
project('p4', '[dependencies]\njson = "^2"\n')
runs = [
    '# R-PX5, R-PA10: one [patch] entry: --replace-dep <the URL of the header entry> <the main file of the copy> at the end of the arguments',
    '@roc check p1/main.roc',
    '# the flags come after the other arguments of the command',
    '@roc build p1/main.roc --opt=speed',
    '# the arguments after -- are for the app: the flags come before it',
    '@roc p1/main.roc -- a b',
    '# 2 entries: in the order of the [patch] table (parser, then json)',
    '@roc check p2/main.roc',
    '# R-PA6: the base is not the hash of the header entry: a stale patch. Exit 14 (frozen), the compiler does not run, and no .last-use is written',
    '@roc check p3/main.roc',
    '# R-PX7: TALON_PROXY=0 does no extra work: no check and no flag',
    '@roc check p3/main.roc env:TALON_PROXY=0',
    '# a talon.toml with no [patch]: the arguments are as they are (R-PX3)',
    '@roc check p4/main.roc',
    '# a command that has no project file: no flag (R-PX3)',
    '@roc version',
]
put('fx/commands', '\n'.join(runs) + '\n')
put('entry', 'commands\n')
rules = os.path.join(root, 'research/slice-043-revert/px3-rules.txt')
put('rules', open(rules).read() if os.path.exists(rules) else 'R-PX5 R-PA6 R-PA10 R-PX7\n')
print('written', dst)
