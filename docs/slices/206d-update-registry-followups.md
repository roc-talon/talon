# 206d Registry in update: unknown values, offline

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 206d of `PLAN-P2-CLI.md`. It continues slice 206b (the setting is read in `InstallFlow` after `ResolveLoad.prepared!`; the first query runs in `PickFlow.query!` after the scope).

## Split (accepted by the manager: 206d2 is in `PLAN-P2-CLI.md`)

The row has 4 parts. Each needs its own L2 fixtures, and part 2 needs a closure that has no tuple with the held variables fixed. One review of all 4 is too large (TW19). The test agent proposes 2 sub-slices:

| # | Sub-slice | Content | Rules | Depends on |
| --- | --- | --- | --- | --- |
| 1 | 206d (this file) | Part 1: `UnknownValues.settle!` after the first query of `tln update`, the `Label` and `Archive` ends in the pick and `Gather`, the `fixed: not in the registry index` line. Part 3: `--offline` with a registry (`Offline` index, the R-IX6 note) | R-AP28, R-AP65, R-DI7, R-DI11, R-C9, R-IX6, R-AD37, R-DI12, R-IX5 | 206b, 208 |
| 2 | 206d2 | Part 2: the second query of a held move (R-SP16, R-SP23, R-SP24, `LogSnapshot.second!`), with the movable groups and the ranges of a moved variable. Part 4: `--json` `snapshot` with a time snapshot (Q438: the time and the log size apart, `Report.Outcome`), and `log:N` in the compiler range step (`ResolveSelect.snapshot_of`) | R-AP16 (second), R-SP16, R-SP23, R-SP24, R-AP19 (second), R-DT5, R-J3 | 206d |

Reason for the order: part 2 uses the index of part 1 (an anchor of R-DI11 is never movable, R-SP23, and the first answer after `settle!` gives the `log_size` of the second query). Part 4 is small and is about the snapshot, as the second query (`second_cut` uses the N of the user).

The rest of this file is sub-slice 1.

## Scope

| In | Out (where) |
| --- | --- |
| `tln update` with a registry: `UnknownValues.settle!` after `ClosureIndex.query!`, before `LogSnapshot.hide_above` | The other commands (`install`, `verify`, `upgrade`, `outdated`): 206e, 206f |
| The ends of a value in the pick and in `Gather` (R-DI7, R-C9, Q425), the anchor of a group with no row in the answer (R-AP28, R-DI11) and its line | The second query of a held move, `--json` `snapshot` with a time, `log:N` in the compiler range step: 206d2 |
| `tln update --offline` with a registry: the index `Offline(origin)`, no guard, no request, the R-IX6 note | A candidate whose archive is not in `packages/` (R-IX6, R-DI12: skipped): not in a case of this slice (the direct rule, no change) |
| | The L3 case with the real `curl` children (slice 208 list, row 6): 206f |

## Rules

R-AP28, R-AP65, R-DI7, R-DI11 (registry part), R-C9, R-IX6, R-AD37, R-DI12 (Registry 4.1; CLI 7.3, 6.1; Resolution 2). As used: R-AP9, R-AP41 row 5, R-AP43, R-DA8, R-AP34, R-AP19, R-DT5, R-RG4, R-RG5, R-DI14, R-AL8, R-IX5, R-PU40, Design Q421 to Q425.

## Code shape

One new pure function (Design Q461): `ClosureIndex.drop_labels : { list : List(Index.Candidate), known : List(Str) } -> List(Index.Candidate)` (stub `crash "todo: slice 206d"`, rules in its doc). It drops a candidate whose group form and version are those of a header URL in `known` with another hash. The other decisions exist: `UnknownValues.classify`, `ingest_verdict`, `anchor_note` (slice 208), `ClosureIndex.offline!`, `candidates` (slice 206), `LogSnapshot.hide_above` (slice 207). The rest is command code (part C): the code agent changes `PickFlow`, `PickIndex`, `InstallFlow` (where it wants).

## Reading that the tests fix

