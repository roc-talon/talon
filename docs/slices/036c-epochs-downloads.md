# 036c Epochs in the loop, fix lines (optional downloads split out)

Phase: P1. Status: done

Slice 036c is the plan row 036c of `PLAN-P1.md`. It needs 036b, 036b2 and 036b3 (done). The test agent proposes a split (section 1): this slice has the compiler list D, the epochs, the `fix:` lines and the hint. The optional downloads (R-DL1, R-DL6, R-NI4, U5) go to a later slice, because the design has no producer for them in a command with a held compiler (TW17).

The private reference had 205 added lines of code (without comments and empty lines). The row said about 450 for the whole slice. The reference was deleted at the review (2026-10-24).

## 1. Scope and split

| Item | Where | Rule | In this slice |
| --- | --- | --- | --- |
| D is read by the loop (Q1 (b) of slice 036: when a probe or a check needs it) | `PickLoop.wide!`, verdict `Wide` | R-EP10, R-EP11 | yes |
| Epochs and inferred facts feed the solver (the explanation uses real and inferred facts) | `Oracle.checks_of`, `PickLoop.wide!` | R-EP10, R-EP9, R-EP14, R-EP7 | yes |
| `Off` explains with the inferred facts, and marks them | `Explain.lines`, `Explain.details` | R-EP9, R-EP14 | yes |
| The hint `tln roc use <id>` from known facts, and the `fix:` lines | `Oracle.hint`, `Explain.lines` | R-RP2 | yes |
| Revisit of D2 of 036b: the assumed pass holds on H only | `Oracle.checks_of` | R-EP7, D2 | yes |
| Optional downloads of a held-nightly command, the cap, the skipped line, the flag `--probe-downloads` | none | R-DL1, R-DL6, R-NI4 | no, see section 7 |

## 2. Public signatures (stubs in `cli/lib/`, `crash "todo"`)

| Name | Signature | File |
| --- | --- | --- |
| `Explain.Cause` | `{ label, alias, kind : [Fail, Hang, Crash], modules, from, to, inferred }` | `cli/lib/Explain.roc:24` |
| `Explain.lines` | `{ causes, hint : Try(Str, [None]) } -> List(Str)` | `cli/lib/Explain.roc:27` |
| `Explain.details` | `{ held, causes, hint } -> JsonDoc` | `cli/lib/Explain.roc:31` |
| `Oracle.hint` | `Oracle.Input, Oracle.Compat -> Try(Str, [None])` | `cli/lib/Oracle.roc:93` |
| `Oracle.Compat` | 2 new fields: `domain : Try(List(Str), [NotRead])`, `inferred : List(Epochs.Inferred)` | `cli/lib/Oracle.roc` |
| `Oracle.Verdict` | new tag `Wide` | `cli/lib/Oracle.roc` |
| `ResolveBase.Probed` | the same 2 fields | `cli/lib/ResolveBase.roc` |
| `PickLoop.run!` | new arm `Wide` (stub: internal failure) | `cli/lib/PickLoop.roc` |

## 3. When D is read (the answer to Q1 (b) of slice 036, exactly)

| Case | Reads D? | Why |
| --- | --- | --- |
| `Done`, `Need`, a `Pairs` of `Allowed` | no | no explanation needed |
| A `Fail` whose proof has a probe cause (unit fail, hang, crash on H), D not read | yes (`Wide`) | the explanation and the hint need the other compilers |
| A `Fail` with no probe cause | no | `resolve/rs-failures` has no new call |
| `--no-probe`, the lookup round (a chosen release changes and has no row) | yes (`Wide`) | the db and the inferred facts are all the evidence (R-EP9) |
| `--no-probe`, nothing to look up | no | `probe/dm1-domain` run 4 |
| No compiler (`--no-check`, `verify`) | no | no compiler slot |
| Once read | never again | `Ok(D)` in the next step |

Read: `Toolchain.host`, `Nightlies.list!` (with `request.now`), one `Facts.load!` for each release of the slots on each compiler of D (minus the keys in `looked`), then `Epochs.epochs`. Any failure gives `Ok([H])` and no inferred fact, with no warning: no list, offline with no cache, a bad page, H not in D.

