# 061 Zig GC

Phase: P1. Status: done

Slice 061 is the plan row 061 of `PLAN-P1.md` (from section 5b, Q5 of slice 044): `tln cache gc` today leaves the `zig-*` dirs of `toolchains/` alone, because `Compiler.installed` does not list them. R-D2 says "GC removes it when no source build needs it". This slice makes GC remove the Zig installs that no running source build uses. A source build marks its Zig with a `.last-use` (R-CC9), and GC applies the last-day rule of R-CC10 to it. It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-061-revert/before/` (with `NEW.txt`).

Manager review (2026-10-25): section 0 rows 1 to 5, the reuse of the toolchain path (the `going` list, lock, trash, report), the output proposal and the move of the fixture out of `gc1-select` are accepted. The manager answered Q1 to Q4 (section 10). R-CC4 calls a Zig install "a toolchain install (a compiler or Zig)", so R-CC10 applies to a Zig as to a compiler.

## 0. Which Zig installs GC keeps and which it removes

"Zig install" means a directory `<cache>/toolchains/zig-<X.Y.Z>/` (R-D2). The design text for each row is in the third column.

| # | Case | GC does | Design text | Tests |
| --- | --- | --- | --- | --- |
| 1 | A dir `zig-<X.Y.Z>` (a release version of 3 numbers), no lock held, with no `.last-use` in the last day | Removes it. It is renamed to `<id>.<16hex>.trash` and deleted. The report names it as a toolchain, with its size. | R-D2: "GC removes it when no source build needs it". R-CC4: a Zig install is a toolchain install. R-CC10: GC renames and deletes a toolchain. | L0 `ZigTest` expects Z1 and Z2, L2 `gc7-zig` runs 1 to 4, L3 `gc1-real` part 9 |
| 2 | The same, and the lock `zig-<X.Y.Z>.lock` is held (an install is in progress or waits in its lock, R-CC4 step 3) | Skips it: it stays, and the report says `skipped toolchain zig-<X.Y.Z>: an install holds it` | R-CC10: "For each toolchain to remove, GC takes its lock with no wait, and skips it when an install holds the lock" | L2 `gc7-zig` runs 2, 3. L3 part 9b |
| 3 | `--dry-run` | Lists the Zig installs as `would remove toolchain zig-<X.Y.Z> (<size>)`. Takes no lock (so a busy one is also listed, as for compilers). Removes nothing. | R-GC11 | L2 `gc7-zig` run 1, L3 part 9a |
| 4 | A name that is no Zig install: a file `zig-0.15.2`, a dev version `zig-0.18.0-dev.31+abc1234`, a name with 2 or 4 numbers, a temp `zig-<v>.<16hex>.tmp`, a lock dir, a trash dir, `link-zig-*`, any compiler | Not a Zig install: this rule does not remove it. A stale temp and a stale trash dir go by their age (R-CC2, R-GC6, old rule). The other names stay. | R-D2: "`toolchains/zig-<version>/`". Slice 044 D10: only a dir with a release version is a Zig that Talon installed (`Zig.installed`). Talon installs releases only (R-D2: from the Zig index). | L0 `ZigTest` expect Z1, L2 `gc7-zig`, L3 part 9 |
| 5 | `$ZIG` or `zig` on `PATH` | Never seen: they are outside `toolchains/` | R-D1 | none needed |
| 6 | A Zig that a running source build uses (Q2, answer a) | Stays. A source build writes the `.last-use` of its Zig when it starts to use it. GC keeps a Zig with a last use in the last day: not more than 86400 s before `TALON_NOW` (exactly one day stays, a time in the future stays). | R-CC10: "GC skips a toolchain with a last use (R-CC9) in the last day: a running build wrote it when it started". R-CC9: the file `.last-use`, the time of Talon, a write with no read. | L0 `ZigTest` expect Z2, L2 `gc7-zig` (zig-0.15.1), L3 part 9 (zig-0.15.1); the write: L2 `roc/gi2-zig` runs 2 to 4 |
| 7 | A Zig that an installed `git-*` toolchain was built with (Q1) | Removed as in row 1. An installed `git-*` toolchain does not keep a Zig: a source build needs a Zig only while it runs. | R-D2 read literally: after the build, `git-<id>` does not run Zig. Design gap G1. | Not a case of its own: no rule reads a `git-*` entry. `Gc.zig_dirs` and `Gc.zigs` have no input for it. |
| 8 | A Zig with a last use more than one day ago, or with no `.last-use` (Q3) | Removed. There is no GC age for a Zig: no project pins a Zig, so the age rule of R-GC5 has no input. Only the last-day rule (row 6) and the lock (row 2) keep a Zig. | R-GC5, R-GC9: the age is for toolchains that a project pins or uses. Design gap G3. | L0 `ZigTest` expect Z2, L2 `gc7-zig` (zig-0.14.0 two days, zig-0.17.0 no file) |
| 9 | A dir `zig-<X.Y.Z>` with no `.talon.json` (a hand copy) (Q4) | The name decides: it is a Talon Zig install, and rows 1 to 8 apply. A hand copy there is removed. | Design gap G4 (R-D1 says "a Zig that Talon installed"; R-GC5 keeps `link-*` and `copy-*`, but a Zig has no such prefix). | `Gc.zig_dirs` reads names only (L0 `ZigTest` expect Z1) |
| 10 | A `.last-use` that GC cannot read (`Denied`, `Other`), or whose text is no UTC time | Stays: GC does not judge what it cannot read (as an unreadable project file, D4 of slice 028) | none (decision D8) | L0 `ZigTest` expect Z2 |

Risk that remains: the window between the end of `ZigInstall.ensure!` and the write of `.last-use` is zero calls (the write is the next call). A Zig that a person runs by hand, outside `tln roc install --git`, has no `.last-use` and goes (row 8).

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-D2 (second sentence): GC removes a Zig install that no source build needs (rows 1 and 6 to 8) | `Gc.zig_dirs`, `Gc.zigs`, `CacheGc.work!` (steps 7b and 8) | L0 `ZigTest` expects Z1 and Z2. L2 `gc/gc7-zig` runs 1 to 4. L3 `cache/gc1-real` part 9 |
| R-CC9, R-CC10 (as used for a Zig): a source build writes the `.last-use` of its Zig when it starts to use it, and GC skips a Zig with a last use in the last day | `GitInstall.build!` (the write), `Gc.zigs` | L2 `roc/gi2-zig` runs 2 to 4 (the write). L0 `ZigTest` expect Z2, L2 `gc7-zig`, L3 part 9 (the rule) |
| R-GC5, R-CC10 (as used for a Zig): a Zig install is a toolchain: the lock with `NoWait`, `Busy` skips it | `CacheGc.remove_all!` (old code) | L2 `gc7-zig` runs 2, 3. L3 part 9b |
| R-GC11 (as used): the dry run lists a Zig with its size and removes nothing | `Gc.report`, `Gc.asks` (old code) | L2 `gc7-zig` run 1. L3 part 9a |
| R-CC2, R-GC6 (as used): a temp of a Zig install is a stale temp, not a Zig | `Temp.old` (old code) | L2 `gc7-zig` runs 1, 2 |
| R-D1 (as used): the Zig dirs of Talon are `zig-<release version>` | `Gc.zig_dirs` | L0 `ZigTest` expect Z1 |

`MISSING=1 scripts/rules.sh R-D R-GC` lists no id.

## 2. Flow after this slice

`tln cache gc` (`CacheGc.work!`):

| Step | Change | Rule |
| --- | --- | --- |
| 7b (new) | After the read of the compilers (step 7): `zig_ids` is `Gc.zig_dirs` of the first `list_dirs!` result (the listing of `toolchains/`, no new call). With one Zig dir or more: one `read_files!` of `Roots.item(roots, ToolchainLastUse(id))` for each id, in the order of `zig_ids` (no call for no Zig). The Zig installs have no `.talon.json` read. | R-CC9, R-CC10 |
| 8 | `zigs` is `Gc.zigs({ ids: zig_ids, reads, now })` (`now` is the time of Talon, `clocks.now`). `going` is the compilers that `Gc.toolchains` removes, then `zigs`. Nothing else changes: `compat_of` gives `Err(None)` for a Zig (no `found` row), `Gc.asks` gives each Zig its `tree_info` path `Roots.item(roots, Toolchain(id))` (the same path as `Roots.item(roots, Zig(version))`), step 9 takes its lock and calls `Trash.move!`, `Gc.report` and `Gc.data` print it as a toolchain. | R-D2, R-CC10, R-GC11 |

Byte order puts `zig-` after `git-`, `link-`, `copy-`, `nightly-` and the release versions, so "compilers first, then Zig" is also the sorted order.

`tln roc install --git` (`GitInstall.build!`), the change that writes the use (Q2, answer a):

| Step | Change | Rule |
| --- | --- | --- |
| 10b (new) | Directly after `ZigInstall.ensure!` returns, and before `fx.locked!` of the build item: when the Zig is one of Talon (`how` is `Installed`, `Present`, or `Found(Installed)`; not `Found(Env)` or `Found(Path)`), one `write_atomic!` of `<cache>/toolchains/zig-<version>/.last-use` with `Launch.last_use(run.now)` (`Launch.touch!(fx, roots, { id: "zig-<version>", now })` does it). A write error is ignored (as R-CC9 in the proxy: a run does not stop for it). The write comes also when the lock then finds the build item there (`Present`: no build): the Zig was found for the run. | R-CC9, R-CC10 |

The call is placed before the lock wait so that a build that waits for the lock of its item already marks its Zig. `ZigInstall.ensure!` itself does not change: the L2 cases of slice 044 do not change.

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Gc.roc` | 359 (+21) | Test agent, stubs | New public `zig_dirs` and `zigs` (`crash "todo: slice 061"`), with the contract in their docs. A row in the table at the top of the doc. |
| `cli/lib/CacheGc.roc`, `cli/lib/GitInstall.roc` | 239, 296 (0) | Code agent | Not changed by the test agent. The stubs are not called, so the old cases do not crash. The code agent writes the wiring (section 2). |
| `tests/unit/ZigTest.roc` | 418 (+76) | Test agent | Two new `expect`s at the end (Z1 `zig_dirs`, Z2 `zigs`), `import lib.Clock`, `import lib.Gc`. In the driver `l0-6.roc` (no driver change). |
| `tests/commands/cases/gc/gc7-zig/` | 4 runs | Test agent | New L2 case: `entry`, `fx/` (`commands`, `env`, `locks`, `mtimes`), `given/home` (compilers and Zig entries in `toolchains/`), `given/home2`, `expect/` (made with the private reference, read by eye) |
| `tests/commands/cases/roc/gi2-zig/expect/` | `calls.log` +3 lines, `tree.diff` +4 lines | Test agent | The write of `.last-use` in runs 2, 3 and 4 (TW21, section 8) |
| `tests/commands/cases/gc/gc1-select/` | 1 file less | Test agent | `given/home/.cache/roc/toolchains/zig-0.17.0/zig` removed (section 8). A comment of `fx/commands` changed. No expected file changes. |
| `tests/scenarios/cache/gc1-real/` | `cmd` 131 (+28) | Test agent | New part 9 (9a, 9b, 9c). `expect/stdout` +30 lines, `expect/stderr` +2 lines. `tree.diff` and `exit` do not change. |
| `research/slice-061-revert/` | | Test agent | `before/` (and `NEW.txt`), `stubs/`, `red.log`, `green.log`, `mutate.log`. The private reference is deleted (manager, 2026-10-25). |

