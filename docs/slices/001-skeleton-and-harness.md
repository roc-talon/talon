# 001 Skeleton and harness

Phase: P0. Status: verify

Slice 001 makes the base of all later slices: the `cli/` app, the `Fx` record, the real `Fx`, the runners for L0, L2 and L3, the fake `roc`, and `scripts/test.sh`. The harness code is complete and green. The Talon decisions are stubs (`crash "todo"`) and their tests are red.

## Rules

| Group | Ids | Design |
| --- | --- | --- |
| Commands | R-CM19, R-CM20 | CLI 1 |
| Global flags | R-FL1 to R-FL4, R-FL6, R-FL7, R-FL12 | CLI 1 |
| Exit codes | R-E1 to R-E5, R-EC0 to R-EC21 (the table of CLI 3, all codes, as a table test) | CLI 3 |
| JSON | R-J1 to R-J6 | CLI 3 |
| Output | R-OUT1, R-OUT4, R-OUT5 | CLI 3 |
| Prompts | R-NM1 to R-NM10, R-NR1, R-NR5, R-NR6 | CLI 4 |
| TTY | R-HF1 | Design 6.2 |
| Variables | R-EV1, R-EV8, R-EV9, R-EV18, R-EV22 | CLI 1 |

## Files

| Path | Writer | State |
| --- | --- | --- |
| `cli/main.roc` | Test agent (harness) | Done. It builds the real `Fx` and calls `Run.run!`. No Talon logic (TW4). |
| `cli/RealFx.roc` | Test agent (harness) | Done. The real `Fx` on basic-cli 0.25.0. |
| `cli/fxprobe.roc` | Test agent (harness) | Done. A test tool: one real `Fx` call for each command line. Not part of `tln`. |
| `cli/lib/` (package) | Stubs from the test agent. Bodies from the code agent. | `Fx`, `Answer` and the types are done. `Kind`, `JsonDoc`, `Fail`, `Exit`, `Out`, `Mode`, `Prompt`, `Args`, `Clock`, `Run` are stubs. |
| `tests/unit/*.roc` | Test agent | 22 `expect`s, red ("todo") |
| `tests/commands/` (`main.roc`, `FakeFx.roc`, `run.sh`, `cases/`) | Test agent | Runner and fake: done. 3 cases: red. |
| `tests/run.sh`, `tests/lib.sh`, `tests/fakes/roc`, `tests/tools/ptyrun.py`, `tests/scenarios/` | Test agent | Runner and fake: done. 5 cases: 3 red, 2 green (real `Fx`). |
| `tests/selftest.sh`, `tests/selftest/` | Test agent | The "must fail" self-tests of both runners. 23 checks, green. |
| `scripts/test.sh`, `scripts/env.sh` | Test agent | Done |
| `scripts/rules.sh` | Test agent | One line changed: `cli/` and `worker/` no longer count as test dirs (a rule id in a code comment is no test) |
| `research/roc-test-segfault/repro.roc` | Test agent | Repro of a compiler crash (see "Compiler limits") |

The layout follows the manager's recommendation. The local package `cli/lib` has a `package` header and does not depend on the platform. `cli/main.roc` and the test apps reach it with a path entry (`lib: "lib/main.roc"`). A path entry to Talon's own code is allowed (R-GP3 is about generic packages).

## Public signatures

`Fx` (`cli/lib/Fx.roc`). One record of effect functions. A test fakes it in a compiled basic-cli app (`tests/commands/FakeFx.roc`).

| Call | Type | Real `Fx` | Fake `Fx` |
| --- | --- | --- | --- |
| `args!` | `() => List(Str)` | The arguments that `main!` got | `fx/args`, one for each line |
| `env_all!` | `() => List((Str, Str))` | `Env.dict!` | `fx/env`, `NAME=value` for each line |
| `cwd!` | `() => Str` | `Env.cwd!` | `<case>/project` |
| `tty!` | `() => { stdin : Bool, stderr : Bool }` | R-HF1: `sh -c 'test -t 0; i=$?; test -t 2; echo $i $?'` with inherited stdin and stderr. Windows: both true. | `fx/tty` |
| `clock!` | `() => U64` | Seconds since the epoch, from `Utc.now!`. `TALON_NOW` is not applied here (R-EV22). | `fx/clock` |
| `read_files!` | `List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)]))` | `Path.read_utf8!`, in list order | Real files in `<case>/project` and `home` |
| `write_atomic!` | `List({ path : Str, content : Str }) => Try({}, { path : Str, err : [..] })` | Temp file and `rename`. It stops at the first error. Slice 002 adds the rules of CLI 7.4. | Writes in the case dir |
| `out!`, `err!` | `Str => {}` | stdout, stderr, no added newline | `out/stdout`, `out/stderr` |
| `ask!` | `Str => Try(Str, [EndOfInput])` | Writes the prompt to stderr, reads one line of stdin | `fx/answers`, one reply for each line |

