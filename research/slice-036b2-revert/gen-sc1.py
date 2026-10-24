# Slice 036b2: make the L2 case probe/sc1-scan (the used-module scan in the oracle loop, B10, Q7).
# Run: python3 -I research/slice-036b2-revert/gen-sc1.py
# The case reuses the packages, the index and the config of probe/un1-units.
import os, shutil
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/probe')
src, dst = os.path.join(cases, 'un1-units'), os.path.join(cases, 'sc1-scan')
shutil.rmtree(dst, ignore_errors=True)
os.makedirs(dst + '/fx')
shutil.copytree(src + '/given/home', dst + '/given/home', symlinks=True)
shutil.copytree(src + '/fx/http', dst + '/fx/http')
shutil.copy(src + '/fx/gitdirs', dst + '/fx/gitdirs')
open(dst + '/entry', 'w').write('resolve\n')
open(dst + '/fx/env', 'w').write('HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n')

PF = 'https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst'
J0 = 'https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst'
PA = 'https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst'
H21 = '4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq'   # json 2.1.0
HP12 = 'EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt'  # parser 1.2.0
FAIL = '../fixtures/check/out/unit-fail.stderr'          # a fail in Yaml.roc of the package dir
# parser 1.2.0 has the modules Parser.roc and Yaml.roc (the app of p3 imports Parser)
pk = dst + '/given/home/.cache/roc/packages/' + HP12
open(pk + '/Parser.roc', 'w').write('module [parse]\n\nparse = 1\n')
open(pk + '/Yaml.roc', 'w').write('module [yaml]\n\nyaml = 1\n')
# a unit fail in main.roc of the package, and a new error in parser 1.2.0 for the whole-app check
fail = open(os.path.join(root, 'tests/fixtures/check/out/unit-fail.stderr')).read()
open(dst + '/fx/unit-main.stderr', 'w').write(fail.replace('Yaml.roc:5:12', 'main.roc:5:12'))
new = open(os.path.join(root, 'tests/fixtures/check/out/pkg-new.stderr')).read()
parser_part = '── ✗ ' + new.split('── ✗ ')[2]
open(dst + '/fx/new-parser.stderr', 'w').write(parser_part.replace('EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc', HP12).replace('2 errors and 0 warnings', '1 error and 0 warnings'))

# (name, compiler, extra talon.toml, unit rows, imports, command)
runs = [
 ('p1', 'nightly-2026-10-19-1a1a1a1', 'free-parser', [(H21, 1, '-', FAIL)], 'import json.Yaml\n\n', 'update json parser'),
 ('p2', 'nightly-2026-10-20-2b2b2b2', '', [(H21, 1, '-', 'unit-main.stderr')], 'import json.Yaml\n\n', 'update json'),
 ('p3', 'nightly-2026-10-21-3c3c3c3', 'free-parser', [(HP12, 1, '-', FAIL)], 'import parser.Parser\n\n', 'update json parser'),
 ('p4', 'nightly-2026-10-22-4d4d4d4', 'free-parser', [], '', 'update json@2.2.0 parser'),
 ('p5', 'nightly-2026-10-23-5e5e5e5', 'free-parser', [(H21, 1, '-', FAIL), (HP12, 1, '-', FAIL)], 'import json.Yaml\n\n', 'update json parser'),
]
runs_f, units_f = [], []
for name, comp, extra, units, imp, cmd in runs:
    d = f'{dst}/given/project/{name}'
    os.makedirs(d)
    open(d + '/main.roc', 'w').write(f'app [main!] {{\n\tpf: platform "{PF}",\n\tjson: "{J0}",\n\tparser: "{PA}",\n\troc: "{comp}",\n}}\n\n{imp}main! = |_args| Ok({{}})\n')
    toml = '[dependencies]\npf = "acme/pf@=0.1.0"\n' + ('' if extra == 'free-parser' else 'parser = "acme/parser@=1.0.0"\n')
    open(d + '/talon.toml', 'w').write(toml)
    runs_f.append(f'{cmd} file={name}/main.roc compiler={comp}')
    for h, code, out, err in units:
        units_f.append(f'{h}:{comp}\t{code}\t{out}\t{err}')
shutil.copy(os.path.join(root, 'research/slice-036b2-revert/sc1-rules.txt'), dst + '/rules')
open(dst + '/fx/runs', 'w').write('\n'.join(runs_f) + '\n')
open(dst + '/fx/units', 'w').write('# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n' + '\n'.join(units_f) + '\n')
shutil.copy(os.path.join(root, 'research/slice-036b2-revert/sc1-probes.txt'), dst + '/fx/probes')
