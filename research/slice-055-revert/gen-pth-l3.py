# Slice 055: make the L3 scenario path/pt1-entry (the real `tln` and the real Fx: R-PTH1, R-PTH2 offline, R-PTH3, R-PTH4, R-EC2).
# Run: python3 -I research/slice-055-revert/gen-pth-l3.py   It writes only tests/scenarios/path/pt1-entry (without `expect/`: `UPDATE=1 tests/run.sh path/`, TW21).
import os, shutil, hashlib

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'


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


dst = os.path.join(root, 'tests/scenarios/path/pt1-entry')
shutil.rmtree(dst, ignore_errors=True)
PF = url('acme', 'pf', '0.2.0')
JSON = url('acme', 'json', '2.1.0')
HP = hash_of('acme', 'pf', '0.2.0')
put(dst, f'given/home/.cache/roc/packages/{HP}/main.roc', 'platform "acme-pf"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n')
put(dst, 'given/project/main.roc',
    f'app [main!] {{\n\tpf: platform "{PF}",\n\tjson: "{JSON}",\n\tlib: "../shared/lib/main.roc",\n\todd: "https://example.com/pkg/{{v}}/x.tar.zst",\n}}\n\nmain! = |_args| Ok({{}})\n')
put(dst, 'given/env', 'TALON_NOW=2026-10-15T12:00:00Z\n')
put(dst, 'cmd', '''# R-CM25 R-PTH1 R-PTH2 R-PTH3 R-PTH4 R-EC2 R-J1 (slice 055): `tln path` on the real binary and the real Fx. The package pf is in the cache, the package json is not (the network is off).
st() { echo "== $*"; if "$@"; then echo "exit 0"; else echo "exit $?"; fi; }
# a release entry in the cache: one line, the packages dir of the run (R-PTH1, R-CR1)
st tln path pf
# a path entry: the directory of its file, seen from the project (the directory does not exist, R-PTH5)
st tln path lib
# --json: the envelope
st tln path pf --json
# R-PTH3: a foreign URL and an unknown alias are exit 2. No alias: exit 2.
st tln path odd
st tln path nope
st tln path
# R-PTH2: the package is missing and --offline: exit 15
st tln path json --offline
echo "== the project is not changed"
cat main.roc
''')
print('written', dst)
