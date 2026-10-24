# Slice 037c: make the L2 case probe/pd1-downloads (tln probe --range with the optional compiler downloads).
# Run: python3 -I research/slice-037c-revert/gen-pd.py
# The case reuses the packages, the config and the 10 nightlies (n1..n10) of probe/pc2-range, with new homes that start with the same compilers.
# The expect/ dir is NOT made here: make it with the private reference (UPDATE=1) and read it (TW21).
import os, shutil, json

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
cases = os.path.join(root, 'tests/commands/cases/probe')
src = os.path.join(cases, 'dm1-domain')
dst = os.path.join(cases, 'pd1-downloads')

PF = 'https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst'
JS = 'https://github.com/acme/json/releases/download/2.1.0/4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq.tar.zst'
PA = 'https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst'
PB = 'https://github.com/acme/parser/releases/download/1.2.0/EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt.tar.zst'
H_PF = '895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw'
H_JS = '4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq'
H_PA = 'EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc'
H_PB = 'EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt'
UNIT_FAIL = '../fixtures/check/out/unit-fail.stderr'
FAKE_SHA = 'b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78'   # sha256 of the text `fake`, what the fake curl writes


def sha_of(i):
    return (f'{i % 10}' + 'abcdef'[i % 6]) * 3 + f'{i % 10}'


D = [f'nightly-2026-10-{i:02d}-{sha_of(i)}' for i in range(1, 11)]
N = {i + 1: D[i] for i in range(10)}
NOW_ID = 'nightly-2026-10-14-38a3029'
INST = [1, 3, 5, 6, 7, 8, 9, 10]            # installed at the start of each home (n2 and n4 are not)
HOMES = ['home', 'home2', 'home3', 'home4', 'home5', 'home6', 'home7']


def size_of(n):
    return 73000000 + 100000 * n            # n4: 73.4 MB, n2: 73.2 MB


RULES = """R-NI4 R-DL1 R-DL4 R-DL5 R-DL6 R-NM6 R-NM8 R-PB3 R-PB4 R-P5 R-P3 R-PP2 R-PP4 R-AL4 R-NS3 R-C7 R-EC12 R-HF1 R-J5 (slice 037c, questions Q1 to Q8 of slice 037c): `tln probe --range` with the optional compiler downloads. Phase 1 uses the installed compilers (as probe/pc2-range). Phase 2 downloads the releases that the next round needs, only with the opt-in (`--probe-downloads` or `--yes`), inside the cap `probe.max-toolchains`, and inside the budget `probe.max`.
The packages, the config and the compiler list (n1 to n10) are those of `probe/pc2-range`, with correct digests and sizes (n4: 73.4 MB, n2: 73.2 MB). Every home starts with n1, n3, n5, n6, n7, n8, n9, n10 installed. n2 and n4 are downloads. The truth (the fake `units`): json passes on n5, n6, n7. parser passes on n3 to n10 (fails on n1 and n2). parser2 passes on n5 to n10, crashes on n3, fails on n1, n2 and n4.
Run 1 (R-DL4, R-NI4, U5): a person (the fake tty is true), no flag. Phase 1 gives the range n5 .. n7 with the lower end unknown (n4 is not installed). The next round would download n4, so the line `skipped 1 compiler download (73.4 MB), pass --probe-downloads` is printed. No prompt (no `ask`, no `tty` call), exit 12. Run 2 (R-DL4): the same with no person (CI): the same line, no probe (all facts are known).
Run 3 (R-NI4, R-DL5, R-DL10, R-NM6, R-J5): `--probe-downloads` with `TALON_AUTO_INSTALL=no` (the variable is about required downloads only), `--json`. Phase 1 asks nothing (facts known). Phase 2: the answer line, the download of n4 (list, lock, curl, tar, chmod, rename), one probe on n4 (a fail), the lower end n5 is real, exit 0. `data.downloads` is 1.
Run 4 (R-DL5): parser with no person, `TALON_AUTO_INSTALL=yes` and `--allow-downloads`: both answer a required download only, so the optional download is skipped: phase 1 (10 probes), the line for n2, exit 12.
Run 5 (R-NM8, R-NI4, U5): `--yes` with a person is the opt-in: no prompt. The facts are known, n2 is downloaded and probed (a fail), the lower end n3 is real, exit 0.
Run 6 (R-DL6): `max-toolchains = 1` (project p2, home2). Phase 2 wants n2 and n4: the cap allows 1 (the first of the round, n2). n4 is dropped and is not asked again. The lower end stays unknown: exit 12, the note of the cap.
Run 7 (R-DL6): `max-toolchains = 0` (project p3, home3) with `--probe-downloads`: nothing is offered. No line, no download, exit 12.
Run 8 (R-P3, R-DL6): the download of n4 fails (home4: the fake curl exits 22). A warning, no fact for n4, no leftover item. The lower end stays unknown: exit 12. `--json`: `error.details.downloads` is 0.
Run 9 (R-P5): `probe.max = 8` (project p4, home5) with `--probe-downloads`. Phase 1 uses all 8 probes. Phase 2 would need n4 and there is no room for a probe, so n4 is not downloaded: exit 12 with the budget text (1 unit check did not run).
Run 10 (R-DL6, R-P3, question Q3): home6 has only n10 installed and each download fails; `max-toolchains = 4` (project p5). Phase 1 probes n10 (a fail): no pass. Phase 2 round 1 wants n9, n8, n7: 3 tries, all fail. Round 2 wants n6, n5, n4: the cap that is left is 1, so only n6 is tried (it fails) and n5 and n4 are dropped. Round 3 wants n3, n2, n1: the cap is spent, so no try. A failed download counts for the cap, so a dead network ends after 4 tries. The result is no pass, 9 releases with no fact: exit 12, and the note of the cap (5 downloads were not made).
Run 11 (R-P5, gap test A10): `probe.max = 2` (project p6, home7: only n10 installed, the downloads work). Phase 1 probes n10 (a fail): no pass, 1 probe. Phase 2 wants n9, n8, n7 and the budget allows 1: n9 is downloaded and probed (a fail). The round is cut, so the search ends after it, with the failure that counts the 2 checks of that round that did not run. No second round starts: a next round would give another count (3), and no download of n8."""


