# 058 `tln run --each`: dependency order and `[run] after`

Phase: P1. Status: done

Slice 058 adds `tln run --each [<name>] [--keep-going] [-- <args>]` (CLI 1: R-CM24, R-RUN13, R-RUN10 with `--each`, R-FL12, R-EA1 to R-EA8). `--each <name>` runs the script `<name>` in each node of the workspace, one node at a time, in dependency order. A node is a directory that has a `talon.toml` of the workspace and a member file (R-EA1, R-WS5, NC4). Two kinds of edge give the order: the path entries of the member headers (R-EA2) and `after` in the table `[run]` (R-EA3). `--each` with no name prints the order and the edges and runs nothing (R-EA8). `--keep-going` skips each node that comes after a failed node (R-EA7).

User answers (`research/talon-scripts/design-draft/DIFF.md`): Q-S6 (a directory that others need runs first, ties in path byte order), Q-S12 (a) (no parallel runs), Q-S13 (a) (`after` does not apply to `in` steps), OP9 (a) (the args of `--` go to the last step of the script in each node), NC4 (a) (a `talon.toml` is a file of the workspace only when a member file is in its directory or below it, up to the next `talon.toml`; any other one is standalone and no node). The user of the feature is `cloudflare-workers/research/talon-fit/TRANSITION.md` 3.3.

Size (TW19): the plan row says 250. The private reference (`research/slice-058-revert/reference/`, deleted at the review, 2026-10-25) had 343 lines in `RunEach`, 175 in `RunEachFlow`, 119 in the new `RunSteps` (code moved out of `RunFlow`, which goes from 254 to 152), and about 25 lines of change in `RunCmd`, `Args`, `Intent`, `main`. About 670 new lines in all, over the limit of 400 lines of TW19, but the plan says 250 for the code that is new and 119 lines are a move. No split proposed: each module is under 330 lines.

Live reads: none. No real network and no real long build in L0 to L3. L2 uses the fake `Fx` (no child runs). L3 uses real `sh` children.

Left by slice 057 (its section 7): R-RUN13, the `--each` part of R-RUN10, `--keep-going` (the R-FL12 rows for `--each` and `--keep-going`), `[run] after` (Q-S13).

## 1. Rules, and the tests that name them

L0 is the new `expect`s 12 to 19 of `tests/unit/RunscriptTest.roc` (the 11 old ones stay). L2 is the new case `tests/commands/cases/run/rn4-each` (15 runs). L3 is the new case `tests/scenarios/run/rn2-each` (7 steps).

| Rule | Content | Tested by |
| --- | --- | --- |
| R-RUN13 | `--each <name>`: the script in each node, not the root file, in the order of R-EA1 to R-EA8. No workspace, or a start in a standalone project (NC2, NC5, R-PD5): exit 2 | L0 12, 18. L2 `rn4` runs 1, 2, 10, 14, 15. L3 steps 2, 5 |
| R-RUN10 (`--each`) | The args after `--` go to the last step of the script in each node (OP9). With no name: exit 2 | L0 18. L2 `rn4` run 2. L3 step 2 |
| R-FL12 (`--each`, `--keep-going`) | Both are flags of `run` only. `--keep-going` needs `--each`: else exit 2 | L0 18. L2 `rn4` run 8. L3 step 6 |
| R-EA1 | The nodes: the nearest `talon.toml` of a member file, not the root. A `talon.toml` above a nearer one, or with no member file, is standalone and no node | L0 12. L2 `rn4` run 1 (`workers/talon.toml`, `workers/solo`). L3 step 1 |
| R-EA2 | Edge kind 1: path entries of the member headers (a member file of a node, or a file in the directory of a node) | L0 13. L2 `rn4` runs 1, 3, 11. L3 step 7 |
| R-EA3 | Edge kind 2: `[run] after`. An entry that is no node: exit 19 with the file and the entry. `[run]` is not a table of the root file. `after` has no effect on `in` steps (Q-S13) | L0 13, 14, 19. L2 `rn4` runs 1, 9, 11, 12 |
| R-EA4 | An edge through a node with no script of the name stays | L0 15. L2 `rn4` runs 1, 6 (api after mid after zlib, `mid` has no `build` and no `fail`) |
| R-EA5 | A cycle: exit 19 before the first step, the loop with the kind of each edge | L0 15. L2 `rn4` run 11. L3 step 7 |
| R-EA6 | Ties: the smallest ready path first (byte order) | L0 15. L2 `rn4` runs 1, 3. L3 steps 1, 2 |
| R-EA7 | One node at a time, one line for each node, the first failure stops with its code. `--keep-going`: skipped nodes (direct or not), the code of the first failure | L0 16. L2 `rn4` runs 1, 5, 6, 7. L3 steps 2, 3, 4 |
| R-EA8 | No name: the order and the edges (text and `--json` `data`), nothing runs | L0 17. L2 `rn4` runs 3, 4. L3 step 1 |
| R-RUN8 (Q-S13) | `after` does not change the order of the `in` steps of a script | L2 `rn4` run 9 |
| R-RUN9 | The 2 variables in each node (the directory of the step is the node) | L2 `rn4` runs 1, 2 (`calls.log`). L3 step 2 |
| R-PD9 | `--each` records all member files of the root (before the steps, also when a later step fails) | L2 `rn4` (`projects.json`, runs 1, 11, 12, 13). L3 `tree.diff` |
| R-WS5, R-PD6, NC4 | Which `talon.toml` is a node | L0 12, 19. L2 `rn4` run 1 |
| R-PD5, NC2, NC5 | The workspace has no effect on a standalone project: `--each` there is exit 2, nothing is recorded | L0 12. L2 `rn4` run 15 |
| R-PD8 | A member file of a node with no header, or a bad header: exit 2 | L0 13 |
| R-TF4 | An unknown key of `[run]` is a warning | L0 19 |

