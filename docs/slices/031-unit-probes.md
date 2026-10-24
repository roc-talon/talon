# 031 Unit probes and slots

Phase: P1. Status: done

Slice 031 adds ladder step 1 (R-LD2, R-LD3): a unit probe for each package of the closure of the candidate, in a pool of slots. It adds the scan of the used modules (R-UM1), the facts of the probes in `compat.db` (R-P4, R-PP4), the budget (R-P5), the `[probe]` keys and `--slots` (R-FL11). The slice is about 500 lines of code. It is not clearly too large (the plan says 400), so it is one slice. A split, if the manager wants one: 031a the pool and the keys (`RealJobs`, `Probe`, `Intent`, `Opts`, `--slots`), 031b the unit probes and the scan (`Units`, `Uses`, `Ladder.run!`).

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-LD2 (unit probe of a package: `check main.roc` in its dir) | `Units.nodes`, `Units.specs`, `Ladder.run!`, `Ladder.verify!`, `RemoveFlow` | L0 `units` 1. L2 `probe/un1-units` runs 1 to 19, `probe/un2-remove-units`, `probe/un3-verify-units` |
| R-LD3 (the same for the platform, other label) | `Units.judge`, `Units.results` | L0 `units` 3, 4. L2 run 8 |
| R-UM1 (a unit fail counts only for a used module) | `Uses.*`, `Units.suspects`, `Units.judge` | L0 `uses` 1, 2. L0 `units` 4, 5. L2 runs 5, 6, 14, 18 |
| R-AL4 (a unit probe for each pair (hash, compiler) with no fact) | `Units.missing`, `Facts.load!` | L0 `units` 1. L2 runs 3, 4, 12, 19 |
| R-PP2 (baseline and unit probes in one round) | `Ladder.run!` | L2 runs 1 to 19 (round 1 has both) |
| R-PP3 (results in the order of the list) | `Units.specs`, `Units.results`, `RealJobs.probes!` | L0 `units` 1, 3. L3 `fx/pl1-probe-pool` |
| R-PP4 (each probe that starts counts, facts written for each round) | `Ladder.run!`, `Units.budget` | L0 `units` 2. L2 runs 1, 9, 11, 16, 17. L3 `update/up2-unit-flags` (the printed count) |
| R-PP5 (a hang keeps its slots until the timeout) | `RealJobs.probes!` | L3 `fx/pl1-probe-pool` (last part) |
| R-PP6 (pool of 12 slots, check 1, build 4) | `Probe.weight`, `RealJobs.probes!` | L0 `probe` 1. L3 `fx/pl1-probe-pool` |
| R-PP7 (12 checks, 3 builds, a mix, `probe.slots`, `--slots`) | `Probe.settings`, `RealJobs.probes!` | L0 `probe` 2. L3 `fx/pl1-probe-pool`. L2 run 15 |
| R-P2 (a warning is a pass) | `Units.results` | L0 `units` 3. L2 run 10 |
| R-P3 (a signal from outside and a download error give no fact. A hang and a crash are facts) | `Units.results` | L0 `units` 3. L2 runs 8, 9 |
| R-P4 (fact for (hash, compiler, target `any`), the failing modules) | `Units.results`, `Facts.of_probe` | L0 `units` 3. L2 `tree.diff` (the facts) |
| R-P5 (`probe.max`, `probe.timeout`) | `Units.budget`, `Probe.settings`, `Intent` | L0 `units` 2, 6. L0 `probe` 2. L0 `intent`. L2 runs 11, 12, 15, 16, 17 |
| R-P8 (an error that the baseline hid shows as new: conservative) | `Ladder.check` (P0, no change) | L0 `ladder` (the row stays) |
| R-FL11 (`--slots <n>`) | `Opts`, `Probe.settings` | L0 `opts` 4. L0 `removal` 4. L2 run 15. L3 `update/up2-unit-flags` |
| R-CC9 (`.last-use` before each round, now more rounds) | `Ladder.probes_touched!` | L2 `roc/us1-use`, `consent/dl1-resolve` (the old cases, now with 3 rounds) |
| R-P6, R-EP7, R-UP7, R-EC12, R-LF3, R-CC8, R-NS12, R-EF1, R-LY4, R-TF4, R-LD7 | The cases above | Named in the cases |

`MISSING=1 scripts/rules.sh LD UM AL PP P FL CC` lists only the ids in section 8.

## 2. Flow (what the L2 case fixes)

`Ladder.run!` (install, add, update, upgrade, remove) and `Ladder.verify!` (verify) have the same steps for each member (review Q3). `roc use` runs no unit probe (R-U3: steps 2 and 3 only). The calls for one run, in order. A round is one `probes!` call.

