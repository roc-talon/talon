# 002 Project, files and locks

Phase: P0. Status: verify

Slice 002 makes the decisions about where Talon works and what it writes: the project file search, the roots of the directory layout, the formats of the Talon files, `projects.json`, the temp names, the check before a write of project files, and the lock between processes. It adds 5 calls and 1 helper to the `Fx` record (`list_dirs!`, `delete!`, `canonical!`, `lock!`, `unlock!`, `with_lock!`). It builds no P0 command. The decisions are stubs (`crash "todo"`) and their tests are red.

## Rules

| Group | Ids | Design | Where tested |
| --- | --- | --- | --- |
| Project search | R-PD1 to R-PD6, R-PD8 | CLI 1 "The project" | `project.roc`, `members.roc`, L2 `project/pd-search` |
| Known projects | R-PD9 to R-PD13 (R-PD10: the pure decision only) | CLI 1 | `projects.roc`, L2 `locks/cc-locked-update`, L3 `files/cc1-atomic-write` |
| Layout and roots | R-LY1 to R-LY7 (Linux, macOS), R-EV13, R-CR1 | CLI 6.1, CLI 1, Design 2.2 | `roots.roc`, L3 `files/cc1-atomic-write` |
| Priority of settings | R-LY4 (with R-EV1 of slice 001) | CLI 6.1 | `roots.roc` |
| Talon files | R-TF1 to R-TF3, R-TF4 (syntax of `talon.toml` and `workspace.members`), R-TF5, R-TF6 | CLI 6.1 | `talonfile.roc`, `project.roc`, `projects.roc`, L2 `project/pd-search`, L3 `files/tf-bad-projects-json` |
| Temps | R-CC1, R-CC2, R-CC11 (files) | CLI 7.4 | `temp.roc`, L3 `files/cc1-atomic-write` |
| Locks | R-CC3, R-CC5, R-CC6, R-CC12, R-HF3 | CLI 7.4, Design 6.2 | `lock.roc`, L2 `locks/cc-locked-update`, L3 `locks/*`, L3 `files/*` |
| Check before a write | R-CC7 (the decision) | CLI 7.4 | `guard.roc` |

## Files

| Path | Writer | State |
| --- | --- | --- |
| `cli/lib/Lock.roc`, `Temp.roc`, `Roots.roc`, `Item.roc`, `Members.roc`, `Project.roc`, `TalonFile.roc`, `Projects.roc`, `Guard.roc`, `Setting.roc` | Stubs from the test agent. Bodies from the code agent. | Compile. The doc comments hold the contract. `Item` has no function. |
| `cli/lib/Known.roc` | Stub. Command code. | `Known.record!` |
| `cli/lib/Fx.roc` | Test agent (types, wrappers). The body of `with_lock!` is a stub. | 5 new fields, 5 wrappers, `with_lock!` |
| `cli/lib/JsonDoc.roc` | Slice 001 owns it. This slice added the stub `JsonDoc.parse`. | `render` unchanged |
| `cli/lib/main.roc` | Slice 001 owns it. This slice added 11 names to the exposes list. | The code agent adds the package entry `toml` (`roc-toml` 0.1.0, URL in `docs/slices/PLAN.md`), because `Project.workspace_of` needs it. It is not added here: no stub imports it. |
| `cli/RealFx.roc` | Test agent. `list_dirs!`, `delete!`, `canonical!` are done (no Talon logic). `lock!` and `unlock!` are stubs. `write_atomic!` is the plain form of slice 001: the code agent changes it (below). | `make` is now `make!` |
| `cli/main.roc`, `cli/fxprobe.roc` | Test agent | The call `RealFx.make!`. `fxprobe` has 5 new calls (`list`, `delete`, `canonical`, `lock`, `lockseq`). |
| `cli/flowprobe.roc` | Test agent | New test tool, not part of `tln`: `flowprobe record <file>...` runs `Known.record!` with the real `Fx`. It stands in for the P0 commands that slice 007 builds. |
| `tests/unit/{roots,members,project,lock,temp,talonfile,projects,guard}.roc` | Test agent | 23 `expect`s, red ("todo") |
| `tests/commands/FakeFx.roc`, `tests/commands/main.roc` | Test agent | The fake has the 5 new calls and the lock log. The entries `project` and `locks` are new. The `harness` entry calls each new call once. |
| `tests/commands/cases/project/pd-search/`, `tests/commands/cases/locks/cc-locked-update/` | Test agent | 2 L2 cases, red |
| `tests/scenarios/locks/cc12-lock-contract/`, `locks/cc12-heartbeat/`, `files/cc1-atomic-write/`, `files/tf-bad-projects-json/` | Test agent | 4 L3 cases, red |
| `tests/run.sh`, `tests/lib.sh`, `scripts/test.sh`, `tests/selftest.sh`, `tests/selftest/commands/pass/harness/fake-fx/` | Test agent | The runner builds `flowprobe`. `tree.diff` now writes `$HOME`, `$PROJECT` and `$WORK` for the work dir paths in file content. `scripts/test.sh` checks `flowprobe.roc`. The self-test follows the new `harness` entry (still 23 checks, green). |

## Public signatures

### Fx (`cli/lib/Fx.roc`)