Later slices add calls (`fetch!`, `probes!`, `lock!`, `db_query!` and the rest of `TESTING.md` 2.3). Each call is coarse (TW3).

| Module (`cli/lib/`) | Public functions | Rules |
| --- | --- | --- |
| `Kind` | `code : Kind -> I32`, `name : Kind -> Str`. Tags: `Done`, `Internal`, `Usage`, `NoTuple`, `AppError`, `Budget`, `Consent`, `Frozen`, `Network`, `Integrity`, `Conflict`, `Environment`, `Input`, `Rejected`, `Findings` | R-EC0 to R-EC21, R-E5 |
| `Fail` | `new : Kind, Str -> Fail`, `line : Fail -> Str` (the line `tln: error[<kind>]: <message>`) | R-E4 |
| `Exit` | `choose : { failures, child } -> I32` | R-E1, R-E2 |
| `JsonDoc` | `render : JsonDoc -> Str` | R-J1 |
| `Out` | `schema`, `json_ok`, `json_fail`, `fail`, `show` | R-J1 to R-J6, R-OUT4, R-OUT5, R-FL4, R-E3, R-E4 |
| `Mode` | `from_env`, `with_tty`, `color` | R-NM1, R-NM2, R-NR1, R-EV8, R-EV9 |
| `Prompt` | `decide`, `reply`, `text`, `picker`, `ask!` | R-NM3 to R-NM10, R-NR1, R-NR5, R-NR6 |
| `Args` | `parse` | R-CM19, R-CM20, R-FL1 to R-FL4, R-FL6, R-FL7, R-FL12 |
| `Clock` | `parse_utc`, `now` | R-EV18, R-EV22 |
| `Run` | `run! : Fx => I32` | R-FL12 (dispatch), R-EC2, R-J, R-E |

The doc comment of each stub holds the contract. This file holds the rules that are too long for a comment (Args rules, Output).

## Args rules

`Args.parse(words)` gets the words after `tln`. A "flag" is a word that starts with `-` and has more than one character. A bare `--` ends the parse: the words after it go to `passthrough` as they are.

| # | Rule | Source |
| --- | --- | --- |
| A1 | The global flags are `--json`, `--yes`, `--offline`, `--quiet` (no value), and `--registry <v>`, `--file <v>` (the next word is the value). They work for every command and at any place before a bare `--` (Q1). | R-FL1 to R-FL6 |
| A2 | The command words are the first words that are not flags: one word, or two for `tool`, `roc` and `cache`. `share` takes an optional second word. A verb alias becomes the long form in `command` (`rm` to `remove`, `ls` to `list`, `i` and `add` to `install`, `up` to `update`), at the top level and in the second word of `tool`, `roc` and `cache`. `typed` holds the words as typed. | R-CM19, R-CM20 |
| A3 | Words after the command words that are not flags are `operands`, in order. | |
| A4 | A flag that is not global must be in the table of R-FL12 for the command. A flag with a value (`--as`, `--ci`, `--path`, `--roc`, `--snapshot`, `--strategy`, `--slots`, `--reason`, `--to`, `--ignore`) takes the next word. The other flags go to `options` in the order of the line, as (flag, value or `Unset`). For a command that R-FL12 does not name the flag for: a usage failure. | R-FL12 |
| A5 | The resolve flags (`--frozen`, `--no-probe`, `--no-check`, `--dry-run`, `--snapshot`, `--strategy`, `--slots`) work for `install`, `remove`, `update`, `upgrade`, `verify`. `--slots` also works for `probe`, `tool install` and `x`. `--dry-run` also works for `cache gc`, `cache clean` and `tool remove` (own meaning). Other commands reject them. R-FL13 and R-FL14 (more limits on `--frozen`, `--dry-run`, for slice 007) are not in this slice. | R-FL7, R-FL12 |
| A6 | `--file` works for the commands that use a project: `install`, `remove`, `update`, `upgrade`, `outdated`, `why`, `list`, `patch`, `probe`, `verify`, `audit`, `publish`, `roc use`. For `roc` (the other subcommands), `tool`, `x`, `cache`, `setup`, `yank`, `move`: usage failure. `init` and `share`: Q8. | R-FL6, R-PD14, R-PD16 |
| A7 | `--json` before a bare `--` with `x`: usage failure. | R-FL1 |
| A8 | The command words that are not a known command (the 21 top-level words of CLI 1 with their aliases, and the sub-words of R-CM15 to R-CM17, R-CM23): usage failure, message `unknown command '<typed>'`. A flag without its value: usage failure, `flag '<flag>' needs a value`. A flag that is not allowed: `flag '<flag>' is not for '<command, long form>'`. Messages are a proposal (TW24). | R-FL12, R-EC2 |
| A9 | On a failure the error has `json` (true when `--json` is anywhere before a bare `--`, also after the word that failed) and `typed` (the command words as typed, up to the failure). | R-J1 |
| A10 | For flags of commands of later phases (`init`, `probe`, `patch`, `x`, `tool`, `roc`, `cache`, `setup`, `audit`, `yank`, `move`, `share`), follow the R-FL12 table. A flag that the table does not name for the command is rejected. Gaps go to Questions. | R-FL12 |

