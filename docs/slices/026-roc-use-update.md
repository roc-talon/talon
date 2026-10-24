# 026 tln roc update, and the base of a relative step (026a)

Phase: P1. Status: done

Slice 026 of `docs/slices/PLAN-P1.md` is `tln roc use` and `tln roc update`. It is too large for one slice (TW19: the ladder and baseline check, the pin edit for each member, the workspace, and the update). This file splits it. Part 026a is tested here. Part 026b (`roc use`) is an outline only (section 2).

## 0. The split

| Part | Content | State |
| --- | --- | --- |
| 026a | `tln roc update` (R-RU1 to R-RU4). The base of `@+N` and `@-N` for `roc install` and `roc default` (slice 024 Q4, R-PD16). G2 of slice 024b (the second form of `Pin.toolchain_note`). | Tests written, this file |
| 026b | `tln roc use` (R-CS1, R-U1 to R-U6, R-WS13, R-RP1 `roc use`, R-PH8 `roc use`) | Outline in section 2. Next slice. |

Why this order: `roc update` needs no ladder and no header edit. The base needs the same selection code that `roc use` needs (a `@-1` for `roc use` has the same base). The note of G2 only names `roc use` as the command that is not allowed for a link, copy or git id.

## 1. Rules of 026a

| Id | Rule (short) | Where | Tested by |
| --- | --- | --- | --- |
| R-CS3 | `tln roc update` takes no operand | `Manage.read_update` | L0 `manage`. L2 `up1` run 9. L3 `ru1` step 8 |
| R-RU1 | `roc update` is `roc install @latest` plus the default move. When the newest is installed already, nothing is downloaded, the first line is `<id> is the newest`, and the default is still decided (R-RU2) | `RocManage.update!` | L2 `up1` runs 1 to 3, 11 to 13. L3 `ru1` steps 1 to 4 |
| R-RU2 | The default moves when it is unset, a nightly or a release. It stays when it is a git, link or copy build, and a note says how to change it | `Manage.update_move` | L0 `manage`. L2 `up1` runs 1, 4, 5, 11 to 13. L3 `ru1` steps 1, 3, 6 |
| R-RU3 | No check, no project file is written. A project `roc:` pin stays | `RocManage.update!` | L2 `up1` run 1 (tree.diff of `project`). L3 `ru1` step 5 |
| R-RU4 | Older compilers stay installed | `RocManage.update!` | L2 `up1` run 1. L3 `ru1` step 1 |
| R-SL7, R-PD16 | The base of `@+N` and `@-N` is the compiler that Resolution 13 selects for `main.roc` of the current directory | `Base.selected!`, `RocInstall.offer!`, `Toolchain.needs_base` | L0 `toolchain`. L2 `bs1`, `bs2`, `bs3`. L3 `bs1-base-ranks` |
| R-SO2 to R-SO6, R-SO14, R-NS1, R-TF5 | The ranks that give the base: ROC_TOOLCHAIN (2), header pin (3), range (4), `.roc-version` (5, only with no `talon.toml`), default (6), `roc` on PATH (7). No compiler: exit 18 | `Base.selected!` | L2 `bs1`, `bs2`, `bs3`. L3 `bs1-base-ranks` |
| R-DL3, R-DL4, R-DL5, R-DL10, R-NI6 | The command names the download: Enter is yes, no person starts the download, `n` is exit 13. `TALON_AUTO_INSTALL=no` does not refuse (answer Q2) | `RocManage.update!` (calls `RocInstall.download!`) | L2 `up1` runs 1, 4, 10, 14 |
| R-C7, R-NS2, R-NS3, R-DI12, R-SO15 | `min-release-age`, the nightly switch, `--offline`, the first compiler is the default | `RocInstall.download!` (unchanged) | L2 `up1` runs 3, 5, 6, 7, 8. L3 `ru1` steps 1, 7, 8 |
| R-J3, R-OUT4 | `--json`: stdout is only the envelope | `Manage.update_data` | L0 `manage`. L2 `up1` run 5. L3 `ru1` step 4 |
| R-CM19 | The alias `up` | `Args.parse` (already accepted) | L0 `args`. L2 `up1` run 3. L3 `ru1` step 2 |
| G2 of 024b | `Pin.toolchain_note` has a second form for a link, copy or git id | `Pin.toolchain_note` | L0 `pin`. L2 `ladder/ld-no-check-refuse` run 9 |