| Call | Type | Real `Fx` | Fake `Fx` |
| --- | --- | --- | --- |
| `list_dirs!` | `List(Str) => List(Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)]))` | `Path.list!`, `Path.is_dir!`, `Path.time_modified!` (seconds). Done. | Real files in the case dir |
| `delete!` | `List(Str) => List(Try({}, [NotFound, Denied, Other(Str)]))`. A file, or a dir with its content. A missing path is `Ok`. | `Path.type!`, `Path.delete!`, `Path.delete_all!`. Done. | The same, on real files |
| `canonical!` | `List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)]))` | `Path.canonicalize!`. Done. | The path as it is when it exists |
| `lock!` | `Str, [Wait, NoWait] => [Held(Lock), Busy]` | R-CC12. Stub. | `fx/locks` table, log line |
| `unlock!` | `Lock => {}` | R-CC12. Stub. | log line |
| `with_lock!` | `Fx, Str, [Wait, NoWait], (() => Try(ok, err)) => Try(ok, [Busy, Failed(err)])` (a method, not a field) | Stub in `Fx.roc` | The same code |
| `write_atomic!` | Unchanged type. R-CC1: the temp is `Temp.name({ target, hex: Temp.hex(<Random.seed_u64!>) })` in the dir of the target. It makes the missing parent dirs first. | The code agent changes the plain form | Writes in place, makes the parent dirs |

`Lock := { item : Str, token : Str }` (`cli/lib/Lock.roc`). `RealFx.make!` is effectful: it can draw the token of the process.

### Pure decisions (`cli/lib/`)

| Module | Functions | Rules |
| --- | --- | --- |
| `Lock` | `dir`, `state`, `owner_text`, `owns`, `stale_name`, `waiting_line` | R-CC3, R-CC5, R-CC12, R-LY3 |
| `Temp` | `hex`, `name`, `of_item`, `old` | R-CC1, R-CC2 |
| `Roots` | `from_env : List((Str, Str)) -> Try(Roots, Fail)`, `item : Roots, Item -> Str` | R-LY1 to R-LY3, R-LY5 to R-LY7, R-EV13, R-CR1 |
| `Item` | 19 tags (the table in its doc comment) | R-LY1, R-LY2 |
| `Setting` | `pick` | R-LY4, R-EV1 |
| `Members` | `matches`, `step` (the step of the expansion of `members`: `Need(dirs)` or `Done(files)`) | R-PD3, R-PD4 |
| `Project` | `parent`, `absolute`, `stops`, `workspace_of`, `root_of`, `find`, `check_header`, and the effect `find!` | R-PD1 to R-PD6, R-PD8, R-TF4, R-TF5 |
| `TalonFile` | `open`, `render` | R-TF1 to R-TF3, R-TF6 |
| `Projects` | `record`, `entries`, `prune` | R-PD9 to R-PD13, R-TF1 to R-TF3, R-TF6 |
| `Guard` | `check_all` | R-CC7 |
| `JsonDoc` | `parse` (new) | R-TF1, R-TF2 |
| `Known` | `record!` (command code) | R-PD9, R-CC2, R-CC3, R-CC6 |

## Rules for the code agent

### Project search (R-PD1 to R-PD6, R-PD8)

| # | Rule | Source |
| --- | --- | --- |
| P1 | The walk goes up from the start directory. After a directory is checked, it ends when `Project.stops` (an entry named `.git`, a dir or a file, or the dir is `home`) or `Project.parent` is `AtRoot`. A directory above the stop is never listed and never read. | R-PD2 |
| P2 | The workspace root is the nearest directory of the walk whose `talon.toml` has a `[workspace]` table. The `talon.toml` files are read nearest first, and a file above the root is never parsed. A file that does not parse (before the root) is a failure of kind `Input`: `<dir>/talon.toml:<line>: not valid TOML`. | R-PD3, R-TF4 |
| P3 | With no `--file`: for each directory of the walk, from the start up to the root. The member files of the directory are the members whose directory is this one. 2 or more: failure `Usage`, `<dir> has <n> member files: <a>, <b>. Pass --file <path>.` Exactly 1: it is the project file (a member). Else, in a directory that is not the root, a `main.roc` entry is the project file (standalone). At the root only member files count. | R-PD4 |
| P4 | A member is part of the workspace: `workspace` is `Ok({ root, members })`. A project file that is not a member is standalone (`Err(Standalone)`), also inside a workspace dir. With no project file and a root: `file` is `Err(NoCurrent)`, `workspace` is the workspace. With neither: failure `Usage`, `no project file found. Checked: <dir>, <dir>. Pass --file <path>.` (all directories of the walk, nearest first). | R-PD5 |
| P5 | The `talon.toml` of a member (and of the workspace with no member) is the nearest on the path from the member dir up to the root, the root included. The `talon.toml` of a standalone project is the one in its own directory when that file has no `[workspace]` table. A `talon.toml` in a parent dir has no effect. | R-PD6 |
| P6 | `--file`: the path is relative to the start directory (`Project.absolute`). The project file is that file. The start directory of the walk is its directory. It is a member when the root has it in `members`. | R-PD1, R-PD5 |
| P7 | The project file needs an app, package or platform header (`Project.check_header`): no header is `Usage` (exit 2), a header that does not parse is `Input` (exit 19) with the 1-based line. | R-PD8, R-TF5 |

Call order of `Project.find!` (the L2 case `project/pd-search` fixes it):

| Step | Call |
| --- | --- |
| 1 | With `file`: `canonical!` of `Project.absolute({ base: start, path: file })`. The result is the project file. Its directory is the start directory. |
| 2 | `list_dirs!` of one directory for each call: the start directory, then each parent, until the walk ends (P1) |
| 3 | One `read_files!` of the `talon.toml` of the walk dirs that have one (their entry names have `talon.toml`), nearest first. No call when there is none. |
| 4 | With a root: `Members.step` with `listed` seeded from the listings of step 2 (a root that the walk listed is not listed again). Each `Need(dirs)` is one `list_dirs!` call. A directory that is missing has the entries `[]`. |
| 5 | With a project file: `read_files!` of it, then `Project.check_header`. With no project file: no call. |

### Members (R-PD3, R-PD4)

The glob syntax is question Q3. The default: a pattern is `/`-separated, a segment is literal or has `*` (any run of characters in one name, also none), the last segment names files, the others name directories. `Members.step` returns the missing level of each pattern, joined and sorted, and `Done` with sorted, unique absolute paths.

