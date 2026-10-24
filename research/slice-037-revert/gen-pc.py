# Slice 037: make the L2 cases probe/pc1-targets and probe/pc2-range (tln probe: the 3 targets, the range search).
# Run: python3 -I research/slice-037-revert/gen-pc.py
# The cases reuse the packages, the compiler list (10 nightlies, n1..n10) and the config of probe/dm1-domain.
# The expect/ dirs are NOT made here: make them with the reference (UPDATE=1) and read them (TW21).
import os, shutil

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/probe')
src = os.path.join(cases, 'dm1-domain')

PF = 'https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst'
JS = 'https://github.com/acme/json/releases/download/2.1.0/4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq.tar.zst'
PA = 'https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst'
PB = 'https://github.com/acme/parser/releases/download/1.2.0/EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt.tar.zst'
H_PF = '895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw'
H_JS = '4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq'
H_PA = 'EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc'
H_PB = 'EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt'
H_BUN = '8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f'   # a bundle file: not in packages/
H_BUN2 = 'AJn26sZEXCwpyJNwjCgzYyLBXVC8HdvXhGWVD6bknvkq'  # a second bundle file (pc2)
UNIT_FAIL = '../fixtures/check/out/unit-fail.stderr'
PASS = ['0', '../fixtures/check/out/pass.stdout', '../fixtures/check/out/pass.stderr']
BUILD_PASS = ['0', '../fixtures/check/out/build-pass.stdout', '../fixtures/check/out/build-pass.stderr']
APP_ERRORS = ['1', '../fixtures/check/out/app-errors.stdout', '../fixtures/check/out/app-errors.stderr']

RULES1 = """R-CM8 R-PB1 R-PB2 R-PB6 R-PB7 R-SC1 R-SC16 R-SC6 R-H4 R-LD2 R-LD3 R-LD7 R-P3 R-P4 R-RC3 R-RC4 R-AL4 R-FE2 R-FE3 R-FE4 R-NI5 R-EC13 R-EC2 R-J3 R-J4 R-OUT4 (slice 037, questions E1, P1, R1, T1, R-FE4 of slice 037): `tln probe` with no `--range`: the 3 targets and their errors. 15 runs, one project dir each (p1 to p4). The packages, the compiler list and the config are those of `probe/dm1-domain`. The compiler is the `roc` on PATH, nightly-2026-10-14-38a3029 (not installed, not in the list: no download).
Alias (R-PB1, R-PB2, R-SC1, R-SC16): runs 1 to 3 probe the package of a header entry on the selected compiler, one unit check each, and write the fact with `existing=replace` (P1: a known fact is probed again). Run 1: json passes. Run 2: the platform pf fails in Yaml.roc. Run 3: the selector `parser@1` (R-SC16) finds parser 1.0.0, the check hangs (R-RC3, a fact: R-P3), and the fact replaces the fail that the db had. Run 4: `json@3` is not in the project (exit 2). Run 5: `local` is a path entry, it has no hash (R-H4, question T1: exit 2). Run 6: `--json`: the envelope has the `data` of the proposal, the human text goes to stderr (R-J3, R-J4, R-OUT4).
Project file (R-PB1, R-PB2, R-PB7, R-LD7): runs 7 to 9 run ladder steps 2 and 3 with no baseline, in the project dir (no copy), and write no fact. Run 7: an app, check and build pass. Run 8: the check of the app fails with 5 errors, no build. Run 9: a package, the check passes, no build (a package has no app).
Bundle file (R-PB1, R-FE2, R-FE3, R-FE4): run 10 copies the file to a temp dir in `packages/`, runs `roc unbundle <hash>.tar.zst` there (R-FE4: no compiler is installed, so the program is the `roc` on PATH, `/fake/bin/roc`), renames the dir, and probes the hash. Run 11: the dir is there, so there is no copy and no unbundle.
Usage errors (R-PB6, R-CM8, question R1): run 12 `--share` (exit 2: `direct` has no registry), run 13 two operands, run 14 `--range` with no operand. No `Fx` call that probes. Run 15 (R-NI5, R-EC13): the pin of p4 names a compiler that is not installed. A required download with no answer in a non-interactive run is exit 13, and nothing is probed."""

