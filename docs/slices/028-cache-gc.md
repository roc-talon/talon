# 028 Cache gc

Phase: P1. Status: done

Slice 028 is part 1 of `tln cache gc` (CLI 6.3, R-GC5, R-GC6, R-GC9, R-GC11, R-CC2, R-CC10). GC removes the compilers that nothing needs, the stale temps, `.trash` dirs, stale lock dirs and probe copies that a crash left, and the entries of `projects.json` that protect nothing. It takes the GC lock, and one lock for each compiler that it removes. `--dry-run` prints what it would remove and removes nothing. It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-028-revert/before/` (with `NEW.txt`).

## 0. Size and split proposal (for the manager)

| Item | Value |
| --- | --- |
| Plan row | 400 lines |
| Reference of this part (deleted, was `research/slice-028-revert/reference/cli/lib/Gc.roc`, `CacheGc.roc`) | 286 lines that are not comment or blank (`Gc` 110, `CacheGc` 176), and 12 lines in `Intent` and `Temp` |
| Estimate of the whole row (all of R-GC1 to R-GC11) | About 490 lines, with a new `Fx` call (real `Fx`, fake `Fx`, `fxprobe`) |
| Verdict | The whole row is about 20 percent over TW19 and brings a new `Fx` call, a closure walk and a second review point. So this file is part 1. Part 2 is a proposal. |

| Part | Content | Rules | State |
| --- | --- | --- | --- |
| 028 (this file) | Toolchains (age, pins, default, last day, hand made entries), the GC lock, the toolchain locks, the trash, the compat dir of a removed compiler, stale temps and `.trash` dirs and stale lock dirs and probe copies and the `.locks` registry, the entries of `projects.json`, `gc-age`, `--dry-run`, `--json` | R-GC3 (first sentence), R-GC5, R-GC6, R-GC9, R-GC11, R-CC2 (GC), R-CC10, R-EV22 (GC ages), R-PD12 (GC), R-PD13 (GC), R-CM17 (`gc`) | tests written |
| 028b (proposal) | `nightly-<tag>/`, `debug-<sha>/` and other `compat-<id>/` dirs by the age of their newest file (R-GC2, R-GC3 second sentence). `packages/<hash>/` that no live known project uses, with the closure read from the package headers in the cache and never fetched (R-GC4). The new call `Fx.tree_info!` (the newest modification time and the size of a dir, so the dry run can print sizes, Q5). The check that GC never looks inside a kept build cache (R-GC1). | R-GC2, R-GC3 (second sentence), R-GC4, R-GC1, Q5 | not started. Plan row to add: `028b`, after 028, before 029 (029 needs the sizes) and before 053 (the P1 exit case "GC frees the legacy dirs"). About 200 lines. |
| 049 | `talon/x/<digest>/` (R-GC7). No `x` entry and no `x` last-use record exists yet (R-X2). The plan row of 049 has R-GC7 already. | R-GC7 | out of scope here |

Part 1 needs no new `Fx` call. The cost of the whole row is in part 2.

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-GC5 (keep the default, keep every toolchain that a live known project pins (any age) and every toolchain used in the GC age (D17), keep a `link-*` and a `copy-*` entry, a `git-*` build follows the rule of a nightly, never remove a toolchain that an install holds or that was used in the last day) | `Gc.toolchains`, `CacheGc.work!`, `CacheGc.remove_all!` | L0 `gc` row 3. L2 `gc/gc1-select` runs 1, 3, 4. L3 `cache/gc1-real` parts 1, 3, 4 |
| R-GC9 (`gc-age` of `config.toml`, default 30 days, "in the age" is not more than the age; the last uses are the times that Talon records: `.last-use` and `installed_at` of a toolchain, `last_use` of a project) | `Gc.age`, `Intent.read_config`, `Gc.toolchains`, `Gc.projects` | L0 `gc` rows 1, 2, 3, `intent` row 7. L2 `gc1-select` (30 days: runs 1, 3, home3 run 7). L3 part 1 (7 days) |
| R-GC11 (`--dry-run` prints what it would free and removes nothing; no operand) | `Gc.read`, `Gc.report`, `CacheGc.gc_flow!` | L0 `gc` rows 1, 5. L2 `gc1-select` runs 1, 2, 5. `gc2-busy` runs 3, 4. L3 parts 1, 6, 7 |
| R-CC10 (the lock of the item `talon/gc` with `NoWait`, another GC: the line and exit 0; for each toolchain its lock with `NoWait`, `Busy` skips it; the last day is skipped; `rename` to `<id>.<16hex>.trash`, then delete) | `CacheGc.gc_flow!`, `CacheGc.remove_all!`, `CacheGc.trash!` | L2 `gc1-select` runs 3, 4 (the lock of 6666666 is busy). `gc2-busy` runs 1, 2. L3 parts 2, 3, 4, 5 (real lock dirs) |
| R-GC3, first sentence (the compat dir of each compiler that GC removes goes with it, and no other compat dir) | `Manage.compat_of`, `CacheGc.work!` | L2 `gc1-select` runs 1 to 3 (`compat-aaaaaaa` and `compat-ccccccc` go, `compat-6666666` stays while its lock is busy, `compat-other` and `compat-bbbbbbb` stay). L3 parts 1, 3, 4 |
| R-GC6, R-CC2 (temps, `.trash` dirs, stale lock dirs and probe copies `talon/tmp/<16hex>/` older than 1 day, by file modification time against the real clock; the registry `talon/tmp/<16hex>.locks` of a process that ended) | `Gc.scan_dirs`, `Gc.entries`, `Temp.old` | L0 `gc` row 4, `temp` row 4. L2 `gc1-select` runs 1, 3. L3 parts 1, 3, 6 |
| R-EV22 (GC ages use `TALON_NOW`: toolchains and projects. Temps use the real clock) | `CacheGc.clocks_of`, `CacheGc.work!` | L2 `gc1-select` (the fake clock is 7 days before `TALON_NOW`). L3 part 6 |
| R-PD12, R-PD13 (GC reads the project file again: an entry whose file is missing, has no header, or was last used more than the GC age ago leaves the list, and protects nothing; a file that cannot be read stays) | `Gc.projects`, `CacheGc.known_projects!`, `CacheGc.prune!` | L0 `gc` row 2. L2 `gc1-select` runs 3 (tree diff), 6 (a `projects.json` that does not parse: exit 19, nothing removed). L3 parts 3, 6 |
| R-CM15, R-CM17 (the command, no operand) | `Gc.read`, `Run.tln!` | L0 `gc` row 1. L2 `gc1-select` run 5, `gc2-busy` run 4. L3 part 7 |
| R-GC1, R-GC8 (build-cache files and app installs are left to roc: GC does not look at them) | `Gc.scan_dirs` has no build-cache dir and no `bin` dir | L3 part 7 (`compat-other` and the app file stay). The age rule for whole build-cache dirs is part 2 |
| R-J3, R-J4, R-OUT2, R-OUT4 (the text and `data`) | `Gc.report`, `Gc.data` | L0 `gc` rows 5, 6. L2 `gc1-select` runs 2, 3, `gc2-busy` run 2. L3 part 4 |
| R-GC10 | Slice 021 (the compat id is in `.talon.json`) | `Manage.compat_of` reads it |
| R-GC2, R-GC3 (second sentence), R-GC4 | Part 2 (028b) | none here |
| R-GC7 | Slice 049 | none here |

Rules of other slices that the cases also touch: R-CC1 (the writes of `projects.json`), R-CC3 (no `ask!` call in a lock: there is none), R-CC6 (the lock of `projects.json`), R-CC9 (`.last-use`), R-TF4 (a bad `gc-age`, exit 19), R-TF6 (`projects.json` that does not parse, exit 19), R-LY1, R-LY3, R-R4 (a `git-*` id is never a `roc:` pin, so no project pins it), R-RR2 (the same pin test as `roc rm`, `Manage.pinned_by`).

`MISSING=1 scripts/rules.sh R-GC R-CC R-EV R-PD R-CM` lists, for the ids of this slice, none. It lists R-GC2, R-GC4, R-GC7 (parts 2 and 049) and R-GC12 to R-GC14 (slice 029).

## 2. Flow of `tln cache gc` (the calls that the L2 cases fix)

The doc of `cli/lib/CacheGc.roc` has the same table.

| Step | Calls | Rule |
| --- | --- | --- |
| 1 | `Gc.read(args)` (no `Fx` call). A failure: `Common.failed!`. | R-GC11 |
| 2 | `args`, `env_all`, `clock` (one call: the real time. `TALON_NOW` is the time of Talon, else the same real time) | R-EV22 |
| 3 | Not a dry run: `lock <cache>/talon/gc nowait`. `busy`: the line `another tln cache gc runs`, exit 0, no more call. A dry run takes no lock. Steps 4 to 11 are in the lock, and `unlock` is the last call. | R-CC10 |
| 4 | `read_files config.toml` (one call). The warnings on stderr. | R-GC9 |
| 5 | One `list_dirs` with 6 dirs: `toolchains`, `packages`, `talon`, `talon/tmp`, `talon/index`, `talon/x` | R-CC2, R-LY1 |
| 6 | `read_files talon/projects.json`. A missing file is no project. A file that does not parse is exit 19 and the run ends here (no removal). With one entry or more: one `read_files` of the project files. | R-PD12, R-TF6 |
| 7 | One `read_files` with 2 paths for each compiler, in the order of the ids: `.talon.json`, `.last-use` (as `roc list`). No call with no compiler. | R-CC9 |
| 8 | The decisions (no call). A dry run stops here and prints. | R-GC5, R-GC6 |
| 9 | For each compiler to remove, in the order of the ids: `lock <item> nowait`. `busy`: nothing more for it. `held`: `random`, `rename` to `<item>.<16hex>.trash`, `delete` of the trash dir and its compat dir (one call), `unlock`. | R-CC10, R-GC3 |
| 10 | `delete` of the stale paths (one call, none when there is no stale path) | R-CC2, R-GC6 |
| 11 | When an entry of `projects.json` leaves: `lock <cache>/talon/projects.json nowait` (the log shows `nowait`: `Fx.locked!` takes `NoWait` first), `read_files`, `write_atomic`, `unlock`. The second read applies only the entries of step 6 that left, so an entry that a command added since stays. | R-PD13, R-CC6 |
| 12 | The text on stdout (`--quiet` hides it, `--json` moves it to stderr) and with `--json` the envelope on stdout | R-OUT2, R-J3 |

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Gc.roc` | 87 | Stubs from the test agent. Bodies from the code agent. | New pure module. 8 public functions and 5 types, all bodies `crash "todo"`. The docs have the contract. |
| `cli/lib/CacheGc.roc` | 26 | Same | New command module. `run!` is `crash "todo"`. The doc has the table of the calls. |
| `cli/lib/Intent.roc` | +1 | Test agent, stub | `Config` has the field `gc_age`. `read_config` gives `Err(Unset)` (stub: the value is not read). |
| `cli/lib/Base.roc`, `cli/lib/ResolveBase.roc` | +1 each | Test agent | The record of a missing `config.toml` has `gc_age: Err(Unset)` |
| `cli/lib/Temp.roc` | doc | Test agent | The doc of `old` names the `.locks` file. The body is for the code agent (`is_stale_kind`). |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | +3, +2 | Test agent | The dispatch for `["cache", "gc"]`, and `CacheGc` and `Gc` in the exposes list |
| `tests/unit/gc.roc` | 256 | Test agent | 6 `expect`s, red |
| `tests/unit/temp.roc`, `tests/unit/intent.roc` | +25, +24 | Test agent | 1 new `expect` each, red. The old `expect`s are not changed. |
| `tests/commands/cases/gc/gc1-select/`, `gc2-busy/` | 2 cases | Test agent | L2, 7 and 4 runs, red |
| `tests/scenarios/cache/gc1-real/` | 1 case | Test agent | L3, 7 parts (62 lines of `cmd`), red |
| `research/slice-028-revert/` | | Test agent | `before/` (copies and `NEW.txt`), `stubs/` (the 8 files that differ), `swap.sh` and `mutate.py` (they need the reference, which is deleted), `mk-fixtures.py`, `mutate-run.log`, `results.md`, `baseline.log`, `red.log`. The private reference is deleted (D17). |