### Roots and items (R-LY, R-EV13, R-CR1)

| # | Rule |
| --- | --- |
| L1 | `cache = <XDG_CACHE_HOME or $HOME/.cache>/roc`. `pkgs = cache/packages`: it ignores `ROC_CACHE_DIR`. `build = ROC_CACHE_DIR or cache` (the parent of `compat-<id>/`). `config = <XDG_CONFIG_HOME or $HOME/.config>/talon`. `data = <XDG_DATA_HOME or $HOME/.local/share>/talon`. |
| L2 | `Roots.item` gives the path of an item (the table in `Item.roc`). The lock of an item is `Lock.dir(path)`: `<path>.lock`. |
| L3 | `Setting.pick`: the first set value of `flag`, `env`, `project`, `user`. |

### Talon files (R-TF1 to R-TF3, R-TF6)

`TalonFile.open` is the table in its doc comment. `projects.json` is not a file that Talon can make again, so `can_recreate` is false for it. The form of the file is a proposal (below). A JSON that is not an object with an array `projects` of objects with a text `path` and an integer `last_use` is content that does not parse. An unknown field stays in place, also in an entry.

### Temps and locks (R-CC1, R-CC2, R-CC3, R-CC5, R-CC6, R-CC12)

| # | Rule | Source |
| --- | --- | --- |
| T1 | `RealFx.write_atomic!`: for each file, make the parent dirs (`Path.create_all!`), write `Temp.name({ target, hex: Temp.hex(Random.seed_u64!()) })`, then `Path.rename!` over the target. It stops at the first error. The target is never written in place. | R-CC1 |
| T2 | `Known.record!` is the flow of the table in its doc comment. After the lock, the holder deletes each temp of the item (`Temp.of_item`), with no age rule (question Q7). | R-CC2, R-CC6 |
| T3 | `Temp.old` is the choice of `tln cache gc` (P1). It is pure, so this slice tests it. | R-CC2 |
| K1 | `Fx.with_lock!`: `NoWait` gives `Err(Busy)` on a busy item. `Wait` tries `NoWait` first, prints `Lock.waiting_line` once to stderr on `Busy`, then calls `lock!(item, Wait)`. `unlock!` runs also when the body gives an `Err`. | R-CC3, R-CC5 |
| K2 | `RealFx.lock!`: make the missing parent dirs of the item. `Path.create_dir!` of `Lock.dir(item)`. On success write `owner` (`Lock.owner_text`: token and start time) and `beat`. On failure read the modification time of `beat` (or `NoBeat`) and of the directory, and ask `Lock.state` with the real clock (`Fx.clock!`, never `TALON_NOW`). `Stale`: rename the directory to `Lock.stale_name`, delete it, try again. `Live`: `NoWait` gives `Busy`. `Wait` polls every 200 ms. | R-CC12 |
| K3 | While the process holds a lock and waits (the poll of `lock!` with `Wait`), it writes `beat` again every 2 s, for each lock that it holds. The tests need it for a lock that was taken by an earlier `lock!` call of the same process (L3 `cc12-heartbeat`). A lambda keeps no state, so the real `Fx` needs a place for the held locks: question Q8. | R-CC12 |
| K4 | `RealFx.unlock!`: delete the lock directory only when `owner` holds the token of the lock (`Lock.owns`). | R-CC12 |
| K5 | `Fx.lock!` has only the answers `Held` and `Busy` (R-CC3). A directory that cannot be made for another reason is question Q9. | R-CC3 |

### Check before a write (R-CC7)

`Guard.check_all` is the pure part. The command code (slice 007) reads each file again, cuts the spans, calls it, applies the span edit for `Reapply`, and then writes the files in the order that it gives (R-CC1). The span cut is `roc-app-header` (the header) and `roc-toml` (each table that Talon changes).

## Tests

L0 (23 `expect`s, `roc test`). Each `expect` checks a table of cases and prints the wrong rows with `dbg`.

| File | `expect`s | Checks |
| --- | --- | --- |
| `tests/unit/roots.roc` | 3 | Roots from the environment: HOME only, the 3 XDG variables, `ROC_CACHE_DIR` with and without XDG (R-LY5 to R-LY7, R-EV13, R-CR1). The path of each of the 19 items, and 7 lock dirs (R-LY1 to R-LY3, R-CR1, R-CC3). The priority of a setting (R-LY4, R-EV1). |
| `tests/unit/members.roc` | 2 | `matches` (14 rows). The step: `Need` for 0, 1 and 2 listed levels, `Done` sorted, a missing dir, a dir with a member name, 2 patterns for one file (R-PD3, R-PD4). |
| `tests/unit/project.roc` | 6 | `parent`, `absolute`, `stops` (R-PD1, R-PD2). `workspace_of`: no table, a table, bad TOML, a bad `members` (R-PD3, R-TF4). `root_of`: the nearest root, a bad file above the root is not read, a bad file below fails (R-PD2, R-PD3, R-TF4). `find` with no file, 12 rows (R-PD1, R-PD4 to R-PD6). `find` with `--file`, 6 rows (R-PD1, R-PD5, R-PD6). `check_header`: app, package, platform, 3 forms of no header, a bad header (R-PD8, R-TF5). |
| `tests/unit/lock.roc` | 2 | `state`: 11 rows, the age 30 s, the future, no `beat` (R-CC12). `owns`, `owner_text`, `dir`, `stale_name`, `waiting_line` (R-CC3, R-CC5, R-CC12, R-LY3). |
| `tests/unit/temp.roc` | 3 | `hex`, `name` (R-CC1). `of_item`: file and dir temps of the item, 6 names that are not (R-CC2, R-CC4). `old`: 1 day, a probe copy, a trash dir, a lock dir, a package, the future (R-CC2, R-GC6, R-EV22). |
| `tests/unit/talonfile.roc` | 3 | `JsonDoc.parse` (7 good texts, 11 bad ones, a round trip) (R-TF1, R-TF2). `TalonFile.open`: 13 rows (R-TF1 to R-TF3, R-TF6). `render` (R-TF1, R-TF2). |
| `tests/unit/projects.roc` | 3 | `record`: 11 rows (R-PD9 to R-PD12, R-TF1, R-TF2). The 7 failures (R-TF3, R-TF6, R-PD12). `prune` and `entries` (R-PD12, R-PD13). |
| `tests/unit/guard.roc` | 1 | `check_all`: same, reapply, conflict, a span that is gone, the order, many conflicts (R-CC7). |

