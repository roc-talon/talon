# 210 Index notes

Phase: P2 (CLI client). Status: done (2026-11-03).

Plan row 210 of `PLAN-P2-CLI.md`. With a registry, a stale `checked` item of the closure answer gives one note in `tln update`, `tln outdated` and `tln add`: `index: <owner>/<repo> checked <age> ago`, or `index: <owner>/<repo> not checked since its first ingest` (R-AP29, R-AP30). `--json` gets a `notes[]` element of kind `index-stale` (a proposal).

## Scope

| In | Out (where) |
| --- | --- |
| New module `cli/lib/IndexNotes.roc` (in `main.roc`): `age_text`, `note`, `json_note`, `notes`, `json_notes` (pure) | The print of the notes in a whole `update`, `outdated` or `add` run with a registry (the call of `notes` on the answer, stderr, `--quiet` of R-FL4, the place in `data`): slice 206b (no command can select a registry before 206b and 224). Not chosen here |
| The note text, the age, the JSON note, which items give a note | No L2 case: no flow is needed for these decisions |
| | `repos` states in a command (see Q1) |

## Rules

R-AP29, R-AP30, R-AP32 (Q1: no test), R-AP64 (the source of `checked`, slice 206). As used: R-AP50 (milliseconds), R-OUT2.

## Decisions (pure, L0)

| Name | Signature | Rule |
| --- | --- | --- |
| `IndexNotes.age_text` | `U64 -> Str` | R-AP30 (proposal) |
| `IndexNotes.note` | `{ now, item : Wire.Checked } -> Try(Str, [Fresh])` | R-AP29, R-AP30 |
| `IndexNotes.json_note` | `{ now, item } -> Try(JsonDoc, [Fresh])` | R-AP30 (proposal) |
| `IndexNotes.notes` | `{ now, answers : List(Wire.Answer) } -> List(Str)` | R-AP30, Q408 |
| `IndexNotes.json_notes` | `{ now, answers } -> List(JsonDoc)` | R-AP30, Q408 |
| `IndexNotes.index_notes` | `{ now, answers } -> Try(JsonDoc, [None])` | R-AP30, Q407 (the member `data.index_notes`, none when empty) |

Tested reading:

| # | Topic | Reading |
| --- | --- | --- |
| 1 | Who gets a note | Only `stale` decides. Fresh: no note, also with an old or a null `checked_at` (the Worker computes `stale`, R-AP29). Stale with a recent time: a note, age `0m` |
| 2 | Text | `stale` and a time: `index: <name> checked <age> ago`. `stale` and null: `index: <name> not checked since its first ingest`. `<name>` is the `name` of the item |
| 3 | Time | `checked_at` is milliseconds (R-AP50), `now` is seconds. A time after `now` is age 0 |
| 4 | Age (proposal) | Days from 86400 s, else hours from 3600 s, else minutes; rounds down; `3d`, `5h`, `12m`, `0m` |
| 5 | JSON (proposal) | `{"kind":"index-stale","name":..,"checked_at":<ms or null>,"text":<the note>}` |
| 6 | Answers (Q408) | 1 or 2 answers. One note for each repository, sorted by name (bytes). With 2 stale items of one name: the older `checked_at`, null oldest. A fresh and a stale item: the stale one. No item: none |
| 7 | Member (Q407) | `index_notes`: the array of `json_notes`, or `Err(None)` with no note |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/IndexnotesTest.roc` (driver `l0-3.roc`), 14 `expect`s: the age units and borders; the text with a time (d, h, m, ms remainder); null time; `stale` alone decides; a future time; `notes` (order, fresh left out); empty and all fresh; `json_note` (render, null, fresh); `json_notes`; Q408: same name in 2 answers (older time, both orders), null against a time, fresh against stale, sort by name across answers; Q407: `index_notes` member and none | R-AP29, R-AP30, R-AP50, Q407, Q408 |

Not tested (moved to slice 206b, no choice made): the notes inside a real `update`, `outdated` or `add` run: the stream (stderr), `--quiet` (R-FL4: hides notes), the exit code (R-AP30: unchanged), the place of `json_notes` in the `--json` `data`, `--offline` and `direct` (no answer: no note).

## Red result

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-3.roc` | 104 pass, 14 fail: each `IndexnotesTest` expect, `todo: slice 210` |
| `scripts/test.sh check fmt` | pass |

## Revert check

`research/slice-210-revert/` (`before/`, `results.txt`). A private reference was green (113 of 113), then 6 mutations, each caught by L0: M1 no hour unit, M2 `stale` ignored, M3 milliseconds not divided, M4 JSON time in seconds, M5 notes in reverse order, M6 future time wraps. After Q407 and Q408: a private reference (green, 118 of 118) and 5 more mutations (M7 newer time wins, M8 null not oldest, M9 no sort, M10 fresh item counts, M11 member always present), each caught; the reference is deleted (TW18).