`FakeFx`, `tests/commands/main.roc`, `tests/commands/run.sh`, `tests/run.sh`, `scripts/test.sh`, `tests/selftest.sh`, `cli/RealFx.roc` and `cli/fxprobe.roc` are not changed. There is no new `Fx` call.

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Gc.Plan` | `{ dry_run : Bool }` | R-GC11 |
| `Gc.Project` | `{ path : Str, text : Manage.Read }` | R-PD12 |
| `Gc.Why` | `[Hand, Default, LastDay, NoTime, Pinned, Used]` | R-GC5 |
| `Gc.Choice` | `{ id : Str, verdict : [Remove, Keep(Gc.Why)] }` | R-GC5 |
| `Gc.Done` | `{ dry_run : Bool, ran : Bool, toolchains : List(Str), skipped : List(Str), compat : List(Str), stale : List(Str), projects : List(Str) }` | R-OUT2 |
| `Gc.read` | `Args -> Try(Gc.Plan, Fail)` | R-GC11, R-CM15 |
| `Gc.age` | `Try(U64, [Unset]) -> U64` | R-GC9 |
| `Gc.projects` | `{ entries : List({ path : Str, last_use : U64 }), reads : List(Manage.Read), now : U64, age : U64 } -> { live : List(Gc.Project), gone : List(Str) }` | R-PD12, R-PD13 |
| `Gc.toolchains` | `{ rows : List(Manage.Row), projects : List(Gc.Project), now : U64, age : U64 } -> List(Gc.Choice)` | R-GC5, R-CC10 |
| `Gc.scan_dirs` | `Roots -> List(Str)` | R-CC2 |
| `Gc.entries` | `{ dirs : List(Str), listed : List(Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)])) } -> List({ path : Str, is_dir : Bool, mtime : U64 })` | R-CC2 |
| `Gc.report`, `Gc.data` | `Gc.Done -> List(Str)`, `Gc.Done -> JsonDoc` | R-OUT2, R-J3 |
| `CacheGc.run!` | `Fx, Args => I32` | R-CM17 |
| `Intent.Config` | `{ nightly, min_release_age, default_roc, gc_age : Try(U64, [Unset]) }`. `gc-age` is `"<n>d"` in seconds. | R-GC9 |
| `Temp.old` | Same type. A file `<16hex>.locks` in a `tmp` dir of a `talon` dir is a stale kind. | R-CC2 |

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/gc.roc` 1 (`read`, `age`) | No operand, `--dry-run` with the other global flags, 1 and 2 operands are `Usage`. The age: not set is 2592000, a set value, 0. | R-GC11, R-CM15, R-GC9 |
| L0 | 2 (`projects`) | A missing file, a text, a bad header, an entry older than the age (exactly the age stays, a time in the future stays), `Denied` stays, `gone` is sorted. | R-PD12, R-PD13 |
| L0 | 3 (`toolchains`) | 20 rows, the verdict of each: removed (a nightly, a release, a `git-*`, a fallback to `installed_at`), `Pinned` (the other tag form of the pin counts, an old use stays), `Used` (no pin, used in the age), `Default`, `LastDay` (3600 s, exactly 1 day, a time in the future, the fresh install), `Hand` (`link-*`, `copy-*`), `NoTime`. Then the age edge (exactly the age stays, 1 s more goes), a 60 s age (the last day is the floor, a pin keeps), no live project, a 7 day age. | R-GC5, R-CC10, R-GC9, R-EV22 |
| L0 | 4 (`scan_dirs`, `entries`, `Temp.old`) | The 6 dirs. The entries of a listing with full paths, an error gives none. With the real time: temp, trash, stale lock dir, probe copy and `.locks` older than 1 day go. The young ones, a package, a compiler dir, `projects.json` and a lock dir stay. | R-CC2, R-GC6 |
| L0 | 5 (`report`) | Another GC runs. Nothing to remove. A full run in the order of the lists. A dry run says `would remove` and ends with a line. | R-OUT2, R-GC11, R-CC10 |
| L0 | 6 (`data`) | The keys and their order. A busy run. A dry run. | R-J3, R-J4, R-OUT4 |
| L0 | `tests/unit/temp.roc` 4 | `<16hex>.locks`: a file in `talon/tmp` older than 1 day goes. A dir with the name, a short name, a non-hex name, `.lock`, another parent dir and another grandparent are not chosen. A day exactly stays. | R-CC2, R-GC6 |
| L0 | `tests/unit/intent.roc` 7 | `gc-age`: `"7d"`, `"30d"` with another key, `"0d"`, not set, no unit, hours, a number, empty. The failure has the file, the line and the key (exit 19). | R-GC9, R-TF4 |
| L2 | `gc/gc1-select` (8 runs) | 1 `--dry-run`: the text, no lock, no write. 2 `--dry-run --json`: the envelope on stdout, the text on stderr. 3 the real run: 14 toolchains in the store, 5 are chosen and 1 of them is skipped (busy), 9 stay (the reasons are in the `fx/commands` comments), the compat dirs, the 6 stale items go and the 3 young ones stay (the fake clock is 7 days before `TALON_NOW`), `projects.json` loses 3 entries. 4 the same again: only the skip. 5 an operand: exit 2. 6 a `projects.json` that does not parse: exit 19, no removal. 7 a bad `gc-age`: exit 19. 8 `gc-age` is 0 days: only the default and the last day keep a compiler that nothing pins (the floor of R-CC10). | R-GC5, R-GC3, R-GC6, R-GC9, R-GC11, R-CC2, R-CC10, R-EV22, R-PD12, R-PD13, R-CM15, R-TF4, R-TF6, R-J3 |
| L2 | `gc/gc2-busy` (4 runs) | Another GC holds `talon/gc`: 1 the line, exit 0, 4 calls only. 2 `--json`: `ran` false. 3 `--dry-run`: no lock, it lists. 4 an operand: no lock. | R-CC10, R-GC11, R-CM15, R-J3 |
| L3 | `cache/gc1-real` (7 parts) | The real binary and `Fx`, `gc-age = "7d"`. 1 the dry run: the listing of the store before and after is the same. 2 the lock dir of another GC with a live `beat`: the line, exit 0, nothing removed, the lock dir stays. 3 the lock dir of an install: that compiler is skipped, the other old ones go, the young items stay, `projects.json` is written. 4 the install ended: `--json` removes it. 5 nothing to remove. 6 `TALON_NOW` 7 months later: the toolchains and projects age, the young temps do not (the real clock). 7 an operand, `compat-other` and an app file stay, no lock dir is left. | R-GC5, R-GC3, R-GC6, R-GC9, R-GC11, R-GC1, R-GC8, R-CC2, R-CC10, R-EV22, R-PD13, R-CM15, R-J3 |