Other rule ids that the tests name (the slice does not own them): R-RUN1, R-RUN2, R-RUN7, R-FL1, R-FL6, R-PD3, R-J3, R-OUT2, Q-S6, Q-S12, Q-S13, OP9, NC4.

Rule check: `MISSING=1 scripts/rules.sh R-EA R-RUN R-FL R-CM` lists only R-CM13, R-CM14, R-CM21, R-CM22, R-CM23 (P2 and P3). R-EA1 to R-EA8 and R-RUN13 each have a test.

## 2. Files

New files (also in `research/slice-058-revert/before/NEW.txt`). The code agent writes the bodies of the 2 stubs.

| File | Lines (stub, reference) | Content |
| --- | --- | --- |
| `cli/lib/RunEach.roc` (stub) | 95, 343 | Part A: `Node`, `Edge`, `paths`, `nodes`, `header_paths`, `read_after`, `edges`, `order`, `skipped`, `label`, `list_text`, `list_data` |
| `cli/lib/RunEachFlow.roc` (stub) | 39, 175 | Part C: `run!` (direct style) |
| `cli/lib/RunSteps.roc` (not in the stub state) | 0, 119 | The code agent makes it: `plan!`, `steps!`, `known_files`, `derived`, `exec!`, `find_entry`, `tool_run` and the types `Scan`, `Ready`, moved out of `RunFlow` (section 10) |
| `tests/unit/RunscriptTest.roc` | 339 to 537 | 8 new `expect`s (12 to 19) |
| `tests/commands/cases/run/rn4-each/` | 42 files | L2: 15 runs |
| `tests/scenarios/run/rn2-each/` | `cmd` 28, 24 files | L3: 7 steps |
| `research/slice-058-revert/` | | `stubs/`, `before/`, `ref-off.sh`, `mkstubs.py` and `mut.py` (they need the deleted reference), `gen-each.py` (writes the given, fx, entry and rules of the L2 case, no `expect/`), `mut.py`, `mutations.txt`, `red-run.log`, `green-run.log` |

Changed files (a copy of each is in `research/slice-058-revert/before/`). These changes are complete (wiring), not stubs:

| File | Change |
| --- | --- |
| `cli/lib/Args.roc` | `--each` and `--keep-going` are flags of `run` (one row of `allows`). Both are in `options` of `Args` |
| `cli/lib/RunCmd.roc` | `Cmd` has the new fields `each : Bool` and `keep_going : Bool`. In the stub state `read` gives `Bool.False` for both and has none of the new checks (the code agent writes them, section 3) |
| `cli/lib/RunFlow.roc` | `import RunEachFlow`. In `flow!`, right after `Project.scan!`: `if cmd.each { return RunEachFlow.run!(fx, args, cmd, { env, roots, now, scan }, tln) }`. The rest is as in slice 057 (the code agent moves the shared code, section 10) |
| `cli/lib/main.roc` | exposes `RunEach` and `RunEachFlow` |
| `cli/lib/Intent.roc` | not changed in the stub state. The code agent adds `"run"` to `known_tables` and `member_tables`, and refuses `[run]` in the role `Root` (section 5). L0 19 is red until then |

