#!/usr/bin/env python3
"""Slice 057: makes the `given/`, `fx/`, `entry` and `rules` files of the L2 cases run/rn1-scripts, run/rn2-words and run/rn3-tools (no `expect/`: UPDATE=1 writes it from the reference, TW21).
Run from the repo root: python3 research/slice-057-revert/gen-run.py. It writes only under tests/commands/cases/run/. It reads the classes of research/slice-056-revert/gen-ptools.py (the text before its first case: the file is read, never run as a whole,
so the cases of slices 048, 049 and 056 are not rewritten). The hashes are the base58 of the sha256 of a label, so they are valid package hashes and stay the same on each run."""
import hashlib, json, os, shutil

src = open("research/slice-056-revert/gen-ptools.py").read().split("# ---------------------------------------------------------------- ptool/pt1-add")[0]
exec(src)

ROOT = "tests/commands/cases/run"
EXEC_RULES = "# needle, TAB, code: the first rule whose needle is in the argv answers (default: exit 0). 143 is what the real Fx gives for a child that SIGTERM ended (128 + 15).\ntool-fail\t3\ntool-sig\t143\ntool-gone\tnotstarted:NotFound\n"


def scripts(lines):
    return "[scripts]\n" + "\n".join(lines) + "\n"


# ---------------------------------------------------------------- run/rn1-scripts
RULES = """Slice 057, `tln run` with `[scripts]`, no tool and no compiler (entry `commands`): R-CM24, R-RUN1, R-RUN2, R-RUN4, R-RUN5, R-RUN7 to R-RUN12, R-RUN14, R-RUN16, R-RUN17, R-PD9, R-PD16, R-FL1, R-FL6, R-FL7, R-EC18, R-HK1, NC1, NC2, NC4, NC5.
`TALON_NOW=2026-10-15T12:00:00Z`, `project/` has a `.git` (the stop of the walk). The fake runs no child: `fx/exec` gives the exit code by a word of the argv (`tool-fail` 3, `tool-sig` 143, `tool-gone` is not on PATH), else 0.
Projects: `p1` (a standalone project with `main.roc`, many scripts, and `sub/talon.toml` with the script `inner`), `p2` (a `talon.toml` and no app file), `p3` (a `talon.toml` with bad forms), `w` (a workspace: root with `[scripts]`, members `m1` (own `talon.toml`, script `ms`) and `m2` (no `talon.toml`) and `deep/inner`;
`w/s` is a standalone project with `main.roc`, `w/s2` a standalone `talon.toml` with no app file, `w/deep/talon.toml` has no member file of its own: the member `deep/inner/main.roc` has `deep/inner/talon.toml`, so `deep/talon.toml` is a standalone file, NC4).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `run hi` in `p1` | one child in `p1`: the words are as written (no expansion, R-RUN2: the L0 rows show the words). The variables `TALON_SCRIPT=hi` and `TALON_SCRIPT_DIR=<p1>` (R-RUN9). The project file `p1/main.roc` is recorded (R-PD9) | R-RUN2, R-RUN5, R-RUN8, R-RUN9, R-PD9, R-PD16, R-RUN16 |
| 2 | `run chain -- extra words` in `p1` | `@hi` then `tool-b`: the args go to the last step (R-RUN10) | R-RUN4, R-RUN10 |
| 3 | `run tail -- last` in `p1` | the last step is `@chain`: the args go to the last step of `chain` | R-RUN10, R-RUN4 |
| 4 | `run all` in `p1` | `in` steps: the working directory is `p1/sub`, `TALON_SCRIPT_DIR` too, `TALON_SCRIPT` is `all`. The step `@inner` runs the script of `p1/sub/talon.toml` (one read of that file) | R-RUN8, R-RUN9, R-RUN4 |
| 5 | `run failing` in `p1` | the 2nd step exits 3: the 3rd does not start, the exit code is 3 | R-RUN5, R-RUN7, R-E1 |
| 6 | `run sig` in `p1` | the child ended by a signal: the code 143 passes through | R-RUN7 |
| 7 | `run gone` in `p1` | the program is not on PATH: exit 18, the message names the program and the step | R-RUN7, R-EC18 |
| 8 | `run loop-a` in `p1` | `loop-a` calls `loop-b`, which calls `loop-a`: exit 19 before the first step (`tool-x` does not run) | R-RUN4 |
| 9 | `run shell` in `p1` | the 2nd step has the word `\\|`: exit 19, and the 1st step (`tool-ok`) does not run | R-RUN2 |
| 10 | `run dangling` in `p1` | `@nothere`: exit 19 | R-RUN4 |
| 11 | `run out` in `p1` | the directory `../..` is outside the repository (the stop is `project/`): exit 19 | R-RUN8 |
| 12 | `run nofile` in `p1` | `in = "nodir"` with `@x`: that directory has no `talon.toml`: exit 19 | R-RUN8 |
| 13 | `run noname` in `p1` | `sub/talon.toml` has no script `missing`: exit 19 | R-RUN8 |
| 14 | `run nosuch` in `p1` | no `talon.toml` has the name: exit 2, the message lists the files that the walk checked | R-RUN12 |
| 15 | `run hi extra` in `p1` | a word after the name with no `--`: exit 2, no read | R-RUN10 |
| 16 | `run hi --json` in `p1` | exit 2 (the steps write to stdout) | R-FL1, R-RUN11 |
| 17 | `run hi --file x` in `p1` | exit 2 (`--file` is not a flag of `run`) | R-FL6, R-RUN16 |
| 18 | `run hi --frozen` in `p1` | exit 2 (the resolve flags are not flags of `run`) | R-FL7, R-RUN16 |
| 19 | `build` in `p1` | `tln build` is not `tln run build`: exit 2, unknown command (`p1` has a script `build`) | R-RUN17 |
| 20 | `run` in `p1` | the list: each script with its steps, on stdout | R-RUN11, R-CM24 |
| 21 | `run --json` in `p1` | the same list in `data` | R-RUN11 |
| 22 | `run s2` in `p2` | a standalone `talon.toml` with no app file: the child runs, the `talon.toml` path itself is recorded (NC1) | R-PD9, NC1 |
| 23 | `run bad` in `p3` | the table has a bad form: exit 19, the first issue by line | R-RUN1 |
| 24 | `run r` in `w/m1` | the member file `w/m1/talon.toml` has no `r`: the walk goes up to the root file. The working directory is `w`. All member files are recorded (the root file) | R-RUN12, R-RUN8, R-PD9, R-RUN14 |
| 25 | `run ms` in `w/m1` | the member file has the script: the working directory is `w/m1`, the member files of that node are recorded (only `w/m1/main.roc`) | R-RUN12, R-RUN14, R-PD9 |
| 26 | `run r` in `w/s` | `w/s` is a standalone project in a workspace directory (no member file): the walk stops there, the root script has no effect: exit 2 (NC5) | R-RUN12, NC5, NC2 |
| 27 | `run sx` in `w/s` | its own script runs in `w/s`, `w/s/main.roc` is recorded | R-RUN12, NC2, R-PD9 |
| 28 | `run sy` in `w/s2` | a standalone `talon.toml` with no app file in a workspace directory: runs, records the `talon.toml` path | NC1, NC2, R-PD9 |
| 29 | `run dp` in `w/deep/inner` | `w/deep/inner/talon.toml` is a member file and has no `dp`: the walk goes up. `w/deep/talon.toml` has no member file of its own (the member is the node `deep/inner`): one `read_files` of `w/deep/inner/talon.toml` tells it, so it is a standalone file and holds `dp` | R-RUN12, NC4 |
| 30 | `run r` in `w/deep/inner` | the walk stops at the standalone file `w/deep/talon.toml`: exit 2 | R-RUN12, NC5, NC4 |
| 31 | `run r` in `w` | the root itself: working directory `w` | R-RUN12 |
| 32 | `run r` in `w/m2` | `w/m2` has no `talon.toml`: the walk goes to the root | R-RUN12 |
| 33 | `run r` in `.` | no `talon.toml` on the walk: exit 2, the message lists the directories | R-RUN12 |
| 34 | `run -- x` in `p1` | words after `--` and no name: exit 2, the words need a script name (Q1 of the review) | R-RUN10, R-RUN11 |
| 35 | `run unclosed` in `p1` | the 2nd step has a quote that is not closed: exit 19 with the script named, and the 1st step (`tool-ok`) does not run (Q3 of the review) | R-RUN2 |
"""
c = Case("rn1-scripts", RULES)
c.write("fx/gitdirs", ".\n")
c.write("fx/exec", EXEC_RULES)
c.write("given/project/p1/main.roc", app_text(deps=()))
c.write("given/project/p1/talon.toml", scripts([
    'hi = "tool-a one \\"two words\\" \'three four\' $HOME ~ *.txt"',
    'chain = ["@hi", "tool-b"]',
    'tail = ["tool-c", "@chain"]',
    'all = [{ in = "sub", run = "tool-d x" }, { in = "sub", run = "@inner" }]',
    'failing = ["tool-ok", "tool-fail", "tool-never"]',
    'sig = "tool-sig"',
    'gone = "tool-gone --flag"',
    'loop-a = ["tool-x", "@loop-b"]',
    'loop-b = "@loop-a"',
    'shell = ["tool-ok", "tool-p | tool-q"]',
    'dangling = "@nothere"',
    'out = [{ in = "../..", run = "tool-o" }]',
    'nofile = { in = "nodir", run = "@x" }',
    'noname = { in = "sub", run = "@missing" }',
    'build = "tool-build"',
    'unclosed = [\'tool-ok\', \'tool-q "two words\']',
]))
c.write("given/project/p1/sub/talon.toml", scripts(['inner = "tool-e"']))
c.write("given/project/p2/talon.toml", scripts(['s2 = "tool-s2"']))
c.write("given/project/p3/talon.toml", scripts(['ok = "tool-ok"', 'bad = { in = "x" }', '"Bad Name" = "x"']))
c.write("given/project/w/talon.toml", '[workspace]\nmembers = ["m1/main.roc", "m2/main.roc", "deep/inner/main.roc"]\n\n' + scripts(['r = "tool-r"']))
c.write("given/project/w/m1/main.roc", app_text(deps=()))
c.write("given/project/w/m1/talon.toml", "[dependencies]\n\n" + scripts(['ms = "tool-m"']))
c.write("given/project/w/m2/main.roc", app_text(deps=()))
c.write("given/project/w/s/main.roc", app_text(deps=()))
c.write("given/project/w/s/talon.toml", scripts(['sx = "tool-sx"']))
c.write("given/project/w/s2/talon.toml", scripts(['sy = "tool-sy"']))
c.write("given/project/w/deep/talon.toml", scripts(['dp = "tool-dp"']))
c.write("given/project/w/deep/inner/main.roc", app_text(deps=()))
c.write("given/project/w/deep/inner/talon.toml", scripts(['di = "tool-di"']))
c.finish([
    "run hi cwd:p1",
    "run chain -- extra words cwd:p1",
    "run tail -- last cwd:p1",
    "run all cwd:p1",
    "run failing cwd:p1",
    "run sig cwd:p1",
    "run gone cwd:p1",
    "run loop-a cwd:p1",
    "run shell cwd:p1",
    "run dangling cwd:p1",
    "run out cwd:p1",
    "run nofile cwd:p1",
    "run noname cwd:p1",
    "run nosuch cwd:p1",
    "run hi extra cwd:p1",
    "run hi --json cwd:p1",
    "run hi --file x cwd:p1",
    "run hi --frozen cwd:p1",
    "build cwd:p1",
    "run cwd:p1",
    "run --json cwd:p1",
    "run s2 cwd:p2",
    "run bad cwd:p3",
    "run r cwd:w/m1",
    "run ms cwd:w/m1",
    "run r cwd:w/s",
    "run sx cwd:w/s",
    "run sy cwd:w/s2",
    "run dp cwd:w/deep/inner",
    "run r cwd:w/deep/inner",
    "run r cwd:w",
    "run r cwd:w/m2",
    "run r",
    "run -- x cwd:p1",
    "run unclosed cwd:p1",
])
# the last run is in `project/` itself, which has no `talon.toml`: the `.git` of `project/` ends the walk