RULES2 = """R-PB3 R-PB4 R-PB7 R-PB1 R-LB3 R-CM8 R-AL4 R-PP2 R-PP3 R-PP4 R-P4 R-P5 R-EP5 R-EP6 R-EP8 R-EP11 R-NS3 R-C7 R-LD2 R-CC9 R-EC12 R-NI4 R-J5 R-FE4 R-FE2 R-FE3 (slice 037, questions S1 to S4 of slice 037): `tln probe --range`: the search for the range of one hash over the installed compilers. The packages, the compiler list (n1 to n10) and the config are those of `probe/dm1-domain`. Installed: n1, n3, n5, n6, n7, n8, n9, n10 (n2 and n4 are not). No download is offered (the default of R-NI4 is no, 037b has the opt-in). The db has a row of another hash on n10, and a row of pf on n10 with the target x64musl: neither is read (R-LD2).
The truth (the fake `units`): json passes on n5, n6, n7. parser passes on n6 to n10. pf passes on n5, n6, n7 and crashes on n8. The others fail. Parser2 passes everywhere.
Run A (R-P5, R-PP4, R-EC12): parser in p2 with probe.max 4. Round 1 asks n10, n9, n8 (the newest installed, 3 for each round). Round 2 wants n3, n5, n6 and the budget allows 1: n3. The facts are saved, the run prints the range for the facts that it has (n8 .. n10, the lower end unknown) and exits 12 with the budget failure.
Run B (R-PB3, R-AL4, R-PP4): parser in p1 goes on. It reads the 4 facts and asks 3 releases (n5, n6, n7): the whole range is n6 .. n10, both ends real (n5 is a real fail, n10 is the end of D), exit 0.
Run C: json: rounds n10 n9 n8 (fail), n7 n6 n5 (pass), n1 n3 (fail): 8 probes. n4 is not installed, so the lower end n5 is unknown. The upper end is real (n8 is a real fail). Exit 12 (R-PB4: 1 end).
Run D (R-EP5): pf: the same rounds, and n8 crashes: a crash is a fact (it is not asked again), but no real fail, so the upper end is unknown too. Exit 12 with 2 ends.
Run E (R-J5): json again with `--json`: all facts are known, no probe starts. The result is the same, exit 12, and the envelope of the failure has the range in `error.details`.
Run F (R-LB3, R-PB1, R-FE4): `tln probe --range <bundle file>`: no compiler is selected, so the newest installed compiler (n10) unbundles. Then the search runs: 3 rounds, 7 probes (n10 n9 n8, n3 n5 n6, n1). The releases n2, n4 and n7 have inferred passes (R-EP6: between two real passes), so the whole list is the range, both ends real, exit 0.
Run I (R-FE4): a bundle file with no `--range`, in p5 whose pin n3 is installed. Rule 1: the selected compiler unbundles (the program of n3, not the newest installed n10), then the unit check runs on n3. Run G (R-NS3): `[toolchain] nightly = false` in p4: no candidate is allowed. No probe starts, no pass is known: the result is `no release of the compiler list has a real pass`, exit 12 (10 releases have no real fact).
Run H (R-C7, R-NS3): `min-release-age = "7d"` in p3 with TALON_NOW 2026-10-15: n8, n9 and n10 are younger than 7 days, so they are not asked. Rounds n7 n6 n5, then n1 n3: 5 probes. The range is n1 .. n7: the lower end is the end of D, the upper end is unknown (n8 has no real fact). Exit 12."""

def sha_of(i):
    return (f'{i % 10}' + 'abcdef'[i % 6]) * 3 + f'{i % 10}'
D = [f'nightly-2026-10-{i:02d}-{sha_of(i)}' for i in range(1, 11)]
N = {i + 1: D[i] for i in range(10)}
NOW_ID = 'nightly-2026-10-14-38a3029'   # the roc on PATH (as probe/un3-verify-units)