def sh(*parts):
    return ''.join(parts)


def app(name, header):
    d = f'{dst}/given/project/{name}'
    os.makedirs(d, exist_ok=True)
    open(d + '/main.roc', 'w').write('app [main!] {\n' + ''.join(f'\t{l},\n' for l in header) + '}\n\nmain! = |_args| Ok({})\n')
    return d


shutil.rmtree(dst, ignore_errors=True)
os.makedirs(dst + '/fx')
os.makedirs(dst + '/given/project')
open(dst + '/entry', 'w').write('commands\n')
# the packages, the config of probe/dm1-domain
for h in (H_JS, H_PF, H_PA, H_PB):
    shutil.copytree(f'{src}/given/home/.cache/roc/packages/{h}', f'{dst}/given/home/.cache/roc/packages/{h}')
os.makedirs(dst + '/given/home/.config/talon')
# default-roc is set (an installed compiler), so a download does not edit config.toml (R-SO15 sets it only when none is set: question Q7)
open(dst + '/given/home/.config/talon/config.toml', 'w').write(f'default-roc = "{N[10]}"\n\n' + open(src + '/given/home/.config/talon/config.toml').read())
# the installed compilers
for n in INST:
    t = f'{dst}/given/home/.cache/roc/toolchains/{N[n]}'
    os.makedirs(t)
    open(t + '/roc', 'w').write('fake roc\n')
    open(t + '/.talon.json', 'w').write('{"format":1,"id":"%s","url":"http://127.0.0.1:1/dl/%s","sha256":"00","sha256_source":"github-digest","typed":"%s","compat":null,"installed_at":"2026-10-12T12:00:00Z","published_at":"2026-10-%02dT15:00:00Z"}\n' % (N[n], N[n], N[n], n))
# the same state for the other homes (each home has its own compat.db and its own list cache)
for h in HOMES[1:]:
    shutil.copytree(dst + '/given/home', f'{dst}/given/{h}')
# home6 (run 10) has only n10 installed: the search needs many downloads, and each one fails
for n in INST:
    if n != 10:
        shutil.rmtree(f'{dst}/given/home6/.cache/roc/toolchains/{N[n]}')
        shutil.rmtree(f'{dst}/given/home7/.cache/roc/toolchains/{N[n]}')    # home7 (run 11): only n10, and the downloads work

# the projects
HDR = [f'pf: platform "{PF}"', f'json: "{JS}"', f'parser: "{PA}"']
app('p1', HDR)
d = app('p2', [f'pf: platform "{PF}"', f'parser2: "{PB}"'])
open(d + '/talon.toml', 'w').write('[resolution]\nprobe = { max-toolchains = 1 }\n')
d = app('p3', HDR)
open(d + '/talon.toml', 'w').write('[resolution]\nprobe = { max-toolchains = 0 }\n')
d = app('p4', HDR)
open(d + '/talon.toml', 'w').write('[resolution]\nprobe = { max = 8 }\n')
d = app('p5', HDR)
open(d + '/talon.toml', 'w').write('[resolution]\nprobe = { max-toolchains = 4 }\n')
d = app('p6', HDR)
open(d + '/talon.toml', 'w').write('[resolution]\nprobe = { max = 2 }\n')

