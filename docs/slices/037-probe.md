# 037 `tln probe`: the targets, the range search

Phase: P1. Status: done

Slice 037 is the plan row 037 of `PLAN-P1.md`. It needs 036c (done). The test agent proposes a split (section 1): the command with its three targets and the range search over the installed compilers are tested here. The optional downloads (R-DL1, R-DL4, R-DL6, R-NI4 and the opt-in of U5) are a later part (037c), because the design does not give the search policy for a download and U5 is open.

The private reference has about 634 lines of code (without comments and empty lines): `ProbeCmd` 545 and `ProbeRange` 134, minus the stubs (45). The row said about 450. The split in section 1 gives about 380 for part a and about 255 for part b. The tests of both parts are written and green with the reference. The reference was deleted at the review (2026-10-24) with `swap.sh`. `mutate.py` needs it, so it cannot run again. Its log stays.

## 1. Scope and split

| Item | Where | Rule | Part |
| --- | --- | --- | --- |
| The operand and the flags: alias, bundle file, none, `--range`, `--share` | `ProbeCmd.read` | R-CM8 R-PB1 R-PB6 | a |
| The header entry that a name selects, its hash | `ProbeCmd.entry` | R-PB1 R-SC1 R-SC6 to R-SC8 R-SC14 R-SC16 R-WS8 | a |
| A bundle file is a package: temp dir, `roc unbundle`, rename | `ProbeCmd.bundle_hash`, `run!` | R-PB1 R-FE2 R-FE3 | a |
| One unit check on the selected compiler, fact written (replace) | `run!` | R-PB2 R-P4 R-LD2 R-LD3 | a |
| The project file: check, build of an app, no fact | `run!` | R-PB1 R-PB2 R-PB7 R-LD7 | a |
| The texts and the `--json` data of these three | `ProbeCmd.text`, `ProbeCmd.data` | R-OUT2 R-OUT4 TW24 | a |
| A required download with no answer: exit 13 | `Start.run!` (done in 025) | R-NI5 R-EC13 | a (one run) |
| The search for the range: rounds of 3, newest first, open range cut in 4 | `ProbeRange.step`, `ProbeRange.found` | R-PB3 R-PP2 R-AL4 R-EP5 R-EP6 | b |
| The candidates: `nightly` switch, `min-release-age`, installed | `run!` | R-PB3 R-NS3 R-C7 | b |
| The budget `probe.max`, exit 12, `unknown` ends | `ProbeCmd.stop`, `run!` | R-PB4 R-P5 R-EC12 | b |
| `roc bundle`, then `tln probe --range <bundle file>` | `run!` | R-LB3 | b |
| Optional downloads: the opt-in, D with the cap, the skipped line, `max-toolchains = 0`, one prompt | none | R-DL1 R-DL4 R-DL6 R-NI4 | c (not in this slice) |

Parts a and b are tested here, and the code agent does both in one step (review). The files of part b: `tests/unit/proberange.roc`, expect 4 and the Range rows of expect 5 and 6 of `tests/unit/probecmd.roc`, and `tests/commands/cases/probe/pc2-range`.

## 2. Rules

| Rule | Tested by |
| --- | --- |
| R-CM8 | `probecmd.roc` expect 1, `pc1-targets`, `pc1-probe-command` |
| R-PB1 | the same, `pc2-range` run F |
| R-PB2 | `pc1-targets` runs 1 to 3, 7 to 11, `pc1-probe-command` |
| R-FE2, R-FE3, R-FE4 | `probecmd.roc` expect 7, `pc1-targets` runs 10 and 11, `pc2-range` runs F and I |
| R-PB3 | `proberange.roc` (3 expects), `pc2-range` runs A to H |
| R-PB4 | `probecmd.roc` expect 4, `pc2-range` runs A, C, D, E, G, H |
| R-PB6 (the `direct` branch, 3 forms) | `probecmd.roc` expect 1, `pc1-targets` run 12, `pc1-probe-command` |
| R-PB7 | `pc1-targets` runs 7 to 9 (no fact), `pc1-probe-command` (facts of the 2 unit runs only) |
| R-LB3 | `pc2-range` run F |
| R-NI4 (the default branch: no download, installed compilers only) | `pc2-range` (all runs: no download is offered) |
| R-NI5 | `pc1-targets` run 15 |
| R-DL1, R-DL4, R-DL6, R-NI4 (opt-in, cap, line, prompt) | part c, not in this slice |
| R-PB5, R-PB6 for a registry | P2 |

