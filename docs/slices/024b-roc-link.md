# 024b Roc link

Phase: P1. Status: done

Slice 024b makes `tln roc link <name> <path>` and `tln roc link --copy [--force] <name> <path>` (CLI 6.6, R-R12, R-R13, R-LK1 to R-LK4). A link (`link-<name>`) is a dir in `toolchains/` with only a `.talon.json` that records the absolute path of a compiler that the user built. Talon runs that path (the proxy and each probe), so a rebuild changes the compiler under the same id. A copy (`copy-<name>`) is a copy of the binary, so a rebuild does not change it. The slice also fixes a hole that slice 023 (G1) opened: `ROC_TOOLCHAIN=link-dev` or a `default-roc` of a local build was written as the `roc:` pin (R-R4, R-LK3). It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-024b-revert/before/` (with `NEW.txt`).

## 0. R-R5 and the plan row

| Item | Result |
| --- | --- |
| R-R5, `tln roc default --git Karakatiza666/roc@my-branch` | Slice 045 (the plan row of 045 lists R-R5; slice 024 said the same). It needs the `.talon.json` of a git build (R-R1). Not in 024b. |
| R-R5, first sentence (selection of a `git-`, `link-`, `copy-` build by `roc +<id>` and `ROC_TOOLCHAIN`, like a nightly) | The proxy half is in 024b for link and copy ids (tests `proxy/lk2-run-link` and `compilers/lk1-link-real`). The `roc default <id>` half was tested in slice 024. |
| R-LK1, second sentence (the local probe results of a link are keyed by the sha256 of the binary) | Slice 030 (`compat.db`). No store of probe results exists yet. See section 8. |

The plan row of 024b, after this slice: R-R4, R-R12, R-R13, R-LK1 (first sentence), R-LK2 to R-LK4, and R-R5 (first sentence, proxy half). The manager moves R-LK1 (second sentence) to slice 030.

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-R12 (`tln roc link dev <path>` makes `link-dev`, no build, no copy), R-CM15 (the command and its operands) | `Link.read`, `Link.source`, `RocLink.link!` | L0 `link` 1, 2. L2 `link/lk1-link` runs 1, 7 to 10. L3 `compilers/lk1-link-real` runs 1, 7 |
| R-R13 (`--copy` makes `copy-<name>`, a copy of the binary) | `Link.read`, `RocLink.link!`, `Fx.copy_file!` | L0 `link` 1. L2 `lk1-link` run 4. L3 `lk1-link-real` run 4. L3 `fx/lk1-real-fx-copy-file` |
| R-LK1, first sentence (a link follows its target: a rebuild changes the compiler under the same id) | `Launch.program!`, `Link.target` | L3 `lk1-link-real` run 3. L2 `proxy/lk2-run-link` (the target is read on each run) |
| R-LK2 (the copy follows symlinks and does not change with the source tree, a name that exists is an error, `--force` replaces) | `Link.decide`, `RocLink.make!`, `RealFiles.copy_file!` | L0 `link` 3. L2 `lk1-link` runs 2, 3, 5. L3 `lk1-link-real` runs 4, 5, 6. L3 `fx/lk1-real-fx-copy-file` |
| R-LK3 (`copy-*` follows R-R4 and R-R5: never a `roc:` pin) | `Pin.decide` | L0 `pin` (rows of R-LK3). L2 `probe/pb1-ladder` run 11. L2 `proxy/lk2-run-link` run 3 |
| R-R4 (Talon never writes `git-*` or `link-*` into a `roc:` pin, R-H6 keeps the header) | `Pin.decide` | L0 `pin` (6 rows). L2 `probe/pb1-ladder` run 10 (`tree.diff` has no `roc:` line) |
| R-LK4 (a link is not a file system link, `.talon.json` records the absolute path, Talon runs that path) | `Link.meta`, `Link.target`, `Launch.program!`, `Proxy.go!`, `Ladder.start!` | L0 `link` 4, 5. L2 `lk1-link` run 1. L2 `lk2-run-link`. L2 `pb1-ladder` run 10. L3 `lk1-link-real` runs 1, 2, 9 |
| R-R5 (first sentence, proxy half) | `Launch.program!`, `Proxy` | L2 `lk2-run-link` runs 1 to 3. L3 `lk1-link-real` run 2 |
| R-FL12 (G4 of slice 024: `--copy` is a flag of `roc link` only, `--force` is for `roc link --copy`) | `Args.allows`, `Link.read` | L0 `args` (usage and accepted rows), L0 `link` 1. L2 `lk1-link` run 6. L3 `lk1-link-real` run 7 |
| R-CC1, R-CC3, R-CC4 step 6 (temp dir and rename, lock of the item, `.talon.json` last), R-CC5 (the waiting line) | `RocLink.make!` | L2 `lk1-link` runs 1, 4, 5, 10, 11. L3 `lk1-link-real` (no temp, trash or lock is left) |
| R-LY1, R-CC9 (`roc list` shows the new kinds, `.last-use` of a link is written when it runs), R-J3, R-OUT2 | `Manage.rows` (as before), `Launch.touch!`, `Link.report`, `Link.data` | L0 `link` 6. L2 `lk1-link` runs 5, 12. L3 `lk1-link-real` runs 2, 8 |
| R-TF1 to R-TF3, R-TF6, R-EC19 (the `.talon.json` of a link is read as a Talon file) | `Link.target` | L0 `link` 5. L2 `lk2-run-link` runs 5, 6 |

`MISSING=1 scripts/rules.sh R-R4 R-R5 R-R12 R-R13 R-LK1 R-LK2 R-LK3 R-LK4` lists none of these ids.

## 2. Flow of the commands (the calls that the L2 cases fix)

`roc link` (the doc of `cli/lib/RocLink.roc` has the table):

| Step | Calls |
| --- | --- |
| 1 to 3 | `env_all`, `clock`, `cwd`, `canonical` (one call with the path made absolute from `cwd` by `Text.resolve`, only to check that the file exists). A usage failure of step 1 makes no call. A missing file ends here (exit 2, no lock). |
| 4, 5 | `lock <item> nowait` (`wait` after the line `waiting for another tln: <item>` when it is busy), `list_dirs` of `toolchains`, then the decision. `exists` ends here (unlock, no write). |
| 6 | `random`. A copy: `copy_file` from `full` (the absolute path of step 2) to `<item>.<hex>.tmp/roc`. `write_atomic` of `<item>.<hex>.tmp/.talon.json`. A failure: `delete` of the temp dir. |
| 7 | `--force` over a copy: `rename` item to `<item>.<hex>.trash`. `rename` temp dir to item. `delete` of the trash dir. Then `unlock`. |

The proxy and the probes (`Launch.program!`, new in this slice): for a `link-*` id in the listing, one `read_files` of `toolchains/<id>/.talon.json`, in the proxy before `write_atomic` of `.last-use`, in `Ladder` before the `canonical` of step 0c. For any other id: no new call. The L2 cases show the order.

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Link.roc` | 89 | Stubs from the test agent. Bodies from the code agent. | New pure module. 8 signatures, all bodies `crash "todo"`. The contract is in the doc comments. |
| `cli/lib/RocLink.roc` | 25 | Same | New command module: `link!` is `crash "todo"`. The doc has the table of the calls. |
| `cli/lib/Launch.roc` | 100 | Test agent (stub) | New `program!`. The stub gives `Ok(Launch.program(run))` (the old behavior, so the old tests pass). The doc has the table. |
| `cli/lib/Proxy.roc`, `cli/lib/Ladder.roc` | about +3 -2, +4 -3 | Test agent (wiring) | They call `Launch.program!` (before `touch!` in the proxy, before `child_env!` in `Ladder.start!`). The docs have the new step 9g and the changed step 0c. |
| `cli/lib/Fx.roc`, `cli/RealFx.roc`, `cli/RealFiles.roc` | about +9, +1, +4 | Test agent, stub | New `copy_file!`. In `RealFiles` it is `crash "todo"`. |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | about +3, +2 | Test agent | The dispatch for `["roc", "link"]`, and `Link`, `RocLink` in the exposes list |
| `cli/fxprobe.roc` | about +9 | Test agent (test tool) | The call `copyfile <from> <to>` |
| `tests/commands/FakeFx.roc` | about +32 | Test agent | `copy_file!` (real bytes, logged as `copy_file <from> <to>`), and `import lib.Text` |
| `tests/unit/link.roc` | 131 | Test agent | 6 `expect`s, red |
| `tests/unit/pin.roc`, `tests/unit/args.roc` | about +6 rows, +9 rows (with 2 comment lines) | Test agent | Rows of R-R4, R-LK3 and G4 (before copies in `before/`) |
| `tests/commands/cases/link/lk1-link/` | 1 case | Test agent | L2, 13 runs |
| `tests/commands/cases/proxy/lk2-run-link/` | 1 case | Test agent | L2, 8 runs |
| `tests/commands/cases/probe/pb1-ladder/` | runs 10 and 11 added | Test agent | The old runs and their expected lines are unchanged (before copy in `before/`) |
| `tests/scenarios/compilers/lk1-link-real/` | 1 case | Test agent | L3, 9 parts |
| `tests/scenarios/fx/lk1-real-fx-copy-file/` | 1 case | Test agent | L3, the real `Fx` job |
| `research/slice-024b-revert/` | | Test agent | `before/` (copies and `NEW.txt`), `stubs/`, `mk-fixtures.py`, `mutate.py`, `mutate-run.log`, `results.md`. The private reference was deleted on 2026-10-23 after the review (it can be rebuilt from the notes in section 14 only by the code agent). |

