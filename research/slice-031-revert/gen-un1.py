# Makes tests/commands/cases/probe/un1-units (run from tests/commands/cases). The case has files only: this script is the record of how they were made.
import os, shutil
src='ladder/ld-ladder-flow'
dst='probe/un1-units'
os.makedirs(dst+'/fx',exist_ok=True)
os.makedirs(dst+'/given/project',exist_ok=True)
shutil.copytree(src+'/fx/http',dst+'/fx/http',dirs_exist_ok=True)
shutil.copy(src+'/fx/gitdirs',dst+'/fx/gitdirs')
shutil.copytree(src+'/given/home',dst+'/given/home',dirs_exist_ok=True)
open(dst+'/entry','w').write('resolve\n')
C=['nightly-2026-10-14-38a3029','nightly-2026-10-09-258ab27','nightly-2026-10-10-abcdef0','nightly-2026-10-11-1a2b3c4','nightly-2026-10-12-2664a27','nightly-2026-10-13-91fa0c2','nightly-2026-10-15-38e6c42','nightly-2026-10-16-1df370f','nightly-2026-10-18-5349569','nightly-2026-10-08-0a1b2c3','nightly-2026-10-07-3f4e5d6','nightly-2026-10-17-601b54c','nightly-2026-10-05-9f8e7d6','nightly-2026-10-04-8a7b6c5','nightly-2026-10-03-7a6b5c4']
PF='895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw'; J0='7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21'; J1='4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq'; PA='EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc'
def header(c): return f'''app [main!] {{
	pf: platform "https://github.com/acme/pf/releases/download/0.1.0/{PF}.tar.zst",
	json: "https://github.com/acme/json/releases/download/2.0.0/{J0}.tar.zst",
	parser: "https://github.com/acme/parser/releases/download/1.0.0/{PA}.tar.zst",
	roc: "{c}",
}}

'''
# (compiler index, imports of main.roc, talon.toml tables, extra words of the run)
# The runs 1 and 2 come first: they have the rows of `fx/probes` (the rows are counted over all runs of the case).
runs=[
 (9,'import parser.Parser\nimport parser.Yaml\n','',''),
 (10,'import parser.Parser\n','',''),
 (0,'','',''),
 (0,'','',''),
 (1,'','',''),
 (1,'import json.Yaml\n','',''),
 (2,'import json.Yaml\n','',''),
 (3,'','',''),
 (4,'','',''),
 (5,'','',''),
 (6,'','[resolution]\nprobe = { max = 3 }\n',''),
 (6,'','[resolution]\nprobe = { max = 6 }\n',''),
 (7,'','',' no-probe'),
 (1,'import json.Yaml\n','',' no-probe'),
 (8,'','[resolution]\nprobe = { slots = 5, timeout = 7 }\n',' slots=3'),
 (11,'','[resolution]\nprobe = { max = 4 }\n',''),
 (12,'','[resolution]\nprobe = { max = 5 }\n',''),
]
words=[]
for i,(ci,imp,toml,extra) in enumerate(runs,1):
    p=f'p{i}'
    d=f'{dst}/given/project/{p}'
    os.makedirs(d,exist_ok=True)
    open(d+'/main.roc','w').write(header(C[ci])+imp+('\n' if imp else '')+'main! = |_args| Ok({})\n')
    open(d+'/talon.toml','w').write('[dependencies]\n'+('\n'+toml if toml else ''))
    words.append(f'update json file={p}/main.roc{extra} compiler={C[ci]}')