| Step | Call | Rule |
| --- | --- | --- |
| 0 | `Start.run!` (as before) | R-PH7 |
| 1 | `Facts.load!`: one `db_query` with the keys of the packages of all closures (`Units.keys`). No package: no call. Busy or failed: warning and `[]` | R-EF1, R-CC8 |
| 1b | `remove` first walks the closure of the candidate header (the entries without the removed aliases): `list_dirs` of `packages`, `read_files` of the package headers (`ResolveBase.closure!`). A walk failure is the failure of the command. `verify` has its closures already (the tuple) | R-CM2, R-LD2 |
| 2 | For each member: `random`, `copy_tree`, `list_dirs`, `write_atomic` of the candidate header (as before) | R-LD4 |
| 3 | `Units.missing` for the packages of the closure of this member. `--no-probe`: none. `Units.budget` cuts the list | R-AL4, R-P5 |
| 4 | Round 1: `probes!` with the baseline and the unit probes (order: baseline, then the nodes in the order of the closure). `Launch.touch!` before it (as before) | R-PP2, R-PP3 |
| 5 | `Units.results`, then one `db_write` with `existing=replace` (no row: no call). Then `Ladder.baseline` (a failure stops). Then the first output with no fact is a failure `Internal` | R-PP4, R-P3 |
| 6 | `Units.suspects`. When there is one: the scan of the used modules, one `read_files` for each level (a package member starts at the exposed modules). Then `Units.judge`: exit 10 with the blame | R-UM1 |
| 7 | The budget cut of step 3: exit 12 | R-P5 |
| 8 | Round 2: `probes!` with the candidate check. `Ladder.check`. Round 3 (apps): the build. `Ladder.build`. Each round needs a probe that fits in `probe.max` | R-LD4, R-LD5, R-P5 |
| 9 | `delete` of the copy (also after a failure) | R-CC2 |

`verify!` has no copy: `random`, `make_dirs`, then rounds 1, 2 and 3 as above with the candidate check in the project dir with `--replace-dep` (the baseline and the candidate are two rounds now, as in `run!`). The unit probe is `<compiler> check main.roc` with the dir `<cache>/packages/<hash>` (no temp dir: the existing copy dir is the only temp dir of the ladder). Its fact key is `(hash, Start.Started.id, any)`.

## 3. Files

