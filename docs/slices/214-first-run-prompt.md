# 214 First-run prompt

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Plan row 214 of `PLAN-P2-CLI.md`. The prompt R-NI16 before the work of the first interactive command, the skip cases of R-SH11, a Consent prompt that `--yes` does not answer (R-NM12), and the end of input that writes nothing. No network, no queue (215), no send (216).

## Rules

R-SH11, R-NI16, R-NM12 (also named in the tests: R-SH1, R-SH2 rows 2, 4 and 5, R-SH5, R-SE15, R-NM1, R-NM2, R-NM8, R-NM10, R-HF1, R-NR1, R-LY3, R-CC6).

Design: CLI 1 (R-SH1, R-SH2, R-SH5, R-SH11), CLI 4 (R-NM1, R-NM2, R-NM12, R-NI16).

## Public signatures (stubs, `crash "todo: slice 214"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `FirstRun.Why` | `[Command, NonInteractive, DoNotTrack, Ci, Set, Direct]`: why a command does not ask | R-SH11 |
| `FirstRun.of_command` | `List(Str) -> [Skip(Why), Check]`: step 0, from `Args.command` only: `share` (any word) and `setup` give `Skip(Command)` | R-SH11 rows 1, 2 |
| `FirstRun.gate` | `{ env, json } -> [Skip(Why), NeedTty]`: step 1: `Mode.from_env` is `NonInteractive`, then the `DO_NOT_TRACK` condition, then the `CI` condition of R-SH2 | R-NM1, R-NM2, R-SH11 row 5, R-SH2 rows 4, 5 |
| `FirstRun.need` | `{ share, registry } -> [Skip(Why), Ask]`: step 2: `share` set gives `Skip(Set)`, a `Direct` registry gives `Skip(Direct)`, else `Ask` | R-SH11 |
| `FirstRun.written` | `{ answer, mode } -> [Write(Bool), Nothing]`: the mode that comes back from `Prompt.ask!` is `NonInteractive` (end of input) gives `Nothing` | R-SH11, R-NM12 |
| `FirstRun.prompt` | `{} -> Prompt`: kind `Consent`, yes/no, default No, id `share`, the text below | R-NI16, R-NM12 |
| `FirstRunFlow.before!` | `Fx, Args => Try(Fx, Fail)`. The steps and the calls are in its doc. | R-SH11 |

Edits to existing files (copies in `research/slice-214-revert/before/`): `cli/lib/main.roc` (2 exposes), `tests/unit/ShareTest.roc` (3 new `expect`s and 4 imports), `docs/slices/PLAN-P2-CLI.md` (status), and 113 expected `calls.log` files of L2 cases (see "Existing cases"). The stubs do not call `Run.roc`: the code agent adds the call.

## Steps of the command code (R-SH11)

Place: `Run.tln!`, after `Args.parse` and `check_refs` gave no failure, before the dispatch. A parse failure and a usage failure never ask. `Help.route` ends `--help`, `--version` and `help` before it. The `roc` proxy path of `Run.run!` never reaches it.

| Step | Does | Calls in `calls.log` |
| --- | --- | --- |
| 0 | `FirstRun.of_command`. `Skip`: stop. | none (so `tln share` and `tln setup` keep their `calls.log`) |
| 1 | `env_all`, `FirstRun.gate`. `Skip`: stop. | `env_all` |
| 2 | `tty` once, `Mode.with_tty`. Not `Interactive`: stop. The `Fx` that goes on has `tty!` fixed to this answer (`{ ..fx, tty!: || tty }`, as `Common.shown_fx` fixes `out!`), so a later prompt of the command makes no second `tty` call (R-HF1). | `tty` |
| 3 | `config.toml`: `Share.setting`, `Net.registry`. A failure of the setting stops the command (R-TF4). | `read_files <config.toml>` |
| 4 | `FirstRun.need`. `Skip`: stop. | none |
| 5 | `Prompt.ask!` with mode `Interactive`, `yes: args.yes`, `flag: Err(NoFlag)`. No answer line and no more text. | `ask "<text>"` |
| 6 | `FirstRun.written`. `Write(v)`: the edit of `config.toml` under its lock (`share = v`), and for true also `share.json` under its lock (id, `chmod 0600`): the steps 2 and 3 of `ShareFlow.on!`. `Nothing`: no call. | as `share on` |

