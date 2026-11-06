# 204b Toolchain size and answers

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Follow-up of slices 204 (`cli/lib/RegistryToolchains.roc`, `cli/lib/Nightlies.roc`) and 211 (`cli/lib/ShortNames.roc`, `cli/lib/Lookup.roc`). Their open questions G-C42 to G-C44 have design answers: DESIGN.md Q340, Q222, Q223, DESIGN-CLI.md R-CV3, R-IX4, R-AD34, R-I8, DESIGN-REGISTRY.md R-AP80, R-RE4.

Part 0 (done first, because it broke the driver `l0-3` for all agents): records slice 104h made `size : U64` required in `Toolchain.Row` (after `sha256`). The row literals of `RegtoolchainsTest`, the fx answer bodies and the given `toolchains.json` files of the two L2 cases now have `size` (`1000 + log_index`, except where a case needs another value). `l0-3` compiles again.

## Rules

R-AP80, R-CV3, R-CV2, R-CV6, R-IX4, R-TF2, R-TF3, R-AD34, R-I8, R-AD4, R-AD5, R-AD7, R-SN5, R-EC2.

## Answers and where they are tested

| Question | Answer | Test |
| --- | --- | --- |
| G-C42 (Q340, 204 Q1) | The asset size is the `size` of the row. The URL is `https://github.com/roc-lang/nightlies/releases/download/<tag>/<asset_name>`. A row with size 0 is `NoAsset` (a missing size does not decode: exit 15 for a page, `Bad` for a file) | L0 `from_rows` (sizes 1001 to 1004, a size 0 row), `parse_file` and `page` with a missing size, a text size and a negative size. L2 `cv1-registry-nightlies`: the size column of all runs, run 7 (size 0 row) |
| G-C43 (Q222, 204 Q2) | No `get/` copy and no freshness rule | Already tested by slice 204 (no `get/` file in the calls of `ap5-toolchain-rows`) |
| G-C43 (Q222, 204 Q3) | A file with a newer `format` is not read and not written. Talon reads the list from `after=0` into memory. The file stays | L2 `ap5-toolchain-rows` run 13 (origin 17): `after=0`, no write, no delete, no warning. Run 14: offline gives `missing` |
| G-C43 (Q222, 204 Q5) | Unknown members of the file and of a row are kept on write (R-TF2) | L2 `ap5-toolchain-rows` run 12 (origin 16): `note` in the top object, `more` and `flag` in a row. They stay in the written file |
| G-C43 (Q222, 204 Q6) | Two rows of one tag and target: the smaller log index is the record, also when the list has the later row first. A later row with another sha256 is the R-CV6 mismatch (`changed` and `dropped`, exit 16 where a command names the tag) | L0 `from_rows` (list in both orders), L0 `row_changes` (4 groups of rows). L2 `cv1-registry-nightlies` run 7 |
| G-C44 (Q223, 211 Q1) | Several failing short names give ONE exit-2 stop that lists each failing name, also for `tln add` (scope `Install`) and for `Tool` and `X` | L0 `Lookup.registry_all` (3 failing of 4, one failing, `Tool`). L2 `sn7-short-answers` runs 2, 3, 4, 5 |
| G-C44 (Q223, 211 Q2) | A selector stays with the name: `parser@^2` goes on as `<owner>/roc-parser@^2` | L0 `registry_all` (the `ref` of an entry). L2 `sn7-short-answers` run 1 |
| G-C44 (Q223, 211 Q3) | A failed `?q=` read gives no suggestion, and the stop stays exit 2 | L2 `sn7-short-answers` run 3 (`?q=qf` answers 500) |

## Public signatures (changed or new)

| Name | Change |
| --- | --- |
| `Nightlies.row_changes` | New, stub `crash "todo: slice 204b"`. `{ host : Host, rows : List(RegistryToolchains.Row) } -> List(Facts.Change)`. The doc has the rules |
| `Lookup.registry_all` | New, stub `crash "todo: slice 204b"`. `Scope, List({ ref : Ref, found : ShortNames.Found }) -> Try(List({ ref : Ref, lookup : Lookup, matched : Try(Str, [None]) }), { fail : Fail, block : Str })`. The doc has the table |
| `Nightlies.from_rows` (changed, not stubbed) | The asset has `size` = the row size, and a row with size 0 is `Err(NoAsset)`. Of two rows of one tag and target, the one with the smaller `log_index` counts (the list can have them in any order). Today the code gives size 0 and the first row of the list |
| `Nightlies.list_registry!` (changed, not stubbed) | `changed` is the result of `Facts.pin_all!` and then `Nightlies.row_changes` of the visible rows. `releases` and `dropped` follow `without_changed` as before |
| `RegistryToolchains.list!` (changed, not stubbed) | The written file keeps the unknown members of the top object and of the kept rows. A newer `format` is as before (no write). The text form is a decision, see below |
| L2 word `toolchains` (test code) | The row line has the size at the end: `row <log> <tag> <target> <asset_name> <sha256> <published_at> <size>` |
| L2 word `shorts` (test code) | New word of `tests/commands/L2Registry.roc`. As `short`, with one `Lookup.registry_all` for all asked names |