| Path | Lines | State |
| --- | --- | --- |
| `cli/lib/Units.roc` | 97 | New. 9 stubs `crash "todo"` with the contract in the docs |
| `cli/lib/Uses.roc` | 50 | New. `edges`, `level`: `crash "todo"` |
| `cli/lib/Probe.roc` | +30 | `Spec.weight`; `weight`, `Keys`, `Settings`, `settings` (stubs) |
| `cli/lib/Intent.roc` | +30 | `resolution.probe` and `Config.probe` (`Probe.Keys`). The stub gives `Unset` |
| `cli/lib/Opts.roc` | +6 | `slots` (the stub gives `Unset`) |
| `cli/lib/Removal.roc` | +4 | `Opts.no_probe`, `Opts.slots` (pass-through) |
| `cli/lib/ResolveBase.roc` | +8 | `Request.probe`, `probe_settings` (the stub gives the defaults) |
| `cli/lib/Fx.roc`, `cli/RealFx.roc`, `cli/RealJobs.roc`, `cli/fxprobe.roc` | | `probes!` takes `{ pool, specs }`. `RealJobs.probes!` still starts all probes at once (stub). `fxprobe pool <slots> ...` and the word `weight=<n>` |
| `cli/lib/Ladder.roc` | +30 | `Checked` has `text`. `verify!` has `no_probe`, `closures` and gives `probes`. | `weight` in the plans, `run!` has `probe`, `no_probe`, `closures` and gives `probes`. The stub keeps the P0 behavior and the old count |
| Flows: `InstallFlow`, `RemoveFlow`, `VerifyFlow`, `RocUse`, `Install`, `Update`, `Remove`, `Verify`, `Ls`, `main` | small | Pass the new fields (`closures`, `probe`) |
| `tests/unit/units.roc` | 243 | New. 6 `expect`s |
| `tests/unit/uses.roc` | 111 | New. 2 `expect`s |
| `tests/unit/probe.roc`, `intent.roc`, `opts.roc`, `removal.roc` | +32, +108, +50, +40 | 2, 2, 1, 1 new `expect`s |
| `tests/unit/ladder.roc`, `verify.roc` | | The `Spec` rows have `weight` (they pass) |
| `tests/fixtures/check/` | | `make.sh` has `ONLY=unit`. 4 sources `src/unit-*` and 16 real outputs of the pinned roc `out/unit-*` |
| `tests/commands/FakeJobs.roc`, `FakeFx.roc`, `main.roc` | | The fake `probes!` has the pool and `fx/units`. The entry `resolve` reads `no-probe` and `slots=<n>` |
| `tests/commands/cases/probe/un1-units/` | 19 runs, 73 files | New L2 case. Made by `research/slice-031-revert/gen-un1.py` |
| `tests/commands/cases/probe/un2-remove-units/`, `un3-verify-units/` | 5 and 3 runs | New L2 cases (review Q3). Made by `gen-un23.py` |
| `tests/scenarios/fx/pl1-probe-pool/` | 1 file `cmd` | New L3 case |
| `tests/scenarios/update/up2-unit-flags/` | | New L3 case (the project of `update/up1-update-entries`) |
| 20 old L2 cases | 4 `fx` files, 20 `expect` dirs | Section 6 |
| 4 old L3 cases | | Section 6. They get a new `expect/facts.tsv` |
| `research/slice-031-revert/` | | `before/` (old files, `NEW.txt`), `stubs/`, scripts (the private reference is deleted, review 2026-10-23), `results.md`, `red-run.log` |

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Probe.Spec` | has `weight : U64` | R-PP6 |
| `Probe.weight` | `Command -> U64` (Check 1, Build 4) | R-PP6 |
| `Probe.Keys` | `{ max, timeout, slots, max_toolchains : Try(U64, [Unset]) }` | R-P5 |
| `Probe.Settings` | `{ max, timeout, slots, max_toolchains : U64 }` (100, 30, 12, 10) | R-P5, R-PP7 |
| `Probe.settings` | `{ flag_slots : Try(U64, [Unset]), project : Keys, user : Keys } -> Settings` | R-LY4 |
| `Units.nodes` | `List(Closure.Walked) -> List(Units.Node)` | R-LD2 |
| `Units.keys` | `{ nodes, nightly } -> List(Db.Key)` | R-EF1 |
| `Units.missing` | `{ nodes, nightly, facts } -> List(Units.Node)` | R-AL4 |
| `Units.specs` | `{ nodes, compiler, program, env, pkgs, timeout } -> List(Probe.Spec)` | R-PP3, R-PP6 |
| `Units.budget` | `{ max, started, fixed, wanted } -> Try({ run, cut }, [Spent])` | R-P5 |
| `Units.results` | `{ nodes, outputs, nightly, compiler, pkgs } -> { facts, failure : Try(Fail, [None]) }` | R-P2 to R-P4 |
| `Units.suspects` | `{ nodes, facts, nightly, baseline } -> List(Units.Node)` | R-UM1 |
| `Units.judge` | `{ nodes, facts, nightly, compiler, baseline, used } -> Try({}, Fail)` | R-LD2, R-UM1 |
| `Units.spent` | `{ max, left } -> Fail` | R-P5, R-EC12 |
| `Uses.edges` | `Closure.Walked -> List(Uses.Edge)` | R-UM1 |
| `Uses.level` | `{ project_dir, pkgs, edges, sources, seen } -> { used, next }` | R-UM1 |
| `Fx.probes!` | `{ pool : U64, specs : List(Probe.Spec) } => List(Probe.Output)` | R-PP6 |
| `Ladder.run!` | the request has `probe : Probe.Settings`, `no_probe : Bool`, `closures`. The result has `probes : U64` (the number of probes that started) | R-PP4 |
| `Opts.slots` | `Try(U64, [Unset])` | R-FL11 |
| `Intent` | `resolution.probe`, `Config.probe : Probe.Keys` | R-P5, R-TF4 |

## 5. Tests

| Layer | Case | Checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/units.roc` 1: nodes, keys, missing, specs (11 rows) | the closure rows, shared hash once, key target `any`, a fact of another compiler is no fact, the spec of a unit probe | R-LD2, R-AL4, R-EF1, R-NS12, R-PP3, R-PP6 |
| L0 | `units` 2: budget (10 rows) | cut, exactly full, started before, spent | R-P5, R-PP4, R-UP7 |
| L0 | `units` 3: results (8 real outputs, kills, no start) | pass, fail with modules, warnings only, hang, crash, foreign file, no fact and the first failure | R-P2 to R-P4, R-RC1 to R-RC4, R-PP3 |
| L0 | `units` 4: judge (15 rows) | used modules, `main.roc`, no module, hang, crash, 2 blames in order, baseline excuse, another compiler | R-LD2, R-LD3, R-UM1, R-P6, R-EP7, R-PH10 |
| L0 | `units` 5: suspects (9 rows) | the nodes that need the scan | R-UM1, R-P6 |
| L0 | `units` 6: spent (3 rows) | the failure text | R-P5, R-EC12 |
| L0 | `uses.roc` 1, 2: edges, level (5 rows) | aliases of app and package headers, local imports, cycle, no repeat | R-UM1, R-LD7 |
| L0 | `probe.roc` 1, 2: weight, settings (7 rows) | check 1, build 4. The layers flag, talon.toml, config.toml, default | R-PP6, R-P5, R-PP7, R-LY4 |
| L0 | `intent.roc` 2: talon.toml and config.toml probe keys (12 rows each) | whole numbers, 0, bad values with the line, unknown key | R-P5, R-TF4, R-LY4 |
| L0 | `opts.roc` 1, `removal.roc` 1: `--slots` | value forms, 0 and text are usage errors | R-FL11 |
| L0 | `ladder.roc`, `verify.roc` (old rows) | `Spec` with `weight`, R-P8 row stays | R-PP6, R-P8 |
| L2 | `probe/un2-remove-units` (5 runs) | `remove`: the walk of the candidate closure, 2 unit probes, the facts known, a unit fail with the scan (exit 10 with the `remove` text), `--no-probe` with a known fact, `--no-probe` with no fact | R-LD2, R-UM1, R-AL4, R-PP4, R-LF3 |
| L2 | `probe/un3-verify-units` (3 runs) | `verify`: unit probes of the tuple, 3 rounds, the scan, known facts, a fail that the app does not use is ignored | R-CM11, R-LD2, R-UM1, R-AL4, R-PP4 |
| L2 | `probe/un1-units` (19 runs) | the flow of section 2 and the rows of `rules` | R-LD2, R-LD3, R-UM1, R-AL4, R-PP2 to R-PP4, R-P2 to R-P6, R-FL11, R-LF3, R-LY4, R-LD7, R-EC12 |
| L3 | `fx/pl1-probe-pool` (8 parts) | 13 checks at most 12 at once, 4 builds 3 at once, 1 build and 9 checks 9 at once, a pool of 2 and of 1, FIFO, weight above the pool, a hang keeps its slot | R-PP3, R-PP5, R-PP6, R-PP7 |
| L3 | `update/up2-unit-flags` (6 commands, `facts.tsv`) | `--no-probe`, `--slots 0` and `--slots many`, the facts written once and then known, the printed probe count | R-LF3, R-FL11, R-PP4, R-AL4 |
| L3 | 4 old cases | the printed count and the extra `check main.roc` lines, `facts.tsv` | R-PP4 |