Old expected files that changed (TW21): none. The old L2 and L3 cases pass in the red run (143 and 75), and the old L0 `expect`s pass (55).

Module plan (TW19, the manager may change it): `RunFlow` goes from 254 to 152 lines (reference), `RunSteps` 119, `RunEachFlow` 175, `RunEach` 343, `Intent` 395 to 397. All stay under 490.

## 3. Public signatures

The L0 tests call `RunEach` and `RunCmd`, so these are fixed. `RunEachFlow.run!` is a proposed structure: the `calls.log` file fixes the order of the `Fx` calls, not the names.

### RunEach (fixed, L0 12 to 17)

| Function | Signature |
| --- | --- |
| `Node` | `{ dir : Str, members : List(Str), text : Str }` (absolute `dir` and member files, the text of its `talon.toml`) |
| `Edge` | `{ from : Str, to : Str, kind : [Path, After] }` (`from` comes after `to`) |
| `paths` | `{ root : Str, members : List(Str) } -> List(Str)` |
| `nodes` | `{ root : Str, members : List(Str), files : List({ path : Str, text : Try(Str, [None]) }) } -> List(Node)` |
| `header_paths` | `List(Node) -> List(Str)` |
| `read_after` | `{ path : Str, text : Str } -> Try(List(Str), Fail)` |
| `edges` | `{ nodes : List(Node), headers : List({ file : Str, text : Str }) } -> Try(List(Edge), Fail)` |
| `order` | `{ nodes : List(Str), edges : List(Edge), root : Str } -> Try(List(Str), Fail)` |
| `skipped` | `{ edges : List(Edge), failed : List(Str), node : Str } -> Try(Str, [None])` |
| `standalone` | `{ toml_dirs : List(Str), root : Str, nodes : List(Str) } -> Try(Str, [None])` (review: the standalone directory of the start, else `Err(None)`) |
| `label` | `{ root : Str, dir : Str } -> Str` |
| `list_text` | `{ file : Str, root : Str, order : List(Str), edges : List(Edge) } -> Str` |
| `list_data` | `{ root : Str, order : List(Str), edges : List(Edge) } -> JsonDoc` |

### RunCmd (fixed, L0 18)

`Cmd : { name : Try(Str, [None]), args : List(Str), each : Bool, keep_going : Bool }`. `RunCmd.read : Args -> Try(Cmd, Fail)`.

### Proposed structure (not fixed by an L0 test)

| Module | Function | Signature |
| --- | --- | --- |
| `RunEachFlow` | `run!` | `Fx, Args, RunCmd.Cmd, { env : List((Str, Str)), roots : Roots, now : U64, scan : <the scan of RunFlow> }, (Fx => I32) => Try(I32, Fail)` (the last argument runs a `tln` step) |
| `RunSteps` | `plan!` | `Fx, { name, args, dir, stop }, List(RunPlan.File) => Try(List(RunPlan.Flat), Fail)` |
| `RunSteps` | `steps!` | `Fx, Args, { name, ready }, List(RunPlan.Flat), (Fx => I32) => Try(I32, Fail)` |

Order of the `Fx` calls of `RunEachFlow.run!` (fixed by `calls.log` of the L2 case, the stub has the table in its doc): the calls of slice 057 up to `Project.scan!` (`args`, `env_all`, `clock`, `cwd`, `list_dirs`, one `read_files` of the `talon.toml` files of the walk, the `list_dirs` of the members), then one `read_files` of `RunEach.paths` (a missing file is no file), then `RunEach.standalone` (a start in a standalone project stops here, exit 2, nothing recorded), then `canonical` of all member files of the root and the `projects.json` write (R-PD9), then one `read_files` of `RunEach.header_paths`, then for a name one `exec_in` for each step of each node. An empty list of paths makes no call.

## 4. Tests

### L0 (`RunscriptTest`, the new `expect`s)

