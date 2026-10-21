# 013 Pin gate

Phase: P0. Status: done

This slice tests the decision `docs/design-gaps/G-pin-gate.md` (applied to the design files, `docs/design-gaps/APPLIED.md` section 2) and the 4 open cases of slice 012 (N3, G5, F1, I1). It follows `docs/agents/BRIEF-tests.md`. The earlier slices are not committed: the pre-slice copies of the changed files are in `research/slice-013-revert/before/` (with `NEW.txt`).

## Rules

R-SO19, R-SO20, R-SO21, R-SO22 (new, Resolution 13), R-SP1, R-RP2, R-NS4, R-NS5, R-SO17, R-PH7. Also from slice 012: R-NS9 over R-NS10 (N3), R-SO13 (the `Path` rows of `gate`), R-LF1 (F1), R-RP3, R-H6.

The decision in one table (G-pin-gate section 3). The held nightly is what a command checks, probes and writes as the `roc:` pin. The run compiler is what runs a `roc` call.

| Header, environment | `install` `add` `update` `remove` (role `Lock`) | `install --frozen` | `verify` (role `Verify`) |
| --- | --- | --- | --- |
| Pin, `ROC_TOOLCHAIN` not set or the same id | hold the pin | ok | probe on the pin |
| Pin, `ROC_TOOLCHAIN` names another id | hold the pin, probe on it, one note (R-SO20) | ok, no note | probe on `ROC_TOOLCHAIN` (R-SO21) |
| Pin the intent does not admit | exit 10 before the index (R-RP2) | exit 14 | exit 10 |
| Pin not installed | exit 13 at the first probe. `--no-check`: no probe, ok (R-SO22) | ok | as `Lock` |
| No pin, `ROC_TOOLCHAIN` set | rank 2 is held. The intent gates it: exit 10 (R-SO19). Not installed: first probe exit 13 | ok | rank 2 runs, no gate (R-NS4) |
| No pin, no `ROC_TOOLCHAIN`, the `roc` on `PATH` | `Pin.gate` as in slice 012 (exit 10 switch, exit 13 range) | ok | as `Lock` |
| A header with a pin and a `roc` on `PATH` that the range does not admit (G5) | `Pin.gate` does not run: the pin is checked, `PATH` is irrelevant | ok | as `Lock` |

## Files

