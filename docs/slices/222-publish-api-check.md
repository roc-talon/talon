# 222 Publish API check

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 222 of `PLAN-P2-CLI.md`. `tln publish` runs `roc bump --old <URL> --expect <version>` before it sends the request (Registry R-PU39, Design Q31). Slice 221 (`docs/slices/221-publish.md`) made the command. This slice adds the check between the facts and the token request.

## Rules

R-PU39, R-AP13 (the read of the group). Named also: R-PUB4 item 1 (the order of the checks), R-OUT2 (the texts), R-RG3 (a registry read has no token), R-AP24 (the read cache).
Design: Registry 7 (R-PU39), 4 (R-AP13); Design 2 (`roc bump`, the group, the series); Design Q31; CLI R-PUB3 (the same "warn and send" rule for no facts).

## Reuse (no second copy)

| Need | Reused | New |
| --- | --- | --- |
| Read of the group | `Registry.releases_url` (no `series`), `RegistryCache.get!` (no token), `records.Index.decode_releases` | none |
| The group and the version of the new release | `Ident.of_url(asset URL)`: `group.form`, `version` | none |
| Order of versions | `semver.Semver` | `PublishCheck.previous` |
| The flow | `PublishFlow.flow!` (steps 4 and 5 give the facts) | one new step (6) |

## Public signatures (stubs, `crash "todo: slice 222"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `PublishCheck.previous` | `{ version : Str, rows : List(Release.Row) } -> Try(Release.Row, [NoPrevious])` | R-PU39, R-AP13 |
| `PublishCheck.bump_args` | `{ old : Str, version : Str } -> List(Str)` | R-PU39 |
| `PublishCheck.first_note` | `{ form : Str, version : Str } -> Str` | R-PU39 |

Edits to existing files (copies in `research/slice-222-revert/before/`): `cli/lib/main.roc` (1 expose: `PublishCheck`), `tests/unit/l0-6.roc` (1 import), `tests/tools/mk-publish.sh` (the 15 cases of slice 221 change, and `pu16`). New: `cli/lib/PublishCheck.roc` (stub), `tests/unit/PublishCheckTest.roc`, `tests/commands/cases/publish/pu16-no-previous`. `PublishFlow.roc` is not edited (the code agent does it). No file of the 206e3b agent was edited.

## The flow (my reading, for the review)

Place in the order of R-PUB4 item 1: after the facts of `compat.db` (R-PUB3) and before the token request. Reason for the place: the OIDC token lives a few minutes (slice 221, the same reason as "the facts come before the token"), and a `roc bump` run can be long. So a run that stops on a fact (`pu5`: exit 19) makes no group read. This is a reading: Q6.

| Step | Does | Rule |
| --- | --- | --- |
| 6a | `RegistryCache.get!` of `Registry.releases_url({ origin, group: <form of the asset URL>, series: Err(None) })` with `newest` (no copy is read, one `http_get!` with `Cache-Control: no-cache`, no `Authorization`). A good answer is decoded with `Index.decode_releases`. | R-PU39, R-AP13, R-RG3 |
| 6b | `PublishCheck.previous({ version, rows })`. `Err(NoPrevious)`: stderr `note: ` and `PublishCheck.first_note`; no compiler is started. | R-PU39 |
| 6c | A previous release: `roc bump --old <its url> --expect <version>` with the compiler of the `roc:` pin. Not in this part (Q1 to Q4). | R-PU39 |
| 7 | The token request and the publish (slice 221 steps 6 and 7). The exit code does not change. | R-PU39 |

Readings, each in a test:

| Reading | Where |
| --- | --- |
| The group is the URL form (`Ident.group.form`, the field `group` of a row) and the read has no `series`: the answer has all series. So 1.9.0 is the previous release of 2.0.0 (the bump check is for a major change too). | L0 `previous` (rows of 2.x and 1.x for 2.1.0, 10.0.0 for 3.0.0) |
| "Newest with a smaller version" is by version (Semver), not by `published_at` or `log_index`. 1.10.0 is larger than 1.9.0. | L0 `previous` |
| The same version (another hash: a publish again) is not smaller. | L0, L2 `pu16` |
| `<URL>` is the `url` of the row, as it is. `<version>` is the version of the new asset URL (`Ident`), the same as the tag in the normal case. | L0 `previous` (the row), `bump_args` |
| The arguments are exactly `bump --old <URL> --expect <version>`: R-PU39 names no more (no path of the new package: Q2). | L0 `bump_args` |
| The read of the group uses `newest` (the check must see a release that another job published a moment ago). The L2 `calls.log` has one `http_get` and no `list_dirs`, no `write_atomic` (the answer is `no-store`). | L2 (all cases that reach step 6a): Q5 |
| The note of a first release is on stderr, one line, before the token request. A good run prints nothing more (no line for a check that passes: proposal, Q3). | L2 |

## Tests

| Layer | Where | Rules |
| --- | --- | --- |
| L0 | `tests/unit/PublishCheckTest.roc` (driver `l0-6`) expect 1: `previous` (order of rows, the number order, other series, the newest below the version) | R-PU39, R-AP13 |
| L0 | expect 2: a yanked release is skipped; all below yanked gives `NoPrevious` | R-PU39, R-AP13 |
| L0 | expect 3: the same version, larger versions, an empty answer give `NoPrevious` | R-PU39, R-AP13 |
| L0 | expect 4: the result is the whole row (its `url`) | R-PU39 |
| L0 | expect 5: `bump_args` | R-PU39 |
| L0 | expect 6: `first_note` | R-PU39 |
| L2 | `publish/pu16-no-previous`: the answer of the group has 3.0.0, 2.1.0 (another hash) and 2.0.0 yanked: the note, no compiler call, the publish goes on, exit 0 | R-PU39, R-AP13 |
| L2 | `pu1`, `pu2`, `pu6` to `pu15`: changed. The `calls.log` has the group read after `db_query` and before the token request, and each run has the note (the answer of the group in these cases is empty: the first-release path). `pu11` (the token request refused) shows that the read comes first. `pu3`, `pu4`, `pu5` are unchanged: they stop before the read. | R-PU39, R-PUB4 |

No L2 case runs `roc bump`: the fake `Fx` form of the call and the answer of roc are open (Q1 to Q4). The mapping of a roc result to the warning or to the note of a failed bump is not tested for the same reason.

Expected exits (read): `pu16` 0 (R-PU39 "the exit code does not change"); all the other exits are the same as in slice 221 (`pu1` 0 x3; `pu2` 0; `pu3` 2, 2, 15, 15, 2 x7; `pu4` 2; `pu5` 19; `pu6` 0; `pu7` 15; `pu8` 0; `pu9` 20, 20; `pu10` 0, 0; `pu11` 2; `pu12` 20; `pu13` 0; `pu14` 0; `pu15` 0). The exit of a run does not depend on the check.

## Output (proposed, R-OUT2, TW24)

| Text | Form |
| --- | --- |
| First release | stderr `note: no earlier release of <form> before <version>: roc bump did not run` (`<form>` is the URL form, for example `github.com/acme/json/releases/download/{v}/`: a repository can have more than one group) |
| A check that passes | no line |
| Warning (the label bumps less than the API change needs) | not proposed: it names "the bump that roc wants", and the form of the answer of roc is not in the design (Q3) |
| Note of a failed `roc bump` | not proposed (Q3) |
| Failed read of the group | not proposed (Q5) |
| `--json` | no new member: the notes go to stderr and `data.publish` has the members of slice 221 |

## Out of scope

| Item | Why |
| --- | --- |
| A flag or a key to switch the check off | Not in the design |
| The registry running `roc bump` | R-RL3, R-PU39: the registry runs no compiler |
| A stop on a mismatch | R-PU39: the check never stops |
| `--offline` | `publish` with `--offline` is exit 15 before any request (R-PUB4 item 1) |
| Part 2 of the flow (6c) | Questions Q1 to Q4 |

## Questions (stop until answered)

Manager (2026-11-03): Q1 to Q7 went to TalonRegistry as G-C156 to G-C162 (in this order). The code step waits for the answers.

