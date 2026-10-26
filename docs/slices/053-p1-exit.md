# 053 P1 exit

Phase: P1. Status: done

Slice 053 checks the exit criteria of P1 (Design 7): "Talon finds a working tuple for parser 2.0.0 + basic-cli without help. GC frees the legacy dirs." It also adds the TW16 case for the failure example of Resolution 5. It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-053-revert/before/` (with `NEW.txt`).

All 3 cases pass on the current code. So there is no code step (review of 2026-10-25 accepted this). The slice changes no Roc file. It changes the L3 runner a little (section 3).

## 1. Design 7: each P1 item and its test

| Design 7 item | Test or slice | State |
| --- | --- | --- |
| Exit: "a working tuple for parser 2.0.0 + basic-cli without help" | L4 `exit/ex1-parser-basic-cli` (tags `net real-roc`) | new, green with OPT=speed |
| Exit: "GC frees the legacy dirs" | L4 `exit/ex2-gc-real-cache` (tag `real-roc`) | new, green |
| TW16: the failure example of Resolution 5 | L3 `exit/ex3-no-tuple-yaml` (fast set) | new, green. Its text is not the text of the example: finding F2 |
| Scope: toolchain manager | Slices 020 to 027, 044, 045, 060, 061 (all done) | covered |
| Scope: `roc` proxy | Slices 022b, 023, 023b, 023c (done) | covered |
| Scope: `tln cache gc` | Slices 028, 028b, 029, 029b (done), 061 | covered. `ex2` adds the real cache |
| Scope: local probes, the PubGrub oracle | Slices 030 to 039c, 037, 037c (done). 037d closed (no design basis) | covered |
| Scope: `tln tool` (CLI 6.4) | Slices 046 to 051, 056 to 059. 046b dropped (user, 2026-10-25) | covered. The status line of `046-tool-install.md` says `code` and the plan row says done: finding F6 |
| Scope: `install.sh`, `install.ps1`, prebuilt binaries (CLI 6.5) | Slice 052 (done), 018b (CI jobs), `install/test.sh` | covered |
| TW16: P1 design examples other than Resolution 5 | `tln roc install --git` prompt (CLI 6.6 R-D4): L3 `compilers/gi1-git-install`. `tln tool rm talon` prompt (CLI 6.5): L0 `TalonRemoveTest`, L2 `tool/rm1-default`, L3 `tools/rm1-remove-talon` (`--dry-run` list) | covered. The prompt of `tool rm talon` has no L3 case with a pseudo terminal (F5, not built) |
| TW16: `tln upgrade` and `tln add parser@2.0.0` examples | The design says phase P2 (`log:` snapshot, short name) | later phase, not here |

## 2. Rules

R-AL1, R-AL5, R-AL7, R-SP6, R-SP8, R-SP12, R-UP6, R-UP7, R-UM1, R-DT1, R-DT2, R-DT4, R-FL9, R-NI12, R-DL4, R-DI1, R-DA1, R-LD1, R-RC1, R-PH10 (the tuple, `ex1` and `ex3`). R-GC1, R-GC2, R-GC3, R-GC4, R-GC9, R-GC11, R-LY1, R-CC10, R-EV22, R-J3, R-OUT4 (the GC cases). R-EP7, R-EP10, R-EP11, R-J5 (`ex3`). All rules have tests in earlier slices. The new cases check them again on real data.

## 3. What changes in the harness (no public Roc signature changes)

| File | Change |
| --- | --- |
| `tests/run.sh` | A case with the tag `net` runs with no network cut (`netoff`) and gets `GITHUB_TOKEN` and `GH_TOKEN` of the caller (R-RG3: 60 requests an hour with no token). A case with the tag `net` or `real-roc` gets `TALON_TEST_REAL_CACHE`: `REAL_CACHE`, else `~/.cache/roc` of the caller. 3 comment lines in the header. |
| `tests/run.sh` (review) | A case with the file `needs-real-cache` is skipped, with a `SKIP <case>: <reason>` line, when the dir of the real cache does not exist. `ex2` has the file. |
| `tests/selftest.sh` | New rows `net_env` (6 cases) and `net_cache` (skip and run). With the old `tests/run.sh` the row `net_env` fails. |
| `tests/scenarios/exit/` | New area. 3 cases. |
| `research/slice-053-revert/` | `mk-ex3.py` (makes the `given/` files of `ex3` from real data), `mutate.sh`, `mutate.py`, `f1-repro/repro.sh` (F1), `before/` |

The `tags` file of a case is one line with the tags split by a space (`net real-roc`). Two lines do not work: the runner matches ` real-roc ` in the text of the file.

## 4. Tests

| Layer | Case | Content | Rules |
| --- | --- | --- | --- |
| L4 | `exit/ex1-parser-basic-cli` (tags `net real-roc`, 4 parts, 14 s) | The real `tln` (OPT=speed), the real pinned `roc`, the real GitHub API, the real basic-cli and roc-parser releases, one real compiler download (75 MB). The app uses basic-cli 0.24.0 and roc-parser 2.0.0 (imports `parser.Utf8`), `talon.toml` has `parser = "=2.0.0"`, no `roc:` pin. Part 1: the real `roc check` fails (exit 1). Part 2: `tln upgrade --snapshot 2026-10-13T00:00:00Z` moves pf to basic-cli 0.25.0 (new series) and writes the pin of the `roc` on PATH. parser stays (anchor, held). 7 probes. Part 3: the real `roc check` of the new header passes. Part 4: the same command again says `nothing to change`. `TALON_NOW` is fixed. The roc cache is outside `home/` (no 100 MB in the tree diff) and the case deletes it | R-AL1, R-AL5, R-AL7, R-SP6, R-SP12, R-UP6, R-UP7, R-UM1, R-DT1, R-DT2, R-DT4, R-FL9, R-NI12, R-DL4 |
| L4 | `exit/ex2-gc-real-cache` (tag `real-roc`, 4 parts, 4 s) | The real `tln`, real file times. It copies the real roc cache (3.0 GB here: 5 `nightly-*` dirs, 1 `debug-*`, 66 `compat-*`, 59 packages) to the case dir, and runs only in the copy (`XDG_CACHE_HOME` and `ROC_CACHE_DIR` point to it). It sets the ages: the first dir of each kind has one young file (stays), the second is 3 days old (a build dir stays, a package goes: 7 days against 1 day), the last is young (stays), the others are 2000 (go). Part 1: `--dry-run --json` lists exactly these sets, each with a size, and `freed` is the sum of the file sizes. The tree is the same. Part 2: the real run removes exactly these dirs and the sidecars `<hash>.deps.json`, and nothing else. Part 3: the legacy dirs that stay. Part 4: a second run says `nothing to remove`. The output has no name, size or count of the machine | R-GC1, R-GC2, R-GC3, R-GC4, R-GC9, R-GC11, R-LY1, R-J3, R-OUT4, R-CC10 |
| L3 | `exit/ex3-no-tuple-yaml` (fast set, 0.3 s) | The world of the example of Resolution 5 with real data: the app imports `parser.Yaml`, uses basic-cli 0.25.0 and roc-parser 2.0.0 (their real headers, stub modules), the pin is `nightly-2026-09-30-4c37850`. `compat.db` has the real results of `conformance/compat-sweep` (66 rows: 3 hashes on 22 nightlies, the real nightly list). `tln upgrade roc` (R-SP8: the packages are held, the nightly is free) fails with exit 10. The text and the `--json` `details` have both causes, the ranges, and the `fix:` lines | R-AL5, R-UM1, R-EP7, R-EP10, R-EP11, R-SP8, R-UP6, R-J5, R-OUT4 |

Run commands (the fast set skips `ex1` and `ex2`; `scripts/test.sh` runs `ex3`):

| Case | Command |
| --- | --- |
| `ex1` | `OPT=speed NET=1 REAL_ROC=1 tests/run.sh exit/ex1` (the dev build of `tln` crashes on a real GitHub answer: F1) |
| `ex2` | `REAL_ROC=1 tests/run.sh exit/ex2` (`REAL_CACHE=<dir>` for another cache) |
| all | `OPT=speed SLOW=1 NET=1 REAL_ROC=1 scripts/test.sh` (the nightly run) |
| on a machine with a small `/tmp` | `TMPDIR=<dir on disk>`: `ex2` copies 3 GB, `ex1` writes about 200 MB. The cases delete them (`trap`). |

## 5. Output (proposed, TW24)

| Output | Text | Where |
| --- | --- | --- |
| `ex1`, `ex2` | The `echo` lines of the `cmd` files and the output of `tln` as it is today. Nothing is new for the human to accept except the 2 facts below | `expect/stdout` |
| The default compiler after `ex1` | `default-roc = "nightly-2026-10-12-2664a27"` in `config.toml` (R-SO15: the first download sets it). The download is the newest compiler N that the command names. The pin stays at the compiler of PATH. So the default is a compiler that the project does not use | `ex1` `tree.diff` (F4) |
| `ex3` | The text of `Explain.lines` (slices 035, 036c) with the nightly ids of the real list | `ex3` `expect/stderr`, `stdout` |

## 6. Findings (for the manager)

| Id | Finding | Evidence | Suggested step |
| --- | --- | --- | --- |
| F1 | A dev binary of `tln` crashes on `tln add --dry-run lukewilliamboswell/roc-parser@2.0.0` and on `tln verify` with the real GitHub API: `[ROC CRASHED] boxy runtime list comparator ordering layout failed` (and `boxy runtime erased proc argument-layout registration failed`). Review result: the cause is not the bytes of the answers and not `--opt=dev` alone. The same sources built with `--opt=dev --no-cache` and with `--opt=speed` do not crash. The dev build against the warm roc cache (`.work/cache`) crashes (this is the object cache bug of `research/roc-object-cache/RESULTS.md`). The real answers of the 3 release lists (2.6 MB) on the fake HTTP give no crash, and a fresh cache gives none, so a small repro was not found. `f1-repro/repro.sh` builds both dev binaries and shows the crash against the real API (2026-10-25: warm cache: crash, `--no-cache`: no crash). Not reported upstream (manager). `release.yml` and the nightly run build with `--opt=speed` | `research/slice-053-revert/f1-repro/repro.sh` | The runners already build with `--no-cache`. Nothing more here. |
| F2 | The text of the example of Resolution 5 and the text of the code differ. The case has the text of the code (the TW24 proposal of 035 and 036c). See the table below | `ex3` `expect/stderr` | Design gap, for the human (review): change the design example, or a code slice. Not decided here. Same point as design gap G6 of slice 035. |
| F3 (follow-up row, manager) | For `tln upgrade roc` the `fix:` lines say `or tln upgrade roc`: the command that just failed | `ex3` `expect/stderr` | The code agent of a later slice leaves it out when the command is `upgrade roc`. No test names it now (the case shows it). |
| F4 (follow-up row, manager) | `tln upgrade` downloads N (the newest compiler) and `default-roc` becomes N, also when the pin and the result stay on the compiler of PATH | `ex1` `tree.diff` | The human confirms R-SO15 for this case. |
| F5 (follow-up row, manager) | The prompt of `tln tool rm talon` (CLI 6.5 example) has L0 and L2 cases and the L3 `--dry-run` list. No L3 case shows the prompt with a pseudo terminal | grep of `tests/scenarios` | A small tty case in a later slice, as `cache/cl2-prompt-tty`. Not built here. |
| F6 (manager fixes the status) | Slice 046: the plan row says done, the status line of `046-tool-install.md` says `code` | `docs/slices/046-tool-install.md:3` | The manager updates the file. |
| F7 | On a machine with no real cache dir (the GitHub runner of `nightly.yml`) `ex2` is skipped with the line `SKIP exit/ex2-gc-real-cache: no real roc cache: <dir> does not exist`. A cache dir with too few dirs fails the case (exit 3). A follow-up row builds a cache in `nightly.yml` (manager) | `ex2`, selftest row `net_cache` | Q2 answered |

The example of Resolution 5 against the output of `ex3`:

| Part | Example (`DESIGN-RESOLUTION.md` 5) | Output of `ex3` |
| --- | --- | --- |
| First line | `error: no tuple works` | `tln: error[no_tuple]: no tuple works: the unit check on <held nightly> fails for <package> (<module>); <platform> (no module is named)` |
| Per package | `<package> (module Yaml)   checks on nightly 09-24 .. 10-01` | `  <package> fails on <nightly A> .. <nightly B>`: the complement of the example (035 G6) |
| Last conflict line | `no nightly is in both ranges` | none |
| `fix:` 1 | `relax pf to "0.24.*" (checks on 09-26 .. 10-06, overlap 09-26 .. 10-01)` | `tln roc use <id>` (no nightly works, so the placeholder) |
| `fix:` 2 | `stop using parser.Yaml (parser.Parser checks on 10-09)` | `or tln upgrade roc`, then `or stop using parser.Yaml` (no range for `parser.Parser`) |

## 7. Out of scope

| Item | Reason |
| --- | --- |
| A real nightly build of a user app, `tln x` and `tln tool install` on real downloads | The L3 cases use real `roc bundle` and fake compilers. Design 7 has no exit criterion for them. The plan row 053 does not name them. |
| The `real-roc` runs named in slices 032 and 032b (a real unit fail with modules, a real build on the real `Fx`) | `ex1` runs the real ladder (real `roc check`, real build) on a real unit fail (`Yaml` on the pinned nightly: the note `module Yaml fails on nightly-2026-10-14-38a3029. Your app does not import it.`). No more cases. |
| The Windows and macOS GC | No real cache for them in this slice. `ci.yml` runs the fast set only. |
| The design example `tln upgrade` and `tln add parser@2.0.0` | Phase P2 |

## 8. Questions (TW17), answers of the review (2026-10-25)

| Id | Question | Answer |
| --- | --- | --- |
| Q1 | The Resolution 5 example and the code text differ (F2) | Not decided: the human decides (a design example change, or a code slice). Recorded as a design gap. `ex3` keeps the code text. |
| Q2 | `ex2` on a runner with no real cache | `ex2` skips with a reason when the dir does not exist, and fails when it has too few dirs. A cache built in `nightly.yml` is a follow-up row (manager). |
| Q3 | Tag of `ex2` | Keep `real-roc`. |
| Q4 | GitHub data in `ex1` | Accepted. |

## 9. Disputes (from the code agent)

None yet.

## 10. Verify results

| Check | Result |
| --- | --- |
| New cases against the current code | `OPT=speed NET=1 REAL_ROC=1 tests/run.sh exit/`: 3 passed, 15 s (`ex1` 14 s, `ex2` 4 s, `ex3` 0.3 s). No red state: the code exists. For the right reason of a red state see the mutations below. |
| `scripts/test.sh` (fast set, 2026-10-25) | pass: check 1.7 s, fmt 0.2 s, l0 7.7 s, l2 8.2 s, l3 10.0 s, selftest 3.3 s, l1 35.9 s. Total 68 s |
| `tests/selftest.sh` | 73 passed (72 before the row `net_env`). With the old `tests/run.sh` the row fails |
| Revert check | 8 hand mutations of the code (table below; `mutate.sh` and `mutate.py` rebuild them): m1 to m7 are caught, m0 (no edit) passes. 2 mutations (m2, m5) were first not caught: the case got a debug dir in the old set and a dir of 3 days. Then they were caught |
| Disk and processes | 157 GB free after the run. The copies of the real cache, the mutated builds and the work dirs are deleted. No background process |
| The real cache | Read only (`cp -a` of `~/.cache/roc`). No file in `~/.cache/roc` was changed (every run had `HOME` and the cache dirs in the case dir) |
| No GitHub change | No release, no push, no repository change. Some GitHub API calls and a few downloads of the compiler (75 MB each) in the experiments, and one of each in every run of `ex1` |

Mutations (one line of `cli/` each, in a copy; the copy and the binaries were deleted):

| Id | File | Edit | Case | Result |
| --- | --- | --- | --- | --- |
| m0 | none | baseline | `ex2`, `ex3` | pass |
| m1 | `cli/lib/CacheGc.roc` | a removed package keeps its sidecar | `ex2` | caught |
| m2 | `cli/lib/Gc.roc` | `is_build_name` does not accept `debug-` | `ex2` | caught, after the debug dir became an old dir in the case |
| m3 | `cli/RealFiles.roc` | `tree_info` gives the oldest file time | `ex2` | caught |
| m4 | `cli/RealFiles.roc` | `tree_info` sums only the first file | `ex2` | caught |
| m5 | `cli/lib/CacheGc.roc` | the span of a package is `gc-age`, not 1 day | `ex2` | caught, after the dir of 3 days was added |
| m6 | `cli/lib/Explain.roc` | no `stop using` line in `fix:` | `ex3` | caught |
| m7 | `cli/lib/Pick.roc` | `after_snapshot` is not applied | `ex1` | caught (speed build) |

Review run (2026-10-25): `scripts/test.sh` result in the reply to the manager; `OPT=speed NET=1 REAL_ROC=1 tests/run.sh exit/`: 3 passed (build 4.7 min); `ex2` with `REAL_CACHE=<missing dir>`: skipped with the reason.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| Code agent step | None: the 3 cases pass on the current code. No Roc file changed. |
| `scripts/test.sh` | exit 0 (test agent run): check 1.6, fmt 0.3, l0 8.2, l2 10.1, l3 10.2, selftest 4.4, l1 43.2 s |
| L4 | `OPT=speed NET=1 REAL_ROC=1 tests/run.sh exit/`: 3 of 3 pass; `ex2` skips with a missing real cache |
| Revert check | 7 hand mutations caught (section 10) |
| Findings | F1 is the known roc object-cache bug (replay in `research/slice-053-revert/f1-repro/`). F2 to F5 and Q2 are rows in PLAN-P1 5b. F6 fixed (046 status). |