# run 18: a package project (no build, the scan starts at the exposed module Lib). run 19: a workspace of 2 apps with different packages.
d=dst+'/given/project/p18'; os.makedirs(d,exist_ok=True)
open(d+'/main.roc','w').write(f'''package [Lib] {{
	json: "https://github.com/acme/json/releases/download/2.0.0/{J0}.tar.zst",
	roc: "{C[13]}",
}}
''')
open(d+'/Lib.roc','w').write('module [lib]\n\nimport json.Yaml\n\nlib = 1\n')
open(d+'/talon.toml','w').write('[dependencies]\n')
words.append(f'update json file=p18/main.roc compiler={C[13]}')
d=dst+'/given/project/ws'; os.makedirs(d+'/apps/a',exist_ok=True); os.makedirs(d+'/apps/b',exist_ok=True)
open(d+'/talon.toml','w').write('[workspace]\nmembers = ["apps/*/main.roc"]\n\n[dependencies]\n')
for n,extra in (('a',''),('b',f'\tparser: "https://github.com/acme/parser/releases/download/1.0.0/{PA}.tar.zst",\n')):
    open(f'{d}/apps/{n}/main.roc','w').write(f'''app [main!] {{
	pf: platform "https://github.com/acme/pf/releases/download/0.1.0/{PF}.tar.zst",
	json: "https://github.com/acme/json/releases/download/2.0.0/{J0}.tar.zst",
{extra}	roc: "{C[14]}",
}}

main! = |_args| Ok({{}})
''')
words.append(f'update json file=ws/apps/a/main.roc compiler={C[14]}')
open(dst+'/fx/runs','w').write('\n'.join(words)+'\n')
pk=dst+'/given/home/.cache/roc/packages/'
open(pk+J1+'/Yaml.roc','w').write('module [yaml]\n\nimport Wire\n\nyaml = Wire.wire\n')
open(pk+J1+'/Wire.roc','w').write('module [wire]\n\nwire = 1\n')
open(pk+PA+'/Parser.roc','w').write('module [parse]\n\nparse = 1\n')
open(pk+PA+'/Yaml.roc','w').write('module [yaml]\n\nyaml = 1\n')
os.makedirs(dst+'/given/home/.config/talon',exist_ok=True)
open(dst+'/given/home/.config/talon/config.toml','w').write('[probe]\ntimeout = 9\n')
O='../fixtures/check/out/'
rows=[
 f'{J1}:{C[1]}\t1\t-\t{O}unit-fail.stderr',
 f'{J1}:{C[2]}\t1\t-\tunit-foreign.stderr',
 f'{PF}:{C[3]}\tsignal:11\t-\t-',
 f'{PA}:{C[3]}\ttimeout\t-\t-',
 f'{J1}:{C[4]}\tsignal:9\t-\t-',
 f'{PA}:{C[5]}\t2\t-\t{O}unit-warn.stderr',
 f'{PA}:{C[9]}\t1\t-\t{O}unit-fail-two.stderr',
 f'{PA}:{C[10]}\t1\t-\tunit-parser.stderr',
 f'{J1}:{C[13]}\t1\t-\t{O}unit-fail.stderr',
]
open(dst+'/fx/units','w').write('# <hash>[:<compiler>] <code> <stdout> <stderr>: the answer of a unit probe (check main.roc in the package dir). No row: it passes.\n'+'\n'.join(rows)+'\n')
open(dst+'/fx/unit-foreign.stderr','w').write('── ✗ type mismatch ─────────────────────────── ../otherx1x0x0/Lib.roc:3:1\n\nThe body.\n\n── 1 error and 0 warnings ───────────────────────────── main.roc\n')
open(dst+'/fx/unit-parser.stderr','w').write(open('../../fixtures/check/out/unit-fail.stderr').read().replace('Yaml.roc','Parser.roc'))
# the other probes: the baseline of run 1 (index 0: it has the error of acme/parser, so the unit fail of Parser.roc is the known error); run 2: baseline, candidate, build (indexes 1 to 3)
open(dst+'/fx/probes','w').write(f'''# run 1: the baseline has the error in acme/parser Parser.roc (the unit fail has Parser.roc too: excused, and Yaml.roc: blamed)
1\t{O}pkg-base.stdout\t{O}pkg-base.stderr
# run 2: the same baseline, the candidate has the same error, the build passes: the unit fail of Parser.roc is the error of the baseline (R-P6)
1\t{O}pkg-base.stdout\t{O}pkg-base.stderr
1\t{O}pkg-same.stdout\t{O}pkg-same.stderr
0\t{O}build-pass.stdout\t{O}build-pass.stderr
''')