## Output (proposed, R-OUT2)

| Case | Text |
| --- | --- |
| Stale, with a time | `index: someone/roc-json checked 3d ago` (the text of R-AP30; the age format is the proposal) |
| Stale, null | `index: someone/roc-json not checked since its first ingest` |
| `--json` | an element of `notes[]`: `{"kind":"index-stale","name","checked_at","text"}` |

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | R-AP32 (`repos` states): the rules that show a `state` or a successor are R-PU28 (`outdated` shows `moved to <successor>`, `update` with no names prints `json: moved to acme/roc-json. Run: tln update json`) and R-PU29 (`add` of a moved name), and the plan puts R-PU28 to R-PU30 in P3. Does slice 210 do them, or only the stale notes? No test and no stub now | Answered (Design Q406, Registry R-AP30): no `repos` state in P2. No test, no stub. The decoder of `repos` stays unread here |
| Q2 | `--json` `notes`: today `Report.data` has `notes` as a list of texts. R-AP30 says `notes[]` kind `index-stale`, so an element has a kind. Do all elements of `notes` become objects with `kind` and `text`, or do the index notes go in a second list? The L0 test fixes only the element, not its place | Answered (Design Q407, Registry R-AP30): a second list. `json_notes` stays and its element is as tested; the place is `data.index_notes`, left out when empty. `notes` stays a list of texts and each index note text is also in it (the call is slice 206b). Test change: none in this slice. Cost for the other slices: none, no pinned `--json` output has the new member. A check in 206b that `index_notes` is absent with no stale item |
| Q3 | A held move has 2 answers (R-AP16, second query), each with `checked`. One note for each repository: from the first answer, from the second, or from the older `checked_at`? `notes` takes one answer | Answered (Design Q408, Registry R-AP30): one note for each repository from the stale item with the older `checked_at`, `null` oldest. Test change: `notes` and `json_notes` take `answers : List(Wire.Answer)` (the list has 1 or 2 answers) in place of one `answer`, and L0 gets 4 `expect`s: the same name stale in both (the older time), null against a time, fresh and stale (the stale), and the order by name. The first and second `answer` of the held move are joined by the caller (206b) |
| Q4 | The age format (`3d`, `5h`, `12m`) and `0m` under one minute: the design gives none (a proposal for review) | Accepted (Design Q407): the age text `3d`, `5h`, `12m`, `0m` and the JSON keys `kind`, `name`, `checked_at` (ms or null), `text` agree with the design |

## Code

| File | Change |
| --- | --- |
| `cli/lib/IndexNotes.roc` | The 6 stubs (`crash "todo: slice 210"`) |
| `cli/lib/main.roc` | `IndexNotes` in the package list |
| `tests/unit/IndexnotesTest.roc`, `tests/unit/l0-3.roc` | The L0 tests and the driver import |

## Code (code agent)

| Item | Result |
| --- | --- |
| `cli/lib/IndexNotes.roc` | The 6 stubs have bodies. Helpers `picked` (stale items of all answers, sorted by name, one for each name, older `checked_at` wins, null oldest) and `older` |
| `tests/unit/l0-3.roc` | 118 of 118 pass |
| `scripts/test.sh check l0 l2 l3` | pass |
| Compiler note | `json_note` as `match IndexNotes.note(..) { Ok .. Err(Fresh) .. }` made the compiler crash (SIGSEGV, post-check `arc`). The form `text = IndexNotes.note(..)?` works |

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-210-revert/code-final.sha256` | 1 of 1 OK |
| `todo: slice 210` in `cli/` | None |
| L0 | `l0-3` 118 of 118 (`IndexnotesTest`). `scripts/test.sh l0` fails only in `l0-4` and `l0-5`, on slice 209 red tests (`EvidenceTest`, `MatrixTest`). |
| `scripts/test.sh check l2 l3` | Pass. `fmt` fails only on the slice 209 files `Evidence.roc` and `Matrix.roc` (in progress). |
| L2 cases | None (no flow in this slice) |
| Revert check | 11 mutations. M10 (a fresh item counts) was not re-run at the test step; the manager ran it by hand on the final code: caught by `IndexnotesTest.roc:106`. Code restored, hash OK. |
| Design answers | Q406, Q407, Q408; Q4 text proposals accepted |
| Compiler note | A `match` on `IndexNotes.note(..)` with `Err(Fresh) => Err(Fresh)` crashed the compiler (SIGSEGV in `arc`); `?` works. |
| Moved out | Slice 206b: the notes inside a real `update`, `outdated`, `add` run, and `index_notes` in `data`. |