def start(name):
    dst = os.path.join(cases, name)
    shutil.rmtree(dst + '/fx', ignore_errors=True)
    shutil.rmtree(dst + '/given', ignore_errors=True)
    os.makedirs(dst + '/fx')
    os.makedirs(dst + '/given/project')
    open(dst + '/entry', 'w').write('commands\n')
    # the packages of the case (the unit probes run in them), the compiler list and the config
    for h in (H_JS, H_PF, H_PA, H_PB):
        shutil.copytree(f'{src}/given/home/.cache/roc/packages/{h}', f'{dst}/given/home/.cache/roc/packages/{h}')
    os.makedirs(dst + '/given/home/.config/talon')
    shutil.copy(src + '/given/home/.config/talon/config.toml', dst + '/given/home/.config/talon/config.toml')
    shutil.copytree(src + '/fx/http', dst + '/fx/http')
    for d in ('api.github.com/repos/acme/json', 'api.github.com/repos/acme/parser', 'api.github.com/repos/acme/pf'):
        shutil.rmtree(f'{dst}/fx/http/{d}', ignore_errors=True)
    open(dst + '/fx/env', 'w').write('HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n')
    open(dst + '/fx/gitdirs', 'w').write('.\n')
    open(dst + '/fx/path-roc', 'w').write('# a tln of 5000 bytes and a roc of 1000 bytes (no file is hashed)\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
    open(dst + '/fx/programs', 'w').write('roc\n')
    shutil.copy(src + '/fx/mtimes', dst + '/fx/mtimes')
    return dst


def app(dst, name, header, extra=''):
    d = f'{dst}/given/project/{name}'
    os.makedirs(d, exist_ok=True)
    open(d + '/main.roc', 'w').write('app [main!] {\n' + ''.join(f'\t{l},\n' for l in header) + '}\n\nmain! = |_args| Ok({})\n' + extra)
    return d


def toml(d, text):
    open(d + '/talon.toml', 'w').write(text)


def write_units(dst, rows):
    open(dst + '/fx/units', 'w').write('# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n' + ''.join('\t'.join(r) + '\n' for r in rows))


def write_jobs(dst, second=False):
    # the compiler on PATH, and the unbundle of the bundle file (R-FE2)
    open(dst + '/fx/jobs', 'w').write(
        f'version\t0\tRoc compiler version {NOW_ID}\t-\t-\n'
        f'unbundle {H_BUN}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{H_BUN};copy:{{cwd}}/{H_BUN}/main.roc={{w}}/fx/pkgs/bundle.roc\n')
    os.makedirs(dst + '/fx/pkgs')
    open(dst + '/fx/pkgs/bundle.roc', 'w').write('package [Lib] {}\n')
    os.makedirs(dst + '/given/project/bundles')
    open(f'{dst}/given/project/bundles/{H_BUN}.tar.zst', 'w').write('fake archive\n')
    if second:
        open(dst + '/fx/jobs', 'a').write(f'unbundle {H_BUN2}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{H_BUN2};copy:{{cwd}}/{H_BUN2}/main.roc={{w}}/fx/pkgs/bundle.roc\n')
        open(f'{dst}/given/project/bundles/{H_BUN2}.tar.zst', 'w').write('fake archive 2\n')


# ---------------------------------------------------------------- pc1-targets
dst = start('pc1-targets')
HDR = [f'pf: platform "{PF}"', f'json: "{JS}"', f'parser: "{PA}"', 'local: "./lib/main.roc"']
d = app(dst, 'p1', HDR)
os.makedirs(d + '/lib')
open(d + '/lib/main.roc', 'w').write('package [] {}\n')
# p2: an app with errors in main.roc (the check fails)
app(dst, 'p2', [f'pf: platform "{PF}"', f'json: "{JS}"'])
# p3: a package (no build)
d = f'{dst}/given/project/p3'
os.makedirs(d)
open(d + '/main.roc', 'w').write(f'package [Lib] {{\n\tjson: "{JS}",\n}}\n')
open(d + '/Lib.roc', 'w').write('module [x]\n\nx = 1\n')
# p4: a pin for a compiler that is not installed (a required download, R-NI5)
app(dst, 'p4', [f'pf: platform "{PF}"', f'json: "{JS}"', f'roc: "{N[2]}"'])
write_jobs(dst)
write_units(dst, [
    [f'{H_PF}:{NOW_ID}', '1', '-', UNIT_FAIL],
    [f'{H_PA}:{NOW_ID}', 'timeout', '-', '-'],
])
# the non-unit probes: the project file of p1 (check, build), p2 (check fails), p3 (check)
open(dst + '/fx/probes', 'w').write('# probe 1 and 2: p1 check and build. 3: p2 check (errors, no build). 4: p3 check (a package: no build)\n' + ''.join('\t'.join(r) + '\n' for r in (PASS, BUILD_PASS, APP_ERRORS, PASS)))
os.makedirs(dst + '/given/home/.cache/roc/talon', exist_ok=True)
open(dst + '/given/home/.cache/roc/talon/compat.tsv', 'w').write(f'format\t1\nfact\t{H_PA}\t{NOW_ID}\tany\tfail\tParser.roc\t\n')
cmds = [
    'probe json --file p1/main.roc',                      # 1  alias, pass
    'probe pf --file p1/main.roc',                        # 2  the platform, fail with a module
    'probe parser@1 --file p1/main.roc',                  # 3  a selector, hang, replaces the fail of the db
    'probe json@3 --file p1/main.roc',                    # 4  not in the project
    'probe local --file p1/main.roc',                     # 5  a path entry
    'probe json --json --file p1/main.roc',               # 6  --json
    'probe --file p1/main.roc',                           # 7  the project file: app, check and build
    'probe --file p2/main.roc',                           # 8  the project file: the check fails
    'probe --file p3/main.roc',                           # 9  the project file: a package
    f'probe {{w}}/project/bundles/{H_BUN}.tar.zst --file p1/main.roc',   # 10 a bundle file: unbundle, unit probe
    f'probe {{w}}/project/bundles/{H_BUN}.tar.zst --file p1/main.roc',   # 11 the dir is there: no unbundle
    'probe --share json --file p1/main.roc',              # 12 R-PB6
    'probe json parser --file p1/main.roc',               # 13 2 operands
    'probe --range --file p1/main.roc',                   # 14 R1
    'probe json --file p4/main.roc',                      # 15 a required download, no answer: exit 13
]
open(dst + '/fx/commands', 'w').write('\n'.join(cmds) + '\n')
open(dst + '/rules', 'w').write(RULES1)

# ---------------------------------------------------------------- pc2-range
dst = start('pc2-range')
# the installed compilers: n1, n3, n5, n6, n7, n8, n9, n10 (n2 and n4 are not)
INST = [1, 3, 5, 6, 7, 8, 9, 10]
for n in INST:
    t = f'{dst}/given/home/.cache/roc/toolchains/{N[n]}'
    os.makedirs(t)
    open(t + '/roc', 'w').write('fake roc\n')
    open(t + '/.talon.json', 'w').write('{"format":1,"id":"%s","url":"http://127.0.0.1:1/dl/%s","sha256":"00","sha256_source":"github-digest","typed":"%s","compat":null,"installed_at":"2026-10-12T12:00:00Z","published_at":"2026-10-%02dT15:00:00Z"}\n' % (N[n], N[n], N[n], n))
HDR = [f'pf: platform "{PF}"', f'json: "{JS}"', f'parser: "{PA}"']
app(dst, 'p1', HDR)
d = app(dst, 'p2', HDR)
toml(d, '[resolution]\nprobe = { max = 4 }\n')
d = app(dst, 'p3', [f'pf: platform "{PF}"', f'parser2: "{PB}"'])
toml(d, '[resolution]\nmin-release-age = "7d"\n')
d = app(dst, 'p4', [f'pf: platform "{PF}"', f'parser2: "{PB}"'])
toml(d, '[toolchain]\nnightly = false\n')
app(dst, 'p5', [f'pf: platform "{PF}"', f'json: "{JS}"', f'roc: "{N[3]}"'])
write_jobs(dst, second=True)
rows = []
for n in (1, 3, 8, 9, 10):      # json: passes on n5, n6, n7 only
    rows.append([f'{H_JS}:{N[n]}', '1', '-', UNIT_FAIL])
for n in (3, 5):                # parser: passes on n6 .. n10
    rows.append([f'{H_PA}:{N[n]}', '1', '-', UNIT_FAIL])
for n in (1, 3, 9, 10):         # pf: passes on n5, n6, n7, crashes on n8
    rows.append([f'{H_PF}:{N[n]}', '1', '-', UNIT_FAIL])
rows.append([f'{H_PF}:{N[8]}', 'signal:11', '-', '-'])
write_units(dst, rows)
os.makedirs(dst + '/given/home/.cache/roc/talon')
open(dst + '/given/home/.cache/roc/talon/compat.tsv', 'w').write(
    'format\t1\n'
    f'fact\t7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21\t{N[10]}\tany\tfail\t\t\n'    # another hash: never read
    f'fact\t{H_PF}\t{N[10]}\tx64musl\tpass\t\t\n'                                       # another target (R-LD2): never read
)
cmds = [
    'probe parser --range --file p2/main.roc',                 # A  probe.max 4: the budget cuts round 2, exit 12
    'probe parser --range --file p1/main.roc',                 # B  goes on: the facts are saved, 3 probes, real ends, exit 0
    'probe json --range --file p1/main.roc',                   # C  one end unknown (n4 is not installed), exit 12
    'probe pf --range --file p1/main.roc',                     # D  2 ends unknown: n4, and n8 is a crash (a fault), exit 12
    'probe json --range --json --file p1/main.roc',            # E  all facts known: no probe, the same result, --json
    f'probe --range {{w}}/project/bundles/{H_BUN}.tar.zst --file p1/main.roc',   # F  a bundle file (R-LB3)
    f'probe {{w}}/project/bundles/{H_BUN2}.tar.zst --file p5/main.roc',   # I  R-FE4: the pin n3 is installed: it unbundles and runs the unit check (the newest installed is n10)
    'probe parser2 --range --file p4/main.roc',                # G  nightly = false: no candidate, no probe, no pass: exit 12
    'probe parser2 --range --file p3/main.roc',                # H  min-release-age 7d hides n8, n9, n10: 5 probes, exit 12
]
open(dst + '/fx/commands', 'w').write('\n'.join(cmds) + '\n')
open(dst + '/rules', 'w').write(RULES2)
print('ok')