Deep tests (2 L2 cases, 4 L3 cases):

| Layer | Case | Checks | State |
| --- | --- | --- | --- |
| L2 | `tests/commands/cases/project/pd-search` | 14 searches over one tree (`Project.find!` with the fake `Fx`): a standalone project below a repo that has `main.roc` and a `talon.toml` with `[workspace]` above it (never read, R-PD2); a member from its dir, from a dir below it, and with 2 member files in one dir (exit 2, the list); a workspace with no current member; a standalone project inside the workspace; `--file` for a member, a non-member and the root `main.roc`; no project file (the list of dirs); a file with no header (exit 2); a header that does not parse (exit 19, the line); a `talon.toml` that is not TOML (exit 19, the line); the home dir as the stop. The `calls.log` fixes the call order: one `list_dirs!` for each dir of the walk, the one `read_files!` of the tomls, the `Members.step` rounds with the listings of the walk reused. R-PD1 to R-PD6, R-PD8, R-TF4, R-TF5, R-EC2, R-EC19, R-E4 | red |
| L2 | `tests/commands/cases/locks/cc-locked-update` | `with_lock!` in 4 runs (a body that works, a body that fails: `unlock!` still runs, `NoWait` on a busy item: no body and no unlock, `Wait` on a busy item: `NoWait` first, the waiting line once, then `Wait`). Then `Known.record!` in 3 runs on a busy `projects.json` item: NoWait, the line, Wait, the holder deletes the stale temp, read, `write_atomic!`, unlock; no files: no call; a temp copy only: the lock and the read, no write. No `ask!` in a lock (the fake logs a VIOLATION line). R-CC1 to R-CC3, R-CC5, R-CC6, R-PD9, R-PD11, R-PD12, R-TF1, R-HF3 | red |
| L3 | `tests/scenarios/locks/cc12-lock-contract` | The lock contract of the real `Fx` as one suite: a free item (held, the dir is gone after unlock), a live lock (busy, the dir stays), a stale `beat` taken with `NoWait` and with `Wait` (`touch -d`), no `beat` with an old and a new dir, the first run (parent dirs made), 2 locks in a process (the second is busy, the first is released), no `.stale` dir left. R-CC3, R-CC12, R-HF3, R-LY3 | red |
| L3 | `tests/scenarios/locks/cc12-heartbeat` | A process holds A and waits for B (made by the shell with a live `beat`). The `beat` of A is set old by the shell. After 5 s it is new again (the heartbeat, 2 s). Then the shell changes `owner` of A, and releases B: the process takes B, and `unlock!` keeps A because its `owner` is not the token of the process. R-CC12, R-CC3, R-HF3. About 6 s. | red |
| L3 | `tests/scenarios/files/cc1-atomic-write` | A write never goes in place: a hard link keeps the old content (R-CC1). The first run of `flowprobe record` with no cache dir: `projects.json` under `$XDG_CACHE_HOME/roc/talon` and not under `ROC_CACHE_DIR` (R-LY5, R-EV13, R-CR1), the lock is released, the entries are sorted with the times of `TALON_NOW` (R-PD9, R-PD12, R-EV22). An unknown field stays (R-TF2). A second run with `TALON_NOW` changed: the old and the new temp of `projects.json` are deleted, the temp of `tools.json` stays (R-CC2). A temp copy and a package file are never recorded (R-PD11). R-CC1, R-CC2, R-CC6, R-CC11 (a file is replaced by a rename), R-PD9, R-PD11, R-PD12, R-LY5, R-EV13, R-CR1, R-TF1, R-TF2, R-EV22 | red |
| L3 | `tests/scenarios/files/tf-bad-projects-json` | `projects.json` with content that does not parse, a newer format, and an entry with no text path: each exit 19 with the error line that names the file, the file is not changed, the lock is released after each failure. R-TF3, R-TF6, R-EC19, R-E4, R-CC3, R-CC6 | red |

Red output (`scripts/test.sh`, 2026-10-18): see "Red output" below.

## Output (proposed, R-OUT2: text, file forms)

The strings are fixed in the expected files. The human accepts or changes them at the review.

