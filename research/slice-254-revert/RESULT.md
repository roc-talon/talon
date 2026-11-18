# Slice 254 mutation check (test agent, TW12, 2026-11-18)

Script: `mutate.sh` (mirror under `.tmp/slice-254-mut`, each step capped at 16G and 600 s, one mutant at a time, the shared heavy lock). Tests: the L0 driver `tests/unit/l0-5.roc` (`OwnerNoteTest`), L2 `registry/oc registry/sa registry/yf5 registry/su registry/au7`, and more groups for the mutants that touch shared code (m9: `install/ registry/`, m12: `update/ registry/`). Logs: `run.log` (all), `run2.log` (m7 and m8 again, after the gap test).

Base: l0-5 135/135. L2: all pass except `oc11-failed-no-note`, which is red against the code (the gap of Q254-9, see below). So `oc11` fails in every row, and it is not counted as a kill.

| Mutant | What it changes | Killed by |
| --- | --- | --- |
| m1 | `OwnerNote.find`: an event at the same ms as the release counts as "after" (`<=` to `<`, Q254-1) | L0 (the same-ms expect) |
| m2 | `date_text`: the day number is one day late | L0 (12 expects), L2 `oc1`, `oc2`, `oc4`, `oc5`, `oc6`, `oc8`, `oc9` |
| m3 | `date_text`: January and February get the year before (the leap-year edge, `month <= 2` to `< 2`) | L0 (`2024-02-29`) |
| m4 | `find`: no dedupe of the same (alias, name) (Q254-8) | L0 (the workspace expect) |
| m5 | `find`: no sort by alias (Q254-8) | L0, L2 `oc8-two-aliases` |
| m6 | A transfer never names the owner (always "another GitHub account", Q254-3) | L0, L2 `oc2-update-transfer` |
| m7 | A recreate also takes the owner of the successor (Q254-3: a transfer only) | SURVIVED in run 1. Gap test added: L0 expect "a recreate has no owner, also when the item is moved with a successor" (`OwnerNoteTest.roc`, last expect). Run 2: killed by L0 (1 fail); the real code passes (136/136) |
| m8 | `AuditResolve.owners!`: the `!request.offline` guard is removed (Q254-6) | Not killed: EQUIVALENT. With `--offline` the index is `Offline(origin)` (`ClosureIndex.Source`, R-IX6), never `Answer`, so the match arm `Answer(a)` is not reached and the guard is redundant. `oc7-offline` (the guard case) still checks the behavior |
| m9 | `install` also prints the owner note (Q254-5) | L2 `oc10-install-no-note` |
| m10 | The T1 sentence also with no successor (an empty successor) | L2 `sa4-add-yanked-no-successor`, `yf5-add-each-yanked`, `yf5b-add-each-yanked-version`, `yf5c-add-each-withdrawn` |
| m11 | The T2 hint is dropped for a selector with no match (Q254-12) | L2 `sa5-add-selector-moved` |
| m12 | `data.owner_changes` is written also when it is empty (T7) | L2: 12 old `update` and `outdated` `--json` cases (`al2-*`, `ap30-*`, `cv1-outdated-query`, `ef3-note-tuple`, `pb3-outdated-runs`, `rg2-default-registry`, `rg9-*`, `su11-outdated-successor`) |
| m13 | A header value that is not in the answer gives no note (Q254-2) | L0 (the unknown-hash expect) |
| m14 | Another release of the answer decides, not the release of the header value (Q254-7) | L0 (3 expects). Note: L2 `oc6` does not kill it, because the first other release in its answer (pf 0.1.0) has the same `published_at` as json 2.0.0 |

Results: 14 mutants. 12 killed in run 1, 1 killed after the gap test (m7), 1 equivalent (m8).

## The gap of Q254-9 (case `oc11-failed-no-note`)

`AuditResolve.owners!` runs in `InstallFlow.finish!` right after `AuditResolve.warn!`, before the ladder (`PatchApply.run!`, `settle!`). A failure there (here: the whole-app check of the candidate finds a new error in main.roc, exit 11) still has the owner line on stderr. Q254-9 (a) says the line is printed only when the command reaches its report. `oc11` is red against the code: 2 extra `warning: json: the repository was made again ...` lines (the plain and the `--json` run). The code agent must move the print after `settle!` (or print the kept docs at the report).
