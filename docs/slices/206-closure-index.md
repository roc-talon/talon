# 206 Closure answer as the index

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 206 of `PLAN-P2-CLI.md`. The seam: with a registry, `PickIndex`, `ResolveBase` and `Gather` get the candidates, the kinds, the deps and the rank 4 hints from one closure answer (`records.Closure.Answer`), in place of GitHub pages, archive reads and `.roc-version` requests. One command uses one index (R-DI14). `--offline` with a registry (G-C9) uses the kept copies (CLI R-IX6, Design Q205).

## Scope

| In | Out (where) |
| --- | --- |
| New module `cli/lib/ClosureIndex.roc`: the `Source` of a run, the pure reads of an answer (`candidates`, `header`, `hint`, `checked_of`), the query flow `query!`, the offline flow `offline!` | The query step in the flows (R-AL2 step 2): which groups and window a command sends (R-DI1, R-AP16), the set of `Request.index` to `Answer` after the query. A command reaches a registry only after the registry setting (R-RG1, R-RG2: slice 224). Proposal: slice 206b, after 224 or with a test word |
| `ResolveBase.Request.index` (every constructor gives `Direct`) | The second query of a held move, `log:N` (slice 207) |
| `Gather.facts!`: R-AL8 source 2 before sources 3 and 4 | `unknown` hashes, R-AP28, R-AP65, the anchor note `fixed: not in the registry index` (slice 208) |
| `PickIndex.index!` by the index: `Answer` (no GitHub call), `Offline` (the copies) | `epochs`, `runs`, `nearest`, `hints` as evidence (slice 209) |
| `PickLoop.hints!`: rank 4 from `roc_version` | The `checked` note text (slice 210). This slice only reads the item (`checked_of`) |
| `ResolveBase.read_releases!`, `Walk.level!` and `PickLoop.read_all!` read records through `Gather.facts!` | Yank (R-C6, P3: `yanked` is always false before P3) |
| | The note `fixed: offline, no cached index` of R-IX6 (the output of `update` and `outdated` with a registry: a command slice) |

## Rules

R-AP17, R-AP18, R-AP20, R-AP42, R-AP49 (reader), R-AP63, R-AP64, R-DI14 (Registry 4.1, 4.2, 5; CLI 7.3; Resolution 5). G-C9: R-IX6, R-AD37, R-DI12, R-IX5. As used: R-AL8 (source 2), R-AL9, R-AP34 (no second try), R-AP50, R-AP74 rows 1 and 4, R-E6, R-IX3, R-EF1 rank 4, R-DI8.

## Decisions (pure, L0) and flows (L2)

