# 255 Audit warnings only on success, and one text for the each-yanked stop

Phase: P2. Status: tests (red), 2026-11-18. The user ordered the two fixes on 2026-11-18 (after slice 254, commit 748682ae).
Design ids (confirmed by TalonRegistry): slice 255, Design Q635, G-C265.
Test agent: 2026-11-18. No product code.

## 1. Decisions (the order of the user, no question)

| # | Decision | Before |
| --- | --- | --- |
| D1 (strict, the user 2026-11-18) | The R-AU7 and R-AU14 warning lines of a resolve (`warning: <...>. Fix: <fix>.`, `warning: json: moved to acme/roc-json. Run: tln update json`) are printed only after the whole command succeeds: after the check (the ladder), the consent of the held moves and the writes. They are printed at the point of the R-PU30 owner lines (after `settle!`), just before them. A failure of any step (the check, a declined or refused consent, a patch, a write) prints the error and no warning line. The `--json` member `data.audit_warnings` is not changed (a failed run has `data: null`). | `warn!` printed before the ladder (slice 249). The first fix of slice 255 printed after the ladder but before the consent and the writes. |
| D2 | One text for the stop of R-AD35 step 2 (Design Q630-3, R-B3) and R-PU29: `<name> has no release that Talon can use: each release is yanked or withdrawn.` The successor sentence (` Its successor is <s>. Run: tln add <s>`) is added only when the `repos` item has a successor (slice 254, T1). | With no successor: `... each release is yanked.` (slice 250). With a successor: `... each release is yanked or withdrawn. Its successor is ...` (slice 254). |

## 2. Scope: where the code is today

| Item | Where | Commands |
| --- | --- | --- |
| D1 | `InstallFlow.finish!` line 435: `AuditResolve.warn!` runs after `ResolveBase.closure_notes!`, before `PatchApply.run!` and `settle!` (the ladder, the consent of the held moves, the writes). The owner lines already wait for `settle!` (`AuditResolve.print_owners!`, slice 254 fix). | each command that reaches `InstallFlow.finish!`: `install`, `install <names>`, `add`, `update`, `upgrade`. R-AU7 (1) also names `init`; `Init.roc` does not call `InstallFlow` directly, so the code agent checks its path (no `init` failure case here) |
| D1 | `VerifyFlow.roc` line 111: `AuditResolve.warn!` runs before `Ladder.verify!`. | `verify` |
| D1 | The R-AU6/R-FE10 message of a download 404 (`AuditResolve.explain`) is an error text, not a warning line. It does not change. | |
| D2 | `FullName.each_yanked` (the text), used by `PickFlow.each_yanked_fail` when the item has no successor. `FullName.each_yanked_moved` has the new text already. | `add`, `install <names>` |
| D2 | No other site has the old text: `cli/`, `tests/` (grep `each release is yanked`). `ToolFlow` and `Init` have their own texts. | |

No existing L2 or L3 case has an R-AU7/R-AU14 line on stderr together with a failing run (checked: every case whose stderr has `Fix: ` or `Run: tln update` exits 0 in each run). So D1 changes no expected file; it needs new cases.

Limit of D1 (a note for the review): a line that is printed late can come after other stderr lines of the same run. In a `--json` run of a changed project, `check: skipped` (the ladder step) now comes before the warning, and with a held move the `~ <alias>: ... (held)` and `writes` lines come before it. When the command fails, the user sees no R-AU7 line: a failure caused by a finding (for example the download 404 of a deleted release) still has its own error text (R-AU6, R-FE10).

## 3. Tests

| Layer | Case | Checks | Red state |
| --- | --- | --- | --- |
| L2 | `registry/au7-failed-no-warning` (new) | `update json` with the check. pf (acme/pfx) is `moved` to acme/pfx2, so the resolve has the R-AU14 line. The whole-app check of the candidate (json 2.0.1) finds a new error in main.roc: exit 11. Stderr has the error only. Run 2 `--json`: the same | fails: 2 extra `warning: pf: moved to acme/pfx2. Run: tln update pf` lines |
| L2 | `registry/au7-verify-failed-no-warning` (new) | The same for `tln verify` (`VerifyFlow`) | fails: the same 2 lines |
| L2 | `registry/yf5-add-each-yanked`, `yf5b-add-each-yanked-version` (run 2), `yf5c-add-each-withdrawn`, `sa4-add-yanked-no-successor` (changed by hand) | The D2 text with no successor | fail: the old text |
| L0 | `tests/unit/YankfilterTest.roc` (driver l0-1): the `each_yanked` text expect changed; one new expect for `each_yanked_moved` (the same sentence, then the successor sentence) | D2 | the `each_yanked` expect fails (1); the new expect passes (a guard of slice 254) |
| L2 | `registry/au7-consent-refused-no-warning` (new) | The fixtures of `au7-held-move` (a repo-missing finding for json), no `--dry-run`: the held move of pf needs consent, the run is not interactive: exit 13. Stderr: the held-move lines and the consent error, no R-AU7 line. Run 2 `--json`: the same (closure answers 3 and 4 repeat 1 and 2) | fails: the R-AU7 line before the held-move lines (2 extra lines) |
| L2 | `registry/au7-held-move`, `update/au7-direct-held-move` (changed by hand, D1 strict) | The order: the held-move lines and `writes` first, then the R-AU7 line | fail: the R-AU7 line comes first |
| L2 | `registry/sa1-add-moved` run 2 `--json` (changed by hand) | The order: `check: skipped`, then the R-AU14 line | fails: the line comes before `check: skipped` |
| L2 | `registry/au7-write-conflict-no-warning` (new, mutation gap n3) | `update json` with the check; pf moved (R-AU14 on success). A concurrent edit of the header after the build probe makes the write stop: exit 17 (R-CC7). No R-AU14 line | passes with the code of slice 255; red with the mutant that prints before `write!` |
| L2 guards | `registry/oc11-failed-no-note` (slice 254) passes; the au7 success cases (`au7-install-warnings`, `au7-ignore`, `su1` run 1, `sa1`) keep the lines | D1 on success | pass |

