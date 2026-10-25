# 054 The build target

Phase: P1. Status: done

Slice 054 is the plan row 054 of `PLAN-P1.md` (TRANSITION step 5, gap G1). It needs the ladder (032, 036, 040) and the member files (WS rules). A project file has a build target. The build probe of ladder step 3 gets `--target=<t>`. The key of a build fact has the target. A platform release that lacks the `[build] target` of a member is no candidate (R-C10, answer OP10: exit 10).
The private reference has about 330 lines of code without comments and empty lines (`BuildTarget` about 170, and about 160 lines of wiring in 11 old modules). No module has more than 450 lines (`PickLoop` 369, `Ladder` 403, `Intent` 373).

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-TG1 | Build target of an app project file: (1) `[build] target`; (2) the host target (musl before glibc) if the platform `targets` has it; (3) the one target of the platform; else exit 2 and the message lists the targets | L0 `BuildtargetTest.roc` expects `targets_of`, `host`, `pick`. L2 `tg1-ladder` runs 1 to 7, `tg2-workspace` run 1. L3 `tg1-wasm-platform` run 1 |
| R-TG2 | `roc build --target=<t> main.roc --output=<tmp>`. The key of a build fact is (platform hash, compiler, target) | L0 `BuildtargetTest.roc` expects `key`, `with_target`, `build_at`. L2 `tg1-ladder` runs 1 to 6 (`compat.tsv` in `tree.diff`), `tg2-workspace` runs 1, 2 |
| R-TG3 | `[build] target` is one of the 35 Roc target names. Another value is exit 19 with the file and the line, for an app project file only (R-TG4) | L0 `BuildtargetTest.roc` expect `is_name`. L0 `IntentTest.roc` expect `[build]` (22 rows). L2 `tg1-ladder` run 8. L3 `tg1-wasm-platform` run 2 |
| R-TG4 | A package or platform project file has no build. `[build]` has no effect, also a bad value (no exit 19, Q3 answer) | L0 `IntentTest.roc` expect `[build]` (the `check:` rows). L2 `tg1-ladder` runs 9 and 10 |
| R-TG5 | Each member has its own target (the nearest `talon.toml`, R-PD6). The root key is not read for a member that has its own file. `[build]` is allowed in a member file (R-WS5) | L0 `IntentTest.roc` expect `[build]` and the member rows. L0 `BuildtargetTest.roc` expect `wanted`. L2 `tg2-workspace` |
| R-TG6 | The proxy does not use the build target | L2 `proxy/tg4-proxy` (a guard: it passes on the stubs, by design). `tln init --platform` and the tool build: out of scope |
| R-C10 | A platform release without the `[build] target` of a member is no candidate. No release has it: exit 10 (OP10) | L0 `BuildtargetTest.roc` expects `admits`, `wanted`, `gate`, `no_release`. L2 `tg3-constraint` runs 1 to 4 |
| R-C4, R-SP19, R-AL8, R-EC10 (as used) | The solver never takes an `App` release for a slot. `install` holds the platform. Exit 10 | L2 `tg3-constraint` |
| R-LD5, R-LD7, R-BS1, R-P4, R-EC2, R-EC19, R-WS5, R-PD6, R-IK7 (as used) | The ladder build step, no build for a package, the skip, the key, exit 2 and 19, the member table, the nearest file, the target list | L0, L2 as above |

## 2. Public signatures (stubs in `cli/lib/`, `crash "todo: slice 054"`)

