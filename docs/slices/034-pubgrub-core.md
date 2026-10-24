# 034 PubGrub core

Phase: P1. Status: done

Slice 034 is the plan row 034 of `PLAN-P1.md`: the new Talon package `packages/resolve` (R-PK6) with the solver step `step : Request -> [Need, Done, Fail]` (`TESTING.md` 2.2, part B). It has the domain of a variable (R-C1, R-C6, R-C7, R-C9, R-VA6), the facts that make incompatibilities (R-C2, R-C3, R-C4), terms, unit propagation, decisions by `priority` and `strategy`, and a search that is complete (it finds the best tuple, or says that none exists). Conflict resolution of PubGrub, the learned incompatibilities of the probes and the explanation of a failure are slice 035. No command calls the package yet (slice 036). L0, and L1 against brute force on small random problems (`TESTING.md` 4, the `pubgrub` row). The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed file, the stubs and the scripts are in `research/slice-034-revert/` (`before/NEW.txt` lists the new files).

## 1. Rules

| Id | What the slice does with it | Tested by |
| --- | --- | --- |
| R-PK6 (`resolve`: PubGrub, the oracle interface and the solver step) | The package `packages/resolve` with `Domain` and `Solver`. The step is `Solver.step` | L0 `solver` 1 to 5, L1 `pubgrub` |
| R-GP6 (`resolve` stays in the Talon repository: its API has Talon concepts) | The package is in `packages/` with no `LICENSE` and no `.git`. Its header names `roc-semver` by a release URL and no header of Talon has a path entry for a generic package (R-GP3) | Selftest `s_packages` |
| R-C1 (ranges) | `Domain.values` rule 2: each range admits the version | L0 `domain` 1, 2. L0 `solver` 1. L1 |
| R-C2 (Roc MVS: a direct pin is at least the highest version of that group) | A dep of the chosen release on the group of another slot: that slot has a value at or above the version (an incompatibility of the fact). Transitive groups are the caller's closure walk (D2, Q3) | L0 `solver` 3. L1 |
| R-C3 (one platform) | The `pf` of a package release must be the one platform slot (D8) | L0 `solver` 1, 4. L1 |
| R-C4 (alias kind) | A fact with the wrong kind, or the kind `App`, takes the release out of the slot. No fact: taken as fit | L0 `solver` 4. L1 |
| R-C6 (yanked, withdrawn, draft, prerelease are not candidates) | `Candidate.yanked` (D10): such a release is not a value, except the header value | L0 `domain` 2. L0 `solver` 1. L1 |
| R-C7 (`min-release-age`, snapshot hide new releases) | `Domain.values` rule 4: too young, or after the snapshot time. The time form only (the log form is the registry, P2) | L0 `domain` 2. L0 `solver` 1. L1 |
| R-C9 (R-C6, R-C7 and a snapshot never hide the header value) | `Domain.values` rules 1, 3 and 4: the header value is added when the list lacks it, and it is not hidden. A range still excludes it | L0 `domain` 2. L0 `solver` 1. L1 |
| R-VA6 (`priority` and `strategy` break ties: the first name is maximized, then the second, ...) | The slots are in the order of `priority`. The first slot has its best value, then the second, and so on, with the order of `Domain.values` | L0 `domain` 1. L0 `solver` 1. L1 |
| R-DT2 (the resolver is a pure function) | The same request gives the same step, also when the candidates, the facts and the conflicts are in another order | L0 `domain` 1. L0 `solver` 1 to 5 (each row also runs with the lists reversed). L1 |
| R-AL3, R-AL8, R-AL9 (named, they belong to slice 036) | The step asks only for the facts of the best tuple (`Need`), in the order of the slots, and never for a release outside the domains. The closure walk of R-AL9 is slice 036 | L0 `solver` 2. L1 |

`MISSING=1 scripts/rules.sh R-PK R-GP R-C R-VA` after the slice: R-PK1 to R-PK5 and R-GP1, R-GP2, R-GP4, R-GP5, R-GP7 are not rules of this slice (generic packages, other repositories). R-C5 (compatibility) is in `PLAN-P1.md` for slices 035 and 036, and R-C8 has a test of slice 010 or 011. R-PK6, R-GP6, R-C1 to R-C4, R-C6, R-C7, R-C9 and R-VA6 are named.

## 2. Split of the slice

The private reference has 73 lines (`Domain`) and 244 lines (`Solver`). The doc comments (the contract) are about 55 of them, so the code is about 260 lines. That is under the 400 lines of the row, so there is no split. If the manager wants one, the 2 modules are the 2 parts (034a `Domain`, with `domain.roc`, 034b `Solver`, with `solver.roc`) and the L1 target tests both. The conflict resolution of PubGrub (a real learned incompatibility from a conflict, and the explanation) is slice 035, as in the plan.

