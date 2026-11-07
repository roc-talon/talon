# 218b Probe smoke

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-03).

Plan row 218b of `PLAN-P2-CLI.md`. `tln probe --smoke <alias or release URL> [--target <t>]...` (Design Q579, Resolution R-PB10). It fetches the platform by its URL and checks the hash, builds the smoke app of R-SM2 on the selected compiler (`ROC_TOOLCHAIN` for the bot) for each `--target` (each target of the header with none), always builds, and writes the result in the table `smoke`. `--json`: `data.smoke` is a list of `{target, result}`. The bot (slice 223) uses it later for R-MX10 and the platform pairs of R-MX13.

## Rules

R-PB10, R-PB8, R-CM8, R-FL12 (CLI 1 flag row), R-FL6, R-PD16 (a URL uses no project). Named in the tests as used: R-SM1, R-SM2, R-SM4, R-SM7, R-FE1 to R-FE4, R-DI5, R-LD8, R-OUT4, R-J3, R-J4, R-J6, R-E7, R-SC1, R-SO2, R-SO21, R-RC2 to R-RC4, R-TF7, R-EC2, R-EC13.
Questions Q1 to Q8 of the first round are answered (Design Q586 to Q593, Resolution R-PB10 details 1 to 6); round 2 below. Design: Resolution 4 (R-PB8, R-PB10, R-SM1 to R-SM7), CLI 1 (R-CM8, R-FL12), CLI 7.1 and 7.3 (fetch, R-DI5); Design Q549, Q579. Slices read: 217, 217b, 218.

## Reuse (no second copy)

| Need | Reused | New |
| --- | --- | --- |
| The smoke app, the class of a result, the machine errors | `Smoke.app_text`, `Smoke.result`, `Smoke.machine_errors` (slice 218) | none |
| The table | `Db.SmokeRow`, `Db.Write` `Smoke` (slice 218), the `smoke.tsv` of the fake | none (no `Smoke` query: the command always builds) |
| The header targets | `BuildTarget.targets_of` | `ProbeSmoke.pick` (which targets, the exit 2 stops) |
| The compiler, the project, the fetch | the steps of `ProbeFlow.flow!` and `single!` (the prelude, `Start.run!`), `ProbeCmd.entry`, `Fetch.packages!`, `Ident.of_url`, `Fx.probes!` | `ProbeSmokeFlow.run!` |

## Public signatures (stubs, `crash "todo: slice 218b"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `ProbeSmoke.Operand` | `[Alias(Str), Url(Str)]` | R-PB10 |
| `ProbeSmoke.Plan` | `{ operand, wanted : List(Str), opts : Opts }`. The field is `wanted`: `targets` is a reserved word of Roc | R-PB10 |
| `ProbeSmoke.read` | `Args -> Try(Plan, Fail)`: the 9 checks of its doc, exit 2 | R-PB10, R-FL12, R-DI5 |
| `ProbeSmoke.pick` | `{ text, given, what } -> Try(List(Str), Fail)`: the targets to build, exit 2 for a bad target and for a text that is not a platform | R-PB10 |
| `ProbeSmoke.word` | `[Row(Db.Outcome), Machine, NoFact] -> Str`: `pass`, `fail`, `hang`, `crash`, `machine-error`, `no-fact` | R-PB10, R-SM7 |
| `ProbeSmoke.data`, `ProbeSmoke.text` | the `data` member `smoke` and the human text | R-PB10, R-OUT4 |
| `ProbeSmokeFlow.run!` | `Fx, Args => I32`. The steps are in its doc | R-PB10 |

Edits to existing files (copies of the state before in `research/slice-218b-revert/before/`): `cli/lib/Run.roc` (1 import, the branch `probe` with `--smoke` or `--target` before the branch `probe`), `cli/lib/main.roc` (2 exposes), `cli/lib/Args.roc` (the flag rows: `--smoke` and `--target` for `probe`, `--target` takes a value for `probe`; this is the wiring of R-FL12, so that the L2 cases reach the stub), `tests/unit/l0-2.roc` (1 import). New: `cli/lib/ProbeSmoke.roc`, `cli/lib/ProbeSmokeFlow.roc`, `tests/unit/ProbesmokeTest.roc`, `tests/tools/mk-probe-smoke.sh` (makes the `given/` and `fx/` files of the 6 L2 cases), `tests/commands/cases/probe/sm1` to `sm6`. No file of slice 217b (`ProbeShow`, `ProbeCmd`, `ProbeSearch`) and no file of slice 223 (`bot/`) was edited. `ProbeFlow.roc` is not edited: the code agent may make `single!`, `rows_of`, `node_of!` and `source_of` callable (they are private there) or move them.