The reference of the test agent exposes `ShareFlow.set_share!` and `ShareFlow.ensure_id!` for steps 6. The code agent may choose another way.

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ShareTest.roc` (driver `l0-8.roc`), expect 9: `of_command` (5 Check, 4 Skip) and `gate` (`--json`, `CI` true, TRUE and 1, `DEBIAN_FRONTEND`, `NONINTERACTIVE`, `TALON_INTERACTIVE` 0 and 1, `DO_NOT_TRACK` 1, true, empty and 0, `CI` false and 0, `CI` with `TALON_INTERACTIVE=1`, the order of the checks, `TALON_REGISTRY` ignored) | R-SH11, R-NM1, R-NM2, R-NM12, R-SH2 |
| L0 | expect 10: `need` (5 rows) and `written` (5 rows: Yes, No, end of input, Option) | R-SH11, R-SH1, R-NM12 |
| L0 | expect 11: the prompt fields (Consent, yes/no, default No) and its exact text, `Prompt.decide`: `--yes` with a person still gives `Ask`, no person gives `Use(No)` | R-NI16, R-NM12, R-NM10 |
| L2 | `tests/commands/cases/share/sh4-first-run`: a person is there (`tty` true, `TALON_INTERACTIVE=1`), registry URL. 7 runs of `cache dir`: `y` (writes `share = true`, comment stays, makes `share.json` with the `chmod`); a second run (set: no ask); Enter (default No: writes `share = false`, no `share.json`); `--yes` (still asked, answer `n`); `--offline` (asked, answer `no`); end of input twice (no write, asked again). One `tty` call and the prompt before the output of each run. | R-SH11, R-NI16, R-NM12, R-NM10, R-SH1, R-SH5, R-LY3, R-CC6, R-HF1, R-SE15 |
| L2 | `tests/commands/cases/share/sh5-first-skips`: the same world, share not set, no answers. `share`, `setup`, `@roc`, `--version`, registry `direct`, `DO_NOT_TRACK=1`, `CI=true` with `TALON_INTERACTIVE=1`, `--json`, `TALON_INTERACTIVE=0`, `CI=true` with `TALON_INTERACTIVE=0`: no `ask` and no write. The calls show where each run stops (none, `env_all`, `tty`, config read). | R-SH11, R-SH2, R-NM1, R-NM2, R-NM12 |
| L3 | `tests/scenarios/share/fr1-first-run-tty` (tag `tty`): the real terminal and the real `Fx`. Answer `y`: the screen shows the prompt before the cache root, `config.toml` has `share = true`, `share.json` has the mode `-rw-------`, the id has 32 hex digits (the case fixes it, so the tree diff is stable). The second run does not ask. | R-SH11, R-NI16, R-SH5, R-SE15, R-HF1, R-NR1 |

Why the skip cases are not all asked in L0: `Direct` and `Set` are in `need` (L0 and L2), the other skips are in `of_command` and `gate` (L0 and L2). The condition 3 of R-SH2 (`--offline`) is not a skip: the L2 case `sh4-first-run` runs it and the prompt shows.

## Output (proposed, TW24)

The prompt (R-NI16). The text of `Prompt.text` is the question, `[y/N]` and a space. No answer line is printed after an asked prompt, and nothing is printed after the write (as the other asked prompts).

```
Talon can share the results of its probes with the registry.
For a public package it sends the hash of the package, the compiler, the target, the Talon version and the result (pass, fail or crash). It sends no code, no path and no error text.
The registry keeps each result with a random id of this machine until you run tln share forget, or until its compiler is 12 months old.
Reading compatibility data does not need sharing.
You can turn sharing off at any time with tln share off.
Share the probe results of public packages? [y/N]
```

## Readings that the design implies (tested)

| # | Reading |
| --- | --- |
| 1 | R-SH11 says "asks before it does its work": the prompt comes before the first call of the command (the L2 logs show the hook lines first). |
| 2 | R-SH5 says that the id is made "the first time that sharing turns on". The answer Yes turns it on, so it also makes `share.json` (step 6). The answer No writes `share = false` only (D5 of slice 213: the same as `share off`, without the queue). |
| 3 | R-SH11 lists the conditions 2, 4 and 5 of R-SH2 only. `--offline` (3) and the setting are not skips: with `--offline` Talon asks. |
| 4 | R-NM1, R-NM2: a non-interactive mode (also `--json`) never asks and writes nothing (R-NM12: the answer is No and nothing is written). A usage failure and `--help` do not run the command, so they do not ask. |
| 5 | R-HF1: the `tty` test runs once for a whole command, so the hook passes its answer on. |
| 6 | The answer Enter is the default No (R-NI16): it is an answer, so `share = false` is written. Only the end of input writes nothing. |

## Existing cases (the world default)

The design does not allow a world with no `Fx` call for the hook: each interactive-capable command now calls `env_all`, and `tty` or a config read, before its work. A test world default cannot hide this, because `calls.log` has each call. What does not change: `stdout`, `stderr`, the exit code and the file tree of each old case (the default registry is `direct`, so no old case asks; `tln share` and `tln setup` make no new call).

| What | Count |
| --- | --- |
| Old L2 cases whose expected `calls.log` I changed (only added lines: `env_all`, `tty`, `read_files <home>/.config/talon/config.toml`; a `tty` line moves up to the first position) | 113 |
| Old cases that pass now and need the same change in the code step: `tool/*`, `gc/gc6-prebuilt-entries` (cases of slices 092 and 093 and of the other test agent) | 56 (55 in `tool/*`, `gc6`). With the 17 failing `ptool/*` cases the list has 74 names: `research/slice-214-revert/OTHER-CASES.txt` |
| L3 cases | none change (the runner sets `CI=true`: no prompt) |

How the 113 files were made: the private reference was installed, `UPDATE=1 tests/commands/run.sh <case>` for each failing case, and `diff` against the old files showed only these added lines. The same step for these cases: after the other agent ends its work, install the reference (or the code), run `UPDATE=1 tests/commands/run.sh tool/ ptool/ gc/gc6`, and check that `diff` shows only the lines above.

The red state: 113 old cases and 2 new cases fail (the hook is not there). The 17 `ptool/*` cases fail already (the other agent).

## Out of scope

| Item | Reason |
| --- | --- |
| The answer line of `FirstRun.prompt` | A Consent prompt with no flag never shows it (R-NM12). Not tested. |
| An invalid reply (asks again) | `Prompt.ask!` does it for each prompt (`prompt/nm-interactive-tty`). |
| `tln run` steps that call `tln` in the same process | Question Q1. |
| R-SH2 for the queue (when a fact goes in), R-SH3, send | Slices 215, 216. |
| The proxy line of `sh5-first-skips` (`@roc --version`) | It shows that the proxy asks nothing, but its own calls are noisy (a compiler search with a 404). Its expected lines change when the proxy changes. |

## Questions (stop until answered)

| # | Question | Proposal | State |
| --- | --- | --- | --- |
| Q1 | `tln run` runs steps that are `tln` commands in the same process (`RunFlow.run!` calls `Run.tln!`). With the hook in `Run.tln!`, a step can ask again after the end of input, because nothing was written. R-SH11 says "the first command". | The hook runs once for each process: the inner call skips it. The code agent keeps the inner call as it is until the answer. | Open: design gap G-C35 (design agent). No test. |
| Q2 | A config with `share = 3` (wrong type) now stops each interactive command with exit 19 (R-TF4) at step 3, also a command that does not read the setting. | Accept: the file is wrong, and the command reads `config.toml` anyway. | Answered (manager reading: a bad config file is exit 19 everywhere today). No new test. |
| Q3 | The write after Yes: when `share.json` exists but is damaged, the command stops with exit 19 (as `share on`). | As `share on`. | Answered (manager reading, as Q2). No new test. |

## Disputes (from the code agent)

None.

Code agent notes: `ShareFlow.record!(fx, roots, value)` is new and public (the steps 2 and 3 of `on!`, or the step 2 of `off!` without the queue). `Run.tln!` now calls `dispatch!` (a private function with the old if-chain) after `FirstRunFlow.before!`. No revert check was run by the code agent (the test agent's 6 mutations stay).

## Verify results

Red result (2026-11-02, test agent), stubs installed:

| Check | Result |
| --- | --- |
| `roc test tests/unit/l0-8.roc` | 3 `expect`s of `ShareTest.roc` fail with `todo: slice 214` (log `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red-l0.log` is the first run) |
| `tests/commands/run.sh` | 123 pass, 132 fail: 113 old (hook lines missing), 2 new (no prompt), 17 `ptool/*` (other agent) |
| `tests/run.sh share/fr1` | fails: no prompt, so the answer `y` is not read (the screen and the files differ) |
| `roc check` of `cli/lib/main.roc`, `cli/main.roc`, `tests/commands/main.roc`; `roc fmt --check` of the new and changed files | 0 errors, exit 0 |

With the private reference (`research/slice-214-revert/reference/cli/lib/`): 3 L0 `expect`s, `sh4`, `sh5`, `fr1`, and the 113 updated cases pass; the whole L3 fast set passes (90 passed, 3 skipped).

Mutations of the reference (6, the most tricky behaviors):

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `written`: the end of input writes `false` | L0 expect 10, L2 `sh4-first-run` |
| M2 | the prompt kind is `Default` (so `--yes` answers it) | L0 expect 11, L2 `sh4-first-run` |
| M3 | `of_command`: `setup` is not a skip | L0 expect 9, L2 `sh5-first-skips` |
| M4 | no fixed `tty!` (a second `tty` call in a command with a prompt) | old L2 `moves/hm2-interactive` |
| M7 | the answer Yes does not make `share.json` | L2 `sh4-first-run` (L0 has no row for it) |
| M9 | `need`: a `Direct` registry still asks | L2 `sh5-first-skips`, `moves/hm2-interactive` |

M7 was run with L0 and L2 only. M4 is caught by the old interactive cases, not by the new ones (the new cases run `cache dir`, which makes no prompt of its own).

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo: slice 214"` | None |
| Tests of this slice | 3 ShareTest expects, `share/sh4-first-run`, `share/sh5-first-skips`, the 113 old cases with hook lines, L3 `share/fr1-first-run-tty`: all pass (code agent run). |
| Hook lines in other cases | 44 plain `tool/*` cases updated by the test agent (additive only, all pass). The 11 Windows `tool/*` cases get the hook lines in slice 088f (with the R-LY10 test world fix). `ptool/*` and `gc/gc6` get them in slices 092 and 093. |
| Revert check | Test step: M1, M2, M3, M4, M7 and M9 caught. |
| Follow-up | 213b: Q215 (`TALON_SHARE_ASKED`, once per process tree, also for the in-process `tln run` step), Q213. |