# ---------------------------------------------------------------- run/rn2-words
RULES = """Slice 057, the first word of a step: `roc`, `tln` and a `.roc` script (entry `commands`): R-RUN3 (point 1), R-RUN6, R-RUN9, R-RUN7, R-PX1, R-E1. One home with the compiler `nightly-2026-10-14-38a3029` installed. The fake runs no child.
`p1` has the scripts `v` (`roc +<id> version`), `t` (`tln --version`), `s` (a `.roc` script with a flag), `tf` (`tln frobnicate`, then a step that must not run) and `w` (a `.roc` script with no more words).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `run v` in `p1` | the proxy of this `tln` selects the compiler (rank 1, `+<id>`) and runs it by its path in the directory of the step. The `exec_in` line has the compiler file and the 2 variables of R-RUN9 (the proxy adds its own) | R-RUN3, R-PX1, R-RUN9, R-RUN5 |
| 2 | `run t` in `p1` | `tln --version`: this `tln` runs the words (the version line on stdout), no child | R-RUN3 |
| 3 | `run s -- more` in `p1` | a first word that ends with `.roc`: `roc scripts/notes.roc -- --since v1 more` through the proxy, in the directory of the step. The target file is relative to that directory | R-RUN6, R-RUN3, R-RUN10, R-PX1 |
| 4 | `run tf` in `p1` | `tln frobnicate` is an unknown command: its exit code 2 stops the run, the next step does not start | R-RUN7, R-RUN3 |
| 5 | `run w` in `p1` | a `.roc` script with no more words: `roc scripts/notes.roc --` (the `--` stays, R-RUN6) | R-RUN6 |
"""
c = Case("rn2-words", RULES)
c.write("fx/gitdirs", ".\n")
c.write("fx/exec", EXEC_RULES)
c.write("fx/path-roc", "# a tln of 5000 bytes\nexe /fake/bin/tln 5000 1700000000\n")
c.toolchain(PIN)
c.write("given/project/p1/main.roc", app_text(deps=()))
c.write("given/project/p1/scripts/notes.roc", app_text(deps=()))
c.write("given/project/p1/talon.toml", scripts([
    f'v = "roc +{PIN} version"',
    't = "tln --version"',
    's = "scripts/notes.roc --since v1"',
    'tf = ["tln frobnicate", "tool-never"]',
    'w = "scripts/notes.roc"',
]))
c.finish(["run v cwd:p1", "run t cwd:p1", "run s -- more cwd:p1", "run tf cwd:p1", "run w cwd:p1"], env_extra=[])

