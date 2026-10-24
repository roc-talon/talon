# Slice 036b: make the L2 case probe/lp1-loop (the loop of the probe rounds). Run: python3 -I research/slice-036b-revert/gen-lp1.py
# The case reuses the packages, the index and the config of probe/un1-units.
import os, shutil
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/probe')
src, dst = os.path.join(cases, 'un1-units'), os.path.join(cases, 'lp1-loop')
shutil.rmtree(dst, ignore_errors=True)
os.makedirs(dst + '/fx')
shutil.copytree(src + '/given/home', dst + '/given/home', symlinks=True)
shutil.copytree(src + '/fx/http', dst + '/fx/http')
for f in ('gitdirs', 'unit-foreign.stderr'):
    shutil.copy(src + '/fx/' + f, dst + '/fx/' + f)
open(dst + '/entry', 'w').write('resolve\n')
open(dst + '/fx/env', 'w').write('HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n')

PF = 'https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst'
J0 = 'https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst'
PA = 'https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst'
H21 = '4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq'
FAIL = '../fixtures/check/out/unit-fail.stderr'
# (name, compiler, extra flags, talon.toml extra, unit rows, db rows, imports)
runs = [
 ('p1', 'nightly-2026-10-02-a1a1a1a', '', '', [], [], ''),
 ('p2', 'nightly-2026-10-03-b2b2b2b', '', '', [], [], ''),
 ('p11', 'nightly-2026-10-12-e1e1e1e', ' dry-run', '[FREE-PARSER]', [], [], ''),
 ('p12', 'nightly-2026-10-13-f2f2f2f', '', '\n[resolution]\nprobe = { max = 5 }\n', [], [], ''),
 ('p3', 'nightly-2026-10-04-c3c3c3c', '', '', [(H21, 1, '-', 'unit-foreign.stderr')], [], ''),
 ('p4', 'nightly-2026-10-05-d4d4d4d', '', '', [(H21, 'signal:11', '-', '-')], [], ''),
 ('p5', 'nightly-2026-10-06-e5e5e5e', '', '', [(H21, 1, '-', FAIL)], [], ''),
 ('p6', 'nightly-2026-10-07-f6f6f6f', ' no-probe', '', [], [(H21, 'fail', '')], ''),
 ('p7', 'nightly-2026-10-08-a7a7a7a', ' no-probe', '', [], [], ''),
 ('p8', 'nightly-2026-10-09-b8b8b8b', '', '\n[resolution]\nprobe = { max = 1 }\n', [(H21, 1, '-', 'unit-foreign.stderr')], [], ''),
 ('p9', 'nightly-2026-10-10-c9c9c9c', '', '[OVERRIDE]', [(H21, 1, '-', 'unit-foreign.stderr')], [], ''),
 ('p10', 'nightly-2026-10-11-d0d0d0d', ' no-check', '', [], [(H21, 'fail', '')], ''),
]
runs_f, units_f, tsv = [], [], ['format\t1']
for name, comp, flags, extra, units, db, imp in runs:
    d = f'{dst}/given/project/{name}'
    os.makedirs(d)
    open(d + '/main.roc', 'w').write(f'app [main!] {{\n\tpf: platform "{PF}",\n\tjson: "{J0}",\n\tparser: "{PA}",\n\troc: "{comp}",\n}}\n\n{imp}main! = |_args| Ok({{}})\n')
    toml = '[dependencies]\npf = "acme/pf@=0.1.0"\nparser = "acme/parser@=1.0.0"\n'
    if extra == '[FREE-PARSER]':
        toml, extra = '[dependencies]\npf = "acme/pf@=0.1.0"\n', ''
    if extra == '[OVERRIDE]':
        toml = '[overrides]\njson = "acme/json@=2.1.0"\n\n' + toml
    else:
        toml += extra
    open(d + '/talon.toml', 'w').write(toml)
    names = 'json parser' if name == 'p11' else 'json'
    runs_f.append(f'update {names} file={name}/main.roc{flags} compiler={comp}')
    for h, code, out, err in units:
        units_f.append(f'{h}:{comp}\t{code}\t{out}\t{err}')
    for h, outcome, mods in db:
        tsv.append(f'fact\t{h}\t{comp}\tany\t{outcome}\t{mods}\t')
shutil.copy(os.path.join(root, 'research/slice-036b-revert/lp1-rules.txt'), dst + '/rules')
open(dst + '/fx/runs', 'w').write('\n'.join(runs_f) + '\n')
open(dst + '/fx/units', 'w').write('# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n' + '\n'.join(units_f) + '\n')
os.makedirs(dst + '/given/home/.cache/roc/talon', exist_ok=True)
open(dst + '/given/home/.cache/roc/talon/compat.tsv', 'w').write('\n'.join(tsv) + '\n')
open(dst + '/fx/probes', 'w').write(
'# run 1: the unit check of json 2.1.0 passes, the whole-app check finds a new error in acme/json 2.1.0 (a named release): the loop drops 2.1.0 and the ladder runs on json 2.0.5 (rows 3 to 5: no row, they pass)\n'
'1\t../fixtures/check/out/pkg-base.stdout\t../fixtures/check/out/pkg-base.stderr\n'
'1\t../fixtures/check/out/pkg-new.stdout\t../fixtures/check/out/pkg-new.stderr\n'
'# row 3 to 5: the ladder on json 2.0.5 passes\n'
'0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n'
'0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n'
'0\t../fixtures/check/out/build-pass.stdout\t../fixtures/check/out/build-pass.stderr\n'
'# run 2: the whole-app check crashes (no release is named): the loop drops the whole tuple and the ladder runs on json 2.0.5 (rows 8 to 10)\n'
'0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n'
'signal:11\t-\t-\n'
'# rows 8 to 10: the ladder on json 2.0.5 passes\n'
'0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n'
'0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n'
'0\t../fixtures/check/out/build-pass.stdout\t../fixtures/check/out/build-pass.stderr\n'
'# run 3 (named blame, 2 free groups): json 2.1.0 with parser 1.2.0 is the first tuple, its check has a new error in acme/json 2.1.0 (the baseline has the error of acme/parser). The conflict is on json 2.1.0, so the next tuple is json 2.0.5 with parser 1.2.0 (rows 13 to 15: no row, they pass)\n'
'1\t../fixtures/check/out/pkg-base.stdout\t../fixtures/check/out/pkg-base.stderr\n'
'1\t../fixtures/check/out/pkg-new.stdout\t../fixtures/check/out/pkg-new.stderr\n'
'# rows 13 to 15: the ladder on json 2.0.5 passes\n'
'0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n'
'0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n'
'0\t../fixtures/check/out/build-pass.stdout\t../fixtures/check/out/build-pass.stderr\n'
'# run 4 (the budget counts the probes of the dropped tuple): probe.max is 5: the loop probe (1), the baseline and the units of pf and parser (3) and the check (1) are 5. The check fails with a new error in acme/json 2.1.0, and the probe of json 2.0.5 in the loop has no budget left: exit 12 (rows 16 and 17)\n'
'1\t../fixtures/check/out/pkg-base.stdout\t../fixtures/check/out/pkg-base.stderr\n'
'1\t../fixtures/check/out/pkg-new.stdout\t../fixtures/check/out/pkg-new.stderr\n')