No change to `scripts/`, `tests/commands/*.roc`, `tests/run.sh`, `Fx`, `RealFx`, `FakeFx`.

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Gc.zig_dirs` | `List({ name : Str, is_dir : Bool, mtime : U64 }) -> List(Str)` | R-D2, R-D1 |
| `Gc.zigs` | `{ ids : List(Str), reads : List(Manage.Read), now : U64 } -> List(Str)` | R-D2, R-CC9, R-CC10 |

`Gc.zig_dirs` rules (the table is in its doc comment):

| Input | Result |
| --- | --- |
| An entry that is a dir, with the name `zig-` and a release version of 3 numbers (`X.Y.Z`, only digits) | Its name (`zig-<X.Y.Z>`) |
| A file, a dev version, a version with 2 or 4 parts, a non-numeric part, a name with a suffix (`.tmp`, `.lock`, `.trash`), `zig-`, `zig`, `zigzag-*`, `link-zig-*`, a compiler | Nothing |
| Many entries | The names in byte order (`zig-0.17.10` before `zig-0.17.9`), each once, whatever the order of the listing. The `mtime` is not read. |

`Gc.zigs` rules (`reads` has one result of `Fx.read_files!` for each id, in the order of `ids`):

| `reads` of an id | Result |
| --- | --- |
| `Ok(text)` with a UTC time (`Clock.parse_utc` of the trimmed text) that is not more than 86400 s before `now` (exactly one day stays, a time in the future stays) | Stays |
| `Ok(text)` with a UTC time more than 86400 s before `now` | Goes |
| `Err(NotFound)` | Goes |
| `Err(Denied)`, `Err(Other(_))`, `Ok(text)` that is no UTC time (also empty) | Stays |

The result has the ids that go, in the order of `ids`.

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/ZigTest.roc` expect Z1 (`zig_dirs`, 8 rows) | An empty listing. One Zig. Two Zig with the times 0 and 99999999999 (the time is not read). Byte order of the names and the order of the listing. 16 names that are no Zig install (a file, a dev version, 2 and 4 parts, a temp, a lock dir, a trash dir, `zig-`, a non-numeric version, `zig`, `zigzag-*`, `link-zig-*`, `git-*`, `copy-*`, a nightly, a release). The same with one Zig added or around them. | R-D2, R-D1 |
| L0 | `ZigTest` expect Z2 (`zigs`, 14 rows) | One hour, 12 hours, exactly one day (stays), one day and 1 s, 2 days (go), a text with no line end, a time in the future (stays), `NotFound` (goes), `Denied`, `Other`, a text that is no time, an empty text (stay), a list of 5 ids in order. | R-D2, R-CC9, R-CC10 |
| L2 | `gc/gc7-zig` run 1 `cache gc --dry-run` | Lists `nightly aaaaaaa` (a compiler that goes), `zig-0.14.0`, `zig-0.16.1`, `zig-0.17.0` and the stale temp, each with its size, in this order. No lock. Nothing removed. `zig-0.15.1` (last use 12 hours ago), the dev dir, the file `zig-0.15.2` and the compiler `38a3029` are not listed. One read of the compilers, then one read of the 4 `.last-use` of the Zig installs, then one `tree_info` for all asks. | R-D2, R-CC10, R-GC11, R-CC2 |
| L2 | `gc7-zig` run 2 `cache gc --json` | The GC lock, then the lock of aaaaaaa (held), of `zig-0.14.0` and `zig-0.17.0` (held): `rename` to `.trash`, `delete`, `unlock`; `zig-0.16.1` (busy: skipped). One `delete` for the stale temp. `data.toolchains` is `["nightly-2026-08-01-aaaaaaa","zig-0.14.0","zig-0.17.0"]`, `skipped` is `["zig-0.16.1"]`, the sizes and `freed`. The text is on stderr. | R-D2, R-GC5, R-CC10, R-J3 |
| L2 | `gc7-zig` run 3 `cache gc` | `zig-0.14.0` and `zig-0.17.0` are gone. The read of the `.last-use` has only `zig-0.15.1` and `zig-0.16.1`. `zig-0.15.1` stays, `zig-0.16.1` is skipped again. | R-CC10, R-GC6 |
| L2 | `gc7-zig` run 4, `HOME=home2` | A store with no compiler: no `.talon.json` is read. One read of the `.last-use` of its Zig (21 days ago): it goes. | R-D2 |
| L2 | `roc/gi2-zig` runs 2, 3, 4 (changed expected files) | A new `write_atomic $HOME/.cache/roc/toolchains/zig-0.17.0/.last-use` directly after the Zig step and before the build lock (run 2: after the install, `unlock`; runs 3 and 4: after `programs zig`, `list_dirs`). In run 4 the build item is `Present` and the write is made all the same. `tree.diff` shows the file `.last-use` with `2026-10-22T12:00:00Z` (run 2 installs the Zig in the tree). The Zig of `PATH` in `roc/gi1-install` gets no write (unchanged). | R-CC9, R-CC10 |
| L3 | `cache/gc1-real` part 9 | The real binary and `Fx`: `zig-0.17.0` (no `.last-use`), `zig-0.16.1` (last use 21 days ago, and the lock dir of an install with a live `beat`), `zig-0.15.1` (last use 12 hours ago), a dev dir, a file. 9a the dry run lists `zig-0.16.1` and `zig-0.17.0` with real sizes. 9b the real run removes `zig-0.17.0` and skips `zig-0.16.1`. 9c the lock dir is gone: `--json` removes `zig-0.16.1`. `zig-0.15.1`, the dev dir and the file stay. | R-D2, R-GC5, R-CC10, R-CC9, R-GC11 |