# ---------------------------------------------------------------- run/rn3-tools
RULES = """Slice 057, `tln run` with project tools `[tools]` (entry `commands`): R-RUN3 (point 2 and 3), R-RUN8, R-RUN11, R-PT8, R-PT9, R-PT10, R-PT12, R-PT15, R-DL7, R-DL2, R-RUN16, R-PD9, OP4, NC2, Q-S15. One home with the compiler `nightly-2026-10-14-38a3029` installed, the platform in the package cache,
`TALON_NOW=2026-10-15T12:00:00Z`, no `TALON_AUTO_INSTALL`, no terminal (non-interactive). The fake runs no child (default exit 0). The fake `roc build` writes the output file. A global tool `fmt` is in `tools.json` with a binary in the bin dir: a project tool never runs it (R-PT12).
Projects: `p1` has the tool `fmt` (acme/fmt 1.0.0, its `x` entry has the binary) and the scripts `ck`, `all` (an `in` step). `p2` has `gen` (acme/gen 1.0.0, no `x` entry: the first run builds it). `p3` has `old` (its app pins a compiler that is not installed). `p4` has `off` (acme/zz: its bundle is not in the cache).
`p5` has `bd` (acme/bad: its build fails). `p6` has `nu` (a `[tools]` key `lz` with no `url`). `p7` has `w` (a `[tools]` entry with an unknown key, a step with no tool). The workspace `w` has `[tools]` with `foo` in its root file, a member `w/m1` with a script `mc`, and `w/s`, a standalone project in a workspace directory with its own `[tools]` (`own`) and no `foo`.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `run ck` in `p1` | the first word `fmt` is a key: the binary of its `x` entry runs (`<home>/.cache/roc/talon/x/<digest>/fmt`, not the global binary), in `p1`, with the 2 variables of R-RUN9 only (no `PATH`). No request, no read of `tools.json`, no write (R-PT8, R-PT12). The next step (`tool-after`) is a program of `PATH` | R-RUN3, R-PT9, R-PT8, R-PT10, R-PT12, R-RUN16 |
| 2 | `run all` in `p1` | an `in` step uses the same table: `fmt` is the project tool, the working directory is `p1/sub`. No more `x` read than run 1 for the table | R-RUN8, R-RUN3, OP4 |
| 3 | `run mk` in `p2` | no `x` entry for the bundle of the `url`: the bundle is fetched and built (the platform line and the build line on stderr), the entry is written, the new binary runs. The compiler is the pin of the app, which is installed. No release list (R-PT8) | R-PT9, R-PT6, R-RUN16 |
| 4 | `run mk` in `p2` | the entry of run 3 is there: no build, the binary runs | R-PT9 |
| 5 | `run nc` in `p3` | the build needs a compiler that is not installed: a required download (R-DL2), non-interactive, no consent: exit 13 (the text names `--yes` and `TALON_AUTO_INSTALL=yes`, not `--allow-downloads`, which `run` refuses: Q6 of the review), no child | R-PT9, R-DL7, R-DL2 |
| 6 | `run off --offline` in `p4` | no binary, no bundle in the cache, `--offline`: exit 15 | R-PT15, R-FL3 |
| 7 | `run mc` in `w/m1` | the script is in the member file; the table is the `[tools]` of the root file `w/talon.toml` (OP4): `foo` is its tool, the binary runs in `w/m1` | R-RUN3, OP4, R-PT2 |
| 8 | `run so` in `w/s` | the standalone project in a workspace directory has its own table (NC2): `own` is its tool. The step `foo go` is not a key of that table: it is a program of `PATH` (the root `[tools]` has no effect on it) | R-RUN3, NC2, R-PT2 |
| 9 | `run` in `p1` | the list, and the note on stderr for the key `fmt` that is also a program on `PATH` (`fx/programs`) | R-RUN11, Q-S15 |
| 10 | `run bd` in `p5` | the build fails: exit 11 (as `tln x`), the step after it does not start | R-PT9, R-PT6, R-RUN5 |
| 11 | `run nu` in `p6` | the key `lz` has no `url`: exit 14, the text names `tln install` (Q2 of the review), no child, no request | R-PT7, R-PT9, R-RUN3 |
| 12 | `run w` in `p7` | the `[tools]` table has an unknown key (`note`): the warning goes on stderr as `warning: <file>:<line>: <message>` before the step, which does not use a tool and runs (C8 of the verify results) | R-RUN3, R-PT1 |
"""
c = PCase("rn3-tools", RULES)
ROOT = "tests/commands/cases/run"
c.toolchain(PIN)
c.platform()
c.platform_cached()
for repo in ("acme/gen", "acme/bad"):
    releases(c, repo, [("1.0.0", OLD)])
