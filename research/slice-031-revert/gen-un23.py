# Makes tests/commands/cases/probe/un2-remove-units and un3-verify-units (run from tests/commands/cases). The expected files come from the reference.
import os, shutil
PF='895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw'; J0='7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21'; J1='4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq'; PA='EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc'
J2='7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW'
PFX='6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL'
C='nightly-2026-10-14-38a3029'
O='../fixtures/check/out/'
def fresh(dst, src):
    shutil.rmtree(dst, ignore_errors=True)
    os.makedirs(dst+'/fx'); os.makedirs(dst+'/given/project')
    for f in os.listdir(src+'/fx'):
        if f in ('hooks','probes','probe-text') or f.startswith('probe-'): continue
        a=src+'/fx/'+f
        (shutil.copytree if os.path.isdir(a) else shutil.copy)(a, dst+'/fx/'+f)
    shutil.copytree(src+'/given/home', dst+'/given/home')
    open(dst+'/entry','w').write('commands\n')
    open(dst+'/fx/probes','w').write('')
    pk=dst+'/given/home/.cache/roc/packages/'
    os.makedirs(pk+J1,exist_ok=True)
    for h in (J0,J1,J2,PA):
        os.makedirs(pk+h,exist_ok=True)
        if not os.path.exists(pk+h+'/main.roc'): open(pk+h+'/main.roc','w').write('package [Lib] {}\n')
    open(pk+J1+'/Yaml.roc','w').write('module [yaml]\n\nimport Wire\n\nyaml = Wire.wire\n')
    open(pk+J1+'/Wire.roc','w').write('module [wire]\n\nwire = 1\n')
def header(pf, json, pin):
    return f'''app [main!] {{
	pf: platform "https://github.com/acme/{'pfx' if pf==PFX else 'pf'}/releases/download/0.1.0/{pf}.tar.zst",
	json: "https://github.com/acme/json/releases/download/{'2.1.0' if json==J1 else '2.0.0'}/{json}.tar.zst",
	parser: "https://github.com/acme/parser/releases/download/1.0.0/{PA}.tar.zst",
{pin}}}

'''
def project(dst, name, pf, json, imp, pin, toml=None):
    d=f'{dst}/given/project/{name}'; os.makedirs(d)
    open(d+'/main.roc','w').write(header(pf,json,pin)+imp+('\n' if imp else '')+'main! = |_args| Ok({})\n')
    if toml is not None: open(d+'/talon.toml','w').write(toml)
# un2: remove
d='probe/un2-remove-units'
fresh(d,'remove/rm1-flow')
pin=f'\troc: "{C}",\n'
t='[dependencies]\n'
project(d,'p1',PF,J0,'',pin,t); project(d,'p2',PF,J0,'',pin,t); project(d,'p3',PF,J1,'import json.Yaml\n',pin,t); project(d,'p4',PF,J1,'import json.Yaml\n',pin,t); project(d,'p5',PF,J2,'',pin,t)
open(d+'/fx/commands','w').write('remove parser --file p1/main.roc\nremove parser --file p2/main.roc\nremove parser --file p3/main.roc\nremove parser --file p4/main.roc --no-probe\nremove parser --file p5/main.roc --no-probe\n')
open(d+'/fx/units','w').write(f'# <hash>[:<compiler>] <code> <stdout> <stderr>\n{J1}\t1\t-\t{O}unit-fail.stderr\n')
open(d+'/rules','w').write('''R-LD2 R-LD3 R-UM1 R-AL4 R-PP4 R-PP3 R-EF1 R-CC8 R-RV1 R-RV2 R-LF3 (slice 031, review Q3): the unit probes of `tln remove`: the closure of the header without the removed alias is walked (the headers of its packages are read), and ladder step 1 runs on its packages, as for `install` (the Fx calls are those of `probe/un1-units`).
Run 1: acme/pf and acme/json 2.0.0 have no fact: round 1 is the baseline and 2 unit probes, then one `db_write`, then the candidate check and the build. Run 2: the same packages, the facts are known: round 1 is the baseline only. Run 3: json 2.1.0 has a unit fail in Yaml.roc and the app imports json.Yaml: the scan reads Yaml.roc and Wire.roc, exit 10 with the text that `remove` adds (`tln remove moves no other entry`), the candidate check does not run. Run 4 (`--no-probe`): the fact of run 3 is known and judged, also with the flag: exit 10, no unit probe. Run 5 (`--no-probe`, another json package with no fact): round 1 is the baseline only, no `db_write`.
''')
# un3: verify
d='probe/un3-verify-units'
fresh(d,'verify/vf1-flow')
project(d,'p1',PFX,J0,'import json.Yaml\n',''); project(d,'p2',PFX,J0,'',''); project(d,'p3',PFX,J0,'import json.Yaml\n','')
open(d+'/fx/commands','w').write('verify --file p1/main.roc\nverify --file p2/main.roc\nverify --file p3/main.roc\n')
open(d+'/fx/units','w').write(f'# <hash>[:<compiler>] <code> <stdout> <stderr>\n{J1}\t1\t-\t{O}unit-fail.stderr\n')
open(d+'/rules','w').write('''R-CM11 R-LB2 R-LD2 R-LD3 R-UM1 R-AL4 R-PP4 R-PP3 R-EF1 R-LD7 (slice 031, review Q3): `tln verify` runs ladder step 1 on the packages of the tuple (`--replace-dep` candidate): round 1 is the baseline and the unit probes of the packages with no fact, then the candidate check (round 2) and the build (round 3).
Run 1: the tuple has json 2.1.0, whose unit check fails in Yaml.roc, and the app imports json.Yaml: the scan reads Yaml.roc and Wire.roc, exit 10, the candidate check does not run. Run 2: the app does not import it: the fact is known (round 1 is the baseline only), the fail is ignored (R-UM1), the check and the build pass. Run 3: the fact is known and the app imports json.Yaml: exit 10 after the baseline only.
''')
