# Slice 042: make the L2 case patch/pa1-flow (tln patch). Run: python3 -I research/slice-042-revert/gen-pa.py
# It writes only tests/commands/cases/patch/pa1-flow (without `expect/`). The expected files come from `UPDATE=1 tests/commands/run.sh patch/pa1-flow` (TW21), read by hand.
import os, shutil, hashlib

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
dst = os.path.join(root, 'tests/commands/cases/patch/pa1-flow')
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
NOW = '2026-10-15T12:00:00Z'


def b58(data):
    n = int.from_bytes(data, 'big')
    out = ''
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


def hash_of(owner, repo, ver):
    return b58(hashlib.sha256(f'talon-042/{owner}/{repo}/{ver}'.encode()).digest())


def url(owner, repo, ver):
    return f'https://github.com/{owner}/{repo}/releases/download/{ver}/{hash_of(owner, repo, ver)}.tar.zst'


PF = url('acme', 'pf', '0.1.0')
JSON = url('acme', 'json', '2.1.0')
PARSER = url('acme', 'parser', '1.0.0')
HJ = hash_of('acme', 'json', '2.1.0')
HP = hash_of('acme', 'parser', '1.0.0')
HPF = hash_of('acme', 'pf', '0.1.0')
FOREIGN = 'https://example.org/archive/main.tar.gz'
PIN = 'nightly-2026-10-14-38a3029'
PLATFORM = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'

shutil.rmtree(dst, ignore_errors=True)


def put(rel, data):
    p = os.path.join(dst, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'wb' if isinstance(data, bytes) else 'w').write(data)


def header(entries):
    body = ''.join(f'\t{k}: {v},\n' for k, v in entries)
    return f'app [main!] {{\n{body}\troc: "{PIN}",\n}}\n\nmain! = |_args| Ok({{}})\n'


def platform(alias='pf'):
    return (alias, f'platform "{PF}"')


# The package acme/json 2.1.0, in the roc cache. Its files have the edge cases of a diff.
j = lambda n: ''.join(f'j{i:02d}\n' for i in range(1, n + 1))
BASE = {
    'main.roc': 'package [Json] {}\n',
    'Json.roc': j(30),
    'Inner/Deep.roc': '# deep\nx = 1\n',
    'Inner/Gone.roc': '# gone\n',
    'Old.roc': '# old\nold = 1\n',
    'data.bin': b'\xff\xfe\x00\x01DATA',
    'keep.bin': b'\xc3\x28',
    'empty.txt': '',
    'notes.txt': 'last line',
    'tail.txt': 'a\nb\nc',
    'shrink.txt': 'x\ny\n',
}
# The copy of p3: edited, added and deleted files.
json_lines = j(30).split('\n')[:-1]
edited = []
for i, line in enumerate(json_lines, 1):
    if i == 3:
        edited.append('j03 patched')
    elif i == 4:
        pass
    elif i == 28:
        edited.append('j28 patched')
    else:
        edited.append(line)
    if i == 15:
        edited.append('j15 new line after')
COPY = {
    'main.roc': 'package [Json, New] {}\n',
    'Json.roc': '\n'.join(edited) + '\n',
    'Inner/Deep.roc': '# deep\nx = 1\n',
    'Inner/New/Leaf.roc': 'leaf\n',
    'New.roc': '# new\nnew = 1\n',
    'data.bin': b'\xff\xfe\x00\x02DATA',
    'keep.bin': b'\xc3\x28',
    'new.bin': b'\x80\x81',
    'added_empty.txt': '',
    'empty.txt': 'now has text\n',
    'notes.txt': 'last line\n',
    'tail.txt': 'a\nX\nc',
    'shrink.txt': '',
}

# The cache of the home: the platform, acme/json 2.1.0. acme/parser 1.0.0 is not there: run 7 fetches it.
put(f'given/home/.cache/roc/packages/{HPF}/main.roc', PLATFORM)
for rel, data in BASE.items():
    put(f'given/home/.cache/roc/packages/{HJ}/{rel}', data)