| # | Topic | Reading |
| --- | --- | --- |
| 1 | Order | Guard, the first query, `settle!` (the warnings of case 1 source 1, `programs curl`, one `http_all`, the warnings of the answers, the second query), then `hide_above` for `--snapshot log:N`, then the index `Answer` with the answer that `settle!` gives |
| 2 | `settle!` input | `urls`: the header values of the members (the `entries` of the first query). `facts`: the facts of the first query (the second query has the same body). `snapshot`: true for `--snapshot log:N`, false for a time and for none. `first`: the first answer, not hidden |
| 3 | `Indexed` | The facts come from the record of the answer of `settle!` (R-AL8 source 2): no archive read |
| 4 | `Label`, `Archive` | The facts come from the archive in `packages/` (R-DI7, Q425), in the one `Gather` read of the ids with no record. The header value stays in the domain (R-C9) |
| 5 | Anchor | A value whose `anchor_note` is `Ok` (no release of its group in the answer of `settle!`) acts as in R-DI11: its group is an anchor at its header value, and the line `<alias>: fixed: not in the registry index` is printed once for each such value (the alias of its header entry, Q462), in the order of `unknown` (stdout, after the warnings, before `check:`). The anchor itself (held, not free) gives no other output with `--no-check` (revert M8): 206d2 tests it through R-SP23 |
| 6 | Another host with a registry | It is a value of case 3 (R-PU40), so it has the line of row 5. The line of `direct` (`fixed: <host> has no index without a registry`, R-DI11 first part) is not printed with a registry: that text is false with a registry, and R-AP28 gives the registry text |
| 7 | `--snapshot log:N` | No ingest, no `programs` call, no second query (R-AP28 case 3); a `Label` of source 1 keeps its warning; every github value of `unknown` is `Archive` |
| 8 | The printed log size | `log:<log_size>` of the answer that `settle!` gives (51 after the ingest, not 50): it is the answer that the command uses (Design Q460). It is also "the first answer" of a held move (206d2) |
| 8b | A `Label` value (Design Q461) | The registry's release of the same group and version with another hash is no candidate (`ClosureIndex.drop_labels` with the header values as `known`): the pick keeps the header URL, and its facts come from the archive (Q425). Other versions of the group stay |
| 9 | `--offline` and a registry | The setting is read (a bad text stops, as in 206b). Then the index is `Offline(origin)`: no guard, no request, no `talon/index/github/` (R-IX5). `PickIndex.index!` gives the candidates from the kept copies (`ClosureIndex.offline!`). The facts come from the archives (R-DI7). One `index: cached at <oldest>` line on stderr |
| 10 | R-IX6 note | A variable whose group has no copy (`missing`, or its form in `missing_forms`) acts as in R-DI11 and prints `<alias>: fixed: offline, no cached index` (Q462, the alias of the first use; stdout, after the index step, in the order of the variables) |
| 11 | No registry | `Off` and a `Setting` that reads `direct`: the same calls and output as before (all old L2 cases pass with the private reference) |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ClosureindexTest.roc` (driver `l0-8.roc`), 2 new expects: `drop_labels` drops the registry's 1.0.0 with another hash and keeps 1.1.0 (a header URL with the same hash drops nothing); a header URL of another form (`v{v}`), of another repository, and a path drop nothing | Q461, R-AP28, R-C9 |
| L2 | `registry/ap28-update-unknown` (entry `commands`, 3 runs, the case file `rules` has the detail). Header: pf (indexed), json (case 2, 201 with a bookmark, then indexed), parser (case 1 source 1: the answer has parser 1.0.0 with another hash), csv (case 2, 422: archive), yaml (case 2, 409 `label-conflict`: case 1 source 2, Q425), other (`example.org`: case 3). Run 1: the order of row 1; json's facts from the second answer (no archive read, no line); 3 `fixed` lines (csv, yaml, other); one read of the 3 archives; parser moves to 1.2.0; no `example.org` line of `direct`; `resolved at log:51`. Run 2 (`--snapshot log:40`): no ingest, no `programs`, no second query, the parser warning, 4 `fixed` lines, 4 archives read, `resolved at log:40`. Run 3 (`--snapshot log:30`, Q461): the snapshot hides parser 1.2.0, so the only parser row is the registry's 1.0.0 with another hash: parser keeps the header URL (`nothing to change`), and its archive is read with the 4 others (Q425). All `fixed` lines carry the alias (Q462) | Q461, Q462, R-AP28, R-AP65, R-DI7, R-DI11, R-C9, R-AP9, R-AP41, R-AP43, R-DA8, R-AP34, R-AP19, R-DT5, R-RG4, R-DI14, R-AL8 |
| L2 | `registry/ix6-update-offline` (entry `commands`, 1 run): `update --no-check --dry-run --offline` with the registry of `config.toml`. No request, no guard read, no GitHub page. json: the group copy, moves to 2.1.0. parser: the repository copy, the rows of its form only, moves to 1.2.0. pfx: no copy, stays, `pf: fixed: offline, no cached index` (Q462). One `index: cached at 2026-10-14T15:00:00Z` (the oldest copy). Archive reads of the 3 chosen releases. `resolved at 2026-10-15T12:00:00Z, 0 probes` | R-IX6, R-AD37, R-DI12, R-IX5, R-DI11, R-DI7, R-DI14, R-DT5 |

The fixtures are made by `research/slice-206d-revert/mkcases.py` (given and fx only; it deletes and writes the 2 case dirs, so run it only before the expect files are written). The expect files were written from the rules above, and each line was checked against them (calls, warnings, lines, reads) and against a private reference run (see Revert check).

## Red result

After the answers (2026-11-03):

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-8.roc` | 189 pass, 2 fail: the 2 `drop_labels` expects (`todo: slice 206d`) |
| `tests/commands/run.sh` | 302 pass, 5 fail: the 2 new cases, and `tool/rm1`, `rm2`, `rm7` only because of the private `TMPDIR` (as before) |
| `roc check cli/lib/ClosureIndex.roc`, `roc fmt --check` of the 2 changed Roc files | pass |