| Case | Text | Where |
| --- | --- | --- |
| Two member files in a dir | `tln: error[usage]: <dir> has <n> member files: <a>, <b>. Pass --file <path>.` | `project.roc`, `pd-search` |
| No project file | `tln: error[usage]: no project file found. Checked: <dir>, <dir>. Pass --file <path>.` (the dirs of the walk, nearest first) | `project.roc`, `pd-search` |
| No header | `tln: error[usage]: <path> has no app, package or platform header` | `project.roc`, `pd-search` |
| Header that does not parse | `tln: error[input]: <path>:<line>: the header is not valid` | `project.roc`, `pd-search` |
| `talon.toml` that does not parse | `tln: error[input]: <dir>/talon.toml:<line>: not valid TOML`. A bad `members`: `...:<line>: the key workspace.members must be a list of strings`. The text of `roc-toml` is not shown, so that no expected file depends on it. | `project.roc`, `pd-search` |
| Talon file with bad content | `tln: error[input]: <path>: the content does not parse` | `talonfile.roc`, `tf-bad-projects-json` |
| Talon file with a newer format | `tln: error[input]: <path>: format <n> is newer than this tln (format <m>). Run: tln tool update talon` | `talonfile.roc`, `tf-bad-projects-json` |
| A file that can be made again, bad content | The warning `<path>: the content does not parse. Talon deletes it and makes it again.` | `talonfile.roc` |
| Wait for a lock | `waiting for another tln: <name>` (the last segment of the item path, question Q1) | `lock.roc`, `cc-locked-update` |
| A write conflict | `tln: error[conflict]: <path>[, <path>...] changed while tln ran. Nothing was written. Run the command again.` | `guard.roc` |
| `projects.json` | One line: `{"format":1,"projects":[{"path":"<canonical path>","last_use":<seconds>}]}` and a newline. Sorted by path. | `projects.roc`, `cc1-atomic-write` |
| Lock `owner` file | The token, a newline, the start time in seconds, a newline | `lock.roc` |
| Temp names | `<target>.<16hex>.tmp`, `<item>.lock.<16hex>.stale` (the design names the first) | `temp.roc`, `lock.roc` |
| `fxprobe`, `flowprobe` | Test tools: the lines in their doc comments (`held <item>`, `recorded <n>`) | the L3 cases |

## Out of scope

| Id | Reason |
| --- | --- |
| R-PD7, R-PD17 | The `roc` proxy is P1 |
| R-PD10 (the write on a new entry only) | The pure decision is tested (`Projects.record` with `After(86400)`). The proxy is P1. |
| R-PD14, R-PD16 | The `--file` flag of each command: slice 001 (`args.roc`, `fl12-bad-flags`) |
| R-PD15 | `tln init` is P1 |
| R-TF3 (migration of an older format) | No file has an older format in P0. `TalonFile.open` reads an older `format` as it is. The migration is per file, in the slice that makes the format change. |
| R-TF4 (ranges, unknown `strategy`, the warning for an unknown key) | The keys of `talon.toml` are slice 005 (R-I, R-VA, R-C). This slice tests the syntax of the file and `workspace.members`. |
| R-LY5 to R-LY7 (Windows column), R-LY8, R-LY9 | Windows CI is P1. The bin dir and the `PATH` line are `tln setup` (P1). |
| R-CC2 (the `talon/tmp/<16hex>/` of a command that ends, probe copies) | P1 (probes). `Temp.old` tests the GC choice of these dirs. |
| R-CC4, R-CC8 to R-CC10 | P1 (toolchain install, `compat.db`, `last-use`, GC lock) |
| R-CC7 (the command flow: read again, cut spans, span edit, write) | Slice 005 (the header edit) and slice 007 (the commands). This slice tests the decision (`Guard.check_all`). |
| R-CC11 (directories: `packages/<hash>/`, `talon/x/`) | A directory write and "the loser drops its copy" come with the fetch (slice 003) and `tln x` (P1). This slice tests a file that is replaced by a rename. |
| R-CC12 (an OS file lock instead of the lock dir) | The design says the mechanism can change later. The contract tests stay. |
| Ctrl-C while a process waits (R-CC5) | No test can send the signal in the fast set |

## Questions (stop until answered)

Each question has the default that the tests use. The code agent does not decide these.

| # | Question | Default in the tests | Depends |
| --- | --- | --- | --- |
| Q1 | R-CC5 prints `waiting for another tln: <item>`. The item of `lock!` is a path. The design example shows `nightly-2026-10-13-91fa0c2`, not a path. Which text for the item? | The last segment of the path | `lock.roc` (2), `cc-locked-update` stderr |
| Q2 | `HOME` is not set, or a XDG variable is empty or not an absolute path. Error kind and message, or the default path? | Not tested. `Roots.from_env` gives `Err` of kind `Environment` when a root needs `HOME` and it is missing. | `roots.roc` |
| Q3 | The glob syntax of `members` (Design 4.4 has only the example). | `*` matches any run of characters in one name. No `**`, no `?`. The last segment names files. | `members.roc` |
| Q4 | A `[workspace]` table with no `members` key. | `members` is `[]`. Not tested. | `Project.workspace_of` |
| Q5 | `--file` that names a path that does not exist, or that is not a file. | A failure of kind `Usage` (exit 2), `<path>: no such file`. Not tested. | `Project.find!` |
| Q6 | A crash between the `rename` to `<item>.lock.<16hex>.stale` and the delete leaves that dir. R-CC2 does not list it. | Not tested. Proposal: add it to R-CC2 and `Temp.old`. | `Temp.old` |
| Q7 | R-CC2 says the lock holder of an item deletes the temps of that item and cites R-CC4 (toolchains). Does it hold for each locked item (R-CC6: `projects.json`, `tools.json`, `share.json`, `config.toml`), with no age rule? | Yes. `Known.record!` deletes each temp of `projects.json` after it takes the lock, also a new one. | `cc-locked-update`, `cc1-atomic-write` |
| Q8 | The real `Fx` keeps no state between calls (TESTING.md 2.1). R-CC12 says it writes `beat` again for each lock that it holds, inside its own waits. How does it know the held locks? | The test `cc12-heartbeat` needs it for a lock of an earlier `lock!` call. Proposal: a token of the process (`RealFx.make!`) and a registry file of the held lock dirs in the system temp dir. If the code agent finds no way, it writes a dispute. | `cc12-heartbeat` |
| Q9 | `Path.create_dir!` fails with a reason other than "exists" (no right, no disk). `lock!` has only `Held` and `Busy`. | Not tested. Proposal: `Busy` with `NoWait`, and the failure is a crash of the real `Fx` with a message. | `RealFx.lock!` |
| Q10 | Does `projects.json` hold the path as given or the canonical path? R-PD9 says canonical. Who makes it canonical: `Project.find!` (done: `canonical!` for `--file`) or `Known.record!`? | `Known.record!` records the paths as given. The command passes canonical paths. | `Known` doc comment |
| Q11 | `Known.record!` failures: a read or write error of `projects.json`. | Kind `Environment` (exit 18). Not tested. | `Known` doc comment |

