# 236 tln version gate

Phase: P2. Status: done (TW24 texts wait for the user review)

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-TF10 (Design Q607, Q610 = G-C240) | `[toolchain] tln = "<semver range>"` in the root `talon.toml`. A person writes it, Talon never writes it. Each command that reads `talon.toml`, and the `roc` proxy, checks it first. This tln outside the range: exit 19 and `this project needs tln <range>, this is tln <version>. Run: tln tool update talon`. A range that does not parse: exit 19 as R-TF4. In a workspace only the root file counts. |
| R-TF4, R-TF8, R-EC19 (Design Q609) | A range that does not parse, or a value that is not a string, is a fault of the value of a known key: exit 19 with the hint line `A newer tln may know this value. Update tln: tln tool update talon` (`Fail.newer_hint`, `Fail.with_hint`). |
| R-WS5 (Design 4.4) | Only the root file holds `[toolchain]`. A member file with a `[toolchain]` table is exit 19 already (the table is not allowed). So a key `tln` in a member file never reaches the gate. |
| R-PX5, R-PX2 | The proxy reads the `talon.toml` of the target file (the early read). The gate runs in that read. |
| R-RUN12 | `tln run` reads `talon.toml` with `ScriptsToml.read`, not with `Intent.read`. The gate must run there too. |

Source: research/cli-format-audit/PLAN.md (F3, the user decision of 2026-11-08), row 236 of docs/slices/PLAN-P2-CLI.md.

## Scope

Facts found in the code (before any change):

| Question | Answer | Where |
| --- | --- | --- |
| Is the key known today? | No. `[toolchain]` has the known keys `roc` and `nightly`. `tln` is an unknown key: a warning `unknown key toolchain.tln`, no gate. | cli/lib/Intent.roc:348 |
| How is the version of the running tln known? | The constant `Help.version` (`"0.0.1"`). `tln --version` prints it (cli/lib/Run.roc:79). The User-Agent and the share rows use it. | cli/lib/Help.roc:6 |
| Can an L2 test set the version? | No. It is a constant, not an `Fx` call and not an environment variable. L2 cases use ranges that hold for each version below 999.0.0 (`>=0.0.1` inside, `>=999.0.0` outside). The expected texts hold `0.0.1` (L0 reads `Help.version`). A release that bumps `Help.version` changes the L2 expected files. | cli/lib/Help.roc:6 |
| The range parser | `Ranges.check : Str -> Try({}, [BadRange])` and `Ranges.admits : { ranges, version } -> Bool`, on `VersionReq` of `roc-semver`. Syntax: `^2.1`, `~1.2`, `=2.0.0`, `0.25.*`, `*`, `>=1.2, <1.5`, `2`. Not: `latest`, the empty text, `^`, `1.2.3.4`. `admits` never admits a pre-release version. | cli/lib/Ranges.roc:20, :29 |
| Where is `talon.toml` read? | `Intent.read` (one function: `Base`, `ResolveLoad`, `PathFlow`, `ToolsFlow`, so each project command and the proxy). Other readers: `ScriptsToml.read` (`tln run`), `RunEach.read_after`, `RunTools`, `ToolsPlan`, `Removal.keys_of`, `Project.workspace_of`. The L2 run case shows that `run` has no `Intent.read` call. | cli/lib/Intent.roc:102, cli/lib/ScriptsToml.roc:57 |
| Does a write path of `talon.toml` drop or add the key? | No. `IntentEdit` (`apply`, `rename`, `remove`, `add_patch`) edits spans of `[dependencies]` and `[patch]` only, and no template (`tln init`) writes `[toolchain]`. L0 guards this. | cli/lib/IntentEdit.roc, cli/lib/InitText.roc |
| Order of the project record step | In `install` and in the proxy the record step (`projects.json`) runs before the read of `talon.toml` that fails. In `run` the failure of the file read comes before the record step. The expected files of the red cases keep these orders. | see the cases |