`scripts/test.sh`, `tests/run.sh`, `tests/commands/run.sh` and `tests/selftest.sh` are not changed. No Args or Pin change is in the stub tree: the code agent makes them (the rows are red).

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Fx.copy_file!` | `{ from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)])`: one file, with its permission bits, a link at `from` is followed, the parent dirs of `to` are made, `Exists` when `to` is there, a directory at `from` is `Other("is a directory")` | R-LK2, R-R13 |
| `Link.Plan` | `{ copy : Bool, force : Bool, name : Str, id : Str, path : Str }` | R-R12, R-R13 |
| `Link.read` | `Args -> Try(Link.Plan, Fail)` | R-CM15, R-FL12, R-LK2 |
| `Link.source` | `{ typed : Str, result : Try(Str, [NotFound, Denied, Other(Str)]) } -> Try(Str, Fail)` | R-R12 |
| `Link.decide` | `{ id : Str, copy : Bool, force : Bool, installed : List(Str) } -> Try([Create, Replace], Fail)` | R-LK2 |
| `Link.meta` | `{ id : Str, kind : [Link, Copy], path : Str, now : U64 } -> Str` | R-LK4, R-LK2, R-TF1 |
| `Link.target` | `{ id : Str, path : Str, text : Try(Str, [NotFound, Denied, Other(Str)]) } -> Try(Str, Fail)` | R-LK4, R-TF3, R-TF6 |
| `Link.report` | `{ id : Str, kind : [Link, Copy], path : Str } -> List(Str)` | R-OUT2 |
| `Link.data` | `{ id : Str, kind : [Link, Copy], path : Str, replaced : Bool } -> JsonDoc` | R-J3, R-OUT4 |
| `Launch.program!` | `Fx, { roots : Roots, id : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } => Try(Str, Fail)` | R-LK4, R-PX2 |
| `RocLink.link!` | `Fx, Args => I32` | R-R12, R-R13 |

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/link.roc` 1 (`read`, 18 rows) | `link-<name>` and `copy-<name>`, the flags before and after the operands, the name as typed. No operand, one, 3 (the count comes first). `--force` with no `--copy`. A name with a space, `/`, `\`, a tab, empty, ending in `.lock` or `.tmp`. | R-CM15, R-R12, R-R13, R-LK2, R-FL12, R-LY1 |
| L0 | 2 (`source`) | The absolute path `full` (no symbolic link resolved), also when `canonical!` gives another path. No such file is exit 2, another failure is exit 18. | R-R12, R-R13 |
| L0 | 3 (`decide`) | Create, Replace (copy and `--force`), the 2 errors (copy: `Use --force`, link: `Run: tln roc remove`), `link-dev` and `copy-dev` are 2 ids | R-LK2 |
| L0 | 4 (`meta`) | The text of `.talon.json` for a link (`path`) and a copy (`source`), the key order, JSON escapes | R-LK4, R-LK2, R-TF1 |
| L0 | 5 (`target`, 14 rows) | The path. A field that Talon does not know. No file, no permission, a read error (exit 18). Not JSON, no `format`, a newer `format` (exit 19). No `path`, a number, `null`, a relative path, an empty path (exit 19). | R-LK4, R-TF1 to R-TF3, R-TF6 |
| L0 | 6 (`report`, `data`) | The 2 lines, the 4 keys in order | R-OUT2, R-J3, R-J4, R-OUT4 |
| L0 | `tests/unit/pin.roc` (6 rows in the slice 013 `expect`) | A link, a copy and a git build held by `ROC_TOOLCHAIN`, a link that rank 6 gives, 2 members: held, no write. A nightly is still written. | R-R4, R-LK3, R-SO11, R-H6 |
| L0 | `tests/unit/args.roc` (6 usage rows, 3 accepted rows) | `--copy` for `install`, `roc install`, `roc rm`, `remove` is exit 2. `--copy=yes` and an unknown flag for `roc link` are exit 2. `roc link` with `--copy`, `--force`, `--json` is accepted. | R-FL12 |
| L2 | `link/lk1-link` (13 runs, `commands` entry) | See the list below | R-R12, R-R13, R-LK2, R-LK4, R-CM15, R-FL12, R-CC1, R-CC3, R-CC5, R-J3, R-LY1 |
| L2 | `proxy/lk2-run-link` (8 runs, `commands` entry) | See the list below | R-LK4, R-R5, R-LK3, R-LK1, R-PX2, R-PX7, R-CC9, R-TF3, R-TF6, R-E1 |
| L2 | `probe/pb1-ladder` runs 10, 11 (`resolve` entry) | No pin, `ROC_TOOLCHAIN` is a link (run 10) or a copy (run 11). The probes run the target path (the copy: `toolchains/copy-fix-1/roc`). `.last-use` is written before each round. The header gets no `roc:` entry. Run 10 reads `.talon.json` before the `canonical` call. | R-R4, R-LK3, R-LK4, R-R5, R-CC9, R-PX2 |
| L3 | `compilers/lk1-link-real` (9 parts) | The real binary, the real `Fx`, and the launcher. A compiler that is a script with a build number. See the list below. | R-R12, R-R13, R-R5, R-LK1, R-LK2, R-LK3, R-LK4, R-CC1, R-FL12, R-CM15, R-J3, R-CC9 |
| L3 | `fx/lk1-real-fx-copy-file` | `copy_file!` of the real `Fx`: the bytes and the executable bit, the parent dirs, a mode with no executable bit stays, a link is followed, a later change of the source, `Exists`, `NotFound`, a directory | R-LK2, R-R13, TW4 |

L2 runs of `lk1-link` (`fx/commands` has the comments; `fx/locks` has `busy toolchains/link-dev6`):

| # | Run | Shows |
| --- | --- | --- |
| 1 | `roc link dev roc-src/zig-out/bin/roc` | The path is made absolute from `cwd`. Lock, listing, `random`, `write_atomic` of the temp `.talon.json`, `rename`. No copy. |
| 2, 3 | the same again, and `--copy fix-1` (exists) | Exit 2, the 2 texts. Calls stop after `list_dirs` and `unlock`: no write. |
| 4 | `--copy fix-2` | `copy_file` into the temp dir, then `write_atomic` of `.talon.json`, then `rename` |
| 5 | `--copy --force fix-1 ... --json` | `rename` to the trash name, `rename` of the temp dir, `delete` of the trash. The human line is on stderr, stdout is the envelope with `replaced: true`. |
| 6 to 9 | `--force dev3 ...`, `dev`, `a b c`, `bad/name` | Exit 2 each. One `args` call each: no effect. |
| 10 | `dev4 roc-src/missing` | Exit 2 after `canonical`, no lock |
| 11 | `--copy dev5 roc-src` (a directory) | The fake `copy_file!` says `Other`: exit 18, `delete` of the temp dir, no item, `unlock` |
| 12 | `dev6 ... --quiet` with a busy lock | `lock nowait: busy`, the line `waiting for another tln: link-dev6`, `lock wait: held`. `--quiet` hides the stdout line. |
| 13 | `roc ls` | The 2 new kinds and `installed_at` of the new files (the date of `TALON_NOW`) |

L2 runs of `lk2-run-link`:

| # | Run | Shows |
| --- | --- | --- |
| 1 | `@roc +link-dev version` | `read_files` of the `.talon.json`, then `.last-use`, `canonical`, `exec` of the target path |
| 2 | `@roc version` (the default is `link-dev`) | The same, after the read of `config.toml` (rank 6) |
| 3 | `@roc version` with `ROC_TOOLCHAIN=copy-fix-1` | No read of `.talon.json`: `exec` of `toolchains/copy-fix-1/roc` |
| 4 | `+link-dev version` with `TALON_PROXY=0` | The target is still found. No `clock`, no `.last-use`. The variables: `TALON_IN_PROXY=1` only. |
| 5, 6 | `link-bad` (no `path`), `link-new` (`format` 2) | Exit 19. The file is named. No `.last-use`, no `canonical`, no `exec`. |
| 7 | `link-gone` (no `.talon.json`) | Exit 18, the text says how to link again |
| 8 | `link-moved` (the target is gone, the fake `exec` says `NotStarted`) | `.last-use` is written and `exec` runs: the proxy does not look at the target file. Exit 18, `cannot run <target>: NotFound`. |

L3 parts of `lk1-link-real` (`cmd` has the comments):

| # | Part | Shows |
| --- | --- | --- |
| 1 | `roc link dev` | The dir has `.talon.json` only. The text has the absolute path and the time of Talon. |
| 2 | `+link-dev`, `ROC_TOOLCHAIN`, the default | The 3 ranks run the target path, the arguments go on, `.last-use` has the time of Talon |
| 3 | a rebuild | The same id runs build 2 (R-LK1) |
| 4 | `--copy fix-2` after build 2, then build 3 | The copy runs build 2 and is executable. The link runs build 3. `.talon.json` has `source`. |
| 5 | the name exists, `--force` | The copy stays (exit 2), `--force` replaces it (build 3). `--force` with no `--copy` and a link that exists are exit 2. |
| 6 | a symbolic link at the source, with a `..` part in the typed path | The copy is a plain file. The link records the absolute path of the symbolic link (`..` removed, nothing resolved). A rebuild that replaces the symbolic link is followed. |
| 7 | usage failures | No operand, a missing file, a bad name, `--git` (not a flag of `roc link`): exit 2 |
| 8 | `roc ls`, `--json` | The kinds, the dates. The envelope only on stdout. |
| 9 | the target is deleted | The proxy gives exit 18 with the path, the copy still runs. No `.tmp`, `.trash` or `.lock` is left. |

Count: 6 new L0 `expect`s in `link.roc`, 6 rows in `pin.roc`, 9 rows in `args.roc`, 2 new L2 cases (21 runs) and 2 added runs in an old case, 2 L3 cases. No selftest row.

## 6. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| `roc link`, stdout | `linked <id> -> <absolute path>` |
| `roc link --copy`, stdout | `copied <absolute path> to <id>` |
| `--json` `data` | `{"id","kind","source","replaced"}`. `kind` is `link` or `copy`. `source` is the target of a link or the file that was copied. `replaced` is true only for `--force` over a copy. The human line goes to stderr. |
| `.talon.json` of a link | `{"format":1,"id","path","installed_at"}` (`path`: R-LK4) |
| `.talon.json` of a copy | `{"format":1,"id","source","installed_at"}` |
| Usage failures | `tln roc link needs a name and a path: tln roc link <name> <path>`, `tln roc link takes a name and a path, got <n> operands`, `flag '--force' is not for 'roc link' without --copy`, `<name> is not a valid compiler name: use one word with no space, no / and no \`, `no such file: <typed path>`, `link-<name> exists. Run: tln roc remove link-<name>`, `copy-<name> exists. Use --force to replace it.` |
| Environment failures | `cannot read <typed path>: <text>`, `cannot copy <path>: <error>`, `cannot write <path>: <error>`, `cannot make <item>: <error>`, `cannot replace <item>: <error>` |
| A broken link in the proxy or a probe | exit 18: `<file>: the link <id> has no .talon.json. Run: tln roc remove <id>, then tln roc link <name> <path>.`. Exit 19: `<file>: the link <id> has no absolute target path` and the texts of `TalonFile.open`. |
| A target that is gone | The existing text (R-E1): `cannot run <target>: <text>`, exit 18 |

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | New modules `Link` (pure) and `RocLink` (command). `Manage` and `RocManage` stay as they are. | More code in `Manage`/`RocManage` (they have 360 and 324 lines). |
| D2 | New call `Fx.copy_file!`. The real `Fx` uses `Path.copy!` (the permission bits stay, a link is followed: measured in the L3 case). | `copy_tree!` with a file (it copies a directory). Read the bytes and `write_atomic!` (the executable bit is lost, and `Fx` has no read of bytes). A hard link (R-HF7 says none is needed, and it fails across file systems). |
| D3 | A copy or a link is made as `roc install` makes a toolchain: the lock of the item with `Wait`, a temp dir `<item>.<hex>.tmp`, `.talon.json` last, `rename` of the dir (R-CC1, R-CC3, R-CC4 step 6). `--force` moves the old dir to the trash name first and deletes it after. | A write into the item dir (a crash leaves a dir with no `.talon.json`, so a broken compiler). `NoWait` and exit 17. |
| D4 | One `canonical!` call with the absolute path (`Text.resolve(cwd, typed)`) before the lock, for both commands, only to check that the file exists. The path in `.talon.json` and the source of the copy are that lexical absolute path: `.` and `..` removed, no symbolic link resolved (review 2026-10-23, R-LK4). `Text.resolve` is the normalize function, no new function. | The canonical path (a link would not follow a build that replaces a symbolic link such as `zig-out/bin/roc`). No existence check (a typo is found at the first run). A check with `read_files!`. |
| D5 | `Launch.program!` reads the `.talon.json` of a link at each run (the proxy and each probe round). The pure `Launch.program` stays as it was, for the other ids. | A signature change of `Launch.program` (it changes `launch.roc`, the `Ladder` code and 3 test files). A cache of the path. |
| D6 | The probes run the target of a link too (`Ladder.start!` calls `Launch.program!`). Without it, a held link would run `toolchains/link-<name>/roc`, a file that does not exist. | Leave the probes for a later slice. |
| D7 | `Launch.program!` comes before `touch!` in the proxy and before `child_env!` in `Ladder.start!`, so a broken link ends the run before any write or `canonical!` call. | After `touch!` (a broken link would get a `.last-use`). |
| D8 | `Pin.decide` writes no id that is not a nightly or a release (`is_compiler_id`): `held` is the local build, `writes` is empty. | A check in each command that writes a pin (4 callers). A check of `Compiler.kind` (`Pin` cannot import `Compiler`: a cycle). |
| D9 | `link` and `link --copy` do not write `config.toml` (R-SO15 is for an install) and write no `.last-use` (no compiler ran). | The first link becomes the default. |
| D10 | A name is one path part: not empty, no `/`, no `\`, no white space, not ending in `.lock` or `.tmp` (R-LY1: `Compiler.installed` would not list it). The prefix is never added twice by hand: `link-link-x` is a valid id. | A check of the characters of a POSIX name only. |
| D11 | The failures: no such file is `Usage` (exit 2, a bad operand). A name that exists is `Usage` (question Q2). A copy that fails is `Environment` (exit 18). A `.talon.json` that has no file is `Environment` (18), one that is bad is `Input` (19, R-TF6). | `Conflict` (17) for a name that exists. |
| D12 | `.talon.json` of a copy has `source` (the path that was copied), a link has `path` (R-LK4). No `sha256` and no `url`: the tree is not a download (R-CV5 is for downloads). | A `sha256` of the copy (one more `Fx` call, and the id is the key of its results, R-LK3). |
| D13 | `Launch.program!` reads `.talon.json` only for a `link-*` id that is in `installed`. A link that is not in the listing was refused before (`Proxy.want` refuses a download of a `link-*` id, `Compiler.require` refuses an id that is not installed). | Read the file for any `link-*` id. |

Answers of the user (`docs/slices/ANSWERS.md`) that bind this slice: `--json --quiet` is the envelope only (slice 007 D4): `link` uses `Install.shown_fx` (the same as `roc default`). The other answers (stale keys, `--as`, `X@sel`, path entries, the nearest move) are for the commands that edit a header or a `talon.toml`: `link` edits no project file.

## 8. Out of scope

| Id | Reason |
| --- | --- |
| R-LK1, second sentence (the local probe results of a link are keyed by the sha256 of the binary, not by the id) | No store of probe results exists yet (`compat.db`: slice 030, R-CC8, R-PK7). The test belongs to 030: a rebuild of the link gives a new key. 024b only makes the proxy and the probes run the current binary. |
| R-R5, `roc default --git <owner/repo@ref>` | Slice 045 |
| R-U1 (`tln roc use link-dev` is an error), and the note of `Pin.toolchain_note`, which tells the user to run `tln roc use <id>` also for a local build | Slice 026. See gap G2. |
| R-GC5 (GC never removes a `link-*` or `copy-*` entry) | Slice 028 |
| R-RR3, R-RM2 (`roc rm` of a link: the dir goes, the target stays) | Slice 024 (tested there) |
| Windows: `roc.exe` in the copy dir, the rename of a running `.exe` | The Windows CI job. `Launch.program` uses `roc` as before. |
| A target that is a directory, or a file that is not a compiler | No check by the design (question Q3). A link to a directory fails at the first run (R-E1). A copy of a directory is exit 18 (L2 run 11, L3 `fx/lk1-real-fx-copy-file`). |
| R-PX5 (`--replace-dep`) | Slice 043 |

## 9. Questions (TW17)

The reference has a default for each question. The named tests pin it.

| # | Question | Default of the tests and of the reference | Other option |
| --- | --- | --- | --- |
| Q1 | R-FL12 names `--force` for `roc link --copy`. Is `--force` valid for a plain `roc link` (a name that exists)? | No: exit 2, `flag '--force' is not for 'roc link' without --copy`. To change a link, the user runs `roc rm link-<name>` first. Pinned by L0 `link` 1, L2 `lk1-link` run 6, L3 part 5. | `--force` replaces a link. Or a link that exists is replaced with no flag (as `rustup toolchain link`). |
| Q2 | The exit code for a name that exists (R-LK2 says "an error") | `Usage`, exit 2. Pinned by L0 `decide`, L2 runs 2 and 3, L3 part 5. | `Conflict`, exit 17 (R-EC17 is for a change by another process) |
| Q3 | Does `link` check the target (a file, executable, `<path> version` gives a compiler id)? | No check. `canonical!` finds a missing file (exit 2). A bad target fails at the first run (R-E1). | Run `<path> version` at `link` time and refuse a file that is no compiler |
| Q4 | Does the first `link` or `link --copy` set the global default when none is set (R-SO15 says "the first compiler that Talon installs")? | No (D9). Not tested. | Yes, as an install |
| Q5 | Is the path of a link the canonical path (a symbolic link at the path is resolved), or the absolute path as typed (R-LK4: "the absolute path of the target")? | Answered by the manager (2026-10-23): the absolute path as typed, made absolute from the current directory, with `.` and `..` removed lexically, no symbolic link resolved (D4). Pinned by L0 `source` and L3 part 6. | The canonical path |
| Q6 | A name that starts with `link-` or `copy-` (`roc link link-x p`) | The id is `link-link-x`. No special case. Not tested. | A refusal, or the prefix is not added twice |

## 10. Design gaps found

| # | Gap |
| --- | --- |
| G1 (G4 of slice 024) | R-FL12 has no row for `--copy`. Proposal for the design: a row `--copy` / `roc link` / `6.6, R-LK2`, and the `--force` row keeps `remove`, `roc link --copy`. `Args.allows` knows only the command, so `--force` with no `--copy` is checked in `Link.read` (question Q1). |
| G2 | `Pin.toolchain_note` (slice 013) tells the user `To change the pin, run tln roc use <id>` for a `ROC_TOOLCHAIN` that differs from the pin. For a `link-`, `copy-` or `git-` id that is wrong: R-U1 says `roc use` refuses it (R-R4, R-LK3). The text needs a second form. Slice 026. |
| G3 | Slice 023 G1 made `ROC_TOOLCHAIN=link-dev` valid and `Pin.decide` wrote the held id as the pin, against R-R4, R-SO11 and R-H6. Fixed here (D8). The doc of `Pin.decide` said that `compiler` was never a local build: true for rank 7 only. |
| G4 | R-LK4 and R-R12 do not say how the proxy and the probes get the path, nor the other fields of `.talon.json`. D5 and D12 are the proposal. |
| G5 | R-R4 names `git-*` and `link-*`. R-LK3 adds `copy-*`. R-SO11 names `debug-<sha>`. The test and the code use one rule: only a nightly or a release is written (D8). |
| G6 | R-CC4 describes a toolchain install. A link and a copy are not downloads, but they make the same kind of dir, so D3 applies the same lock and rename. The design could say so. |

## 11. Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| In a Roc string, `\\` is one backslash and `\"` is a quote | The text `... no \` of the name failure ends with one backslash. In the rows it is written `no \\`. |
| `Path.copy!` keeps the executable bit (measured in the L3 case `fx/lk1-real-fx-copy-file`) | The real `copy_file!` is `Path.copy!` after the checks |

