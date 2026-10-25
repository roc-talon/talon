#!/usr/bin/env python3
"""Slice 059: makes the `given/`, `fx/`, `entry` and `rules` files of the L2 case x/x3-project (no `expect/`: UPDATE=1 writes it from the reference, TW21).
Run from the repo root: python3 research/slice-059-revert/gen-x.py. It writes only under tests/commands/cases/x/x3-project/ (it deletes that dir first). It copies the home of the case run/rn3-tools (the compiler, the x entries, the global tool fmt)."""
import os, shutil

SRC = "tests/commands/cases/run/rn3-tools"
DST = "tests/commands/cases/x/x3-project"
shutil.rmtree(DST, ignore_errors=True)
os.makedirs(DST + "/given")
shutil.copytree(SRC + "/given/home", DST + "/given/home")
os.makedirs(DST + "/fx")
for name in ["env", "programs", "path-roc", "probes", "jobs"]:
    shutil.copy(f"{SRC}/fx/{name}", f"{DST}/fx/{name}")
shutil.copytree(SRC + "/fx/src", DST + "/fx/src")
open(DST + "/entry", "w").write("commands\n")


def put(path, text):
    full = f"{DST}/given/project/{path}"
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w").write(text)


APP = open(SRC + "/given/project/p1/main.roc").read()
U_FMT = "https://github.com/acme/fmt/releases/download/1.0.0/HUhnMnhZM81eHg9NRfEG9pEAF7nB6oFTRCvpt5oTUAdS.tar.zst"
U_GEN = "https://github.com/acme/gen/releases/download/1.0.0/kLr6hRCJDWbAZeDRzHGqu8AmF72m52j9acNNDus4YpD.tar.zst"
U_FOO = "https://github.com/acme/foo/releases/download/1.0.0/GTD8yh6ExWViorE8u3JMyK9mC5b6FRuCgpd5xNhd7xtW.tar.zst"
U_OWN = "https://github.com/acme/own/releases/download/1.0.0/7TBeuBWwAcsabfpRPKPeHdnMd8VcJ7yqiG4y24RKyRU4.tar.zst"

# p1: the tool fmt (a global tool fmt is installed too). Its [scripts] has a bad form: `tln x` never reads it (R-RUN15). A sub dir with no talon.toml: the walk goes up.
put("p1/main.roc", APP)
put("p1/talon.toml", f'[tools]\nfmt = {{ ref = "acme/fmt@^1", url = "{U_FMT}" }}\n\n[scripts]\nbad = 3\n')
put("p1/sub/notes.txt", "sub\n")
# p2: gen has no x entry: the first run builds it.
put("p2/main.roc", APP)
put("p2/talon.toml", f'[tools]\ngen = {{ ref = "acme/gen@^1", url = "{U_GEN}" }}\n')
# p6: the key lz has no url.
put("p6/main.roc", APP)
put("p6/talon.toml", '[tools]\nlz = { ref = "acme/lz@^1" }\n')
# p7: an unknown key in an entry.
put("p7/main.roc", APP)
put("p7/talon.toml", f'[tools]\nfmt = {{ ref = "acme/fmt@^1", url = "{U_FMT}", note = "x" }}\n')
# p8: a [tools] value that is not a table (exit 19).
put("p8/main.roc", APP)
put("p8/talon.toml", '[tools]\nfmt = "acme/fmt"\n')
# p9: a talon.toml and no app file (NC1: the talon.toml itself is recorded).
put("p9/talon.toml", f'[tools]\nfmt = {{ ref = "acme/fmt@^1", url = "{U_FMT}" }}\n')
# p10 (gap step): 2 entries for the app acme/fmt (the keys fmt and fmt2): `tln x acme/fmt` is exit 2 (review Q1).
put("p10/main.roc", APP)
put("p10/talon.toml", f'[tools]\nfmt = {{ ref = "acme/fmt@^1", url = "{U_FMT}" }}\nfmt2 = {{ ref = "acme/fmt@1.0.0", url = "{U_FMT}" }}\n')
# free: no talon.toml on the walk.
put("free/notes.txt", "no talon.toml here\n")
# w: a workspace with 2 members, the tool foo in its root file. w/m1 has a talon.toml (it may not have [tools]). w/s is a standalone project in a workspace directory: its own [tools] has a key foo that is another app (acme/own).
put("w/talon.toml", f'[workspace]\nmembers = ["m1/main.roc", "m2/main.roc"]\n\n[tools]\nfoo = {{ ref = "acme/foo@^1", url = "{U_FOO}" }}\n')
put("w/m1/main.roc", APP)
put("w/m1/talon.toml", '[scripts]\nmc = "foo go"\n')
put("w/m2/main.roc", APP)
put("w/s/main.roc", APP)
put("w/s/talon.toml", f'[tools]\nfoo = {{ ref = "acme/own@^1", url = "{U_OWN}" }}\n')