Count: 8 L0 `expect`s (6 in the new file, 1 in `temp.roc`, 1 in `intent.roc`), 2 L2 cases (12 runs), 1 L3 case (7 parts). No selftest row.

## 6. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| stdout, a run | One line for each item, in this order: `removed toolchain <id>` (each id of `toolchains`), `skipped toolchain <id>: an install holds it`, `removed <path>` (the compat dirs, then the stale paths), `removed project <path>`. The ids are in byte order, the paths too. |
| stdout, a dry run | The same, with `would remove` in place of `removed`. The last line is `dry run: nothing was removed`. |
| stdout, nothing to do | `nothing to remove` |
| stdout, another GC | `another tln cache gc runs` (exit 0) |
| `--json` `data` | `{"dry_run","ran","toolchains":[ids],"skipped":[ids],"compat":[paths],"stale":[paths],"projects":[paths]}`. `ran` is false when another GC holds the lock: all lists are then empty. The text goes to stderr. |
| Errors | `tln: error[usage]: tln cache gc takes no operand, got <n>`. `tln: error[input]: <path>: the content does not parse` (`projects.json`, exit 19). `tln: error[input]: <config>:<line>: gc-age: must be a number of days, for example "30d"` (exit 19). `tln: error[usage]: TALON_NOW is not a UTC time: <text>`. `tln: error[environment]: cannot remove <item>: <error>` (a `rename` that fails, exit 18). |

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | Replaced by D17 (the manager answered Q1). | Reading C of Q1 |
| D2 | The used time of a compiler is `.last-use` (R-CC9), else `installed_at` of `.talon.json`. With neither (no file, a bad file) it stays (`NoTime`). So a compiler that was installed an hour ago and never ran is not removed. | An unknown time is old. `installed_at` is not used. |
| D3 | "Used in the GC age" is `now - time <= age`. More than the age is old. A time in the future is not old (as `Temp.old` and `Projects`). `gc-age = "0d"` makes each unused toolchain old. | `<` in place of `<=` |
| D4 | A project entry whose file cannot be read for a reason other than a missing file (`Denied`, `Other`) stays and pins nothing. Only a missing file, a file with no header and an old entry leave (R-PD13). | The entry leaves |
| D5 | `link-*` and `copy-*` are never removed (R-GC5). A `git-*` build is removed by the rule of a nightly. A Zig dir (`toolchains/zig-<version>`) is no compiler row and GC does not touch it (gap G3). | |
| D6 | A dry run takes no lock (Q4) and writes nothing. It cannot know that an install holds a compiler, so it lists it, and the real run skips it. | The dry run takes the GC lock with `NoWait` |
| D7 | GC reads all it needs first (config, listing, `projects.json`, project files, `.talon.json` and `.last-use`), then removes. A failure while it reads (a `projects.json` that does not parse, a bad `gc-age`) ends the run with nothing removed: without the pins GC does not know what is safe. | A temp cleanup that goes on |
| D8 | The order of the removal: the compilers (in the order of the ids, each under its lock), then the stale paths (one `delete`), then the entries of `projects.json`. A `rename` that fails stops GC with exit 18 (the earlier removals stay). | The temps first |
| D9 | The dirs that GC lists are the 6 of `Gc.scan_dirs` (Q3). A temp in the config dir (`config.toml.<hex>.tmp`) or in the data dir is not found. | The config and data dirs too |
| D10 | `talon/tmp/<16hex>.locks` (the registry of a process, `RealLocks`) is a stale kind: a file with this name in `talon/tmp` that is older than 1 day (file time, real clock). A process that holds a lock for more than a day and a registry that GC removes only loses the heartbeat for the next wait. | Another age. No rule (a file stays for ever). |
| D11 | GC holds the GC lock for the whole run, also the project lock step (the order is `talon/gc`, then a toolchain, then `projects.json`: no two of these are held together). | |
| D12 | The second read of `projects.json` (step 11) applies only the entries that left at step 6. | The first decision is applied to the new text (an entry that a command added since is removed) |
| D13 | The compat dir of a removed compiler goes with it, also when another compiler uses the same compat id (Q6). | A check for other users |
| D14 | `gc-age` has the form `"<n>d"` of `min-release-age`, and is a field of `Intent.Config` (`gc_age`). | A separate reader `Gc.age_of(text)` |
| D15 | `--json` with another GC: the envelope has `ran: false` and empty lists. The line goes to stderr as the other text does. | An error exit code |
| D16 | `--quiet` hides the text as in the other commands (`Common.shown_fx`). No test row. | |
| D17 | R-GC5 is an OR (the answer of the manager to Q1, 2026-10-23). GC keeps the default, every toolchain that a live known project pins (any age), and every toolchain used in the GC age. The last day of R-CC10 stays as a floor, so a short `gc-age` still keeps a compiler used in the last day. Order of the reasons: `Hand`, `Default`, `LastDay`, `Pinned`, `Used`. | Reading C (pinned and used in the age) |