## 3. Public signatures (stubs in `cli/lib/`, `crash "todo"`)

The stubs have the contract tables in their doc comments. They are the spec of the code agent.

| Name | Signature | File |
| --- | --- | --- |
| `ProbeRange.End` | `{ id : Str, real : Bool }` | `cli/lib/ProbeRange.roc:29` |
| `ProbeRange.Found` | `[NoPass, Range({ from : End, to : End })]` | `cli/lib/ProbeRange.roc:32` |
| `ProbeRange.Round` | `[Need(List(Str)), Done(Found)]` | `cli/lib/ProbeRange.roc:35` |
| `ProbeRange.Input` | `{ hash, domain, askable, facts }` | `cli/lib/ProbeRange.roc:38` |
| `ProbeRange.step` | `Input -> Round` | `cli/lib/ProbeRange.roc:41` |
| `ProbeRange.found` | `Input -> Found` | `cli/lib/ProbeRange.roc:47` |
| `ProbeCmd.Target`, `Plan` | `[Alias(Str), Bundle(Str), Project]`, `{ target, range, opts }` | `cli/lib/ProbeCmd.roc:27` |
| `ProbeCmd.read` | `Args -> Try(Plan, Fail)` | `cli/lib/ProbeCmd.roc:42` |
| `ProbeCmd.entry` | `{ text, rows : List(Locked.Row) } -> Try(Units.Node, { fail, block })` | `cli/lib/ProbeCmd.roc:55` |
| `ProbeCmd.bundle_hash` | `Str -> Try(Str, Fail)` | `cli/lib/ProbeCmd.roc:60` |
| `ProbeCmd.unbundler` | `{ selected, installed, path, roots } -> Try(Str, [NoCompiler])` | `cli/lib/ProbeCmd.roc:74` |
| `ProbeCmd.Done`, `Shown` | the end of a probe, the three results | `cli/lib/ProbeCmd.roc:64`, `:73` |
| `ProbeCmd.stop` | `{ found, cut, unseen } -> Try(Fail, [None])` | `cli/lib/ProbeCmd.roc:89` |
| `ProbeCmd.text`, `data` | `Shown -> Str`, `Shown -> JsonDoc` | `cli/lib/ProbeCmd.roc:99`, `:109` |
| `ProbeCmd.run!` | `Fx, Args => I32` | `cli/lib/ProbeCmd.roc:113` |
| `Run.run!` | new branch `args.command == ["probe"]` | `cli/lib/Run.roc:74` |
| `main.roc` | `ProbeCmd` and `ProbeRange` in `exposes` | `cli/lib/main.roc` |

## 4. How the search reads the design (the tested reading)

`ProbeRange.step` has 4 rows (the table in its doc). p is the newest release of D with a real pass. A fact of any outcome (also a hang or a crash) is a fact: the release is not asked again (R-EP5).

| # | Case | Result |
| --- | --- | --- |
| 1 | Askable releases that are newer than p (all, when there is no p) have no fact | `Need`: the newest 3, newest first |
| 2 | There is no p | `Done(NoPass)` |
| 3 | q is the oldest release such that each release from q to p has a pass (real or inferred, R-EP6). F is the nearest real fail below q. Askable releases between F and q with no fact | `Need`: all of them when 3 or fewer, else the places m/4, m/2, 3m/4 |
| 4 | Nothing is left | `Done(Range)` |

An end is real when the release next to it, outside the range, is a real fail, or the end is an end of D (R-PB3). Else it is `unknown` (R-PB4).

## 5. Tests