open(DST + "/fx/exec", "w").write("# The exit code of the fake child (default 0), by a word of its argv.\n--boom\t7\n")
open(DST + "/fx/gitdirs", "w").write(".\n")

COMMANDS = [
    ("x fmt cwd:p1 -- --check src", "the key `fmt`: the project tool, not the global `fmt`; the words after `--`", "R-PT11, R-PT12, R-X4, R-CM12, R-PD9, R-PD16, R-RUN15, R-PT8"),
    ("x acme/fmt cwd:p1/sub -- --boom", "the app of the entry, no selector, from a sub dir (the walk goes up): the note, the same binary, the exit code of the app", "R-PT11, R-E1, R-RUN12, R-PD2, R-PD9"),
    ("x acme/fmt@1.0.0 cwd:p1 --offline", "a selector: no project tool, no walk. The global flow (R-X1 to R-X5, R-B5, R-B8): the installed tool runs in place", "R-PT11, R-X1, R-B5, R-B8, R-PT12"),
    ("x gen cwd:p2", "no x entry for the bundle: the bundle is fetched and built (R-PT6), the entry is written, the binary runs. No release list", "R-PT9, R-PT6, R-PT8, R-X2, R-SE8"),
    ("x lz cwd:p6", "the key has no url: exit 14 (as `tln run`), no child", "R-PT7, R-PT9"),
    ("x fmt cwd:p8", "a [tools] value that is not a table: exit 19, no child, nothing recorded", "R-PT1, R-PT11"),
    ("x foo cwd:w/m1 -- go", "a member file: the table is the [tools] of the root file (OP4). Records only the member files of its node (w/m1/main.roc)", "R-PT11, R-PT2, OP4, R-PD9, R-WS5"),
    ("x foo cwd:w/s -- go", "a standalone project in a workspace directory: its own table (NC2, NC5): `foo` is acme/own here, not the root `foo`. Records its main.roc", "R-PT11, R-PT2, NC2, NC5, R-PD5, R-PD9"),
    ("x foo cwd:w", "the workspace root: the root table. Records all member files", "R-PT11, R-PD9, R-WS5"),
    ("x fmt cwd:p9", "a talon.toml and no app file: the talon.toml path is recorded (NC1)", "R-PD9, NC1, R-PD12"),
    ("x fmt cwd:p7", "an unknown key in an entry: the warning on stderr, the run goes on", "R-TF4, R-PT1, R-PT11"),
    ("x acme/fmt cwd:free --offline", "no talon.toml on the walk: as before (the installed tool runs, no record)", "R-PT11, R-PD16, R-B8"),
    ("x acme/fmt cwd:p10", "2 entries have the app acme/fmt: exit 2 that names both keys and says `tln x <key>` (review Q1). Nothing is recorded, no child, no `x` cache read. The key form of the same file still works (not run here: L0)", "R-PT11"),
    ("x fmt2 cwd:p10", "the key of one of the 2 entries runs it (the same binary: both urls are one bundle)", "R-PT11"),
]
open(DST + "/fx/commands", "w").write("\n".join(c for c, _, _ in COMMANDS) + "\n")

rules = """Slice 059, `tln x` of a project tool (entry `commands`): R-PT11, R-PT12, R-PT8, R-PT9, R-PD9, R-PD16, R-X4, R-RUN12, R-RUN15, NC1, NC2, NC5, OP3, OP4. One home with the compiler `nightly-2026-10-14-38a3029` installed (the pin of each app), `TALON_NOW=2026-10-15T12:00:00Z`, no tty (non-interactive). The fake `exec!` runs nothing: `fx/exec` gives the exit code by a word of the argv (`--boom` 7). The fake `roc build` writes the output file.
A global tool `fmt` (acme/fmt 1.0.0, the same bundle hash as the project tool) is in `tools.json`, with a binary in the bin dir: a project tool never runs it (R-PT12). The `x` cache has the builds of `fmt`, `foo` (acme/foo) and `own` (acme/own).
Projects: `p1` has the tool `fmt` and a `[scripts]` table with a bad form (`tln x` never reads it). `p2` has `gen` (no `x` entry). `p6` has `lz` with no `url`. `p7` has `fmt` with an unknown key. `p8` has `[tools]` with a value that is not a table. `p9` has a `talon.toml` and no app file. `p10` has 2 entries for acme/fmt (gap step). `free` has no `talon.toml`.
The workspace `w` has the members `m1` and `m2` and the tool `foo` (acme/foo) in its root file. `w/m1` has a `talon.toml` with a script and no `[tools]`. `w/s` is a standalone project in a workspace directory: its `[tools]` has the key `foo` for acme/own (the root `foo` has no effect there).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
"""
for i, (cmd, what, ids) in enumerate(COMMANDS, 1):
    rules += f"| {i} | `{cmd}` | {what} | {ids} |\n"
open(DST + "/rules", "w").write(rules)