Not written: a separate `add` or `upgrade` failure case for D1. They run the same `InstallFlow.finish!` step as `update`; the code agent fixes one site. A mutant that moves the print for one command only is not possible there.

## 4. Red state (test agent, 2026-11-18)

| Run | Result |
| --- | --- |
| L0 `tests/unit/l0-1.roc` | 228 pass, 1 fail (`YankfilterTest.roc:110`, the old `each_yanked` text) |
| L2 `tests/commands/run.sh` (all) | 745 pass, 6 fail: `au7-failed-no-warning`, `au7-verify-failed-no-warning`, `sa4`, `yf5`, `yf5b`, `yf5c`. Each fails on stderr only |
| `roc fmt --check` | `YankfilterTest.roc` valid |

The `calls.log` and `tree.diff` of the 2 new cases are the calls of the code (the warning sends no request). stdout and stderr are written by hand.

Red state after D1 strict (test agent, 2026-11-18, against the first fix of the code agent): L2 748 pass, 4 fail: `au7-consent-refused-no-warning`, `au7-held-move`, `sa1-add-moved`, `update/au7-direct-held-move`. Each fails on stderr only (the place of the R-AU7/R-AU14 line). The cases of the first red state (`au7-failed-no-warning`, `au7-verify-failed-no-warning`, `sa4`, `yf5`, `yf5b`, `yf5c`) pass with that fix. The other cases with an R-AU7 line (`au7-install-warnings`, `au7-ignore`, `au7-transitive`, `yf1`, `su1`, `su6`, `su14`, `oc2`, `verify/au7-direct`, `update/au7-direct-series`, `update/au7-direct-offline`) print nothing on stderr after the line in the same run, so their files do not change. No L3 case has an R-AU7 line.

Mutation check: `research/slice-255-revert/RESULT.md` (6 mutants, all killed; n3 after the gap case above).

## 5. Conflict check with the design

No conflict. The design does not say that the R-AU7/R-AU14 lines print after a failure: CLI R-AU7 (5) says "on stderr, kept with `--json` and `--quiet`", and "the warning does not change the exit code". The index notes of Registry R-AP30 are printed "also after an error"; that is another rule, and this slice does not change it. One effect to know: when a command fails because of a finding (for example the download 404 of a deleted release), the user sees the R-AU6/R-FE10 error text, not the warning line.

## 6. Design text changes (for TalonRegistry)

| Spot | Old | New |
| --- | --- | --- |
| `DESIGN-CLI.md` R-AU7 (5) | `... on stderr, kept with --json and --quiet.` | `... on stderr, kept with --json and --quiet. The lines are printed only when the command succeeds: after the check, the consents and the writes, just before the owner lines of Registry R-PU30. A command that fails prints its error and no line (Design Q635; the owner note, Q634 (9)).` |
| `DESIGN-CLI.md` R-AU14 | none | `The moved line follows R-AU7 (5): only when the command succeeds (Design Q635).` |
| `DESIGN.md` Q630 row, item (3) | `exit 2, <name> has no release that Talon can use: each release is yanked.` | `exit 2, <name> has no release that Talon can use: each release is yanked or withdrawn. (text changed by Design Q635)` |
| `DESIGN-CLI.md` R-B3 | no text given | no change (R-B3 names no text) |
| `DESIGN-REGISTRY.md` R-PU29 | `the message names the successor` | no change; Q634 T1 already has `yanked or withdrawn` |
| `DESIGN.md`, a new row | none | `Q635 \| G-C265: the R-AU7/R-AU14 lines after a failed command, and the text of the each-yanked stop (CLI slice 255)? \| Decided by the user, 2026-11-18. (1) The R-AU7 and R-AU14 lines print only when the command succeeds: after the check, the consents and the writes, just before the owner lines (Q634 (9)). (2) One text: <name> has no release that Talon can use: each release is yanked or withdrawn., and the successor sentence only with a successor. \|` |
| `docs/slices/254-add-moved-owner-note.md` N2 | the two texts differ | resolved by slice 255 |

## 7. Plan row (for `docs/slices/PLAN-P2-CLI.md`)

| 255 | Audit warnings only on success, one each-yanked text | Tests for R-AU7, R-AU14 (the lines only on success, `InstallFlow.finish!` and `VerifyFlow`), R-AD35 step 2 / R-B3 / R-PU29 (one text in `FullName.each_yanked`) | R-AU7, R-AU14, R-PU29, R-B3 | G-C265 (Design Q635) | 249, 250, 254 / none | 20 | Sonnet |
