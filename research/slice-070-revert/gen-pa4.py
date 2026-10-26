# Slice 070: make the L2 case patch/pa4-base-missing (R-PA13: a `base` that no release of the group has).
# Run: python3 -I research/slice-070-revert/gen-pa4.py
# It writes only tests/commands/cases/patch/pa4-base-missing (without `expect/`). The expected files come from `UPDATE=1 tests/commands/run.sh patch/pa4-base-missing`, read by hand (TW21).
import os, shutil, hashlib, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
dst = os.path.join(root, 'tests/commands/cases/patch/pa4-base-missing')
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
    return b58(hashlib.sha256(f'talon-070/{repo}/{ver}'.encode()).digest())


def url(repo, ver):
    return f'https://github.com/acme/{repo}/releases/download/{ver}/{hash_of(repo, ver)}.tar.zst'


shutil.rmtree(dst, ignore_errors=True)


def put(rel, data):
    p = os.path.join(dst, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'wb' if isinstance(data, bytes) else 'w').write(data)


# The cache has the platform and json 2.2.0 (the header release): the pick reads their headers. It has no `packages/<base>`: the base is the hash of a json 2.1.5 that no release of the list has.
HPF, HA, HX = hash_of('pf', '0.1.0'), hash_of('json', '2.2.0'), hash_of('json', '2.1.5')
put(f'given/home/.cache/roc/packages/{HPF}/main.roc', PLATFORM)
put(f'given/home/.cache/roc/packages/{HA}/main.roc', 'package [Json] {}\n')
put(f'given/home/.cache/roc/packages/{HA}/Json.roc', 'top\n')
rels = [('2.1.0', '2026-09-25'), ('2.2.0', '2026-10-01'), ('2.3.0', '2026-10-05')]
items = []
for ver, day in rels:
    h = hash_of('json', ver)
    items.append({'tag_name': ver, 'draft': False, 'prerelease': False, 'published_at': day + 'T12:00:00Z',
                  'assets': [{'name': h + '.tar.zst', 'size': 1000, 'browser_download_url': url('json', ver)}]})
put('fx/http/api.github.com/repos/acme/json/releases?per_page=100', json.dumps(items, separators=(',', ':')))
put('given/project/p1/main.roc', f'app [main!] {{\n\tpf: platform "{url("pf", "0.1.0")}",\n\tjson: "{url("json", "2.2.0")}",\n\troc: "{H}",\n}}\n\nmain! = |_args| Ok({{}})\n')
put('given/project/p1/talon.toml', f'[patch]\njson = {{ path = "./.talon/patches/json/main.roc", base = "{HX}" }}\n')
put('given/project/p1/.talon/patches/json/main.roc', 'package [Json] {}\n')
put('given/project/p1/.talon/patches/json/Json.roc', 'top patched\n')
runs = [
    ('install --offline --file p1/main.roc', 'R-PA13, R-DI12: the base is not in the cache and the release list has no cached page: exit 15'),
    ('install --file p1/main.roc', 'R-PA13: the list is read (live, and cached), no release of the group has the base: exit 14'),
    ('install --offline --file p1/main.roc', 'R-PA13: the cached list, the same exit 14, with the line `index: cached at <time>`'),
]
put('entry', 'commands\n')
put('fx/commands', '\n'.join(f'# {c}\n{r}' for r, c in runs) + '\n')
put('fx/env', 'HOME={w}/home\nTALON_NOW=' + NOW + '\nCI=true\n')
put('fx/gitdirs', '.\n')
put('fx/mtimes', 'acme/json/1.meta 1792065000\n')
put('fx/programs', 'roc\n')
put('fx/jobs', f'version\t0\tRoc compiler version {H}\t-\t-\n')
put('fx/path-roc', '# slice 022b: a tln of 5000 bytes and a roc of 1000 bytes. The sizes differ, so no file is hashed.\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
rules = os.path.join(root, 'research/slice-070-revert/pa4-rules.txt')
put('rules', open(rules).read() if os.path.exists(rules) else 'R-PA13\n')
print('written', dst, 'HX', HX, 'HA', HA)