## The flow as I read it

Steps and calls: the doc of `ProbeSmokeFlow`. The calls of `calls.log` came from a private reference that was deleted (see Expected files).

| # | Reading | Source |
| --- | --- | --- |
| R1 | The command is `probe` with `--smoke` or `--target`. `--smoke` takes no value: the operand follows it. `--target <t>` is repeated for more targets | R-CM8, R-FL12 |
| R2 | An alias operand: the prelude and the compiler are those of `tln probe` with no `--range` (`probe/pc1-targets`). A URL operand uses no project (Q591): `env_all`, `clock`, the read of `config.toml`, `path_roc`, the toolchain list, then `Compiler.select` (`ROC_TOOLCHAIN` first, then `default-roc`, then the `roc` on PATH). `ROC_TOOLCHAIN` selects the compiler as for `tln verify` (R-SO21) | R-PB10 "section 13", Q591 |
| R3 | The platform is fetched with `Fetch.packages!` (a dir of `packages/` is "fetched" with no download). The program of the unbundle is the held compiler. A wrong hash is exit 16 (R-FE2) | R-PB10 "fetches it and checks the hash" |
| R4 | An alias that names a package or an app is exit 2 before the fetch (the node knows `is_platform`). A URL is checked after the header read (`BuildTarget.targets_of`) | R-PB10 "an operand that is not a platform" |
| R5 | A URL that `Ident.of_url` refuses (R-DI5), and a URL with `--file`, are exit 2 in `read`: no call after the prelude of a failure | R-PB10, R-DI5, Q586, Q591 |
| R6 | One temp dir for each target (`random`, `make_dirs`, `write_atomic`), one `probes!` round, no `Smoke` query, one `Smoke` write, one `delete!` of the dirs. No queue call | R-SM1, R-SM4, R-PB10 |
| R7 | The key is (hash of the platform, id of the compiler, target of the build). The smoke app has the URL (alias: the URL of the header entry; URL: the operand), Q549 | R-SM2 |
| R8 | A result is a fact of the command, not a failure: fail, hang, crash and machine-error are exit 0 (R-PB8, Q590). The table has the rows `Smoke.result` gives (`Row`, any outcome); the first row of a key stays, `data.smoke` shows the new result (Q589). A `no-fact` item (R-P3) makes exit 1, `data` null, `error.details.smoke` the whole list; the rows of the other targets are written | R-PB8, R-SM4, Q589, Q590 |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ProbesmokeTest.roc` (driver `l0-2`) expect 1: `read` (URL, loopback URL, alias, a full name, targets in the order of the line, the operand before the flag, `--slots`; the 8 failures, one fault in each row) | R-PB10, R-CM8, R-FL12, R-FL11, R-DI5 |
| L0 | expect 2: `Args.parse`: `--smoke` and `--target` on `verify` (exit 2), `--target` with no value, `--smoke` on `probe` is accepted | R-FL12 |
| L0 | expect 3: `pick` (the header order, an unsorted header, 1 target, the order of the line, a bad name, the first bad name, an app, a package, a text that is no header) | R-PB10 |
| L0 | expect 4, 5, 6: `word` (6 words, with `no-smoke-app`), `data` (the order, the keys, `machine-error`), `text` | R-PB10, R-SM4, R-SM7, R-J6, R-OUT2 |
| L2 | `probe/sm1-url-targets`: a URL, no `--target`: 4 targets in the header order, one round of 4 builds, pass, fail, hang, crash, one write of 4 rows, exit 0. No project (Q591): no `cwd`, no `projects.json`. The keys of x64musl (same result) and arm64musl (another result) are in the table: both build again, the row of arm64musl stays, the output shows `fail` (Q589) | R-PB10, R-PB8, R-SM1, R-SM2, R-SM4, R-LD8, R-RC2 to R-RC4, R-PD16, Q589 |
| L2 | `sm2-json-order` (2 runs): `--target` order of the line, `--json` (`data.smoke`, the text on stderr), `ROC_TOOLCHAIN` an installed compiler (program and key); a run with 1 target and no `--json` | R-PB10, R-OUT4, R-SO21 |
| L2 | `sm3-fetch` (2 runs): a platform that is not in `packages/`: download, unbundle, header read, build, rows; a wrong hash: exit 16, no build, no row | R-PB10, R-FE1 to R-FE4 |
| L2 | `sm4-alias` (3 runs): `pf` (the platform entry), `json` (a package: exit 2, no fetch), `nope` (exit 2) | R-PB10, R-SC1 |
| L2 | `sm5-usage` (11 runs): no operand, `--range`, `--share`, a bundle file, 2 operands, `--target` with no `--smoke`, a bad target, the URL of a package, a URL with no version, a URL with `--file`, a platform with no `targets` section: all exit 2 | R-PB10, R-FL12, R-FL6, R-DI5, R-EC2, Q586, Q587, Q591 |
| L2 | `sm7-no-smoke-app` (2 runs): a platform with a 2-entry `requires` (no smoke app, R-SM2): no temp dir, no build, no row; `data.smoke` has each target as `no-smoke-app`; exit 0 | R-PB10, R-SM2, R-SM4, Q598 |
| L2 | `sm8-no-compiler` (2 runs): a URL operand with no compiler selected: run 1 non-interactive with no flag is exit 13, no download; run 2 with `TALON_AUTO_INSTALL=yes` downloads the latest compiler, sets `default-roc`, and the 4 builds run on it | R-PB10, R-SO14, R-SO23, R-DL1 to R-DL5, R-NI5, Q597 |
| L2 | `sm6-no-fact` (2 runs): `--json` with a SIGKILL build: exit 1, `data` null, `error.details.smoke` the whole list, the other row written; a machine error alone: exit 0, no row | R-PB8, R-P3, R-J4, R-SM7, Q590 |

Expected files: `sm1` to `sm6` `expect/` came from a private reference of the code (`ProbeSmoke` and the flow in a copy of `cli/` under `research/slice-218b-revert/ref/`, built as its own L2 binary; deleted at the end; built twice, again for round 2). Each expected file was read (TW21). The 6 L0 expects were run against the same reference and pass.

## Output (proposed, R-OUT2, TW24)

| Text | Form |
| --- | --- |
| Human text | `smoke build of <label> on <compiler>:` and `  <target>: <word>` for each target. `<label>` is `ProbeShow.label_of` of the node (`the platform acme/pfx 0.1.1`). With `--json` on stderr, as `tln probe` |
| `data` | `{"smoke":[{"target","result"}]}`: the keys in this order, the items in the order of the targets. No other member. No new `schema` (R-J6) |
| Usage texts | `tln probe --smoke needs a header alias or a release URL`; `... cannot run with --range`; `... cannot run with --share`; `... takes one platform: a header alias or a release URL`; `... needs a header alias or a release URL, not a bundle file: the smoke app names the URL of the platform`; `flag '--target' works only with --smoke`; `'<url>' is not a release URL: it needs one version X.Y.Z (R-DI5)`; `'<x>' is not a platform: tln probe --smoke builds the smoke app of a platform`; `'<t>' is not a target of '<x>': it has the targets <a>, <b>` |

## Expected exits (read, TW21)

| Case | Exits | Rule of the run |
| --- | --- | --- |
| `sm1` | 0 (a fail, a hang and a crash are in the output) | R-PB8, R-E7 |
| `sm2` | 0, 0 | R-PB8 |
| `sm3` | 0, 16 | R-FE2 (a wrong hash is `integrity`, exit 16) |
| `sm4` | 0, 2, 2 | R-PB10 (not a platform), R-SC1 (not in the project) |
| `sm5` | 2 x 11 | R-PB10, R-FL12, R-FL6, R-DI5, Q586, Q587, Q591 |
| `sm7` | 0, 0 | R-PB8, Q598 (a platform with no smoke app is a printed result, not exit 2) |
| `sm8` | 13, 0 | R-DL5, R-EC13 (a refused or impossible download); then the build runs, R-PB8 |
| `sm6` | 1, 0 | R-PB8 and Q590 (a build with no fact is exit 1; a machine error alone is 0) |

No stderr in a run that exits 0 except the text of `sm2` run 1 and `sm6` run 1 (`--json`: the human text goes to stderr, R-OUT4; `sm6` run 1 also has the error line).

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| `scripts/test.sh selftest` | pass |
| `ProbesmokeTest` (driver `l0-2`) | 5 of 6 expects fail with `todo: slice 218b`. The `Args.parse` expect passes: the flag rows of `Args.roc` are the wiring (a guard) |
| `tests/commands/run.sh probe/sm` | 6 of 6 fail with `[ROC CRASHED] todo: slice 218b` |
| `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh l0 l2` | the new tests fail as above. The other failures are slice 223 (`bot/` L2 cases, `BotTest`, `l0-9`) and 217b (`ProbecmdTest`, `pc4`, `pd1`) |
| `JOBS=1 scripts/test.sh l3` | pass |
| `MISSING=1 scripts/rules.sh R-PB R-SM` | no id with no test |

## Out of scope

| Item | Why |
| --- | --- |
| The bot calls of R-MX10 and R-MX13 | Slice 223 and after |
| `--offline` with a URL that is not in `packages/` | The code of `Fetch.packages!` (R-FE1) is tested by `fetch/` and `probe/lp2-fetch` |
| `--share`, `--range` with `--smoke` | Exit 2 (tested) |
| The queue (R-SH3) and `tln probe --share` of a smoke row | Q579 names the table `smoke` only (question Q7) |
| The text of the smoke app as the flow writes it | `Smoke.app_text` has its L0 expects (slice 218). `tree_diff` leaves out `tmp/`, so no L2 case shows the file (slice 218, dispute sh78). Doubt D4 |

## Questions

Q1 to Q8 of round 1 are answered (Design Q586 to Q593, Resolution R-PB10 details 1 to 6). No open question.

| # | Answer | Test change |
| --- | --- | --- |
| Q1 (Q586) | The order of the table: flags, `--target` with no `--smoke`, `--range`, `--share`, 2 operands, no operand, bundle file, bad URL; after the fetch: not a platform, no target to build, a target that is not of the platform | L0 `read` rows, `pick` rows (an app with a bad target is "not a platform"; `targets: {}` with a target is "no target to build"); `sm5` |
| Q2 (Q587) | `targets: {}` and no `targets` section are exit 2 `no target to build` (not "not a platform") | L0 `pick` (3 rows), `sm5` run 11 |
| Q3 (Q588) | A repeated `--target` is one build, at its first place | L0 `pick` row |
| Q4 (Q589) | The first row stays, `data.smoke` shows the new result | `sm1`: arm64musl has `pass` in the table, the build fails: the text shows `fail`, the file keeps `pass` |
| Q5 (Q590) | `machine-error` alone: exit 0. `no-fact`: exit 1, `data` null, `error.details.smoke` the whole list | L0 `word`, `data`; `sm6` |
| Q6 (Q591) | A URL operand uses no project; `--file` with it is exit 2; an alias uses the project | `sm1` has no project; `sm2`, `sm3`, `sm5` URL runs lose `--file`; `read` row and `sm5` run 10 |
| Q7 (Q592) | No share queue | The cases have sharing off, so none proves it (no cheap world: it needs a sharing run with a registry). The flow doc says it. Not tested |
| Q8 (Q593) | The key is written for each compiler id | Not tested (the world needs a non-nightly toolchain and its sidecar). The cases use nightlies |

## Doubts (a reading that the code agent may dispute)

| # | Doubt |
| --- | --- |
| D1 | The prelude and the compiler (R2): the calls up to `canonical <cache> <roc cache>` are those of `probe/pc1-targets` (project, `Known.record!`, `ResolveLoad.prepared!`, pin check, `HeldRoc.held!`, `Start.run!`). This is the alias path only. The URL path has no project (Q591); its calls (`env_all`, `clock`, `config.toml`, `path_roc`, the toolchain list) are a reading of "the compiler of section 13 with no project" and are fixed by `sm1`, `sm3`, `sm5`, `sm6`. |
| D2 | A package alias is exit 2 before the fetch (R4), a package URL after the header read. The two stops have different calls (`sm4` run 2, `sm5` run 8). A code that reads the header for an alias too is a dispute, not a design change. |
| D3 | The unbundle program of a fetch is the held compiler (`started.program`). `probe` of a bundle file uses `ProbeFlow.unbundle_program!` (`Fetch.unbundler`). In the world of `sm3` (no installed compiler, the `roc` on PATH) both give `/fake/bin/roc`. |
| D4 | The fake `random` gives one value, so the temp dirs of the targets have one name in `calls.log` (the real `Fx` gives one name each). The smoke app text of the flow is not seen by any L2 case: a code that passes the wrong URL to `Smoke.app_text` passes the L2 cases. |
| D5 | The platform fixture header is the form of `BuildtargetTest` (`provides [main_for_host!]`, a `targets` record). |
| D6 | The rows are written in one `db_write!` before the text is printed (R6, R8): a failed write is the warning or stop of `Db.on_err` (R-CC8), as for `Facts.save!`. Not in a case. |
| D7 | `Args.roc` is edited here (the flag rows). It is the wiring, not logic. If the manager wants no edit of a production file in the test step, move these 3 lines to the code step: the 6 L2 cases then fail with exit 2 (`flag '--smoke' is not for 'probe'`), and the L0 expect 2 fails. |

## Disputes (from the code agent)

None. D9 is not a dispute: `ProbeFlow.begin!` calls `Install.compiler!` (`path_roc`) for each run, as `tln probe` does, so a `path_roc` call with `ROC_TOOLCHAIN` set is the same call as in `probe/pc1-targets`.

## Questions (from the code agent, TW17)

| # | Question | Code now |
| --- | --- | --- |
| C1 (answered Q597: `NoRank.ensure!`, scope `Project([hash])`) | A URL operand with no compiler selected (`Compiler.select` gives no id: no `ROC_TOOLCHAIN`, no `default-roc`, nothing installed, no `roc` on PATH). The design says nothing for a run with no project (Q591). | Stop: `Compiler.failure(NoCompiler)` (exit 18), no download. Answered (Design Q597, R-PB10 detail 7): R-SO14 case (1) with the platform hash as the package, the consent rules, `default-roc` set. Tests: `sm8`. |
| C2 (answered Q598: `no-smoke-app` items, exit 0) | A platform whose `requires` clause gives no smoke app (`Smoke.app_text` gives `NoSmoke`, R-SM2). | Exit 2: `'<x>' has no smoke app ...`, before any temp dir. Answered (Design Q598, R-PB10 detail 8): exit 0, no build, no temp dir, no row, each target `no-smoke-app`. Tests: `sm7`, L0 `word` and `data`. |

## Verify results

| Step | Result |
| --- | --- |
| `scripts/test.sh check fmt selftest` | pass |
| `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh l0 l2` | l2 pass. l0: `ProbesmokeTest` (`l0-2`) pass; the only failures are slice 223 (`l0-9` `BotTest`, `l0-10` `BotReadTest`: type mismatch in `Bot.failure`) |
| `tests/commands/run.sh probe/sm1` to `sm6` | 6 of 6 pass |
| `JOBS=1 scripts/test.sh l3` | pass |

Code: `cli/lib/ProbeSmoke.roc`, `cli/lib/ProbeSmokeFlow.roc`, `cli/lib/ProbeFlow.roc` (new public `begin!`, `started!`, `node_of!`, `source_of`; `flow!` and `single!` call them, no copy). Copies before: `research/slice-218b-revert/code-before/`. Hashes: `research/slice-218b-revert/code-final.sha256`.

## Round 3 (answers Q597, Q598; code agent readings C1, C2)

| Change | Where |
| --- | --- |
| `NoSmokeApp` is a 4th result tag: `ProbeSmoke.word`, `data`, `text` and `ProbeSmokeFlow.Smoked` take `[Row(Db.Outcome), Machine, NoFact, NoSmokeApp]`; `word` has the arm `NoSmokeApp => crash "todo: slice 218b"` (the code agent writes `no-smoke-app`). These are the only edits to the files of the code agent; copies of the state before in `research/slice-218b-revert/before/` (`ProbeSmoke.roc`, `ProbeSmokeFlow.roc`) | `cli/lib/ProbeSmoke.roc`, `cli/lib/ProbeSmokeFlow.roc` |
| L0 `word` and `data`: the word `no-smoke-app` and an item with it | `tests/unit/ProbesmokeTest.roc` |
| L2 `sm7-no-smoke-app`, `sm8-no-compiler` (`tests/tools/mk-probe-smoke.sh`; `sm8` copies the channel list of `init/it4-nocompiler`) | `tests/commands/cases/probe/` |

The expected files of `sm7` and `sm8` came from a private reference (the 2 changes in a copy of `ProbeSmokeFlow.roc` under `research/slice-218b-revert/ref/`, deleted): Q597 is `NoRank.ensure!` with `scope: Project([<platform hash>])`, `exclude: []` and the downloads facts of the run, in place of the exit 18; Q598 is a return before the temp dirs with `NoSmokeApp` for each target. Each expected file was read.

Expected exits: `sm7` 0, 0 (Q598). `sm8` 13 (R-DL5: the download needs consent, and the run is not interactive and has no flag), then 0 (the consent of `TALON_AUTO_INSTALL=yes`, the builds pass, R-PB8).

Doubts: D10 the call order of `sm8` is that of `NoRank.ensure!` as `init/it4-nocompiler` fixes it (list read and kept, `pinned` write, `facts` query for the hash, the lock of the item, the download); a code that asks before the list read changes `calls.log`. D11 the pick is the latest compiler old enough for `min-release-age` (`nightly-2026-10-12-2a2a2a2`; the newest is young): with `Project([hash])` and no recorded pass for the hash, the rule "newest with a recorded pass, else the latest" gives the latest. No case has a recorded pass for the platform hash.

Red result (round 3): `sm7` fails on the exit code (2 instead of 0, `no smoke app` text), `sm8` run 1 on the exit code (18 instead of 13). L0 `word` and `data` fail on `todo: slice 218b`.


## Verify results (round 3)

| Step | Result |
| --- | --- |
| `tests/commands/run.sh probe/sm` | 8 of 8 pass (sm7, sm8 included) |
| `roc test tests/unit/l0-2.roc` | 93 pass |
| `scripts/test.sh check fmt` | pass |

Code: `ProbeSmokeFlow.roc` (URL with no selectable compiler: `NoRank.ensure!` with `Project([hash])`; `NoSmoke` returns `NoSmokeApp` for each target before any temp dir), `ProbeSmoke.word` (`no-smoke-app`). Hashes updated in `code-final.sha256`.

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-218b-revert/code-final.sha256` | 3 files OK (`ProbeFlow.roc`, `ProbeSmoke.roc`, `ProbeSmokeFlow.roc`) |
| `todo: slice 218b` | none |
| Expected exits read | sm1: 0. sm2: 0, 0. sm3: 0, 16. sm4: 0, 2, 2. sm5: 2 (11 runs). sm6: 1, 0. sm7: 0, 0. sm8: 13, 0. Each is the rule of its run |
| Questions | G-C215 to G-C222 (Q586 to Q593), G-C226, G-C227 (Q597, Q598): all answered |
| Wiring by the test agent | `Args.roc` (3 flag rows), `Run.roc`, `main.roc`: accepted as stub wiring |
| Mutations (private builds in a mirror, deleted) | 4 of 4 caught: no dedup of a repeated `--target` (ProbesmokeTest); `Machine` for a platform with no smoke app (sm7); no exit 1 for a no-fact item (sm6); a `db_write` with no rows (sm6) |
| `check`, `fmt`, `selftest` | pass |
| L0 | pass |
| L2 | 515 passed, 0 failed |
| L3 (`JOBS=1`) | pass (81.9 s, over the 60 s budget: warning) |
| Not tested | Q592 (no queue row) and Q593 (a non-nightly id), and the "newest with a recorded pass" half of Q597 |

## Human review (the user, 2026-11-06)

The user accepted all the proposed output texts and `--json` fields of this slice (TW24, R-OUT2). They are final.