Answers of the user (`docs/slices/PLAN-P1.md`, `docs/slices/ANSWERS.md`) that bind this slice:

| Answer | Effect here |
| --- | --- |
| `--json --quiet`: the JSON envelope only (slice 007 D4) | `CacheGc` uses `Common.shown_fx`, so with both flags stdout is the envelope and stderr is empty. No test row for the 2 flags together. |
| The other answers | They are for commands that edit a header or choose a compiler. GC edits no project file, so none binds this slice. |

## 8. Out of scope

| Id | Reason |
| --- | --- |
| R-GC2, R-GC3 (second sentence), R-GC4, R-GC1 (the age rule part) | Part 2 (028b, section 0). It needs the newest file time of a tree: a new `Fx` call. |
| R-GC7 | Slice 049. No `x` entry and no record of its last use exist (R-X2). |
| R-GC8 (app installs are outside the cache root) | No code: GC lists only the 6 dirs. The L3 case shows that a file in `~/.local/bin` stays. |
| R-GC12 to R-GC14, R-NI7, R-NR3 | Slice 029 (`cache clean`). `cache gc` has no prompt. |
| The Windows rule of R-CC10 (the `rename` of a running compiler fails, exit 17) | The Windows CI job |
| A `rename` that fails (`Exists`, `Denied`) during the removal | The fake can make a `rename` fail only by a suffix for the whole run (`fx/rename`). Exit 18 is the decision D8, no test row. |
| Two processes at the same time: a `tln roc rm` or an install that starts between the listing and the toolchain lock | The lock and the last day rule are the guard (R-CC10). No stable L2 or L3 test. |
| `tln roc rm` shares the trash code | Not changed in this slice (slice 024 has it, N2 of the notes) |
| Temps of a lock holder (R-CC4 step 5, `Temp.of_item`) | Slice 021 and slice 002 |