`MISSING=1 scripts/rules.sh R-CS3 R-RU R-SL7 R-PD16 R-NS1 R-SO` lists no id of this table.

## 2. Outline of 026b (not tested)

| Part | Rules | Note |
| --- | --- | --- |
| Refuse `git-`, `link-`, `copy-` ids | R-U1 | Use the text of the second form of `Pin.toolchain_note` |
| `--no-check` is an error | R-U4 | |
| A `[toolchain] roc` range or the nightly switch refuses the id. No `talon.toml` edit | R-U5 | |
| A missing nightly is a required download, in the same prompt as the baseline compiler | R-U2, R-U3, R-NI5 | |
| Baseline check with the old pin, then the ladder, then the pin edit | R-U3, R-RP1 | Reuse `Ladder` and `Pin.decide` |
| Each workspace member gets the same `roc:` entry | R-CS1, R-WS13 | Questions Q4, Q5 |
| A note when an argument or `ROC_TOOLCHAIN` has higher priority than the new pin | R-U6 | Same note as `Pin.toolchain_note` |
| `@+N` and `@-N` as the operand | R-SL7 | Needs `Base.selected!` of 026a |

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Manage.roc` | +33 | Stub | `read_update`, `update_move`, `update_report`, `update_data` (types, doc tables, `crash "todo"`) |
| `cli/lib/Toolchain.roc` | +11 | Stub | `needs_base` (`crash "todo"`) |
| `cli/lib/Base.roc` | 39 (new) | Stub | `selected!` (type, doc with a table of the calls, `crash "todo"`) |
| `cli/lib/RocManage.roc` | +17 | Stub | `update!` (type, `roc update` steps table in the module doc, `crash "todo"`) |
| `cli/lib/RocInstall.roc` | +2 | Test agent | Doc of `offer!` and step 4 name the base. The code keeps the old body (red). |
| `cli/lib/Pin.roc` | +9 | Test agent | The doc of `toolchain_note` has 2 forms. The body keeps the old text (red). |
| `cli/lib/Run.roc` | +2 | Test agent | The branch `["roc", "update"]` calls `RocManage.update!` |
| `cli/lib/main.roc` | +1 | Test agent | Exposes `Base` |
| `tests/unit/manage.roc` | +55 | Test agent | 3 new `expect`s |
| `tests/unit/toolchain.roc` | +23 | Test agent | 1 new `expect` (`needs_base`, 14 rows) |
| `tests/unit/pin.roc` | +24 | Test agent | 1 new `expect` (5 `toolchain_note` rows, 2 `Pin.decide` rows) |
| `tests/unit/args.roc` | +6 | Test agent | 2 accepted rows, 2 failure-message rows (they pass today) |
| `tests/commands/cases/roc/up1-update/` | new, 10 runs | Test agent | L2 |
| `tests/commands/cases/roc/bs1-base/`, `bs2-no-pin/`, `bs3-range/` | new, 8 + 4 + 1 runs | Test agent | L2 |
| `tests/commands/cases/ladder/ld-no-check-refuse/` | +1 run (9) | Test agent | L2, the second form of the note |
| `tests/scenarios/compilers/ru1-update/`, `bs1-base-ranks/` | new, 8 steps + 10 steps and an end state | Test agent | L3 with the fake release server (`mk-nightly.sh`, ARCHIVE=real) |
| `research/slice-026-revert/` | | Test agent | `before/`, `before/NEW.txt`, `FILES`, `bk.sh`, `swap.sh`, `mkstubs.py`, `mutate.py`, `mutate.out`, `stubs/` (the private `reference/` is deleted) |

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Manage.read_update` | `Args -> Try({}, Fail)`. An operand: `tln roc update takes no operand, got <n>` (Usage, exit 2) | R-CS3 |
| `Manage.update_move` | `{ default : Try(Str, [Unset]) } -> [Move, Stay]` | R-RU2 |
| `Manage.update_report` | `{ id : Str, installed : Bool, default : [Set, Moved(Str), Stay(Str), Same], compat : ... } -> { stdout : List(Str), stderr : List(Str) }` | R-RU1, R-RU2 |
| `Manage.update_data` | `{ id, item, installed : Bool, previous : Try(Str, [Unset]), changed : Bool } -> JsonDoc` | R-J3, R-OUT4 |
| `Toolchain.needs_base` | `Str -> Bool`. True only for `@` plus a sign plus digits | R-SL7 |
| `Base.selected!` | `Fx, { env : List((Str, Str)), roots : Roots, installed : List(Str), config : Intent.Config } => Try(Try(Str, [None]), Fail)` | R-PD16, R-SO2 to R-SO14 |
| `RocManage.update!` | `Fx, Args => I32` | R-CS3, R-RU1 to R-RU4 |