| Name | Signature | Rule |
| --- | --- | --- |
| `ClosureIndex.Source` | `[Direct, Answer({ origin : Str, answer : Wire.Answer }), Offline(Str)]` | R-DI14, R-IX6 |
| `ClosureIndex.Header` | `{ release : Release, entries : List(Closure.Entry), target_names : List(Str) }` | R-AL8 |
| `ClosureIndex.candidates` | `{ releases, artifacts, name } -> List(Index.Candidate)` | R-AP17, R-AP49, R-AP50, R-AP63 |
| `ClosureIndex.header` | `Wire.Answer, Str -> Try(Header, [NotInAnswer])` | R-AL8, R-AP17, R-AP49 |
| `ClosureIndex.hint` | `Wire.Answer, Str -> Try(Str, [None])` | R-EF1 rank 4, R-AP49 `roc_version` |
| `ClosureIndex.checked_of` | `Wire.Answer, Str -> Try(Wire.Checked, [None])` | R-AP64 |
| `ClosureIndex.query!` | `Fx, { origin, version, facts : ClosureRequest.Facts } => Try(Wire.Answer, Fail)` | R-AP20, R-AP34, R-AP74, R-IX3 |
| `ClosureIndex.offline!` | `Fx, { roots, origin, version, now, name, forms } => Try({ list, missing, oldest }, Fail)` | R-IX6 |
| `Gather.facts!` | `Fx, { roots, net, offline, selected, none, index }, List(Str) => Try(List([Record(..), Text(Got)]), Fail)` | R-AL8, R-DI14 |
| `PickLoop.hints!` | `Fx, { net, roots, offline, index }, List(OracleBase.Pair) => List({ id, hint })` | R-EF1, R-DI8, R-DI14, R-IX6 |
| `PickIndex.index!` | unchanged signature, reads `request.index` | R-DI14, R-IX6 |
| `ResolveBase.Candidates` (Q391, code agent) | proposal: a new field `missing_forms : List(Str)`, the URL forms of the name with no copy. `missing` keeps its meaning: no group of the name has a copy (and the direct cases as before). `PickIndex.slots_of` holds a variable when `missing` or its form is in `missing_forms`. The L2 harness prints `missing-group <name> <form>` for each item (a line the test agent adds once the field exists) | R-IX6, R-DI11 |
| `ClosureIndex.query!` (Q390, code agent) | step 4 also refuses a decoded answer with a release whose `log_index` is greater than `log_size` (exit 15, the text in Output) | R-AP18, R-E6 |
| `ClosureIndex.offline!` (Q392, code agent) | a copy whose body does not decode (`records.Index.decode_releases` is `Err`): remove its 2 files (body, then meta), print the warning of Output on stderr, and go on as with no copy | R-IX6, R-TF6 |
| `flowprobe registry-index` (Q392, code agent, `cli/flowprobe.roc`) | `registry-index --offline --origin <url> [--known <url>]... <owner>/<repo>...`: `PickIndex.index!` with the real `Fx`, a request with `offline` and the index `Offline(<origin>)`, the roots of `Roots.from_env`, the clock of `Fx.clock!`. stdout: as the L2 word `offline` (`candidate ...`, `missing <name>`, `missing-group <name> <form>`). A failure: its line on stderr and the exit code of its kind | R-IX6, R-TF6 |
| `Walk.run!` | the input gains `index` | R-AL8, R-AL9 |

The tables of rules are in the doc comments of each stub. The tested reading:

| # | Topic | Reading |
| --- | --- | --- |
| 1 | Candidates of a name | The release rows whose `repo` is the name in lower case, in the order of the answer. Not filtered by range or series (R-AP63: the answer has what was asked; the release of a header value stays). The solver applies the range |
| 2 | `withdrawn` | Any text (also one Talon does not know) makes the release no candidate (R-AP49, R-AU2, R-C6) |
| 3 | A candidate | `published_at` / 1000 (R-AP50), `tag` null is `""`, `size` from the artifact of the hash (0 with no record: a kept copy has no artifacts, and offline never downloads) |
| 4 | Header facts | Found by the hash of the URL (the hash fixes the facts, R-AL8). `deps`: the `url` of each item, record order. A path id, or a hash with no record: not in the answer, so sources 3 and 4 |
| 5 | Order of `Gather.facts!` | The order of the ids. The ids with no record go to ONE `get!` call, none: no call |
| 6 | Hint | The row with this `url`, its `roc_version` read as a `.roc-version` text (`Github.hint` of 200). No request and no cache file. `Offline`: no hint (R-IX6: evidence is local only) |
| 7 | `query!` | One `http_send!` POST, `timeout_s` 20, no second try (R-AP34). `Err(NoCompiler)` of a `Free` window: `no_compiler`, exit 10, no request (R-AP74 row 4). Nothing is written (R-IX3) |
| 8 | `offline!` | For each known form: the copy of `?group=<form>` (no series). A form with no copy, or a name with no form: the copy of `/v1/packages/<owner>/<repo>/releases`, only the rows of those forms. `missing` when a form (or the name) has no copy. One line `index: cached at <oldest>` for the command (`PickIndex.index!`). No GitHub page (R-IX5) |
| 9 | Forms of a name (offline) | The group forms of the `known` URLs whose `Ident.name` is the name (any case), first appearance, each once |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ClosureindexTest.roc` (driver `l0-8.roc`): candidates (name case, withdrawn, other repo, other host, null tag, size, seconds) | R-AP17, R-AP49, R-AP50, R-DI14 |
| L0 | unknown withdrawn value; no artifact gives size 0 | R-AP49, R-IX6 |
| L0 | no range filter, a URL with no version is no candidate | R-AP63, R-C9 |
| L0 | header of a package (deps, entries), of a platform (target names), by hash with another URL form, not in the answer | R-AL8, R-AP17, R-AP49 |
| L0 | hint: first line, null, blank, no row | R-EF1, R-AP49, R-DI14 |
| L0 | `checked_of` by name in any case, none | R-AP64, R-AP29 |
| L2 | `registry/ap17-closure-index`: one POST with the body and headers, `log_size`, `unknown`, candidates with no GitHub call, `checked`, no file | R-AP17, R-AP18, R-AP42, R-AP49, R-AP50, R-AP63, R-AP64, R-DI14, R-IX3, R-AP23 |
| L2 | `registry/al8-closure-facts`: facts and records with no read, a hash not in the answer read from `packages/`, hints with no request, the walk reads no record of a non-winner and makes no call | R-AL8, R-AL9, R-AP17, R-AP49, R-AP63, R-DI14, R-EF1 |
| L2 | `registry/ap20-closure-errors`: exit 10 with no request, no answer 15, 400 is 1, 502 is 15, bad body 15, 429 non-problem 15, one request each, no file | R-AP20, R-AP34, R-AP74, R-E6, R-AP51, R-IX3 |
| L2 | `registry/ap18-closure-log-size` (Q390): run 1, a release with `log_index` = `log_size` is used; run 2, `log_index` = `log_size` + 1: nothing is used, exit 15 | R-AP18, R-E6, R-AP51 |
| L2 | `registry/ix6-offline-groups` (Q391): one name, 2 known forms, a group copy for one form only and no repository copy: the copied form gives its candidate, only the other form is missing (`missing-group`), the name is not missing, one `index: cached at` line | R-IX6, R-DI11, R-DI12 |
| L3 | `index/ix6-damaged-copy` (Q392): `flowprobe registry-index --offline` with a damaged group copy: one warning that names the `.json` file, both copy files removed (tree diff), the group missing, exit 0; the second run: no warning | R-IX6, R-TF6, R-DI11 |
| L2 | `registry/ix6-offline-registry`: group copy, repo copy for a form with no group copy (only that form), no copy (missing), new name (all rows), one `index: cached at` line with the oldest time, no request, no hint | R-IX6, R-AD37, R-DI12, R-IX5, R-IX2 |

The L2 lines `closure` and `offline` are new words of the entry `registry` (`tests/commands/L2Registry.roc`, doc table). The fixtures are made by `research/slice-206-revert/mkcases.py` (given and fx only).

Not tested at L2: `PickLoop.read_all!` and `PickLoop.hinted!` switch to `Gather.facts!` and `hints!` (they need a whole command with a registry, slice 206b or 224). The code agent changes them; the reviewer reads them.

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-8.roc` | 125 pass, 9 fail: each `ClosureindexTest` expect, `todo: slice 206` |
| `tests/commands/run.sh` | 264 pass, 4 fail: the 4 new cases, `[ROC CRASHED] todo: slice 206` |
| `scripts/test.sh check fmt l0` | check and fmt pass; l0 fails only in `l0-8` (the 9 above) |

The changed functions with old bodies (`PickIndex.index!`, `ResolveBase.read_releases!`, `Walk.run!`, `PickLoop.read_all!`) keep the direct behavior. The new type field `index` is set to `Direct` in each `Request` constructor (Install, Ls, ProbeFlow, Update, RocUse, Remove, Verify, `ResolvebaseTest`, `L2Resolve`), so the old tests pass.

## Expected exits (read, TW21)

Each case has `expect/exit` 0. The `exit` lines in stdout: only `ap20-closure-errors`: 10 (R-AP74 row 4), 15 (R-E6 no answer), 1 (R-AP74 row 1, 400), 15 (R-E6, 502), 15 (R-AP51, body), 15 (R-E6, not problem details). The other 3 cases have no failure line and no stderr except the `index: cached at` line of R-IX6.

## Revert check

