# 072a The first default compiler, written by `tln setup`

Phase: P1. Status: done

Slice 072a is the first half of the plan row 072 of `PLAN-P1.md` (section 2c). The user words: "During the first installation Talon automatically selects the latest version of Roc as default ... Then the selected nightly can be downloaded when needed." The second half (a command with no compiler selected, R-SO14) is slice 072b.

R-ST16 (design agent, 2026-10-25): when `config.toml` has no `default-roc`, `tln setup` writes it. The value is the latest compiler in the channel: the newest release that the `nightly` switch and `min-release-age` allow (R-RU1). Setup downloads no compiler. It reads the compiler list once. A list that cannot be read gives a note and no failure. A `default-roc` that is set is never changed. This is a user act for R-SO15.

## 1. Rules

| Rule | Content | Tested by |
| --- | --- | --- |
| R-ST16 | The step above | L0 `Toolchain.latest`, L2 `setup/st8-first-default`, 5 changed L2 cases, L3 `setup/st1-setup-real` |
| R-SO15 (part) | `tln setup` is a user act that sets the default when none is set | `st8-first-default` runs 3 and 5 |
| R-IS6 (part) | `tln setup` applies R-ST16 after R-ST1 to R-ST6 | the same |
| R-RU1, R-C7, R-NS3 (as used) | "Latest" is the newest release that the switch and `min-release-age` allow. The age of `config.toml` is used (a user key), else 2 days | L0 `Toolchain.latest`, `st8-first-default` runs 3 and 5 |
| R-CV1 (as used) | The list is read once, with the cache of R-DI2 | `st8-first-default` run 3 (one `http_get`) |
| R-DI12 (as used) | `--offline` with no cached page: `Missing`, so no list | `st8-first-default` run 1 |

## 2. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `Toolchain.latest` | The body: the last id of `Toolchain.domain(facts).auto`, or `Err(Empty)`. Stub: `crash`. Slice 072b uses it too |
| 2 | `RocInstall.latest!` | New. Stub: `crash`. The calls are in its doc: `clock!` (one call), `platform!` (a host with no asset: `Unread`, no list call), the calls of `Nightlies.list!`. Then `Toolchain.latest` |
| 3 | `SetupFlow.default_step!` | New step 13 (after the writes of step 10 and the completion). Stub: gives `Kept("")` (no call, no line: the old behavior). The table is in the doc comment above the function |
| 4 | `SetupFlow.flow!` | Calls `default_step!` after the completion write, and puts the result in `done.default` |
| 5 | `SetupText` | New type `Default`, new field `Done.default`, new `unread_note`. `report` and `data` use the field (stubs ignore it) |

The unchanged parts: the prompts (before any write and any lock, R-CC3 point 5), the entries, the PATH step, the `talon` entry. Setup writes the default last, so a run that fails earlier (exit 17, 18, 19) never reaches the step and its `calls.log` does not change.

The private reference (3 functions and 2 stubs: about 60 lines; kept in `research/slice-072-revert/reference/` until the review) makes all new tests pass.

## 3. Public signatures

| Name | Signature | State |
| --- | --- | --- |
| `Toolchain.latest` | `{ releases : List(Nightlies.Release), now : U64, min_age : U64, nightly : Bool } -> Try(Str, [Empty])` | stub (`crash "todo: slice 072a"`) |
| `RocInstall.latest!` | `Fx, { env : List((Str, Str)), offline : Bool, config : ConfigToml.Config } => Try(Try(Str, [Unread(Str)]), Fail)` | stub (`crash`) |
| `SetupText.Default` | `[Set(Str), Kept(Str), Unread(Str)]` | done (type) |
| `SetupText.Done.default` | `SetupText.Default` | done (field) |
| `SetupText.unread_note` | `Str -> Str` | stub (`crash`) |
| `SetupFlow.default_step!` (private) | `Fx, Args, Facts => Try(SetupText.Default, Fail)` | stub: `Ok(Kept(""))` |

## 4. The tested reading