## 4. Rules of the step

| Rule | Text | Test |
| --- | --- | --- |
| Checks of D | For a release and a compiler of D: the real row; else the assumed pass (header value, H only); else the inferred fact (source `Inferred`) | `oracledomain.roc` expect 2 |
| D2 revisit | A current value on another compiler has no assumed pass: it needs a real row or a probe | expect 2 (row 1), expect 4 (D2 rows) |
| `Allowed` | An inferred fact never decides: the step asks for the real fact | expect 2 |
| `Off` | An inferred fact decides, and the failure names it | expect 2, L2 `dm1-domain` run 3 |
| `hint` | The oldest compiler n of D, n not H, where the same step with `compiler: Ok(n)`, `Allowed`, no inferred facts, no conflicts, no assumed pass is `Done` | expect 4 |
| Header not read | A `Need` for a header is no fact about n: it is taken as fit (empty fact, D3), the step runs again (3 rounds at most) | expect 4 (2 rows), L2 `dm1-domain` run 1 |
| H not in D, or D empty | The step uses `[H]` | expect 1 (2 rows), L2 run 2 |

## 5. Tests

| Layer | File and case | Content | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/explain.roc` expect 1 (18 rows) | cause lines, words of the kinds, inferred mark, from equal to, fix block, `stop using`, `main.roc`, dedupe, order | R-RP2 R-EP7 R-EP9 R-EP14 R-UM1 |
| L0 | `tests/unit/explain.roc` expect 2 (3 rows) | `details` JSON, key order, null hint, all causes | R-J5 R-OUT2 |
| L0 | `tests/unit/oracledomain.roc` expect 1 (16 rows) | when the step gives `Wide` and when not | R-EP9 R-RP2 R-EP11 |
| L0 | same, expect 2 (13 rows) | checks of D, interval, hint, inferred with `Off` and `Allowed`, D2 revisit, order of rows | R-EP7 R-EP8 R-EP9 R-EP14 R-RP2 R-DT2 |
| L0 | same, expect 3 (3 rows) | `fail.details` of a failure | R-J5 R-OUT2 |
| L0 | same, expect 4 (19 rows) | `Oracle.hint` | R-RP2 R-EP8 R-EP11 |
| L0 | `tests/unit/oracleprobe.roc` expect 5 | the old text now ends with the fix block (changed, section 8) | R-PH13 R-RP2 |
| L2 | `probe/dm1-domain` run 1 | D read online, `fails on n2 .. n5`, hint n6 (n1 has the pass of json only: D2 revisit) | R-EP7 R-RP2 R-EP10 |
| L2 | same, run 2 | H not in the list: no cause line, no hint | R-EP11 |
| L2 | same, run 3 | `--no-probe`, inferred fail on n8, the mark, the hint | R-EP9 R-LF2 R-EP14 |
| L2 | same, run 4 | `--no-probe`, nothing to look up: no call for the list | R-LF2 |
| L2 | same, run 5 | `--offline`, D from the cache | R-EP11 R-EP8 |

L0 expects: `explain.roc` 2, `oracledomain.roc` 4, `oracleprobe.roc` 8 (one changed). The `--json` envelope with `details` is not run at L2 (the entry `resolve` prints no JSON): expect 2 of `explain.roc` and expect 3 of `oracledomain.roc` check the value. A new L3 scenario for it is a question (Q7).

## 6. Output proposals (TW24, for the human review)

| Output | Text |
| --- | --- |
| First line | unchanged: `no tuple works: the unit check on <H> fails for <blame>; <blame>` |
| Cause line | `  <label> <fails or hangs or crashes> on <from> .. <to>`, or `on <from>`; ` (inferred on <id>, <id>)`. Printed when `from` is not `to`, or the fail is inferred |
| Fix block | `  fix: tln roc use <n> (the oldest nightly that works)` (else `tln roc use <id>`), then `       or tln upgrade roc`, then `       or stop using <alias>.<Module>` for each failing module the app uses (not `main.roc`, not the platform) |
| `details` | `{"compiler","causes":[{"release","kind","modules","from","to","inferred"}],"hint"}`, keys in this order, `hint` is an id or `null` |

Only the example of Resolution 5 is fixed by the design. The rest is a proposal.

## 7. Out of scope, questions (TW17)

| Id | Item | Reason | Proposal for the later slice |
| --- | --- | --- | --- |
| Out 1 | R-DL1, R-DL6, R-NI4 (optional downloads in a held-nightly command) | The design names optional downloads for the range search (`tln probe --range`, R-PB3, R-PB4, slice 037) and `upgrade` (038, 039). R-RP2 says the hint comes "when a probe or the matrix knows it": known facts. No design text says which other compilers a held-nightly command tries, in which order. The 025 prompt already asks for the required download only (reading (c) of U5) | Q5 (a) of 036: D with the cap R-DL6 |
| Out 2 | U5 form of the opt-in | Explicit opt-in is the recommended reading | Flag `--probe-downloads` (design name, parsed in `request.downloads.probe`, read by no code), or `--yes` inside the cap. Rows that depend on it: "U5" |
| Out 3 | The skipped line (R-DL4) and the cap `max-toolchains = 0` | They need Out 1 | the later slice |

| Id | Question | Options |
| --- | --- | --- |
| Q1 | Do you accept the split (section 1)? | (a) yes, optional downloads go to 037 with the range search (recommended); (b) no, give the search policy: which compilers, which order, how many rounds |
| Q2 | After a spent budget (exit 12) the step gives no explanation (036b Q3 (a)). Should an `Off` step explain after it? | (a) no, as now (recommended); (b) yes, one `Off` step, then the explanation |
| Q3 | `remove` and `verify` ladder failures have no hint (the ladder has no D). | (a) none (recommended, as written); (b) give the ladder the D read |
| Q4 | The D read loads the rows of each release of the slots on each compiler of D in one `db_query`: releases times compilers (59 keys in `dm1-domain`). With a large list, is a bound needed? | (a) no bound in P1; (b) only the releases in the proof, then the rows of the hint |
| Q5 | The alternative tag form of the held id (R-CV1) is not mapped into D: D is `[H]`. | (a) degrade (chosen); (b) map with `Nightlies.same_nightly` |
| Q6 | The list is read with `request.now` (the clock of the command, `TALON_NOW`). `RocInstall.offer!` uses the real clock for the list cache. | (a) `request.now` (chosen, no new `clock` call); (b) the real clock |
| Q7 | Add an L3 scenario with `--json` for `error.details`? | (a) yes, in the review of this slice; (b) no |

## 8. Changed old tests (TW21)

All changes are by `research/slice-036c-revert/update-l2.sh` and `check-diff.py` (only the allowed kinds of lines). Old copies are in `research/slice-036c-revert/before/`.

| Case | File | Change | Reason |
| --- | --- | --- | --- |
| `tests/unit/oracleprobe.roc` | the Compat literals, `view`, expect 5 | `domain: Ok([nightly]), inferred: []`, arm `Wide`, the text has the fix block | new fields; R-RP2 |
| `probe/lp1-loop` | `expect/stderr` (+2 lines), `calls.log` (+15 lines, 3 reads of the list) | run 9: the fix block. 2 `--no-probe` runs: the lookup round reads D (no route: 404, degrade) | Q1 (b), R-RP2 |
| `probe/un1-units` | `expect/stderr` (+11 lines: 4 fix blocks, 3 with `stop using json.Yaml`), `calls.log` (+25 lines, 5 reads of the list) | 4 failures with a probe cause, and 1 `--no-probe` lookup run | same |
| `ladder/bs1-build-skip` | `expect/calls.log` (+5 lines) | the `--no-probe` run reads D (404) | same |
| `scenarios/update/up2-unit-flags` (L3) | `expect/http.log` (+1 line) | `--no-probe`: one GET of the list (404) | same |

No change in stdout, exit or tree diff of any old case. `resolve/rs-failures` and the other cases with a failure that has no probe cause did not change: no read of D.

## 9. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Red (stubs, `research/slice-036c-revert/red-run.log`) | l0: `explain`, `oracledomain` fail (todo crash, text with no `Wide`), `oracleprobe` expect 5 fails (7 of 8 pass). l2: 4 cases fail (`dm1-domain`, `lp1-loop`, `un1-units`, `bs1-build-skip`). l3: `up2-unit-flags` fails. check, fmt, selftest, l1 pass |
| Green (reference, `green-run.log`) | all steps pass: check 1.4, fmt 0.1, l0 6.8, l2 2.2, l3 9.9, selftest 10.6, l1 32.9 (budgets 10, 5, 10, 30, 60, 20, 60) |

Revert check: 11 mutations of the reference (`research/slice-036c-revert/mutate.py`, logs `mutate-*.log`), filtered runs only.

| Id | Mutation | Result |
| --- | --- | --- |
| M1 | assumed pass on each compiler of D | survived the first run. New row (oracledomain expect 2, row 1) catches it |
| M2 | an inferred fact replaces the assumed pass | caught (oracledomain) |
| M3 | the hint is the newest compiler | caught (oracledomain) |
| M4 | the hint reads inferred facts | survives: equal mutant. With `Allowed`, B has real facts for all its pairs, so an inferred fail cannot change a `Done`. The rule stays for clarity |
| M5 | `Wide` for a failure with no probe cause | caught (oracledomain) |
| M6 | `Wide` for a `Pairs` of `Allowed` | caught (oracledomain) |
| M7 | `Off` does not ask for D | caught (oracledomain) |
| M8 | H not in D is not degraded | caught (oracledomain) |
| M10 | no cause line for an inferred fail on H alone | caught (explain) |
| M13 | `wide!` loads the keys that were looked up again | caught by L2 `dm1-domain` only |
| M14 | the hint does not accept an unread header | caught (oracledomain, 2 new rows) |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Size | Reference: `Explain` 56, `Oracle` 113, `PickLoop` 36 added code lines. `Oracle.roc` is 486 lines with the reference (limit 500): split a part if more is added |
| Reference parts | `Oracle.run` (the `assume` flag), `domain_of`, `checks_of`, `check_at`, `needs_wide`, `has_probe`, `failure` (explain only when `assume`), `cause_of`, `label_of`, `works_on`, `settled`; `PickLoop.wide!`, `domain_keys` |
| `hint` and `failure` | The step of the hint runs with `explain` off, or `failure` calls `hint` without end |
| Compiler limits met | none new. The reference has no `Bool` field in an `Err` record and no warning |
| Cache time in L2 | the time of `index: cached at` is the real mtime of the `.meta` file: `fx/mtimes` fixes it in `dm1-domain` |
| Scripts | `gen-dm1.py` makes the case, `mutate.py` runs the mutations, `update-l2.sh` and `check-diff.py` change the old expected files |

## Review (manager, 2026-10-24)

Accepted. Status: code.

| Item | Answer |
| --- | --- |
| Q1 | Split accepted. Optional downloads (R-DL1, R-DL6, R-NI4, the skipped line, `max-toolchains = 0`) move to slice 037. The manager updates the rows. U5 stays open for the user. The proposal of section 7 stays for 037 |
| Q2 | Keep 036b: a spent budget exits 12 at once with the `probe.max` error and no explanation. The R-EP9 explanation with inferred facts after a spent budget is a follow-up that the manager records |
| Q3 | Accepted: `remove` and `verify` give no hint (no D) |
| Q4 | Accepted: one db query for the D keys (59 keys is far under the SQLite limit) |
| Q5 | Accepted: D is `[H]` for an alternative tag form |
| Q6 | Accepted: `request.now` |
| Q7 | Accepted: L0 checks the `details` value. No L3 scenario now |
| R-RP2 reading | Accepted: the hint comes from known facts |
| D rows, TW24 texts | Accepted as proposals: cause line, `fix:` block, `stop using <alias>.<Module>` |
| Changed old tests | Accepted: `probe/lp1-loop`, `probe/un1-units`, `ladder/bs1-build-skip`, L3 `update/up2-unit-flags`, `oracleprobe.roc` expect 5 |
| Note for the code agent | `Oracle.roc` will be about 486 lines. It may move code to a new module to stay under 500 |

## Code result (code agent, 2026-10-24)

`scripts/test.sh` exit 0: check 1.1, fmt 0.2, l0 6.9, l2 2.9, l3 9.9, selftest 10.5, l1 31.4 s (budgets 10, 5, 10, 30, 60, 20, 60). `OPT=speed`: all pass, l2 191 s (the known reason).

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Explain.roc` | 91 | `lines`, `details` (stub bodies replaced) |
| `cli/lib/Oracle.roc` | 469 | `hint`, `Wide`, `step_with` (the `assume` flag), `causes_of`, `failure` with the explanation, `checks_of` over D, `label_of`, `alias_of` |
| `cli/lib/OracleDomain.roc` | 49 | new: `hash_of`, `row_of` (moved from `Oracle`), `space` (D or `[H]`), `checks` (real row, assumed pass on H, inferred fact) |
| `cli/lib/PickLoop.roc` | 260 | `wide!`, `listed!`, `domain_keys`, arm `Wide` |
| `cli/lib/main.roc` | +1 | exposes `OracleDomain` |

