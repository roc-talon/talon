#!/usr/bin/env python3
"""Slice 058: makes the `given/`, `fx/`, `entry` and `rules` files of the L2 case run/rn4-each (no `expect/`: UPDATE=1 writes it from the reference, TW21).
Run from the repo root: python3 research/slice-058-revert/gen-each.py. It writes only under tests/commands/cases/run/rn4-each/. It reads the text of research/slice-057-revert/gen-run.py before its first case (the classes and `scripts`, `EXEC_RULES`):
the file is read, never run as a whole, so the cases of slice 057 are not rewritten. The hashes are the base58 of the sha256 of a label, so they stay the same on each run."""
import hashlib, json, os, shutil

src = open("research/slice-057-revert/gen-run.py").read().split("# ---------------------------------------------------------------- run/rn1-scripts")[0]
exec(src)

ROOT = "tests/commands/cases/run"


def app_paths(paths=()):
    """The header of an app with the platform and path entries (key, path)."""
    lines = ["app [main!] {", f'\tpf: platform "{PF}",']
    for key, path in paths:
        lines.append(f'\t{key}: "{path}",')
    lines += [f'\troc: "{PIN}",', "}", "", "main! = |_args| Ok({})"]
    return "\n".join(lines) + "\n"


RULES = """Slice 058, `tln run --each` (entry `commands`): R-RUN13, R-RUN10 (OP9), R-RUN8 (Q-S13), R-EA1 to R-EA8, R-FL12, R-FL1, R-RUN7, R-RUN9, R-PD9, R-PD3, R-PD5, R-PD6, R-WS5, NC2, NC4, NC5, Q-S6, Q-S12.
`TALON_NOW=2026-10-15T12:00:00Z`, `project/` has a `.git` (the stop of the walk). The fake runs no child: `fx/exec` gives the exit code by a word of the argv (`tool-fail` 3, `tool-sig` 143, `tool-gone` is not on PATH), else 0.
Workspace `w1` (root members `workers/*/main.roc` and `zlib/main.roc`; the root has the scripts `build`, `fail` and `ins`, which no `--each` run may start):

| Node | `talon.toml` | Edges |
| --- | --- | --- |
| `workers/Admin` | scripts `build`, `fail`, `gone` | none (`A` is before `a` in byte order) |
| `workers/api` | scripts `build`, `fail`, `gone` | its header has the path entry `mid: "../mid/main.roc"`: api after mid (kind path) |
| `workers/ledger` | scripts `build`, `fail` (exit 3), `gone` (not on PATH) | none |
| `workers/mid` | `[run] after = ["../../zlib"]`, the script `other` only (no `build`, no `fail`) | mid after zlib (kind after) |
| `workers/web` | `[run] after = ["../ledger"]`, `build` with 2 steps, `fail`, `gone` | web after ledger (kind after) |
| `zlib` | scripts `build`, `fail` (a signal, 143), `gone` | none |
| `workers/solo` | a standalone `talon.toml` (its app file is `app.roc`: no member file), script `build` | not a node (NC4) |
| `workers/talon.toml` | a `talon.toml` above the nodes, with no member file of its own, script `build` | not a node (NC4) |

The order of `w1` (Kahn, the smallest ready path first): Admin, ledger, web, zlib, mid, api. A depth first order would be different. `mid` has no `build`: it is not run, and the edge api after mid after zlib stays (R-EA4).
Other workspaces: `w2` (a after b by `after`, b after a by a path entry: a cycle), `w3` (`after` names a directory that is no node), `w4` (the node `b` has a shell word in its script, the node `a` is first). `p1` is a standalone project (no workspace).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `run --each build` in `w1` | one line `running <node>` on stderr and the steps of `build` for each node that has it, in the order of `w1`: Admin, ledger, web (2 steps), zlib, api. The directory of each step is its node and `TALON_SCRIPT=build` (R-RUN9). The root, `solo` and `workers/` (standalone) do not run. The member files of the root are recorded | R-RUN13, R-EA1, R-EA2, R-EA3, R-EA4, R-EA6, R-EA7, R-RUN9, R-PD9, NC4, Q-S6, Q-S12 |
| 2 | `run --each build -- --fast x` in `w1` | the args go to the last step of the script in each node (web: only its second step) | R-RUN10, OP9, R-RUN13 |
| 3 | `run --each` in `w1` | no name: the order and the edges on stdout, nothing runs (no `exec_in`) | R-EA8 |
| 4 | `run --each --json` in `w1` | the same in `data` (`order` and `edges` with `from`, `to`, `kind`) | R-EA8, R-J3 |
| 5 | `run --each fail` in `w1` | Admin runs, ledger fails with 3: the command stops, exit 3, no later node starts | R-EA7, R-RUN7 |
| 6 | `run --each fail --keep-going` in `w1` | ledger fails (3): web is skipped (`skipped workers/web (after workers/ledger)`), zlib runs and ends by a signal (143), api is skipped (`(after zlib)`: it comes after zlib through `mid`, which has no `fail`). Exit 3: the code of the first failure | R-EA7, R-EA4, R-RUN7 |
| 7 | `run --each gone --keep-going` in `w1` | ledger cannot start (exit 18, the failure line): a failure of that node, web is skipped, zlib and api run. Exit 18 | R-EA7, R-RUN7 (a proposal: a node that cannot start is a failed node) |
| 8 | `run --keep-going build` in `w1` | `--keep-going` needs `--each`: exit 2, nothing is read | R-FL12 |
| 9 | `run ins` in `w1` | the `in` steps of a root script run in the order of the script (web, then ledger), also when web is after ledger by `after` | R-RUN8, R-EA3, Q-S13 |
| 10 | `run --each build` in `w1/workers/web` | the command works on the workspace of the walk: the same nodes in the same order as run 1 | R-RUN13, R-PD3 |
| 11 | `run --each build` in `w2` | a cycle: exit 19, `a -after-> b -path-> a`, no step runs | R-EA5, R-EA2, R-EA3 |
| 12 | `run --each build` in `w3` | `after` names a directory that is no node: exit 19, the message names the file and the entry | R-EA3 |
| 13 | `run --each build` in `w4` | the second node has a shell word: exit 19 before the first step (the first node does not run) | R-RUN2, R-RUN13 |
| 14 | `run --each build` in `p1` | no workspace: exit 2 | R-RUN13 |
| 15 | `run --each build` in `w1/workers/solo` | a standalone project inside a workspace directory: the walk stops at its own `talon.toml`, the workspace has no effect (R-PD5): as with no workspace, exit 2. Nothing is recorded, no node runs | R-RUN13, NC2, NC5, R-PD5 |
"""
c = Case("rn4-each", RULES)
c.write("fx/gitdirs", ".\n")
c.write("fx/exec", EXEC_RULES)
W = "given/project/w1"
c.write(f"{W}/talon.toml", '[workspace]\nmembers = ["workers/*/main.roc", "zlib/main.roc"]\n\n' + scripts([
    'build = "tool-root build"',
    'fail = "tool-root fail"',
    'ins = [{ in = "workers/web", run = "tool-in-web" }, { in = "workers/ledger", run = "tool-in-ledger" }]',
]))
for name in ("workers/Admin", "workers/api", "workers/ledger", "workers/mid", "workers/web", "zlib"):
    paths = [("mid", "../mid/main.roc")] if name == "workers/api" else []
    c.write(f"{W}/{name}/main.roc", app_paths(paths))