| # | Question | Why it is open | Reading, and what is not tested | Answer and test change |
| --- | --- | --- | --- | --- |
| Q1 | Where does Talon get the compiler of "the `roc:` pin of the release header"? Slice 221 reads the release JSON and the asset URL only. The header of the new asset is in the archive, which `publish` does not download. | R-PU39, R-DI7 | Not tested. Choices: download and read the archive of the new asset into `packages/<hash>/` before the check (cost: one download in each job); or read the pin from another place. Also open: no `roc:` pin in the header (which compiler runs?), a pin that is not installed (does `publish` download a compiler: R-DA, R-CC4, a lock?), and `roc` on `PATH`. | Answered (Q523, R-PUB4 item 13): no archive download. The new package is the project file of the job; the pin is read from its header; the compiler of the pin when installed, else the selected one; a pin not installed is an optional download (`--probe-downloads` or `--yes`) or a note. Test change: L2 `pu17-no-compiler` (the pin is not installed, no flag: the note, no probe, exit 0) and `pu18-pin-installed` (the call uses that compiler) |
| Q2 | How is `roc bump` started? The `Fx` call (`probes!`, `exec_in!`, `spawn_all!`), the working directory, the timeout, and how the new package is named. R-PU39 gives `--old <URL> --expect <version>` and no path of the new package. | R-PU39, TESTING 2.3 | Not tested. `bump_args` pins the 5 words of R-PU39 and nothing else. | Answered (Q524): one `Fx.probes!` spec, args `bump --old <URL> --expect <version> <file>`, `dir` the directory of the project file, `timeout` `probe.timeout`. Test change: `PublishCheck.bump_args` takes `{ old, version, file }` and gives 6 words (expect 5 changes; the stub changes). `--file` names the new package (Q508 changed) |
| Q3 | How does Talon read the result? The exit codes and the text of `roc bump` are not in the design: how to tell "the label bumps less than the API change needs" from "fails for another reason", and where the bump that roc wants is. What is a pass (exit 0, no line)? | R-PU39 | Not tested. The warning and the note of a failed bump have no test and no text. A `roc bump` that cannot start (`NotStarted`) is "fails for another reason": a note (a reading, untested). | Answered (Q525): exit 0 pass; exit 1 with `insufficient version bump` + `must be at least` + the stdout lines gives the warning; all else a note. New pure function (name for the test agent: `PublishCheck.verdict : { ended, stdout, stderr } -> [Pass, Less({ level, next }), Other(Str), TimedOut, Signaled, NotStarted(Str)]`). Test change: new L0 expects with the real texts of `research/roc-bump/results.txt` and `results-worker-nightly.txt` (the wrapped sentence), and L2 cases `pu19-bump-less` (warning), `pu20-bump-pass` (no line), `pu21-bump-failed` (compile error: note), `pu22-bump-unreadable` (headline of the case without the stdout lines: note) |
| Q4 | The compiler run is slow. Is there a time limit for the check, and what is the result when it is reached (a note, as a failed bump)? | R-PU39, R-DA9 | Not tested. | Answered (Q526): `probe.timeout`, 30 s default; at the limit a note and the publish goes on. Test change: L2 `pu23-bump-timeout` (the fake `probes!` gives `TimedOut`: the note, exit 0) |
| Q5 | The read of the group: with `newest` or with the cache (R-AP24)? And a read that fails (no answer, 429, 5xx, a body that does not decode): a note, a warning, or exit 15? R-PU39 covers a first release and a failed `roc bump`, not a failed index read. | R-AP13, R-AP24, R-PU39 | Reading: `newest` (all L2 `calls.log` files pin this form). A failed read is untested. | Answered (Q527): `newest`; a failed read gives the note and no `roc bump`; no retry; exit unchanged. Test change: L2 `pu24-group-read-fails` (a 503 and a body that does not decode, 2 runs: the note, the publish goes on, exit 0) |
| Q6 | The place of the check in R-PUB4 item 1: after the facts and before the token request. | R-PUB4 item 1 | Reading, pinned by the `calls.log` of all cases and by `pu5` (no read). Needs one line in R-PUB4 item 1. | Answered (Q528): the place is as read. Test change: none (R-PUB4 item 1 now has it; the `calls.log` of the cases already pins it) |
| Q7 | Pre-release versions (`2.1.0-rc.1`) and a row with `withdrawn` set: do they count as a previous release? R-PU39 says "smaller version, not yanked" only. | R-PU39 | Untested. `previous` is tested with plain `X.Y.Z` rows and `yanked` only. | Answered (Q529): no for both. Test change: L0 `previous` expect: a withdrawn row is skipped; a row below it is the result. Add `withdrawn` to the row builder of the test |

