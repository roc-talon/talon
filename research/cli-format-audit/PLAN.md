# CLI state formats: design proposals and work plan

Date: 2026-11-08. Input: REPORT.md (findings F1 to F15). Two design agents, then the manager merged and checked the code facts.

Limits from the user: the CLI has no users yet, so breaking changes are allowed now. No `format` or `user_version` bump. No complex rules for small gains.

## 1. Two general rules

| Rule | Text (proposal) | Covers |
| --- | --- | --- |
| R-TF2 (changed): locked meaning | A release never changes the meaning of a field, a table column or a key in place. A changed meaning gets a new field or column name. A new enum word is a new field. A release does not change `format` or `user_version` unless the design shows that the other way gives a worse UX (user decision 2026-11-08). R-TF3 stays as it is for a newer number. | F6, F7, most of F1 |
| R-TF8 (new): unknown values | Hand-edited TOML: an unknown key gives a warning and is kept on rewrite. A known key with an unknown value form gives exit 19 plus the hint line. Files Talon writes (JSON, `compat.db` rows): an unknown field is kept. An item with an unknown enum word is not used, kept unchanged, and listed as "needs a newer tln". A command that targets that item gives exit 19 plus the hint. The other items work. | F2, F3, F4, F8, F11, F13 |

Hint line (TW24 proposal): `A newer tln can know this value. Update tln: tln tool update talon`

## 2. Decisions for each finding

| Id | Decision | Rule |
| --- | --- | --- |
| F1 | The project record step (commands and `roc` proxy) never stops on `projects.json` of kind `input`. It warns and writes nothing. GC still gives exit 19. | R-TF9 (new) |
| F2 | `ToolsJson.Source` gets `Unknown(Str)`. Listed as "needs a newer tln". Kept on write. A targeted command gives exit 19. `tool update` with no key skips it with a warning. | R-TF8 |
| F3, F13 | Keep exit 19 for an unknown value form. Add the hint line. | R-TF4, R-TF8 |
| F3 dead end | `tln tool update talon` (cli/lib/ToolManageFlow.roc:98) reads `config.toml` and every `tools.json` entry, so the fix that the message gives also stops. Self-update reads `config.toml` leniently (bad value: warning, key unset) and never stops on an unknown tool entry. | R-TF8 |
| F4 | A `bin` key that is not a known target gives a warning and is kept (removed with the whole table at a new `url`). | R-PT18 (changed) |
| F5 | A bump is rare (R-TF2). The repair after a bump still fails, as R-TF3 accepts. Also: `tln setup` replaces a `talon` entry of `tools.json` that it cannot read (cli/lib/SetupFlow.roc:206, :246), so the `install.sh --version` repair works. | R-TF2, setup rule |
| F6 | A changed column meaning is a new column. A changed table key is a `user_version` bump that the design must justify (R-TF2). | R-TF7 (added) |
| F7 | All `.talon.json` readers use one function. A newer `format` reads as "no fields" (time unknown, GC keeps it). `Link.target` keeps exit 19. | R-TF3 (added) |
| F8 | A write of a `[tools]` entry keeps each key that Talon does not know. | R-PT3, R-PT19 |
| F9 | One format constant for each file kind. No `migrate` function (no bump will come). | none |
| F10 | The dir lock is a contract between releases. A later mechanism is taken in addition, never instead. | R-CC12, R-CC3 |
| F11 | No change. A row with an unknown word is not used, and the next write replaces it (it is a cache of a measurement). | R-TF7 note |
| F12 | No change. The report was wrong: cli/lib/PathRoc.roc:179 keeps unknown row fields in `extra`. | none |
| F14 | No code. Write down: an unknown `toolchains/` name form is not listed, not selected, never removed. | R-GC5 |
| F15 | No code. Freeze the temp name forms in the design (adds `.stale` and `.locks`, which the code has: cli/lib/Temp.roc:42). | R-CC2 |

## 3. Work items

The design text goes to TalonRegistry first (my agents do not edit DESIGN*.md). Each code item is a normal slice: red test, review, code, mutations.

| # | Slice | Findings | Size | Depends on |
| --- | --- | --- | --- | --- |
| D | Design text: R-TF2, R-TF3, R-TF4, R-TF7, R-TF8, R-TF9, R-PT18, R-PT19, R-CC2, R-CC3, R-CC12, R-GC5 | all | S | user decisions |
| 230 | One format constant per file kind | F9 | S | D |
| 231 | Hint line on R-TF4 value failures. Lenient self-update. | F3, F13 | S | D |
| 232 | `tools.json` unknown source kind. Setup replaces an unreadable `talon` entry. | F2, F5 | M | 231 |
| 233 | `[tools]`: unknown `bin` targets and unknown subkeys are kept | F4, F8 | S | D |
| 234 | The project record step never stops | F1 | S | D |
| 235 | One `.talon.json` reader. L2 test for foreign toolchain dirs (F14). | F7, F14 | S | 230 |
| 236 | `tln` version gate in `talon.toml` (accepted 2026-11-08) | F3 | M | 231 |

Test-only additions: F11 (L0, a `timeout` row reads as no fact) goes into 232. F15 (L0, `Temp.old` forms) goes into 230. The F9 grep lint is dropped: `scripts/test.sh` is out of scope for CLI agents, and the constants are enough.

## 4. User decisions (2026-11-08)

| Point | Decision |
| --- | --- |
| Freeze `format` at 1 | No. Lock the meaning of each field. No version change unless the design shows that the UX is worse without it. |
| R-TF9 for all record steps | Yes |
| 236 version gate | Yes. A later release can remove it: an older tln that knows the key still checks it, and a newer tln that drops it gives only the unknown-key warning. |