First round (before the answers):

| Run | Result |
| --- | --- |
| `tests/commands/run.sh` (a build of the current tree) | 290 pass, 16 fail: the 2 new cases (`ap28-update-unknown`: no ingest, no second query, the `direct` line of `example.org`, `log:50`; `ix6-update-offline`: the run reads the GitHub pages of `direct` and says `nothing to change`), the 11 `share/sh11` to `sh21` cases of slice 216 (`todo: slice 216`, another session), and `tool/rm1`, `rm2`, `rm7` only because the private run used another `TMPDIR` (a size that holds the path; they fail the same way on the unchanged code) |
| `MISSING=1 scripts/rules.sh R-AP28 R-AP65 R-DI7 R-DI11 R-C9 R-IX6 R-AD37 R-DI12` | none missing |
| `roc check`, `roc fmt` | No Roc file changed |

## Expected exits (read, TW21)

`ap28-update-unknown`: `expect/exit` 0; the 3 runs `exit 0`; stderr has 4 warnings (run 1: parser with the hash of the registry, yaml with `another hash`; run 2: parser; run 3: parser). Run 3 prints `nothing to change` and no `resolved at` line (the line of a run with no change, as before the slice). `ix6-update-offline`: `expect/exit` 0; one run, `exit 0`; stderr one line `index: cached at 2026-10-14T15:00:00Z`. `tree.diff` of both: only `projects.json` (dry runs).

## Revert check

`research/slice-206d-revert/`: `before/` (the 3 files before the slice, and `ClosureIndex.roc` with the stub), `mkcases.py`, `results.txt`. A private green reference and 8 mutations were run in a private copy of the tree, then a second reference after the answers and 5 more mutations (N1 to N5); each reference, tree and script was deleted (TW18).

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | no `settle!` (the 206b flow) | `ap28-update-unknown` |
| M2 | `settle!` ignores `--snapshot log:N` | `ap28-update-unknown` run 2 |
| M3 | the index keeps the first answer | `ap28-update-unknown` |
| M4 | the anchor line reads the rows of the first answer | Not caught: equivalent in this fixture |
| M5 | the `direct` line of R-DI11 also with a registry | `ap28-update-unknown` |
| M6 | `--offline` with a registry stays `direct` | `ix6-update-offline` |
| M7 | no R-IX6 note | `ix6-update-offline` |
| M8 | no anchor (the free variable with no candidate stays free) | Not caught: with `--no-check` the pick keeps the header value (R-C9). 206d2 |
| N1 | (Q461) the command does not call `drop_labels` | Not caught at L2: the pick of today tries the registry's row first (it is first in the order of the domain), then drops that tuple on a closure conflict (the header entry of the same label stays in the closure), so run 3 has the same output. L0 fixes the decision |
| N2 | `drop_labels` ignores the hash | L0 |
| N3 | `drop_labels` ignores the version | L0, 4 L2 cases |
| N4 | (Q462) the anchor line with no alias | `ap28-update-unknown` |
| N5 | (Q462) the offline line with no alias | `ix6-update-offline` |