Counts: 14 new L0 `expect`s (units 6, uses 2, probe 2, intent 2, opts 1, removal 1), 3 L2 deep cases (19, 5 and 3 runs), 2 L3 cases. The brief asks for about 5 to 20 L0 and 2 to 6 deep tests.

## 6. Changes of old tests (on purpose)

The ladder has 3 rounds now: round 1 baseline and units, round 2 the candidate, round 3 the build. Each run that has a closure also makes one `db_query`, and a `db_write` when units ran. The printed `probes` count is the number of probes that started.

| Old test | Change | Script |
| --- | --- | --- |
| 28 L2 cases (`consent/dl2-verify-workspace`, `gaps/g1-slice009`, `probe/pb2-verify`, `verify/vf1-flow`, `workspace/ws2-verify-members` and the 20 that follow, review Q3: `remove` and `verify` too) (`consent/dl1-resolve`, `dl3-rank4`, `install/in1-flow`, `ladder/ld-ladder-flow`, `ld-no-check-refuse`, `moves/hm1-noninteractive`, `hm2-interactive`, `probe/pb1-ladder`, `remove/rm1-flow`, `resolve/rs-highest-use`, `rs-install-add-key`, `rs-new-toml`, `rs-unmanaged`, `rs-update-scope`, `rs-workspace-shared-group`, `roc/so1-ranks`, `us1-use`, `us2-workspace`, `us3-step`, `update/up1-flow`) | `calls.log`: `db_query`, unit probe lines, rounds, `db_write`, more `.last-use` writes. `tree.diff`: the new `compat.tsv`. `stdout` and `stderr`: only the number in `N probes`, and `"probes":N` | `update-l2.sh`, `check-diff.py` (it lists each line of another kind: none left) |
| `install/in1-flow`, `remove/rm1-flow`, `roc/us1-use` | `fx/hooks`: `after-probes <n>` counts `probes` calls, so n moves (5 and 8, 9, 46). The hook still fires after the candidate check of the same run | by hand, old file in `before/` |
| `ladder/ld-ladder-flow` | `fx/probes`: run 4 (the baseline hangs) had a row for the candidate check. The candidate does not start now (the baseline is round 1), so the row is removed. Without this, the rows of the next runs shift | by hand |
| `remove/rm1-flow` (L2), `remove/rm1-remove-entries`, `remove/rm2-workspace` (L3) | Fixtures: the closure walk of `remove` reads the headers of the packages, so the cache of the case gets 7, 7 and 2 package headers (`given/home/.cache/roc/packages/`), and L3 `rm1-remove-entries` gets `given/util/main.roc` for its path entry. Without them the walk tries a download and the command fails | by hand, listed in `before/NEW.txt` |
| 10 L3 cases (`add/ad1-add-entries`, `add/ad2-platform-json`, `install/in1-workspace-frozen-rename`, `update/up1-update-entries`, `compilers/dl1-resolve-consent`, `dl3-rank4-download`, `pb1-probes-by-path`, `remove/rm1-remove-entries`, `rm2-workspace`, `verify/vf1-verify`) | `stdout`, `stderr`: the probe count. `roc.log`: more `check main.roc` lines. New `facts.tsv` | `update-l3.sh`, `check-diff3.py` |