Count: 2 new L0 `expect`s (in an old module), 1 new deep L2 case (4 runs), 1 old deep L2 case with 3 changed runs (`gi2-zig`), 1 new part in a deep L3 case. No selftest row.

## 6. Output (proposed, R-OUT2, TW24; accepted at the manager review)

No new text and no new `--json` key. A Zig install is a toolchain of the report:

| Where | Text |
| --- | --- |
| stdout, a run | `removed toolchain zig-<X.Y.Z> (<size>)`, in the lines of the toolchains, after the compilers |
| stdout, a busy install | `skipped toolchain zig-<X.Y.Z>: an install holds it` |
| stdout, a dry run | `would remove toolchain zig-<X.Y.Z> (<size>)` |
| `--json` `data` | `toolchains` has the id `zig-<X.Y.Z>`, `skipped` has it when busy, `sizes` has `{"item":"zig-<X.Y.Z>","bytes":<n>}`, `freed` counts it |

The file `.last-use` of a Zig has the form of the compiler file (`Launch.last_use`): the UTC time of Talon and a line end, for example `2026-10-22T12:00:00Z`. `tln roc install --git` prints no new line.

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `Gc.zig_dirs` takes names only. `Gc.zigs` takes the `.last-use` results and `now`. The Zig installs have no `.talon.json` read and no `installed_at` fallback (Q3: no age). | A fallback to `installed_at`. The `.talon.json` read. |
| D2 | The Zig ids join `going` (the toolchains that go) after the compilers, and use the old lock, trash, size and report code. The id is `zig-<X.Y.Z>`, as the dir name. | A new step and a new `Done` list. A Zig in `Manage.rows`. |
| D3 | The lock of a Zig is `Roots.item(roots, Toolchain("zig-<v>"))`. It is the same path as `Roots.item(roots, Zig(<v>))`, which `ZigInstall` locks (R-CC4). So GC and an install use one lock. | A second lock item |
| D4 | A dev version, a version with 2 or 4 parts and a suffixed name are not a Zig install (as `Zig.installed`, slice 044 D10). | GC removes each `zig-*` dir |
| D5 | `Gc.zig_dirs` and `Gc.zigs` are not called by `CacheGc` in the red state. A stub that crashes would crash all old GC cases. | The wiring with a stub that crashes |
| D6 | The old fixture `zig-0.17.0` of `gc1-select` moves out (section 8). | An `UPDATE=1` of `gc1-select` with a Zig removed next to `git-dd03c09e` and with no `.talon.json` |
| D7 | The L0 `expect`s are in `ZigTest` (418 lines): `GcTest` has 457 lines and the limit is 490. | A new module in a driver |
| D8 | A `.last-use` that GC cannot read (`Denied`, `Other`) or that is no UTC time keeps the Zig. `NotFound` removes it. | An unreadable file removes the Zig. A text that is no time counts as no file. |
| D9 | The write of the use is in `GitInstall.build!` directly after `ZigInstall.ensure!`, not in `ensure!`: only a source build uses a Zig, and the L2 cases of slice 044 stay as they are. The write is made for each run that finds a Zig of Talon, also when the build item is `Present`. | A write inside `ensure!` (it changes the `zig/` cases and the stand-ins). A write only before `zig build` (a wait for the lock of the build item would leave the Zig with no mark). |
| D10 | A Zig of Talon is `how` = `Installed`, `Present`, or `Found(Installed)`. `Found(Env)` and `Found(Path)` get no write: they are no dir of `toolchains/`. | A write for each `how` |