## 3. Public signatures (the code agent keeps them)

The package header `packages/resolve/main.roc` exposes `Domain` and `Solver`. Time is in seconds. A version is `X.Y.Z`.

| Function or type | Signature |
| --- | --- |
| `Domain.Candidate` | `{ id : Str, version : Str, published_at : U64, yanked : Bool }`. `id` is the URL of the release |
| `Domain.Rules` | `{ now : U64, min_age : U64, snapshot : Try(U64, [None]), strategy : [Highest, Lowest] }` |
| `Domain.Query` | `{ candidates : List(Domain.Candidate), ranges : List(Str), current : Try({ id : Str, version : Str }, [None]), named : Try(Str, [None]), rules : Domain.Rules }` |
| `Domain.values` | `Domain.Query -> List(Domain.Candidate)` (best first) |
| `Solver.Slot` | `{ name : Str, group : Str, kind : [Package, Platform], candidates : List(Domain.Candidate), ranges : List(Str), current : Try({ id : Str, version : Str }, [None]), named : Try(Str, [None]) }` |
| `Solver.Dep` | `{ group : Str, version : Str }` |
| `Solver.Fact` | `{ id : Str, kind : [Package, Platform, App], pf : Try(Str, [None]), deps : List(Solver.Dep) }` |
| `Solver.Term` | `{ name : Str, ids : List(Str), sign : [In, NotIn] }` |
| `Solver.Request` | `{ slots : List(Solver.Slot), rules : Domain.Rules, facts : List(Solver.Fact), conflicts : List(List(Solver.Term)) }` |
| `Solver.Ask` | `[Header(Str)]` (the header facts of a release, R-AL8) |
| `Solver.Chosen` | `{ name : Str, id : Str, version : Str }` |
| `Solver.Why` | `{ names : List(Str) }` (a placeholder, see D5) |
| `Solver.step` | `Solver.Request -> [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)]` |

The docs of `packages/resolve/Domain.roc` and `packages/resolve/Solver.roc` have the rules as tables. They are the contract. The names `name` and `pf` are used because `var` and `platform` are reserved words (section 11).

## 4. Files

| Path | Lines | State |
| --- | --- | --- |
| `packages/resolve/main.roc` | 10 | New. The package header with `semver` by its release URL |
| `packages/resolve/Domain.roc` | 28 | New. The types and `values` (stub, `crash "todo"`). The doc has the contract |
| `packages/resolve/Solver.roc` | 55 | New. The types and `step` (stub). The doc has the contract |
| `packages/resolve/tests/domain.roc` | 89 | New. 2 `expect`s (31 rows) |
| `packages/resolve/tests/solver.roc` | 224 | New. 5 `expect`s (66 rows) |
| `tests/fuzz/pubgrub.roc` | 411 | New. The second roc-fuzz target (L1) |
| `tests/selftest.sh` | +15 (607) | The row `s_packages` (R-GP3, R-GP6). The row `l0 in parallel` counted only `tests/unit/` lines: it counts each `.roc` line now, because the first `packages/*/tests/` files exist |
| `research/slice-034-revert/` | | `before/` (the old `tests/selftest.sh`, `NEW.txt`), `stubs/`, `mutate.py`, logs. The private reference was deleted on the manager's order (Review). `mutate.py` needs it, so it cannot run again |

No old expected file changed. No design file, no `TESTING.md` and no `cloudflare-workers/` file changed. `scripts/test.sh` already runs `packages/*/tests/*.roc` (l0) and `packages/*/main.roc` (check), and `fmt` reads `packages/`, so it needed no change.

## 5. How a Talon package is laid out (the brief asks)

The design and `TESTING.md` do not say. `scripts/test.sh` and `scripts/rules.sh` already expect the layout below (slice 001). This slice uses it and proposes it as the rule.

| Item | Layout | Why |
| --- | --- | --- |
| Header | `packages/<name>/main.roc`: `package [Module, ...] { dep: "<release URL>" }`. A module is a type module `Name.roc` in the same dir | As `cli/lib/main.roc` |
| Generic packages | By release URL only (R-GP3). `resolve` uses `semver` | The selftest row `s_packages` checks that no header of Talon has a path entry for them |
| L0 | `packages/<name>/tests/*.roc`: an app `app [main!] { <name>: "../main.roc" }`, with `expect`s. `scripts/test.sh l0` runs each file with `roc test` | `scripts/test.sh` line 34 |
| L1 | `tests/fuzz/<target>.roc`: `app [target] { fuzz: platform ..., resolve: "../../packages/resolve/main.roc" }` | As `tests/fuzz/epochs.roc` |
| check | `roc check packages/<name>/main.roc` (the apps list of `scripts/test.sh`) | |
| Use by `cli/` | Not in this slice. Slice 036 adds `resolve: "../../packages/resolve/main.roc"` to the header of `cli/lib/main.roc` (a path entry to a Talon package is allowed). Tested on a copy: a package with such a path entry compiles, and an app that imports it runs a test | A path entry to a generic package is never allowed (R-GP3). To a Talon package it is |
| License, repository | None of its own (R-GP6, R-GP7 is for generic packages only) | |

