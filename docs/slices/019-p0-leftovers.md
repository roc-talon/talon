# 019 P0 leftovers

Phase: P1. Status: done

This slice adds the tests for the P0 items that no slice owned (`docs/slices/PLAN-P1.md` section 4, row 019). It follows `docs/agents/BRIEF-tests.md`. It changes no code: each new test passes on today's code (gap tests), and the revert check shows that each test catches its mutation. So the slice needs no code step.

## Rules

R-SE7, R-CM11, R-LB2, R-PD4, R-PD5, R-WS1, R-CV3 (the sha256 of `scripts/get-roc.sh`, slice 018b).

## Items

| Item | Source | What the test checks | Rule |
| --- | --- | --- | --- |
| F5 | Slice 009 review | The platform note is printed once when 2 members change the platform (`update` and `verify`) | R-SE7 |
| F12 | Slice 009 review | The `--replace-dep` list of `verify` has each pair once when 2 members name the same package | R-CM11, R-LB2 |
| C9 | Slice 009 review (the `verify --file` rule) | `verify --file <member>` checks that member only (probes, `~` lines). `verify` with no current member checks all members. | R-PD4, R-PD5, R-CM11 |
| G3 | Slice 018b review | `scripts/get-roc.sh` with a wrong digest: exit 1, `sha256 mismatch`, nothing installed | R-CV3 |

## Tests

| Layer | File and case | Checks | Rules |
| --- | --- | --- | --- |
| L2 | `tests/commands/cases/workspace/ws2-verify-members` run 1: `verify --file apps/a/main.roc` (workspace root, members a and b, both name pfx 0.1.0 and json 2.0.0) | One note for the platform (2 members change it). 3 probes for a only (no probe for b). `~` lines for a only. Each candidate probe has one `--replace-dep` for json and one for the platform. Exit 0, nothing written. | R-SE7, R-CM11, R-LB2, R-PD5 |
| L2 | The same case, run 2: `verify` (no `--file`, the root has no member file, so no current member) | One note for the platform. 6 probes: a then b, each with a temp dir. Each candidate has the 2 `--replace-dep` pairs once, not once for each member. `~` lines for a and b. | R-SE7, R-CM11, R-LB2, R-PD4, R-PD5, R-WS1 |
| L2 | `tests/commands/cases/workspace/ws1-closure-keys` run 1 (exists, slice 017): `update pf` in a workspace of 2 members | The same F5 rule for `update`: one note, 2 edits. It was already a test of F5. The revert check shows it. | R-SE7 |
| Selftest | `tests/selftest.sh`, 1 new row after the `ci/*` rows: a fake `gh` first on PATH | A wrong digest: exit 1, text `get-roc: sha256 mismatch for <name>`, no `nightlies` dir. The control: the right digest has no mismatch text (the next step, tar, fails on the fake archive). | R-CV3 |

Count: 0 new L0 expects, 1 new L2 case (2 runs), 1 new selftest row.

## Files

| File | Change |
| --- | --- |
| `tests/commands/cases/workspace/ws2-verify-members/` | New case (entry, rules, fx, given, expect). 1 workspace, 2 members, 2 runs. |
| `tests/selftest.sh` | New row for `scripts/get-roc.sh` (the file with the old content: `research/slice-019-revert/before/tests/selftest.sh`) |
| `research/slice-019-revert/` | `before/` (with `NEW.txt`), `mutate.py`, `cli-scripts-pre.sha256` |

No Roc file changed: no `roc check` or `roc fmt` run is needed. `cli/` and `scripts/` are unchanged (the sha256 file shows it).

## Output (proposed, TW24)

None new. The expected files hold the texts that exist: the note `note: platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1`, the lines `<file>: check: passed` and `<file>: build: passed` for a verify with 2 members, and the `~` lines. Review point: for 2 members, `verify` prints the lines `check` and `build` with the file name in front (the code does this today).

## Decisions that the design does not fix

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | One new case with 2 runs, not new runs in `ws1-closure-keys`: a run with the ladder needs probe answers, and `ws1` has `--no-check` for all runs. A change of `ws1` would also change its 4 expected files. | 3 runs in `ws1` |
| D2 | The workspace root is the project dir (cwd). `verify` with no `--file` has then no current member (R-PD4, R-PD5: the root counts only member files, there are none in the dir). | A cwd option for L2 cases (the fake Fx has none) |
| D3 | The selftest row uses a fake `gh` that ignores the platform name, so it runs on each OS of the CI. | A row that needs the real network (tag `net`) |

## Out of scope

| Item | Reason |
| --- | --- |
| The `install.sh` digest check | Not in the scope of this slice (`install/test.sh` has its own tests) |
| `verify` with 2 members that have different results | The ladder rule per member is slice 009 (L2 `vf1-flow`) |

## Questions (TW17)

None.

## Revert check (test agent, 2026-10-22)

`research/slice-019-revert/mutate.py <id>` mutates the current code in place after a restore. Runs: `tests/commands/run.sh ws1 ws2` (L2) and `tests/selftest.sh`. The sha256 of `cli/lib/*.roc` and `scripts/*.sh` is the same as before (`cli-scripts-pre.sha256`).

| Id | Mutation | Test that fails | Result |
| --- | --- | --- | --- |
| F5 | `moved_platform_notes` (`cli/lib/ResolveBase.roc`) does not remove a repeated note | `ws1-closure-keys` run 1 and `ws2-verify-members` runs 1 and 2 | Caught (2 of 2 cases fail) |
| F12 | `replace` in `VerifyFlow.verified!` (`cli/lib/VerifyFlow.roc`) is not made unique | `ws2-verify-members` run 2 (the `--replace-dep` list) | Caught |
| C9 | `checked_members` (`cli/lib/VerifyFlow.roc`) always gives all members | `ws2-verify-members` run 1 (b is probed) | Caught |
| G3 | The sha256 compare of `scripts/get-roc.sh` is removed | selftest row `get-roc` | Caught (selftest: 38 passed, 1 failed) |

Note: the 2 first tries of C9 did not compile (the compiler warns for an unused variable and for a constant `if`, and `roc build` exits 2 on a warning). The final mutation is `if named.len() >= 0 all else named`.

All 4 mutations are caught. `scripts/test.sh` on the final tree: check, fmt, l0, l2, l3 and selftest pass (selftest 14 s of 20 s budget).

## Review (manager, 2026-10-22)

`scripts/test.sh` passes (manager run). The 4 new checks pass on today's code, and each catches its mutation (4 of 4), so the slice has no code step. D1 to D3 are accepted. The output of `verify` for 2 members (`<file>: check: passed`) is today's behavior from slice 006 D16, and it is accepted.