## 12. Red output

`scripts/test.sh` with the stubs (2026-10-23). The old tests all pass.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt | pass | The stubs compile. `roc fmt --check` passes. |
| L0 old files (54 files) | pass | |
| L0 `tests/unit/link.roc` | red: 6 of 6 `expect`s fail | `Roc application crashed with this message: todo` |
| L0 `tests/unit/pin.roc` | red: 1 of 7 (the slice 013 `expect`) | A wrong value: `writes` has `link-dev`, `copy-fix-1`, `git-dd03c09e` as the pin |
| L0 `tests/unit/args.roc` | red: 1 of 5 (the accepted flags) | A wrong value: `--copy` is not a flag of `roc link` yet (the `--copy` usage rows for the other commands pass, they guard the fix) |
| L2 old cases (47) | pass | |
| L2 `link/lk1-link` | red | `[ROC CRASHED] todo` (the test app writes no exit file) |
| L2 `proxy/lk2-run-link` | red | Wrong values: exit 0 for `link-bad`, `link-new`, `link-gone`, and the proxy runs `toolchains/link-dev/roc` |
| L2 `probe/pb1-ladder` | red, only runs 10 and 11 | Wrong values: the line `+ roc: link-dev` and `+ roc: copy-fix-1` in the output, and no `read_files` of `.talon.json` |
| L3 old cases (39, 1 skipped) | pass | |
| L3 `compilers/lk1-link-real`, `fx/lk1-real-fx-copy-file` | red | `[ROC CRASHED] todo` for each call, exit 2 and the tree shows no `link-dev` |
| selftest | pass | |