## 6. Tests

| Layer | File and case | Rule ids |
| --- | --- | --- |
| L0 | `packages/resolve/tests/domain.roc` 1 (13 rows): the order (highest, lowest, by version and not by text, the major version first), the input in another order, ranges (2 ranges, a caret, an exact range, the star, no value), no candidate, a tie of 2 ids | R-VA6 R-C1 R-DT2 |
| L0 | `domain` 2 (18 rows): yanked, too young, exactly as old as `min-release-age` (visible) and one second younger (hidden), the snapshot time (a release at it is visible), the header value (yanked, young, after the snapshot: stays; not in the list: added; excluded by a range), a named version (young: visible; yanked: hidden; the name of another version exempts nothing, a named version after the snapshot stays, a range still hides a named version), no value | R-C6 R-C7 R-C9 R-C1 |
| L0 | `packages/resolve/tests/solver.roc` 1 (14 rows): the best tuple (highest, lowest), the order of the slots (R-C3 makes the platform and the package a real choice), the request rules (range, yanked, young, header value, named), the facts of releases that lose count, a slot with no release | R-VA6 R-C1 R-C3 R-C6 R-C7 R-C9 |
| L0 | `solver` 2 (11 rows): `Need` asks only for the missing facts of the best tuple, in the order of the slots. A fact changes the tuple. A release outside the tuple needs no fact. `Done`. `Fail` with no ask. The empty tuple | R-AL8 R-AL9 R-AL3 |
| L0 | `solver` 3 (11 rows): R-C2. A limit above all values, the lowest value at or above the limit, 2 limits (the highest wins), a semver (1.10.0 is above 1.9.0), a dep on a group with no slot (not read), a dep on the own group (not read), the group is the key and not the name, the limit is checked against the range of the slot | R-C2 R-C1 |
| L0 | `solver` 4 (11 rows): R-C3 (a platform that is no value, no platform slot, no platform in the fact) and R-C4 (each wrong kind, `App`, no right release, no fact: asked for) | R-C3 R-C4 |
| L0 | `solver` 5 (19 rows): conflicts of the caller. `In` and `NotIn`, a conflict after a decision, a chain, 3 terms, a conflict 3 decisions deep (it needs a learned incompatibility that is sound), 2 terms of one slot, an id that is no value, a name that is no slot, all values out, no pair left, a conflict and a need together | R-VA6 R-AL3 |
| L1 | `tests/fuzz/pubgrub.roc`: 2 numbers of 64 bits make a random world (1 to 3 slots, up to 4 versions each, a range, a header value, yanked and young releases, a snapshot, facts with a kind, a platform and a dep, 2 conflicts). 3 properties: a step with a random part of the facts equals the oracle (brute force over all tuples, written from the rule text with integers and index loops). The loop of a command (step, the facts that it asks for, step) ends with the oracle for all facts, and each need is not empty, has no repeat, no known release and only releases of a domain. Lists in another order give the same step | R-VA6 R-C1 R-C2 R-C3 R-C4 R-C6 R-C7 R-C9 R-AL8 R-AL9 R-DT2 |
| Selftest | `s_packages` (1 row): `gen_paths` flags a path entry of a generic package and not a URL (2 fake headers), the real headers have none, `packages/resolve/main.roc` exists with no `.git` and no `LICENSE` | R-GP3 R-GP6 |

L0 count: 7 `expect`s in 2 files (the budget is 5 to 20: each `expect` is a table of 10 to 18 rows, 97 rows in all). Deep cases: 1 L1 target. There is no L2 or L3 case: no command calls `resolve` before slice 036, so no flow exists to test (as in slice 033).

