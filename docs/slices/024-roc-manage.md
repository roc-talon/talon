# 024 Roc list, default, remove

Phase: P1. Status: done

Slice 024 makes `tln roc list` (`ls`), `tln roc default <ref>` and `tln roc remove <id>` (`rm`) (CLI 6.6, R-CS2, R-RR1 to R-RR3). `list` shows the installed compilers. `default` writes the global default (rank 6, `default-roc` of `config.toml`) with the full id. `remove` takes one compiler away, moves the default when the compiler was the default, and lists the known projects that pin it. It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-024-revert/before/` (with `NEW.txt`).

## 0. Split proposal (for the manager)

The plan row (350 lines) has 4 commands. The reference for the 3 commands below has about 515 lines of code (without comments and blank lines): `Manage.roc` 249 (pure) and `RocManage.roc` 266 (commands). That is over TW19 (about 400). So this file covers the first part, and 2 more cuts are possible.

| Slice | Content | Rules | Lines of the reference (estimate) | State |
| --- | --- | --- | --- | --- |
| 024 (this file) | `roc list`, `roc default`, `roc remove` | R-CS2, R-RR1 to R-RR3, R-RM2, R-R5 (by name), R-CM15, R-CM19, and the shared R-SC9, R-SC10, R-SC13, R-GC3, R-CC10 | 515 | tests written |
| 024b | `roc link <name> <path>`, `roc link --copy <name> <path>`, the proxy and the probes run the target of a link, the new `Fx` call that copies a file (`copy_tree!` copies a directory), `--copy` in the flag table | R-R12, R-R13, R-R4, R-LK1 to R-LK4, R-CM15 (link), R-FL12 (`--copy`) | about 200 | not started |

Cut inside 024, if the manager wants slices of about 300 lines: `list` and `default` (about 320: the table, the `config.toml` edit, the download of a missing compiler) and `remove` (about 200: the projects, the next default, the trash). The tests are already separate for each command (L0 rows of `tests/unit/manage.roc`, one L2 case for each command, one section of the L3 case), so the cut needs no new test. Each half has a green path alone: each command has its own functions, and only `Manage.read`, `Manage.default_set` (`remove` uses it for the move of the default) and the helpers `read_text!` and `read_config!` are shared.

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-CS2 (`roc default <ref>` writes the global default, rank 6), R-SC13 (the full id is stored, a prefix is expanded first), R-CC6 (`config.toml` changes under its lock, by a span edit), R-CC7 (the file is read again before the write) | `Manage.default_set`, `RocManage.default!` | L0 `default_set`. L2 `roc/df1-default` runs 1 to 4, 8. L3 `compilers/mg1-manage` runs 2, 3 |
| R-R5 (selection by name: `git-*`, `link-*` and `copy-*` are valid defaults, a prefix of an installed id is expanded, the full id is stored), R-SC9 (`git-dd03` is a prefix) | `RocManage.default_flow!` | L2 `df1-default` runs 4, 8. L3 `mg1-manage` run 3 |
| R-SC5, R-SC10 (`tln roc ...` names an installed compiler, a prefix is expanded, an ambiguous prefix lists the ids, exit 2) | `Nightlies.pick` over the installed ids | L2 `df1-default` run 5, `rm1-remove` runs 1, 2. L3 `mg1-manage` runs 3, 7 |
| R-DL3, R-DL4, R-NI6 (a compiler that is not installed is the download of `roc install`, Enter is yes, a decline is exit 13), R-DI12 (`--offline`) | `RocManage.fetched!` (calls `RocInstall.offer!` and `install_offer!`) | L2 `df1-default` runs 9, 10, 11 |
| R-RR1 (the default moves to the newest installed nightly or release that the `nightly` switch allows, a note is printed, with none the default is not set), R-NS3 (the switch), R-NS6 (a `git-`, `link-`, `copy-` build is never chosen) | `Manage.next_default`, `Manage.default_unset`, `RocManage.remove_flow!` | L0 `next_default`, `default_unset`. L2 `rm1-remove` runs 6, 7. L3 `mg1-manage` runs 5, 7 |
| R-RR2 (the known projects that pin the compiler are printed, no prompt) | `Manage.pinned_by`, `RocManage.pinned!` | L0 `pinned_by`. L2 `rm1-remove` runs 5, 6 (`TALON_INTERACTIVE=1`, no `ask` call). L3 `mg1-manage` run 4 |
| R-RR3, R-RM2 (a `link-*` entry: the dir goes, the target never) | `RocManage.trash!` | L2 `rm1-remove` run 8 (the target is in `project/`, so `tree.diff` shows it stays). L3 `mg1-manage` run 6 |
| R-GC3 (`roc rm` removes the `compat-<id>/` dir of the compiler, no other), R-CC10 (the lock of the item with `Wait`, `rename` to `<item>.<hex>.trash`, delete, no age rule) | `Manage.compat_of`, `Manage.trash_name`, `RocManage.trash!` | L0 `compat_of`. L2 `rm1-remove` runs 5, 6. L3 `mg1-manage` run 4 (`compat-other` stays, no trash left) |
| R-CM15 (the commands exist, one operand), R-CM19 (`ls` is `list`, `rm` is `remove`, the text names the long form) | `Manage.read`, `Manage.read_list`, `Run.tln!` | L0 `read`. L2 `ls1-list` run 1, `rm1-remove` run 5. L3 `mg1-manage` run 1, 4 |
| R-LY1 (what a compiler dir is: no lock, temp, zig dir or file), R-CC9 (the `.last-use` time), R-J3, R-J4, R-OUT2 (the table, the `--json` envelope) | `Compiler.installed` (as before), `Manage.rows`, `ls_report`, `ls_data` | L0 `rows`, `ls_report`, `ls_data`. L2 `ls1-list`. L3 `mg1-manage` run 1 |

`MISSING=1 scripts/rules.sh R-CS2 R-RR1 R-RR2 R-RR3 R-RM2 R-R5 R-CM15 R-CM19` lists none of these ids. The ids of 024b (R-R4, R-R12, R-R13, R-LK1 to R-LK4) are open.

## 2. Flow of the commands (the calls that the L2 cases fix)

The table of calls for each command is in the doc comment of `cli/lib/RocManage.roc`. There is no new `Fx` call and no new field.

| Command | Calls, in order |
| --- | --- |
| `roc list` | `args`, `env_all`, `read_files` (config), `list_dirs` (toolchains), one `read_files` with `.talon.json` and `.last-use` of each id. No `clock`, no lock. |
| `roc default` (installed) | `args`, `env_all`, `list_dirs`, then the config lock: `lock` `nowait`, `read_files`, `read_files`, `write_atomic`, `unlock`. A value that is equal: no second read and no write. |
| `roc default` (not installed) | `args`, `env_all`, `list_dirs`, then `RocInstall.offer!` (as `roc install`), `ask`, `RocInstall.install_offer!`, then the config lock as above |
| `roc remove` | `args`, `env_all`, `read_files` (config), `list_dirs`, `read_files` (`projects.json`), `read_files` (the project files, one call), `read_files` (the `.talon.json` of each id), then the item lock (`nowait`, and when busy the line `waiting for another tln` and a `wait` lock): `random`, `rename`, `delete`, `unlock`, then, for the default, the config lock |

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Manage.roc` | 133 | Stubs from the test agent. Bodies from the code agent. | New pure module. 17 signatures, all bodies `crash "todo"`. The contract is in the doc comments. |
| `cli/lib/RocManage.roc` | 54 | Same | New command module. `list!`, `default!`, `remove!` are `crash "todo"`. The doc has the 3 tables of calls. |
| `cli/lib/Run.roc` | +7 | Test agent | The dispatch for `["roc", "list"]`, `["roc", "default"]`, `["roc", "remove"]` (before copy in `before/`) |
| `cli/lib/main.roc` | +2 | Test agent | `Manage` and `RocManage` in the exposes list |
| `tests/unit/manage.roc` | 247 | Test agent | 11 `expect`s, red |
| `tests/commands/cases/roc/ls1-list/`, `df1-default/`, `rm1-remove/` | 3 cases | Test agent | L2, 4 + 11 + 9 runs, red |
| `tests/scenarios/compilers/mg1-manage/` | 1 case | Test agent | L3, 14 runs, red |
| `tests/commands/run.sh` | +3 | Test agent (test tool) | In a `.json` file of the given `home/` and `project/`, `{w}` is the case dir. A project path in `projects.json` and a link path in `.talon.json` must be real paths. Before copy in `before/`. |
| `research/slice-024-revert/` | | Test agent | `before/` (copies and `NEW.txt`), `mk-fixtures.py`, `mutate.py` (it needs the deleted reference to run), `results.md` (the private reference is deleted) |

