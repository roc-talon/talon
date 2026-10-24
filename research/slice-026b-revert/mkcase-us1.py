#!/usr/bin/env python3
"""Makes the L2 case tests/commands/cases/roc/us1-use (slice 026b). Run from the repo root: python3 research/slice-026b-revert/mkcase-us1.py
It writes only the inputs (entry, fx/, given/, rules). The expected files come from UPDATE=1 and are read by hand (TW21)."""
import os, shutil

HOOK_N = int(os.environ.get("HOOK_N", "30"))
ROOT = "tests/commands/cases/roc/us1-use"
UP1 = "tests/commands/cases/roc/up1-update"
N = "nightly-2026-10-14-38a3029"   # the new compiler
O = "nightly-2026-10-09-258ab27"   # the old pin
M = "nightly-2026-10-13-91fa0c2"   # one nightly older than N

if os.path.exists(ROOT):
    shutil.rmtree(ROOT)

def put(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(text)

PF = "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst"
JSON = "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst"

def header(pin, comments=False):
    if comments:
        lines = ["app [main!] {", "\t# the platform", f'\tpf: platform "{PF}",', f'\tjson: "{JSON}",']
        if pin:
            lines.append(f'\troc: "{pin}", # the compiler')
        lines += ["}", "", "main! = |_args| Ok({})", ""]
    else:
        lines = ["app [main!] {", f'\tpf: platform "{PF}",', f'\tjson: "{JSON}",']
        if pin:
            lines.append(f'\troc: "{pin}",')
        lines += ["}", "", "main! = |_args| Ok({})", ""]
    return "\n".join(lines)

# projects: dir -> (pin, comments)
projects = {
    "p1": (O, True), "p3": (O, False), "p4": (None, False), "p5": (O, False),
    "p6": (O, False), "p7": (O, False), "p8": (O, False), "p9": (O, False),
    "p12": (N, False), "p13": (O, False), "p14": (O, False), "p15": (O, False), "p16": (O, False),
    "p17": (O, False), "p19": (None, False), "p20": (O, False), "p21": (O, False),
    "p22": (O, False), "p23": ("nightly-2026-October-14-38a3029", False), "p24": (O, False), "p25": (O, False), "p26": (None, False), "p28": ("0.1.0", False), "p29": (O, False),
}
for d, (pin, c) in projects.items():
    put(f"given/project/{d}/main.roc", header(pin, c))
put("given/project/p18/main.roc", f'package [Lib] {{\n\tjson: "{JSON}",\n\troc: "{O}",\n}}\n')
put("given/project/p24/talon.toml", '[toolchain]\nroc = ">=nightly-2026-10-14-ffffff0"\n')
put("given/project/p25/talon.toml", '[toolchain]\nroc = ">=nightly-2026-10-14-ffffff0"\n')
put("given/project/p12/talon.toml", '[toolchain]\nroc = ">=nightly-2026-10-12-2664a27"\n')

def meta(cid, hour="15"):
    day = cid.split("-")
    return ('{"format":1,"id":"%s","url":"http://127.0.0.1:1/dl/%s","sha256":"00","sha256_source":"github-digest","typed":"%s","compat":null,"installed_at":"2026-10-20T12:00:00Z","published_at":"%s-%s-%sT%s:00:00Z"}'
            % (cid, cid, cid, day[1], day[2], day[3], hour))

def installed(home, cid, hour="15"):
    put(f"given/{home}/.cache/roc/toolchains/{cid}/roc", "fake")
    put(f"given/{home}/.cache/roc/toolchains/{cid}/.talon.json", meta(cid, hour))

for cid in (O, N, M):
    installed("home", cid)
put("given/home/.config/talon/config.toml", f'# my settings\nnightly = true\ndefault-roc = "{O}"   # tln roc default writes it\n')
installed("home2", O)
put("given/home2/.config/talon/config.toml", f'default-roc = "{O}"\n')
put("given/home3/.gitkeep", "")
put("given/home4/.gitkeep", "")
installed("home5", N)
put("given/home5/.config/talon/config.toml", f'default-roc = "{N}"\n')
put("given/home6/.cache/roc/toolchains/link-dev/roc", "fake")
put("given/home6/.cache/roc/toolchains/link-dev/.talon.json", '{"format":1,"id":"link-dev","kind":"link","path":"/x/roc"}')
put("given/home6/.config/talon/config.toml", f'default-roc = "link-dev"\n')

for h in ("home7", "home8", "home9"):
    installed(h, N)
    put(f"given/{h}/.config/talon/config.toml", f'default-roc = "{N}"\n')
put("given/home11/.gitkeep", "")
installed("home12", O)
installed("home12", "nightly-2026-10-14-ffffff0", "10")
installed("home12", N)
put("given/home12/.config/talon/config.toml", f'default-roc = "{O}"\n')
installed("home13", O)
installed("home13", "nightly-2026-10-14-ffffff0", "10")
put("given/home13/.config/talon/config.toml", f'default-roc = "{O}"\n')
installed("home10", O)
put("given/home10/.config/talon/config.toml", f'default-roc = "{O}"\n')

runs = [
    ("# R-CS1 R-U3 R-H1 R-RP1 R-PH8 R-CC7 R-PD9: HOME is home, which has O, N and M installed. p1 has the pin O and comments in the header. No download, no list. The baseline check runs on O in the project dir, the candidate check and the build run on N in the temp copy (the log of the probes names the compiler of each). The pin is written with a span edit: the comments stay. The project is recorded.",
     f"roc use {N} --file p1/main.roc"),
    (f"# R-J3 R-OUT4 R-CS1: --json. Human text goes to stderr, stdout is only the envelope: id, files with the previous pin, the probes, the downloads, check, build, notes.",
     f"roc use {N} --file p3/main.roc --json"),
    (f"# R-CS1 R-RP3 R-BL1 R-SO6: p4 has no roc pin. The baseline is the compiler that Resolution 13 selects: the global default O (rank 6). The header gets the entry `roc: \"{N}\"` as its last entry.",
     f"roc use {N} --file p4/main.roc"),
    (f"# R-U6: ROC_TOOLCHAIN is set (rank 2, above the pin). The command still pins N after the check and prints the note that ROC_TOOLCHAIN has a higher priority. The baseline is the pin of p5, as for the other runs.",
     f"env:ROC_TOOLCHAIN={O} roc use {N} --file p5/main.roc"),
    (f"# R-U2 R-NI6 R-DL3 R-DL4 R-CC4: HOME is home2, which has O only. The new compiler N is the one download, and the command names it, so the prompt is the one of roc install (a person: the default is yes, the answer is Enter). The list, the prompt, the install, then the probes.",
     f"env:HOME={{w}}/home2 roc use {N} --file p6/main.roc"),
    (f"# R-U2 R-U3 R-DL1 R-DL5 R-NI5 (question Q4): HOME is home4, which has no compiler. N (new) and O (baseline) are both missing. No person (CI) and --allow-downloads: no prompt, one answer line that names the count and the total size, 2 installs, the probes.",
     f"env:CI=true env:HOME={{w}}/home4 roc use {N} --file p7/main.roc --allow-downloads"),
    (f"# R-U3 R-NI5 R-DL1 R-DL3 (question Q4): HOME is home5, which has N only. The baseline O is the one download. The command does not name it, so the prompt is the one of `roc use` (the default is Yes) and the answer is Enter (the default is Yes, review of slice 026b).",
     f"env:HOME={{w}}/home5 roc use {N} --file p8/main.roc"),
    (f"# R-U3 R-NI5 R-DL1 R-DL4 R-EC13 (question Q4): HOME is home3, which has no compiler, no person, no flag. The 2 downloads are in one stop with the count and the size: exit 13. Nothing is downloaded, nothing is written.",
     f"env:CI=true env:HOME={{w}}/home3 roc use {N} --file p9/main.roc"),
    ("# R-U1 R-R4 R-LK3: a link build is no pin. Exit 2 with no Fx call (the text says to use ROC_TOOLCHAIN or tln roc default).",
     "roc use link-dev"),
    (f"# R-U1 R-LK3: a prefix of an installed link build (HOME is home6): the operand names an installed id, and that id is a link build. Exit 2, nothing is written.",
     f"env:HOME={{w}}/home6 roc use link --file p16/main.roc"),
    (f"# R-U4 R-EC2: --no-check is an error for roc use (R-H6 allows no pin move without the check). Exit 2 with no Fx call.",
     f"roc use {N} --no-check"),
    (f"# R-U5 R-NS7: talon.toml has [toolchain] roc = \">=nightly-2026-10-12-2664a27\" and the operand is O, which is older. The command names the range, writes nothing, and does not edit talon.toml. No probe. Exit 10 (review of slice 026b: as R-NS2).",
     f"roc use {O} --file p12/main.roc"),
    (f"# R-U5 R-NS5 R-NS2: the nightly switch is off (TALON_NIGHTLY=0) and the operand is a nightly. The command names the switch and its source. No probe, no write. Exit 10.",
     f"env:TALON_NIGHTLY=0 roc use {N} --file p13/main.roc"),
    (f"# R-U3 R-H6 R-EC11 R-BL5: the baseline passes and the candidate has a new error in an app file: exit 11, the header is not written, no build. The temp copy is deleted (R-CC2).",
     f"roc use {N} --file p14/main.roc"),
    (f"# R-U3 R-H6 R-BL5 R-P6: the app has errors already (baseline). The candidate has the same errors and nothing new: it passes, the errors are notes, and the pin is written. The build has the same errors too.",
     f"roc use {N} --file p15/main.roc"),
    (f"# R-U3 R-NI5 R-DL5 R-EC13 (question Q4): HOME is home9, which has N only. The baseline O is missing and TALON_AUTO_INSTALL=no: the command refuses with the text of the refusal (exit 13), and it does not ask. Nothing is written.",
     f"env:TALON_AUTO_INSTALL=no env:HOME={{w}}/home9 roc use {N} --file p17/main.roc"),
    (f"# R-J3 R-OUT4 R-U3 R-DL5 R-NI5: a package member (p18, the pin O) with --json. HOME is home7, which has N only. The baseline O is the one download (CI and --allow-downloads: no prompt). data.downloads is 1, data.build is null (no member is an app), 2 probes.",
     f"env:CI=true env:HOME={{w}}/home7 roc use {N} --file p18/main.roc --allow-downloads --json"),
    (f"# R-SO2 R-BL1 R-DL1 R-NI6 R-U6: ROC_TOOLCHAIN is N, the new compiler, and N is missing (HOME is home10, which has O only). p19 has no pin, so its baseline is N too. N is one download (the prompt of roc install, Enter): the list has one entry, not 2.",
     f"env:HOME={{w}}/home10 env:ROC_TOOLCHAIN={N} roc use {N} --file p19/main.roc"),
    (f"# R-U3 R-NI5 R-DL3 (question Q4): HOME is home8, which has N only. The baseline O is missing, the person answers n: exit 13, nothing is downloaded, nothing is written.",
     f"env:HOME={{w}}/home8 roc use {N} --file p20/main.roc"),
    (f"# R-BL1 R-U3 (R-RC4): the baseline check crashes (SIGSEGV) on its own compiler O. The command stops and names O, not N (the compiler of the baseline is not the new one). Nothing is written.",
     f"roc use {N} --file p21/main.roc"),
    (f"# R-U3 R-NI5 R-DL1 R-DL3 (question Q4): HOME is home11, which has no compiler. N (new) and O (baseline) are both missing and a person is asked: one prompt for both, the default is Yes (the command names its download, review of slice 026b), the answer is Enter.",
     f"env:HOME={{w}}/home11 roc use {N} --file p22/main.roc"),
    (f"# R-H1 (question Q7, a proposal): the only member has the new pin already, in the other tag form. No download, no probe, no write. The one line says so. Exit 0.",
     f"roc use {N} --file p23/main.roc"),
    (f"# R-U5 R-NS1 R-NS7 (review of slice 026b): talon.toml has [toolchain] roc = \">=nightly-2026-10-14-ffffff0\". N and the bound are two nightlies of one day. By the tag text N is below the bound, by `published_at` (HOME is home12: the bound at 10:00, N at 15:00) N is in the range. The order of time wins: the pin is written.",
     f"env:HOME={{w}}/home12 roc use {N} --file p24/main.roc"),
    (f"# R-U5 R-NS1 R-NS2 (review of slice 026b): the same range, but N is missing (HOME is home13). The time of N comes from the list (2026-10-14 15:00), the bound is installed (10:00). N is in the range, so the one download (the prompt of roc install, Enter) and the pin follow.",
     f"env:HOME={{w}}/home13 roc use {N} --file p25/main.roc"),
    (f"# R-CV1 R-U6 R-J3 (gap rows of the test agent): ROC_TOOLCHAIN is the other tag form of N. p26 has no pin, so its baseline is that form: it is the new compiler, so it is not started again (no second Start). The pin is written, the note is in data.notes (the last text) with --json.",
     f"env:ROC_TOOLCHAIN=nightly-2026-October-14-38a3029 roc use {N} --file p26/main.roc --json"),
    (f"# R-U6 (gap row): ROC_TOOLCHAIN is set, but p23 has the pin already: nothing is written, so there is no note. One line, exit 0.",
     f"env:ROC_TOOLCHAIN={O} roc use {N} --file p23/main.roc"),
    (f"# R-NS2 R-U3 (gap row): the pin of p28 is the release 0.1.0, which is not installed. No list has a release compiler, so the command stops before any offer (no list request): the failure of Compiler.require, no probe, no write.",
     f"roc use {N} --file p28/main.roc"),
    (f"# R-CC7 R-H6 (gap row): the header of p29 changes between the first read and the write (a hook after the first probe round changes the text of the roc entry, which the command edits). The write sees it: exit 17, nothing is written. A change outside the span of the edit is no stop (R-H1).",
     f"roc use {N} --file p29/main.roc"),
]
put("fx/commands", "\n".join(f"{c}\n{r}" for c, r in runs) + "\n")
put("rules", 'R-CS1 R-U1 R-U2 R-U3 R-U4 R-U5 R-U6 R-RP1 R-PH8 R-H1 R-H6 R-SL7 R-BL1 R-BL3 R-BL5 R-RP3 R-SO2 R-SO6 R-NI5 R-NI6 R-DL1 R-DL3 R-DL4 R-DL5 R-EC2 R-EC11 R-EC13 R-NS1 R-NS2 R-NS5 R-NS7 R-J3 R-OUT4 R-CC7 R-CC9 R-CV1 R-PD9 R-PD14 R-LK3 R-R4 R-RC4 (slice 026b): `tln roc use <ref>` with the fake Fx. The command is `Run.run!` for each line of `fx/commands` (entry `commands`; the fake tty is true, so a line with no `env:CI=true` has a person). The comment above each line says what it shows.\nRun 1 (home: O, N, M installed): the baseline check on the old pin O in the project dir, the candidate check and the build on N in the temp copy, a span edit of the pin (comments stay), the project is recorded. Run 2 (--json). Run 3 (no pin: the baseline is the global default, the entry is added). Run 4 (ROC_TOOLCHAIN: the note, R-U6). Run 5 (home2, N missing, a person, Enter: the prompt of roc install). Run 6 (home4, both missing, CI, --allow-downloads: 2 downloads, one answer line). Run 7 (home5, the baseline O missing, a person, Enter: the prompt of use_download, default Yes). Run 8 (home3, both missing, CI: exit 13, count and size, question Q4). Run 9 (a link build: exit 2, no Fx call). Run 10 (a prefix of an installed link build: exit 2). Run 11 (--no-check: exit 2, no Fx call). Run 12 (R-U5, the range: exit 10). Run 13 (R-U5, the switch: exit 10). Run 14 (a new error in an app file: exit 11, no write). Run 15 (the app has errors already: they are notes, the pin is written).\nRun 16 (home9, the baseline O missing, TALON_AUTO_INSTALL=no: exit 13 with the refusal text, no question). Run 17 (home7, a package member, --json, 1 download: data.downloads 1, data.build null). Run 18 (home10, ROC_TOOLCHAIN is the new compiler N and N is missing: one download, not 2). Run 19 (home8, the baseline O missing, the person answers n: exit 13). Run 20 (the baseline check crashes on its own compiler O: the text names O). Run 21 (home11, both missing, a person, Enter: one prompt for 2 compilers, default Yes). Run 22 (the member has the new pin already: question Q7, one line, no probe). Run 23 (home12, a range, two nightlies of one day: published_at orders them, not the tag text). Run 24 (home13, the same, N missing: the time of N is read from the list). Gap rows of the test agent: run 25 (ROC_TOOLCHAIN in the other tag form of N: no second start, the note is in data.notes), run 26 (ROC_TOOLCHAIN and nothing written: no note), run 27 (a release baseline that is not installed: stop before any offer), run 28 (the header changes during the run: exit 17).\nQuestion Q4 (the one prompt for the new compiler and the baseline): runs 6, 7, 8, 16, 19, 21 follow the slice file as changed by the review. The tree diff covers the dirs `home` and `project` only, so the effects in home2 to home12 are in `calls.log`.\n')
put("fx/hooks", "after-probes\t%d\tproject/p29/main.roc\t258ab27\t1111111\n" % HOOK_N)
put("entry", "commands\n")
put("fx/env", "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
put("fx/tty", "stdin=true\nstderr=true\n")
put("fx/answers", "\n\n\nn\n\n\n")
put("fx/gitdirs", ".\n")
put("fx/programs", "curl\nwget\ntar\n")
compat = {}
rows = ["# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod, R-GC10 the compat check. The first rule whose needle is in the arguments answers.",
        "curl --fail\t0\t-\t-\tfile:{out}",
        "tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details",
        "chmod 0755\t0\t-\t-\t-"]
for home in ("home2", "home3", "home4", "home5", "home7", "home8", "home9", "home10", "home11", "home13"):
    for cid in (N, O):
        sha = cid.split("-")[-1]
        rows.append(f"/{home}/.cache/roc/toolchains/{cid}.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{{w}}/{home}/.cache/roc/compat-{sha}")
rows.append("version\t0\tRoc compiler version nightly-2026-09-01-abcdef0\t-\t-")
put("fx/jobs", "\n".join(rows) + "\n")

PASS = "0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr"
BUILD = "0\t../fixtures/check/out/build-pass.stdout\t../fixtures/check/out/build-pass.stderr"
probes = []
for i in range(1, 8):
    probes += [f"# run {i}: the baseline, the candidate check and the build pass", PASS, PASS, BUILD]
probes += [
    "# run 14: the baseline passes, the candidate has a new error in an app file (main.roc has a duplicate definition): exit 11, no build",
    PASS,
    "1\t../fixtures/check/out/dup.stdout\t../fixtures/check/out/dup.stderr",
    "# run 15: the app has errors already. The candidate has the same errors (shifted lines). The build has them too.",
    "1\t../fixtures/check/out/app-errors.stdout\t../fixtures/check/out/app-errors.stderr",
    "1\t../fixtures/check/out/app-errors-shifted.stdout\t../fixtures/check/out/app-errors-shifted.stderr",
    "1\t../fixtures/check/out/build-errors.stdout\t../fixtures/check/out/build-errors.stderr",
    "# run 17: a package: the baseline and the candidate check, no build",
    PASS, PASS,
    "# run 18: the baseline, the candidate check and the build pass",
    PASS, PASS, BUILD,
    "# run 20: the baseline check crashes with SIGSEGV on its own compiler",
    "signal:11\t-\t-", PASS,
    "# run 21: the baseline, the candidate check and the build pass",
    PASS, PASS, BUILD,
    "# run 23: the range admits N by the time order",
    PASS, PASS, BUILD,
    "# run 24: the range admits N by the time of the list",
    PASS, PASS, BUILD,
    "# run 25: the baseline is the other tag form of N",
    PASS, PASS, BUILD,
    "# run 28: the header changes after the first round",
    PASS, PASS, BUILD,
]
put("fx/probes", "\n".join(probes) + "\n")
src = os.path.join(UP1, "fx/http")
shutil.copytree(src, os.path.join(ROOT, "fx/http"))