Cost of the new files (the code is the private reference): l0 6.2 s (was 6.1 s: the 2 new files run in parallel with the others, `domain` 0.75 s and `solver` 1.0 s each), l1 11.1 s (was 4.5 s: the build of the second target is 6.6 s more, the 20000 runs are fast; budget 60 s), selftest 8.4 s (was 8.2 s). Check 0.9 s, fmt 0.2 s, l2 1.1 s, l3 9.9 s. No `WARN` line (`research/slice-034-revert/green-run.log`).

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | Two modules. `Domain` is part A (pure, no fact): the values of one variable. `Solver` is part B: the step. The package has its own types and cannot import `cli/lib` (`cli` imports it): so a candidate is `{ id, version, published_at, yanked }`, not `Index.Candidate`, and a dep is a group and a version, not a URL | One module. `Index.Candidate` and `Ident` in the package |
| D2 | A variable is a slot (a free direct dep, the platform, `roc`). A transitive group is no variable: a dep on a group with no slot, and a dep on the own group, are not read. The closure walk of R-AL9 is the caller's: it checks the tuple that `Done` gives and returns a failure as a conflict (`conflicts`), and calls `step` again (slice 036). This is what R-AL9 says ("a conflict of the tuple in steps 3 to 5: the solver tries the next tuple") | A lazy variable for each transitive group with the value "lowest that all edges allow" (MVS as a PubGrub decision), see Q3 |
| D3 | `Need` asks for header facts (`Header(id)`), not for probes. `Ask` is a union with one constructor, so slices 035 and 036 add `Probe(...)` with no change of the callers. `TESTING.md` 2.2 writes `Need(List(Probe))`, but the solver also needs the facts of R-AL8 | `Need(List(Str))` (the shape of `Pick.step`) |
| D4 | The step is a function of the request: it holds all facts and all conflicts. There is no `State` value. The learned incompatibilities of slice 035 come back as `conflicts` (the same type: terms that cannot all be true). A step starts from the start each time, so it is pure (R-DT2) and the "state is data" is the request | An opaque `State` that the caller keeps |
| D5 | No conflict resolution (slice 035). The search is complete anyway: on a conflict the solver learns the decisions that gave it (they cannot all hold), goes back one decision and goes on, so it finds the best tuple or a proof that none exists, and the L1 oracle can be a brute force. `Fail` has `Why = { names }`: the slots of the incompatibility that was true with no decision. It is a placeholder: slice 035 gives the explanation. The tests do not read `Why` | `Fail` at the first conflict (the L1 property would only test the soundness, not the result). A proper conflict resolution (slice 035) |
| D6 | A release with no fact is taken as fit (optimistic), as `Pick.step` does. The step returns `Need` when the best tuple has a release with no fact, and `Done` only when each release of it has a fact. `Fail` needs no fact: no tuple with fewer constraints means no tuple | A `Need` for each decision (more rounds) |
| D7 | `Domain.values` follows `Pick.domain_of` rules 1 to 3 and 5: the header value is added when the list lacks it, a range still excludes it, yanked and hidden releases are not values except the header value, a named version is exempt from the age. A version that does not parse is not a value | Exempt the header value from the ranges |
| D8 | R-C3 is checked when the request has exactly one platform slot (as `Pick.step`, its question Q8). With none or 2 or more: no check. The platform slot's own release is not checked | A check against each platform slot |
| D9 | A tie (one version, 2 ids) is in the byte order of the ids, for both strategies. A version is compared as a semver | The order of the input |
| D10 | `Candidate.yanked : Bool` stands for yanked, withdrawn, draft and prerelease (R-C6). The caller maps its states | A tag union of the states |
| D11 | A dep names a group, a slot has a group (the key of the group, for example `acme/json`). Two slots with one group (R-WS2: one value) are not a case of the package: the caller adds a conflict | A check inside the solver |
| D12 | The time is in seconds (`published_at`, `now`, `min_age`, `snapshot`). A release is too young when `published_at + min_age > now` (so exactly `min_age` old is visible: R-RU1 says "at least 2 days old"). It is after the snapshot when `published_at > snapshot` (so at the snapshot time is visible: R-DT4 says "published after that time") | `>=` |
| D13 | The names `name` (a slot) and `pf` (the platform field) in place of `var` and `platform` (reserved words in this compiler) | |
| D14 | The L1 input is 2 numbers that a mixing function (splitmix64) makes into 7 words. Reason: a list of random length needs hundreds of bytes, and libFuzzer grows its inputs slowly, so with 20000 runs the first target (lists and a byte for each field) did not catch 16 of the 37 changes that compile (`mutate.log`), and the same world as 7 numbers of 64 bits read as bytes did not catch 21 of 49 (`mutate2.log`): the short inputs that libFuzzer makes first are zero padded, and most worlds had no dep, no conflict and no tie. With the 2 numbers and the mixing function 10 of 49 are not caught by L1: 6 are cases that the world does not make, 3 are not caught by L0 either, and 1 needs a deeper conflict (section 14). The price: no coverage feedback, and a failing input is a seed pair. `TESTING.md` 4 (TW7) allows a fixed-seed generator as a fallback | A target with a byte for each field. A higher `L1_RUNS` for this target (`scripts/test.sh` has one count for all) |

## 8. Output

None. No command prints from this package. The text of a `Fail` (the explanation, Resolution 5 example) is slice 035. The `--json` fields of a resolve are slice 036.

## 9. Out of scope