| Layer | File and case | Content | Rules | U5 |
| --- | --- | --- | --- | --- |
| L0 | `tests/unit/proberange.roc` expect 1 (22 rows) | `step`: rounds, order, quartiles, faults, island, inferred passes, other target, other hash | R-PB3 R-PP2 R-AL4 R-PP4 R-EP5 R-EP6 R-EP8 | |
| L0 | same, expect 2 (14 rows) | `found`: real and unknown ends, faults, island, NoPass | R-PB3 R-PB4 R-EP5 R-EP6 | |
| L0 | same, expect 3 | the loop of the command against 768 worlds (256 truth tables of 8 releases, 3 askable sets): round rules, at most 8 rounds, the result equals the definition of R-PB3 (written in the test), the whole run is found | R-PB3 R-PB4 R-PP2 R-AL4 R-EP5 R-EP6 | |
| L0 | `tests/unit/probecmd.roc` expect 1 (20 rows) | `read`: the targets, `--range`, `--share` (3 forms), 2 operands, `--slots`, `--registry`, `--probe-downloads` read, `--frozen` refused by `Args` | R-CM8 R-PB1 R-PB6 R-FL7 R-FL11 R-NI4 R-NI5 | read only |
| L0 | same, expect 2 (16 rows) | `entry`: alias, full name, short name, `@sel` filter, tie with block, path entry, foreign URL, dedupe, platform | R-PB1 R-SC1 R-SC6 to R-SC8 R-SC14 R-SC16 R-WS8 R-LD3 R-H4 | |
| L0 | same, expect 3 (6 rows) | `bundle_hash` | R-PB1 R-FE2 | |
| L0 | same, expect 4 (11 rows) | `stop`: cut, 2 and 1 unknown ends, real ends, NoPass | R-PB4 R-EC12 R-UP7 | |
| L0 | same, expect 5 (18 rows) | `text` | R-PB1 R-PB2 R-PB3 R-PB4 R-LD2 R-LD3 R-LD7 R-P2 R-RC3 R-RC4 R-OUT2 | |
| L0 | same, expect 6 (5 rows) | `data` JSON | R-J3 R-J4 R-J5 R-OUT4 R-OUT5 | |
| L0 | same, expect 7 (8 rows) | `unbundler`: the selected compiler if installed, else the newest installed (both tag forms), else the `roc` on PATH, else a required download | R-FE4 R-FE2 | |
| L2 | `probe/pc1-targets` runs 1 to 3 | alias unit probes: pass, platform fail with a module, selector, hang replaces a fail of the db | R-PB1 R-PB2 R-SC16 R-LD2 R-LD3 R-P3 R-P4 R-RC3 | U6 (exit 0 for a fail and a hang) |
| L2 | same, runs 4 and 5 | not in the project, path entry: exit 2 | R-SC1 R-H4 R-EC2 | |
| L2 | same, run 6 | `--json` of a unit probe | R-J3 R-J4 R-OUT4 | |
| L2 | same, runs 7 to 9 | project file: app check and build, failed check, package (no build); no fact | R-PB1 R-PB2 R-PB7 R-LD7 | U6 (exit 0 for a failed check) |
| L2 | same, runs 10 and 11 | bundle file: unbundle in a temp dir and rename, then the dir is there: no unbundle | R-PB1 R-FE2 R-FE3 R-FE4 (rule 3: no compiler is installed, the program is the `roc` on PATH) | |
| L2 | same, runs 12 to 14 | `--share`, 2 operands, `--range` with no operand: exit 2 | R-PB6 R-CM8 | |
| L2 | same, run 15 | a pin that is not installed, no answer: exit 13 | R-NI5 R-EC13 | |
| L2 | `probe/pc2-range` run A | `probe.max` 4 cuts round 2: exit 12, facts saved | R-P5 R-PP4 R-PB4 R-EC12 | |
| L2 | same, run B | goes on from the facts: 3 probes, real ends, exit 0 | R-PB3 R-AL4 R-PP4 | default branch |
| L2 | same, runs C and D | 8 probes each, 1 and 2 unknown ends (n4 is not installed, n8 is a crash), exit 12 | R-PB3 R-PB4 R-EP5 R-LD2 | default branch, U6 (exit 12 for an unknown end) |
| L2 | same, run E | all facts known: no probe, same result, `--json` has the range in `error.details` | R-AL4 R-J5 | |
| L2 | same, run F | `--range <bundle file>`: the inferred passes (R-EP6) make the whole list the range, 7 probes, exit 0 | R-LB3 R-PB1 R-EP6 R-FE4 (rule 2: the newest installed unbundles) | default branch |
| L2 | same, run I | a bundle file with no `--range`, pin n3 installed: n3 unbundles and runs the unit check (not the newest, n10) | R-FE4 R-FE3 R-PB1 | |
| L2 | same, run G | `[toolchain] nightly = false`: no candidate, no pass, exit 12 | R-NS3 R-PB4 | U6 |
| L2 | same, run H | `min-release-age = "7d"` hides n8 to n10: 5 probes, upper end unknown | R-C7 R-NS3 R-PB4 | default branch, U6 |
| L3 | `probe/pc1-probe-command` | the real binary, real Fx, fake roc: 2 unit probes with facts, the project file, `--json`, 4 usage errors | R-CM8 R-PB1 R-PB2 R-PB6 R-PB7 R-P4 | |