## 8. Old cases that change (TW21)

| Case | Change | Reason |
| --- | --- | --- |
| `roc/gi2-zig` | `expect/calls.log`: 3 new lines `write_atomic $HOME/.cache/roc/toolchains/zig-0.17.0/.last-use` (runs 2, 3, 4). `expect/tree.diff`: 4 new lines (the file, run 2). No other change. Copies: `before/tests/commands/cases/roc/gi2-zig/expect/` | Q2 answer (a): a source build marks its Zig. `gi2-zig` is the only old case whose Zig is a Talon install (the others use `zig` on `PATH`). I read the 2 diffs by eye (only added lines). |
| `gc/gc1-select` | `given/home/.cache/roc/toolchains/zig-0.17.0/zig` is deleted, and the comment line 3 of `fx/commands` no longer names `zig-0.17.0`. Copies: `before/tests/commands/cases/gc/gc1-select/` | The old case kept a Zig dir (no `.talon.json`, no `.last-use`) next to `git-dd03c09e`. GC now removes such a Zig. The case is about compilers, so the dir moved into `gc7-zig`. After the move all runs give the old expected files (the 7 `gc/` cases pass with the reference). Accepted at the review. |
| `cache/gc1-real` | New part 9 at the end of `cmd`. `expect/stdout` +30 lines, `expect/stderr` +2 lines. `exit` and `tree.diff` as before (part 9 leaves no file). Copies: `before/tests/scenarios/cache/gc1-real/` | The new part. `diff` of the `before/` copy against the new file shows added lines only. |