## 5. Flow of `roc update` (the calls that the L2 and L3 cases fix)

| Step | Action | Rule |
| --- | --- | --- |
| 1 | `Manage.read_update`: an operand is exit 2 with no Fx call | R-CS3 |
| 2 | Read `config.toml`: the previous default | R-RU2 |
| 3 | `RocInstall.download!` with the text `@latest` (the calls of slice 025: list, consent, install) | R-RU1, R-DL3 |
| 4 | The newest is installed already: nothing is downloaded, the first line is `<id> is the newest`. Go on with step 5 (answer Q1) | R-RU1 |
| 5 | First compiler of the store: it is the default (`Set`). The default text is the id already: `Same`, no write | R-SO15, R-RU2 |
| 6 | Else `Manage.update_move`: `Move` writes `default-roc` (`edit_config!` with `Manage.default_set`), `Stay` prints the note. This holds also when nothing was downloaded | R-RU2 |
| 7 | `Manage.update_report` or, with `--json`, `Manage.update_data` | R-J3 |

Flow of the base (`Base.selected!`, called from `RocInstall.offer!` only when `Toolchain.needs_base`):

| Step | Call | Rule |
| --- | --- | --- |
| 1 | `Compiler.toolchain_of(env)`: ROC_TOOLCHAIN set means no file is read (rank 2) | R-SO2 |
| 2 | `cwd!`, search of `main.roc` (`Project.find_loose!`) | R-TF5 |
| 3 | One `read_files!`: `main.roc`, `talon.toml`, `.roc-version` | R-SO3 to R-SO5 |
| 4 | With a range and installed compilers: one `read_files!` of the `.talon.json` of each (`Compiler.times`) | R-NS1 |
| 5 | The selection with `path: Err(NoCompiler)`. If it gives no installed compiler (or rank 4): `OnPath` (`path_roc!`) and the selection again | R-SO7 |
| 6 | The id is the base. `NoCompiler` and `NoneInRange` are `Err(None)` | R-SO14 |

Import cycle: `Proxy` imports `RocInstall`, so `RocInstall.offer!` cannot call `Proxy` or `Install`. The code that both need goes into leaf modules: `Base` (new) and `OnPath` (the body of `Install.on_path_file!`, which then calls it). The calls are fixed by `expect/calls.log` of `roc/bs1`, `bs2`, `bs3`.