## Output (proposed, R-OUT2)

| Case | Text |
| --- | --- |
| A value of case 3 or of `Label` with no release of its group | `<alias>: fixed: not in the registry index` (Design Q462), stdout, one line for each value. Done in the expect files |
| A group with no copy, `--offline` | `<alias>: fixed: offline, no cached index` (R-IX6, Design Q462), stdout, one line for each variable. Test change: the L2 expect files (`ix6-update-offline`, `ap28-update-unknown`) get the alias before `fixed:` (done) |
| R-DT5 with `--offline` and a registry (no answer, no log size) | `resolved at <now>, <n> probes`, as `direct` |
| The warnings | The texts of slice 208 (`label_warning`), stderr |

## Questions

| # | Question | State |
| --- | --- | --- |
| Q1 | R-DT5 after the second query of R-AP28 case 2 (the query after the ingests): the command uses the second answer, whose `log_size` is larger (51) than the first (50). R-AP19 says "the `log_size` of the first answer" for the second query of a held move (R-AP16); R-DT5 says "the `log_size` of the closure answer". Which number does `update` print, and which answer is "the first answer" for the `log:N` of a held move (206d2)? The test fixes the proposal: the answer that `settle!` gives (51), because the command uses its releases and `--snapshot log:51` repeats the resolve | Answered (Design Q460, Resolution R-DT5): 51, the `log_size` of the answer the command uses. The first answer of a held move is that answer too (206d2). Test change: none for 206d (the test already fixes 51); 206d2 hides the second answer above the smaller of N and 51 |
| Q2 | A `Label` value (case 1 source 1): the registry's release of the same label (another hash) is a candidate of the group ("the other candidates of its group come from the registry"). When the pick keeps the version of the header, it has 2 candidates of one version with 2 URLs. Must the pick keep the header URL (R-C9) and drop the registry's row of that label, or can it move to the registry's hash? | Answered (Design Q461, Registry R-AP28): the pick drops the registry's row of that label with another hash and keeps the header URL. Test change: add an L0 `expect` in the pick tests: a `Label` value 1.1.0 and a registry row 1.1.0 with another hash: one candidate, the header URL; and a case where the pick would have moved to the other hash. The fixture of 206d stays |
| Q3 | `--offline` with a registry and a header value of another host (G-C101) | Answered (Design Q465, CLI R-IX6): `<alias>: fixed: not in the registry index`, as online. Test change: the L2 case `ix6-update-offline` gets a header value on a host other than `github.com` and expects that line; an L0 `expect` that the offline note for such a value is not `no cached index` |
| Q3 test change (done, 2026-11-03) | | `ix6-update-offline`: the header has `other` (example.org, archive in `packages/`). Expected by hand: `other: fixed: not in the registry index` before `pf: fixed: offline, no cached index` (the order of the variables: packages, then the platform), no copy read for it, and its archive in the one read (json, parser, other, pf). Exit 0. `mkcases.py` and `rules` changed. Red on the current code: only the new line is missing. No L0 `expect`: the note is chosen in command code, and a pure function needs a stub in `cli/`, which this follow-up must not edit (the 206d2 test agent works there); the code agent can add one |
| Q2 test change (done) | | The rule is a pure function, `ClosureIndex.drop_labels` (stub), with 2 L0 expects in `ClosureindexTest.roc` (version 1.0.0; the pick tests build no candidates from an answer). L2 run 3 of `ap28-update-unknown` fixes the command outcome. No L2 run can show the move: the pick of today already drops the tuple with the registry's row on a closure conflict (revert N1) |
| Q462 | The text of the 2 `fixed` lines | Answered (Design Q462): `<alias>: ...`. Test change done: the expected stdout of both cases |