| Name | Signature | File |
| --- | --- | --- |
| `BuildTarget.names` | `List(Str)`: the 35 names (real data, no stub) | `BuildTarget.roc` |
| `BuildTarget.is_name` | `Str -> Bool` | same |
| `BuildTarget.targets_of` | `Str -> Try(List(Str), [NoSection])`: the target keys of a platform header text | same |
| `BuildTarget.host` | `BuildSkip.System -> List(Str)` | same |
| `BuildTarget.Chosen` | `[Named(Str), Unlisted]` | same |
| `BuildTarget.pick` | `{ project : Try(Str, [Unset]), host : List(Str), found : Try(List(Str), [NoSection]), file : Str } -> Try(Chosen, Fail)` | same |
| `BuildTarget.key` | `{ pf, nightly, chosen : Chosen, system } -> Try(Db.Key, [Unknown])` | same |
| `BuildTarget.admits` | `{ wanted : Try(Str, [Unset]), found : Try(List(Str), [NoSection]) } -> Bool` | same |
| `BuildTarget.Want`, `Seen` | `{ url, target }`, `{ url, found }` | same |
| `BuildTarget.wanted` | `{ slots : List({ is_platform, urls, files }), members : List({ file, target }) } -> List(Want)` | same |
| `BuildTarget.gate` | `{ facts, seen : List(Seen), wanted : List(Want) } -> List({ url, release })` | same |
| `BuildTarget.no_release` | `{ alias : Str, target : Str } -> Fail` | same |
| `Intent.build` | new field `{ target : Try(Str, [Unset]), bad : Try({ line : U64, message : Str }, [Valid]) }` (stub value `{ target: Err(Unset), bad: Err(Valid) }`). `[build]` is allowed in a member file. `Intent.read` never fails for a bad `[build] target`: `target` is `Err(Unset)` and `bad` has the first problem | `Intent.roc` |
| `Intent.build_check` | `{ path : Str, bad : Try({ line, message }, [Valid]), kind : [App, Package, Platform] } -> Try({}, Fail)`: exit 19 (kind `Input`, `<path>:<line>: <message>`) for an app with `bad` `Ok`, else `Ok({})` (R-TG4). `ResolveLoad` calls it for each member with the `talon.toml` that the member uses | `Intent.roc` |
| `LadderPlan.with_target` | `{ spec : Probe.Spec, target : Chosen } -> Probe.Spec` | `LadderPlan.roc` |
| `LadderJudge.build_at` | `build` with the field `target : Chosen` | `LadderJudge.roc` |
| `Ladder.Member.target`, `Ladder.Checked.target`, `UnitFlow.Ctx.target` | `Try(Str, [Unset])`. The stubs of `InstallWrite`, `VerifyFlow`, `RemoveFlow` and the own member in `Ladder.use!` give `Err(Unset)` | `Ladder.roc`, `UnitFlow.roc` and 3 more |
| `BuildFlow.Plan.target` | new field `Chosen`. `before!` reads the platform header (`fx.read_files!`) and ignores the result in the stub | `BuildFlow.roc` |

Files that the code agent must change and that have no stub (the stub equals the file before the slice): `ResolveBase.roc` (`member_target`, the target of a member), `PickFlow.roc`, `PickLoop.roc` (the `gate` and the R-C10 text), `ResolveLoad.roc` (the call of `Intent.build_check` for each member, after `checked`, so the check has no new `Fx` call). `BuildTarget.scan_targets` is a private helper of the reference. `roc-app-header` has no `targets` accessor and cannot change (R-GP), so `targets_of` scans the span of `Header.span`.

## 3. The tested reading (the rules of the code)

| Topic | Reading |
| --- | --- |
| `targets_of` | The keys at depth 1 of `targets: { ... }` in the platform header, in source order, except `inputs_dir`. A nested key, a word in a string or in a comment, and another section never count. `targets: {}` is `Ok([])`. An app, a package, an old platform or a bad header is `Err(NoSection)` |
| `pick` order | Rule 1 holds also when the platform lacks the target (R-C10 checks that). Rule 2: the first host name that the list has. Rule 3: a list of one. `Err(NoSection)` is `Unlisted` (Q1). Else exit 2 (kind `Usage`) |
| `Unlisted` | No `--target`, and the key has the host target (`BuildSkip.key`). So the facts of the old tests do not change |
| `wanted` | One `Want` for each platform slot, each URL (candidates and current), each member of the slot that has a `[build] target`. A member list that is empty means every member |
| `gate` | A `Platform` fact whose `seen` list lacks one of its wanted targets gets the kind `App`. A release that Talon did not read, a `NoSection`, a package, and a URL with no `Want` are not changed |
| L2 call log | `BuildFlow.before!` reads the platform header (`read_files <pkgs>/<platform hash>/main.roc`) right after `platform`. About 40 old `calls.log` files have this one line more (section 7) |

## 4. Tests