## Disputes (from the code agent)

None.

## Red state (test agent, 2026-11-03)

| Check | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass |
| L0 | 6 new expects fail with `todo: slice 222` (the stubs). No other failure. |
| L2 | 13 cases fail on the `calls.log` and the stderr (the group read and the note are not there yet): `pu1`, `pu2`, `pu6` to `pu16`. `pu3`, `pu4`, `pu5` and all other cases pass. |
| L3 | pass |
| Hand-written expected files | not run against code. No reference implementation was built. |

## Design answers (2026-11-03): facts of `roc bump`, and the TW24 check

Facts: `research/roc-bump/README.md`, `run.sh`, `results.txt` (nightly 2026-10-14), `results-worker-nightly.txt` (2026-10-31). Q530 accepts the proposals of this slice (the first-release note, a passing check with no line, no new `--json` member, the group as the URL form with no series) and adds the texts of R-PUB4 item 13.

| Fact | Effect on the tests |
| --- | --- |
| `roc bump` exits only 0 or 1 | The fake `probes!` of an L2 case gives `Exited(1)` and the real text of the run. The text decides |
| The wanted bump is in the stdout (`This is a MINOR change.`, `1.0.0 -> 1.1.0`); the stderr sentence wraps in the nightly of 2026-10-31 | One L0 expect uses the wrapped stderr |
| The new package is `ROC_FILE` (default `main.roc` of the directory) | The call has the 6th word; `bump_args` has `file` |
| Pre-release versions are refused by `roc bump` | No test of a pre-release previous release |

Part 2 (the run of `roc bump`) can start after the test step adds the cases above.

## Round 2 (test agent, answers Q523 to Q530)

| Item | Result |
| --- | --- |
| Stubs (`PublishCheck`) | `bump_args` takes `{ old, version, file }` (6 words). New: `Ended`, `Verdict`, `verdict`, `report`, `unavailable`, `read_failed` (all `crash "todo: slice 222"`) |
| L0 (12 expects in `PublishCheckTest`, all red on the todo) | `previous` (+ withdrawn and pre-release rows are skipped, Q529); `bump_args`; `verdict` with the real texts of `research/roc-bump` (pass, MINOR, MAJOR, the wrapped sentence of the 2026-10-31 nightly, `does not move forward`, compile error, headline with no stdout lines, `download failed`, `TimedOut`, `Signaled`, `NotStarted`); `report` (warning, no line, 3 notes); `unavailable`; `read_failed`; `first_note` |
| L2 `pu24-group-read-fails` | Written: run 1 gets 503, run 2 a body that does not decode; the note (cause `HTTP 503`, `the answer does not decode`: my proposal), no compiler, exit 0 |
| L2 `pu17` to `pu23` | NOT written. They need the compiler choice and the project file read in `calls.log`: about 20 lines (`canonical`, `list_dirs`, `read_files` of the project, `projects.json` lock, `path_roc`, `list_dirs` of the toolchains, `canonical`, `write_atomic .last-use`, the `probes` line) in the order of code that does not exist yet. The probe cases (`probe/pn1-nocompiler`) show the size. A hand-written list would be a guess and would make false disputes. Decision for the manager: (a) the code agent writes `pu17` to `pu23` with the test agent after a first green flow, from a reviewed run; or (b) a test agent builds a reference first. The cases and their facts: pu17 pin not installed, no flag: note `no API check: the compiler <pin> is not installed (pass --probe-downloads to install it)`; pu18 pin installed: the probe uses that compiler; pu19 `Less`: warning; pu20 pass: no line; pu21 compile error: note; pu22 headline without stdout lines: note; pu23 `TimedOut`: note |
| Existing cases | Unchanged by round 2. A group answer with no previous release gives the first-release note before the project file is read, so `pu1` to `pu16` do not reach the compiler step |
| New open point Q8 | The text of a `Signaled` result is not in R-PUB4 item 13 (`verdict` returns `Signaled`, `report` has no test for it) |
| New reading | `Other(headline)` is the LAST headline `── ✗ <name> ──` of the stderr (a compile error prints the error headline first, then `package does not compile`). A stderr with no headline: not decided, not tested |