| # | Topic | Reading |
| --- | --- | --- |
| 1 | The step | Step 13a: `RocInstall.read_config!` (one `read_files!` of `config.toml`; a missing file is the empty text). `default-roc` set: `Kept(id)`, no more call, no line, also with `--json` (`data.default_roc.action` is `kept`) |
| 2 | The list | Step 13b: `RocInstall.latest!`. `clock`, `platform`, then the list calls of `Nightlies.list!` (`list_dirs` of the index dir, `programs gh`, `http_get`, `write_atomic` of the page, `db_query`, `db_write`: slice 030b). It makes no `list_dirs` of `toolchains` and no `read_files` of `config.toml` (the config of 13a is passed in) |
| 3 | The write | Step 13c: `RocInstall.first_default!`: `lock`, 2 `read_files`, `write_atomic`, `unlock` of `config.toml`. The text of the file keeps its other keys, and `default-roc` is the last line |
| 4 | No download | No `spawn_all`, no `make_dirs`, no `toolchains/` dir, no `Prompt`, no `ask`. Setup never asks for consent for the default (R-ST16) |
| 5 | An unreadable list | `Unread(why)`: a failure of `Nightlies.list!` (the text is its message), and `--offline` with no cached page (the text of `Toolchain.offline_no_list`). One line on stderr, `SetupText.unread_note(why)`. Exit 0. No write. `--quiet` does not hide it (as the other warnings of setup) |
| 6 | The age | `min-release-age` is the key of `config.toml`, else 2 days. The switch is `TALON_NIGHTLY`, else the key `nightly` of `config.toml`, else true (`Pin.switch`, as `RocInstall.offer!`). There is no `talon.toml` (setup has no project) |
| 7 | The first run | The first run of a machine has no `config.toml`, so `read_files` gives the empty text and the write makes the file (the lock makes its dir) |

## 5. Tests