## Notes for the code agent

| # | Point |
| --- | --- |
| 1 | The first query is `PickFlow.query!`; `settle!` needs `roots` (`request.roots`) and `version` (`Help.version`) |
| 1b | Q461: `ClosureIndex.drop_labels` on the candidates of the `Answer` index, with the header values as `known` (`PickIndex.index!` has them) |
| 2 | Reading row 5: the anchor can be a `missing_forms` item of the name in `PickIndex.index!` for `Answer` (the known forms with no row in the answer) |
| 3 | Reading row 6: the `Fixed` note of `Vars.scope` is printed in `PickFlow.prepare!` |
| 4 | Reading row 9: `InstallFlow.with_setting` gives `Off` for `--offline` today; the index must become `Offline(origin)` |

## Code

| File | Change |
| --- | --- |
| `cli/lib/ClosureIndex.roc` | `drop_labels` (Q461): drops a candidate when a `known` URL (`Ident.of_url`) has its group form and version and another hash |
| `cli/lib/PickIndex.roc` | `index!`: `drop_labels` on the candidates of the `Answer` index, with `known` |
| `cli/lib/InstallFlow.roc` | `with_setting`: `--offline` with a registry gives `registry: Off` and `index: Offline(origin)` (no guard, no request) |
| `cli/lib/PickFlow.roc` | `query!`: `UnknownValues.settle!` after the first query (`urls`: the entries, `snapshot`: true for `log:N`), the `<alias>: fixed: not in the registry index` line of each value whose `anchor_note` is `Ok` (alias of the header entry, order of `unknown`), then `hide_above` on the answer of `settle!`; the index is that answer (so R-DT5 prints its `log_size`, Q460). It also gives the anchor URLs. `prepare!`: no `direct` R-DI11 note of a `Fixed` host with a registry (`Read` or the `Offline` index, Q462); `anchored` adds the form of each anchor to `missing_forms` of its name (the pick holds the header value); `offline_notes!` prints `<alias>: fixed: offline, no cached index` (R-IX6) after the index step |
| `cli/lib/PickFlow.roc` (follow-up, Design Q465) | `prepare!`: with the `Offline` index, a `Fixed` host prints `<alias>: fixed: not in the registry index` (the alias of the first use) in place of the `direct` line |

Notes for the review:

| # | Point |
| --- | --- |
| 1 | `--offline` with a registry and a value of another host: answered as Design Q465 (G-C101). `prepare!` prints `<alias>: fixed: not in the registry index` in place of the `direct` line, before the R-IX6 notes (follow-up, `ix6-update-offline` entry `other`) |
| 2 | The anchor note reads the rows of the answer of `settle!` before `hide_above` (reading 5, revert M4: equivalent in the fixture) |

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206d-revert/code-final.sha256` | 4 of 4 OK (`ClosureIndex`, `PickIndex`, `InstallFlow`, `PickFlow`) |
| `todo: slice 206d` in `cli/` | None |
| `scripts/test.sh check fmt l0 l2 l3` | All pass (code agent run: l2 307 of 307, l3 97 pass and 3 skipped; TW20 warnings only) |
| Slice cases | L0 `drop_labels` 2 expects. L2 `registry/ap28-update-unknown` (3 runs), `ix6-update-offline` green; all 35 registry cases green. |
| Expected exits | All 0. stderr: the label and ingest warnings, the `index: cached at` line. |
| Revert check | Round 1: 6 of 8; round 2: 4 of 5. Not caught: M4 (same output with these fixtures), M8 (anchor hold, for 206d2), N1 (drop_labels not called: the pick drops the tuple on a closure conflict; L0 carries the rule). |
| Design answers | Q420 to Q425 (from 208), Q460, Q461, Q462 |
| G-C101 | Answered as Q465: offline, a value of another host prints `<alias>: fixed: not in the registry index`. `ix6-update-offline` has the value; code changed in `PickFlow.prepare!`; 35 of 35 registry cases green. |