| Id | Reason |
| --- | --- |
| R-AL5, R-EP7 to R-EP9 (a learned incompatibility `not (h and roc in [a, b])` from a probe fact, the inferred facts, `--no-probe`) | Slice 035. The input type for them exists here: `conflicts` |
| R-AL3 (as a whole), R-AL6, R-AL7, R-SP24, R-LF2, R-UP7, R-OV2, R-PH10, R-PH13 | Slice 036 (the loop, the budget, the held-move search, the closure walk of R-AL9 on the tuple) |
| R-C5 (compatibility: each hash checks on the nightly) | Slices 035 and 036. In the solver it is a conflict of the caller |
| R-WS2, R-WS3 (2 slots of one group have one value), R-SP23 (movable variables), R-OV (overrides) | Slice 036. A conflict of the caller, or a second search with other slots |
| The log form of the snapshot (R-DT3) | P2. It is a filter of the registry: the caller sends the candidates that it allows. `Domain.Rules.snapshot` is the time form (R-DT4) |
| R-DI15 (a tag with a new asset hash) | The caller removes such a candidate (`Index`) |
| A speed test of unit propagation | Propagation changes the speed only: the result of the search is the same without it, and a search with learning but no propagation does not end (the learned incompatibility has no effect). No row can show it without a very slow case. The code agent follows the doc (R-AL3 "unit propagation") |
| L2 and L3 cases | No command calls the package (section 6) |

## 10. Questions (TW17, stop until answered)

| # | Question | Options | Proposal | Effect |
| --- | --- | --- | --- | --- |
| Q1 (answered, see Review) | R-C7 says that `min-release-age` does not hide a version that the user names (`X@1.2.3`). Does the user name also escape the time snapshot (R-DT4)? | (a) yes, both (as `Pick.is_hidden` of P0). (b) the age only | (a): the user named the version, and a snapshot is also a way to hide new releases | `Domain.hidden`, one condition. Answered (a). 2 L0 rows of `domain` 2 fix it (the L1 target has no named version) |
| Q2 (answered) | R-C3 with 0 or 2 or more platform slots (D8) | (a) no check (as P0). (b) a check against each | (a): a header has one platform (R-C3 text) | `Solver` fact incompatibilities. Not tested (the L1 target has at most one platform slot) |
| Q3 (answered) | How does the closure of R-AL9 reach the solver? A dep of a transitive release (a group with no slot) can name a slot group (R-C2: a direct pin is at least the highest version in the closure), and it counts only when that release wins its group | (a) The caller walks the closure of the tuple after `Done` and gives a failure back as a conflict (D2). (b) A variable for each transitive group, with the value "the lowest version that all edges allow". (c) The solver gets the facts of the transitive winners with `Need` and walks the closure itself | (a): it is what R-AL9 says, and `Pick`, `list` and `why` share the walk (`Closure.step`). With (a) the number of rounds is about the depth of the closure | Slice 036. Slice 034 is the same for (a) and (c). For (b) the `Slot` type gets a flag |

## 11. Design gaps found

| # | Gap | Where | Proposal |
| --- | --- | --- | --- |
| G1 | Resolution 5 and R-PK6 give PubGrub and "the oracle interface and the solver step", but no data model: what a variable, a value, a fact and a conflict are | R-PK6, R-AL3, R-AL8 | Add the types of section 3 and D2 to D6 to Resolution 5 |
| G2 | `TESTING.md` 2.2 writes `step : State, Facts -> [Need(List(Probe)), Done(Tuple), Fail(Why)]`. The step here is `Request -> [Need(List(Ask)), Done(List(Chosen)), Fail(Why)]`. `Ask` has the header facts of R-AL8, and slice 035 adds the probes | `TESTING.md` 2.2 | Change the signature text |
| G3 | R-C7 names the exemption of a named version for `min-release-age` only (Q1) | R-C7, R-C9 | The answer to Q1 |
| G4 | `TESTING.md` 4: the `pubgrub` row says "A failure explanation names only real conflicts". That is slice 035. Slice 034 checks "the result equals brute force" and the protocol of `Need` | `TESTING.md` 4 | Split the row in the text. Add that an L1 target may expand 2 seeds into the world (D14) |
| G5 | R-AL3 lists R-C2 and R-C3 as constraints of the PubGrub step, but both read the closure (R-AL9). Only the part between slots is in the step (D2) | R-AL3, R-AL9 | Q3 |

## 12. Compiler and tool limits met

