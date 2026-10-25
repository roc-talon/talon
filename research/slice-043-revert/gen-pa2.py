# Slice 043: make the L2 case patch/pa2-resolve (a patched entry in the commands that resolve: R-PA4, R-PA5, R-PA6, R-PA10).
# Run: python3 -I research/slice-043-revert/gen-pa2.py
# It writes only tests/commands/cases/patch/pa2-resolve (without `expect/`). The expected files come from `UPDATE=1 tests/commands/run.sh patch/pa2-resolve` (TW21), read by hand.
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
dst = os.path.join(root, 'tests/commands/cases/patch/pa2-resolve')
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
project('p2', J21)
project('p3', J21, toml_extra='[dependencies]\njson = "^2.1"\n\n')
project('p4', J21)
project('p5', J22)   # stale: the header was edited by hand to 2.2.0, the base is 2.1.0
project('p6', J22)
project('p7', J21)
project('p8', J21)   # run 11: an editor changes the base of the [patch] entry while the probes run
project('p9', J21, toml_extra='# keep\n')   # run 12: an editor changes a comment of talon.toml while the probes run
project('p10', J22)  # gap row: a stale patch, and `tln add` of another package does not rebase it (Q6)

runs = [
    ('update --file p1/main.roc', 'R-PA4: update holds the patched entry'),
    ('upgrade --file p1/main.roc', 'R-PA4: upgrade holds it too'),
    ('install --file p1/main.roc', 'R-PA6: the base is the hash: nothing to rebase'),
    ('update json --file p2/main.roc', 'R-PA5: json 2.3.0 does not take the diff; json 2.2.0 does'),
    ('update json@^2.3 --file p3/main.roc', 'R-PA5: no release is left: exit 10'),
    ('update json --dry-run --file p4/main.roc', 'R-LF4 with a patch'),
    ('install --frozen --file p5/main.roc', 'R-PA6: exit 14'),
    ('install --file p6/main.roc', 'R-PA6: tln install applies the patch to the header release'),
    ('verify --file p1/main.roc', 'R-PA10: the probes of verify'),
    ('update json --no-check --file p7/main.roc', 'R-PA5 with --no-check'),
    ('update json --file p8/main.roc', 'R-CC7: the editor changes the [patch] entry: exit 17, nothing is written'),
    ('update json --file p9/main.roc', 'R-CC7: the editor changes a comment: Talon applies its edit to the new text'),
    ('add acme/util --no-check --file p10/main.roc', 'Q6: add does not rebase a stale patch'),
]
put('entry', 'commands\n')
put('fx/commands', '\n'.join(r for r, _ in runs) + '\n')
put('fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\nCI=true\n')
put('fx/gitdirs', '.\n')
# Slice 043 (R-CC7): the hooks count the `probes` calls of all runs. Runs 1 to 10 make 9 calls. Run 11 makes 2 (the baseline and the candidate check: the conflict stops it before the build), so the 1st call of run 12 is the 12th.
put('fx/hooks', f'after-probes\t10\tproject/p8/talon.toml\tbase = "{HB}"\tbase = "{HC}"\nafter-probes\t12\tproject/p9/talon.toml\t# keep\t# kept by the editor\n')
put('fx/programs', 'roc\n')
put('fx/jobs', f'version\t0\tRoc compiler version {H}\t-\t-\n')
put('fx/path-roc', '# slice 022b: a tln of 5000 bytes and a roc of 1000 bytes. The sizes differ, so no file is hashed.\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
rules = open(os.path.join(root, 'research/slice-043-revert/pa2-rules.txt')).read() if os.path.exists(os.path.join(root, 'research/slice-043-revert/pa2-rules.txt')) else 'R-PA4 R-PA5 R-PA6 R-PA10\n'
put('rules', rules)
print('written', dst)
print('HB', HB, 'HA', HA, 'HC', HC)