## 9. Questions (TW17)

The reference has a default for each question. The tests fix the answer of Q1 and the default of Q2 to Q7, as the table says. A different answer changes the rows that the table names.

| # | Question | Default of the reference (tested) | Other option, and the rows that change |
| --- | --- | --- | --- |
| Q1 | R-GC5 says: "Keeps the default, and the toolchains that a known project pins and used in the GC age." Which reading? | Answered by the manager (2026-10-23): OR. Keep the default, every toolchain that a known project pins (any age), and every toolchain used in the GC age. The last day of R-CC10 is a floor (D17). Tested. | Reading C (the first test default): pinned and used in the age. Rows: L0 `gc` 3, L2 `gc1-select` runs 1, 3, 7, 8, L3 parts 1, 3, 6 |
| Q2 | A compiler with no `.last-use` and no `installed_at`: stay or go? | Stay (`NoTime`) | Go. Row: L0 `gc` 3 (`6666666`), L2 `gc1-select` (`7777777`) |
| Q3 | Which dirs does GC list for stale temps? R-CC2 says "the other temps". | The 6 dirs of the cache that Talon writes (`Gc.scan_dirs`) | Also the config dir and the data dir (a `config.toml.<hex>.tmp` that a crash left). Row: L0 `gc` 4 (the list of dirs), the first `list_dirs` line of each L2 run |
| Q4 | Does `--dry-run` take the GC lock? | No (D6) | Yes, with `NoWait`: the line when another GC runs. Rows: L2 `gc2-busy` run 3, L2 `gc1-select` runs 1 and 2 (a `lock` and an `unlock` line) |
| Q5 | Does `--dry-run` print the sizes ("prints what it would free")? | Not in part 1: the sizes need `Fx.tree_info!` (028b). The text has the items only. | Sizes in part 1 need the new call in this part. Rows: every `would remove` line |
| Q6 | The compat dir of a removed compiler: remove it when a compiler that stays has the same compat id? | Yes, as `roc rm` does (D13). The cost is a rebuild of the build cache of the other compiler. | Keep it. Row: none today (no fixture shares a compat id) |
| Q7 | An entry of `projects.json` whose file cannot be read (`Denied`): stay or leave? | Stay (D4). Tested in L0 `gc` row 2 only. | Leave. Row: L0 `gc` row 2 |

## 10. Design gaps found

| # | Gap |
| --- | --- |
| G1 | The R-GC5 sentence has two readings (Q1). |
| G2 | R-GC3 says that GC removes the compat dir of each compiler that it removes. It does not say what happens when 2 compilers share a compat id (Q6). |
| G3 | R-GC5 and R-LY1 name `toolchains/zig-<version>/`, but no GC rule says when a Zig dir goes. GC leaves it (D5). |
| G4 | R-CC2 names the temps, the `.trash` dirs and the probe copies. The registry file `talon/tmp/<16hex>.locks` that `RealLocks` writes (slice 002, Q8) is in none of them. D10 adds it. A line for it in R-CC2 would close the gap. |
| G5 | R-GC9 says that a last use of a toolchain is the time that Talon records (R-CC9), but R-CC9 is only the proxy and the probes. A compiler that was installed and never run has no `.last-use` (D2). |
| G6 | R-PD13 says GC removes an entry "when GC finds that its file is missing or has no header". It does not say what GC does for an unreadable file (Q7). |

## 11. Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| A nightly id needs 7 hex digits as the sha (`Compiler.installed` leaves out `nightly-2026-05-01-jjjjjjj`) | The fixtures use `6666666`, `9999999` and other hex digits |
| `touch -d` with a word date (`3 days ago`) is not portable | The L3 case uses `touch -d '2000-01-01 00:00:00'` (as `locks/cc12-lock-contract`) and the real time of a new file for a young item |
| The tree diff of the runners leaves out a name `tmp` and `*.tmp` (`tests/lib.sh`) | The stale temps are visible only in `calls.log` (L2) and in the `find` lines of the L3 `cmd` |
| The normalizer shows `$HOME2` and `$HOME3` for the second and third home of an L2 case | `expect/stderr` of `gc1-select` has them (as slice 024) |