tool = lambda n, build, fail, gone: scripts([f'build = {build}', f'fail = "{fail}"', f'gone = "{gone}"'])
c.write(f"{W}/workers/Admin/talon.toml", tool("Admin", '"tool-admin build"', "tool-ok admin", "tool-ok admin"))
c.write(f"{W}/workers/api/talon.toml", tool("api", '"tool-api build"', "tool-ok api", "tool-ok api"))
c.write(f"{W}/workers/ledger/talon.toml", tool("ledger", '"tool-ledger build"', "tool-fail ledger", "tool-gone ledger"))
c.write(f"{W}/workers/mid/talon.toml", '[run]\nafter = ["../../zlib"]\n\n' + scripts(['other = "tool-mid other"']))
c.write(f"{W}/workers/web/talon.toml", '[run]\nafter = ["../ledger"]\n\n' + tool("web", '["tool-web one", "tool-web two"]', "tool-ok web", "tool-ok web"))
c.write(f"{W}/zlib/talon.toml", tool("zlib", '"tool-zlib build"', "tool-sig zlib", "tool-ok zlib"))
c.write(f"{W}/workers/solo/app.roc", app_paths())
c.write(f"{W}/workers/solo/talon.toml", scripts(['build = "tool-solo build"']))
c.write(f"{W}/workers/talon.toml", scripts(['build = "tool-workers build"']))
# w2: a cycle. a is after b by `after`, b is after a by a path entry
c.write("given/project/w2/talon.toml", '[workspace]\nmembers = ["a/main.roc", "b/main.roc"]\n')
c.write("given/project/w2/a/main.roc", app_paths())
c.write("given/project/w2/a/talon.toml", '[run]\nafter = ["../b"]\n\n' + scripts(['build = "tool-a"']))
c.write("given/project/w2/b/main.roc", app_paths([("a", "../a/main.roc")]))
c.write("given/project/w2/b/talon.toml", scripts(['build = "tool-b"']))
# w3: `after` names a directory that is no node
c.write("given/project/w3/talon.toml", '[workspace]\nmembers = ["a/main.roc", "b/main.roc"]\n')
c.write("given/project/w3/a/main.roc", app_paths())
c.write("given/project/w3/a/talon.toml", '[run]\nafter = ["../nope"]\n\n' + scripts(['build = "tool-a"']))
c.write("given/project/w3/b/main.roc", app_paths())
c.write("given/project/w3/b/talon.toml", scripts(['build = "tool-b"']))
# w4: a shell word in the second node
c.write("given/project/w4/talon.toml", '[workspace]\nmembers = ["a/main.roc", "b/main.roc"]\n')
c.write("given/project/w4/a/main.roc", app_paths())
c.write("given/project/w4/a/talon.toml", scripts(['build = "tool-a ok"']))
c.write("given/project/w4/b/main.roc", app_paths())
c.write("given/project/w4/b/talon.toml", scripts(['build = ["tool-b", "tool-p | tool-q"]']))
c.write("given/project/p1/main.roc", app_paths())
c.write("given/project/p1/talon.toml", scripts(['build = "tool-p1"']))
c.finish([
    "run --each build cwd:w1",
    'run --each build -- --fast x cwd:w1',
    "run --each cwd:w1",
    "run --each --json cwd:w1",
    "run --each fail cwd:w1",
    "run --each fail --keep-going cwd:w1",
    "run --each gone --keep-going cwd:w1",
    "run --keep-going build cwd:w1",
    "run ins cwd:w1",
    "run --each build cwd:w1/workers/web",
    "run --each build cwd:w2",
    "run --each build cwd:w3",
    "run --each build cwd:w4",
    "run --each build cwd:p1",
    "run --each build cwd:w1/workers/solo",
])