releases(c, "acme/yy", [("1.0.0", OLD)], text=app_text(pin=PIN2))
for repo in ("acme/fmt", "acme/foo", "acme/own"):
    c.xentry(repo, "1.0.0")
c.tools([{"key": "fmt", "name": "acme/fmt", "source": release("1.0.0", "acme/fmt", "1.0.0", "fmt-1.0.0")}])
c.files("fmt", data="the global fmt\n", entry="the global fmt\n")
c.project("p1", toml=tools_toml([tool_entry("fmt", "acme/fmt@^1", tool_url("acme/fmt", "1.0.0"))]) + "\n" + scripts(['ck = ["fmt --check src", "tool-after"]', 'all = [{ in = "sub", run = "fmt --in-sub" }]']))
c.project("p2", toml=tools_toml([tool_entry("gen", "acme/gen@^1", tool_url("acme/gen", "1.0.0"))]) + "\n" + scripts(['mk = ["gen --make", "tool-after"]']))
c.project("p3", toml=tools_toml([tool_entry("old", "acme/yy@^1", tool_url("acme/yy", "1.0.0"))]) + "\n" + scripts(['nc = ["old --x", "tool-after"]']))
c.project("p4", toml=tools_toml([tool_entry("off", "acme/zz@^1", tool_url("acme/zz", "1.0.0"))]) + "\n" + scripts(['off = ["off --x", "tool-after"]']))
c.project("p6", toml=tools_toml([tool_entry("lz", "acme/lz@^1")]) + "\n" + scripts(['nu = ["lz --x", "tool-after"]']))
c.project("p7", toml='[tools]\nfmt = { ref = "acme/fmt@^1", url = "' + tool_url("acme/fmt", "1.0.0") + '", note = "x" }\n\n' + scripts(['w = "tool-after"']))
c.project("p5", toml=tools_toml([tool_entry("bd", "acme/bad@^1", tool_url("acme/bad", "1.0.0"))]) + "\n" + scripts(['bd = ["bd --x", "tool-after"]']))
c.write("given/project/w/talon.toml", '[workspace]\nmembers = ["m1/main.roc"]\n\n' + tools_toml([tool_entry("foo", "acme/foo@^1", tool_url("acme/foo", "1.0.0"))]) + "\n" + scripts(['wr = "foo root"']))
c.write("given/project/w/m1/main.roc", app_text(deps=()))
c.write("given/project/w/m1/talon.toml", scripts(['mc = ["foo go", "tool-after"]']))
c.write("given/project/w/s/main.roc", app_text(deps=()))
c.write("given/project/w/s/talon.toml", tools_toml([tool_entry("own", "acme/own@^1", tool_url("acme/own", "1.0.0"))]) + "\n" + scripts(['so = ["own go", "foo go"]']))
c.finish(
    [
        "run ck cwd:p1",
        "run all cwd:p1",
        "run mk cwd:p2",
        "run mk cwd:p2",
        "run nc cwd:p3",
        "run off --offline cwd:p4",
        "run mc cwd:w/m1",
        "run so cwd:w/s",
        "run cwd:p1",
        "run bd cwd:p5",
        "run nu cwd:p6",
        "run w cwd:p7",
    ],
    [BUILD_OK, BUILD_FAIL],
    programs=("curl", "wget", "tar", "fmt"),
)