## 12. Red output

`scripts/test.sh` with the stubs (2026-10-23). The old tests all pass. The log is `research/slice-028-revert/red.log`.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt | pass | The stubs compile. `roc fmt --check` passes. |
| L0 old files (59 files) | pass | |
| L0 `tests/unit/gc.roc` | red: 6 of 6 `expect`s fail | `Roc application crashed with this message: todo` |
| L0 `tests/unit/temp.roc` | red: 1 of 4 fails (the new `.locks` row) | A wrong value: `Temp.old` gives `[]` |
| L0 `tests/unit/intent.roc` | red: 1 of 7 fails (the new `gc-age` row) | A wrong value: `gc_age` is `Err(Unset)` for each text |
| L2 old cases (64) | pass | |
| L2 `gc/gc1-select`, `gc/gc2-busy` | red | `[ROC CRASHED] todo` (the test app writes no exit file) |
| L3 old cases (49, 1 skipped) | pass | |
| L3 `cache/gc1-real` | red | `[ROC CRASHED] todo` for each `tln cache gc` (the exit code is 1 in place of 0, 2 and the files are not removed) |
| selftest | pass | |

```text
tests/unit/gc.roc: FAILED   (6 failed: Roc application crashed with this message: todo)
tests/unit/temp.roc: FAILED (1 failed: the .locks row, got [])
tests/unit/intent.roc: FAILED (1 failed: the gc-age row)
FAIL gc/gc1-select   the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL gc/gc2-busy     the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL cache/gc1-real  stdout differs: +[ROC CRASHED] todo, tree.diff has the removals that did not happen
```

Times on the stub tree (warm cache, run after D17): check 1.3 s, fmt 0.1 s, l0 4.7 s, l2 2.4 s, l3 9.4 s, selftest 3.7 s. With the reference: check 1.3 s, l0 4.9 s, l2 1.8 s, l3 9.4 s, selftest 3.7 s, exit 0, no `WARN` line (`research/slice-028-revert/green.log`). Before the slice (`baseline.log`): check 4.7 s (cold cache), l0 4.8 s, l2 4.8 s, l3 9.4 s, selftest 3.7 s. The budgets of check and l0 are not at risk: the new L0 file adds 0.1 s. L3 is dominated by the build of `tln`, as before.

## 13. Check against the design (TW21)

The expected files of the 2 L2 cases and the L3 case were made by a private reference (`research/slice-028-revert/reference/`, deleted after the review of the manager, D17) and read by eye against the design. With the reference all 6 `expect`s of `gc.roc`, the new rows of `temp.roc` and `intent.roc`, the 2 L2 cases and the L3 case pass.

| File | What was checked |
| --- | --- |
| `gc/gc1-select/expect/calls.log` | The order of the calls against the table of section 2. The dry runs have no `lock`, no `random`, no `rename`, no `delete`, no `write_atomic`. The real run has the GC lock first and last, one `lock` and `unlock` for each toolchain that goes (and one `busy` line without `unlock`), `random`, `rename`, `delete` of the trash dir and the compat dir, then one `delete` of the stale paths, then the lock, `read_files` and `write_atomic` of `projects.json`. A run with a bad `projects.json` ends after its read, with an `unlock`. The bad `gc-age` ends after the read of `config.toml`. |
| `gc/gc1-select/expect/stdout`, `stderr` | The texts of section 6. In the `--json` run the text is in `stderr`. The ids and paths are in byte order. The second real run has only the skip line. |
| `gc/gc1-select/expect/tree.diff` | 4 compilers are gone (each with its `.talon.json`, `.last-use` and `roc`), 2 compat dirs, the old `.trash` dir and `projects.json` has 2 entries. The young items, `compat-6666666` (lock busy), `compat-other`, `compat-bbbbbbb`, the package, `link-dev`, `copy-fix-1`, the default and `zig-0.17.0` are not in the diff, so they stay. |
| `gc/gc2-busy/expect/calls.log` | The busy runs have 4 calls: `args`, `env_all`, `clock`, `lock ... busy`. The operand run has 1 call. The dry run has no `lock`. |
| `cache/gc1-real/expect/stdout` | Part 1: the listing before is the listing after. Part 2: the lock dir stays, nothing is removed. Part 3: the install lock dir stays, `compat-6666666` stays, 2 toolchains go (the age is 7 days: `ddddddd` is not pinned and used 10 days ago; `bbbbbbb` and `ccccccc` are pinned and stay, `eeeeeee` is used 3 days ago and stays), the young temps stay. Part 6: the young temps are not in the list, although `TALON_NOW` is 7 months later. |
| `cache/gc1-real/expect/tree.diff` | The same removals as `stdout`. `link-dev/.talon.json` has the path that the `cmd` wrote. |

## 14. Revert check (TW12)