## 6. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `manage.roc`: `read_update` | No operand, the alias, flags, the operand error | R-CS3, R-CM19 |
| L0 | `manage.roc`: `update_move` (7 rows) | Unset, nightly, release move. Git, link, copy stay | R-RU2 |
| L0 | `manage.roc`: `update_report` (10 rows), `update_data` (5 rows) | All texts, compat warnings (shown only for an install), the key order, `changed` differs from `installed` both ways, a move with no install | R-RU1, R-RU2, R-J3 |
| L0 | `toolchain.roc`: `needs_base` (14 rows) | `@+1`, `@-1`, `@-99` are True. `@latest`, `@nightly-...`, ids, `@`, `@+`, `@+x` are False | R-SL7 |
| L0 | `pin.roc`: `toolchain_note` (5 rows), `Pin.decide` (2 rows) | First form for nightly, release. Second form for link, copy, git | G2 of 024b |
| L0 | `args.roc` | `roc update`, `roc up` with the global flags. The flag errors for `--file`, `--allow-downloads` | R-CS3, R-CM19 |
| L2 | `roc/up1-update` (14 runs) | See the list below | R-CS3, R-RU1 to R-RU4, R-NI6, R-DL3, R-DL4, R-C7, R-NS2, R-NS3, R-DI12, R-J3, R-OUT4, R-DL5, R-DL10 |
| L2 | `roc/bs1-base` (8 runs) | `@-1`, `@+1`, `@-2`, `roc default @-1` with a header pin. ROC_TOOLCHAIN (rank 2). `@-99` exit 2. A full id and `@nightly-...` need no base (no read of `main.roc`) | R-SL7, R-PD16, R-SO2, R-SO3, R-CS2 |
| L2 | `roc/bs2-no-pin` (4 runs) | Default is the base (rank 6). No compiler: exit 18. ROC_TOOLCHAIN `git-` is not in the list: exit 2. An installed id as ROC_TOOLCHAIN | R-SO6, R-SO14, R-SO2, R-NS6 |
| L2 | `roc/bs3-range` (2 runs) | A range (rank 4), two nightlies of one day: the `published_at` order, not the tag text, gives the base. Run 2 (home2): no installed compiler in the range, exit 18 (answer Q3) | R-SO4, R-NS1, R-SO14 |
| L2 | `ladder/ld-no-check-refuse` run 9 | `ROC_TOOLCHAIN=link-dev` with a different pin: the second form of the note | G2 of 024b, R-U1 |
| L3 | `compilers/ru1-update` (8 steps) | Real binary and `curl`, `tar`. First install and default. `up` says newest. An older default moves to the newest that is installed already, with no download (step 3, answer Q1). `--json`. A link default stays with the note. `--offline` with no cache exit 15. Switch off exit 10. Operand exit 2. No temp or lock file | R-RU1 to R-RU4, R-CS3, R-CM19, R-DI12, R-NS2 |
| L3 | `compilers/bs1-base-ranks` (10 steps and an end state) | Dirs `pin`, `plain`, `ver`, `vt`, `range`, `none`. `.roc-version` is rank 5 only with no `talon.toml` (`vt` shows it). A bad header. A new store with no default: exit 18 | R-SL7, R-SO2 to R-SO6, R-SO14, R-TF5 |

L2 runs of `up1-update`:

| # | Run | Shows |
| --- | --- | --- |
| 1 | Person, Enter | List, one prompt, install, the default (a nightly) moves. The old compiler and the project pin stay. |
| 2 | Same again | `<id> is the newest`. No lock, no write. |
| 3 | `up --offline` | The cached list gives the same answer, no request |
| 4 | `home2`, CI, link default | No prompt, the download starts. The default stays, the note says how to change it. |
| 5 | `home3`, `--json` | The first compiler is the default. `previous` is null, `changed` true. stdout is only the envelope. |
| 6 | `home4`, `TALON_NOW` 2026-10-19 | `min-release-age` hides the 2 newest. The compat warning is on stderr. |
| 7 | `home5`, `TALON_NIGHTLY=0` | Exit 10, the text names the switch and its source |
| 8 | `home6`, `--offline`, no cache | Exit 15 |
| 9 | An operand | Exit 2, no Fx call |
| 10 | `home7`, answer `n` | Exit 13, nothing downloaded, the default does not change |
| 11 | `home8`, the newest installed, an older nightly is the default | No download. `<id> is the newest`, then the move line. |
| 12 | `home9`, the newest installed, no default, `--json` | The default is set: `installed` false, `previous` null, `changed` true |
| 13 | `home10`, the newest installed, a link build is the default | No download. `<id> is the newest`, then the note. The default stays. |
| 14 | `home11`, `TALON_AUTO_INSTALL=no`, older default | No refusal: the download starts and the default moves (answer Q2) |

## 7. Output (proposal for the review, TW24)