Commands that read no `talon.toml` are not gated, as R-TF10 says: `--version`, `--help`, `tool update talon`, `setup`, `cache`, `path`, `tool list`. See Open Q1 and Q2.

Out of scope: a way to write the key (R-TF10: Talon never writes it), a `tln` key in `config.toml`, `format` numbers.

## Tests

| Layer | Test | Rules | State now |
| --- | --- | --- | --- |
| L0 | tests/unit/TlngateTest.roc, expect 1: ranges that admit this tln (`*`, `>=0.0.1`, `>=0.0.1, <999.0.0`, `<999.0.0`) read with no failure and no warning. | R-TF10 R-TF4 | red: the warning `unknown key toolchain.tln` |
| L0 | expect 2: ranges that do not admit this tln (`>=999.0.0`, `<0.0.1`, `^999.1`, `=999.0.0`), role Standalone and Root, give exit 19 and the text of R-TF10 with the path and the line of the key. | R-TF10 R-EC19 | red: no failure |
| L0 | expect 3: a range that does not parse (`banana`, empty, `^`, `1.2.3.4`, `latest`) gives exit 19, `toolchain.tln: '<text>' is not a version range` and the hint line. | R-TF10 R-TF4 R-TF8 | red: warning only |
| L0 | expect 4: `tln = 5` gives `toolchain.tln: must be a string` and the hint line. | R-TF10 R-TF4 R-TF8 | red: warning only |
| L0 | expect 5: no key (a `[toolchain]` with `roc` or `nightly`, other tables, the empty text): no failure, no warning. | R-TF10 | green (guard) |
| L0 | expect 6: `roc`, `nightly` and `tln` in one table: `roc` and `nightly` read as before, no warning. | R-TF10 | red: the warning |
| L0 | expect 7: the gate fails and the file has another fault (a bad `strategy`, a bad dependency range, a table of `[run]` in the root file): the gate message wins ("checks it first"). | R-TF10 | red: the other fault shows |
| L0 | expect 8: role Member with the key (outside and inside the range): the failure is the R-WS5 table failure, with no word of the gate. | R-TF10 R-WS5 | green (guard) |
| L0 | expect 9: `Intent.apply`, `rename` and `remove` keep the `tln` line and its comment, and `apply` adds no `tln` to a text without it or to the empty text. | R-TF10 | green (guard, no write path exists) |
| L0 | tests/unit/TlngatepureTest.roc: `TlnGate.check` (pure, takes the version). Pre-release `0.4.0-rc.1` (and `0.4.0-rc.1+build.5`) counts as `0.4.0`: inside `>=0.4.0`, `^0.4`, `=0.4.0`; outside `>=0.4.1`, `<0.4.0`. Release versions, range edges, `banana` and the empty text give `BadRange`. | R-TF10 | red: `TlnGate` does not exist (compile error, on purpose) |
| L2 | tests/commands/cases/gate/tf10-install: `install --frozen` of 9 projects: inside, outside, `banana`, `5`, `[toolchain]` with no key, outside with a bad `strategy`, workspace root outside, workspace root inside, member file with the key. | R-TF10 R-TF4 R-TF8 R-EC19 R-WS5 | red: outside, `banana`, `5`, `both` and `wout` runs go on (exit 0) and the warning shows. The `wmem` and `none` runs are green. |
| L2 | tests/commands/cases/gate/tf10-proxy: `roc` proxy with the project: inside (rank 1, the compiler runs), outside with rank 1 and rank 3, `banana`, workspace root outside and inside. | R-TF10 R-PX5 R-WS5 | red: the outside runs reach `exec` |
| L2 | tests/commands/cases/gate/tf10-run: `tln run hi`: inside, outside, `banana`, workspace root outside. | R-TF10 R-RUN12 R-WS5 | red: the step runs (exit 0) |
| L2 | tests/commands/cases/gate/tf10-update-talon: `tool update talon` with a `talon.toml` outside the range in the directory of the run. It is the case `tool/th3-self-update-bad-config` plus that file. | R-TF10 R-TF8 | green (guard: the fix of the message is never gated) |