| Decision | Choice | Rejected |
| --- | --- | --- |
| `assume` flag | A Bool parameter of `search`, `walked`, `failure`. On for `step_probed`. Off for the step of `hint`: no assumed pass (D2) and no explanation (no recursion) | A field in `Compat` (would change the public type) |
| Cause kind of a fault | `Hang` or `Crash` by the db row of H (as the first line did) | none |
| Causes | Dedupe by equal record, order of the proof | none |
| Failure of `Facts.load!` in `wide!` | Passed on as the failure of the command (as `round!` does) | Degrade to `[H]`: the design lists list failures only |
| Failure of the list or `Toolchain.host` | Degrade to `Ok([H])`, no warning | none |
| `hint` rounds | `settled` runs the step again after an empty fact for each `Need`, 3 times at most | none |

No test, fixture or expected file changed (no dispute rows). No question (TW17). No new compiler limit.

## Verify results

Revert check (TW12), filtered runs only: 11 mutations of the final code, `research/slice-036c-revert/agent-mutate.py`, log `agent-mutate.log`, table `agent-results.md`. Caught 11 of 11. The code is the same after the run (`code-final.sha256` OK).

| Id | Mutation | Caught by |
| --- | --- | --- |
| C1 | assumed pass on each compiler of D | l0 `oracledomain` |
| C2 | an inferred fact replaces the assumed pass | l0 `oracledomain` |
| C3 | the hint is the newest nightly | l0 `oracledomain` |
| C4 | `Wide` for a failure with no probe cause | l0 `oracledomain` |
| C5 | `Wide` for a `Pairs` of `Allowed` | l0 `oracledomain` |
| C6 | `Off` does not ask for D before a lookup round | l0 `oracledomain` |
| C7 | H not in D is not degraded to `[H]` | l0 `oracledomain` |
| C8 | the hint does not accept a header that was not read | l0 `oracledomain` |
| C9 | the option `stop using` is repeated | l0 `explain` |
| C10 | `wide!` loads the keys that were looked up again | l2 `probe/dm1-domain` |
| C11 | a list without H is read as D | l2 `probe/dm1-domain` |

## Close (manager, 2026-10-24)

The code decisions are accepted (the `assume` flag, the degrade rules, the 3 `hint` rounds). The revert check caught 11 of 11 targeted mutations, so no gap rows are needed. `sha256sum -c code-final.sha256` is clean. `scripts/test.sh` exits 0 with no WARN (l0 6.8 s, l1 33.0 s). Optional downloads moved to 037. Status: done.