```text
tests/unit/link.roc: FAILED   (6 failed: Roc application crashed with this message: todo)
tests/unit/pin.roc: FAILED    (1 failed: writes [(a, "link-dev")] against [])
tests/unit/args.roc: FAILED   (1 failed: bad = [roc link --copy ..., roc link --copy --force ...])
FAIL link/lk1-link            the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL proxy/lk2-run-link       stdout differs: -exit 19 / +exit 0 (link-bad, link-new), -exit 18 / +exit 0 (link-gone)
FAIL probe/pb1-ladder         stdout differs: +  + roc: link-dev, +  + roc: copy-fix-1
FAIL compilers/lk1-link-real  stdout differs: the first `tln roc link` crashes with todo
FAIL fx/lk1-real-fx-copy-file stderr differs: +[ROC CRASHED] todo
```

Times on the stub tree: check 2.0 s, l0 3.7 to 5.3 s, l2 1.6 s, l3 9.3 s, selftest 4.6 s. With the reference: check 1.3 s, l0 5.0 s, l2 1.4 s, l3 9.4 s, selftest 3.9 s, no `WARN` line.

## 13. Check against the design (TW21)

The expected files of the L2 cases, the L3 cases and the new rows were made by a private reference (deleted after the review on 2026-10-23) and read by eye against the design. With the reference all 6 `link.roc` `expect`s, the rows of `pin.roc` and `args.roc`, the 2 new L2 cases, the 2 runs of `pb1-ladder` and the 2 L3 cases pass, and `scripts/test.sh` exits 0 with no `WARN` (check 1.3 s, l0 5.0 s, l2 1.4 s, l3 9.4 s, selftest 3.9 s).