## 9. Out of scope

| Id | Reason |
| --- | --- |
| R-GC13, R-GC14: `tln cache clean` | R-GC14 says it never removes a toolchain. A Zig install is a dir of `toolchains/`, so clean leaves it. No design text names Zig for `clean`: not changed (G5). |
| `tln roc rm zig-<v>` | R-RR1 to R-RR3 name compilers. `roc rm` of a Zig id has no rule. Not changed (G5). |
| A Windows `rename` of a running `zig.exe` (R-CC10 exit 17) | The Windows rule names compilers. No Windows host in the fast set. |
| The last use of a Zig that `tln tool install` or another command uses | Only `tln roc install --git` runs `zig build` (the only caller of `ZigInstall.ensure!`). |
| R-DA6, a real Zig download | No download here. GC removes only. |

## 10. Questions of the first version, and the manager's answers (2026-10-25)

| # | Question | Answer | Where it is in the tests |
| --- | --- | --- | --- |
| Q1 | Which source build needs a Zig? | A source build needs a Zig only while it runs (R-D2 read literally). Q2 covers it. An installed `git-*` toolchain does not keep a Zig. | Section 0 row 7. No input and no fixture for `git-*` next to a Zig. |
| Q2 | How does GC see a running source build? | (a) The build writes the `.last-use` of its Zig when it starts to use it (the form of the compiler file, R-CC9). GC skips a Zig with a last use in the last day (R-CC10). | `Gc.zigs`, `GitInstall.build!` step 10b, section 0 row 6 |
| Q3 | Does the GC age apply to a Zig? | No age: no project pins a Zig. Only the last-day rule and the lock. | Row 8. No `installed_at` fallback (D1). |
| Q4 | Is a `zig-<X.Y.Z>` dir with no `.talon.json` a Talon install? | The name decides. A hand copy there is removed. | Row 9 |