`scripts/test.sh`, `tests/run.sh` and `tests/selftest.sh` are not changed. `docs/slices/PLAN-P1.md` is not changed.

## 4. Public signatures

`Manage` (pure, `cli/lib/Manage.roc`):

| Item | Type | Rule |
| --- | --- | --- |
| `Manage.Read` | `Try(Str, [NotFound, Denied, Other(Str)])` (a result of `Fx.read_files!`) | |
| `Manage.Row` | `{ id, kind : [Nightly, Release, Git, Link, Copy], installed_at : Try(U64, [Unknown]), last_use : Try(U64, [Unknown]), is_default : Bool }` | R-LY1 |
| `kind_of`, `kind_text` | `Str -> [Nightly, Release, Git, Link, Copy]`, `[...] -> Str` | R-LY1 |
| `read` | `{ args : Args, verb : [Default, Remove] } -> Try(Str, Fail)`: one operand, else `Usage` with the long form | R-CM15, R-CM19 |
| `read_list` | `Args -> Try({}, Fail)`: no operand (question Q1) | R-CM15 |
| `rows` | `{ found : List({ id, meta : Read, last_use : Read }), default : Try(Str, [Unset]) } -> List(Row)` | R-LY1, R-CC9 |
| `ls_report`, `ls_data` | `{ rows, default } -> { stdout : List(Str), stderr : List(Str) }`, `... -> JsonDoc` | R-OUT2, R-J3 |
| `default_set` | `{ path, text, id } -> Try({ previous : Try(Str, [Unset]), edit : [Same, Set(Str)] }, Fail)` | R-CS2, R-CC6 |
| `default_unset` | `{ path, text } -> Try([Same, Set(Str)], Fail)` | R-RR1, R-CC6 |
| `next_default` | `{ installed, removed, nightly, times } -> Try(Str, [None])` | R-RR1, R-NS3, R-NS6 |
| `pinned_by` | `{ id, projects : List({ path, text : Read }) } -> List(Str)` | R-RR2 |
| `compat_of` | `Read -> Try(Str, [None])` | R-GC3 |
| `trash_name` | `{ item, hex } -> Str` | R-CC10 |
| `default_report`, `default_data` | `{ id, installed, edit : [Same, Set] } -> List(Str)`, `{ id, previous, edit, installed } -> JsonDoc` | R-OUT2, R-J3 |
| `remove_report`, `remove_data` | `{ id, was_default, next, projects } -> List(Str)`, `{ id, item, was_default, default, projects } -> JsonDoc` | R-RR1, R-RR2, R-OUT2 |