| # | Limit |
| --- | --- |
| 1 | `var`, `platform` and `with` are reserved words, also as field names and as names of a function (`with = ...` is a parse error that points at the next line). The names are `name`, `pf` and `conflicting` |
| 2 | A function that is not a method of the type cannot be called with a dot: `facts.on_pf(...)` is "missing method". Use `facts \|> on_pf(...)` |
| 3 | A number literal with a method (`(2).pow(n)`) gives the warning "literal defaulted" (and `roc build` exits 2). Write `2.U64.pow(n)`. `U64` has no `shift_right_by`: use `//` and `pow` |
| 4 | A mutation that leaves a variable unused or a condition constant does not compile. The mutations of `mutate.py` read the value (`take_first(0)`, `k >= 0`) |
| 5 | libFuzzer grows its inputs slowly, so an input that needs 100 bytes or more is rare in 20000 runs. D14 |
| 6 | `roc test` prints the crash text once for each `expect` that calls a stub (5 times for `solver.roc`, 2 for `domain.roc`) |

## 13. Red output

| Run | Result |
| --- | --- |
| `scripts/test.sh` with the stubs (`research/slice-034-revert/red-run.log`) | `check` pass, `fmt` pass, `l0` FAIL (only `packages/resolve/tests/domain.roc` and `solver.roc`, 70 other files pass), `l1` FAIL (only `tests/fuzz/pubgrub.roc`, `tests/fuzz/epochs.roc` passes), `l2` pass, `l3` pass, `selftest` pass (with the new row) |
| `l0` | `Roc application crashed with this message: todo`, for each `expect` of the 2 files |
| `l1` | `tests/fuzz/pubgrub.roc: FAILED (exit 77, seed 1, 20000 runs)`, `[roc crashed] todo` |

With the private reference in place (`research/slice-034-revert/green-run.log`): `scripts/test.sh` exits 0, `roc test` gives "All (2) tests passed" and "All (5) tests passed", and `l1` passes (11.1 s).

## 14. Revert check (TW12)

`research/slice-034-revert/mutate.py` puts 49 small changes of the private reference in `packages/resolve/` (one file at a time, a copy over the file), each compiled with `roc check packages/resolve/main.roc` (0 errors and 0 warnings), then the 2 L0 files and then the `l1` step. At the end the stubs are copied back (`cmp` equal). Final log: `mutate-final.log` (`mutate.log`, `mutate2.log` and `mutate3.log` are the earlier runs, see D14).

| Group | Changes | L0 | L1 |
| --- | --- | --- | --- |
| Order of the values (highest and lowest swapped, a tie in the reverse byte order, a tie in the order of the input, the order reads only the minor and patch) | d01, d02, d02b, d16 | caught | d01, d16 caught. d02, d02b: the L1 world has no tie |
| Ranges (any in place of all) | d03 | caught | not caught: the L1 world has at most one range for each slot, so any and all are the same |
| R-C6, R-C7 (a yanked release is a value, too young not applied, `>=` in place of `>` for the age and for the snapshot, the snapshot ignored) | d04, d06 to d09 | caught | caught |
| R-C9 (the header value is hidden when yanked, young or late, not added when the list lacks it, a range does not exclude it) | d05, d10, d14, d15 | caught | caught |
| A named version (hidden when young, a value when yanked) | d12, d13 | caught | not caught: the L1 world has no named version (D14, Q1) |
| R-C4 (an `App` release is a value of a package slot or of a platform slot, only `App` is checked, a release with no fact is not fit, a fact for another release is read) | s01 to s04, s28 | caught | caught |
| R-C2 (`>` in place of `>=`, a dep on the own group is read, the name of the slot in place of the group, a limit above all values is not read, the deps are not read) | s05 to s07, s11, s31 | caught | caught |
| R-C3 (a platform that is no value does not exclude, the platform is not read, the platform of a platform slot release is read, the check holds with 2 platform slots) | s10, s32, s08, s09 | s10, s32 caught. s08, s09 not caught | s10, s32 caught. s08, s09 not caught |
| Decisions and the search (the worst value, learn only the last decision which is unsound, the conflicts of the caller not read, the sign of a term swapped, an unknown name applies without its term, 2 terms of one slot not joined, a Contra term does not stop a propagation) | s12, s13, s30, s21, s20, s33, s18 | caught | caught, except s13 |
| The protocol (`Need` names all chosen ids, the first missing id only, the ids in reverse, `Done` with one fact missing, the facts of releases outside the first value of a slot are not read) | s14 to s17, s29 | caught | caught |
| The request (the version of a chosen is its id, the strategy ignored, the header value, the ranges, the named version or the rules not passed to the domain) | s22 to s27 | caught | caught, except s27 (no named version in L1) |
| A term with no value still gives an incompatibility (s34) | s34 | not caught: the change is equivalent (such a term is `Contra` in each state, so the incompatibility never fires) | not caught, same reason |