## Tests

L0 (22 `expect`s, `roc test`, each file one test app). Each `expect` checks a table of cases and prints the wrong rows with `dbg`.

| File | `expect`s | Checks |
| --- | --- | --- |
| `tests/unit/kind.roc` | 3 | The table of codes and names, no code twice (R-EC0 to R-EC21, R-E5). `Exit.choose` (R-E1, R-E2). `Fail.line` (R-E4). |
| `tests/unit/out.roc` | 4 | `JsonDoc.render` (R-J1). The envelope (R-J1 to R-J6, R-OUT5, R-E5). `Out.fail` with and without `--json` (R-J1, R-J2, R-E4, R-OUT4). `Out.show` for `--quiet` (R-FL4). |
| `tests/unit/mode.roc` | 3 | Mode from the variables and `--json` (R-NM1, R-NM2, R-EV1, R-EV8). `with_tty` (R-NR1, R-HF1). Color (R-EV9, R-NM3). |
| `tests/unit/clock.roc` | 2 | `TALON_NOW` parse (R-EV18). `now` (R-EV22). |
| `tests/unit/args.roc` | 5 | Verb aliases (R-CM19, R-CM20). Global flags, options, `--` (R-FL1 to R-FL4, R-FL6). Rejected flags (R-FL12, R-FL6, R-FL7, R-FL1). Accepted flags. Failure messages. |
| `tests/unit/prompt.roc` | 5 | `decide` in non-interactive mode (R-NM3 to R-NM5, R-NM12, R-NR5). `decide` with `--yes` and answer flags (R-NM8 to R-NM10, R-NR6). `decide` interactive, `NeedTty` (R-NM2, R-NR1, R-HF1). `picker` (R-NM7). `reply` and `text` (R-NR2). |

Deep tests (6 red cases, 2 green cases):

| Layer | Case | Checks | State |
| --- | --- | --- | --- |
| L3 | `tests/scenarios/json/ec2-unknown-command-json` | `tln --json frobnicate`: exit 2, one envelope on stdout, the error line on stderr | red |
| L3 | `tests/scenarios/errors/e3-quiet-keeps-error` | `tln --quiet frobnicate`: exit 2, the error stays, no stdout | red |
| L3 | `tests/scenarios/flags/fl12-bad-flags` | 5 bad command lines, each exit 2 with its error line (a flag the command does not take, `--file` of `cache gc`, a resolve flag of `list`, a resolve-free command, a flag with no value) | red |
| L2 | `tests/commands/cases/prompt/nm-noninteractive-ci` | `CI=true`: no tty call, no ask. Defaults, `--yes`, answer flag over `--yes`, `--quiet` keeps the answer line, a Required prompt with no answer stops (exit 13, no file). | red |
| L2 | `tests/commands/cases/prompt/nm-interactive-tty` | `TALON_INTERACTIVE=1` over `CI=true`, both TTYs. One tty call for 8 prompts. The ask text shows the default. A Consent prompt with `--yes` is asked. An empty reply is the default. | red |
| L2 | `tests/commands/cases/prompt/nr1-half-tty-is-not-interactive` | `TALON_INTERACTIVE=1`, stdin not a TTY: non-interactive, no ask, one tty call | red |
| L3 | `tests/scenarios/fx/hf-real-fx-jobs` | One line for each call of the real `Fx` with `fxprobe`: args, cwd, env (the fixed environment of the runner), read, write (tree diff), out, err, clock, tty with no terminal, ask at the end of input (TW4, R-HF1, R-EV18, R-EV22) | green |
| L3 | `tests/scenarios/fx/hf1-tty` (tag `tty`) | The real TTY test under a pseudo terminal: stdin and stderr apart. A prompt writes to stderr and reads stdin (R-HF1, R-NR1, R-NM2) | green |

Runner self-tests (`tests/selftest.sh`, 23 checks, green). A mutation of the runner makes the matching check fail (tested by hand: exit code, stdout, file tree and unexpected roc call).