Points that were read by eye:

| File | What was checked |
| --- | --- |
| `link/lk1-link/expect/calls.log` | The order of the calls of each run against the table of section 2. A refused name: no write. A replace: `rename` to the trash, `rename` of the temp dir, `delete`. The failed copy: the temp dir is deleted. |
| `link/lk1-link/expect/tree.diff` | No `.trash` dir is left. The `.talon.json` of a replaced copy has the new source and the date of `TALON_NOW`. The link dir has only `.talon.json`. |
| `proxy/lk2-run-link/expect/calls.log` | The read of `.talon.json` is before `write_atomic` of `.last-use`. A broken link ends before `write_atomic`, `canonical` and `exec`. A copy makes no read. |
| `probe/pb1-ladder/expect` | The old runs are unchanged. Runs 10 and 11: the program is the target (10) or the copy (11), `tree.diff` has no `roc:` line. |
| `compilers/lk1-link-real/expect/stdout` | A rebuild changes the link and not the copy. `--force` gives the new build. The link at the source is resolved. No temp, trash or lock is left. |

## 14. Revert check (TW12)

Method: the private reference (deleted after the review on 2026-10-23) made all new tests pass. `research/slice-024b-revert/mutate.py` applies one hand-made mutation at a time to the reference, runs only the layers that should catch it (the 3 L0 files, the 3 L2 cases, the 2 L3 cases), and puts the file back. No full sweep. Result: 41 mutations, 40 caught, 1 not caught (M37). 2 of them (M34, M38) did not apply or compile the first time and were written again. The table is in `research/slice-024b-revert/results.md` (the log of M06 to M38 is `mutate-run.log`).

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Link.read` and the name rules (prefix, `--force` check, `.lock`, backslash, count text) | M01 to M05 | L0 (M01 also L2, L3) |
| `Link.source`, `Link.decide` (copy with `--force`, the link text) | M06 to M08 | L0 |
| `Link.source` gives `full`, not the canonical or the typed path (changed 2026-10-23) | M20, M41 | L0, L3 (M41 also L2) |
| `Link.meta` (key `source`, the time), `Link.target` (absolute path, `newest`, the kind of no file), `Link.report`, `Link.data` | M09 to M15 | L0, and L2 or L3 for the text, the time and the key |
| `RocLink` (`Wait`, the delete of the temp dir, the trash rename and delete, the lexical absolute path, the clock, `--json`, `--quiet`, the check of `canonical!`, the kind of `.talon.json`) | M16 to M25, M39, M40, M38 | L2 (M20 only L3: the fake `canonical!` gives the path as it is, the real one resolves the link) |
| `Launch.program!` (no read, a read for a copy), `Proxy` (the order with `touch!`, the pure `program`), `Ladder` (the pure `program`) | M26 to M30 | L2 (M26, M29 also L3) |
| `Pin.decide` (a local build written as the pin) | M31 | L0, L2 |
| `Args` (`--copy` for every command, `--copy` missing) | M32, M33 | L0 (M33 also L2, L3) |
| `RealFiles.copy_file!` (no `Exists`, a copy by bytes with no executable bit, no parent dirs) | M34 to M36 | L3 |
| `RealFiles.copy_file!` (the text of the error of a directory) | M37 | not caught: the L3 case hides the text of `Other` on purpose (it is the text of the platform) |

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The docs of `Link`, `RocLink`, `Launch.program!`, `Fx.copy_file!`, `Proxy` (step 9g) and `Ladder` (step 0c) have the contract. The L2 `calls.log` fixes the order of the calls, including the one `read_files` of `Launch.program!`. |
| N2 | `Pin.decide`: `writes` only for an id that `is_compiler_id` (the private function of `Pin.roc`: a nightly or a release). `held` stays the local build. `Pin` cannot import `Compiler` (a cycle). |
| N3 | `Args.allows`: add `"--copy" => cmd == "roc link"`. `--force` stays for `remove` and `roc link`. |
| N4 | `RealFiles.copy_file!`: `Path.copy!` after the checks `NotFound`, `Exists`, directory. It keeps the executable bit. The parent dirs of `to` are made. |
| N5 | A function must not have the name of a method of its type module (slice 020 limit). `RocLink` has the private helpers `flow!`, `make!`, `build!`, `print!`, `clock_now!`, `unlocked`. |
| N6 | `Link.read` checks in this order: the count of operands, `--force` with no `--copy`, the name. The L0 rows fix it. |
| N7 | Do not edit a test (TW18). A question goes to the manager. |

## Review (manager, 2026-10-23)

| Item | Result |
| --- | --- |
| D1 to D13 | Accepted |
| Section 6 proposals (text and `data` fields) | Accepted |
| G1 to G6 | Accepted. The design text stays a proposal in this file. G2 goes to slice 026. |
| Q1, Q2, Q3, Q4, Q6 | The defaults are accepted |
| Q5 | Changed. The link records the absolute path as the user typed it, made absolute against the current directory and with `.` and `..` removed lexically, and with no symbolic link resolved. Reason: R-LK4 says "the absolute path of the target", and a link to a dev build must follow a build that replaces a symbolic link (for example `zig-out/bin/roc`). D4 changed. |
| R-R5 `default --git` | Moves to slice 045 (the manager updates PLAN-P1.md) |

Test changes for Q5 (test agent, 2026-10-23):

| File | Change |
| --- | --- |
| `cli/lib/Link.roc` | `Link.source` has a new field `full`. A good result gives `full`. No new normalize function: `Text.resolve` is used. |
| `tests/unit/link.roc` | `source` `expect`: `Ok(canonical)` with another canonical path gives `full` |
| `tests/scenarios/compilers/lk1-link-real` part 6 | The typed path has a `..` part. The link and the copy record `$PROJECT/roc-src/lnk-roc`. The symbolic link is then replaced and `+link-via-link` runs the new build. |
| Mutations | M20 changed, M39 to M41 added, all caught (table in section 14). L2 is not changed: the fake `canonical!` gives the path as it is. |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | A failed `rename!` of the temp dir only deletes the temp dir. With `--force` the old copy stays in the trash dir and GC removes it (accepted by the manager). | A rename of the trash dir back (a call that no test fixes) |
| C2 | `RealFiles.copy_file!` checks in this order: `from` missing (`NotFound`), `to` there (`Exists`), `from` is a directory (also a link to a directory, by `Path.canonicalize!`), then `Path.copy!` (accepted). | Check the directory after the copy |
| C3 | No stale-temp cleanup (`Temp.of_item`) in `RocLink`: the L2 `calls.log` has no such call (accepted). | A cleanup before `random` |
| C4 | The copies of two helpers are gone. New public `Clock.now!(fx, env)` (one `clock!`, `TALON_NOW`, a bad value is `Usage`) and `Fx.locked!(fx, item, body!)` (`with_lock!` with `Wait`, `Busy` is `Internal`). Callers: `Clock.now!` in `RocLink`, `Proxy.run!` (the private `clock_now!` is deleted), `Install.begin!`. `Fx.locked!` in `RocLink`, `RocManage` (the private `unlocked` is deleted, 2 callers), `RocInstall` (`install_offer!`, `set_default!`), `Known.record_with!`. Same texts and same call order: the old tests pass with no change. `RocInstall.offer!` keeps its own read of the time: it also needs the real time for the list of nightlies. | A copy of the helpers in `RocLink` |

## Code result

| Item | Value |
| --- | --- |
| `scripts/test.sh` | exit 0, no WARN. check 2.5 s, fmt 0.1 s, l0 57 files pass 6.3 s, l2 50 passed 1.9 s, l3 41 passed 1 skipped 9.3 s, selftest pass 4.0 s. `OPT=speed`: exit 0 (l2 73 s: LLVM build). |
| Files (lines) | `cli/lib/Link.roc` 158, `cli/lib/RocLink.roc` 132, `cli/lib/Launch.roc` 110, `cli/RealFiles.roc` 286, `cli/lib/Args.roc` 267, `cli/lib/Pin.roc` 430, `cli/lib/Clock.roc` 119, `cli/lib/Fx.roc` 244, `cli/lib/Proxy.roc` 473, `cli/lib/Install.roc` 268, `cli/lib/RocManage.roc` 317, `cli/lib/RocInstall.roc` 351, `cli/lib/Known.roc` 72 |
| Signatures | The public signatures of the slice are as in section 4. New public: `Clock.now!`, `Fx.locked!` (C4). |

## Verify results (code agent, TW12)

42 small mutations (`research/slice-024b-revert/code-mutate.py`, `code-results.md`, a copy of the final code in `code-final/` that is restored before and after each mutation). Caught 37 of 42. After the run `cli/` is the same as `code-final/` (`diff -r`: SAME).

| Group | Mutations | Result |
| --- | --- | --- |
| `Link.read`, `source`, `decide`, `meta`, `target`, `report`, `data`, the name rules | M01 to M16 | caught by L0 `link` (M06 also by the L3 case) |
| `RocLink`: `Wait`, temp dir delete, trash delete and name, absolute path, canonical path, clock, `--json`, `--quiet`, kinds, `replaced` | M17 to M27 | caught by L2 `link/` (M21 by L3 `lk1-link-real`) |
| `Launch.program!` | M28, M29 | caught by L2 `proxy/lk2` |
| `Pin.decide`, `Args` | M31 to M33 | caught by L0 `pin`, `args` |
| `RealFiles.copy_file!` | M34, M35 | caught by L3 `fx/lk1-real-fx-copy-file` |
| `Clock.now!`, `Fx.locked!` | M39, M41, M42 | caught by L2 `link/` |

| Not caught | Class |
| --- | --- |
| M30: `Launch.program!` reads `.talon.json` for a `link-*` id that is not installed | Equivalent change: `Proxy.want` and `Compiler.require` refuse such an id before the call |
| M36: a directory as `from` is not seen (the check tests `to`). M37: the text of the error of a directory. M38: a link to a directory is not seen as a directory | Equivalent change in the L3 view: `Path.copy!` also fails, and the case checks the variant `Other`, not the platform text |
| M40: a bad `TALON_NOW` gives `Environment`, not `Usage` | Test gap: no L2 or L3 case sets a bad `TALON_NOW` (old hole of R-EV22, Q5, Q7). Proposal: one row in an L2 case. |

Questions (TW17): none.

## Gap rows (test agent)

| Gap | Row | Check |
| --- | --- | --- |
| M40 (R-EV22): a bad `TALON_NOW` is exit 2 through `Clock.now!` | L3 `compilers/lk1-link-real`, part 7b: `env TALON_NOW=yesterday tln roc link dev9 $B`. Expected: exit 2, stderr `tln: error[usage]: TALON_NOW is not a UTC time: yesterday`, no `link-dev9` in the final `ls`. It is an L3 row, not an L2 run, because `fx/env` of an L2 case is one file for all runs. | M40 applied by hand (`Usage` changed to `Environment` in `cli/lib/Clock.roc`): the case fails on the stderr line. `Clock.roc` restored: `cmp` with `code-final/lib/Clock.roc` is the same. |

## Close (manager, 2026-10-23)

C1 to C4 of the code agent are accepted (`Clock.now!` and `Fx.locked!` are shared, no copies). M40 is caught by L3 part 7b. M30 and M36 to M38 are equivalent. `scripts/test.sh` exits 0 with no WARN. Status: done.