## 11. Design gaps (all, for the next edit of the design files)

| # | Gap | Proposed text |
| --- | --- | --- |
| G1 | R-D2 uses "needs" with no definition (Q1). | R-D2: "GC removes it when no running source build uses it (R-CC10 last-day rule). An installed `git-*` toolchain does not keep a Zig." |
| G2 | R-CC9 names the proxy and the probes as the writers of `.last-use`, and R-CC10 uses it as "a running build wrote it when it started". `tln roc install --git` and a Zig have no such writer (Q2). | R-CC9: "`tln roc install --git` writes the `.last-use` of a Zig of Talon (`toolchains/zig-<v>/`) before it builds, also when it waits for a lock." |
| G3 | R-GC5 and R-GC9 give the age for toolchains that a project pins or uses. A Zig has no pin, so it has no age (Q3). | R-GC5: "A Zig install has no GC age: it stays only while its last use is in the last day (R-CC10) or its lock is held." |
| G4 | R-D1 says "a Zig that Talon installed", and R-GC5 keeps hand-made `link-*` and `copy-*` entries. A hand copy of a Zig in `toolchains/zig-<v>/` is removed by name (Q4). | R-D2: "A dir `toolchains/zig-<X.Y.Z>` counts as a Zig of Talon, also when a person made it." |
| G5 | R-GC13, R-GC14 and R-RR1 to R-RR3 do not say what `tln cache clean` or `tln roc rm` do with a Zig. | R-GC14: add "or a Zig install". R-RR: say that `roc rm` takes compilers only. |
| G6 | R-CC4 says a toolchain install is "a compiler or Zig", but R-GC5 is the row "Toolchains" with a compiler in mind. This slice applies R-CC10 (lock, last day) to a Zig. | One sentence in R-GC5: "A Zig install is a toolchain for R-CC10." |
| G7 | Slice 044 Q2 and 045 G6: a dev `minimum_zig_version` and a `build.zig.zon` with no key are open (not changed here). A Zig for a dev version is a release dir of the same series. | As in slices 044 and 045. |