`research/slice-206-revert/`: `before/` (the stubs), `reference/` (a private green reference of the 6 files: for the manager, not for the code agent, TW18), `mutate.py`, `results.txt`. Reference green (L0 and the 4 cases), then 10 mutations, each caught:

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `candidates` keeps a withdrawn release | L0, `ap17` |
| M2 | name compare with no lower case | L0, `ap17` |
| M3 | `published_at` kept in milliseconds | L0 |
| M4 | record found through the release URL, not the hash | L0 |
| M5 | `Gather.facts!` ignores the answer | `al8` |
| M6 | the walk ignores the index | `al8` |
| M7 | `query!` sends again after no answer | `ap20` |
| M8 | `hints!` with an answer asks GitHub | `al8` |
| M9 | offline repo copy gives the rows of every form | `ix6` |
| M10 | offline line names the newest copy | `ix6` |

## Output (proposed, R-OUT2)

| Case | Kind | Text |
| --- | --- | --- |
| An answer with a release above `log_size` (Q390) | network (15) | `the answer of the registry <origin> is not a closure answer: the release <url> has the log index <n>, above the log size <m>` |
| A kept copy that does not decode (Q392, the text of the design answer) | warning, no exit | `warning: the kept answer <path of the .json file> of the registry <origin> does not decode (<reason>); removed` |

The other texts are those of slices 201 (`no_answer`, `refuse`, `closure_answer`), 205b (`no_compiler`) and of `Github.offline_line`.

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | The platform edge of a record. R-PU38 row 13 (Design Q128): an app record has `platform_hash` only, not the URL of its platform entry, and a package or platform record keeps its platform entry as a `deps` item with no mark. `Release.pf` (R-C3) and `Closure.Entry.is_platform` need the URL and the mark. Which: (a) a new member in records (`is_platform` of a dep, or the platform URL of an app; TalonRegistry), (b) the client reads such a record as not complete and reads the archive (source 3 or 4), (c) the client marks the dep whose hash is `platform_hash` (works only for an app, and the app record has no such dep)? The stub gives `pf` = none and `is_platform` false for each dep; no test fixes this part | Answered (Design Q251, Registry R-AP81): option (a) with a mark. Each dep gets `is_platform` (records 104i, Worker 125). `release.pf` is the `url` of the marked dep of a package or platform record, none for an app, none with no mark. `entries[].is_platform` is the mark of the dep. Test changes after 104i: each `Artifact.Dep` fixture gets `is_platform`; new `expect`s for a package with a marked dep (pf set, entry marked), an app (pf none), a package with no mark (pf none). The stub's `Err(None)` and `Bool.False` become the rule. Moved to slice 206c (after records 104i is green): no `pf` test in slice 206 |
| Q2 | `timeout_s` of the closure query. The design gives none. The slice uses 20 s, the time of `RegistryCache.get!` (`no answer in 20 s`) and of `http_get!` (CLI R-CC12: a step that is not a wait ends in under 25 s) | Answered (Q392 row: the 20 s agrees with R-DA9, R-CC12) |
| Q3 | R-AP18 (reader): an answer with a release whose `log_index` is greater than `log_size` breaks R-AP18. Does the client refuse it (exit 15, as R-E6 last row) or use it? | Answered (Q390, R-AP18): refuse the whole answer, exit 15. Case `registry/ap18-closure-log-size` |
| Q4 | R-IX6 for a name with 2 known forms, one with a copy and one with none: `PickIndex.Candidates.missing` is for the name, so the slice marks the name missing (both groups act as anchors). A per-group flag needs a change of `ResolveBase.Candidates` | Answered (Q391, R-IX6): per group. Case `registry/ix6-offline-groups`, and `ix6-offline-registry` now also prints the group line |
| Q5 | A kept copy that does not decode with `--offline`: exit 15, or the same as no copy? | Answered (Q392, R-IX6, R-TF6): as no copy; delete it, print a warning. L3 case `index/ix6-damaged-copy` |

Answers (design agent, 2026-11-03):

| G-C | Design Q | Answer | Test change |
| --- | --- | --- | --- |
| G-C52 (Q3) | Q390 | Refuse the answer: exit 15, as R-E6 last row (Registry R-AP18) | New L2 case: a closure answer with `log_index` above `log_size` gives exit 15 |
| G-C53 (Q4) | Q391 | Per group, as R-IX6 says. The whole-name mark is not correct: `ResolveBase.Candidates` needs a flag for each group | New L2 case: 2 groups of one name, one copy |
| G-C54 (Q5) | Q392 | As no copy, with the R-TF6 warning, and the copy is deleted. Not exit 15. | New L3 case: `--offline` with a damaged copy |
| Q2 | Q392 | The 20 s timeout agrees with R-DA9 and R-CC12 | None |