| Layer | File | Case | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/BuildtargetTest.roc` (driver `l0-3.roc`) | `targets_of` (many headers) | R-TG1, R-C10 |
| L0 | same | `is_name` (all 35 names, 11 valid and 17 bad values) | R-TG3, R-IK7 |
| L0 | same | `host` (8 systems, 3 with no target) | R-TG1 |
| L0 | same | `pick` (the 5 rules, order, the message) | R-TG1, R-TG3, R-EC2 |
| L0 | same | `key` | R-TG2, R-P4, R-ID6 |
| L0 | same | `admits` | R-C10, R-TG1 |
| L0 | same | `wanted` | R-C10, R-TG5, R-WS5 |
| L0 | same | `gate` | R-C10, R-C4 |
| L0 | same | `no_release` | R-C10, OP10 |
| L0 | same | `with_target` | R-TG2, R-LD5 |
| L0 | same | `build_at` (text for a named target) | R-TG2, R-LD5, R-PH10, R-EC10 |
| L0 | `tests/unit/IntentTest.roc` | expect `[build]` (22 rows: roles, bad values in `target` and `bad`, line numbers, warning, 7 `check:` rows for `build_check` by kind) | R-TG3, R-TG4, R-TG1, R-TG5, R-WS5, R-TF4, R-EC19 |
| L0 | same | 4 old message rows changed: the member message ends with `patch and build` | R-WS5 |
| L2 | `tests/commands/cases/target/tg1-ladder` (10 runs) | wasm32 failing build, one target, host target, `[build]` key, skip with the key, glibc fallback, exit 2, exit 19, a package, a package with a bad value (no exit 19) | R-TG1, R-TG2, R-TG3, R-TG4, R-LD5, R-BS1, R-P4, R-EC2, R-EC19, R-EC10, R-LD7 |
| L2 | `target/tg2-workspace` (2 runs) | `verify` on 3 members, 3 targets, root key not read by a member with its own file, skip in run 2 | R-TG5, R-TG1, R-TG2, R-WS5, R-PD6, R-LD5, R-BS1 |
| L2 | `target/tg3-constraint` (4 runs) | the release filter, rule 2 without a key, `install` holds the platform: exit 10, no release has it: exit 10 | R-C10, R-TG1, R-TG3, R-C4, R-SP19, R-EC10, R-AL8 |
| L2 | `proxy/tg4-proxy` (1 run) | the proxy has no `--target` | R-TG6, R-PX3, R-PX7 |
| L3 | `tests/scenarios/update/tg1-wasm-platform` (2 runs) | the real `tln` reads the platform header from the cache: `--target=wasm32` (rule 3), exit 19 for `wasm64` | R-TG1, R-TG2, R-TG3 |

Counts: 11 L0 expects in `BuildtargetTest.roc`, 1 new and 1 changed in `IntentTest.roc`, 4 L2 cases (17 runs), 1 L3 scenario (2 runs).

## 5. Output proposals (TW24, for the human review)

| Output | Text | In the test |
| --- | --- | --- |
| Exit 2 (R-TG1 rule 5) | `<file>: no build target: the platform has the targets <t>, <t>, and none is the host target (<h>, <h>). Set the target in the [build] table of talon.toml, for example: target = "<first target>"`. An empty list: `... the platform has no targets. Set the target in the [build] table of talon.toml.`. No host target: `unknown host` | L0 `pick`, L2 `tg1-ladder` run 7 |
| No release (R-C10, exit 10) | `no tuple works: <alias> has no platform release with the build target <t> (R-C10). Change [build] target in talon.toml, or use a platform that has it.` | L0 `no_release`, L2 `tg3-constraint` runs 3, 4 |
| Build fails for a named target | `no tuple works: the build for the target <t> failed on the platform <name> <version>: <title>; <title>` (`the host target` when `Unlisted`) | L0 `build_at`, L2 `tg1-ladder` run 1 |
| `[build]` in `talon.toml` | `<path>:<line>: build.target: must be a string` and `<path>:<line>: build.target: '<value>' is not a Roc target` (exit 19, for an app only: `Intent.build_check`) | L0 `IntentTest` `[build]` |
| Member table message | `... (it has only dependencies, overrides, patch and build)` | L0 `IntentTest`, L2 `rs-member-root-table` |
| `--json` | no new `data` field | none |

## 6. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | R-C10 uses `gate`: a platform release that lacks the target gets the kind `App` before the solver, so the solver (R-C4) needs no change. `PickLoop.no_target` replaces the text of the R-C4 failure | A new filter inside `packages/resolve` (a generic package, a new input). A new fail kind |
| D2 | `Chosen = [Named(Str), Unlisted]`. `Unlisted` keeps the old behavior (no `--target`, the host key) when the header has no readable `targets` (Q1) | An exit 2 for no `targets` (it breaks the old tests and the apps on basic-cli with an old header). The host target as a made-up name |
| D3 | `[build]` is a new field of the `Intent` record, and the platform header is read in `BuildFlow.before!` (one `read_files` call, ladder step 3) | A new `Fx` field. A target in the compat fact of the platform |
| D4 | New functions `LadderPlan.with_target` and `LadderJudge.build_at`. Old closed records and `build` are unchanged | A new field in `plan` or `build` inputs (it changes about 20 old tests) |
| D5 | `--target=<t>` goes right after `build`, before the file (the form of R-LD5). `--replace-dep` pairs stay at the end | The flag after the file |
| D6 | `targets_of` scans the span of `Header.span` in `BuildTarget` (the keys at depth 1) | A `targets` accessor in `roc-app-header` (R-GP: no change in a generic package). A TOML parse (the header is Roc) |
| D7 | A member with its own `talon.toml` reads only that file. The root key is for the root file and the members with no file of their own (R-PD6) | A merge of two files |
| D8 | The target names are the 35 names of Registry R-IK7. `riscv64` is not a name in this nightly | Free text with a check by `roc` |
| D9 | `tln update` with a `[build] target` that no platform release has: exit 10 (the answer OP10 of the user) | Exit 2 |
| D10 | The check of a bad `[build] target` is `Intent.build_check`, called by `ResolveLoad` per member with the kind of the member file (Q3 answer). The check is no part of `Intent.read`, because the file does not know the kind | A check in `Intent.read` (it fails for a package, against R-TG4). A check at the use in `BuildFlow` (after the probes start, the exit 19 would be late) |

## 7. Questions (TW17, stop that part)

| Id | Question | In the stub and tests |
| --- | --- | --- |
| Q1 | A platform whose header has no `targets` list that Talon can read (an old platform, a header that does not parse). The design has no rule 4 | `Unlisted`: no `--target`, the host key as before. Tested by the old L2 and L3 cases and the `pick` row |
| Q2 | The set of valid target names (R-TG3): the list in Registry R-IK7 has the codes 1 to 35. If `roc` adds a name later, `is_name` says no | The 35 names. `riscv64` is not tested |
| Q3 | A bad `[build] target` in a package project file (R-TG4 says it has no effect). Exit 19 or ignored? | Answered by the manager: ignored (no exit 19). L0 `IntentTest` `check:` rows, L2 `tg1-ladder` run 10 |
| Q4 | `tln roc use` and `tln probe` have no platform and no member file: no target | `Err(Unset)`, not tested |
| Q5 | An app with a platform that is a path or a URL that is not in the package cache: the header is not read, so the result is `NoSection` (as Q1) | Not tested |

Design gaps: R-TG1 has no rule for a header without `targets` (Q1). R-C10 does not say what a release without a readable `targets` does (the reference admits it).

## 8. Red run (stubs)

`scripts/test.sh` with the stubs (log: `research/slice-054-revert/red-run.log`). The old tests pass, apart from `resolve/rs-member-root-table` (the new member text, section 10).

| Step | Result | The new tests |
| --- | --- | --- |
| check, fmt | pass | The stubs compile |
| l0 | FAIL (`l0-3`: 51 passed, 13 failed) | `BuildtargetTest.roc`: 11 of 11 expects fail with `todo: slice 054`. `IntentTest.roc`: 2 expects fail by value (the stub has the old member text and `build: Err(Unset)`). `l0-1`, `l0-2`, `l0-4` to `l0-8` pass |
| l2 | FAIL (106 passed, 4 failed) | `target/tg1-ladder`: the failure text says `the host target`, and no `--target`. `tg2-workspace`: the builds of members b and d are skipped (the key has no target). `tg3-constraint`: the platform moves to 0.1.2 (no gate). `tg1-ladder` run 10 passes on the stubs (the stub has no `[build]` check at all): it pins that no change may add the exit 19 for a package. `resolve/rs-member-root-table`: the old member text. `proxy/tg4-proxy` passes: it is a guard |
| l3 | FAIL (64 passed, 1 failed, 1 skipped) | `update/tg1-wasm-platform`: run 2 has exit 0 (the stub has no `[build]` read) |
| selftest, l1 | pass | |

The stub of `BuildFlow.before!` makes the read of the platform header and ignores the result, so that the 40 old `calls.log` files pass.

## 9. Revert check (mutations of the private reference)

13 mutations of the private reference, now deleted (`research/slice-054-revert/mutate.py`, log `mutate.log`, each compile-checked, filtered runs only, the tree equal to the reference after the run). All are caught.

| Id | Mutation | Caught by |
| --- | --- | --- |
| B1 | glibc before musl in `host` | L0, L2 |
| B2 | the one platform target wins over `[build] target` | L0 |
| B3 | `inputs_dir` counts as a target | L0 |
| B4 | a nested key counts as a target | L0 |
| B5 | `gate` looks at the first want only | L0 |
| B6 | `admits` is true when the list lacks the target | L0, L2 |
| B7 | `--target` goes at the end of the arguments | L0, L2, L3 |
| B8 | the key has a fixed target | L0, L2 |
| B9 | the exit 2 has the kind `NoTuple` | L0, L2 |
| B10 | no release is exit 2, not 10 | L0, L2 |
| B11 | the member `[build] target` is not given to the build | L2 |
| B12 | the solver does not get `gate` | L2 |
| B13 | a bad `[build] target` of a package file is exit 19 (Q3, after the review) | L0, L2 |

## 10. Old tests that change (TW21)

| Test | Change | Reason |
| --- | --- | --- |
| `tests/unit/IntentTest.roc` | 4 message rows end with `patch and build` | `[build]` is allowed in a member file (R-WS5, R-TG5) |
| `tests/commands/cases/resolve/rs-member-root-table/expect/stderr` | the same text | the same |
| 40 L2 `calls.log` files (the list is in section 11) | one inserted line `read_files $HOME/.cache/roc/packages/<platform hash>/main.roc` after `platform`, before `db_query` | the read of the platform header (R-TG1). Checked against the saved old files: no line is removed, no other line changes (all added lines are this one line) |
| L3 scenarios | none | The `roc.log` and `facts.tsv` of the old cases do not change (the fake platform has no `targets`: `Unlisted`) |

## 11. Files

| File | Lines | State |
| --- | --- | --- |
| `cli/lib/BuildTarget.roc` | 128 (stub) | new |
| `cli/lib/Intent.roc`, `LadderPlan.roc`, `LadderJudge.roc`, `Ladder.roc`, `BuildFlow.roc`, `UnitFlow.roc`, `InstallWrite.roc`, `VerifyFlow.roc`, `RemoveFlow.roc`, `main.roc` | 358, 63, 233, 403, 77, 169, 192, 143, 318, 168 | changed (stubs; backups in `research/slice-054-revert/before/`) |
| `tests/unit/BuildtargetTest.roc`, `l0-3.roc`, `IntentTest.roc` | 351 | new (11 expects), 1 import, 1 new and 1 changed expect |
| `tests/commands/cases/target/` (3 cases), `proxy/tg4-proxy/` | 52, 21, 27, 22 files | new |
| `tests/scenarios/update/tg1-wasm-platform/` | 14 files | new |
| `research/slice-054-revert/` | | `backup.sh`, `swap.sh`, `mutate.py`, `gen-tg.py`, `before/`, `stubs/`, `red-run.log`, `reference-run.log`. The private reference was deleted at the review (2026-10-24); `swap.sh` has the modes `stub` and `check` only |

The 40 old L2 cases with a changed `calls.log`: consent/dl1-resolve, dl2-verify-workspace, dl3-rank4; evidence/ev3-summary, ev4-baseline-note; init/it1-app; install/in1-flow; ladder/bs1, bs2, bs3, ld-ladder-flow, ld-no-check-refuse; moves/hm1, hm2; patch/pa2-resolve; probe/lp1, lp2, pb1, pb2, sc1, un1, un2, un3; remove/rm1-flow; resolve/rs-install-add-key, rs-unmanaged, rs-update-scope; roc/so1-ranks; update/up1-flow; upgrade/ug1, ug2, ug3, ur1 to ur6; verify/vf1-flow; workspace/ws2-verify-members.

## 12. Compiler limits met

`targets` is a reserved word (the fields are `found` and `seen`). `{ x }` alone is a block. `==` on a `Try` does not compile (the rows compare strings). A local name equal to a method of its type module is a duplicate (`host`, `names`). A module cannot import a module that imports it. `roc build` exits 2 on a warning. `keep_oks(...).first()` crashed the app (the reference uses `find_first`). `Str.inspect` of an `I32` literal prints `2.0` (the exit code is a `Str` in the `pick` rows).

## Review (manager, 2026-10-24)

Accepted, no split. D1 to D9, the TW24 texts and the TW21 changes (4 `IntentTest` rows, `rs-member-root-table`, the 40 `calls.log` lines) are accepted.

| Id | Answer |
| --- | --- |
| Q1, Q5 | Accepted: `Unlisted` (the behavior before the slice). A design gap, recorded by the manager |
| Q2 | Accepted: the 35 names of R-IK7. No new test |
| Q3 | Change: follow R-TG4. A `[build] target` in a package project file has no effect, so no exit 19 for it. Done: D10, `Intent.build_check`, `IntentTest` `check:` rows, `tg1-ladder` run 10 (appended, TW21), mutation B13 |
| Q4 | Accepted, out of scope |
| Gap (R-C10 and a release with no readable `targets`: admitted) | Accepted, recorded by the manager |

After the Q3 change: the reference passes `scripts/test.sh`. Only `tg1-ladder` (run 10 appended, `projects.json` of `tree.diff` has `p10`) and `IntentTest` (the 8 bad rows now read `Ok` with `bad`, 7 `check:` rows) changed. The old expected files of the other cases did not change.

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Verify results (code agent, 2026-10-24)

`scripts/test.sh` exit 0: check 3.4 s, fmt 0.3 s, l0 16.1 s (12 files, 449 tests), l2 11.2 s (110 cases), l3 11.7 s (65 passed, 1 skipped), selftest 6.1 s, l1 72.7 s. The 2 WARN lines (l0 and l1 over the budget) came from a loaded machine (a build ran at the same time as the first run); no test failed. `MISSING=1 scripts/rules.sh R-TG R-C10` lists no rule with no test.

Revert check (`research/slice-054-revert/agent-mutate.py`, `agent-results.md`): 10 mutations, 10 caught. `cli/lib` was compared with `research/slice-054-revert/code-final/` after the run (no difference, `sha256sum -c research/slice-054-revert/code-final.sha256` passes).

| Id | Mutation | Result |
| --- | --- | --- |
| M1 | `host`: glibc before musl | caught: L0 `l0-3`, L2 `tg1-ladder` |
| M2 | `pick`: rule 2 takes the list order of the platform | caught: L0 |
| M3 | `pick`: the one platform target wins over `[build] target` | caught: L0 |
| M4 | the solver gets the facts with no `gate` (R-C10) | caught: L2 `tg3-constraint` |
| M5 | no release is exit 2 | caught: L0, L2 `tg3-constraint` |
| M6 | `member_target` is always `Unset` (R-TG5) | caught: L2 `tg2-workspace`, `tg1-ladder` |
| M7 | the `[build]` of a package file is exit 19 (R-TG4) | caught: L0, L2 `tg1-ladder` |
| M8 | the build gets no `--target`, the key has it | caught: L2 `tg1-ladder`, `tg2-workspace` |
| M9 | the platform of the header is not read first | caught: L2 `tg3-constraint`, `tg2-workspace` |
| M10 | `--target` at the end of the arguments | caught: L0, L2 `tg1-ladder` |

Not mutated: R-TG6 (the proxy has no target code to mutate; `tg4-proxy` is a guard).

Code files (lines): `BuildTarget.roc` 318 (new), `Intent.roc` 389, `PickLoop.roc` 382, `ResolveBase.roc` 362, `ResolveLoad.roc` 178, `LadderJudge.roc` 240, `LadderPlan.roc` 66, `BuildFlow.roc` 80, `PickFlow.roc` 271. `InstallWrite`, `VerifyFlow`, `RemoveFlow` change one expression each (`ResolveBase.member_target`). No module has more than 500 lines.

Decisions of the code agent (the slice does not fix them):

| Id | Decision | Rejected |
| --- | --- | --- |
| C1 | `ResolveBase.Probed` has a new field `seen : List(BuildTarget.Seen)`. `PickLoop.read_all!` fills it with `BuildTarget.targets_of` for each platform release that it reads. `PickLoop.run!` gives the facts through `BuildTarget.gate` to the solver | A new field in `PickLoop.State` (more records to change) or in `PickLoop.Input` (built in `PickIndex`, a file that the slice does not change) |
| C2 | Before each solver step, `PickLoop.run!` reads the platform URL that a platform slot has now, when a member wants a target of it and no fact has it (`unread_current`, one `read_all!`). The expected `calls.log` of `tg1`/`tg2`/`tg3` (the current release is read before the best candidate) fixes this order. A value that is no release URL is not read | Read only what the solver asks for (the log differs) |
| C3 | `PickLoop.no_target` replaces the failure of the solver (kind `NoTuple`) by `BuildTarget.no_release` only when a platform slot has all its read releases gated out. Another `NoTuple` failure stays | Replace each `NoTuple` failure when any release was gated |
| C4 | `LadderJudge.build` and `build_at` share a private `build_for` with the label `the host target` or `the target <t>` | A copy of the judge for a named target |
| C5 | `BuildTarget.wanted` keeps the order of `members` (not of `files`) and drops a repeated `(url, target)` pair | The order of `files` |
| C6 | `Intent.read_build` uses `field`: the first issue of `[build] target` is `bad`, `target` is `Err(Unset)`. `build_check` fails for kind `App` only | A check in `read` (D10) |

Questions (TW17): none new.

## Gap tests (test agent, 2026-10-24)

Two gap rows for the decisions C3 and C5. No code was changed: `sha256sum -c research/slice-054-revert/code-final.sha256` is OK for all 15 files after each mutation. Mutations G1 to G3 are in `research/slice-054-revert/mutate.py` and `mutate.log`.

| Decision | New test | Mutation | Result |
| --- | --- | --- | --- |
| C3: only a platform slot with all its read releases gated out gets the `no_release` text | L2 `target/tg3-constraint` run 5 (appended, TW21): `pf = "acme/pf@=0.1.2"` and `[build] target = "wasm32"`, the header release 0.1.0 has wasm32. Exit 10 with the text of the solver: `no tuple works: pf has no release of the kind platform in =0.1.2 (R-C4)` | G3: `no_target` uses `any` for `all` | caught by L2 `tg3-constraint` |
| C5: `wanted` keeps the order of `members`, not of `files` | L0 `BuildtargetTest.roc` expect `wanted`, row "the order of the members, not of the files" | G1: the order of `files` | caught by L0 `l0-3` |
| C5: `wanted` drops a repeated pair | L0 `wanted`, rows "2 members with the same target: one pair" and "the same url in 2 slots: one pair" | G2: no `fold` for repeats | caught by L0 `l0-3` |

The text of run 5 is the text of the solver (R-C4) and it is a proposal for the review: it names `=0.1.2` but not the build target. The slice file does not fix a better text, so this is a fact of the code and not a bug. The expected files of the other cases did not change (checked against saved copies).

## Close (manager, 2026-10-24)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-054-revert/code-final.sha256` | OK, 15 lines |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.4, fmt 0.2, l0 7.3, l2 7.5, l3 9.9, selftest 3.0, l1 38.9 s |
| Gap tests | 2 rows (C3, C5), 3 hand mutations, all caught; no code bug |
| Note | The C3 run gives the solver text, which names the range but not the build target. As the design says (R-C10 text only when the target gate removes all releases). |