## Decisions that the design does not fix (the test agent chose, for review)

| Decision | Options rejected |
| --- | --- |
| The listing of the walk is one `list_dirs!` call for each directory, and the walk stops at the first stop dir. The `Members.step` rounds reuse these listings. | One call for all parents up to `/` (it lists dirs above the stop: reads outside the repository). |
| `Members.step` is a step function (`Need` or `Done`), as the solver step. The glob is pure and the listings come from `Fx`. | A `glob!` effect (Talon logic in the real `Fx`, TW4). |
| `Fx.list_dirs!` gives the `mtime` of each entry, and the order is not fixed. The pure code sorts (TW2). | A separate `mtime!` call. A sorted list from the real `Fx`. |
| `Fx.delete!` takes files and dirs, and a missing path is not an error. `Fx.canonical!` is an effect (R-PD9 says canonical). | A `delete_file!` and a `delete_dir!`. Canonical paths in pure code (no symbolic links). |
| `with_lock!` is a method of `Fx` and wraps the body error as `Failed(err)`. With `Wait` it tries `NoWait` first and prints the line. | A free function in another module. An open error union (a compiler warning for `..` in an output). Printing in `lock!` (a real `Fx` with Talon logic). |
| `lock!` and `write_atomic!` make the missing parent dirs. The first run has no `talon/` dir. | A command that makes the dirs (every caller must remember). |
| `Roots.item` has one tag for each item of R-LY1 and R-LY2, and the lock item is the path of the item. | Items as lists of segments (the layout would be in the callers). |
| `Item` is its own module, and `Roots` fields are `cache`, `pkgs`, `build`, `config`, `data` (`packages` is a reserved word). | One `Roots` module with an inline union of 19 tags. |
| `Lock.owner_text`, `Lock.stale_name`, the form of `projects.json` and `TalonFile.render` are proposals (above). | Binary or other forms. |
| A JSON with no integer `format`, or that is not an object, is "content that does not parse" (R-TF6). | A third kind of error. |
| `projects.json` is not a file that Talon can make again: bad content or a newer format stops the command (R-TF3, R-TF6). The design lists only `path-roc.json` and the manifests of `talon/x/` as files that Talon can make again. | Make `projects.json` again (GC would lose the protection of the known projects). |
| The `Guard` module takes the spans as text, cut by the command code. | `Guard` reads the files (an effect in a pure decision). |
| `Setting.pick` is generic over the value type and has 4 layers. | One function for each setting. |
| `RealFx.make` is now `make!` (it can draw a process token). | A `make` that gets the token as an argument. |
| The harness: `tree.diff` writes the work dir paths in file content as `$HOME`, `$PROJECT`, `$WORK`. The L2 entry `project` makes `.git` dirs from `fx/gitdirs`, because git cannot hold a `.git` name in a case tree. | A `.git` file in the case tree (git refuses the name). |
| 23 `expect`s (the budget is about 20). `temp.roc` has 3 (the name, the item, the GC choice) and `roots.roc` has the setting priority. | Fewer `expect`s with less reach. |

## Compiler and syntax limits found

| Limit | Evidence |
| --- | --- |
| `packages`, `platform` and `app` are reserved: not allowed as a record field or a local name | `Roots` (`pkgs`), `project.roc` (`pf_header`) |
| `{ name }` alone is a block, not a record with a shorthand field. Write `{ name: name }`. A record with more fields can use the shorthand. | `Project.root_of({ walk: walk })` |
| No spread in a list literal. Use `concat`. | `members.roc` |
| `Str` has no `sort`: no default order. Sort with `sort_with` and a byte compare. | `Text` helper of the private reference (not kept) |

## Red output

`scripts/test.sh` (2026-10-18). The old tests all pass. Each new test fails for "todo", or for the wrong values that follow from it.

| Step | Result |
| --- | --- |
| check, fmt | pass (`flowprobe.roc` is in the list. The fmt step skips the fixtures under `given/`: a case has a header that does not parse on purpose.) |
| L0 | The 8 new files: `Roc application crashed with this message: todo`, 23 of 23 `expect`s. The 14 old files pass. |
| L2 | `FAIL project/pd-search` and `FAIL locks/cc-locked-update`: `the test app wrote no exit file`, `[ROC CRASHED] todo`. The 3 old cases pass. |
| L3 | `FAIL files/cc1-atomic-write`, `files/tf-bad-projects-json` (exit 1 in place of 19, `[ROC CRASHED] todo` in stderr), `locks/cc12-lock-contract` (`[ROC CRASHED] todo`, no output line), `locks/cc12-heartbeat` (about 10 s: no `A.lock/beat`). 9 cases pass (the 9 old ones). |
| Self-test | 23 checks pass |

Run `CASE_TIMEOUT=<s>` limits one L3 case (default 120 s, exit code 124): a lock that waits for ever fails a case and does not stop the run.

## Check against the design

The tests were run against a private reference implementation of all the stubs, the real `Fx` locks and the write included (not kept, TW18). All 23 `expect`s, the 2 L2 cases and the 4 L3 cases passed with it. Mutations of it that each made a test fail:

| Rule ids | Mutation | Caught by |
| --- | --- | --- |
| R-CC12 | the age of 30 s as `>=`, the future time not guarded (U64 underflow), no `beat` taken as fresh, `owns` by prefix, a stale lock never taken, a lock that is never stale in L3 | `lock.roc`, `cc12-lock-contract` |
| R-CC12, R-CC3 | no heartbeat, `unlock!` that always deletes, a stale dir not deleted, `NoWait` that waits (the case hangs and the timeout stops it), no parent dirs for the lock | `cc12-heartbeat`, `cc12-lock-contract` |
| R-CC1 | a write in place, no parent dirs in the write | `cc1-atomic-write` |
| R-CC2 | the 1 day as `>=`, a probe copy chosen without the dir test, a temp name with a short or long hex, a temp of another item, no delete of the temps of the item | `temp.roc`, `cc-locked-update`, `cc1-atomic-write` |
| R-CC3, R-CC5, R-CC6 | no unlock after a failed body, no waiting line, `Wait` that skips `NoWait`, `Known.record!` with `NoWait`, an `ask!` in the lock | `cc-locked-update`, `tf-bad-projects-json` |
| R-LY1 to R-LY7, R-EV13, R-CR1, R-LY4 | the packages root under `ROC_CACHE_DIR`, `ROC_CACHE_DIR` ignored, the config item in the data dir, the cache root from `ROC_CACHE_DIR`, the setting order | `roots.roc`, `cc1-atomic-write` |
| R-PD2 | no stop at `.git`, no stop at the home dir, no stop at all (`pd-search` lists above the repository) | `project.roc`, `pd-search` |
| R-PD3 to R-PD6, R-PD8 | `main.roc` of the root counted, a parent `talon.toml` used, the own `talon.toml` with `[workspace]` used, 2 member files accepted, a non-member taken as a member, no root `talon.toml` of a member, a bad `members` accepted, a file above the root read, no read of the header, no `canonical!`, the listings of the walk not reused, every `talon.toml` read | `project.roc`, `members.roc`, `pd-search` |
| R-TF1 to R-TF6 | a newer format used, `format` kept in the fields, an unknown field dropped, a bad `projects` accepted, a trailing comma in JSON, a float accepted, a header error of kind `usage` | `talonfile.roc`, `projects.roc`, `project.roc`, `tf-bad-projects-json` |
| R-PD9 to R-PD13 | a package or temp copy recorded, `After(n)` as `>=`, the entries not sorted, `Always` that does not update, the GC age as `>=` | `projects.roc`, `cc1-atomic-write` |
| R-CC7 | no order, no reapply, one conflict named | `guard.roc` |

Gaps that the first run of the mutations found, and the change that closed each: the L0 case of a `talon/tmp/<16hex>` that is a file (`temp.roc`), `Known.record!` with `NoWait` (the L2 case now has `busy projects.json`, so `NoWait` gives a failure), and the parent dirs of `write_atomic!` (the L3 case `cc1-atomic-write` writes into new dirs). The tests do not check the 30 s of the lock age at L3 (the old `beat` is 26 years old). `lock.roc` checks it.

## Review (manager, 2026-10-18)

The manager accepted the tests and the output proposals. The answers below are the manager's proposals. The user did not confirm them yet. The code agent follows them.

| # | Answer |
| --- | --- |
| Q1, Q3, Q4, Q5, Q7, Q10, Q11 | The defaults of the slice. |
| Q2 | `HOME` missing when a root needs it: kind `Environment` (exit 18). A XDG variable that is empty or not an absolute path is ignored, as the XDG spec says. |
| Q6 | Yes: `Temp.old` selects a `<item>.lock.<16hex>.stale` dir older than 1 day, as a temp. |
| Q8 | The proposal: a process token from `RealFx.make!`, and a small file of the held lock dirs of that token. Put the file in the Talon cache (`talon/tmp/<token>.locks`), not in the system temp dir, so GC and R-CC2 cover it. |
| Q9 | The proposal: `Busy` with `NoWait`. With `Wait`, the real `Fx` stops with a message that names the path and the error (a crash of the real `Fx` is acceptable here). |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Verify results

`scripts/test.sh` (2026-10-18): check, fmt, L0 (20 files, all `expect`s), L2 (5 cases), L3 (13 cases), self-test (23 checks): all pass. The L3 lock cases ran 3 more times alone with no flake.

### Code written (the stubs of this slice)

| File | Lines | Note |
| --- | --- | --- |
| `cli/lib/Lock.roc`, `Temp.roc`, `Roots.roc`, `Setting.roc`, `Members.roc`, `Project.roc`, `TalonFile.roc`, `Projects.roc`, `Guard.roc`, `Known.roc`, `JsonDoc.roc` (`parse`), `Fx.roc` (`with_lock!`) | 60, 93, 84, 17, 106, 335, 51, 148, 41, 67, 235, 122 | Bodies |
| `cli/lib/Text.roc` | 42 | New helper module (not in the slice): byte order of `Str` (`compare`, `sorted`, `sorted_unique`) and the path pieces (`last_segment`, `dir_of`, `join`). `Str` has no sort. In the exposes list of `cli/lib/main.roc`. |
| `cli/lib/main.roc` | | New package entry `toml` (`roc-toml` 0.1.0 by release URL), new name `Text` |
| `cli/RealFx.roc` | 407 | `write_atomic!` (R-CC1), `lock!`, `unlock!`, the heartbeat, the registry (Q8) |
| `research/slice-002-revert/revert.py` | 119 | The revert check: 55 mutations, run with `python3 -I research/slice-002-revert/revert.py [rule filter]` |

### Decisions that the slice does not fix