Result: L0 catches 46 of 49. The 3 that it does not catch: s08 (a platform slot release with a `pf` field: no design rule, a header of a platform has no platform entry, so the L1 world does not make one), s09 (2 platform slots, Q2, not tested), s34 (equivalent). L1 catches 39 of 49: the 3 above, and d02, d02b, d03, d12, d13, s27, s13. The first 6 are cases that the L1 world does not make (a tie, 2 ranges, a named version). s13 (learn only the last decision) needs a conflict that shows 3 decisions deep: the L0 row of `solver` 5 has it, and the L1 world (3 slots, 2 conflicts) does not make one in 20000 runs.

A change that removes unit propagation (the `fire` result `Moved` becomes `Stable`) does not end: with learning and no propagation the learned incompatibility has no effect (the same decision is made again). It was run for 100 s and stopped, and it is not in the list. A pure depth-first search with no learning and no propagation gives the same result, only slower (section 9).


## 15. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The docs of `packages/resolve/Domain.roc` and `Solver.roc` have the contract. The signatures stay (section 3) |
| N2 | The search of the reference (about 80 lines): per variable a list of the possible values (places in its list). An incompatibility is a list of terms (a variable and a set of places). Unit propagation: an incompatibility with one open term and all others true takes that term out. All terms true is a conflict. A decision takes the first variable with more than one place and its first place. A conflict learns the decisions (as an incompatibility) and goes back one decision. The decisions are made again from the start each time, so the state is data |
| N3 | An incompatibility with 2 terms on one variable joins them (the places that both hold). A term with no place never applies |
| N4 | Unit propagation must work: a search with learning and no propagation does not end |
| N5 | Roc: a local variable must not have the name of a function of its type module. `var`, `platform`, `with`, `package` are reserved. `Str` has no sort (the domain sorts with `Semver.order_relative_to` and a byte compare) |
| N6 | Do not edit a test (TW18). A question goes to the manager |
| N7 | `cli/` does not import `resolve` in this slice. `scripts/test.sh` must exit 0 with no change to `cli/` |

## 16. Next step

Review (the human): D1 to D14, Q1 to Q3, G1 to G5, the budget (l1 11.1 s of 60 s). Then the code agent. Slice 035 takes the conflict resolution and the explanation. Slice 036 wires `resolve` into the commands, adds the path entry to `cli/lib/main.roc`, and decides Q3.

## Review (manager, 2026-10-23)

Accepted, no split. Answers:

| # | Answer | Effect |
| --- | --- | --- |
| Q1 | Keep the P0 reading (slice 005 D7, `cli/lib/Pick.roc` line 26): a version that the user named is hidden by neither min-release-age nor the snapshot. The R-C7 text names only min-release-age: the manager records it for the next design edit (G3) | 2 new L0 rows in `domain` 2: a named version after the snapshot time stays a value (the same release with no name does not), and a range `=1.0.0` still hides a named version that it does not admit. The first row fails when the snapshot hides a named version (checked by hand) |
| Q2 | Accepted as P0: R-C3 is checked only with exactly one platform slot | No new test |
| Q3 | Accepted: after `Done` the caller walks the closure (R-AL9) and feeds a failure back as a conflict (slice 036) | |
| D1 to D14 | Accepted. D5: slice 035 replaces the "go back one" learning with PubGrub conflict resolution. `Why` stays a placeholder that no test reads | |
| G1, G2, G4, G5 | Recorded by the manager in `PLAN-P1.md` 5b. `TESTING.md` and the design files are not edited | |
| Selftest rows, L1 11.1 s, l0 6.2 s | Accepted | |

Done after the review: the 2 rows, the private reference deleted (`mutate.py` stays as the record), status `code`. Red state confirmed again (section 13).

## Code result (code agent)

`scripts/test.sh` exits 0 (no `WARN` line). `OPT=speed scripts/test.sh` exits 0 too (l1 19.5 s).

| Step | Result | Seconds | Budget |
| --- | --- | --- | --- |
| check | pass | 1.1 | 10 |
| fmt | pass | 0.2 | 5 |
| l0 | pass | 6.1 | 10 |
| l1 | pass | 13.7 | 60 |
| l2 | pass | 1.1 | 30 |
| l3 | pass | 9.8 | 60 |
| selftest | pass | 8.5 | 20 |

| File | Lines |
| --- | --- |
| `packages/resolve/Domain.roc` | 90 (was 28) |
| `packages/resolve/Solver.roc` | 259 (was 55) |

No test, fixture, `tests/fuzz/`, script or design file changed. No signature changed. No dispute rows. `cli/` is not touched (N7).

Shape of the code (the package cannot import `cli/`, D1):