| # | Rows | Rules |
| --- | --- | --- |
| 12 | `paths` and `nodes`: the nearest `talon.toml` of each member file, the root file is not a node, a `talon.toml` above a nearer one is no node (NC4), a node has the member files below it up to the next `talon.toml`, nested nodes, no file, member in the root directory. `standalone`: the nearest `talon.toml` of the walk is a standalone file, a node, the root, none | R-EA1, R-WS5, R-PD6, R-RUN13, NC5 |
| 13 | `edges`: path entries (member of another node, a file that is no member in the directory of a node, the platform entry), a release URL, the same node, a path in no node or in the root directory give none; `after` (repeat, absolute entry, `.` as a cycle, `..` and an unknown entry as exit 19); the 2 kinds of one pair; the sort; a member file with no header or a bad header (exit 2); `header_paths` | R-EA2, R-EA3, R-PD8 |
| 14 | `read_after`: no table, no key, empty, a list, a string, a list with a number, `run = 1`, not TOML | R-EA3 |
| 15 | `order`: byte order of ties (`Zed` before `alpha`), Kahn (the smallest ready node first, not depth first), a chain through a node with no script, a fan, a cycle of 2, a self cycle, 2 cycles in one text, a cycle with a node after it, a cycle of 3 | R-EA4, R-EA5, R-EA6, Q-S6 |
| 16 | `skipped`: direct, indirect, through other nodes, an independent node, no failure, the first failed node of the list, a node before the failed one | R-EA7 |
| 17 | `label`, `list_text` (with edges, no edge, no node), `list_data` | R-EA8, R-EA5 |
| 18 | `Args.parse` and `RunCmd.read`: `--each` with a name and with none, `--each` after the name, `--keep-going`, `--keep-going` with no `--each`, `--json` with a name, `--file`, 2 words, `--` with no name, `--each` on `list`, `--keep-going` on `install` | R-RUN13, R-RUN10, R-FL12, R-FL1, R-FL6 |
| 19 | `Intent.read` of `[run]`: member and standalone have it with no warning, an unknown key gives a warning, the root file gives exit 19 | R-EA3, R-WS5, R-TF4 |

### L2 and L3

| Case | Content |
| --- | --- |
| `run/rn4-each` | 15 runs (the file `rules` has the table). Workspace `w1` with 6 nodes (`workers/Admin`, `api`, `ledger`, `mid`, `web`, `zlib`) and 2 standalone `talon.toml` files (`workers/solo`, `workers/talon.toml`). Runs: the full order and the steps (1), args (2), the list as text (3) and `--json` (4), a failure that stops (5), `--keep-going` with a direct and an indirect skip and 2 failures (6), a node that cannot start (7), `--keep-going` alone (8), `in` steps of a root script (9), a start inside a node (10), a cycle (11), a bad `after` (12), a shell word in the second node (13), no workspace (14), a start in a standalone project of the workspace (15) |
| `scenarios/run/rn2-each` | 7 steps with real `sh` children: the order, the args, the stop at the first failure (a signal, 143), `--keep-going` (143 first, then 3, one skip), a start inside a node, `--keep-going` alone (exit 2), a cycle (exit 19, no file made) |

The order of `w1` is Admin, ledger, web, zlib, mid, api. A depth first order gives a different list, and so does a largest first or a locale order. L3 does not depend on file age (given files keep the checkout mtime).

## 5. Output (proposed, R-OUT2, TW24)

The design gives no text for these (R-EA5 gives the form of a cycle, R-EA7 gives `skipped <dir> (after <failed dir>)`). They are proposals for the review (the expected files fix them):