# p1: no talon.toml. The entries: the platform, a release, a path entry (ut), a foreign URL.
put('given/project/p1/main.roc', header([platform(), ('json', f'"{JSON}"'), ('util', '"../ut/main.roc"'), ('src', f'"{FOREIGN}"')]).replace(f'"{JSON}"', f'"{JSON}"'))
put('given/project/ut/main.roc', 'package [] {}\n')
# p2: a talon.toml with comments and tables. The parser is fetched, then json is added to the same table.
put('given/project/p2/main.roc', header([platform(), ('parser', f'"{PARSER}"'), ('json', f'"{JSON}"')]))
put('given/project/p2/talon.toml', '# our intent\n[dependencies]\npf = "0.1.*"\nparser = "^1"   # the parser\n\n[resolution]\nstrategy = "lowest"\n')
# p3: a patch with edits. The copy is in .talon/patches/json, the base is the cached acme/json 2.1.0.
put('given/project/p3/main.roc', header([platform(), ('json', f'"{JSON}"')]))
put('given/project/p3/talon.toml', f'[patch]\njson = {{ path = "./.talon/patches/json/main.roc", base = "{HJ}" }}\n')
for rel, data in COPY.items():
    put(f'given/project/p3/.talon/patches/json/{rel}', data)
# p4: a talon.toml with no [patch], for --json
put('given/project/p4/main.roc', header([platform(), ('json', f'"{JSON}"')]))
put('given/project/p4/talon.toml', '[dependencies]\njson = "^2"\n')
# p5: a talon.toml with no [patch] key, for --diff (question Q1). p6: a [patch] entry whose copy dir is missing.
put('given/project/p5/main.roc', header([platform(), ('json', f'"{JSON}"')]))
put('given/project/p5/talon.toml', '[dependencies]\njson = "^2"\n')
put('given/project/p6/main.roc', header([platform(), ('json', f'"{JSON}"')]))
put('given/project/p6/talon.toml', f'[patch]\njson = {{ path = "./.talon/patches/json/main.roc", base = "{HJ}" }}\n')
# p7: a [patch] entry whose base package is not in the cache (and is not the hash of the header entry): the base dir is missing (Environment failure, slice 042 gap).
put('given/project/p7/main.roc', header([platform(), ('json', f'"{JSON}"')]))
put('given/project/p7/talon.toml', '[patch]\njson = { path = "./.talon/patches/json/main.roc", base = "5ARuaVcDBLCvdGSxpt3tqEmRV5fLaaqjQLcFjt2jJWgq" }\n')
put('given/project/p7/.talon/patches/json/main.roc', 'package [] {}\n')

runs = [
    'patch json --file p1/main.roc',
    'patch json --file p1/main.roc',
    'patch pf --file p1/main.roc',
    'patch util --file p1/main.roc',
    'patch src --file p1/main.roc',
    'list --file p1/main.roc',
    'patch parser --file p2/main.roc',
    'patch json --file p2/main.roc',
    'patch parser --diff --file p2/main.roc',
    'patch json --diff --file p3/main.roc',
    'patch json --diff --json --file p3/main.roc',
    'patch json --json --file p4/main.roc',
    'patch json --diff --file p5/main.roc',
    'patch json --diff --file p6/main.roc',
    'patch json --diff --file p7/main.roc',
]
put('entry', 'commands\n')
put('fx/commands', '\n'.join(runs) + '\n')
put('fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\n')
put('fx/gitdirs', '.\n')
put('fx/programs', 'curl\n')
put('fx/jobs', '# run 7: the fetch of acme/parser 1.0.0 (R-PA1: the package is not in the cache). The first rule whose needle is in the arguments answers.\n'
    f'unbundle {HP}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{HP};file:{{cwd}}/{HP}/main.roc;file:{{cwd}}/{HP}/Parse.roc\n'
    f'{HP}.tar.zst\t0\t-\t-\tfile:{{w}}/home/.cache/roc/packages/{HP}.0123456789abcdef.tmp/{HP}.tar.zst\n')
print('written', dst)
print('HJ', HJ, 'HP', HP)