| Layer | Case | Checks | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/ToolchainTest.roc` (driver `l0-8.roc`), new expect: `Toolchain.latest`, 6 rows | the last visible id: the 2 day age, a release 1 second too young, age 0, a very old list (only the oldest is old enough), a nightly with no asset or 2 assets is no candidate, a list of one too young release, an empty list, the switch off | R-ST16, R-RU1, R-NS3, R-C7, R-SO14 |
| L2 | `tests/commands/cases/setup/st8-first-default` (new, 7 runs) | run 1 `setup --offline --json` (no list: note, `data.default_roc` is `unread`, exit 0, entries made). Run 2: the list call gets a 404: the same note. Run 3: the list is read, `min-release-age = "1d"` in `config.toml` (36 hours old nightly is visible): the default is written, the key stays, no download, one line. Run 4: the default is set: one read, no list, no line. Run 5: another home with no config: the 2 day age hides the 36 hours old nightly, so the older one is the default (the stdout line). Run 6 (manager review): `TALON_NIGHTLY=false` in a new home: the list is read, no release is allowed, so the note (the text names the switch and min-release-age), exit 0, no default (a flow that ignores the switch writes one). Run 7 (manager answer Q2): the second `platform!` call says `os=freebsd` (`fx/platform`, 13 rows): the note has `no compiler asset exists for freebsd x64`, exit 0, no default, no list call | R-ST16, R-SO15, R-RU1, R-C7, R-CV1, R-NS3, R-IS6, R-J3, R-OUT4 |
| L2 | `setup/st1-flow`, `st2-copy-fallback`, `st3-gaps`, `st5-talon-entry`, `st6-talon-in-file` | each home gets a `config.toml` with `default-roc` (so these cases keep their meaning, and no list is read). `calls.log`: one `read_files config.toml` at the end of each run that reaches step 13 (12 + 2 + 1 + 3 + 1 lines). `stdout`: in `st1-flow` (2 runs) and `st5-talon-entry` (1 run) the `--json` data has `default_roc` with the action `kept` | R-ST16, R-J3 |
| L2 | `setup/st4-no-tln`, `st7-talon-bad` | no change: the run fails before step 13 | |
| L3 | `tests/scenarios/setup/st1-setup-real` | the given home gets a `config.toml` with `default-roc`: no list is read (the case has no fake HTTP server). No expected file changes | R-ST16 |

Counts: 1 new L0 expect (6 rows), 1 new L2 case (7 runs), 5 changed L2 cases (`calls.log` 5 files, `stdout` 2 files, 5 new `given` files), 1 changed L3 case (1 new given file, 2 comment lines). The old copies are in `research/slice-072-revert/before/` (`NEW.txt` lists the new files).

## 6. Output (proposed, R-OUT2, TW24)

| Item | Text |
| --- | --- |
| stdout, `Set(id)` | `default compiler: <id> (downloaded when a command needs it)` |
| stdout, `Kept`, `Unread` | no line |
| stderr, `Unread(why)` | `note: no default compiler was set, because the list of compilers cannot be read (<why>). The first command that needs a compiler picks one.` |
| `--json` `data.default_roc` | an object with `action` (`set`, `kept`, `unread`) and `id` (the id, or null for `unread`). It is the last key of `data` |

## 7. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | The step is the last one of setup (after the entries, the PATH line and the completion). A run that fails before it writes no default | The step first: a failure of the list or of the lock would stop setup before the entries |
| D2 | Setup passes the config that step 13a read to `RocInstall.latest!` (no second read) | `RocInstall.offer!`: it reads `config.toml` and `toolchains/` again, and requires a digest and a download size that setup does not need |
| D3 | Any failure of `Nightlies.list!` is `Unread` (no network, a rate limit, a bad page). The note shows the text | Only a failure of kind `Network`: R-ST16 says "cannot be read" without a kind |
| D4 | The note is on stderr, with no `--quiet` effect | A line on stdout |
| D5 | `Kept(id)` shows no line, but `--json` shows it | No `default_roc` key when the default was kept |
| D6 | The 5 old cases get a `config.toml` with a default | No config: each run would read the list and print the note, and the 5 cases would test another thing |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| R-SO14 (a command that needs a compiler and none is selected) | Slice 072b |
| The switch of the flow (`TALON_NIGHTLY=false` or `nightly = false` in `config.toml`) | The result of a list with no allowed release is question Q1. L0 `Toolchain.latest` has the row with the switch off. No L2 run shows that `RocInstall.latest!` passes the switch |
| R-IS6 text about the `talon` entry | Slice 063 (done) |
| An L3 case with a fake HTTP server for `tln setup` | The L2 case shows the calls. The real Fx is tested by the cases of `tln roc install`, which use the same `Nightlies.list!` |

## 9. Questions (TW17) and manager answers (2026-10-25)

| Id | Manager answer |
| --- | --- |
| Q1 | Accepted: no allowed release is handled like an unreadable list (note, exit 0, no default) |
| Q2 | Not exit 18. R-ST16 says that setup does not fail on the first default. A host with no asset gives a note on stderr, exit 0, no default |
| Gap | The `nightly` switch is named by the design for "latest in the channel": run 6 of `st8-first-default` catches a flow that ignores it |

| Id | Question | Options | Default in the tests |
| --- | --- | --- | --- |
| Q1 | ANSWERED (a), `st8-first-default` run 6 (switch off). The list is read and no release is allowed (all are younger than `min-release-age`, the switch is off, or the list is empty). R-ST16 gives a rule for "cannot be read" only | (a) The same as an unreadable list: the note, no failure (the reference does this, and no test fixes it). (b) A failure with exit 10 (R-NS2). (c) No note, no default | no test. The doc of `RocInstall.latest!` says (a) |
| Q2 | The host has no compiler asset (`Toolchain.host` fails: for example FreeBSD): is it `Unread` too? | (a) Yes (setup never fails for the default). (b) The failure of `Toolchain.host` (exit 18, as `tln roc install`) | ANSWERED (a), `st8-first-default` run 7 |
| Q3 | Known open (user questions of 2026-10-25, not decided here): `min-release-age` for the "latest" of setup. The text as written is used: R-RU1 (2 days, or the key of `config.toml`) | | `st8-first-default` runs 3 and 5 |

## 10. Compiler and tool limits met

| Id | Limit | Effect | Workaround |
| --- | --- | --- | --- |
| C1 | A warning fails a build (an unused parameter) | the stubs name their parameters `_x` | none needed |
| C2 | An L2 stub that crashes stops the whole test app | `default_step!` is a stub that gives `Kept("")`, not a `crash` | the L0-only stubs (`Toolchain.latest`) crash |
| C3 | `tests/commands/` tree diff shows `home/` and `project/` only | a second home (`home2`) is not in `tree.diff`: run 5 shows its default in the stdout line | |

## 11. Verify results (test agent, 2026-10-25)

Red state (stubs, new tests):

| Step | Result |
| --- | --- |
| check, fmt, selftest, l3 | pass |
| l0 | FAIL: `tests/unit/ToolchainTest.roc:102` (the `Toolchain.latest` expect) crashes with `todo: slice 072a`. All other l0 files pass |
| l2 | FAIL, 6 cases of 172: `setup/st1-flow`, `st2-copy-fallback`, `st3-gaps`, `st5-talon-entry`, `st6-talon-in-file` (a missing `read_files config.toml` line, and in 2 of them the `default_roc` key), `st8-first-default` (no default written, no list read). The log is `research/slice-072-revert/red-run-072a-l2.log` |

After the stubs and tests of slice 072b are added, the count is 9 of 174 L2 cases: these 6 and 3 of slice 072b (see `072b-no-rank-download.md`, section 12).

Private reference (a copy of the tree, `research/slice-072-revert/reference/sandbox`): check, l0, l2 (172 of 172) and l3 pass.

Revert check (7 hand mutations of the reference; every one is caught):

| # | Mutation | Test that failed |
| --- | --- | --- |
| M1 | `default_step!` ignores a set default (runs the list read) | `setup/st1-flow`, `st2-copy-fallback`, `st3-gaps`, `st5-talon-entry`, `st6-talon-in-file`, `st8-first-default` |
| M2 | `Toolchain.latest` takes the first visible id, not the last | L0 `ToolchainTest` expect, L2 `st8-first-default` |
| M3 | `RocInstall.latest!` uses 2 days and not the key of `config.toml` | `st8-first-default` (run 3) |
| M3b | the default age is 0, not 2 days | `st8-first-default` (run 5) |
| M4 | an unreadable list is a failure | `st8-first-default` |
| M5 | `--offline` is inverted | `st8-first-default` |
| M6 | `Missing` is a failure | `st8-first-default` |

M7 (manager review): `RocInstall.latest!` ignores the switch (`nightly: switch.nightly or Bool.True`): `st8-first-default` (run 6).

## 12. Verify results (code agent, 2026-10-25)

`scripts/test.sh`: check, fmt, l0, l2 (174 of 174), l3, selftest and l1 pass.

| # | Mutation | Test that failed |
| --- | --- | --- |
| M1 | `Toolchain.latest` takes the first id | L0 `ToolchainTest` (`l0-8`) |
| M2 | `default_step!` ignores a set default (reads the list) | L2 `setup/st6-talon-in-file`, `st8-first-default` |
| M3 | `RocInstall.latest!` ignores the switch | L2 `setup/st8-first-default` |

Decision of the code agent: `default_step!` gives `Kept(id)` when `first_default!` finds a default that another process wrote (a race). Rejected: `Set(id)`, because the file keeps the other value.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-072-revert/code-final.sha256` | All files OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run) | Exit 0, all 7 steps, 174 L2 cases |
| Gap step | Skipped: 9 of 9 code-agent mutations caught (17 with the test agent's) |
| Follow-up | `NoRank.offer!` prints no R-CV6 warning for a changed tag sha256. R-CV6 is a trust rule, so slice 072c adds it with a test. |