## 12. Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| A new name in a function of `CacheGc` or `Gc` must not repeat an existing binding of the module (`found`, `read`) | The private reference used `names` and `got` |
| `roc test` of `l0-6.roc` did not report the duplicate name of the reference in `Gc.zigs` (the unit file passed with it), but `roc build` of the L2 app did | Check an L2 build after a change of `Gc.roc` |

## 13. Red output

`scripts/test.sh` with the stubs (`research/slice-061-revert/red.log`): check pass, fmt pass, l0 FAIL (7.8 s), l2 FAIL (10.1 s), l3 FAIL (10.0 s), selftest pass, l1 pass. The old tests all pass.

| Layer | Result | Reason |
| --- | --- | --- |
| l0 `l0-6.roc` | 2 of 65 fail (`ZigTest` expects Z1 and Z2) | `Roc application crashed with this message: todo: slice 061` (the stubs `Gc.zig_dirs` and `Gc.zigs`) |
| l0 other drivers | pass (`l0-7`: 64, `l0-8`: 77) | |
| l2 | 168 passed, 2 failed: `gc/gc7-zig`, `roc/gi2-zig` | `gc7-zig`: a wrong value (no Zig is removed: the stubs are not called). `gi2-zig`: the 3 `write_atomic ... .last-use` lines and the tree diff are missing. The 6 old `gc/` cases pass. |
| l3 | 82 passed, 1 failed, 1 skipped: `cache/gc1-real` | A wrong value: part 9 keeps `zig-0.17.0` and `zig-0.16.1` |

With the private reference (`green.log`): `scripts/test.sh` passes all 7 steps (l0 8.0 s, l2 10.1 s, l3 10.1 s). The reference was `Gc.zig_dirs` (about 4 lines and a helper), `Gc.zigs` (a line and a helper), 5 lines in `CacheGc.work!` and 5 lines in `GitInstall.build!`.

## 14. Revert check (TW12)

Method: a private script put the reference into `cli/lib`, made one change, checked `roc check cli/lib/main.roc`, then ran l0 (`l0-6.roc`), l2 (`gc/` and `roc/gi`) and l3 `cache/gc1-real`. The first failing layer ended the run. 9 hand mutations of the most tricky behaviors (user rule 2026-10-23), no full sweep. Result: 9 caught of 9 (`mutate.log`). Then the reference was deleted and the stubs put back.

| Id | Mutation | Caught by |
| --- | --- | --- |
| M1 | A file `zig-<v>` counts as a Zig install (no `is_dir`) | L0 `ZigTest` expect Z1 |
| M2 | Every `zig-*` dir counts (dev, temp, lock, trash) | L0 `ZigTest` expect Z1 |
| M3 | A name with more parts counts (`zig-0.17.0.<hex>.tmp`, `zig-0.17.0.lock`) | L0 `ZigTest` expect Z1 |
| M4 | The Zig ids come before the compilers in `going` | L2 `gc/gc7-zig` |
| M5 | A store with no compiler removes no Zig | L2 `gc/gc7-zig` run 4 |
| M6 | New (`Gc.zigs`): the last-day rule is dropped (span 0): a Zig used 12 hours ago goes | L0 `ZigTest` expect Z2 |
| M7 | New (`CacheGc`): the `.last-use` of the Zig installs is not read (each is `NotFound`) | L2 `gc/gc7-zig` (`zig-0.15.1` goes, the read is missing from `calls.log`) |
| M8 | New (`GitInstall`): no `.last-use` is written before a source build | L2 `roc/gi2-zig` runs 2 to 4 |
| M9 | New (`GitInstall`): a Zig on `PATH` or in `$ZIG` gets a write too | L2 `roc/gi1-install` |