Red state: `scripts/test.sh check fmt` pass. L0: the 12 expects of `PublishCheckTest` fail on `todo: slice 222`, nothing else. L2: 14 publish cases fail (`pu1`, `pu2`, `pu6` to `pu16`, `pu24`: the group read and the note are missing); 10 other cases fail (`registry/ap30-*`, `share/sh49` to `sh51-*`) and belong to the slice 206e4 agent. L3 pass. Exits read: `pu24` 0, 0; the others as above.

## Design answers for Round 2 (2026-11-03)

| Item | Answer | Test change |
| --- | --- | --- |
| Q8 (G-C163), `Signaled` | Q531: own note `note: roc bump ended with signal <n>: no API check. The publish goes on.`. `TimedOut` stays a kind of its own (the timeout note) | `report` gets an expect: `Signaled(9)` gives that text (exact), and `TimedOut` still gives the timeout text, so the 2 differ |
| G-C164, no headline | Q532: exit 1 with no `── ✗ <name> ──` line gives `note: roc bump did not compare <old> and <version>. The publish goes on.` (no cause words). `verdict` returns `Other("")` for it | `verdict` expect: the stderr `Error: no value was supplied for --old` (run 17 of `research/roc-bump/results.txt`) gives `Other("")`; `report` expect: `Other("")` gives the text with no cause |
| G-C164, exit code not 0 or 1 | Q532: cause `exit code <n>`; stderr is not read. `verdict` returns `Other("exit code 2")` | `verdict` expect: `Exited(2)` with a stderr that has a headline gives `Other("exit code 2")` (the headline is not used); `report` expect: the text `... did not compare <old> and <version>: exit code 2. The publish goes on.` |
| G-C164, the last headline | As read in Round 2 (the compile error runs 7, 8, 12 end with `package does not compile`; the run with `package download failed` too). No change | the existing `verdict` expect for a compile error stays |

## Round 3 (test agent): the reference, pu17 to pu23, Q531, Q532

Q531 and Q532 are in L0: `Signaled(n)` has its note (`roc bump ended with signal <n>: no API check. The publish goes on.`), exit 1 with no headline is `Other("")` and the note has no cause words, an exit code other than 0 and 1 is `Other("exit code <n>")` with the stderr not read. `verdict` returns `Signaled(I32)` now. 14 L0 expects in all.

The L2 cases `pu17` to `pu23` (made by `tests/tools/mk-publish.sh`; their `expect/` files are NOT written by the generator: they came from a private reference, `research/slice-222-revert/ref/`, a copy of `cli/` with a real `PublishCheck` and a check step in `PublishFlow`, built as its own L2 binary. All 24 publish cases passed on it, each line of each `calls.log` was read, and the reference is deleted). Mutations that the cases found: the warning given with no stdout lines (`pu22` fails), a timeout that gives no line (`pu23` fails), a pin that is not installed that is not checked first (`pu17` and the cases that list the toolchains fail).