| File | Change |
| --- | --- |
| `cli/lib/Pin.roc` | Types and docs only (the stubs keep today's behavior): `Decision` has `held_from` and `note`. `decide` takes `toolchain` and `role`. `gate` takes `held_from`. New `Pin.toolchain_note` (`crash "todo"`) |
| `cli/lib/ResolveBase.roc` | `Request.toolchain`. The calls of `Pin.decide` and `Pin.gate` pass the new fields (`role: Lock`, `held_from: Path`) |
| `cli/lib/InstallFlow.roc`, `cli/lib/RemoveFlow.roc` | The call of `Pin.decide` passes `toolchain: request.toolchain`, `role: Lock` |
| `cli/lib/Install.roc`, `Update.roc`, `Remove.roc`, `Verify.roc`, `Ls.roc` | The `Request` has `toolchain: Err(Unset)` (a placeholder: the code agent wires `Compiler.toolchain_of`) |
| `tests/unit/pin.roc` (+59 lines) | The call of `decide` in expect 2 has the new fields. Two new expects: `hold` and `gate` |
| `tests/commands/main.roc` | The L2 entry `resolve` reads the word `toolchain=<id>` (needed because the test app builds the `Request`) |
| `tests/commands/cases/ladder/ld-no-check-refuse/` | +4 runs (5 to 8), +4 projects `q5` to `q8`, `rules`, expected files |
| `tests/commands/cases/resolve/rs-failures/` | +1 run (10), `rules`, expected files |
| `tests/scenarios/verify/vf1-verify/cmd` | 1 run changed, +6 runs, expected files |
| `tests/scenarios/update/up1-update-entries/cmd` | 1 run changed (`ROC_TOOLCHAIN`), +1 run, expected files |
| `tests/scenarios/remove/rm2-workspace/cmd` | 1 run changed (`ROC_TOOLCHAIN`), +2 runs (outside pin, Q37), expected files |
| `tests/scenarios/install/in1-workspace-frozen-rename/cmd` | +1 run, expected files |
| `research/slice-013-revert/` | `before/`, `mutate.py`, `results.md`, `cli-stub.sha256` |

## Public signatures (stubs)

| Item | Signature |
| --- | --- |
| `ResolveBase.Request` | New field `toolchain : Try(Str, [Unset])`: `ROC_TOOLCHAIN`, a full id (`Compiler.toolchain_of`) |
| `Pin.decide` input | New fields `toolchain : Try(Str, [Unset])` and `role : [Lock, Verify]` |
| `Pin.Decision` | New fields `held_from : [Pin, Env, Path]` and `note : Try(Str, [None])` (the text of the note, `Ok` only for a `Lock` command that keeps a pin against another `ROC_TOOLCHAIN`) |
| `Pin.toolchain_note` | `{ pin : Str, toolchain : Str } -> Str` (R-SO20, the text is a proposal) |
| `Pin.gate` input | New field `held_from : [Env, Path]` |

The table of `Pin.decide` is in its doc comment (`cli/lib/Pin.roc`). `ResolveBase.check_pin` and `ResolveBase.prepared!` need a `role` in the code (the stubs call them as today).

## Tests

| Layer | File and case, and what it checks | Rules |
| --- | --- | --- |
| L0 | `tests/unit/pin.roc` expect 3 (`hold`): 10 rows of `Pin.decide` and the text of `Pin.toolchain_note`. A pin and another `ROC_TOOLCHAIN`: `Lock` keeps the pin and has the note, `Verify` holds `ROC_TOOLCHAIN` with no note, the same id gives no note. A pin outside the range stays `outside` in `Verify`. No pin: rank 2 is held and written as the pin after the check, `--no-check` writes none, no `roc` on `PATH` is no problem, no `ROC_TOOLCHAIN` gives `Path` | R-SO19 R-SO20 R-SO21 R-SO22 R-RP3 R-RP2 R-H6 R-SO3 |
| L0 | `tests/unit/pin.roc` expect 4 (`gate`): 7 rows. `Env`: switch off exit 10, range exit 10, the switch first, inside the range ok, a release with the switch off ok. `Path`: range exit 13, switch exit 10 (as slice 012) | R-SO19 R-SO13 R-NS2 R-NS3 R-PH7 R-EC13 |
| L2 | `ladder/ld-no-check-refuse` runs 5 and 6 (G5): a pin inside `[toolchain] roc`, the `roc` on `PATH` below the range. `--no-check`: exit 0, json moves, the pin stays. Without it: exit 13 with the text of `Compiler.require` (the pin compiler is not installed), no write | R-SO19 R-SO22 R-PH7 R-RP2 |
| L2 | `ladder/ld-no-check-refuse` run 7 (I1): the pin is the `roc` on `PATH`, `toolchain=` names another id, `update`: the first stdout line is the note, the 3 probes of `calls.log` run on the pin, json moves, the pin stays | R-SO20 R-SP1 R-BL1 |
| L2 | `ladder/ld-no-check-refuse` run 8: no pin, `--no-check`, `toolchain=` names an id that is not installed: no probe, json moves, no pin is written | R-SO22 R-H6 |
| L2 | `resolve/rs-failures` run 10: `update` with a pin outside `[toolchain] roc`: exit 10 before the index, same text as `install` (run 6) | R-RP2 R-SO17 R-NS5 |
| L3 | `verify/vf1-verify`: the run `ROC_TOOLCHAIN=<other id> verify --no-check` now exits 0 (it was exit 13). New run without `--no-check`: exit 13 at the first probe, text of `Compiler.require` | R-SO22 R-PH7 R-SO21 |
| L3 | `verify/vf1-verify`: `[toolchain] nightly = true` in `talon.toml` and `nightly = false` in `config.toml`: the command runs (N3) | R-NS9 R-NS10 |
| L3 | `verify/vf1-verify`: the header pin is another compiler than the `roc` on `PATH`. `verify`: exit 13 at the first probe (pin). `ROC_TOOLCHAIN=<roc on PATH>` `verify`: the probes run on it, exit 0 | R-SO21 R-SO22 |
| L3 | `verify/vf1-verify`: no pin, `[toolchain] roc` does not admit the `roc` on `PATH`, `ROC_TOOLCHAIN` names it. `verify`: exit 0 (R-NS4). `install`: exit 10, names `ROC_TOOLCHAIN` and the range | R-NS4 R-SO19 |
| L3 | `update/up1-update-entries`: `ROC_TOOLCHAIN=<other id>` with `update` and with `install --dry-run`: the note, the 3 probes on the pin (they pass because the pin is the `roc` on `PATH`), the same plan | R-SO20 R-SP1 |
| L3 | `remove/rm2-workspace`: `ROC_TOOLCHAIN=<other id>` with `remove` in a workspace: the note, check and build run. A pin outside `[toolchain] roc` (the root `talon.toml` has `roc = "0.1.0"`): exit 10, also with `--no-check` (Q37) | R-SO20 R-RP2 R-SO19 |
| L3 | `install/in1-workspace-frozen-rename`: `ROC_TOOLCHAIN=<other id> install --frozen`: exit 0, no note, no `roc` call (F1) | R-SO22 R-LF1 |

Count: 2 new L0 expects (17 rows) and 1 changed expect (the call of `decide`). 5 L2 runs in 2 existing cases (no new case). 10 L3 runs in 4 existing cases (3 old runs changed: `vf1-verify` (exit 13 to 0, see R-SO22), `up1-update-entries` and `rm2-workspace` (`ROC_TOOLCHAIN` added, one note line more)).

## Output proposals (TW24, for the review)

| Item | Proposal |
| --- | --- |
| The note of R-SO20 | The first line of stdout, as `note: <text>` (the `Outcome.notes` and `data.notes` with `--json`, as the other notes). Text: `ROC_TOOLCHAIN is <toolchain>, but the header pin is <pin>. This command keeps the pin. To change the pin, run tln roc use <toolchain>.` One note for each run, also in a workspace |
| `ROC_TOOLCHAIN` outside the range, no pin | `tln: error[no_tuple]: the compiler <id> from ROC_TOOLCHAIN is outside [toolchain] roc (<range>). Change ROC_TOOLCHAIN or [toolchain] roc.` Exit 10 |
| `ROC_TOOLCHAIN` a nightly, the switch off, no pin | `tln: error[no_tuple]: the compiler <id> from ROC_TOOLCHAIN is a nightly, and nightly is false (set by <source>). Change ROC_TOOLCHAIN or the nightly switch.` Exit 10 |
| The pin not installed, at the first probe | The text of `Compiler.require` of slice 012, unchanged (exit 13) |

## Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `ResolveBase.Request` gets a field `toolchain`. The L2 test app builds the `Request`, and the code agent cannot edit the tests (TW18), so the field must exist before the code | The code agent adds the field (it would break `tests/commands/main.roc`) |
| D2 | `Pin.decide` decides `held`, `held_from` and `note` (one pure function, L0 rows). `Pin.toolchain_note` is the text | The note text in `InstallFlow` and `RemoveFlow` (two copies, no L0 row) |
| D3 | `Pin.gate` takes `held_from : [Env, Path]`. The caller skips it for `Pin` (G5) and for `Verify` with `Env` (R-NS4). Both are checked by deep tests, not L0 | `gate` takes the role, or accepts `Pin` (it would hide the G5 rule in the function) |
| D4 | For `Env` both stops (the range, the switch) are exit 10 (R-SO19: "exit code 10 (`no_tuple`)"). The `Path` rows keep exit 13 for the range (R-SO13) and exit 10 for the switch | Exit 13 for `Env` (a download that P0 refuses): R-SO19 says 10 |
| D5 | `Verify` with the same id as the pin: `held_from` is not fixed (no test). The doc of `decide` says `Pin` | A row for it |
| D6 | I1 is tested with `update`, `install --dry-run` and `remove`. `add` is `install` with names: it calls the same `InstallFlow.resolve!` and `check_pin` (no own run) | A run for `add` |
| D7 | R-NS4 for `verify` is a run with no pin, so the gate of rank 2 is the only difference from `install` (the same header and `talon.toml`) | A run with a pin |
| D8 | The L2 entry `resolve` reads `toolchain=<id>`. It sets `Request.toolchain` without the environment. The wiring `Compiler.toolchain_of(env)` is tested by L3 only | The L2 entry `commands` with an environment for each case |
| D9 | N3 is one direction only: `talon.toml` says true, `config.toml` says false, and the header pin is a nightly. A swapped order stops the run (exit 10), so one run catches it | A run for each direction |

## Out of scope

| Rule or case | Reason |
| --- | --- |
| R-SO19 "rank 4 finds no installed compiler in the range" | Rank 4 is P1 (no compiler manager) |
| R-SO19 ranks 5 and 6 (`.roc-version`, the global default) | P1 (Q30 of slice 012) |
| R-SO20 "`ROC_TOOLCHAIN` still selects the compiler of the proxy (R-U6)" | The proxy is P1 |
| R-SO22 "the held nightly is a required download" with a download | P0 refuses it with exit 13 (R-PH7). The refusal is tested |
| `upgrade` (R-RP2 "`upgrade` when the nightly is not free", R-NS4 `roc use`) | P1 |
| R-SO11, R-NS6 (a local build is not checked) | A local build id is `NoCompiler` in P0 (`Compiler.on_path`), tested in `compiler.roc` |
| `Compiler.select` | No test names it. W1 of G-pin-gate (no eager `require`) is tested through the runs of `vf1-verify` and `in1` |

## Questions (TW17)

| # | Question | Default (the tests follow it) |
| --- | --- | --- |
| Q37 | `remove` with `--no-check` (and `--force`): `RemoveFlow` skips `check_pin` then (`skip_check`). R-RP2 lists `remove` with no exception for `--no-check`, and `install`, `update` and `verify` check the pin with `--no-check`. Does `remove --no-check` stop for a pin that the intent does not admit? | Yes: the test `rm2-workspace` expects exit 10 for `remove --no-check` with a pin outside the range. The code stops only when the check runs, so this run is red |
| Q38 | R-SO19 says that a no-pin command checks the compiler that rank 2 selects, and the table says that `verify` does not (R-NS4: run it). Is the `verify` row right for `ROC_TOOLCHAIN` outside the range, with no pin? | Yes (`vf1-verify` runs it: exit 0) |

## Old tests that changed

| Test | Change | Rule |
| --- | --- | --- |
| `verify/vf1-verify` run `ROC_TOOLCHAIN=nightly-2026-10-09-258ab27 tln verify --no-check` | exit 13 becomes exit 0 and the output is the output of `verify --no-check`. The exit 13 check moves to a run without `--no-check` (first probe) | R-SO22 |
| `update/up1-update-entries` run "No name" | `ROC_TOOLCHAIN` is set. One more first line (the note). The same writes | R-SO20 |
| `remove/rm2-workspace` last run | `ROC_TOOLCHAIN` is set. One more first line (the note). The same writes | R-SO20 |
| `tests/unit/pin.roc` expect 2 | The call of `Pin.decide` passes `toolchain: Err(Unset)` and `role: Lock` (the new fields). The rows are the same | |

The expected files of all other cases are not changed (the `calls.log` of the L2 cases that use the `resolve` entry are the same: the new word is only a field of the `Request`).

## Notes for the code agent

| # | Note |
| --- | --- |
| 1 | W1: `Compiler.select` must not call `Compiler.require` for `ROC_TOOLCHAIN` (R-SO22). `Install.compiler!` gives the id of rank 2 (`Compiler.toolchain_of`) and the `roc` on `PATH` apart. Set `Request.toolchain` in `Install.flow!`, `Update`, `Remove` and `Verify` (the stubs have `toolchain: Err(Unset)`). `Compiler.select` has no test: change or remove it |
| 2 | W3: `Pin.decide` is in the table of its doc comment. `Pin.toolchain_note` is the text of the proposal. The 3 callers pass `role: Lock`. `VerifyFlow` needs `role: Verify` (`ResolveBase.prepared!` is the shared first step: give it the role). `Decision.pinned` can stay (nothing in the tests reads it) |
| 3 | W4: `ResolveBase.check_pin` reads `decision.held_from`. `Pin`: no `gate` (G5). `Env`: `gate` with `held_from: Env`, except for `Verify` (R-NS4). `Path`: as today. The `gate` texts of `Env` are in its doc comment and in `tests/unit/pin.roc` |
| 4 | Print the note (`decision.note`) as the first `note:` line, after `check_pin` and before the pick, in `InstallFlow.resolve!` and in `RemoveFlow.remove!`. `verify` has no note. The L3 expected files fix the place |
| 5 | Q37: `RemoveFlow.remove!` calls `check_pin` also with `--no-check` and `--force` (the `skip_check` guard goes). `rm2-workspace` fixes it. If the manager answers "no", the run `remove json --file apps/a/main.roc --no-check` is a dispute (TW18) |
| 6 | The test agent ran the whole fast set with the reference (see the revert check): no old expected file changed, also no `calls.log`. The reference change for Q37 (`check_pin` also with `--no-check` and `--force` in `remove`) came after that run, and only `rm2-workspace` ran with it. The other `remove` runs have no pin and no range, so `check_pin` gives `Ok` there. If one of them changes, it is a dispute row |

## Red output (2026-10-21, `scripts/test.sh`, pinned roc, `cli/` with the stubs)

| Step | Result |
| --- | --- |
| `check`, `fmt`, `selftest` | pass |
| `l0` | `tests/unit/pin.roc`: 2 of 4 expects fail, both with wrong values (no `todo`: the `and` stops before `Pin.toolchain_note`). `hold`: 9 of 10 rows (the stub holds the `roc` on `PATH` or ignores `toolchain` and `role`: `held` and `held_from` are wrong, the note is `Err(None)`). `gate`: the 3 `Env` rows (the stub gives the text and the exit code of `Path`: exit 13 and `the roc on PATH ...`). All other files pass |
| `l2` | 30 pass, 1 fails: `ladder/ld-no-check-refuse`, stdout only: the first line of run 7 (the note) is missing. Runs 5, 6 and 8 and `rs-failures` run 10 pass (G5, R-SO22 and R-RP2 for `update` are gap tests: the code stops as the design says) |
| `l3` | 23 pass, 1 skipped, 3 fail. `verify/vf1-verify`: the run with `ROC_TOOLCHAIN=<other id> --no-check` gives exit 13 (expected 0), `ROC_TOOLCHAIN=<roc on PATH> verify` with another pin gives exit 13 (expected 0), the no-pin `verify` with `ROC_TOOLCHAIN` gives exit 13 (expected 0), `install` gives exit 13 with the text of `Pin.gate` (expected exit 10, the text of `Env`). `update/up1-update-entries`: `update` with `ROC_TOOLCHAIN` gives exit 13 (expected exit 0 and the note). `remove/rm2-workspace`: `remove --no-check` with a pin outside the range writes the header (expected exit 10), then `ROC_TOOLCHAIN` gives exit 13. `install/in1` (F1) passes: gap test |

## Revert check (TW12)

A private reference of the slice (the minimum code in `cli/`, built from the stubs) ran the whole fast set green: `scripts/test.sh` passed with all new and changed tests. Then `research/slice-013-revert/mutate.py` put 19 small changes in it, one by one (results: `research/slice-013-revert/results.md`). The reference is deleted: `cli/` equals the stubs again (`research/slice-013-revert/cli-stub.sha256`, checked with `sha256sum` and `diff`).

| Result | Rows |
| --- | --- |
| Caught (19 of 19) | N1 P1 P2 (the note: L0, L2 `ld-no-check-refuse`, L3 `up1`, `rm2`), N2 (`Lock` holds `ROC_TOOLCHAIN`), V1 (`Verify` ignores it), E1 (no pin, rank 2 ignored), G5, NS4 (R-NS4 for `verify`), X1 X2 (the `Env` gate), S1 (a write with `--no-check`), C1 C2 (the eager `require` of W1, also for `--frozen`), R1 (no `check_pin` in `update`), R2 R3 (none in `remove`), N3 (config over toml), W1 (`ROC_TOOLCHAIN` is not read from the environment), O1 (`verify` does not report an outside pin) |
| First try not caught (1) | G5: the first row gated the pin id, which is no bug (`outside` checked it before). The row was rewritten to gate the `roc` on `PATH` with a pin (the bug G5 names). Then it is caught by `ld-no-check-refuse` runs 5 and 6 |

## Next step

The human reviews the 2 L0 expects, the 15 new L2 and L3 runs, the 3 changed runs, the output proposals and Q37, Q38. Then the code agent (notes 1 to 5).


## Review (manager, 2026-10-21)

D1 to D9 and the output proposals (TW24) are accepted.

| # | Answer |
| --- | --- |
| Q37 | The design reading: R-RP2 lists `remove` with no exception. `check_pin` is not the ladder, so `--no-check` and `--force` do not skip it. |
| Q38 | The table of G-pin-gate (R-NS4): `verify` with no pin runs the `ROC_TOOLCHAIN` compiler. |
| Prefix in `ROC_TOOLCHAIN` with `--frozen` | Exit 2 stays: the value is bad input, also when no compiler is needed. No new test. |
| `Decision.pinned` | The code agent may remove it when `held_from` replaces it, if no test reads it. |

Status: code.

## Code (code agent, 2026-10-21)

`scripts/test.sh` exits 0: check, fmt, l0 (all unit files), l2 (31 cases), l3 (26 pass, 1 skipped), selftest.

| File | Change |
| --- | --- |
| `cli/lib/Pin.roc` | `decide` uses the private `held_choice` (the table of its doc). `toolchain_note` has its text. `gate` reads `held_from` (`Env`: exit 10 and the text of `ROC_TOOLCHAIN`). `Decision.pinned` is removed (review: `held_from` replaces it) |
| `cli/lib/ResolveBase.roc` | `check_pin` takes `role`: `Pin` no gate (G5), `Env` with `Verify` no gate (R-NS4), `Env` with `Lock` and `Path` call `gate`. `prepared!` takes `role`. New `pin_notes` |
| `cli/lib/InstallFlow.roc`, `RemoveFlow.roc` | `check_pin` with `Lock`, then the note line. `remove` checks the pin also with `--no-check` and `--force` (Q37, review) |
| `cli/lib/VerifyFlow.roc` | `prepared!` and `check_pin` with `Verify` |
| `cli/lib/Compiler.roc` | `select` is removed (G-pin-gate W1: no eager `require` for `ROC_TOOLCHAIN`) |
| `cli/lib/Install.roc`, `Update.roc`, `Remove.roc`, `Verify.roc` | `Compiler.toolchain_of(env)?` sets `Request.toolchain`. `Install.compiler!` is `Fx, Bool => Try(Str, [NoCompiler])` (the `roc` on `PATH` only; was `Fx, env, Bool => Try(Try(..), Fail)`). `Update.request_of` takes `{ compiler, toolchain }` |
| `cli/lib/Resolve.roc` | Doc of `remove!` row 6 only |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Verify results

The script is `research/slice-013-revert/code-mutate.py` (results in `code-results.md`). The copy of the code before the mutations is `research/slice-013-revert/code-green-cli/`. After the mutations `diff -r cli code-green-cli` is empty. 27 mutations: 26 caught, 1 not caught.

| Result | Rows |
| --- | --- |
| Caught by `l0:pin` | N1 N2 V1 E1 SAME S1 X1 X2 T1 |
| Caught by L2 | G5 (`ld-no-check-refuse`), PA (`rs-no-compiler`), R1 (`rs-failures`), NI (`ld-no-check-refuse`) |
| Caught by L3 | NS4 EL RO WV (`vf1-verify`), WU (`up1`), WR R2 R3 NR (`rm2`), C1 (`up1`), C2 (`in1`), VH N3 WI (`vf1`) |
| Not caught (1) | FD: `finish!` in `InstallFlow` calls `Pin.decide` with `toolchain: Err(Unset)`. In P0 this is equal: a write happens only after a probe passed, and a probe passes only when the held id is the `roc` on `PATH`, so `held` is the same id. Equivalent in P0. In P1 (downloads) a test is needed |

## Review of the code (manager, 2026-10-21)

`scripts/test.sh` passes (manager run: l0 12.2 s, l2 61.3 s, l3 9.3 s). The revert check caught 26 of 27 (FD is equal in P0). The decisions are accepted, with one gap: the accepted output proposal puts the R-SO20 note in `Outcome.notes` and `data.notes` with `--json`, and the code prints it only. No test checks it. Moved to slice 014: the test agent adds a `--json` run with the note, the code agent adds it to `Outcome.notes`.