L3 `gc1-real` part 9 is green with the reference and red with the stubs. No mutation needed it as the first catch (L0 and L2 fail first). A hand mutation for L3 alone is not made (no gap test).

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | Write `Gc.zig_dirs` and `Gc.zigs` (the docs of the stubs are the contract), the steps 7b and 8 of section 2 in `CacheGc.work!`, and step 10b in `GitInstall.build!`. Do not change other flow code: the lock, trash, size and report code is shared with the compilers. |
| N2 | `Zig.is_release` and `Zig.triple` are private in `Zig.roc` (458 lines, the limit is 490). Make `is_release` public, or write the 3-number test in `Gc.roc` (359 lines). Both keep the files under 490 lines. |
| N3 | `Launch.touch!` does the write of step 10b (`Launch.touch!(fx, run.roots, { id: "zig-${version}", now: run.now })`). `Gc.roc` needs `import Clock` for `Clock.parse_utc`. |
| N4 | A new binding must not repeat a name of the module (section 12). After a change of `Gc.roc`, build the L2 app (`tests/commands/run.sh gc`). |
| N5 | Do not edit a test (TW18). A question goes to the manager. |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Code (green)

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Gc.roc` | 376 | `zig_dirs`, `zigs`, private `unused_zig`, `import Clock`, `import Zig` |
| `cli/lib/CacheGc.roc` | 246 | Step 7b and the `going` change of step 8 (`zig_ids`, `zig_reads`, `zigs`) |
| `cli/lib/GitInstall.roc` | 306 | Step 10b: private `mark_zig!` (`Launch.touch!`), called before `fx.locked!` |
| `cli/lib/Zig.roc` | 462 | New public `is_release_version` (a wrapper of the private `is_release`, N2) |

Decision of the code agent (not fixed by the slice): N2 option "make public" was done with a new public wrapper `Zig.is_release_version`, not a copy of the 3-number test in `Gc.roc`. Rejected: a second copy of the test.
D10 as coded: `Found(Env)` and `Found(Path)` get no write. `Installed`, `Present` and `Found(Installed)` get one.

## Verify results

`scripts/test.sh` exit 0: check, fmt, l0 (8 files, 65 in `l0-6`), l2 170 passed, l3 83 passed 1 skipped, selftest, l1 all pass (72 s).
Revert check (hand mutations, filtered runs, the files were put back and compared with a copy):

| Id | Mutation | Caught by |
| --- | --- | --- |
| M1 | `zig_dirs`: a file counts (no `is_dir`) | L0 `ZigTest` Z1 |
| M2 | `zigs`: `NotFound` keeps the Zig | L0 `ZigTest` Z2 |
| M3 | `zigs`: span 86399 (exactly one day goes) | L0 `ZigTest` Z2 |
| M4 | `zigs`: an unreadable `.last-use` removes the Zig (D8) | L0 `ZigTest` Z2 |
| M5 | `zigs`: no `trim` of the text | L0 `ZigTest` Z2 |
| M6 | `CacheGc`: Zig ids before the compilers in `going` | L2 `gc/gc7-zig` |
| M7 | `GitInstall`: a Zig of `PATH` or `ZIG` gets a write | L2 `roc/gi1-install` |
| M8 | `GitInstall`: the write is after the build lock | L2 `roc/gi2-zig` |

Caught 8 of 8. Final copy: `research/slice-061-revert/code-final/` and `code-final.sha256`.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-061-revert/code-final.sha256` | OK |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.7, fmt 0.2, l0 7.8, l2 10.1, l3 10.0, selftest 3.4, l1 38.1 s |
| Code pass | 8 of 8 mutations caught |
| Gap tests | None: no mutation was missed; the only new decision is the public `Zig.is_release_version` wrapper (no behavior). |
| Design gaps | G1 to G7, recorded in PLAN-P1 5b. Q1 to Q4 are manager readings of R-D2, R-CC4, R-CC10, R-GC5 for the human to confirm. |