| Case | Text | Stream |
| --- | --- | --- |
| The newest is installed | `<id> is the newest`, then the lines of the default (a move, a set or the note). Only the first line when the default is the newest already | stdout |
| New compiler | `installed <id>` | stdout |
| First default | `<id> is now the default compiler` | stdout |
| Default moved | `the default compiler moved from <old> to <id>` | stdout |
| Default stays (git, link, copy) | `note: the default compiler <d> is a git, link or copy build, so it stays. To change it, run: tln roc default <id>` | stdout |
| Compat id not known | The warning of `Toolchain.report` | stderr |
| Operand | `tln roc update takes no operand, got <n>` | stderr, exit 2 |
| `--json` | `data` has the keys `id`, `path`, `installed`, `previous`, `changed`, in this order | stdout |
| Second form of the pin note | `... A git, link or copy build cannot be a pin, so tln roc use does not take it. Use ROC_TOOLCHAIN or tln roc default for it.` | stderr |

## 8. Decisions that the design does not fix

| Decision | Chosen | Rejected |
| --- | --- | --- |
| Split of slice 026 | 026a update and base, 026b use | One slice (TW19). Update and use together with no base. |
| Where the base code lives | New leaf modules `Base`, `OnPath` | `RocInstall` imports `Proxy` (import cycle). A copy of the proxy steps in `RocInstall`. |
| Base for `@+0` | Not tested (the design is silent) | `@+0` is the base itself. `@+0` is a usage error. |
| `update` with a Stay default | Install, keep the default, print the note | Move the default too. Refuse. |
| `update` prints for a newest that is installed | `<id> is the newest`, then the default lines, exit 0 | Print nothing. |
| `.roc-version` with a `talon.toml` that has no range | Not rank 5 (R-SO5, R-PD6) | Always rank 5 (tested by `vt`) |
| The base when the range has no installed compiler | `Err(None)`, exit 18 (Q3) | Download first, then base |

## 9. Questions (TW17)

| # | Question | State |
| --- | --- | --- |
| Q1 to Q3, Q6 | Answered in the review (section 15) | Closed |
| Q4 | `roc use` prompt: the baseline compiler and the new nightly are in one prompt (R-U3, R-DL1). Does the prompt list both ids? | 026b |
| Q5 | `roc use` in a workspace: one check for the whole workspace, or one for each member (R-WS13, R-WS4)? | 026b |

Design gaps: none new. G2 of 024b is closed by the second form of the note (section 7).

## 10. Out of scope

| Ids | Reason |
| --- | --- |
| R-CS1, R-U1 to R-U6, R-WS13, R-RP1 (`roc use`), R-PH8 (`roc use`) | Slice 026b |
| R-SL7 offline fallback of the list | The step of a relative id with `--offline` and no list is exit 15 as for any list (R-DI12). No new rule. |

## 11. Notes for the code agent

| Topic | Note |
| --- | --- |
| Modules | `Base.roc` and `OnPath.roc` are leaf modules. `OnPath` has the body of `Install.on_path_file!`. `Install.on_path_file!` calls it. Expose both in `cli/lib/main.roc` (`Base` is exposed already). |
| Calls | `expect/calls.log` of `roc/bs1`, `bs2`, `bs3` and `up1` fix the order. `roc/bs1` run 7 and 8 show that no file is read when the operand needs no base. |
| Stubs | The 4 `Manage` functions, `Toolchain.needs_base`, `Base.selected!` and `RocManage.update!` are `crash "todo"`. `RocInstall.offer!` and `Pin.toolchain_note` have the old bodies. |
| Compiler limits | `roc build` exits 2 on a warning. A record with a `Bool` field in an `Err` crashes `roc test`. |

## 12. Red output (stub tree, `scripts/test.sh`)

| Step | Result | Failing |
| --- | --- | --- |
| check, fmt, selftest | pass | none |
| l0 | FAIL | `manage.roc` 3 expects (crash `todo`), `toolchain.roc` 1 (`needs_base`), `pin.roc` 1 (old note). `args.roc` passes. |
| l2 | FAIL, 52 passed, 5 failed | `roc/up1-update` (crash `todo`), `roc/bs1-base`, `roc/bs2-no-pin`, `roc/bs3-range` (old text: no compiler is selected, so a relative step has no start), `ladder/ld-no-check-refuse` (old note) |
| l3 | FAIL, 44 passed, 2 failed, 1 skipped | `compilers/ru1-update`, `compilers/bs1-base-ranks` |

With the private reference tree all steps pass with no WARN (check 5.2, l0 6.4, l2 10.1, l3 9.2, selftest 4.0 seconds). The red output of the stub tree after the review is the same list as above (l2: 52 passed, 5 failed; l3: 44 passed, 2 failed, 1 skipped).