The files of the old cases are in `research/slice-031-revert/before/`.

## 7. Output (proposed, TW24, R-OUT2)

| Text | Where |
| --- | --- |
| `no tuple works: the unit check on <compiler> fails for <blame>; <blame>` (exit 10). `<blame>` is `<name> <version> (<module>, <module>)`, `(hangs)`, `(crashes)`, `(no module is named)`. A platform: `the platform <name> <version>` | `Units.judge` |
| `the unit check of <label> on <compiler> gave no result: <text>. Run the command again.` (exit 1) | `Units.results` |
| `the probe budget is spent: probe.max is <n>. Set probe.max higher.` and, with units left: `... probe.max is <n> and <k> unit check(s) did not run. Run the command again to go on (the facts are saved), or set probe.max higher.` (exit 12) | `Units.spent` |
| `--slots must be a whole number of 1 or more, not '<value>'` (exit 2) | `Opts` |
| `<path>:<line>: <table>.<key>: must be a whole number` or `must be 1 or more`. `<path>:<line>: unknown key <table>.<key>` (warning). `<table>` is `resolution.probe` or `probe` | `Intent` |
| `resolved at <time>, <n> probes` and `--json` `data.probes`: n counts the probes that started (it was 2 or 3 by the plan) | `Ladder.run!` |

## 8. Out of scope

| Rule or part | Reason |
| --- | --- |
| R-PP1 (a compiler download takes no slot, runs at the same time) | The optional compiler downloads are slice 036. The required download is before round 1 (`Start.run!`, no slot) |
| R-PP2: 3 nightlies of a range, the build of each workspace member in parallel, the releases of `tool install` option 2 | Slices 036, 037, 047. P1 runs one compiler. Workspace members are probed one after the other (as in P0) |
| R-AL4 order "installed nightly first, then the strongest hint" | One compiler in this slice. Slice 036 |
| A build fact and the used-closure digest | Slice 032 |
| The consumer of `probe.max-toolchains` | Slice 036 (the key is read and tested) |
| A path package in the scan (R-LD7) | Its files are app files. `Uses.edges` drops its links |
| Unit probes in `roc use` | Review Q3: `roc use` runs steps 2 and 3 only (R-U3) |
| The shortest hang test | `Spec.timeout` is whole seconds: the L3 hang case waits 1 s (it runs in parallel with the other cases) |