`RocManage` (commands): `list!`, `default!`, `remove!` all have the type `Fx, Args => I32`.

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/manage.roc` 1 (`read`, `read_list`) | One operand as typed. None and 2 or more: `Usage` with `tln roc default` and `tln roc remove` (also for `rm`). `--git` and `--yes` and `--json` do not change the operand. `roc ls` and `roc rm` parse to `list` and `remove`. `roc list x`: `Usage`. | R-CM15, R-CM19 |
| L0 | 2 (`kind_of`, `rows`) | The 5 kinds. A time that is missing, not JSON, not a field, or a bad date is `Unknown`. The default is the other tag form of a nightly too. | R-LY1, R-CC9 |
| L0 | 3 (`ls_report`) | The columns, the `*` mark, dates, `-`, no trailing space. No row: one line. A default that is not installed: the warning, the table stays. | R-OUT2 |
| L0 | 4 (`ls_data`) | The keys and the order, `null` for an unknown time and for no default. | R-J3, R-J4, R-OUT4 |
| L0 | 5 (`default_set`) | Same value: `Same`. Another value: replaced in place, comment and order stay. No key: added before the first table. Empty text: one line. Not TOML and not a text: exit 19. | R-CS2, R-CC6, R-LY4 |
| L0 | 6 (`default_unset`) | The line goes with its comment, other bytes stay. No key: `Same`. | R-RR1, R-CC6 |
| L0 | 7 (`next_default`) | The newest by `published_at`, never the removed id, never a git, link or copy build, a release only with the switch off, none gives `Err(None)`. A release with a date (in `times`) is ordered by its date: newer than every nightly it wins, older it loses (G2). | R-RR1, R-NS3, R-NS6 |
| L0 | 8 (`pinned_by`) | The other tag form counts. A missing file, a read error, a header that does not parse, a header with no pin: no pin. Paths sorted. | R-RR2 |
| L0 | 9 (`compat_of`, `trash_name`) | The `compat` text of `.talon.json`, else `None`. `<item>.<hex>.trash`. | R-GC3, R-CC10 |
| L0 | 10, 11 (the texts) | `default_report`, `default_data`, `remove_report`, `remove_data` | R-CS2, R-RR1, R-RR2, R-OUT2, R-J3 |
| L2 | `roc/ls1-list` (4 runs) | 1 `ls`: the 5 kinds, the default, `-` for a missing file or time, the non-compilers of `toolchains/` are not rows. 2 `list --json`. 3 a default that is not installed: the warning on stderr. 4 no toolchains dir. The calls: one `read_files` for all the files. | R-CM19, R-LY1, R-CC9, R-J3, R-OUT2 |
| L2 | `roc/df1-default` (11 runs) | 1 no `config.toml`: made. 2 the value is replaced. 3 a prefix gives the id that is the default already: no write. 4 a prefix of a git build. 5 an ambiguous prefix (exit 2). 6, 7 no operand and 2 operands (exit 2). 8 a link by name, `--json` (`previous`, `changed`). 9 a missing compiler: `offer!`, the prompt, the install, then the default. 10 the prompt declined (exit 13, no write). 11 `--offline` (exit 15). | R-CS2, R-SC13, R-SC10, R-SC9, R-R5, R-CM15, R-DL3, R-NI6, R-CC4, R-CC6, R-DI12, R-J3 |
| L2 | `roc/rm1-remove` (9 runs) | 1 to 4 an ambiguous prefix, no match, no operand, 2 operands (exit 2, nothing removed). 5 `rm`: pinned by a project (listed), no prompt with `TALON_INTERACTIVE=1`, the compat dir goes, `compat-other` stays. 6 the default by a prefix: 2 projects (one in the other tag form), the default moves to the newest nightly by `published_at`. 7 the default again with `TALON_NIGHTLY=false`: no default. 8 a link, with a busy lock (`fx/locks`): `waiting for another tln: link-dev`, then a `wait` lock, then the dir goes, the target stays. 9 a git build, `--json`. | R-CM19, R-RR1 to R-RR3, R-RM2, R-GC3, R-CC10, R-NS3, R-SC10, R-J3 |
| L3 | `compilers/mg1-manage` (14 commands) | The real binary and `Fx`. `ls`, `list --json`. `default` by a prefix (comments and other lines of `config.toml` stay), by a git prefix, the 2 usage errors. `rm` with 2 projects, a compat dir, the default that moves, a link with its target, the default that is unset with `TALON_NIGHTLY=0`. After: no trash dir, no temp, no lock. | R-CS2, R-RR1 to R-RR3, R-RM2, R-R5, R-GC3, R-CC1, R-CC6, R-CC10, R-NS3, R-J3 |

Count: 11 L0 `expect`s, 3 L2 cases (24 runs), 1 L3 case (14 commands). No selftest row.

## 6. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| `roc list`, stdout | A header and one line for each compiler, in byte order of the id: `ID`, `KIND`, `INSTALLED`, `LAST USE`, each column as wide as its widest cell, 2 spaces between. A star and a space before the default, 2 spaces before the others. A time is a date (`2026-10-20`), `-` is no time. |
| `roc list`, no compiler | `no compiler is installed. Run: tln roc install @latest` |
| `roc list`, stderr | `warning: the default compiler <id> is not installed` |
| `roc list --json` `data` | `{"default","compilers":[{"id","kind","installed_at","last_use","default"}]}`. `kind` is `nightly`, `release`, `git`, `link` or `copy`. A time is `2026-10-20T12:00:00Z` or `null`. `default` is an id or `null`. stdout is only the envelope. |
| `roc default`, stdout | `installed <id>` (only when this run downloaded it), then `<id> is now the default compiler` or `<id> is already the default compiler`. With `--json` these go to stderr. |
| `roc default --json` `data` | `{"id","previous","changed","installed"}` (`previous` is an id or `null`, the 2 flags are booleans) |
| `roc remove`, stdout | `removed <id>`. When it was the default: `the default compiler is now <next>` or `no default compiler is set now`. When projects pin it: `known projects that pin <id> (the proxy installs it again when one runs):`, then `  <path>` for each project. With `--json` these go to stderr. |
| `roc remove --json` `data` | `{"id","path","was_default","default","projects"}` (`default` is the default after the command, an id or `null`) |
| Errors | `tln: error[usage]: tln roc default needs one compiler: a full id, a prefix or @latest`, `tln roc default takes one compiler, got <n>`, `tln roc remove needs one compiler: a full id or a prefix of an installed compiler`, `tln roc remove takes one compiler, got <n>`, `tln roc list takes no operand, got <n>`, `no compiler matches <text>`, `<text> matches <n> compilers: <ids>. Use a longer prefix or the full id.` (the texts of slice 020). A decline: `tln: error[consent]: <id> is not installed. Nothing was downloaded.` (exit 13). |

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `roc default <text>` looks at the installed ids first (`Nightlies.pick` with the installed ids as `named` and `auto`). A unique match is used with no network. Only `NoMatch`, and a text that starts with `@`, go on to the online list and the download (`RocInstall.offer!`). `Ambiguous` among the installed ids is an error. Reason: R-SC9 gives `git-dd03` as a prefix, and no list has a git build. | The online list only (a prefix of a git build never matches; `roc default <prefix>` needs the network). |
| D2 | `roc default` of a compiler that is not installed is the download of `roc install` with its prompt (`Consent.roc_install`, answer default yes, R-DL3), and then the default is set. A decline changes nothing (exit 13). | No download (R-NI6 and R-DL7 name `roc default`). |
| D3 | `roc remove` takes a full id or a prefix of an installed id (`Nightlies.pick` over the installed ids). No match: `no compiler matches <text>`, exit 2. | Exit 18, or a text that says "not installed". |
| D4 | The order of `remove`: the item lock, `rename` to the trash, delete, unlock, then the move of the default. A crash in between leaves a default that names a compiler that is gone: the proxy says `not installed` (R-SO12, exit 13), and `roc default` repairs it. | The default first (a failed removal would move the default for nothing). |
| D5 | The known projects that pin the compiler are the ones whose header `roc:` entry is `Pin.same_id` with it. A `.roc-version` or a `talon.toml` range is not a pin here (question Q3). | |
| D6 | The `compat-<id>/` dir of the removed compiler goes with it (R-GC3 names `tln roc rm`). The compat id is the `compat` field of `.talon.json`. No field or `null`: nothing else is removed. | A scan of the build root for the compat dir. |
| D7 | `roc list` columns: `ID`, `KIND`, `INSTALLED` (`installed_at` of `.talon.json`), `LAST USE` (`.last-use`, R-CC9). It does not show the `roc` on `PATH` (rank 7). | A column with the size, or with the source URL. |
| D8 | `roc list` ignores `--quiet`: the table is the answer. With `--json` the table is not printed. | |
| D9 | One `read_files!` call reads `.talon.json` and `.last-use` of all compilers (2 paths for each id), and one call reads all the project files. | One call for each file. |
| D10 | `remove` takes the lock of the item with `Wait`, as `roc install` (review of Q2: the user named the compiler, so `rm` waits and GC skips). | `NoWait` with exit 17. |
| D11 | `Manage.read` for `roc default --git <ref>` gives the operand and ignores `--git` (the meaning of `--git` for `default` is slice 045). | A usage error for `--git`. |

Answers of the user (`docs/slices/PLAN-P1.md`, `docs/slices/ANSWERS.md`) that bind this slice:

| Answer | Effect here |
| --- | --- |
| `--json --quiet`: the JSON envelope only (slice 007 D4) | `default` and `remove` use `Install.shown_fx` (`--quiet` hides the text, `--json` moves it to stderr), so with both flags stdout is the envelope and stderr is empty. `list` prints the envelope with `--json` and the table otherwise (D8). No test row for the 2 flags together. |
| The other answers (`--as` over an unmanaged entry, `X@sel` filters, the nearest move, stale keys, path entries) | They are for commands that edit a header. `list`, `default` and `remove` edit no project file, so none binds this slice. |

## 8. Out of scope

| Id | Reason |
| --- | --- |
| R-R12, R-R13, R-R4, R-LK1 to R-LK4 | Slice 024b (`roc link`) |
| R-R5, last sentence (`roc default --git Karakatiza666/roc@my-branch` picks the newest installed build of that branch) | Slice 045: it needs the `.talon.json` of a git build (R-R1: the repo, the sha, the ref) |
| `roc default @-N`, `@+N` | Question Q4 (the base is not set) |
| R-SO18 for `roc list` | The warning is for the project commands (slice 022) |
| The Windows rule of R-CC10 (the `rename` of a running compiler fails, exit 17) | The Windows CI job |
| `tln roc rm` while a build of another process runs the compiler | No stable L2 or L3 test (the real lock is tested by slices 002 and 021) |
| R-GC5 (GC keeps the default and the pinned compilers) | Slice 028 |

## 9. Questions (TW17)

The reference has a default for each question, and no test fixes it unless the table says so.

| # | Question | Default of the reference | Other option |
| --- | --- | --- | --- |
| Q1 | `tln roc list` with an operand (`tln roc ls nightly-2026`): an error, or a filter? The design has no text for it (R-CM9 says `tln list` takes no name). | Error: `tln roc list takes no operand, got <n>`, exit 2 (L0 `read` pins the text only) | A filter by prefix |
| Q2 | `tln roc remove` of a compiler that an install holds (the lock is busy): R-CC10 says GC skips it, and says nothing for `roc rm`. | Answered in the review: `Wait` (D10). Tested: L2 `rm1-remove` run 8 (`fx/locks`). | |
| Q3 | Does a `.roc-version` that names the compiler, or a `talon.toml` range that only it fits, count as "a known project pins the compiler" (R-RR2)? | Only the `roc:` entry of the header (D5) | The 3 forms |
| Q4 | `roc default @-1`, `@+1`: R-SL7 says "the compiler that Resolution 13 selects in the current directory", and R-PD16 says the target file of the proxy. A `tln roc` command has no target file. | `base: Err(None)`: `NoBase`, exit 18, as `roc install` (slice 021 D3). Not tested. | The default compiler as the base |
| Q5 | The R-RR1 move: when the removed default is a `git-`, `link-` or `copy-` build, does the default move too? | Yes (the rule says "if the compiler is the global default") | Unset |
| Q6 | `tln roc remove` of the only installed compiler of a project that is open now (R-RR2 says the proxy downloads it again). No prompt, as the rule says. Should `--json` list the projects when none is known? | `projects: []` | |

## 10. Design gaps found

| # | Gap |
| --- | --- |
| G1 | R-SC5 says the scope of `tln roc ...` is "installed compiler releases", and R-SC10 says the argument is expanded to the full id. For `roc install` the domain is the online list (slice 021). For `default` it must be both (D1), and the design does not say so. |
| G2 | R-RR1 says "the newest installed nightly or release that the `nightly` switch allows". It does not say how a release and a nightly are ordered. `Pin.order` puts a nightly after a release with no date (it has no day), so the newest is always a nightly when the switch is on. |
| G3 | R-GC3 and R-RR1 to R-RR3 do not say that `tln roc rm` removes the compat dir. Only R-GC3 does, in the column of GC. |
| G4 | R-FL12 has no row for `--copy` (024b). It lists `--force` for `roc link --copy`. |

## 11. Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| `Toml.insert` puts the new key right after the last top-level key, before a comment that follows it | The L0 row for an inserted key has no comment between the last key and the first table |
| A name of `$HOME2` in an expected file: the normalizer of the runners changes the prefix `<work dir>/home` first | `ls1-list` run 3 and 4 show `$HOME2` and `$HOME3` in `calls.log` |

## 12. Red output

`scripts/test.sh` with the stubs (2026-10-23). The old tests all pass.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt | pass | The stubs compile. `roc fmt --check` passes. |
| L0 old files (55 files) | pass | |
| L0 `tests/unit/manage.roc` | red: 11 of 11 `expect`s fail | `Roc application crashed with this message: todo` |
| L2 old cases (45) | pass | |
| L2 `roc/ls1-list`, `roc/df1-default`, `roc/rm1-remove` | red | `[ROC CRASHED] todo` at the first run (the test app writes no exit file) |
| L3 old cases (38, 1 skipped) | pass | |
| L3 `compilers/mg1-manage` | red | `[ROC CRASHED] todo` for each `tln roc` command, `exit 1`, and the tree shows no removal and no edit |
| selftest | pass | |

```text
tests/unit/manage.roc: FAILED   (11 failed: Roc application crashed with this message: todo)
FAIL roc/ls1-list      the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL roc/df1-default   the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL roc/rm1-remove    the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL compilers/mg1-manage   stdout differs: +[ROC CRASHED] todo (x14), exit 0 against exit 1
```

Times on the stub tree: check 1.1 s, l0 4.4 s, l2 1.2 s, l3 9.2 s, selftest 4.4 s. With the reference: check 1.1 s, l0 4.5 s, l2 1.4 s, l3 9.2 s, selftest 4.1 s, no `WARN` line.

## 13. Check against the design (TW21)

The expected files of the 3 L2 cases and the L3 case were made by a private reference (`research/slice-024-revert/reference/`, deleted after the review) and read by eye against the design. With the reference all 11 `expect`s, the 3 L2 cases and the L3 case pass. The reference was deleted after the review (the manager's answer).

Revert check (TW12), on the reference: see `research/slice-024-revert/results.md` (script `mutate.py`, filtered runs).

## 14. Verify results

Test agent, on the private reference (`research/slice-024-revert/mutate.py`, table in `results.md`): 29 small mutations, run with the filtered tests only (the L0 file, the 3 L2 cases, the L3 case). All 29 are caught (27 at first, M28 after the review), each by the layers that the table names. 7 mutations did not compile or did not apply the first time (a constant condition, an unused variable, a changed text), so they were written again.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `kind_of`, `rows` (the other tag form), `Manage.read` text (the long form) | M01, M02, M15 | L0 (M15 also L2) |
| `ls_report`, `ls_data` (the star, `-`, the `last_use` field) | M03, M04, M05 | L0, L2 (M03 also L3) |
| `default_set` (same value, replace), `default_unset` (wrong key) | M06, M07, M08 | L0 (M06 also L2, M08 also L3) |
| `next_default` (git build allowed, the switch, the oldest) | M09, M10, M11 | L0, L2, L3 |
| `next_default` ignores the date of a release (review) | M29 | L0 |
| `pinned_by` (the other tag form), `compat_of`, `trash_name`, the project text | M12, M13, M14, M16 | L0, L2 (M13 and M16 also L3) |
| `RocManage.remove_flow!`: no compat dir, no lock, `NoWait` in place of `Wait` (review), no default move, the switch not read, no project files read | M17, M18, M28, M19, M22, M24 | L2 (M17, M19, M22, M24 also L3) |
| `RocManage.default_flow!`: no installed-first pick, a decline ignored, an ambiguous prefix as another failure, the second read of `config.toml` | M20, M21, M23, M26 | L2 |
| `list_flow!`: the `.last-use` path | M25 | L2 |
| `Run` dispatch for `roc list` | M27 | L2, L3 |

`scripts/test.sh` with the reference: exit 0, no `WARN`. With the stubs: only the new tests fail (section 12).

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The doc table of `RocManage` has the order of the calls. The `calls.log` of the 3 L2 cases fixes them, including the number of `read_files!` calls. |
| N2 | `RocManage` calls `Launch.toolchains!`, `Install.failed!`, `Install.shown_fx`, `Install.nightly_of`, `RocInstall.offer!` and `RocInstall.install_offer!`, `Consent.roc_install` and `roc_install_declined`, `Toolchain.report` (only the `stderr` lines, for the compat warning of a download), `Intent.read_config`, `Projects.entries`, `Locked.read`, `Compiler.times`, `Pin.switch`, `Pin.order`, `Pin.same_id`, `Temp.hex`. A local helper must not have the name of a method of its type module (slice 020 limit). |
| N3 | A failed `Fx.delete!` after the rename is ignored (the trash dir is stale and GC removes it, R-CC2). |
| N4 | Do not edit a test (TW18). A question goes to the manager. |

## Review (manager, 2026-10-23)

The split is accepted: 024 is `roc ls`, `default`, `rm`, and 024b is `link` and `link --copy` (the manager updates PLAN-P1.md). No further cut. D1 to D11 and the proposals of section 6 are accepted.

| Item | Answer | Change in the tests |
| --- | --- | --- |
| Q1 | Error, exit 2 (as `tln list`) | None (the default of the reference) |
| Q2 | `roc rm` is an explicit command, so it waits for the item lock as `roc install` does (the `waiting for another tln` line, the same lock code), then removes. GC skips because it runs by itself. | L2 `rm1-remove`: `fx/locks` has a busy row for `link-dev`. Run 8 shows `lock ... nowait: busy`, the `waiting for another tln: link-dev` line on stderr, `lock ... wait: held`. D10 changed. M28 (`Wait` to `NoWait`) is caught by L2. |
| Q3 | Only the header `roc:` entry (D5) | None |
| Q4 | `NoBase`, exit 18 (as slice 021 D3) | None |
| Q5 | Yes, the default moves | None |
| Q6 | `projects: []` | None |
| G1 | D1 accepted | None |
| G2 | The order is the rule of rank 4 selection: `Pin.order` with the `published_at` of `.talon.json` (slice 022), so a release with a date is ordered by its date | L0 `next_default`: 2 new rows with a release `0.1.0` that has a date in `times`: newer than the nightlies it is chosen, older it is not. M29 (`times` ignored) is caught. |
| G3 | D6 accepted | None |
| G4 | Goes to 024b | None |

The private reference was updated (all tests passed with it: `scripts/test.sh` exit 0), then deleted with `research/slice-024-revert/reference/`. `before/`, `mk-fixtures.py`, `mutate.py` and `results.md` stay. Red state: only the new tests fail (section 12: 11 L0 `expect`s, the 3 L2 cases, the L3 case; the old tests pass).

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `RocInstall.read_text!`, `read_config!` and `ask_download!` are public methods now (they were private functions, with no change in body). `RocManage` calls them. The calls in `RocInstall` are `RocInstall.<name>`. No signature changed. | A copy of the 3 functions in `RocManage` |
| C2 | `RocManage.edit_config!` takes a pure `decide : Str -> Try({ previous, edit }, Fail)` and has the lock, the read, the second read (R-CC7) and the write once. `default` passes `Manage.default_set`, `remove` passes `Manage.default_set` or `Manage.default_unset`. `RocInstall.edit_config!` stays: its decision type is `Keep`/`Set`. | One shared function for both modules (it would change `RocInstall`) |
| C3 | `roc default <text>` with a text that starts with `@` goes to `RocInstall.offer!` at once (no `Nightlies.pick` over the installed ids). `@latest` names the online list (R-SL5). | A pick over the installed ids for `@latest` (it would give the newest installed, not the newest online) |
| C4 | A `rename!` that fails in `remove` (also `NotFound`) is a failure of kind `Environment`: `cannot remove <item>: <error>`. A failed `delete!` after the rename is ignored (N3). | `NotFound` as success |
| C5 | `list` prints the table (or the envelope), then the warning on stderr. | The warning first |

## Code result

| Item | Value |
| --- | --- |
| `scripts/test.sh` | exit 0. check 1.2 s, fmt 0.1 s, l0 all files pass (`manage.roc`: 11 of 11) 4.8 s, l2 48 passed 3.3 s, l3 39 passed 1 skipped 9.3 s, selftest pass 4.8 s. `OPT=speed`: exit 0 (l2 72 s: LLVM build, no WARN for speed). |
| Files | `cli/lib/Manage.roc` 360, `cli/lib/RocManage.roc` 324, `cli/lib/RocInstall.roc` 359 (3 methods made public, C1) |
| Signatures | No public signature of the slice changed. New public: `RocInstall.read_text!`, `RocInstall.read_config!`, `RocInstall.ask_download!` (C1). |

## Verify results (code agent, TW12)

34 small mutations (`research/slice-024-revert/code-mutate.py`, `code-results.md`, a copy of the final code in `code-final/` that is restored before each mutation). Caught 33 of 34. After the run the 4 files are the same as `code-final/` (SAME).

| Group | Mutations | Result |
| --- | --- | --- |
| `kind_of`, `rows`, `ls_report`, `ls_data`, `default_set`, `default_unset`, `next_default`, `pinned_by`, `compat_of`, `trash_name`, `read`, `read_list`, the texts | K01 to K20 | caught by L0 `manage` |
| `RocManage`: compat dir, item lock `Wait`, default move, `nightly` switch, installed-first pick, decline, ambiguous prefix, project files, second read, `.last-use` path, the `installed` flag, one `read_files!` call with no path, the `Run` dispatch | K21 to K31, K33, K34 | caught by L2 |
| `remove_flow!`: `was_default` by `Pin.same_id` (K32) | K32 | not caught |

| Not caught | Test gap |
| --- | --- |
| K32: `RocManage.remove_flow!` decides `was_default` with `default == id` in place of `Pin.same_id(default, id)` | No L2 or L3 row removes a default that `config.toml` stores in the other tag form of the nightly (`nightly-2026-October-14-38a3029`). The L0 rows of `rows` test `Pin.same_id` for the table, not for `remove`. |

Questions (TW17) for the manager:

| # | Question | Default of the code |
| --- | --- | --- |
| Q7 | `roc default <id>` downloads a compiler, and `config.toml` has no `default-roc`. `RocInstall.install_offer!` writes the first default (R-SO15), so `Manage.default_set` finds the same value: the text is `installed <id>` and `<id> is already the default compiler`, and `--json` has `changed: false`. Is that the output that the design wants? No test has this case (`df1-default` run 9 has a default already). | Answered by the manager (test step after the code): `changed` and the text describe the whole command, compared with the state before it. So when the download writes the first default, the text is `installed <id>` and `<id> is now the default compiler`, and `--json` has `previous: null` and `changed: true`. Tested: L2 `df1-default` runs 12 (text, `HOME` is `home2`) and 13 (`--json`, `home3`). They fail until the code agent changes it. The calls stay as they are today (no new call: `install_offer!` already gives `done.default`, `Set` for the first default). |

## Test additions after the code (test agent, 2026-10-23)

| Item | Test | Check |
| --- | --- | --- |
| Gap K32 (`was_default` by `==` in place of `Pin.same_id`) | L2 `rm1-remove`: `config.toml` stores the default as `nightly-2026-October-14-38a3029`, and run 6 removes `nightly-2026-10-14-38a3029` | K32 applied by hand: `rm1-remove` fails (the default does not move, the line `the default compiler is now ...` is missing). The 4 files were put back and are the same as `code-final/` (`cmp`). L3 does not catch it. |
| Q7 | L2 `df1-default` runs 12 and 13 (`home2`, `home3`: no `config.toml`; `fx/answers` has one more line, `fx/platform` more rows, `fx/jobs` 2 compat rules) | Text `installed <id>` then `is now the default compiler`, `--json` `previous: null`, `changed: true`. Red on the code of today: it prints `is already the default compiler`, `previous` is the id, `changed` is false. |

`mk-fixtures.py` writes the new `given/` and `fx/` files (and `fx/locks` of `rm1-remove`, which it had lost). The expected files of the old runs did not change, except the `-default-roc` line of the `tree.diff` of `rm1-remove`.

## Q7 fix (code agent)

| Item | Value |
| --- | --- |
| Change | `cli/lib/RocManage.roc` (`default_flow!`, `download!`, `fetched!`): `RocInstall.install_offer!` gives `default: Set` when it wrote the first default. Then the result of the command is `previous: Err(Unset)`, `changed: true`, so the text is `installed <id>` and `<id> is now the default compiler`, and `--json` has `previous: null`, `changed: true`. No new call. |
| Tests | `scripts/test.sh` exit 0, no WARN (l2 48 passed, with `df1-default` runs 12 and 13 and the K32 row of `rm1-remove`). No test changed. |
| Mutation | K35 (`first_default: Bool.False`): caught by L2. K32 is caught by the new `rm1-remove` row (test agent). `code-final/` is refreshed and the files are the same after the run (SAME). |

## Close (manager, 2026-10-23)

C1 to C5 of the code agent are accepted. Q7 is answered and fixed; K32 and K35 are caught. `scripts/test.sh` exits 0 with no WARN. Status: done.