| Output | Proposal |
| --- | --- |
| The line of each node (stderr, before its steps) | `running <node>`. `<node>` is the directory relative to the root (`workers/web`) |
| A skipped node (stderr, `--keep-going`) | `skipped <node> (after <failed node>)` (the text of R-EA7) |
| `--each` with no name (stdout) | `order of <root>/talon.toml:`, each node 2 spaces in (`  none` for no node), then `edges:` and each edge 2 spaces in as `<from> -<kind>-> <to>`, or `edges: none` |
| `--each --json` with no name | `data`: `{"order": [<node>], "edges": [{"from", "to", "kind": "path" or "after"}]}` (the shape is in the design) |
| A cycle | `the nodes of tln run --each depend on each other: <loop>` (exit 19). The loop is `a -after-> b -path-> a`, from the smallest node on it, one loop for each group of nodes in a cycle, joined with `; ` |
| `after` with an entry that is no node | `<dir>/talon.toml: run.after names '<entry>', which is not a node of the workspace (a directory with a talon.toml and a member file)` (exit 19) |
| `[run]` with a bad form | `<file>:<line>: run: must be a table`, `<file>:<line>: run.after: must be a list of strings (directories, relative to this file)` (exit 19) |
| `[run]` in the root file | `the table [run] is not allowed in the workspace root file (it is for the other files of the workspace, R-EA3)` (exit 19, by `Intent.read`) |
| `--keep-going` with no `--each` | `flag '--keep-going' needs --each` (exit 2) |
| `--each` with no workspace | `tln run --each needs a workspace: no talon.toml with [workspace] on the walk. Checked: <dirs>.` (exit 2) |
| `--each` in a standalone project | `tln run --each needs a workspace: <dir>/talon.toml is a standalone project (no member file of a workspace is in it) and the walk stops there.` (exit 2) |
| A member file with no or a bad header | `<path> has no app, package or platform header`, `<path>:<line>: the header is not valid` (exit 2, the texts of `Project.check_header`) |
| An unknown key of `[run]` | `<file>:<line>: unknown key run.<key>` (a warning, by `Intent.read`) |
| No node has the script | `no script '<name>' in a node of the workspace <root>.` (exit 2, see Q2) |
| A failing node | no extra line: the exit code is the code of the child. A step that cannot start gives the failure line (exit 18) |

## 6. Decisions that the design does not fix (the test agent chose)

| Decision | Chosen | Rejected |
| --- | --- | --- |
| Edge kind 1, "a file in the directory of B" (R-EA2) | The directory itself (and the member files of B, also below it). A file in a subdirectory of B that is no member gives no edge (not tested, Q1) | Any file below B up to the next `talon.toml` |
| Which node a path entry names | The node whose member list has the file, else the node whose directory is the directory of the file | The nearest node above the file |
| Edges between 2 nodes with both kinds | 2 edges, `path` before `after` in the lists | One edge |
| `after = ["."]` (a node after itself) | An edge to itself: a cycle (exit 19) | Ignore it |
| The text of a cycle | One loop for each group of nodes in a cycle, from the smallest node on it, the first edge by the order of `edges`. The example of R-EA5 starts at the node with `after`; a rule for that start is not in the design | Start at the node with `after` |
| The node of a skipped node (R-EA7) | The first failed node in the order of the run that the node comes after (through all nodes, also those with no script) | The nearest failed node |
| A step that cannot start (exit 18) in a node | The node failed with that code: the failure line, `--keep-going` goes on, the exit code is the first failure (L2 run 7) | A stop of the command also with `--keep-going` |
| All scripts are planned before the first step | The forms, the words, `@name` and the `in` directories of all nodes that have the script are checked before the first node runs (L2 run 13). It extends the decision of slice 057 | Plan each node when it starts |
| When R-PD9 records | Right after the root is known, before the nodes are read, so a later failure (a cycle, a bad `after`) still records | After the plan |
| What is recorded | All member files of the root (R-PD9: "each member file for the root file") | Only the files of the nodes that have the script |
| The `[tools]` table | The table of the workspace root for all nodes (R-RUN3 point 2). Not tested here, the tool steps are the code of slice 057 (`RunSteps.steps!`) | The table of each node |
| The workspace of `--each` | The root of the walk (R-PD3), also when the start directory is inside a node (L2 run 10). In a standalone project of the workspace: none (review Q3, L2 run 15) | Only the nodes below the start directory |
| The line of each node | On stderr (the steps own stdout) | stdout |

## 7. Out of scope

| Item | Reason |
| --- | --- |
| A tool step (`[tools]` key) in `--each` | The code is `RunSteps.steps!`, shared with slice 057 and tested by `rn3-tools`. A wrong table in `RunEachFlow` is not caught here (the reference uses the root file) |
| A script name that no node has (Q2) | The design is not clear |
| A path entry to a file below a node directory that is no member (Q1) | The design is not clear |
| `tln x <key>` | slice 059 |

## 8. Questions (TW17) and design gaps

All were answered at the review (section Review). Q1 and Q2 stay untested (accepted as the reference does):

| # | Question | Answer |
| --- | --- | --- |
| Q1 | R-EA2: "a file in the directory of B". Is a file in a subdirectory of B (no member file) in the directory of B? | No: only the directory itself and the member files of B |
| Q2 | R-RUN13: `--each <name>` and no node has the script | Exit 2, `no script '<name>' in a node of the workspace <root>.` |
| Q3 | `--each` from a standalone project in a workspace directory | Changed: exit 2 as with no workspace (L0 12, L2 run 15) |
| Q4 | A member file of a node with no header, or an invalid header | Changed: exit 2 as R-PD8 (L0 13) |
| Q5 | `[run]` in a standalone file, an unknown key in `[run]` | A standalone file may have `[run]` (no warning). An unknown key is a warning (changed, L0 19) |