| Part | Where | What |
| --- | --- | --- |
| `Domain.values` | `packages/resolve/Domain.roc` 30 to 90 | The 5 rules of the doc. It is a small copy of the rules of `Pick.domain_of` (header value, ranges with `VersionReq`, yanked, young, snapshot, named exempt, semver order, byte tie) |
| Variables, incompatibilities | `packages/resolve/Solver.roc` 92 to 183 | A variable is a slot with its domain, less the releases that a fact shows to have the wrong kind. A fact gives incompatibilities of places (R-C2, R-C3). The conflicts of the caller are terms on places (N3 joins 2 terms of one slot) |
| Unit propagation | `Solver.roc` 186 to 230 | `propagate`, `first_move`, `fire`, `class_of` (N4) |
| Search | `Solver.roc` 232 to 259 (`replay`, `search`) | Decisions are made again from the start each time (D4). A clash learns the decisions that were in force (not all of them) and goes back to the one before. A clash with no decision is `Fail` |
| Protocol | `Solver.roc` `step` | `Need` has the ids of the chosen releases that have no fact, in the order of the slots, with no repeat. `Done` otherwise |

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | A clash learns only the first `depth` decisions, where `depth` is the stage of the replay at which the clash showed (a clash that shows before the last decision does not learn the later ones). Sound, and it ends | Learn all decisions (a weaker incompatibility, and the search then does not end when it goes back one) |
| C2 | `Need` has no repeat (two slots with one release give one ask). The doc does not say it, the L1 property does | A repeat |
| C3 | An empty list of terms is a conflict that is always true: `Fail`. No test has it | Ignore such a conflict |

Questions (TW17): none.

## Verify results (code agent)

Source: `research/slice-034-revert/agent-mutate.py`, `agent-run.log`, `agent-results.md`. 48 small changes, one at a time, each over a fresh copy of `code-final/`. Final check: `sha256sum -c research/slice-034-revert/code-final.sha256` from the repo root gives OK.

Caught 43 of 48 (all by L0; l1 ran for the 5 that L0 missed and did not catch them either). The 2 that do not end (unit propagation off, going back to the same decisions) are stopped by the 30 s timeout.

| Id | Change | Result | Kind |
| --- | --- | --- | --- |
| m27 | the platform check with 2 platform slots uses the first | not caught | Test gap: Q2 (accepted, not tested). Closed: gap row 1 |
| m28 | the platform slot's own release is checked against its own `pf` | not caught | Test gap, low value: no design rule gives a platform release a `pf` (D8) |
| m39 | a term with no value still gives an incompatibility | not caught | Equivalent: such a term is false in each state |
| m49 | `Need` can name a release twice | not caught | Test gap: no row has 2 slots with one release (D11). Closed: gap row 2 |
| m56 | the names of a `Fail` are the other slots | not caught | Test gap by design: `Why` is a placeholder (D5) |

The full list with each change is in `research/slice-034-revert/agent-results.md`.

## Gap tests (test agent, 2026-10-23)

Only tests and this file changed. No file of `packages/resolve/*.roc` or `cli/` changed. m27, m49 and the new C3 change were applied by hand (`research/slice-034-revert/gap-mutate.py`, log `gap-mutate.log`): the new row failed, and `code-final/` was copied back over the package (never a delete). `sha256sum -c research/slice-034-revert/code-final.sha256` gives OK for both files. m28 (no design rule), m39 (equivalent) and m56 (`Why` is a placeholder, D5) stay open on purpose.

| Gap | New row in `packages/resolve/tests/solver.roc` | Result of the change |
| --- | --- | --- |
| m27 (the platform check holds with 2 platform slots, the first one) | `solver` 4: slots `x`, `p1`, `p2` (2 platform slots), `x-2.0.0` names `p2-1.0.0`: the step gives `done x=2.0.0 p1=1.0.0 p2=1.0.0` (Q2: no check with 2 platform slots) | L0 caught (that row) |
| m49 (the repeat guard of `Need` is removed) | `solver` 2: the slots `a` and `b` have the one release `a-1.0.0` and no fact: `need a-1.0.0`, once (code decision C2) | L0 caught (that row) |
| C3 (a conflict with no terms gives `Fail`) | `solver` 5: `r([[]])` gives `fail` (code decision C3: a conflict with no term is always true). The change makes such a conflict be ignored | L0 caught (that row) |

Closed: m27 and m49 in the table above. After the gap rows, `scripts/test.sh` exits 0 (`research/slice-034-revert/gap-green.log`: check 1.0, fmt 0.1, l0 6.1, l1 13.6, l2 1.0, l3 9.9, selftest 8.4 s, no WARN). No background process runs.

## Close (manager, 2026-10-23)

Code decisions C1 to C3 are accepted. Of 48 mutations, 43 were caught by L0. The gap rows catch m27, m49 and C3. m28 (no design rule), m39 (equivalent) and m56 (`Why` is a placeholder until slice 035) stay open on purpose. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l1 13.7 s). Status: done.