| Runner | Must pass | Must fail |
| --- | --- | --- |
| L3 `tests/run.sh` | exit code, stdout and stderr, the fixed environment, the file tree (new, changed, removed file; `compat.db`, `tmp` and `*.tmp` left out), the fake `roc` (log, answers, exit 99 for an unknown call), tag `tty`, tag `slow` skipped, no network | wrong exit code, missing exit file for a nonzero exit, wrong stdout, extra stdout, wrong stderr, extra tree, wrong tree, missing tree, unexpected roc call, missing roc call, wrong roc arguments, roc call with no answer, tag `tty` with no terminal. `UPDATE=1` writes the files and then the case passes. |
| L2 `tests/commands/run.sh` | the fake `Fx` (`tests/selftest/commands/pass/harness/fake-fx`) | wrong exit, stdout, stderr, missing call, wrong call order, wrong tree, unknown entry |

Red output (`scripts/test.sh` with the stubs, 2026-10-18). Each red case fails for "todo":

| Layer | Output |
| --- | --- |
| L0 | `tests/unit/*.roc`: `Roc application crashed with this message: todo`, for 22 of 22 `expect`s |
| L2 | `[ROC CRASHED] todo` in all 3 cases ("the test app wrote no exit file") |
| L3 | `exit code differs (expected 2, actual 1)` and `stderr` `[ROC CRASHED] todo` in the 3 red cases. The 2 `fx/` cases pass. |

Check against the design: the tests were also run against a private reference implementation of all stubs (not kept, TW18). All 22 `expect`s and the 3 L2 and 3 L3 red cases passed with it. Mutations of it (Consent answered by `--yes`, tty not asked, answer line removed, exit code of a failure, `CI=1` missing, `--quiet` rule, `--file` rule) each made a test fail.

## Output (proposed, R-OUT2: human text and `data` fields)

These strings are fixed in the expected files. The human accepts or changes them at the review.