Method: the private reference made all new tests pass. `research/slice-028-revert/mutate.py` applies one hand made mutation at a time to the reference, runs only the layers that should catch it (the 3 L0 files, the L2 cases `gc/`, the L3 case `cache/`), and puts the file back. No full sweep. Result: 38 mutations, 38 caught. After D17 the mutations M08 to M14, M40 and M41 were run again on the changed rows and caught (M13 now removes the pin test, M11 needs run 8 of `gc1-select`, M14 has a side condition). The first run (`mutate-run-1.log`) had 8 mutations that did not compile (an unused variable or a constant condition) or hit a doc line, and 1 with a wrong layer list. They were written again and caught (`results.md`). One more (M39, the second read of `projects.json` finds no file) is not tested: it is a race, and it was dropped.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Gc.read`, `Gc.age` (the operand text, the flag, the default age) | M01 to M03 | L0 (M01, M03 also L2, M02 also L2 and L3) |
| `Gc.projects`, `has_header`, `is_older` (the age test, a missing file, a file that cannot be read, the edge) | M04 to M07 | L0 (M04, M05 also L2 and L3) |
| `Gc.toolchains` (`copy-*`, the default, no time, the last day, the `installed_at` fallback, the pin and the age, a pin that is not looked at) | M08 to M14 | L0 and L2 (M09, M13, M14 also L3) |
| `Gc.scan_dirs`, `entries` (the package dir, the full path) | M15, M16 | L0 (M15 also L2) |
| `Gc.report`, `Gc.data` (the verb, the busy text, the key order, the last line) | M17 to M20 | L0 (M17, M18, M20 also L2 and L3, M19 also L2) |
| `Temp.old` (the `.locks` kind, the file check) | M21, M22 | L0 (M21 also L2) |
| `Intent.read_config` (the key `gc-age`) | M23 | L0, L2, L3 |
| `CacheGc`: the time for the temps, the time for the toolchains, the lock of a dry run, `NoWait` of the toolchain lock, the compat dir, the stale `delete`, `prune!` (not called, `valid` list), a `projects.json` that does not parse, `shown_fx`, the compat list of the dry run, a bad `config.toml`, the lock item, the busy result, a toolchain that is not removed | M24 to M38 | L2 (M24, M27 to M31, M34, M36, M37 also L3) |

Not mutated: the exit 18 of a `rename` that fails (D8), the text of `TALON_NOW is not a UTC time` (the same code as `Clock.now!`, slice 007), `--quiet` (D16).

## Review (manager, 2026-10-23)

| Item | Text |
| --- | --- |
| Split | Accepted. 028b is added to `PLAN-P1.md`. R-GC7 goes to 049. |
| D1 to D16, section 6, Q2 to Q7 | Accepted, with the defaults of Q2 to Q7. |
| Q1 | Change. Read R-GC5 as OR: GC keeps the default, every toolchain that a known project pins (whatever its age), and every toolchain used in the GC age. Reason: an old nightly can leave the release list, so a pinned compiler that GC removes may not download again. An unpinned compiler in active use (a `[toolchain] roc` range, `.roc-version`) must not be removed while it is used. The R-CC10 last-day rule stays as the floor for a run that started (it matters with a short `gc-age`). |
| Work asked | Change the `toolchains` rows (`ddddddd`, `ccccccc` and others) and the L2 and L3 expected files. Record it as D17. Update the private reference so all tests pass, run mutations for the changed rows and record them. Set status to `code`. Delete `research/slice-028-revert/reference/`. Confirm the red state with `scripts/test.sh`. |

Answers of the test agent:

| Item | Answer |
| --- | --- |
| D17 | Section 7. |
| L0 | `gc.roc` row 3: `ccccccc` is `Keep(Pinned)`, `ddddddd` is `Keep(Used)`, a 60 s age shows the floor. `Gc.Why` has the new tag `Used`. |
| L2 | `gc1-select`: `ccccccc` and `ddddddd` stay, 4 compilers go and 1 is skipped, run 8 (`gc-age = "0d"`, `home4`) tests the floor. |
| L3 | `gc1-real`: `ddddddd` (unpinned, 10 days) goes, `eeeeeee` (unpinned, 3 days) stays, the pinned ones stay. Part 6 (7 months later) removes `eeeeeee`, `bbbbbbb` and `ccccccc`. |
| Mutations | Section 14: M08 to M14, M40, M41 caught. |
| Reference | Deleted. The stubs are in `cli/lib` and `research/slice-028-revert/stubs/`. |

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The doc table of `CacheGc` has the order of the calls. The `calls.log` of the L2 cases fixes them, including the number of `read_files` calls and the `lock` lines. |
| N2 | `RocManage` has private `found_of` (the 2 reads of each id) and `move_to_trash!`. `CacheGc` can make its own copies (the reference does) or the code agent makes the 2 functions public. A local helper must not have the name of a method of its type module (slice 020 limit). |
| N3 | `Temp.old` gets the `.locks` rule in `is_stale_kind`. `Intent.read_config` reads `gc-age` with `days_of`, as `min-release-age`. |
| N4 | `Fx.with_lock!` with `NoWait` for the GC lock and for each toolchain. `Fx.locked!` (it waits) for `projects.json`: R-CC6. No `ask!` call in a lock (R-CC3 point 5). |
| N5 | The time for the age of toolchains and projects is `Clock.now` (pure, `TALON_NOW` or the real time). The time for the stale paths is the real `clock!`. One `clock!` call gives both. |
| N6 | Do not edit a test (TW18). A question goes to the manager. |

## Code result (code agent)

Result of `scripts/test.sh`: exit 0, no WARN on the warm run. check 7.3 s (first run after the edits 10.0 s, a WARN), fmt 0.1 s, l0 7.2 s (8 new `expect`s pass), l2 66 cases in 5.2 s (`gc/gc1-select` 8 runs, `gc/gc2-busy` 4 runs), l3 50 passed and 1 skipped in 9.4 s (`cache/gc1-real` 7 parts), selftest 3.7 s. `OPT=speed scripts/test.sh`: exit 0 (l2 77.9 s, `agent-speed.log`). Logs: `research/slice-028-revert/agent-run1.log`, `agent-run2.log`, `agent-run3.log` (the last run, after the mutations: no WARN). `roc check`: 0 errors, 0 warnings.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Gc.roc` | 180 | All 8 bodies. Private `judge` (one entry of `projects.json`), `is_over` (the one age test: more than the span, a time in the future is not old), `verdict_of` (the table of the doc), `used_time`. |
| `cli/lib/CacheGc.roc` | 184 | `run!`, `clocks_of` (pure), private `gc_flow!` (the lock), `work!` (steps 4 to 11), `known_projects!`, `remove_all!`, `prune!`, `prune_text!`, `print!`. |
| `cli/lib/Trash.roc` | 28 (new) | `Trash.move!`: `random!`, `rename!`, one `delete!` of the trash dir and the compat dir. Moved from `RocManage.move_to_trash!`. `roc rm` and `cache gc` both call it. |
| `cli/lib/Known.roc` | 84 | New `Known.entries!`: one `read_files!` of `projects.json`, `Projects.entries`. Moved from `RocManage.pinned!`. `cache gc` calls it too. |
| `cli/lib/Manage.roc` | 525 | New public `Manage.found_of` (the 2 reads of each id). Moved from the private `RocManage.found_of`. |
| `cli/lib/RocManage.roc` | 361 | Calls `Trash.move!`, `Known.entries!`, `Manage.found_of`. Same calls in the same order, so the `roc` L2 and L3 cases did not change. |
| `cli/lib/Intent.roc` | | `read_config` reads `gc-age` with `days_of` (as `min-release-age`). |
| `cli/lib/Temp.roc` | | `is_stale_kind` has the `.locks` kind (D10). |
| `cli/lib/main.roc` | | Exposes `Trash`. |

