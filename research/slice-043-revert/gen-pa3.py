# Slice 043 (gap row): make the L2 case patch/pa3-buildfail (a patched entry in the commands that resolve: R-PA4, R-PA5, R-PA6, R-PA10).
# Run: python3 -I research/slice-043-revert/gen-pa2.py
# It writes only tests/commands/cases/patch/pa3-buildfail (without `expect/`). The expected files come from `UPDATE=1 tests/commands/run.sh patch/pa2-resolve` (TW21), read by hand.
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
dst = os.path.join(root, 'tests/commands/cases/patch/pa3-buildfail')
ALPHA = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
NOW = '2026-10-15T12:00:00Z'
H = 'nightly-2026-10-14-38a3029'
PLATFORM = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'


def b58(data):
    n = int.from_bytes(data, 'big')
    out = ''
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


def hash_of(repo, ver):
    return b58(hashlib.sha256(f'talon-043/{repo}/{ver}'.encode()).digest())


def url(repo, ver):
    return f'https://github.com/acme/{repo}/releases/download/{ver}/{hash_of(repo, ver)}.tar.zst'


shutil.rmtree(dst, ignore_errors=True)


def put(rel, data):
    p = os.path.join(dst, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'wb' if isinstance(data, bytes) else 'w').write(data)


# ---- the packages. acme/json 2.1.0 is the base of the patch. 2.2.0 takes the diff (3 lines at the top: the hunks move). 2.3.0 does not (3 files).
j = lambda n: [f'j{i:02d}\n' for i in range(1, n + 1)]
BASE = {
    'main.roc': 'package [Json] {}\n',
    'Json.roc': ''.join(j(30)),
    'Old.roc': '# old\nold = 1\n',
    'Inner/Deep.roc': '# deep\nx = 1\n',
    'data.bin': b'\xff\xfe\x00\x01DATA',
}
PATCHED = dict(BASE)
lines = j(30)
lines[2] = 'j03 patched\n'
lines[27] = 'j28 patched\n'
PATCHED['Json.roc'] = ''.join(lines)
del PATCHED['Old.roc']
PATCHED['New.roc'] = '# new\nnew = 1\n'
PATCHED['data.bin'] = b'\xff\xfe\x00\x02DATA'
V22 = dict(BASE)
V22['Json.roc'] = 'top1\ntop2\ntop3\n' + ''.join(j(30))
V22['Extra.roc'] = '# extra\n'
V23 = dict(BASE)
lines = j(30)
lines[2] = 'j03 upstream\n'
V23['Json.roc'] = ''.join(lines)
V23['Old.roc'] = '# old\nold = 2\n'
V23['data.bin'] = b'\xff\xfe\x00\x03DATA'

HB, HA, HC = hash_of('json', '2.1.0'), hash_of('json', '2.2.0'), hash_of('json', '2.3.0')
HPF = hash_of('pf', '0.1.0')
PF, J21, J22, J23 = url('pf', '0.1.0'), url('json', '2.1.0'), url('json', '2.2.0'), url('json', '2.3.0')
put(f'given/home/.cache/roc/packages/{HPF}/main.roc', PLATFORM)
for h, files in ((HB, BASE), (HA, V22), (HC, V23)):
    for rel, data in files.items():
        put(f'given/home/.cache/roc/packages/{h}/{rel}', data)
# Gap rows (slice 043, after the code): acme/util 1.0.0 for `tln add` (it is in the cache, so the add needs no fetch).
HU = hash_of('util', '1.0.0')
put(f'given/home/.cache/roc/packages/{HU}/main.roc', 'package [Util] {}\n')
put('fx/http/api.github.com/repos/acme/util/releases?per_page=100', json.dumps([{'tag_name': '1.0.0', 'draft': False, 'prerelease': False, 'published_at': '2026-08-01T12:00:00Z',
    'assets': [{'name': HU + '.tar.zst', 'size': 1000, 'browser_download_url': url('util', '1.0.0')}]}], separators=(',', ':')))
rels = [('2.1.0', '2026-09-25'), ('2.2.0', '2026-10-01'), ('2.3.0', '2026-10-05')]
items = []
for ver, day in rels:
    h = hash_of('json', ver)
    items.append({'tag_name': ver, 'draft': False, 'prerelease': False, 'published_at': day + 'T12:00:00Z',
                  'assets': [{'name': h + '.tar.zst', 'size': 1000, 'browser_download_url': url('json', ver)}]})
put('fx/http/api.github.com/repos/acme/json/releases?per_page=100', json.dumps(items, separators=(',', ':')))
put('fx/http/api.github.com/repos/acme/pf/releases?per_page=100', json.dumps([{'tag_name': '0.1.0', 'draft': False, 'prerelease': False, 'published_at': '2026-07-01T12:00:00Z',
    'assets': [{'name': HPF + '.tar.zst', 'size': 1000, 'browser_download_url': PF}]}], separators=(',', ':')))


def project(name, json_url, base=HB, toml_extra='', patch=True):
    d = f'given/project/{name}'
    put(f'{d}/main.roc', f'app [main!] {{\n\tpf: platform "{PF}",\n\tjson: "{json_url}",\n\troc: "{H}",\n}}\n\nmain! = |_args| Ok({{}})\n')
    toml = ''
    if patch:
        toml += f'[patch]\njson = {{ path = "./.talon/patches/json/main.roc", base = "{base}" }}\n'
        for rel, data in PATCHED.items():
            put(f'{d}/.talon/patches/json/{rel}', data)
    put(f'{d}/talon.toml', toml_extra + toml)


# p1: a patch on json 2.1.0 (the base is the hash of the header entry). Runs 1, 2, 3, 9 read it and write nothing.
project('p1', J21)
put('given/home/.cache/roc/talon/tmp/patch-0123456789abcdef/json/left.txt', 'a file that makes copy_tree fail with Exists\n')

runs = [
    ('update json --file p1/main.roc', 'R-CC2: the temp dir of the patch exists, so the build step fails; Talon deletes the temp root'),
]
put('entry', 'commands\n')
put('fx/commands', '\n'.join(r for r, _ in runs) + '\n')
put('fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\nCI=true\n')
put('fx/gitdirs', '.\n')
put('fx/programs', 'roc\n')
put('fx/jobs', f'version\t0\tRoc compiler version {H}\t-\t-\n')
put('fx/path-roc', '# slice 022b: a tln of 5000 bytes and a roc of 1000 bytes. The sizes differ, so no file is hashed.\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
rules = open(os.path.join(root, 'research/slice-043-revert/pa3-rules.txt')).read() if os.path.exists(os.path.join(root, 'research/slice-043-revert/pa3-rules.txt')) else 'R-PA5 R-CC2\n'
put('rules', rules)
print('written', dst)
print('HB', HB, 'HA', HA, 'HC', HC)