## 9. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | 3 rounds: round 1 baseline and units, round 2 the candidate, round 3 the build. A failed baseline or unit stops before the candidate | Baseline and candidate in one round (as P0): a unit fail would cost a wasted check, and the ladder order R-LD1 is 1, 2, 3 |
| D2 | The unit probe is `check main.roc` in `<cache>/packages/<hash>`. The report names a module as `Yaml.roc` (measured with the pinned roc). No temp dir for a unit probe | An absolute path (roc cuts a long path at the left) |
| D3 | The key is `(hash, Start.Started.id, any)`. The same fact for a package and a platform | The id of `held` |
| D4 | Facts: one `db_query` at the start for all closures, one `db_write` with `existing=replace` after each round, before the verdict. A known fact is not probed again | A write at the end (a failure would lose the facts) |
| D5 | `--no-probe`: no new unit probe, the known facts still judge | `--no-probe` ignores the facts |
| D6 | The scan only when a unit fail has a module that the baseline does not explain. It reads one level for each `read_files` call. `main.roc` is always used | A scan for every run |
| D7 | A unit fail with no module is a hard fail (Q4 of slice 030). A hang and a crash blame the tuple (R-EP7) | |
| D8 | Each probe that starts counts for `probe.max`: baseline, units, candidate, build. The units are cut to what is left after the baseline. A candidate or build that has no probe left: exit 12 | Only unit probes count |
| D9 | `slots` and `timeout` need 1 or more. `max` and `max-toolchains` can be 0 | 0 for all |
| D10 | A weight above the pool takes the whole pool. The pool starts probes in FIFO order | Skip a probe that does not fit |
| D11 | `probe.timeout` is the timeout of every probe of the ladder (also of `verify` and `roc use`) | Only unit probes |
| D12 | `probe` in `talon.toml` that is not a table: `resolution.probe: must be a table` (exit 19) | A warning |
| D13 | Member scope: each member probes the packages of its own closure. A workspace has one `db_query` for all | One round for all members |

## 10. Questions (TW17)

| # | Question | Default in the tests |
| --- | --- | --- |
| Q1 | R-P6 says an error of the baseline is not new. R-UM1 does not say whether a unit fail in a module that the baseline already has is a hard fail. Is it excused? | Excused (same hash and module). Runs 1 and 2 |
| Q2 | Which probes count against `probe.max`? R-P5 says "100 checks", R-PP4 says each probe that starts, R-SM4 says a smoke build does not | All probes that start (D8). L0 `units` 2, L2 runs 11, 12, 16, 17 |
| Q3 | Do `remove`, `verify` and `roc use` run unit probes? | Answered in the review: yes for `remove` and `verify`, no for `roc use` |
| Q4 | R-BL6 says unit probes run with `--no-check`. R-SO22 says `--no-check` runs no probe and needs no compiler | No probe with `--no-check` (the old cases stay). Waiting for U3 (the user decides) |
| Q5 | The least value of each key: is `slots = 0` or `timeout = 0` an error? | 1 or more for both. 0 is a value for `max` and `max-toolchains` |
| Q6 | The text and the exit code of a bad `--slots` | Exit 2 (usage) with the text of section 7 |

## 11. Design gaps found

| Gap | Where |
| --- | --- |
| R-BL6 and R-SO22 disagree about `--no-check` and the unit probes (Q4) | Resolution 4 "Baseline check", CLI R-SO22 |
| R-PP2 runs the baseline with the first unit checks in parallel, but R-LD1 is 1, 2, 3 and the candidate check needs the baseline: the round structure is a decision (D1) | Resolution 4 |
| R-P5 "checks" and R-PP4 "probes" count different things (Q2) | Resolution 4 |
| `--no-probe` is in slice 036 (R-LF2) but the flag is in the P0 request: this slice uses it for the units only | PLAN-P1 |

## 12. Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| `roc build` exits 2 on a warning (constant `if`, unused variable or parameter) | The revert check needs mutations that keep every name used |
| `module` is a reserved word | `Uses.roc` uses `file_name` |
| `{ output }` alone is a block | `Build({ output: output })` |
| `??` with a `Try` as default does not work | `FakeJobs` uses a nested `match` |
| `I64` has `to_u64_wrap`, not `to_u64` | `Intent.read_probe` |
| Untyped number literals in an `expect` are `Dec`, so `Str.inspect` shows `30.0` | `units.roc` has a typed `spec` helper |

## 13. Red output

Run with the stubs in the tree (`research/slice-031-revert/red-run.log`).

| Step | Result |
| --- | --- |
| check | pass (1.0 s) |
| fmt | pass |
| l0 | FAIL (5.9 s): `units` 0 of 6 (todo), `uses` 0 of 2 (todo), `probe` 2 failed (todo), `intent` 2 failed (the probe keys are `Unset`), `opts` 1 failed (`--slots 4` gives `Unset`), `removal` 1 failed (the same) |
| l2 | FAIL (3.3 s): 51 passed, 21 failed: `probe/un1-units` and the 20 old cases of section 6 (the stub has the P0 calls: no `db_query`, `probes 2`, no unit probe) |
| l3 | FAIL (9.6 s): 53 passed, 6 failed: `fx/pl1-probe-pool` (`max at once: 13` where 12 is expected, 4 where 3), `update/up2-unit-flags`, and the 4 old cases of section 6 |
| selftest | pass (7.9 s) |

All other old tests pass. Budgets (TW26): check 10, l0 10, l2 30, l3 60, selftest 20: all inside. The case `fx/pl1-probe-pool` runs about 8 s (parallel with the others).