Result of the runs (before any code change):

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` (driver with TlngateTest, BotTest, NewerhintTest) | 37 tests, 31 pass, 6 fail (expects 1, 2, 3, 4, 6, 7 of TlngateTest). 0 compiler errors: the test file calls no new name. |
| `tests/commands/run.sh tf10` | `tf10-install`, `tf10-proxy`, `tf10-run` fail, only on the rows named above. `tf10-update-talon` passes. |
| `tests/commands/run.sh` (all) | 561 old cases pass. The 3 new red cases fail. |
| `scripts/test.sh selftest` | pass |

I added `import TlngateTest` to tests/unit/l0-9.roc (no new driver).

### Mutation check (TW12)

The code agent runs these after the code is green. The guard rows (green now) cannot be proved here by a revert.

| Id | Mutation (after the code is green) | Caught by |
| --- | --- | --- |
| m1 | The gate compares with `>` in place of `>=` at the edge, or treats an outside range as inside | TlngateTest expects 1 and 2, tf10-install `out` |
| m2 | The gate is removed from `Intent.read` | TlngateTest expect 2, tf10-install, tf10-proxy |
| m3 | The gate is removed from `tln run` | tf10-run |
| m4 | The gate is removed from the proxy read only (Base.roc:356, :380) | tf10-proxy |
| m5 | The gate runs after the other checks of the file | TlngateTest expect 7, tf10-install `both` |
| m6 | The gate reads the key of a member file | TlngateTest expect 8, tf10-install `wmem` |
| m7 | A bad range gives no hint line | TlngateTest expect 3 and 4, tf10-install `bad` and `num` |
| m8 | `tool update talon` reads the `talon.toml` of the directory | tf10-update-talon |
| m9 | `IntentEdit.apply` writes or drops `tln` | TlngateTest expect 9 |

## Changed expectations

None. No existing case or test changes. The new cases are new directories, and TlngateTest is a new file.

## Code proposal

| Item | Proposal |
| --- | --- |
| Known key | `Intent.read_toolchain` reads `tln` as a string (checked with `Ranges.check`). `unknown_keys` gets `"tln"` in its list of known keys (cli/lib/Intent.roc:348). The value goes in the `toolchain` record as `tln : Try(Str, [Unset])` (the text), or in a new `Scan` field. The key is read for the roles Standalone and Root. |
| The check | A pure function in a new module `cli/lib/TlnGate.roc`: `TlnGate.check : { range : Str, version : Str } -> Try({}, [BadRange, Outside])`. The tests name it (TlngatepureTest). It drops the pre-release and build parts of `version` (compares major.minor.patch only), then uses `Ranges.check` and `Ranges.admits`. The caller (`Intent.read`, `tln run`) maps `BadRange` to `Fail.with_hint` and `Outside` to the text of the Output table, both kind `Input`. About 25 lines. |
| `Intent.read` | After `Toml.parse` and before `read_tables` issues are returned: if the role is not Member and `[toolchain] tln` exists, call the check with `Help.version`. A gate failure wins over the other issues. A value that is not a string is the failure `toolchain.tln: must be a string` plus the hint, and wins as well. |
| `tln run` | `ScriptsToml.read` is called by the run flow: call the same check on the text first (a small shared function that takes the text and the role). The `run` walk reads the root file of a workspace for `[scripts]`: the gate uses the file that holds `[toolchain]` (the root). |
| Proxy | No extra code if `Base.roc:356` and `:380` call `Intent.read` (they do). |
| Size | About 60 lines. |

## Output (proposed, TW24)

The messages begin with `<path>:<line>: ` as R-EC19 says ("names the file, and the line when there is one"). The line is the line of the key `tln`.

| Case | Text |
| --- | --- |
| Outside the range | `<path>:<line>: this project needs tln <range>, this is tln <version>. Run: tln tool update talon` (R-TF10 gives the text. The path and the line are a proposal.) |
| A range that does not parse | `<path>:<line>: toolchain.tln: '<text>' is not a version range` then a second line `A newer tln may know this value. Update tln: tln tool update talon` (the form of the bad ranges of `[dependencies]`) |
| Not a string | `<path>:<line>: toolchain.tln: must be a string` then the hint line |
| `--json` | The error object has the kind `input` and the message. No `data` field is added. |

## Mutation results (research/slice-236-revert/mutate.sh)

The unchanged mirror passes l0-9 (39).

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | A prerelease tln is compared with its suffix | l0-9 |
| m2 | Commands and the proxy do not check the gate | tf10-install, tf10-proxy |
| m3 | `tln run` does not check the gate | tf10-run |
| m4 | A bad range has no hint line | l0-9 |
| m5 | The gate also checks a member file | l0-9 |

## Verify

check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only). `MISSING=1 scripts/rules.sh R-TF`: no rule without a test. Manager note: `ScriptsToml.read` has no role, so `tln run` checks the gate in any file it reads; harmless, because R-WS5 already makes `[toolchain]` in a member file exit 19.

## Open

| Item | Owner |
| --- | --- |
| Q1 (DECIDED by the user, 2026-11-08; G-C240, Design Q610). Every command and `roc` proxy call that reads the project `talon.toml` checks the gate; no read, no check. `tln tool update talon` is never checked, also if it later reads `talon.toml`. Old text: which commands are gated? R-TF10 says "each command that reads `talon.toml`, and the `roc` proxy". It does not say that `tln --version`, `tln --help`, `tln tool update talon`, `tln setup` and `tln init` are free. The tests assume: a command that reads no `talon.toml` is not gated, and `tool update talon` is never gated (it is the fix that the message names): guard case `tf10-update-talon`. `tln init` with an existing `talon.toml` is not tested. Please confirm, and say whether `tln tool update talon` must stay free also if a later change makes it read `talon.toml` (for the `[tools]` table). | Human (design) |
| Q2 (DECIDED by the user, 2026-11-08, G-C240, Design Q610: no read, no gate). Old text: proxy cases that read no `talon.toml`: `roc version` or `roc --help` (no target file, so no project), the opt-out `TALON_PROXY=0`, and a project with no header. The proxy does not read `talon.toml` there (R-PX2: dispatch, 5 ms target), so the gate does not run. R-TF10 says the proxy "checks it first" without these cases. Is "no read, no gate" right? Not tested. | Human (design) |
| Q3 (DECIDED by the user, 2026-11-08, G-C240, Design Q610). The gate compares only major.minor.patch of this tln, so `0.4.0-rc.1` counts as `0.4.0`. Tests: TlngatepureTest. Old text: a pre-release `tln` (for example `0.4.0-rc1`) against a range such as `>=0.3.0`. `Ranges.admits` never admits a pre-release version, so the gate would stop each pre-release build. The design does not say. Not tested: `Help.version` is a constant and has no pre-release today. | Human (design) |
| Q4 (DECIDED by the user, 2026-11-08). No change in this slice: `Help.version` stays the source. Old text: the `tln` version in the message: `Help.version` has the comment "the design gives no source for it yet". If a release stamps the version in another way (a build constant), the message and the L2 expected files follow it. | Human (design) |
| Q5. Order with the project record step. In `install` and in the proxy a failing read of `talon.toml` comes after the record step (the project is recorded, as for a bad `strategy` today). In `run` it comes before it. The red cases keep these orders and show them in `tree.diff` and `calls.log`. If the code agent has to move the gate to another place, it tells the human before it edits the expected files (TW18). | Code agent, human |
| Q6. The expected `calls.log` of the failing runs is derived by hand: it is the log of a known exit 19 of the same read (a bad `strategy` for `install`, `scripts.hi = 5` for `run`, the stale-patch run of `px4-patch-early` for the proxy), cut after the read of `talon.toml`. | Code agent |
| Q7. Nested standalone project in a workspace directory: it is its own root (R-WS5, R-PD6), so its own `[toolchain] tln` counts. Not tested (no new rule). | none |