Decisions that the slice does not fix:

| Decision | Chosen | Rejected |
| --- | --- | --- |
| Shared code of `roc rm` and `cache gc` (N2) | 3 shared functions in 3 places that already own the topic: `Trash.move!` (new small module, because `Manage` is pure and `RocManage` would make `CacheGc` import a command module), `Known.entries!`, `Manage.found_of`. No copy. | A copy in `CacheGc` (the test agent reference did this). `RocManage` exposes its private functions. |
| The 2 times | `CacheGc.clocks_of` is pure over one `clock!` result and the env. `real` is for `Temp.old`, `now` is for toolchains and projects (N5). | Two `clock!` calls. |
| The old and header test order in `Gc.judge` | The age test first, then the read. An old entry with a `Denied` file leaves (R-PD13 names the age). Only a young entry with an unreadable file stays (D4). | `Denied` stays whatever its age |
| Two compilers with the same compat id | The compat path is listed once for each compiler (D13, Q6). A second `delete!` of a missing dir is not an error. No check for other users. | A dedup of the list |
| `with_lock!` for the GC lock | `Fx.with_lock!` with `NoWait`: `Err(Busy)` is the `ran: false` result, `Err(Failed)` is the failure. `Fx.locked!` (it waits) only for `projects.json` (N4). | none |

Disputes (from the code agent): none. No test, fixture or expected file was changed.

Questions (TW17): none. Compiler limits met: the local name `read` in `Gc.projects` is a duplicate definition with the method `Gc.read` (known limit, renamed to `got`). `roc check` of `cli/main.roc` takes 3.6 s with all 149 modules cached (Shared Monotype Lowering 3.3 s, peak RSS 14 GB), also with the 2 stub files of this slice put back. It was 0.8 s in `green.log`. So the check time is not caused by the new code, but I did not find the cause.

## Verify results (revert check, TW12)

`research/slice-028-revert/agent-mutate.py` puts `code-final/` back, makes one change, runs `roc check`, then the layers of the mutation in order (l0: `gc`, `temp`, `intent`; l2: `gc/`; l3: `cache/gc1-real`). The first failing layer ends the run of the mutation. Result: caught 44 of 44 (`agent-results.md`, `agent-mutate-run.log`). Two mutations did not compile at first (M25: unused variable, M42: unused variable). They were written again and caught. `cmp` of the 9 changed files of `cli/lib` against `research/slice-028-revert/code-final/cli/lib/` shows no difference after the run. No mutation is a test gap or an equal change. The L3 layer ran for none of them, because l0 or l2 failed first.

| Rule | Mutations | Caught by |
| --- | --- | --- |
| R-GC11, R-CM15, R-CM17 | M01 operand count, M02 flag name, M19 verb, M22 last line of a dry run, M30 a dry run takes the lock | l0 `gc`, l2 `gc/` |
| R-GC9 | M03 default age, M07 `>=` in place of `>`, M13 no `installed_at` fallback, M15 the age is fixed, M26 key `gc-age`, M27 `gc_age` not kept | l0 `gc`, `intent` |
| R-PD12, R-PD13 | M04 age edge, M05 a missing file stays, M06 an unreadable file goes, M08 a file with no header stays, M33 no prune, M34 prune keeps the entries that left, M44 `projects.json` missing is an error | l0 `gc`, l2 `gc/` |
| R-GC5 | M09 `copy-*` goes, M10 the default goes, M11 no time goes, M14 pin not looked at, M16 nothing is removed, M41 a compiler is never removed | l0 `gc`, l2 `gc/` |
| R-CC10 | M12 last day is 1 hour, M20 busy text, M23 skip text, M31 `Wait` in place of `NoWait`, M35 other lock item, M36 busy GC has `ran` true, M38 a busy compiler is not in `skipped`, M43 rename to itself | l0 `gc`, l2 `gc/` |
| R-CC2, R-GC6 | M17 `packages` not listed, M18 full path, M24 a dir `.locks` is stale, M25 `.locks` kind not used, M32 no `delete` of the stale paths | l0 `gc`, `temp`, l2 `gc/` |
| R-EV22 | M28 real time is the time of Talon, M29 time of Talon is the real time | l2 `gc/` |
| R-GC3 | M39 compat dir not in the list, M40 one compat dir missing in the dry run, M42 compat dir not deleted | l2 `gc/` |
| R-J3, R-J4 | M21 key order, M37 `--quiet` and `--json` text | l0 `gc`, l2 `gc/` |

Not mutated: the exit 18 of a `rename` that fails (D8: no test row), `--quiet` alone (D16), the race of the second read of `projects.json` (D12: no stable test).

## Close (manager, 2026-10-23)

Part 028a is done. The code agent decisions are accepted (`Trash.move!`, `Known.entries!` and `Manage.found_of` are shared with `roc rm`, no copy). The revert check caught 44 of 44. `scripts/test.sh` exits 0 with no WARN (warm). Part 028b is its own row in PLAN-P1.md. Status: done.