| Case | Text | Where |
| --- | --- | --- |
| Unknown command | `tln: error[usage]: unknown command 'frobnicate'` on stderr. With `--json`: the envelope with `command` `frobnicate` on stdout, `error.message` the same text. | `json/ec2-unknown-command-json`, `tests/unit/out.roc` |
| Bad flag | `tln: error[usage]: flag '<flag>' is not for '<command in long form>'` | `flags/fl12-bad-flags`, `tests/unit/args.roc` |
| Flag with no value | `tln: error[usage]: flag '--registry' needs a value` | `flags/fl12-bad-flags` |
| Required prompt, no answer | `tln: error[consent]: <subject> needs consent. Pass <flag> or <flag> or --yes.` (the flags of the prompt in order, then `--yes`, joined by ` or `) | `tests/unit/prompt.roc`, L2 cases |
| Picker with no person | A failure of kind `usage`. The message is not fixed. | `tests/unit/prompt.roc` (kind only) |
| Interactive prompt text | `<question> [Y/n] `, `<question> [y/N] `, `<question> [1-<count>, default <n>] ` | `tests/unit/prompt.roc`, L2 `nm-interactive-tty` |
| Typed reply | yes/no: `y`, `yes`, `n`, `no` in any case, with spaces cut. Options: the number. An empty line is the default. | `tests/unit/prompt.roc` |
| A known command (the P0 commands are not built) | `tln: error[internal]: command '<typed>' is not built yet`, exit 1. Proposal for the skeleton. No test names it: slice 007 replaces it. | `Run.run!` doc comment |
| JSON | One line, no spaces, keys in this order: `schema`, `command`, `ok`, `data`, `error`. In `error`: `kind`, `code`, `message`, then `details` when the failure has it. Text is escaped for `"`, `\`, newline and tab. | `tests/unit/out.roc` |
| Envelope `command` | The command words as typed: `add`, not `install` (the design example of `tln add` shows `"command": "add"`). Q3. | `tests/unit/args.roc` (`typed`) |
| Catalog rows | None. Slice 001 has no command with `data`. | |

Harness proposals (not in the design, from TESTING.md 3.1 and 3.2):

| Item | Proposal |
| --- | --- |
| `given/roc.tsv` | One rule for each line, 4 fields split by a TAB: argv glob, exit code, stdout file, stderr file (`-` for none). First match wins. No match: exit 99. Files are relative to the case work dir. |
| `expect/roc.log` | When it is missing, the case expects no `roc` call. |
| `$HOME`, `$PROJECT`, `$WORK` | In stdout and stderr, the dirs of the case are these words. |
| `tree.diff` | `diff -rNu` of `home/` and `project/` against the start state, no times. A dir or file named `tmp`, `compat.db` and `*.tmp` are left out. |
| Tag `tty` | The cmd runs under `tests/tools/ptyrun.py`. stdout and stderr are one stream in `expect/stdout`. `given/answers` is the typed text. |
| Tags `slow`, `windows`, `exdev`, `real-roc` | Not in the fast set. `REAL_ROC=1` runs `real-roc` cases with the pinned `roc`. |
| L2 case | `entry` (`run`, `prompt`, `harness`), `fx/` (the answers of the fake `Fx`), `given/`, `expect/{stdout,stderr,exit,calls.log,tree.diff}`. A `rules` file names the rule ids. |
| Network | `bwrap --unshare-net` when it works. Else the case runs with the network (no failure). |

## How to run

| Command | Does |
| --- | --- |
| `scripts/test.sh` | The fast set: check, fmt, L0, L2, L3, self-test. About 8 s. Exit 0 only when all pass. `scripts/test.sh l0` runs one step. |
| `tests/run.sh [filter]` | L3. `UPDATE=1` writes the expected files. |
| `tests/commands/run.sh [filter]` | L2 |
| `tests/selftest.sh` | The self-tests of the runners |
| `MISSING=1 scripts/rules.sh R-CM R-FL R-E R-EC R-J R-OUT R-NM R-NR R-HF R-EV` | Rules with no test. After this slice only R-EV10, R-OUT2 and R-OUT3 of the slice ids are missing (out of scope). |

## Out of scope

| Id | Reason |
| --- | --- |
| R-EV10 | `TALON_YES=1` is for the install script (CLI 6.5, R-IS4). `install/test.sh` tests it. |
| R-OUT2, R-OUT3 | Rules about the review and the catalog (the human accepts the proposals, the accepted rows go in the catalog). No test can check them. The catalog has no row from this slice. |
| R-FL13, R-FL14 | `--frozen` and `--dry-run` limits per command: slice 007 (the commands do not exist). |
| R-FL5, R-FL8 to R-FL11 (meaning) | The flags parse (A4, A5). What they do is in the slices of the commands. |
| The prompts of the table R-NI1 to R-NI16 | The prompt decision is a pure function (`Prompt.decide`) and `Prompt.ask!` is tested with made-up prompts. Each real prompt is tested in the slice of its command. |
| The `roc` proxy has no Talon flags (R-FL1), the TTY rule for Windows (R-NR1 exception) | P1, Windows CI |
| Color and progress output (R-EV9 effect) | Only the pure choice `Mode.color` is tested. No output uses color yet. |
| The fake HTTP server, `given/http` | Slice 003 |
| `scripts/revert-check.sh`, the container (TW9) | `TESTING.md` 8, items 5 and 6 |
| L1 (roc-fuzz) | No target yet. `scripts/test.sh` adds it with the first target. |

## Questions (stop until answered)

Each question has the default that the tests use. The code agent does not decide these. The tests that depend on a default are named.

| # | Question | Default in the tests | Depends |
| --- | --- | --- | --- |
| Q1 | The design says global flags work for every command, but not where on the line. Anywhere before a bare `--`? | Yes (A1). The manager's example `tln --json <unknown>` and the form `tln frobnicate --json` both give the envelope. | `tests/unit/args.roc` expects 2, 3 |
| Q2 | Does a flag with a value also take the form `--flag=value`? | Not tested. Only `--flag value` is tested. | |
| Q3 | The envelope `command` for an alias. The design example of `tln add` shows `"command": "add"`, but R-CM20 says no rule applies to one spelling only and R-CM19 says help and error text print the long form. As typed or long form? | As typed (the example). | `tests/unit/args.roc` expect 1 (`typed`), the `Run` code that gives it to `Out` |
| Q4 | An invalid reply and the end of input at an interactive prompt. R-NR1 (Windows) and R-SH11 say that the end of input gives the non-interactive answer. Is it so for every prompt? An invalid reply: ask again, take the default, or fail? | Not tested. `Prompt.ask!` has no rule for it: the code agent leaves it as an error value. | |
| Q5 | A `TALON_NOW` that does not parse (R-EV18). Exit code and message? `Clock.now` gives `BadTime(<text>)`. | Not tested at the command level. Proposal: usage failure, exit 2. | |
| Q6 | Does Talon print the answer line (R-NM6) for a Consent prompt that gets the answer No with no person (R-NM12)? R-NM6 says each answer with no prompt. R-NM12 says no answer is written. | Not tested. No L2 case has a Consent prompt in non-interactive mode. | |
| Q7 | `tln` with no command, `tln --help`, `tln --version`: output and exit code. The design names `--help` and `--version` (R-SH11) but gives no behavior. | Not tested. | |
| Q8 | `--file` with `init` and with `share`. R-FL6 and R-PD14 to R-PD16 do not name them. | Not tested. | |
| Q9 | `--platform` is a flag without a value for `install` (R-FL12: the ref is the platform) and a flag with a value for `init` (CLI 1). `Args.parse` needs the arity of each flag for each command. | Only `install` is tested (no value). | |
| Q10 | An unknown command is a usage failure (exit 2). R-EC2 lists "bad flag, bad ref" but not "unknown command". | Exit 2. Low risk: confirm in the table of R-EC2. | all `frobnicate` cases |
| Q11 | `TALON_INTERACTIVE` with a value other than `0` and `1` (R-NM2). | Not tested. Reference: as if not set. | |

## Decisions that the design does not fix (the test agent chose, for review)

| Decision | Options rejected |
| --- | --- |
| `Fx` has 10 calls (the table above). `tty!` gives both bits in one call, because R-HF1 runs one child for both. `env_all!` gives the whole environment, because the pure decisions get a `Dict`. | One call for each variable. A `tty!` that takes a stream (it would run the child twice). |
| `write_atomic!` and `read_files!` are in this slice because the L2 fake and `fxprobe` need a file effect. The temp name rule and the fsync rule are slice 002 (R-CC1, R-CC2). | Wait for slice 002: the L2 harness would have no write effect to test. |
| `Prompt.ask!` gets and gives the `mode`, so that `tty!` runs once in a command (R-HF1: once for each command). | A `Fx` that remembers the answer (a lambda cannot change state, `TESTING.md` 2.1). A tty call for each prompt. |
| `Run.run!` reads the environment only when a decision needs it. A failed parse needs only `args!` (not tested at L2 now, the L3 cases cover the output). | A fixed read of all inputs first. |
| Tables of cases live inside `expect` blocks. A top-level value that crashes on a stub makes `roc check` fail (compile-time evaluation). | Top-level tables. |
| The test of an error value uses text, not a record with a `Bool` (compiler crash, below). | |
| 22 L0 `expect`s (the budget is about 20): each is a table with many rows. | Fewer `expect`s with less reach. |

## Compiler limits found

| Limit | Evidence |
| --- | --- |
| `roc test` crashes with `Segmentation fault (SIGSEGV) in the Roc compiler. post-check monotype` when an `Err` value is a record that has a `Bool` field and it is compared with `==` after a `match` that maps it. `roc check` passes. | `research/roc-test-segfault/repro.roc`. A record with a `Str` field passes. |
| A top-level value is evaluated at compile time. A stub that crashes makes `roc check` fail, not only `roc test`. | `tests/unit/kind.roc` header comment |
| `roc test` shows only the source of a failed `expect`, not the values. The tables print the wrong rows with `dbg`. | `tests/unit/*.roc` |

## Review (manager, 2026-10-18)

The manager accepted the tests and the output proposals. The answers below are the manager's proposals. The user did not confirm them yet. The code agent follows them.

| # | Answer |
| --- | --- |
| Q1 | Yes: a global flag can be anywhere before a bare `--`. |
| Q2 | Both forms: `--flag value` and `--flag=value`. No new test. |
| Q3 | As typed (the design example). |
| Q4 | An invalid reply asks again. The end of input gives the non-interactive answer (as R-NR1 for Windows). |
| Q5 | A usage failure, exit 2. The message names `TALON_NOW` and the text. |
| Q6 | No answer line (R-NM12 wins). The Required error names the flags. |
| Q7 | `tln --help` and `tln help`: usage text on stdout, exit 0. `tln` with no command: the same usage text on stderr, exit 2. `tln --version`: `tln <version>` on stdout, exit 0. No new test needed, but one L3 case for each is welcome. |
| Q8 | Open. `init` and `share` are P1 and P2: not in this slice. |
| Q9 | Yes: the arity is per command, as the slice says. |
| Q10 | Exit 2. |
| Q11 | As if not set. |
| `scripts/rules.sh` | The change is accepted: only `tests/` and `packages/` count. |

## Disputes (from the code agent)

None. No test, fixture or expected file of the slice was changed. Three L3 cases were added (Q7, see "Code agent results").

## Code agent results

Result of `scripts/test.sh` for slice 001 alone: check, fmt, L0 (22 of 22 `expect`s), L2 (3 of 3 cases), L3 (8 of 8 cases: the 5 old ones and 3 new), self-test (23 checks): all pass, about 12 s. Slice 004 files (written at the same time by another agent) are in the same tree: with them `scripts/test.sh` is red for slice 004 only (its L0 and its L3 case `refs/sl-bad-refs`). The revert check below ran on a copy of the tree without the slice 004 files.

Files written (lines): `cli/lib/Kind.roc` 45, `Fail.roc` 18, `Exit.roc` 16, `JsonDoc.roc` 40, `Out.roc` 61, `Mode.roc` 47, `Prompt.roc` 147, `Args.roc` 266, `Clock.roc` 68, `Run.roc` 50, `Help.roc` 62 (new module, in the exposes list of `cli/lib/main.roc`). New L3 cases: `tests/scenarios/help/q7-help`, `q7-version`, `q7-no-command`.

| Decision (the slice does not fix it) | Options rejected |
| --- | --- |
| New module `Help`: `route` (pure, picks help, version or a command), `usage`, `version`. `--help` or `help` as the first word is help. Both are read only before a bare `--`. | Put it in `Run` (not testable as a pure function). Help in `Args` (a new field). |
| `Help.version` is `0.0.0`: the design has no source for the version of `tln` (Q12 below). | A build-time value (not possible without a build step). |
| `tln` with only global flags has `command = []` in `Args.parse` (Ok). `Run` prints the usage with exit 2. | A usage failure from `Args.parse`. |
| Messages beyond A8, all kind `usage`: `command 'tool' needs a subcommand` (`tool`, `roc`, `cache` with no second word), `flag '--x' needs a command` (a non-global flag with no command), `flag '--json' takes no value` (`--flag=value` for a flag with no value). | A fixed `unknown command` for all. |
| `--platform` has a value only when the command is `init` at the moment of the flag. `tln --platform x init` is not parsed as a value. | A second pass to find the command first. |
| A word after a value flag that looks like a flag (`--registry --json`) is not a value: `needs a value`. | Take any next word as the value. |
| Flags that the slice file does not list per command, from the CLI 1 commands table: `--undo` (`yank`, `move`), `--reason` (`yank`), `--to` (`move`), `--ignore` (`audit`). `--probe-downloads`: the resolve commands and `probe`. `--allow-downloads`: the same and `roc use`. `--no-check` for `verify` (A5). | Reject them until their slice. |
| `--file` for `init` and `share` is rejected (Q8 is open). | Accept. |
| `Prompt.ask!` after the end of input gives mode `NonInteractive` for the next prompts. A Consent prompt with an answer flag prints the answer line. Without a flag it gets No and no line (Q6). | Keep the mode. |
| `Run.run!` does not call `Clock.now` and does not read `env_all!` yet: no command needs them (Q5 is for the first command that uses time). | Read them at the start. |
| `JsonDoc` escapes also `\r` and the other control characters (below 32) as `\u00XX`. | Only the four named in the test. |

Questions (TW17):

| # | Question |
| --- | --- |
| Q12 | The version text of `tln --version`. The code has `0.0.0`. Where does the version come from (release tag, a file)? The install scripts read `tln <version>` (R-IS5). |
| Q13 | Q7 says `tln` with no command prints the usage on stderr with exit 2. R-E4 says that a Talon failure ends stderr with `tln: error[<kind>]: <message>`. The code follows Q7: no error line. Add the line `tln: error[usage]: no command` after the usage? |

## Verify results

Method: a copy of the tree with the slice 001 files only (the slice 004 agent worked in the real tree at the same time). Each mutation changes one small place, then `scripts/test.sh check l0 l2 l3` runs. A mutation that only made `roc check` fail (a warning) was done again in a form that compiles. After the run, `cli/lib` was compared with the saved copy (`diff -r`): the same. The real tree was also compared (only `cli/lib/main.roc` differs, by the slice 004 edit).

Caught: 96 of 105 mutations (the table has each id group with its first test). Not caught: 9.

| Rule ids | Mutation | Caught by |
| --- | --- | --- |
| R-CM19, R-CM20 | `rm` not mapped, `add` not mapped, sub-word alias not mapped | `unit/args.roc` (1), `flags/fl12-bad-flags` |
| R-FL1 | `--json` read only at the end, `--json` allowed for `x`, `json` false on failure, `--json` allowed after wrong place | `unit/args.roc` (2, 3), `json/ec2-unknown-command-json` |
| R-FL2, R-FL3, R-FL4, R-FL5, R-FL6 | the global flag is not set (`--yes`, `--offline`, `--quiet`, `--registry`, `--file` value) | `unit/args.roc` (2) |
| R-FL6, R-FL7, R-FL12 | `--file` for `cache gc`, a resolve flag for `list`, `--slots` for `why`, `--tree` for all, every flag allowed | `unit/args.roc` (3), `flags/fl12-bad-flags` |
| R-CM12 | passthrough dropped | `unit/args.roc` (2) |
| R-EC2 | an unknown command is accepted | `unit/args.roc` (3), `errors/e3-quiet-keeps-error`, `json/ec2-unknown-command-json` |
| R-E1, R-E2 | max in place of min, child code dropped, `Done` counted | `unit/kind.roc` (2) |
| R-E4 | `tln: err[` in `Fail.line` | `unit/kind.roc` (3), `unit/out.roc`, 5 L2 and L3 cases |
| R-E5, R-EC0, R-EC2, R-EC10, R-EC13, R-EC21 | a code twice, a wrong code, a wrong name | `unit/kind.roc` (1), L2 and L3 cases |
| R-J1 | `, ` separator, no escape of newline, quote or backslash, key order of an object | `unit/out.roc` (1) |
| R-J1 to R-J5, R-OUT4, R-OUT5 | key order of the envelope, `schema` 2, `error` not null on success, `data` not null on failure, no `details`, no `code`, stdout with no `--json`, no envelope with `--json`, no stderr line with `--json` | `unit/out.roc` (2, 3), `json/ec2-unknown-command-json`, `errors/e3-quiet-keeps-error` |
| R-FL4 (R-E3) | `--quiet` hides Info wrongly, hides Error, hides Answer | `unit/out.roc` (4), `prompt/nm-noninteractive-ci` |
| R-NM1, R-NM2, R-EV1, R-EV8 | `CI` case, `CI=1`, `DEBIAN_FRONTEND`, `NONINTERACTIVE`, `--json`, `TALON_INTERACTIVE` 1 and 0, `--json` over `TALON_INTERACTIVE` | `unit/mode.roc` (1) |
| R-NR1, R-HF1 | `or` in place of `and`, stdin only, NonInteractive becomes Interactive | `unit/mode.roc` (2), `prompt/nr1-half-tty-is-not-interactive` |
| R-EV9 | `NO_COLOR` ignored, TTY ignored | `unit/mode.roc` (3) |
| R-EV18 | month 13, day above the month, the time of day dropped | `unit/clock.roc` (1) |
| R-EV22 | `TALON_NOW` ignored, real time wrong | `unit/clock.roc` (2) |
| R-NM3 to R-NM5, R-NM8 to R-NM12, R-NR5, R-NR6 | flag under `--yes`, flag ignored, `--yes` gives the default, option default, `--yes` answers Consent, Consent gets Yes, Default gets Yes, a Required prompt does not stop, a wrong stop kind, flags missing in the message, a wrong separator | `unit/prompt.roc` (1, 2), `prompt/nm-noninteractive-ci`, `prompt/nm-interactive-tty` |
| R-NM2, R-HF1 | Interactive does not ask, NeedsTty does not test the TTY, the mode is lost after an answer (a second `tty` call) | `unit/prompt.roc` (3), `prompt/nm-interactive-tty`, `prompt/nr1-half-tty-is-not-interactive` |
| R-NM6, R-FL4 | no answer line, `--quiet` hides it | `prompt/nm-interactive-tty`, `prompt/nm-noninteractive-ci` |
| R-NM7 | the picker runs with no person, a wrong kind | `unit/prompt.roc` (4) |
| R-NR2 | the default not shown, wrong options text, empty reply not the default, case, trim, range of the number | `unit/prompt.roc` (5), `prompt/nm-interactive-tty` |
| Q7 | help flag, help word, version text, the code and the stream of no command and of help | the 3 new L3 cases |
| R-FL12, R-E3, R-J1, R-E4 (in `Run`) | exit code of a failure, stdout of the envelope, stderr line | `errors/e3-quiet-keeps-error`, `flags/fl12-bad-flags`, `json/ec2-unknown-command-json` |

Not caught:

| # | Rule or question | Mutation | Why no test fails |
| --- | --- | --- | --- |
| 1 | R-FL1 (A9) | `json` also read after a bare `--` for a failure | No test has a failure and `--json` after `--` |
| 2 | R-FL12 (A4) | a word that looks like a flag is taken as a value (`--registry --json`) | No test has a flag with no value before another flag |
| 3 | R-EV18 | the `Z` mark at byte 19 not checked | Each bad text in the test is caught by another check (the length) |
| 4 | R-EV18 | the 100 and 400 year rule of the leap year | The test has `2024-02-29` and no year `2000` or `2100` |
| 5 | Q6, R-NM12 | a Consent prompt with no answer prints an answer line | No L2 case has a Consent prompt in non-interactive mode |
| 6 | Q4 | an invalid reply takes the default (it must ask again) | No test has an invalid reply at the interactive prompt |
| 7 | Q4 | the end of input at an interactive prompt keeps the mode | No test has the end of input at a prompt |
| 8 | R-EC1 | the kind of "is not built yet" is `usage` | The text is a proposal and no test names it |
| 9 | R-EC1 | the text "is not built yet" | The same |

## Review of the code (manager, 2026-10-18)

| # | Answer |
| --- | --- |
| Code Q12 | `tln --version` prints a constant of the code. It stays `0.0.0` until the first release (CLI 6.5). |
| Code Q13 | Yes. `tln` with no command prints the usage on stderr, then `tln: error[usage]: no command` as the last line (R-E4). The slice 004 code agent makes this change and updates `tests/scenarios/help/q7-no-command`. |
| Not caught 1 to 9 | Accepted. 5 to 7 get a test when a command has a real Consent prompt (P1). 8 and 9 go away in slice 007. |

Status: done (2026-10-18).