L0: `proberange.roc` 3 expects, `probecmd.roc` 7 expects (84 rows). L2: 2 cases (15 and 9 runs). L3: 1 case. Part b is `proberange.roc`, expect 4 and the Range rows of expect 5 and 6, and `pc2-range`.

The U5 and U6 column: U5 marks the rows that depend on the opt-in. U6 marks the rows that depend on the exit code of a probe whose result is a fail, a hang or a crash, or of a range with no pass (user question U6, see the review). If U6 gives a code, these rows change.

U5: In this slice no download is made, so each run that shows an `unknown` end is the default branch of R-NI4 ("no download, installed compilers only"). With the opt-in (part c), the same runs would ask for more compilers. These rows change in part c. `--probe-downloads` is read by `ProbeCmd.read` and used by nobody here.

## 6. Output proposals (TW24, for the human review)

The design gives the exit codes and the rules, not the texts. All of these are proposals.

| Where | Text |
| --- | --- |
| Unit | `unit check of <label> on <compiler>: pass`, `fail (<module>, <module>)`, `fail (no module is named)`, `hang`, `crash` |
| `<label>` | `<name> <version>`, `the platform <name> <version>`, the hash for a bundle file |
| Project | `<file> on <compiler>`, `check: passed`, `check: failed, <n> errors` (`1 error`), then `  <place>: <title>`; `hang`; `crash (<text>)`; `build: ...` or `build: not run (a package has no app)` / `(a platform has no app)` |
| Range | `<label> passes on <from> .. <to>`, `  lower end: <id> (real)` or `(unknown)`, `  upper end: ...`. No pass: `<label>: no release of the compiler list has a real pass` |
| Exit 12 | `the range has 2 ends that are not a real fact (unknown): no installed compiler can show them. Run tln roc install for more compilers.` (`1 end`, `show it`). `no installed compiler gave a real pass, and no real fact exists for <n> releases of the list. ...`. The budget text is `Units.spent` (done in 031) |
| Usage | `tln probe --share needs a registry, and this version of tln has only --registry direct`; `tln probe takes one name or one bundle file`; `tln probe --range needs a header alias or a bundle file: the project file has no hash`; `'<x>' is a path entry or a foreign URL: it has no hash to probe`; `'<path>' is not a package archive: the file name must be <hash>.tar.zst`; `'<x>' is not in the project` (the text of `Lookup.find`) |
| `--json` `data` | unit: `kind, hash, label, compiler, outcome, modules, probes`. project: `kind, file, compiler, check, build, probes` (`check` and `build`: `outcome, errors[place, title]`). range: `kind, hash, label, range (null or from/to with id and real), probes` |
| `--json` with exit 12 | `ok` false, `data` null, `error.details` has the `data` above (R-J5, as `tln audit` does for exit 21) |
| Human text with `--json` | on stderr (as `Common.shown_fx`) |

## 7. Out of scope, questions (TW17)

Out of scope:

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | R-DL1, R-DL4, R-DL6, R-NI4 (opt-in, cap, skipped line, `max-toolchains = 0`, one prompt) | Part c. The design gives the opt-in names (R-NI4, R-DL4, CLI 1 flag table: `--probe-downloads`, or `--yes` inside the cap), but no search policy for a download. Q8 |
| Out 2 | R-PB5, the registry branch of R-PB6 | P2 |
| Out 3 | `--share` for a header entry on `direct` | R-PB6 gives exit 2: tested |
| Out 4 | The `probe.max` budget for the project file (2 probes) | no design text. Not tested. The code needs no check |
| Out 5 | A matrix for epochs (more than one release in an epoch) | P2 (R-EP4). In P1 each release is an epoch |