## 9. Compiler and tool limits met

| Limit | Handling |
| --- | --- |
| A local name equal to a name of the test module is a duplicate, and a duplicate definition in a test module is an error of `roc test` | The lambdas of the new `expect`s use `x`, not `d` (`d` is a helper of slice 057) |
| A local name equal to a method of its type module is a duplicate | `RunEach` has the locals `lines` and `links`, not `nodes` and `edges`, in `list_text`, and `list` in `header_paths` |
| `keep_oks(...).first()` crashed the app | `first_file` and `walk` are recursive matches |
| A `var` that holds a bare `Err(...)` | The typed constants `no_code`, `no_plans`, `no_dirs` |
| A module cannot import a module that imports it | `RunFlow` imports `RunEachFlow`, which imports `RunSteps` (not `RunFlow`) |
| `UPDATE=1` writes the expected files | Run only with the filter `run/rn4-each` and `run/rn2-each` (TW21): the old expected files did not change |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Order | One pass is possible: `RunEach` (L0 12 to 17), `RunCmd`, `Intent` (L0 18, 19), then `RunSteps` and `RunEachFlow` (L2, L3). Filter the runs: `tests/commands/run.sh run/rn4`, `tests/run.sh run/rn2-each` |
| `RunSteps` | Move `plan!`, `steps!`, `known_files`, `derived`, `exec!`, `find_entry`, `tool_run` and the types out of `RunFlow` (the reference has `RunFlow` 152 lines, `RunSteps` 119). `plan!` takes `{ name, args, dir, stop }` in place of the `Ready` of slice 057. `RunFlow.flow!` and `RunEachFlow.run!` both call them. The L2 and L3 cases of slice 057 must stay green |
| `Intent` | add `"run"` to `known_tables` and `member_tables`. In `check_tables`: the role `Root` with the table `run` is an issue (the text of section 5). Do not change the message for member tables. In `read_tables`: `unknown_keys(doc, "run", ["after"])` joins the warnings (review Q5) |
| `RunEach.edges` | A member file with no header or a bad header: `Project.check_header`, with the kind `Usage` (exit 2) and its message (review Q4). Then `Release.entries_of` for the entries |
| `RunEachFlow` | The order of the calls changed in the review: `read_files!` of `RunEach.paths` first, then `RunEach.standalone` (exit 2, nothing recorded), then `canonical!` and the `projects.json` write, then the headers (the doc of the stub and `calls.log` have it) |
| `Args` | no change (the flags are allowed) |
| Walk | `RunEachFlow` uses the `scan` of `Project.scan!` (`scan.root`, `scan.members`, `scan.walk`). It reads the nodes with `RunEach.paths` (one `read_files!`) |
| Plan | `ScriptsToml.read` of each node (the first bad form is exit 19), the nodes that have the script in the order of `RunEach.order`, `RunSteps.plan!` for each with `stop` = the root |
| Failures | A step failure (exit 18) of a node: `Common.failed!` prints it, the code is the code of the node. A code that is not 0 is a failed node |
| Tests | do not edit the tests (TW18). A wrong test goes back to the test agent |

## 11. Red run, revert check

Red run with the stubs (`research/slice-058-revert/red-run.log`): `scripts/test.sh` (all steps).

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt, selftest, l1 | pass | the stubs compile with no warning |
| l0 | 8 failed, 55 passed | the 8 new `expect`s of `RunscriptTest`: 12 to 17 `ROC CRASHED todo: slice 058`, 18 (`each` is `Bool.False`, no `--keep-going` check), 19 (`Intent` has no `run`) |
| l2 | 1 failed, 143 passed | `run/rn4-each`: the stub `RunCmd.read` has `each` false, so the command goes the way of slice 057 (a wrong value: other calls, other output) |
| l3 | 1 failed, 75 passed, 1 skipped | `run/rn2-each`: the same reason (the root scripts run, exit codes differ) |

The old cases pass. Their `expect/` files are the same.

Green run with the reference (`green-run.log`, after the review changes): all steps pass (l0 7.4 s of 10 s, l2 9.1 s, l3 9.9 s). The red run was repeated after the review (`red-run.log`).