## 13. Revert check (TW12)

`research/slice-026-revert/mutate.py` makes one change at a time in the private reference and runs only the tests that should catch it. Result in `mutate.out`: 29 of 29 changes caught (U1 to U13 for `update`, N2, N3b, N4 for the review change, B1 to B7 and B9 to B11 for the base, N5 for the exit 18 of a range, G1 and G2 for the note). One change is not listed: `changed: edited.changed` to `changed: Bool.True` in the move branch. It is an equal program, because a move that is not `Same` always writes the file. Rounds that changed the tests:

| Gap found | Fix |
| --- | --- |
| `update_data` had no row where `changed` differs from `installed` | A row with `installed` true, `changed` false |
| `Base` without `times` was not caught (nightlies of one day) | New L2 case `roc/bs3-range` |
| The first mutation of the note text hit the doc comment | The mutation text is now the code line |
| Review: a move with no install (`installed` false, `changed` true) and the text of a move with no install | L0 rows, L2 `up1` runs 11 to 13, L3 `ru1` step 3 |

## 14. Status

Verify. The code is written (section 16). The private reference is deleted (review, section 15).

## 15. Review (manager, 2026-10-23)

The split (026a update and base, 026b use) is accepted. The manager also accepts these decisions: the `Base` and `OnPath` leaf modules, the note when the default is a git, link or copy build, `.roc-version` as rank 5 only with no `talon.toml`, no `@+0` test, and the proposals of section 7.

| Question | Answer | Test change |
| --- | --- | --- |
| Q1 | R-CS3 says `roc update` moves the global default to the newest, and R-RU2 says when. R-RU1 "does nothing" is the case where nothing is left to do. When the newest allowed release is installed already and the default is an older nightly or release (or not set), `update` downloads nothing, prints the `<id> is the newest` line, and moves the default with its note (`changed: true`). When the default is the newest already: the `is the newest` line only, `changed: false`. | `manage.roc` rows (`update_report` 3, `update_data` 1). L2 `up1` runs 11 to 13. L3 `ru1` steps 3 and 4. |
| Q2 | `roc update` names its download, so it behaves as `roc install` does today with `TALON_AUTO_INSTALL=no`: the command is the consent (R-DL4). | L2 `up1` run 14 |
| Q3 | Exit 18 is accepted. | L2 `bs3-range` run 2 |
| Q4, Q5 | Go to 026b. | none |
| Q6 | Accepted: no `projects.json` record. | none |

## 16. Code result (code agent)