### Cases added after the answers (2026-11-03)

The expected files of `ap18-closure-log-size`, `ix6-offline-groups` and `index/ix6-damaged-copy` are written by hand from the rules (`research/slice-206-revert/mkexpect.py` for the 2 L2 cases; `mkcases.py` writes their fx files), not from a run. The reason text `InvalidJson("Invalid JSON")` is what `records.Index.decode_releases` gives for the damaged body `{"releases":` (`research/slice-206-revert/reason.roc`). Expected exits: every case file `exit` is 0; the only failure line is run 2 of `ap18` (exit 15, R-AP18, Q390). `ix6-offline-registry` gained one line (`missing-group someone/roc-c ...`).
The L2 harness has no print of `missing-group` yet (the field does not exist; adding it now would break the build of the shared L2 app). So `ix6-offline-groups` and `ix6-offline-registry` stay red until the field exists and the test agent adds the one print line. The L3 case is red until `flowprobe registry-index` exists.

## Code

| File | Change |
| --- | --- |
| `cli/lib/ClosureIndex.roc` | `candidates`, `header`, `hint`, `checked_of`, `query!` (20 s, one send), `one_state` (R-AP18, Q390), `offline!` (per group `missing_forms`, Q391; a copy that does not decode: delete body then meta, warning, as no copy, Q392) |
| `cli/lib/Gather.roc` | `facts!`: `Record` from the answer, the other ids in one `get!`, none: no call |
| `cli/lib/ResolveBase.roc` | `Candidates.missing_forms : List(Str)` (Q391). `read_releases!` through `Gather.facts!` |
| `cli/lib/PickIndex.roc` | `index!` by `request.index` (`Direct` as before, `Answer`, `Offline`). `slots_of` holds a variable when `missing` or its form is in `missing_forms` |
| `cli/lib/Walk.roc` | `level!` through `Gather.facts!` (a record gives its entries) |
| `cli/lib/PickLoop.roc` | `hints!`. `read_all!` through `Gather.facts!` (a platform record gives its `target_names` as seen). `hinted!` calls `hints!` (the `Direct` calls are the same as before). No test: read them |
| `cli/flowprobe.roc` | `registry-index --offline --origin <url> [--known <url>]... <owner>/<repo>...` (L3 `index/ix6-damaged-copy`) |

Copies and hashes: `research/slice-206-revert/code-final/`, `code-final.sha256`.

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206-revert/code-final.sha256` | 7 of 7 OK |
| `todo: slice 206` in `cli/` | None |
| `scripts/test.sh check fmt l0 l2 l3` | All pass. l0 8.6 s (budget 10), l2 13.7 s, l3 11.2 s. |
| Slice cases | L0 `ClosureindexTest` 9 of 9. L2 `ap17`, `al8`, `ap20`, `ap18`, `ix6-offline-registry`, `ix6-offline-groups` green. L3 `index/ix6-damaged-copy` green. |
| Expected exits | `ap20-closure-errors`: 1 (400, R-AP74 row 1), 10 (no compiler, R-AP74 row 4), 15 four times (no answer, 502, bad body, 429 with no problem body: R-E6, R-AP51). `ap18-closure-log-size` run 2: 15 (Q390). The others exit 0. |
| Code read by the manager (no test) | `PickLoop.read_all!` and `hinted!`: the `Direct` path makes the same calls as before; `Answer` reads hints and records from the answer with no request; `Offline` gives no hints. |
| Design answers | Q251 (moved to slice 206c), Q390, Q391, Q392; 20 s query timeout accepted. |
| Records 104i | Fixtures have `"is_platform":false` on each dep. `pf` stays none until slice 206c. |
| Doubt for later | Offline rows match a form by exact text. A group in another letter case does not match. |
| Moved out | The query step in the commands: slice 206b. The platform entry: slice 206c. |