# fx: env, gitdirs, path-roc, programs (the downloader and the extract), mtimes, the list
open(dst + '/fx/env', 'w').write('HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n')
open(dst + '/fx/gitdirs', 'w').write('.\n')
open(dst + '/fx/path-roc', 'w').write('# a tln of 5000 bytes and a roc of 1000 bytes (no file is hashed)\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n')
open(dst + '/fx/programs', 'w').write('roc\ncurl\ntar\n')
shutil.copy(cases + '/pc2-range/fx/mtimes', dst + '/fx/mtimes')
open(dst + '/fx/jobs', 'w').write(
    '# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod (as slice 021). The first rule whose needle is in the arguments answers.\n'
    '# home4 and home6 are the homes of runs 8 and 10: each download fails (the server answers 404).\n'
    '/home4/\t22\t-\tcurl: (22) The requested URL returned error: 404\t-\n'
    '/home6/\t22\t-\tcurl: (22) The requested URL returned error: 404\t-\n'
    'curl --fail\t0\t-\t-\tfile:{out}\n'
    'tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details\n'
    'chmod 0755\t0\t-\t-\t-\n'
    f'version\t0\tRoc compiler version {NOW_ID}\t-\t-\n')
os.makedirs(dst + '/fx/http/api.github.com/repos/roc-lang/nightlies')
rel = []
for i in range(10, 0, -1):
    t = N[i]
    name = f'roc_nightly-linux_x86_64-{t[len("nightly-"):]}.tar.gz'
    rel.append({'tag_name': t, 'draft': False, 'prerelease': False, 'published_at': f'2026-10-{i:02d}T15:00:00Z',
                'assets': [{'name': name, 'size': size_of(i), 'digest': 'sha256:' + FAKE_SHA,
                            'browser_download_url': f'https://github.com/roc-lang/nightlies/releases/download/{t}/{name}'}]})
open(dst + '/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100', 'w').write('[\n' + ',\n'.join(json.dumps(r, separators=(',', ':')) for r in rel) + '\n]\n')

# the truth
rows = []
for n in (1, 2, 3, 4, 8, 9, 10):
    rows.append([f'{H_JS}:{N[n]}', '1', '-', UNIT_FAIL])
for n in (1, 2):
    rows.append([f'{H_PA}:{N[n]}', '1', '-', UNIT_FAIL])
for n in (1, 2, 4):
    rows.append([f'{H_PB}:{N[n]}', '1', '-', UNIT_FAIL])
rows.append([f'{H_PB}:{N[3]}', 'signal:11', '-', '-'])
open(dst + '/fx/units', 'w').write('# <hash>:<compiler> <code> <stdout> <stderr>: the answer of a unit probe. No row: it passes.\n' + ''.join('\t'.join(r) + '\n' for r in rows))

cmds = [
    'probe json --range --file p1/main.roc',                                                                  # 1  a person, no flag: the line, exit 12
    'env:CI=true probe json --range --file p1/main.roc',                                                      # 2  no person: the same line
    'env:TALON_AUTO_INSTALL=no probe json --range --probe-downloads --json --file p1/main.roc',               # 3  the opt-in: n4 is downloaded, exit 0
    'env:CI=true env:TALON_AUTO_INSTALL=yes probe parser --range --allow-downloads --file p1/main.roc',       # 4  required-download answers do not opt in: the line for n2
    'probe parser --range --yes --file p1/main.roc',                                                          # 5  --yes opts in: n2 is downloaded
    'env:HOME={w}/home2 probe parser2 --range --probe-downloads --file p2/main.roc',                          # 6  the cap 1: n2 only, the note
    'env:HOME={w}/home3 probe json --range --probe-downloads --file p3/main.roc',                             # 7  the cap 0: nothing is offered
    'env:HOME={w}/home4 probe json --range --probe-downloads --json --file p1/main.roc',                      # 8  the download fails: the warning, exit 12
    'env:HOME={w}/home5 probe json --range --probe-downloads --file p4/main.roc',                             # 9  probe.max 8: no room, no download
    'env:HOME={w}/home6 probe json --range --probe-downloads --file p5/main.roc',                             # 10 every download fails: the cap counts the tries
    'env:HOME={w}/home7 probe json --range --probe-downloads --file p6/main.roc',                             # 11 probe.max 2: a partial budget cut in phase 2 ends the search
]
open(dst + '/fx/commands', 'w').write('\n'.join(cmds) + '\n')
open(dst + '/rules', 'w').write(RULES)
print('ok')