| Decision | Options rejected |
| --- | --- |
| Q8: the registry of held locks is the file `<cache>/talon/tmp/<token>.locks` (one lock item for each line). `lock!` adds a line, `unlock!` removes it. At the last line the file and the then empty `talon/tmp` dir are deleted (the L3 case `cc1-atomic-write` lists `talon/` and allows no `tmp`). A write that fails because another process deleted the empty dir is made again once. With no `HOME` there is no registry and no heartbeat. The path comes from `Roots.from_env` and `Roots.item` (pure code). | A registry in the system temp dir. State in a lambda (not possible). |
| The heartbeat runs in the poll of `lock!` with `Wait`: at poll 0, 10, 20, ... (every 2 s, polls of 200 ms). It writes `beat` only for a lock whose `owner` still holds the token. | A heartbeat thread (no threads). |
| K2 stale take over: `Path.rename!` of the dir to `Lock.stale_name`, then `Path.delete_all!`, then try again at once. When the rename fails, the lock is treated as live. When the dir is gone between two calls, try again at once. | A delete in place. |
| Q9 as the manager said: `create_dir!` fails for a reason other than "exists": `NoWait` gives `Busy`, `Wait` is a `crash` with the dir and the error text. | |
| A `talon.toml` or a project file that cannot be read (not "not found" for the file list: it was listed): failure kind `Environment`, `cannot read <path>`. `read_files!` of a `Known.record!` read failure and a write failure: kind `Environment` (Q11), `cannot read <path>: <err>`, `cannot write <path>: <err>`. | Treat an unreadable `talon.toml` as absent (silent). |
| Q5: `--file` that does not exist: `Usage`, `<path as typed>: no such file`. | |
| A `[workspace]` that is not a table (`workspace = 5`): no workspace. | A failure of kind `Input`. |
| `Roots.from_env`: `ROC_CACHE_DIR` that is empty is unset (it is not checked for an absolute path). `HOME` is needed only when a root has no variable. | |
| `Temp.old` also selects `<item>.lock.<16hex>.stale` older than 1 day (Q6). Not tested. | |
| `Projects` entries keep the file order when nothing changes. A written file has the entries sorted by path. A `last_use` below 0 is content that does not parse. | |
| `Members.matches`: a `*` at the edge or in a row (`**`) is read as one `*`. | |

### Revert check (TW12)

Caught 54 of 55. Each mutation was one small change of the code, the tests ran, and the file was put back. The tree of `cli/` was compared with a copy made before the mutations: no difference. Warnings count as a build failure, so the first run of 4 mutations (a compile error or a warning) was changed to a form that compiles.

| Rule ids | Mutations | Caught by |
| --- | --- | --- |
| R-PD1 | `--file` not joined to the start dir | `project.roc` |
| R-PD2 | no stop at `.git`, no stop at home, a walk that never stops | `project.roc`, `pd-search` |
| R-PD3 | the nearest root skipped, `expand` not sorted | `project.roc`, `members.roc` |
| R-PD3 (glob) | `*` pattern: the first part found anywhere (`contains`) in place of at the start | NOT CAUGHT. `members.roc` has no row with the literal first part inside the name but not at its start (for example `a*c` against `xac`). A test gap, not changed (TW18). |
| R-PD4, R-PD5, R-PD6 | 2 member files accepted, a non-member taken as a member, the listing of the walk cut, the own `talon.toml` of the root used | `project.roc`, `pd-search` |
| R-PD8, R-TF4, R-TF5 | header kind, a bad `members` accepted, the line of the header | `project.roc` |
| R-PD9 to R-PD13 | no record, `>=` for the age, a skip that is off, no sort, `Always` that does not update, `prune` that keeps all | `cc-locked-update`, `projects.roc` |
| R-LY1 to R-LY7, R-EV13, R-CR1, R-LY4 | a path item, the lock dir name, the 3 XDG roots, `ROC_CACHE_DIR`, the packages root, the setting order | `roots.roc`, `lock.roc` |
| R-TF1, R-TF2, R-TF3, R-TF6 | `format` last, a JSON array with a trailing comma, an unknown field dropped, a newer format accepted, a wrong kind | `talonfile.roc` |
| R-CC1, R-CC11 | a temp name, a write in place, no parent dirs, no rename over the target | `temp.roc`, `cc1-atomic-write` |
| R-CC2 | no delete of the temps of the item (L2 and L3), a temp of another item, the age of 1 day as `>=` | `cc-locked-update`, `cc1-atomic-write`, `temp.roc` |
| R-CC3, R-CC5, R-CC6 | no `unlock!`, a body that runs on `Busy`, no waiting line, the text of the line, `NoWait` in `Known.record!` | `cc-locked-update`, `lock.roc` |
| R-CC7 | no conflict found | `guard.roc` |
| R-CC12, R-HF3 | the age of 30 s as `>=`, `owns` by prefix, a stale lock never taken, an `unlock!` that deletes a lock of another owner, no heartbeat, no parent dirs, a stale dir not deleted, `NoWait` that waits | `lock.roc`, `cc12-lock-contract`, `cc12-heartbeat` |

## Notes for the manager

| Item | Text |
| --- | --- |
| A stale lock that two processes take at the same time | Both see the same stale dir. One `rename` wins, the other `rename` fails and the second process sees a live lock (a new dir) or a free item. If a third process took the free item between the check and the `rename`, the `rename` can move a live lock. The window is 2 calls. R-CC12 says the mechanism can change. |
| A crash of a process that holds a lock | The registry file `<token>.locks` stays in `talon/tmp/`. `Temp.old` does not choose it (no `.tmp` name, not a dir). A GC rule for it is for the slice of `tln cache gc` (P1). |

## Review of the code (manager, 2026-10-18)

`scripts/test.sh` passes (51 s). Accepted. Open for later slices:

| Item | Where |
| --- | --- |
| A row in `tests/unit/members.roc` where the literal first part is inside the name, not at its start (`a*c` against `xac`). The revert check found this gap. | Next test agent that touches workspaces (slice 005) |
| `talon/tmp/<token>.locks` of a crashed process: GC must remove it. | `tln cache gc` slice (P1) |
| The stale take over race (3 processes) | The limit that R-CC12 accepts |

Status: done (2026-10-18).
