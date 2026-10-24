# Slice 036c: make the L2 case probe/dm1-domain (the compiler list D in the oracle loop, R-EP10, R-EP11, R-RP2, R-EP9).
# Run: python3 -I research/slice-036c-revert/gen-dm1.py
# The case reuses the packages, the index and the config of probe/lp1-loop, and adds a list of 10 compilers (fx/http, roc-lang/nightlies).
import os, shutil
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/probe')
src, dst = os.path.join(cases, 'lp1-loop'), os.path.join(cases, 'dm1-domain')
shutil.rmtree(dst, ignore_errors=True)
os.makedirs(dst + '/fx')
shutil.copytree(src + '/given/home', dst + '/given/home', symlinks=True)
shutil.copytree(src + '/fx/http', dst + '/fx/http')
for f in ('gitdirs', 'unit-foreign.stderr', 'env'):
    shutil.copy(src + '/fx/' + f, dst + '/fx/' + f)
open(dst + '/entry', 'w').write('resolve\n')

PF = 'https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst'
J0 = 'https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst'
PA = 'https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst'
H21 = '4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq'   # json 2.1.0
HPF = '895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw'   # pf 0.1.0
HPA = 'EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc'   # parser 1.0.0

# D: 10 compilers, oldest first (the file lists the newest first, as GitHub does)
def sha_of(i):
    return (f'{i % 10}' + 'abcdef'[i % 6]) * 3 + f'{i % 10}'
D = [f'nightly-2026-10-{i:02d}-{sha_of(i)}' for i in range(1, 11)]
N = {i + 1: D[i] for i in range(10)}
NOT_IN_D = 'nightly-2026-10-12-9a9a9a9'
items = []
for i in range(10, 0, -1):
    tag = N[i]
    date = f'2026-10-{i:02d}'
    sha = tag.split('-')[-1]
    name = f'roc_nightly-linux_x86_64-{date}-{sha}.tar.gz'
    digest = f'{i:x}' * 64
    items.append('{"tag_name":"%s","draft":false,"prerelease":false,"published_at":"%sT15:00:00Z","assets":[{"name":"%s","size":7300000%d,"digest":"sha256:%s","browser_download_url":"https://github.com/roc-lang/nightlies/releases/download/%s/%s"}]}' % (tag, date, name, i % 10, digest, tag, name))
nd = dst + '/fx/http/api.github.com/repos/roc-lang/nightlies'
os.makedirs(nd, exist_ok=True)
open(nd + '/releases?per_page=100', 'w').write('[\n' + ',\n'.join(items) + '\n]\n')

FAIL1 = 'unit-foreign.stderr'
# the db: zone A (the held compiler n3): json 2.1.0 fails on n2, n4, n5 (n3 is probed), passes on n1 (but pf and parser have no row there) and on n6 (all 3 packages pass).
# zone B (the held compiler n8): json 2.1.0 fails on n7 and n9, n8 has no row (R-EP6 case b: the inferred fail).
db = []
def row(h, n, outcome):
    db.append(f'fact\t{h}\t{N[n]}\tany\t{outcome}\t\t')
row(H21, 1, 'pass')
for n in (2, 4, 5, 7, 9):
    row(H21, n, 'fail')
for h in (H21, HPF, HPA):
    row(h, 6, 'pass')

# (name, held compiler, flags, talon.toml head, unit rows)
# p1: online, D read, the interval n2 .. n5 and the hint n6 (n1 has the pass of json only: the header value of pf has no assumed pass on n1, D2 revisit).
# p2: the same with a compiler outside the list: D is [H], no interval, no hint.
# p3: --no-probe: n7 and n9 fail, n8 is inferred (R-EP9): the failure names the inferred compiler.
# p4: --no-probe, json is already 2.1.0: nothing to look up, D is not read.
# p5: offline, the list is in the cache (the runs before read it): D is read from the cache.
runs = [
 ('p1', N[3], '', [(H21, 1, '-', FAIL1)], 'update json', 'json 2.0.0'),
 ('p2', NOT_IN_D, '', [(H21, 1, '-', FAIL1)], 'update json', 'json 2.0.0'),
 ('p3', N[8], ' no-probe', [], 'update json', 'json 2.0.0'),
 ('p4', N[8], ' no-probe', [], 'update json', 'json 2.1.0'),
 ('p5', N[10], ' offline', [(H21, 1, '-', FAIL1)], 'update json', 'json 2.0.0'),
]
runs_f, units_f = [], []
for name, comp, flags, units, cmd, kind in runs:
    d = f'{dst}/given/project/{name}'
    os.makedirs(d)
    cur = J0 if kind == 'json 2.0.0' else J0.replace('/2.0.0/', '/2.1.0/').replace('7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21', H21)
    open(d + '/main.roc', 'w').write(f'app [main!] {{\n\tpf: platform "{PF}",\n\tjson: "{cur}",\n\tparser: "{PA}",\n\troc: "{comp}",\n}}\n\nmain! = |_args| Ok({{}})\n')
    open(d + '/talon.toml', 'w').write('[overrides]\njson = "acme/json@=2.1.0"\n\n[dependencies]\npf = "acme/pf@=0.1.0"\nparser = "acme/parser@=1.0.0"\n')
    runs_f.append(f'{cmd} file={name}/main.roc{flags} compiler={comp}')
    for h, code, out, err in units:
        units_f.append(f'{h}:{comp}\t{code}\t{out}\t{err}')
shutil.copy(os.path.join(root, 'research/slice-036c-revert/dm1-rules.txt'), dst + '/rules')
open(dst + '/fx/runs', 'w').write('\n'.join(runs_f) + '\n')
open(dst + '/fx/units', 'w').write('# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n' + '\n'.join(units_f) + '\n')
# the cache time of a page is the real mtime of its `.meta` file: fix it, so the line `index: cached at ...` of the offline run is the same each time
open(dst + '/fx/mtimes', 'w').write('acme/json/1.meta 1792065590\nroc-lang/nightlies/1.meta 1792065590\n')
open(dst + '/fx/probes', 'w').write('# no probe other than the unit probes runs in this case\n')
os.makedirs(dst + '/given/home/.cache/roc/talon', exist_ok=True)
open(dst + '/given/home/.cache/roc/talon/compat.tsv', 'w').write('format\t1\n' + '\n'.join(db) + '\n')