Result of `scripts/test.sh`: exit 0. check 6.1 s, fmt 0.1 s, l0 6.6 s (255 expects), l2 57 cases passed in 11.8 s, l3 46 cases passed and 1 skipped in 9.3 s, selftest 3.9 s. `OPT=speed scripts/test.sh`: exit 0 (l2 75 s). `roc check`: 0 errors, 0 warnings. `MISSING=1 scripts/rules.sh R-CS3 R-RU R-SL7 R-PD16 R-NS1 R-SO` lists no id.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Base.roc` | 299 | The ranks 2 to 7 and the base. It has what `Proxy` and `RocInstall` share: `Rank`, `Selected`, `select`, `facts`, `choose!`, `find!`, `project_files`, `load!`, `times!`, `in_proxy`, `no_facts`, and `selected!` |
| `cli/lib/OnPath.roc` | 82 (new) | The body of `Install.on_path_file!` (`file!`), with `cached_path` |
| `cli/lib/Proxy.roc` | 286 (was 484) | The shared code moved to `Base`. `Proxy.Rank` is `Base.Rank`. `Proxy.select` and `Proxy.in_proxy` call `Base`. `go!` calls `Base.find!`, `load!`, `facts`, `choose!` |
| `cli/lib/Install.roc` | 174 | `on_path_file!` calls `OnPath.file!` |
| `cli/lib/RocInstall.roc` | 378 | `offer!` calls `Base.selected!` when `Toolchain.needs_base`, between the early `Present` and the list |
| `cli/lib/RocManage.roc` | 393 | `update!`, `update_flow!`, `moved_default!`, `print_update!` |
| `cli/lib/Manage.roc` | 418 | `read_update`, `update_move`, `update_report` (the warning lines are those of `Toolchain.report`), `update_data` |
| `cli/lib/Toolchain.roc` | 416 | `needs_base` (`@` and `Selector.parse` gives `Step`) |
| `cli/lib/Pin.roc` | 446 | The second form of `toolchain_note` (private `local_build`) |
| `cli/lib/main.roc` | | Exposes `OnPath` |

Decisions that the slice does not fix:

| Decision | Chosen | Rejected |
| --- | --- | --- |
| How the base reads files | `Base.load!` has a source: `Read` (the proxy: it reads `config.toml` in the same `read_files!`) or `Given(config)` (the base: the caller has `config.toml`). One function, one call order. | A second loader in `Base` for the base only (a copy). |
| Where `Proxy.select` lives | In `Base`. `Proxy.select` and `Proxy.in_proxy` stay as one-line calls, because `tests/unit/proxy.roc` calls them. | Edit the test. |
| `update` with the default equal to the new id | `Same`, with no lock and no write (run 2 of `up1` has no lock call). The compare is on the text. | Always take the lock. |
| The `Present` result of `update` | Same decision as an install: `default` is decided by `moved_default!` | none |

Disputes (from the code agent): none. No test, fixture or expected file was changed.

Questions (TW17): none. Compiler limits met: a constant `if` condition and an unused variable are warnings (exit 2 of `roc check`), so the revert check uses a condition that is not constant.

## 17. Verify results (revert check, TW12)

`research/slice-026-revert/code-mutate.py` puts `code-final/` back, makes one change, runs `roc check`, then only the tests that should catch it. Result: caught 36 of 36 (`code-results.md`). `diff -r cli research/slice-026-revert/code-final/cli` shows no difference after the run. No mutation is a test gap or an equal change.

| Rule | Mutations | Caught by |
| --- | --- | --- |
| R-CS3 | M1 an operand is accepted | l0 `manage` |
| R-RU1 | M4 text of the newest, M6 warning with no install, M10 lock when the default is the newest, M16 not `@latest` | l0 `manage`, l2 `roc/up1` |
| R-RU2 | M2 link default moves, M3 unset default stays, M5 text of a move, M11 local build moves, M12 move reported as first default, M13 previous default not read | l0 `manage`, l2 `roc/up1` |
| R-SO15 | M9 first default decided again | l2 `roc/up1` |
| R-J3, R-OUT2, R-OUT4 | M7 `changed`, M8 key order, M14 text on stdout with `--json`, M15 warning not printed | l0 `manage`, l2 `roc/up1` |
| R-NI6, R-DL3, R-DL4 | M17 no consent | l2 `roc/up1` |
| R-SL7 | M18 only a step back, M19 no `@` needed, M20 every operand reads a base | l0 `toolchain`, l2 `roc/bs1` |
| R-PD16 | M21 base not used | l2 `roc/bs1` |
| R-SO2 | M23 `ROC_TOOLCHAIN` reads `main.roc` | l2 `roc/bs1` |
| R-SO3, R-SO6 | M24 pin not rank 3, M25 default not the base, M31 order of the files, M32 `config.toml` not read | l2 `roc/bs1`, `roc/bs2`, `proxy/` |
| R-NS1, R-SO4 | M22 no installed ids, M27 no `published_at` | l2 `roc/bs3` |
| R-SO7, R-SO9, R-EV17 | M28 proxy in proxy looks at PATH, M29 range looks at PATH, M35 `Install` not wired to `OnPath`, M36 no early stop | l2 `proxy/`, `roc/bs3`, `install/in1`, `roc/so9` |
| R-SO14 | M26 a range with no compiler has a base | l2 `roc/bs3` |
| R-NS3 | M30 nightly switch default | l2 `proxy/` |
| G2 of 024b | M33 no second form, M34 link id has the first form | l0 `pin` |

## Close (manager, 2026-10-23)

Part 026a is done. The code agent decisions are accepted (Base and OnPath hold the shared code, no copy, no cycle). The revert check caught 36 of 36. `scripts/test.sh` exits 0 with no WARN. Part 026b (`roc use`) is its own row in PLAN-P1.md. Status: done.