| Case | Run | Result |
| --- | --- | --- |
| `pu17-no-compiler` | previous release 2.0.0, package header pins N1, nothing installed, no flag | `note: no API check: the compiler N1 is not installed (pass --probe-downloads to install it)`, no download, no GitHub request, no probe |
| `pu18-pin-installed` | N1 and a newer compiler installed | the probe is the roc of N1: `bump --old <url of 2.0.0> --expect 2.1.0 <file>`, dir `$PROJECT/p`, `timeout=30`; exit 0: no line |
| `pu19-bump-less` | exit 1, MAJOR change, 2.0.0 -> 3.0.0 | `warning: 2.1.0 bumps less than the API change of 2.0.0 needs: roc bump wants at least 3.0.0 (a MAJOR change). The publish goes on.`, the publish is sent, exit 0 |
| `pu20-bump-pass` | no pin; N1 and a newer one installed | the newest installed runs (the rank 6 note of `ResolveSelect` is on stderr, as for `tln probe`), exit 0: no line |
| `pu21-bump-failed` | exit 1, `package does not compile` | `note: roc bump did not compare 2.0.0 and 2.1.0: package does not compile. The publish goes on.` |
| `pu22-bump-unreadable` | exit 1, the headline and `must be at least`, no stdout lines | the note with the cause `insufficient version bump`, not the warning |
| `pu23-bump-timeout` | `timeout` | `note: roc bump did not end in 30 s: no API check. The publish goes on.` |

All 7 end with the publish (exit 0). Exits read: 0 for each.

What the `calls.log` pins (the code agent must reuse the same helpers, in this order; this is what the reference did):
- After the group read: `Install.begin!` (the calls `env_all`, `clock`, `cwd`, the project search, `canonical`, `list_dirs`, `read_files`), then `Install.compiler!` (`path_roc`), then `ResolveLoad.prepared!` (the one `read_files` of header, `talon.toml`, `config.toml`), then `ResolveBase.check_pin`, `HeldRoc.held!`.
- No `Known.record!`: a publish does not write `projects.json` (my reading, not in the design).
- A pin that is not installed with no `--probe-downloads` and no `--yes`: one `list_dirs` of the toolchains, then the note. No `Start.run!`, so no request for the compiler list.
- Else `Start.run!` (a `list_dirs`, `Launch.program!`, `canonical`), then `UnitFlow.probes!` with one spec (it writes `.last-use` first: R-CC9, it is in `tree.diff`), then the report.
- The probe `dir` is the dir of the project file, the argument `<file>` is its absolute path.
- The group read is made with `now: 0`: `newest` does not read the clock (no `clock` call before `Install.begin!`).
- A project file that is not found gives the note `no API check: no project file`, a file that is not a package `the project file is not a package`, no compiler `no compiler`: untested (no case), the texts are in `PublishCheck.unavailable`.
- `--probe-downloads` and `--yes` for a not installed pin: no case (the flag must be allowed for `publish` in `Opts`): open for the code step.

## Code (code agent)

| File | Change |
| --- | --- |
| `cli/lib/PublishCheck.roc` | The 7 stubs are code: `previous` (Semver order, skips yanked, withdrawn, pre-release, same or larger version), `bump_args`, `verdict` (exit 0, exit 1 read by parts, other exit codes, no stderr read), `report`, `unavailable`, `read_failed`, `first_note`. Private helpers: `is_pre`, `read_one`, `last_headline`, `stdout_level`, `stdout_next` |
| `cli/lib/PublishFlow.roc` | Step 5b `check!` between the facts and the token: `group!` (`RegistryCache.get!`, `newest`, `now: 0`), `PublishCheck.previous`, `bump!` (`Install.begin!`, `Install.compiler!`, `ResolveLoad.prepared!`, `ResolveBase.check_pin`, `HeldRoc.held!`, `Start.run!`, `UnitFlow.probes!`), the report on stderr. `ProbeFlow.request_of` is now public (a record of the flags and `none`); `PublishFlow` and `ProbeFlow` both call it. `ladder_downloads` wraps `ResolveBase.ladder_downloads` and sets `auto: No` with no flag |
| `cli/lib/ProbeFlow.roc` | `request_of` moved into the type block (public), with a `flags` record `{ allow, probe, slots, none }`; `flow!` calls it |
| `cli/lib/Args.roc` | `--probe-downloads` is allowed for `publish` (1 word) |

Review notes:

| Note | Text |
| --- | --- |
| Pin not installed | Only a pin (header or `ROC_TOOLCHAIN`) gets the own `list_dirs` check (`pu17`: note, no `Start.run!`). `pu20` (rank 6) has no own listing: its `calls.log` has the 2 `list_dirs` of `ResolveSelect` and `Start.run!` |
| Q542 (one note shape) | Without a flag `Start.run!` runs only for an installed compiler. The own `list_dirs` check runs for every source except `PATH` and rank 6 (no `default-roc`: `ResolveSelect` listed already, `pu20`). No held compiler and no flag: `no compiler`, or for a range the words of Q542 (`held_from` is `Range`; not tested). No `HeldRoc.held!` download without a flag. Failures before the run: first line of the message |
| `--probe-downloads` or `--yes` | `Start.run!` with `downloads.allow` set (an answer), so the download goes with no prompt. No case yet (the test agent adds one) |
| Failures of `prepared!`, `check_pin`, `Start.run!`, `ROC_TOOLCHAIN` | A note `no API check: <fail message>`. The reasons `no project file`, `the project file is not a package`, `no compiler` are as in `PublishCheck.unavailable`. No case |
| Help text | Not changed (no flag table of `publish` was edited) |

## Design answer for G-C172 (2026-11-03)

| Item | Answer | Test change |
| --- | --- | --- |
| A compiler that is not installed, any source (Q542) | `note: no API check: the compiler <id> is not installed (pass --probe-downloads to install it)`; for a range with none installed `no installed compiler is in the range <range> (pass --probe-downloads to install it)`. No call of the required-download consent, so no text with `TALON_AUTO_INSTALL=no` | The cases of `pu17` and the L0 `unavailable` expect take these texts: one expect for a pin, one for `.roc-version` or `default-roc` (same words), one for a range. A case with the flag `--probe-downloads` starts the download and runs the check |
| A failed step before the run (the project read, a bad pin, a bad `ROC_TOOLCHAIN`, a failed download) | `note: no API check: <first line of the failure message>`; exit code of that failure not used; the publish goes on, exit 0 | New L2 `pu25-bad-pin` (a `roc:` pin that `check_pin` refuses: the note with the message, exit 0) and `pu26-bad-toolchain-env` (`ROC_TOOLCHAIN=x`: the note, exit 0) |

## Design answer for G-C174 (2026-11-03)

| Item | Answer | Test change |
| --- | --- | --- |
| `pu25-pin-download`: the write of `default-roc` (Q544) | Right: R-SO15 and R-SO24 (the first compiler of a machine becomes the default; `config.toml` is no project file, R-LF4). The `downloading <id> (<size>)` line stays | None. The case stays as written. Add one run to it: `default-roc` already set in `config.toml`, the download runs, the file is not changed (R-SO24 never changes a set default) |
| `pu27-range-none` (Q544) | Right: the note with the raw range text, no request | None. Add a case with the flag: `publish --probe-downloads` and a range with no installed compiler: one read of the compiler list, then the download of the newest in the range, then the check |

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-222-revert/code-final.sha256` | OK, 6 files |
| `grep "todo: slice 222" cli/` | nothing |
| L2 `publish/pu1` to `pu29` | 29 pass (manager run). Expected exits read: the R-PUB4 check never changes the exit code (all new cases 0, pu24 0, 0); the older stop cases keep their slice 221 codes |
| Notes and warning (read) | pu17, pu26 `the compiler <id> is not installed`; pu27 the range text; pu21 `package does not compile`; pu22 `insufficient version bump` as a note, not the warning (Q525); pu23 the 30 s note; pu19 the MAJOR warning. All agree with R-PUB4 item 13 |
| Reference | private reference under `research/slice-222-revert/ref/` (deleted) made pu17 to pu23; 3 mutations caught. pu25, pu28 made with UPDATE=1 on the code and read; pu26, pu27, pu29 by hand |
| Review changes | `request_of` shared with `ProbeFlow` (no copy); the refused range passes as `Fail.refused_range`, not cut out of a message |
| `Fail.roc` | has both new fields (`ran` of 206e4, `refused_range` of 222) |
| Full `scripts/test.sh check fmt l0 l2 l3` | done at the 206e4 close (that agent was still editing) |
| Design answers | Q523 to Q532, Q542, Q544 |
| Not tested | `--yes` in place of `--probe-downloads`; the notes `no project file`, `the project file is not a package`, `no compiler`; `Signaled` in L2 (L0 only) |

