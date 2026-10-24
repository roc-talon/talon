# Slice 036b, fix F1: make the L2 case probe/lp2-fetch (a release that is new to the machine is fetched before its probe). Run: python3 -I research/slice-036b-revert/gen-lp2.py
# The case reuses the packages, the index and the config of probe/un1-units. The dirs of json 2.1.0 and json 2.0.5 are not in the package cache.
import os, shutil
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases')
src, dst = os.path.join(cases, 'probe/un1-units'), os.path.join(cases, 'probe/lp2-fetch')
shutil.rmtree(dst, ignore_errors=True)
os.makedirs(dst + '/fx/pkgs')
shutil.copytree(src + '/given/home', dst + '/given/home', symlinks=True)
shutil.copytree(src + '/fx/http', dst + '/fx/http')
shutil.copy(src + '/fx/gitdirs', dst + '/fx/gitdirs')
shutil.copy(src + '/fx/unit-foreign.stderr', dst + '/fx/unit-foreign.stderr')
open(dst + '/entry', 'w').write('resolve\n')
open(dst + '/fx/env', 'w').write('HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n')
open(dst + '/fx/programs', 'w').write('roc\ncurl\n')
pk = dst + '/given/home/.cache/roc/packages/'
H21, H205 = '4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq', '8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f'
for h, name in ((H21, 'json_2.1.0'), (H205, 'json_2.0.5')):
    shutil.copy(pk + h + '/main.roc', dst + '/fx/pkgs/' + name + '.roc')
    shutil.rmtree(pk + h)
jobs = ['# The fake downloads of the packages (as slice 010). An unbundle makes the dir of the hash with the main.roc of fx/pkgs. A download makes the archive in the temp dir.',
        'version\t0\tRoc compiler version nightly-2026-10-14-38a3029\t-\t-']
for h, name in ((H21, 'json_2.1.0'), (H205, 'json_2.0.5')):
    jobs.append(f'unbundle {h}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{h};copy:{{cwd}}/{h}/main.roc={{w}}/fx/pkgs/{name}.roc')
for h, name in ((H21, 'json_2.1.0'), (H205, 'json_2.0.5')):
    jobs.append(f'{h}.tar.zst\t0\t-\t-\tfile:{{w}}/home/.cache/roc/packages/{h}.0123456789abcdef.tmp/{h}.tar.zst')
open(dst + '/fx/jobs', 'w').write('\n'.join(jobs) + '\n')
PF = 'https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst'
J0 = 'https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst'
PA = 'https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst'
runs = [('p1', 'nightly-2026-10-02-a1a1a1a'), ('p2', 'nightly-2026-10-03-b2b2b2b')]
for name, comp in runs:
    d = f'{dst}/given/project/{name}'
    os.makedirs(d)
    open(d + '/main.roc', 'w').write(f'app [main!] {{\n\tpf: platform "{PF}",\n\tjson: "{J0}",\n\tparser: "{PA}",\n\troc: "{comp}",\n}}\n\nmain! = |_args| Ok({{}})\n')
    open(d + '/talon.toml', 'w').write('[dependencies]\npf = "acme/pf@=0.1.0"\nparser = "acme/parser@=1.0.0"\n')
open(dst + '/fx/runs', 'w').write('\n'.join(f'update json file={n}/main.roc compiler={c}' for n, c in runs) + '\n')
open(dst + '/fx/units', 'w').write('# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n'
    f'{H21}:nightly-2026-10-03-b2b2b2b\t1\t-\tunit-foreign.stderr\n')
shutil.copy(os.path.join(root, 'research/slice-036b-revert/lp2-rules.txt'), dst + '/rules')