## 14. Revert check (TW12)

79 changes (and 10 more for review Q3, all caught, see results.md) of the private reference, one at a time, in `research/slice-031-revert/mutate.py` (list and result in `results.md`). Each was run with the steps that can see it: the L0 file, L2, or the L3 case. Result: 79 caught, 0 not caught. The first run found 4 gaps, now closed:

| Gap | Fix |
| --- | --- |
| `talon.toml` over `config.toml` for `max`, `timeout`, `max-toolchains` was not seen by L0 | A row in `probe.roc` |
| No test that the candidate check and the build need a probe in `probe.max` | L2 runs 16 and 17 |
| No test of a package member (scan starts at the exposed module) | L2 run 18 |
| No test that a member probes only its own closure | L2 run 19 (a workspace of 2 apps) |

Not mutated: the skip-ahead of the pool (a probe that does not fit lets the next one pass). The L3 FIFO part checks it by time (`c1` starts about 0.5 s after `b1`).

## Review (manager, 2026-10-23)

Accepted: D1 to D13, the output proposals of section 7, the changes of old tests of section 6 (with the 4 edited input files), and the defaults of Q1 (yes, R-P6), Q2 (every started probe counts, R-PP4), Q5 and Q6.

Changes:

| Item | Decision |
| --- | --- |
| Q3 | R-CM11 says `verify` runs the probe ladder, and the ladder includes step 1. So unit probes run in every command that resolves a tuple with the ladder: `install` and `add`, `update`, `upgrade`, `remove` and `verify`. `roc use` runs only the baseline check and the final ladder (R-U3: steps 2 and 3), so no unit probes there. The test agent changed the tests of `remove` and `verify` and their old expected files (section 6, the cases `probe/un2-remove-units` and `un3-verify-units`) |
| Q4 | R-BL6 says unit probes still run with `--no-check`. R-SO22 says `--no-check` runs no probe. This is a real conflict. It goes to the user as U3. The tested default (no probe with `--no-check`) stays, waiting for U3 |

Notes for the code agent from the change: `RemoveFlow.removal_ladder!` walks the closure of the candidate header (`ResolveBase.closure!` with the entries without the removed aliases) and passes it as `closures`. `VerifyFlow` passes its `closures`, `no_probe` and the header text of each member (`Ladder.Checked.text`). Both flows print `done.probes`. A failed walk in `remove` is the failure of the command (the test agent chose this; fixtures got the package headers).

## Code result

`scripts/test.sh` exits 0 (check 1.0 s, fmt 0.1 s, l0 5.8 s, l2 1.8 s, l3 9.7 s, selftest 7.9 s). `OPT=speed scripts/test.sh` exits 0 too (l2 88 s, no WARN line for speed). The L3 case `fx/pl1-probe-pool` passed 3 times in a row (and in each full run).

| File | Lines | What |
| --- | --- | --- |
| `cli/lib/Units.roc` | 191 | The 9 stubs: `nodes`, `keys`, `missing`, `specs`, `budget`, `results`, `suspects`, `judge`, `spent` |
| `cli/lib/Uses.roc` | 108 | `edges`, `level` (lexical scan, `Imports.scan` of `roc-app-header`) |
| `cli/lib/UnitFlow.roc` | 152 | New, command code of step 1: `probes!`, `first!` (round 1), `verdict!`, `step!` (rounds 2 and 3), `texts!`, `scan!` |
| `cli/lib/Ladder.roc` | 574 (was 555) | `run!` and `verify!` call `Facts.load!` once and `UnitFlow` for each member (3 rounds). `Pair` has `facts` and `count`. The timeout of each probe is `request.probe.timeout` (the constant 30 is gone). Under 600 lines: no split |
| `cli/lib/Probe.roc` | 307 | `weight`, `settings` |
| `cli/lib/Intent.roc` | 571 | `read_probe`, `probe_number` (both tables) |
| `cli/lib/Opts.roc` | 116 | `slots_of` |
| `cli/lib/ResolveBase.roc` | 579 | `probe_settings` |
| `cli/lib/RemoveFlow.roc` | 315 | The closure walk (`ResolveBase.closure!` with the entries minus the removed aliases, only when the ladder runs). `read_sources!` moved to `UnitFlow.texts!` |
| `cli/RealJobs.roc` | 239 | The slot pool of `probes!`: FIFO, weights added, a weight above the pool takes the whole pool |
| `cli/lib/main.roc` | 113 | `UnitFlow` in the exposed list |

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | New module `UnitFlow` for the command code of step 1. `Ladder` cannot import it back, so the baseline and the verdict are two calls (`first!`, then `Ladder.baseline`, then `verdict!`) | All in `Ladder.roc` (it would pass 600 lines) |
| C2 | `probes_touched!` moved from `Ladder` to `UnitFlow.probes!` (same body) | A copy |
| C3 | The `compiler` of a unit `Spec` is `Start.Started.id` (the L2 case `probe/pb1-ladder` shows the long id). The text of the blame uses `request.held`, as the other ladder texts do | `held` for the spec |
| C4 | The line of a bad key in a `talon.toml` is the line of the key, else the line of the table (when `Toml.line` has no entry for the key). The keys are checked in a fixed order (`max`, `timeout`, `slots`, `max-toolchains`), unknown keys by name | Order by line only (a tie on one line has no stable order) |
| C5 | The facts of one member are given to the next member (`Pair.facts`), and the count of started probes too (`Pair.count`): a hash that two members share is probed once, and `probe.max` is for the whole command | A fresh state for each member |
| C6 | `RealJobs.probes!`: a pool of 0 is 1, a weight of 0 is 1 (R-PP6: at least 1 slot) | A crash |
| C7 | A `remove` that runs no ladder (`--no-check`, a forced run) does no closure walk | A walk for each `remove` |
| C8 | The scan reads the header text of the member that the command already has (`Member.text`, `Checked.text`), not the file again. A file that cannot be read is skipped (question Q7 of slice 008) | A new read of the project file |