U5 (the user's open question): the design already names the opt-in. R-NI4, R-DL4 and the CLI 1 flag table give `--probe-downloads`, or `--yes` inside the cap. So the form of the opt-in is fixed by the design. The open part is the one-prompt question: how a person accepts a required download and refuses optional ones. The tested reading is (c): the prompt asks only for the required download (`Start.run!`, done in 025), and optional downloads happen only with the opt-in. This slice makes no optional download.

Questions:

| Id | Question | Options (tested reading first) |
| --- | --- | --- |
| Q1 (E1) | The exit code of a unit probe that fails, hangs or crashes | (a) 0: the fact is the result (tested). (b) a code for a failed probe. A probe with no fact (R-P3: a signal from outside, a start error) is exit 1 in both |
| Q2 (P1) | A probe with no `--range` when a fact exists | (a) probe again and replace the fact (tested, `existing=replace`). (b) print the known fact and probe only with a flag |
| Q3 (R1) | `--range` with no operand | (a) exit 2, the project file has no hash (tested). (b) range of each package of the project file |
| Q4 (R-FE4) | Which `roc` runs `unbundle` for a bundle file | Answered by the design (R-FE4): the selected compiler if installed, else the newest installed, else the `roc` on PATH, else a required download. The tests follow it (`unbundler`, pc1 run 10, pc2 runs F and I). No gap. `Gather` and `Fetch.packages!` use `roc` by name: this slice does not change them |
| Q5 (S1, S2) | The order of the rounds | (a) newest 3 first, then the quartile places of the open range (tested, section 4). (b) a binary search with one probe a round (R-PB3 and R-PP2 say 3 for a round: not chosen) |
| Q6 (S3) | A hang or a crash next to an end | (a) the end is unknown (tested: only a real fail makes an end real). (b) a fault is a fail for the end |
| Q7 (S4) | No pass at all | (a) exit 12 when some release of D has no fact, else exit 0 (tested). (b) always 0. (c) always 12 |
| Q8 | Part c: how many compilers to download, in which order | A policy is needed. The proposal of `036c-epochs-downloads.md` section 7 stays: D with the cap R-DL6 |
| Q9 | Split | (a) accept the code in one step (about 634 lines, the tests are written). (b) part a first (about 380 lines), then part b (about 255): the test agent stages the part b tests. (c) another cut |
| Q10 (T1) | An entry with no hash (a path entry, a foreign URL) | (a) exit 2 (tested). (b) probe the file of the path |
| Q11 (B1) | A bundle file needs a project dir here (the config, the compiler selection). A run with no project | (a) the project is found as for other commands, `--file` or the dir (tested). (b) no project: the compiler of `ROC_TOOLCHAIN` or `PATH` |
| Q12 | The alias scope | (a) the header entries of the current member, else of all members (as `why`), with the selector filter R-SC16 (tested). (b) the closure |
| Q13 | The compiler of a run with no `--range` | (a) as `verify` (R-SO21): `ROC_TOOLCHAIN`, then the pin, a required download by R-NI5 (tested). (b) the pin only |
| Q14 | D for the range | (a) the releases of the host list with an asset, in the order of R-NS1, as `PickLoop.wide!` reads them (tested). (b) only the candidates that the switch allows |

The design gaps: the exit code of a failed unit probe and the exit code of `--range` with no pass (both: U6). No design file is changed by this slice.

## 8. Changed old tests (TW21)

The change is by `research/slice-037-revert/update-l3.sh`. The old copies are in `research/slice-037-revert/before/`. No L2 case and no L0 file changed.

| Case | File | Change | Reason |
| --- | --- | --- | --- |
| `tests/scenarios/install/in1-workspace-frozen-rename` (L3) | `expect/stdout` | line `exit 1` after `== tln probe ./apps/b` is `exit 2` | `probe` is built. `./apps/b` is no header alias and no bundle file: a usage error |
| same | `expect/stderr` | last line `tln: error[internal]: command 'probe' is not built yet` is `tln: error[usage]: './apps/b' is not in the project` | same |
| same | `cmd` | the comment before `st tln probe ./apps/b` says the command is not built: it says exit 2 | the old comment is wrong now |

## 9. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Red (stubs, `research/slice-037-revert/red-run.log`, confirmed again after the review) | l0: `proberange.roc` 3 of 3 fail (todo), `probecmd.roc` 7 of 7 fail (todo). l2: `pc1-targets` and `pc2-range` crash with `todo` (87 other cases pass). l3: `probe/pc1-probe-command` and `install/in1-workspace-frozen-rename` fail. check, fmt, l1, selftest pass |
| Green (the reference before it was deleted, `research/slice-037-revert/green-run.log`) | all steps pass: check 1.1, fmt 0.2, l0 7.0, l2 3.6, l3 9.9, selftest 10.8, l1 30.7 (budgets 10, 5, 10, 30, 60, 20, 60). The 768 worlds of `proberange.roc` expect 3 take 0.6 s. The green time must stay under 10 s |

Revert check: 17 mutations of the reference, filtered runs only (`research/slice-037-revert/mutate.py`, `mutate.log`). A mutation that only gave a compiler warning is not counted: the 3 first versions of M10, M11 and M13 were such, and were written again.

| Id | Mutation | Caught by |
| --- | --- | --- |
| M1 | first round asks the oldest releases | `proberange.roc` |
| M2 | picks are not the quartile places | `proberange.roc` |
| M3 | the lower end is always real | `proberange.roc` |
| M4 | a row of another hash is read | `proberange.roc` |
| M5 | a row of another target is read | `proberange.roc` |
| M6 | a fault is asked again | `proberange.roc` |
| M8 | one unknown end gives no exit 12 | `probecmd.roc` expect 4 |
| M9 | a bundle is unbundled again | L2 (`pc1-targets` run 11) |
| M10 | the known facts are not read | L2 (`pc2-range`) |
| M11 | the switch and the age do not limit the candidates | L2 (`pc2-range` runs G, H) |
| M12 | a known fact is not replaced | L2 (`pc1-targets` run 3) |
| M13 | the build runs after a failed check | L2 (`pc1-targets` run 8) |
| M14 | `--share` is not exit 2 | `probecmd.roc` expect 1 |
| M15 | an installed compiler is not needed | L2 (`pc2-range`) |
| M16 | the selected compiler does not unbundle (R-FE4 rule 1) | `probecmd.roc` expect 7 |
| M17 | the oldest installed compiler unbundles (rule 2) | `probecmd.roc` expect 7 |
| M18 | `roc` by name unbundles | L2 (`pc1-targets` run 10, `pc2-range` runs F and I) |

17 of 17 were caught.

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Compiler limits | `roc test` crashes when an `Err` record has a `Bool` field. `==` on a `Try` or on a tag union with no annotation does not compile: use `match`. A warning (unused variable) is an error for `roc build`. No list spread. |
| Flow of `run!` (a proposal, the calls are fixed by the L2 `calls.log`) | `Install.begin!`, `Install.check_member` (project target only), `Known.record!`, `Compiler.toolchain_of`, `Install.compiler!`, the `ResolveBase.Request` of `Verify.flow!`. No `--range`: `ResolveLoad.prepared!`, `ResolveBase.check_pin`, `Start.run!`, then the unit probe or the project probes. `--range`: `ResolveLoad.load!` only (no pin decision, no required download). |
| Alias | `ProbeCmd.entry` over the header rows, then `Fetch.packages!` for its URL. |
| Bundle file | `ProbeCmd.unbundler` gives the program (R-FE4). With no `--range`, `selected` is the id that `Start.run!` started and `installed` is its list. With `--range`, `selected` is `""` and `installed` is `Launch.toolchains!` (one call, also used by the search). Then `list_dirs!` of `packages/`. When the dir is not there: `random!`, `make_dirs!` temp, `copy_file!`, one `spawn_all!` with `<program> unbundle <hash>.tar.zst` in the temp dir, `rename!`, `delete!` temp. `Err(NoCompiler)` is `Compiler.failure(NoCompiler)` (the required download of rule 4 is not tested). |
| Unit probe | `Units.specs`, `UnitFlow.probes!`, `Units.results`, `Facts.save!` with `Replace`. No `Facts.load!`. |
| Project | `Probe.args`, `UnitFlow.probes!`, `Probe.classify`, `Probe.errors`. The build output is in `<cache>/talon/tmp/<hex>/tln-probe.out`, deleted after. No fact. |
| Range | `Toolchain.host`, `Nightlies.list!`, `Toolchain.domain(...).auto`, `Launch.toolchains!`, one `Facts.load!` for all releases of D, then rounds: `ProbeRange.step`, `Units.budget`, `Launch.touch!` for each compiler, one `fx.probes!`, `Units.results` for each probe, one `Facts.save!` (replace) for the round. Then `ProbeCmd.stop`. |
| Exit 12 | The human text is printed first. Then the failure with `details` set to `ProbeCmd.data` (`Common.failed!`). |
| `unseen` | The releases of D with no row of the hash and the target `any`. |

## Review (manager, 2026-10-24)

The slice is accepted with no split: both parts are tested, and the code agent does both in one step. The private reference and `swap.sh` are deleted. The red state is confirmed (`red-run.log`: l0 10 expects fail, l2 2 cases, l3 2 cases; the other steps pass).

| Item | Answer |
| --- | --- |
| Exit code of a probe whose target fails, hangs or crashes (Q1) | Accepted as tested: exit 0, the fact is the result. Exit 1 only with no fact (R-P3). R-EC has no code for it, so the manager adds the user question U6 (option: exit 10 or 11 for a project-file fail, for CI). Rows with U6 in section 5 depend on it |
| `--range` with no pass (Q7) | Accepted: exit 12 when a release of D has no fact, else exit 0. Same U6 mark |
| U5 | R-NI4 names the opt-in (`--probe-downloads`, `--yes` inside the cap). The open part is only the one prompt. The "U5 default branch" marks stay. The download branch is part 037c (the manager adds the row) |
| R-FE4 (Q4) | The rule says: the selected compiler if installed, else the newest installed, else the `roc` on PATH, else a required download. The tests follow it now: `probecmd.roc` expect 7 (8 rows), `pc1-targets` run 10 (rule 3), `pc2-range` run F (rule 2) and run I (rule 1). No gap. Changed after the review: the first version used `roc` by name, and the call log of the two cases changed |
| Q2 (probe again, replace the fact) | Accepted as tested |
| Q3 (`--range` with no operand: exit 2) | Accepted as tested |
| Q5 (newest 3, then quartiles) | Accepted as tested |
| Q6 (a hang or crash next to an end is `unknown`) | Accepted as tested |
| Q8 (policy for downloads) | Stays for part 037c. The proposal of `036c-epochs-downloads.md` section 7 holds |
| Q9 (split) | Not split. Both parts in one code step |
| Q10 (path entry or foreign URL: exit 2) | Accepted as tested |
| Q11 (a bundle file needs a project dir, `verify` compiler choice) | Accepted as tested. `--range` skips `Start.run!` |
| Q12 (alias scope: header entries of the current member, else all) | Accepted as tested |
| Q13 (compiler of a run with no `--range`: as `verify`) | Accepted as tested |
| Q14 (D: the releases of the host list) | Accepted as tested |
| Texts and JSON keys (section 6) | Accepted as proposals. The range in `error.details` is accepted |
| Changed L3 case `install/in1-workspace-frozen-rename` | Accepted |
| l0 time | The green time must stay under 10 s (7.0 s now) |

For the manager (design gaps that change exit codes): the exit code of a failed probe and of a range with no pass (U6). No design file is changed.

## Code result (code agent, 2026-10-24)

`scripts/test.sh` exit 0: check 1.2, fmt 0.2, l0 7.4, l2 2.2, l3 9.8, selftest 10.8, l1 30.3 s (budgets 10, 5, 10, 30, 60, 20, 60). `OPT=speed`: all pass, l2 195 s (the known reason), l0 8.4.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/ProbeRange.roc` | 159 | `step`, `found` (stub bodies replaced), the cells of D, `Epochs.epochs` for the inferred passes |
| `cli/lib/ProbeCmd.roc` | 466 | `read`, `entry`, `bundle_hash`, `unbundler`, `stop`, `text`, `data`, `run!` and the private flow (request, `single!`, `ranged!`, `materialise!`) |
| `cli/lib/ProbeShow.roc` | 60 | new: the words and JSON parts of `text` and `data` (module size) |
| `cli/lib/ProbeUnit.roc` | 81 | new: `node!` (one unit check, fact with `Replace`), `project!` (check, then build of an app) |
| `cli/lib/ProbeSearch.roc` | 106 | new: `run!` (compiler list, one `Facts.load!`, rounds, budget, one `Facts.save!` for each round) |
| `cli/lib/ProbeBundle.roc` | 65 | new: `ensure!` (temp dir, `copy_file!`, `unbundle`, `rename!`, `delete!`) |
| `cli/lib/main.roc` | +4 | exposes `ProbeBundle`, `ProbeSearch`, `ProbeShow`, `ProbeUnit` |

`Run.roc` was not changed (the branch was there). No public signature changed.

| Decision | Choice | Rejected |
| --- | --- | --- |
| Where the flow lives | The flow is in `ProbeCmd` (private functions). The effectful parts are in 3 new modules that do not import `ProbeCmd` (no import cycle), and they use structural records for `Done` | One big `ProbeCmd` (over 500 lines) |
| D of the range | `Nightlies.candidates` of the host list (releases with one asset), as Q14 (a) says | All releases of the list (`PickLoop.wide!` takes them all: a release with no asset could never get a fact, and `unseen` would stay above 0) |
| Askable | `Toolchain.domain(...).auto` that is installed | Candidates that the switch allows (Q14 b) |
| Round budget | `Units.budget` with `fixed: 0`. A cut round runs the first `run` releases, saves the facts, and ends the search with `Units.spent` (left = releases not asked) | A budget check before the round only |
| Releases asked in a round | `ProbeRange.step` row 1 asks releases with no real fact, so an inferred cell is asked again when it is newer than p | Skip inferred cells (the doc says "no real fact") |
| Failure of the compiler list | Passed on as the failure of the run (the search needs D) | Degrade to `[]` |
| Program of `Fetch.packages!` for an alias | `Start.Started.program` with no `--range`, the `ProbeCmd.unbundler` program with `--range` (R-FE4) | `roc` by name |
| `NoFact` of a project probe | Failure of kind `Internal` (exit 1), text `the <check or build> of <file> on <compiler> gave no result: <text>. Run the command again.` (as `Units.results`) | none |
| Bundle file errors | `copy_file!` error is kind `Usage` `cannot read the bundle file <path>`. A failed unbundle is `Fetch.unbundle_failed` (exit 16) | none |

No test, fixture or expected file changed (no dispute rows). No question (TW17). No new compiler limit.

## Verify results

Revert check (TW12), filtered runs only: 10 mutations of the final code, `research/slice-037-revert/agent-mutate.py`, log `agent-mutate.log`, table `agent-results.md`. Caught 10 of 10. The code is the same after the run (`code-final.sha256` OK, 7 files).

| Id | Mutation | Caught by |
| --- | --- | --- |
| P1 | the first round asks the oldest releases | l0 `proberange` |
| P2 | the picks are not the quartile places | l0 `proberange` |
| P3 | a hang or a crash is asked again | l0 `proberange` |
| P4 | one unknown end gives no exit 12 | l0 `probecmd` |
| P5 | a bundle is unbundled when its dir is there | l2 `probe/pc1-targets` |
| P6 | the budget does not count started probes | l2 `probe/pc2-range` |
| P7 | a compiler that is not installed is asked | l2 `probe/pc2-range` |
| P8 | the build runs after a failed check | l2 `probe/pc1-targets` |
| P9 | a known fact is not replaced | l2 `probe/pc1-targets` |
| P10 | the known facts are not read | l2 `probe/pc2-range` |

## Close (manager, 2026-10-24)

The code decisions are accepted. An unreadable compiler list fails `--range` (it needs D), unlike the resolve commands of 036c, which fall back to the held compiler. The revert check caught 10 of 10 targeted mutations, so no gap rows are needed. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN. l0 is 8.9 s in the full run (5.2 s alone; the l1 builds run at the same time), so the next slices must watch it. U6 stays open for the user. Status: done.