Revert check (`mutations.txt`, 12 mutations of the most tricky behaviors, filtered runs, the reference is put back after each one): every mutation is killed by at least one layer.

| Mutation | L0 | L2 | L3 |
| --- | --- | --- | --- |
| ties: the largest ready node first | killed | killed | killed |
| path entries of the headers give no edge | killed | killed | killed |
| `after` gives no edge | killed | killed | killed |
| a cycle is allowed (the nodes in the loop are added at the end) | killed | killed | killed |
| `--keep-going` skips no node | killed | killed | killed |
| the code of the last failure, not the first | survived | killed | killed |
| skip only for a direct edge | killed | killed | survived |
| the list with `--json` never prints `data` | survived | killed | survived |
| a standalone `talon.toml` above the nodes is a node | killed | killed | survived |
| no stop at the first failure (no `--keep-going`) | survived | killed | killed |
| `--keep-going` with no `--each` is accepted | killed | killed | killed |
| a failed node is not recorded for the skips | survived | killed | killed |

Review mutations (`mutations-review.txt`, one hand mutation for each change of the review, each killed by L0; L2 and L3 do not see the header kind and the unknown key):

| Mutation | L0 | L2 | L3 |
| --- | --- | --- | --- |
| Q3: a standalone start is no stop (`standalone` always `Err(None)`) | killed | killed | survived |
| Q4: the header failure has the kind `Input` (exit 19) | killed | survived | survived |
| Q5: no warning for an unknown key of `[run]` | killed | survived | survived |

## Review (manager, 2026-10-25)

The slice is accepted with no split (about 490 reference lines in 2 new modules, and the move of `RunSteps`). The decisions of section 6 and the TW24 texts of section 5 are accepted. The answers:

| Q | Answer | Change in the reference and the tests |
| --- | --- | --- |
| Q1, Q2 | Accepted as the reference does | none |
| Q3 | Changed. NC2 and NC5: in a standalone project inside a workspace directory the walk stops at its own `talon.toml`, and the workspace has no effect (R-PD5). That file has no `[workspace]`, so `--each` there is exit 2 as with no workspace | new `RunEach.standalone`. The calls of `RunEachFlow` are reordered (the node files are read before the record, so a standalone start records nothing). L0 12 rows, L2 `rn4-each` run 15 (the old runs only got the changed order of `read_files` in `calls.log`: checked with `diff -r`) |
| Q4 | Changed. A member file of a node with no header, or a bad header, is exit 2 as R-PD8 says for a project file | `RunEach.edges` uses `Project.check_header` with the kind `Usage`. L0 13 rows |
| Q5 | Changed for the unknown key: an unknown key in `[run]` gives the R-TF4 warning. `[run]` in a standalone file is accepted (no warning) | `Intent` (the code agent writes it). L0 19 rows |

## Verify results (code agent, 2026-10-25)

Files: `RunEach` 346 lines, `RunEachFlow` 190, `RunSteps` 126 (new, moved out of `RunFlow`), `RunFlow` 157 (from 254), `RunCmd` 49, `Intent` 397 (+2), `main` (`RunSteps` exposed). A copy is in `research/slice-058-revert/code-final/` (`code-final.sha256`: `sha256sum -c` from the repo root checks the live files).

| Step | Result |
| --- | --- |
| `scripts/test.sh` (all steps) | exit 0 in 67 s: check, fmt, l0 (567 `expect`s in 12 files, `RunscriptTest` 1 to 19), l1, l2 (144 cases, `rn4-each` 15 runs), l3 (76 cases, 1 skipped, `rn2-each` 7 steps), selftest all pass. No `crash "todo` in `cli/`. |
| Revert check | 11 mutations, 10 caught, 1 not caught (`research/slice-058-revert/agent-results.md`): ties, path entry to a directory, `after` edge, cycle start, skip of a direct edge only, code of the last failure, a node that cannot start, args of `--`, the standalone stop, NC4 nearest file, `[run]` in the root file. Not caught: a path entry to a non member file in the directory of a node (Q1, second rule): L0 13 has the same edge by a member file, L2 and L3 have no such entry |

Decisions of the code agent that the slice does not fix:

| Id | Decision | Rejected |
| --- | --- | --- |
| C1 | `RunSteps.Ready` is `{ env, roots, now, table, tools_file }`. `RunFlow` keeps its own `Ready` (with `scan` and `found`) for the list and gives the narrow record to `steps!` | One `Ready` with fields that the steps do not use |
| C2 | The files that `plan!` knows in `--each`: the `talon.toml` of each node (from the text that was read) and the walk files that are no node. `Need` reads happen only for an `in` directory that is outside both | The walk files only (it adds one `read_files!` for each node: the calls.log of L2 differs) |
| C3 | A path or a header that `read_files!` cannot read, with an error other than `NotFound`, is a failure of kind `Environment` (exit 18): `cannot read <path>` | Treat it as a missing file |
| C4 | A header failure of `RunEach.edges` has the kind `Usage` for both causes (no header, bad header), as L0 13 says. `Project.check_header` gives `Input` for a bad header: its message is kept, its kind is replaced | The kind of `Project.check_header` |
| C5 | `edges` checks the headers (kind 1, exit 2) before it reads `after` (kind 2, exit 19) | `after` first |
| C6 | The loop of a cycle is the shortest loop through the smallest node of the group (breadth first, the first edge in the order of `edges` on a tie). A group is the set of nodes that reach each other | A depth first loop (it can be long and has no rule) |
| C7 | A step failure (`Err` of `RunSteps.steps!`: exit 18, tool and consent failures) prints with `Common.failed!` and fails the node with that code | A stop of the command also with `--keep-going` |
| C8 | `from_root!` is one direct-style function for the steps 2 to 5b with `return` for the standalone stop. The tool table is the one of the root file, as the slice says | A chain of one function for each step |

Disputes (from the code agent): none. No test, fixture or expected file was changed.

## Gap tests (test agent, 2026-10-25)

Rows for accepted behavior of the code (no change of code). Each row got one hand mutation (`research/slice-058-revert/gap-mut.py`, logs `gap-<id>.log`), then the file was put back and `sha256sum -c research/slice-058-revert/code-final.sha256` gave OK for all files. `RunscriptTest` before the rows: `research/slice-058-revert/gap-before/`.

| Id | Behavior | Row | Mutation, result |
| --- | --- | --- | --- |
| m2 (agent) | R-EA2 second rule: a path entry to a file that is no member, in the directory of node B, is an edge. Only the directory itself (Q1): a file in a subdirectory of B gives none | L0 13: `edges_view` rows `../b/Util.roc` (edge `a -path-> b`) and `../b/sub/x.roc` (no edge), each as the only entry | `node_of` has no directory rule: killed by L0 13 |
| C6 | The loop of a cycle is the shortest loop through the smallest node, not the first one found by a depth first walk | L0 15: `a -> b -> c -> a` and `a -> d -> a` (edges in this order): the text is `a -after-> d -path-> a` | the breadth first frontier keeps one item: killed by L0 15 |
| C5 | A header failure (exit 2) comes before an `after` failure (exit 19) | L0 13: a node with `after = ["../nope"]` and a member file with no header gives exit 2 | `after_edges` is read before `path_edges`: killed by L0 13 |
| plan before the first step | All nodes are planned before the first node runs (L2 run 13) | L2 `rn4-each` run 13 (exists): `a` is fine, `b` has a shell word: exit 19 and `a` does not run | each node is planned just before its steps: killed by L2 (run 13 shows `running a`, `exec_in tool-a ok` and then exit 19; other runs show the extra reads of each node file) |

Note on the request: the gap list names the m2 row as "no edge" for a non-member file in the directory of node B. The accepted Q1 answer says the directory itself gives an edge (R-EA2: "a file in the directory of B") and only a subdirectory gives none. The rows follow the accepted answer, and the code (the old L0 row `util` already had the edge with a member file next to it).

Totals now: L0 `RunscriptTest` still has 19 `expect`s (new rows in 13 and 15), `rn4-each` 15 runs. No code, fixture or expected file changed.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-058-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.6, fmt 0.2, l0 7.7, l2 8.7, l3 10.0, selftest 3.0, l1 37.0 s |
| Code pass | 10 of 11 mutations caught; the miss (m2) is now caught by a gap row |
| Gap tests | m2, C6, C5 (L0 rows), plan before the first step (run 13); 4 hand mutations caught; no code bug |
| m2 note | The manager's gap note was wrong: by the accepted Q1 and R-EA2, a non-member file in the directory of B gives an edge; only a file in a subdirectory of B gives none. The rows follow the accepted answer. |