No test, fixture or expected file was changed. No design file was touched. No new question. Q4 (no probe with `--no-check`) stays as tested, waiting for U3.

## Disputes (from the code agent)

None.

## Verify results

Revert check of the code agent (TW12), `research/slice-031-revert/agent-mutate.py`, result `agent-results.md`, log `agent-mutate.log`. 62 small mutations of the final code, one at a time, each run with the steps that can see it (the L0 file, L2, or the L3 case). The final code is in `research/slice-031-revert/code-final/`: it is restored before and after each mutation, and at the end `cmp` of all files of `cli/` with it shows no difference. Result: caught 62 of 62, not caught 0. In the first runs 4 mutations did not compile (a warning or a type error) and 1 matched 2 places: they were made valid and run again (all caught).

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Probe` (weight, layers, defaults) | p1 to p4 | L0 `probe` |
| `Opts` (`--slots`) | o1, o2 | L0 `opts` |
| `Intent` (least values, unknown key, table name, whole number) | i1 to i5 | L0 `intent` |
| `ResolveBase` (layers of the settings) | r1, r2 | L2 `probe/un1-units` |
| `Units` (nodes, keys, missing, specs, budget, results, judge, suspects, spent) | u1 to u15 | L0 `units` |
| `Uses` (edges, local files, no repeat, owner of an alias) | s1 to s4 | L0 `uses` |
| `UnitFlow` (`--no-probe`, budget, outputs, save, scan, failure first) | f1 to f12 | L2 `probe/un1-units`, `consent/dl1-resolve`, `ladder/ld-ladder-flow` |
| `Ladder` (keys of all closures, facts and count of members, verdict, nodes, timeout, verify) | l1 to l9 | L2 `probe/un1-units`, `consent/dl1-resolve`, `consent/dl2-verify-workspace`, `moves/hm1-noninteractive` |
| `RealJobs` (pool size, weight clamp, FIFO, hang, slot release) | j1 to j6 | L3 `fx/pl1-probe-pool` |
| `RemoveFlow` (the closure of `remove`, `--no-probe`) | m1 to m3 | L2 `consent/dl1-resolve`, `probe/un2-remove-units` |

Rule ids: each rule of section 1 has at least one mutation (R-LD2, R-LD3 `u12`, R-UM1, R-AL4, R-PP2 `l8`, R-PP3, R-PP4, R-PP5, R-PP6, R-PP7 `p4`, R-P2 `u13`, R-P3, R-P4, R-P5, R-P6 `u10`, R-FL11, R-LY4, R-LF2, R-LF3, R-EP7 `u11`, R-EF1, R-CM11 `l9`, R-LD7). Not mutated: R-CC9 (`UnitFlow.probes!` is the old body, the old L2 cases check the `.last-use` lines) and R-P8 (no change of `Ladder.check`).

Other runs: `scripts/test.sh` and `OPT=speed scripts/test.sh` exit 0. `L3 fx/pl1-probe-pool` 3 runs, all pass.

## Close (manager, 2026-10-23)

C1 to C8 of the code agent are accepted (UnitFlow holds step 1, no copy). The revert check caught 62 of 62. Q4 waits for the user (U3). `scripts/test.sh` exits 0 with no WARN. Status: done.