The L0 test calls `Nightlies.row_changes` and `Lookup.registry_all`. `registry_pins` keeps its signature (`{ host, releases }`): the pin of a later row is not in it, the change is `row_changes`.

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/RegtoolchainsTest.roc` (driver `l0-3.roc`): 2 new `expect`s and 4 changed. `r_text` and the row literals have `size`. `parse_file` and `page` have 3 and 1 new bad texts (missing, text and negative size). `from_rows`: sizes from the rows, a size 0 row is `NoAsset`. New: two rows of one tag and target in both orders. New: `row_changes` (a later row with another sha256, the same sha256, other target, a tag that is no nightly, a bad sha256, size 0, an unsafe name, the order of the changes, the list in any order) | R-AP80, R-CV3, R-CV6, R-IX4, R-AP51, R-NS1 |
| L0 | `tests/unit/ShortnamesTest.roc` (driver `l0-2.roc`): 1 new `expect`: `Lookup.registry_all` (no failing name with a selector, one failing name next to a match, 3 failing of 4 with 2 blocks and a name with no block, `Tool` with 2 names, no name) | R-I8, R-AD34, R-AD4, R-AD5, R-AD7, R-EC2 |
| L2 | `registry/ap5-toolchain-rows`: runs 12 to 14 and the size column | R-TF2, R-TF3, R-AP80, R-IX4 |
| L2 | `registry/cv1-registry-nightlies`: run 7 (origin 11) and the size of all releases | R-AP80, R-CV3, R-CV6, R-IX4 |
| L2 | `registry/sn7-short-answers` (new, word `shorts`): 5 runs | R-I8, R-AD34, R-AD4, R-AD5, R-AD7, R-SN5, R-EC2 |

## Decisions that the design does not fix (for the review)

| # | Decision | Rejected |
| --- | --- | --- |
| 1 | The two rows of one tag and target are a separate pure function `Nightlies.row_changes`, because `Facts.first_seen_all` sees one new pin for them (the second is `New` and is skipped). `list_registry!` adds its result to `changed` (the same type, so `without_changed` drops the tag) | A change of `Facts.first_seen_all`. A list of pins with 2 rows for one key |
| 2 | Only the rows that count in `row_changes` are those that can be assets: target of the host, nightly tag, safe `asset_name`, size above 0, sha256 of 64 lower-case hex digits. A row that is not an asset is not a mismatch | Count every row |
| 3 | `row_changes` looks at the rows that `visible` leaves (as the pins: a hidden row is not seen, Q4 of slice 204) | All rows |
| 4 | Unknown members are written after the known members, in their original order, in the top object (after `rows`) and in each kept row (after `log_index`). A new row has none. The given test file has them in this place already, so a code that keeps their place also passes | Keep the place in the object (more code, same bytes here) |
| 5 | The text of the stop for 2 or more failing names: `<n> short names are not identified: "<x1>", "<x2>". Use the full name (owner/repo) of each.` for all scopes. The block of each failing name stays (the same blocks as for one name), in the order of the command. A name that matches is not in the stop | A line for each name. A line for `Tool` and `X` with other words |
| 6 | One failing name gives the `Err` of `Lookup.registry` unchanged, also when other names match | The text of the plural form for 1 name |
| 7 | `registry_all` gives the `ref` to go on with (form `Full`, the matched name, the selector of the typed ref), not a change of `lookup`. `New(name)` stays as it is | A selector in `New`. A selector in the matched line |
| 8 | The `?short=` request has the name only, with no selector (as `short_path` of slice 211) | The selector in the request |
| 9 | `registry_all` for `Tool` and `X` always fails (R-AD7), so a command with 2 tool names gets the combined stop | Test only `Install` |

## Output (proposed, TW24)

| Case | Kind | Text |
| --- | --- | --- |
| 2 or more short names not identified | usage (2), blocks then line | the blocks of `Lookup.registry` of each failing name, then `<n> short names are not identified: "<x1>", "<x2>". Use the full name (owner/repo) of each.` |

`--json`: no `data` field in this slice. A failed `?q=` read has no new text.

## Out of scope

| Item | Reason |
| --- | --- |
| The flows of `tln install`, `tln add`, `tln tool install` and `tln x` that call `registry_all`, and the exit 16 of a command that names a changed tag | Slice 206 and the command slices. The L2 words stand in |
| The Worker side of `size` (R-AP80, the 422 for size 0) | Slice 109b |
| A row with size 0 as the first row of a tag and a later valid row | The design says an asset with size 0 is not an asset. No test for the pair |

## Questions (stop until answered)

None. The old questions of 204 (Q1 to Q3, Q5, Q6) and of 211 (Q1 to Q3) are answered above.

## Red result

| Layer | Result |
| --- | --- |
| L0 `l0-3` (`roc test tests/unit/l0-3.roc --no-cache`) | Compiles. 104 expects: 101 pass, 3 fail. `from_rows` (size 0 instead of the size of the row), the new two-row `from_rows` (size 0, so the right sha256 but the wrong size), `row_changes` (`todo: slice 204b`). Log `.../scratchpad/204b-red-l0-3.log` |
| L0 `l0-2` | 87 expects: 86 pass, 1 fail: `registry_all` (`todo: slice 204b`). Log `.../scratchpad/204b-red-l0-2.log` |
| L2 (`tests/commands/run.sh registry/`) | `ap5-toolchain-rows` fails: the file of origin 16 loses `note`, `more` and `flag` (runs 13 and 14 pass: the code already does that). `cv1-registry-nightlies` fails: size 0 in all releases, and run 7 (a size 0 row is an asset, no `changed` line). `sn7-short-answers` fails with `[ROC CRASHED] todo: slice 204b`. `sn6-short-names` passes. Log `.../scratchpad/204b-red-l2.log` |

## Revert check

A private reference (green: l0-2 87 of 87, l0-3 104 of 104, the 3 L2 cases pass with it, and `sn6` too) was run in a copy of the repo. Mutations of it, each caught:

| # | Mutation | L0 | L2 |
| --- | --- | --- | --- |
| M1 | `from_rows` keeps the first row of the list, not the smaller log index | fail | fail (`cv1`: the compat and file differ) |
| M3 | A size 0 row is an asset | fail | fail (`cv1`) |
| M4 | `list_registry!` does not add `row_changes` to `changed` | pass | fail (`cv1` run 7) |
| M5 | The write drops the unknown members | pass | fail (`ap5` run 12) |
| M6 | The stop for 2 or more names has the block of the first failing name only | fail | fail (`sn7`) |
| M7 | `registry_all` drops the selector of the ref | fail | fail (`sn7` run 1) |

The reference and the mutation script are deleted. `research/slice-204b-revert/before/` has the files that the slice changed and `NEW.txt`.

## Code result (code agent)

| Check | Result |
| --- | --- |
| L0 `l0-2` | 87 of 87 pass |
| L0 `l0-3` | 104 of 104 pass |
| `tests/commands/run.sh registry/` | 6 passed, 0 failed (`ap5-toolchain-rows`, `cv1-registry-nightlies`, `sn7-short-answers`, `sn6-short-names`) |
| `scripts/test.sh check` | pass |
| `scripts/test.sh l2` | 246 passed, 17 failed: only `ptool/*` (16) and `gc/gc6-prebuilt-entries` (other agents) |

Files: `cli/lib/Nightlies.roc`, `cli/lib/RegistryToolchains.roc`, `cli/lib/Lookup.roc`. Copies in `research/slice-204b-revert/code-final/`.
New public names (not in the slice list): `RegistryToolchains.file_extras` (the text of the unknown members of a file) and `RegistryToolchains.file_text_keep` (the file text with those members). `file_text` stays as it was. Decision: `from_rows` keeps the place of the tag of the first row in the list and replaces the row by a row with a smaller `log_index`. No disputes. No revert check by the code agent (the manager has not asked for it in this task).

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK (Nightlies, RegistryToolchains, Lookup) |
| Tests (code agent) | l0-2 87 of 87, l0-3 104 of 104, `registry/*` 6 of 6, `check` passes. L2 246 pass. The 17 failures are `ptool/*` and `gc/gc6` (slices 092 and 093). |
| Expected exits (manager check) | `sn7-short-answers`: 4 runs exit 2, all R-I8 short-name stops. `cv1`: none. |
| Revert check | Test step: M1, M3 to M7 caught. |
| Note | `Lookup.roc` changed after slice 211 closed (`registry_all`), so the 211 code-final hash of `Lookup.roc` is replaced by this one. |
