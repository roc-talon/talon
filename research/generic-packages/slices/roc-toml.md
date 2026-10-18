# roc-toml: TOML 1.0.0 parse, print and span edit

Phase: P0 (generic packages, Design 7). Status: done, 0.1.0 released (2026-10-16). Review 1: Q1 to Q10 settled with the proposals, the output proposals and D8 (vendored toml-test) accepted. After review 1: Q14 answered (one nightly, 10-14), Q11 to Q13 settled by the slice proposals, human to confirm. Next: the code agent, slice 1.

| Item | Value |
| --- | --- |
| Repository | `../roc-toml/` (future `github.com/Karakatiza666/roc-toml`), `git init -b main`, no commit |
| Compiler | `nightly-2026-10-14-38a3029` for all checks and CI (Q14), in `.roc-version`. roc-fuzz 0.4.3 targets fail on 10-15 (`research/generic-packages/nightly-1015-check/`). In round 2 the files also passed check, fmt and test on 10-15. |
| Spec | TOML 1.0.0 (https://toml.io/en/v1.0.0), RFC 3339 for dates and times |
| Design rows | R-PK4 (Design 6.1), R-GA5 (6.2), R-H1 (4.2, the model of the span edit), R-GP1 to R-GP7 |
| Uses in Talon (not in the API, R-GP1) | `talon.toml` (Design 4.3, 4.4, Resolution 6, 7), `config.toml` (CLI 6.1 R-LY3), R-TF4 (exit 19, file, line, key), R-CC6 and R-CC7 (span edit, byte compare), R-AD25 and R-AD26 (add a key, create the file), R-RV1 (remove a key), R-NI1 (rename a key) |
| Dependency | roc-parser 2.0.0: `https://github.com/lukewilliamboswell/roc-parser/releases/download/2.0.0/7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW.tar.zst` (R-GA5). The stubs do not import it. |
| roc-parser check | A package module that imports `parser.Parser` and `parser.Utf8` and parses with them (`probes/roc-toml/parser-import/package/Probe.roc`): `roc check` exit 0 with no warning and `roc test` pass on 10-14 and on 10-15. Only `Yaml.roc` of roc-parser has the "redundant expose" error (Design 2), and nothing imports it. |
| Probes | `research/generic-packages/probes/roc-toml/`: `Value.roc` (compiler facts on 10-09, 12 pass), `floats.roc` (each F64 literal in the tests equals `F64.from_str` of its text, 33 pass), `check_cases.py` (hand cases against Python `tomllib`: 165 cases, 7 differ: 3 i64 range cases that Python accepts, 3 second-60 cases (Q9) and 1 BOM case (Q10) that `tomllib` rejects; the 63 expected texts of `edit.roc` and `entries.roc` are all valid TOML), `parser-import/` (the roc-parser check) |

## Slices (TW19)

| # | Slice | Functions | Code estimate | Tests | Talon needs |
| --- | --- | --- | --- | --- | --- |
| 1 | Value forms | `Toml.parse` (the value grammar), `Toml.get`, `Value.is_eq` | 350 to 400 lines | `tests/values.roc` | First, with slice 2: every Talon command reads `talon.toml` and `config.toml` |
| 2 | Structure | `Toml.parse` (keys, tables, arrays of tables, BOM, errors), `Toml.table` | 300 to 400 lines | `tests/structure.roc`, `tests/toml_test_valid.roc`, `tests/toml_test_invalid.roc`, `fuzz/parse-total.roc` | First, with slice 1 |
| 3 | Print | `Value.print`, `Toml.print` | 150 to 250 lines | `tests/print.roc`, `tests/toml_test_roundtrip.roc`, `fuzz/print-roundtrip.roc` | Second: slices 4 and 5 write `Value.print` text, and a new file is `Toml.print` (Q2) |
| 4 | Span edit of values | `Toml.to_str`, `Toml.replace`, `Toml.line` | 150 to 250 lines | `tests/edit.roc`, `fuzz/text-kept.roc`, `fuzz/replace-span.roc` | Third: R-TF4 (line), R-CC6, R-CC7, `tln add` and `update` write ranges (R-AD22) |
| 5 | Whole entries | `Toml.insert`, `Toml.remove`, `Toml.rename` | 250 to 350 lines | `tests/entries.roc`, `fuzz/remove-entry.roc` | Fourth: R-AD25, R-AD26 (insert, new file), R-RV1 (remove), R-NI1 (rename) |

Order of work: 1, 2, 3, 4, 5. Each slice is green when its files pass.

## Public API (`package/main.roc` exposes `Toml`, `Value`)

| Function | Signature | Slice |
| --- | --- | --- |
| `Value` | `Value := [String(Str), Integer(I64), Float(F64), Boolean(Bool), OffsetDateTime({ date : { year : U16, month : U8, day : U8 }, time : { hour : U8, minute : U8, second : U8, nanosecond : U32 }, offset_minutes : I16 }), LocalDateTime({ date, time }), LocalDate({ year, month, day }), LocalTime({ hour, minute, second, nanosecond }), Array(List(Value)), Table(Dict(Str, Value))]` | 1 |
| `Value.is_eq` | `Value, Value -> Bool` (structural, two NaN are equal) | 1 |
| `Value.print` | `Value -> Str` (one line, the text after `key = `) | 3 |
| `Toml` | `Toml :: { text : Str, table : Dict(Str, Value) }` (opaque, the code agent can change the backing) | 1 |
| `Toml.parse` | `Str -> Try(Toml, [TomlErr({ line : U64, column : U64, message : Str })])` | 1, 2 |
| `Toml.table` | `Toml -> Dict(Str, Value)` | 2 |
| `Toml.get` | `Toml, List(Str) -> Try(Value, [NotFound])` | 1 |
| `Toml.print` | `Dict(Str, Value) -> Str` | 3 |
| `Toml.to_str` | `Toml -> Str` | 4 |
| `Toml.replace` | `Toml, List(Str), Value -> Try(Toml, [NoEntry])` | 4 |
| `Toml.line` | `Toml, List(Str) -> Try(U64, [NoEntry])` | 4 |
| `Toml.insert` | `Toml, List(Str), Value -> Try(Toml, [KeyExists, NotATable])` | 5 |
| `Toml.remove` | `Toml, List(Str) -> Try(Toml, [NoEntry])` | 5 |
| `Toml.rename` | `Toml, List(Str), Str -> Try(Toml, [NoEntry, KeyExists])` | 5 |

The doc comments in `package/Value.roc` and `package/Toml.roc` are the contract of each function. They now include the settled answers (Q1 to Q10).

## Rules

R-PK4, R-GA5, R-H1 (as the model), R-GP1, R-GP2, R-GP5, R-GP7. TESTING.md 4 row "toml": `parse(print(doc)) == doc`, parse never crashes. The settled answers Q1 to Q10 below.

## Tests

All tests use the public API only (LAYOUT LP1). Each `expect` has a comment with its id and its source. New in round 2: marked "new".

| Layer | File | Cases (`expect`) | Ids | Source | Slice |
| --- | --- | --- | --- | --- | --- |
| L0 | `tests/values.roc` | 108 (6 new) | V-STR1 to V-STR15, V-INT1 to V-INT7, V-FLT1 to V-FLT6, V-EQ1 to V-EQ3, V-BOOL1, V-DT1 to V-DT12, V-ARR1 to V-ARR5, V-INL1 to V-INL4, V-VAL1. New: V-STR15 (Q8, 2 cases), V-DT12 (Q9, 4 cases) | TOML 1.0.0 value sections; RFC 3339; D2, D3; Q8, Q9 | 1 |
| L0 | `tests/structure.roc` | 65 | S-DOC1 to S-DOC5, S-BOM1 to S-BOM4 (Q10; S-BOM4: U+FEFF in a comment), S-DEEP1 to S-DEEP4 (nesting limit, N1), S-COM1, S-COM2, S-KV1 to S-KV3, S-KEY1 to S-KEY10, S-TBL1 to S-TBL9, S-INL1 to S-INL3, S-AOT1 to S-AOT5, S-ERR1 to S-ERR3, S-GET1 to S-GET5, S-USE1 | TOML 1.0.0 structure sections; D5, D11; Q10; S-USE1 is a file in the form of Design 4.3 with neutral keys | 2 |
| L0 | `tests/toml_test_valid.roc` (generated) | 205 | TT-VALID | toml-test v2.2.0 `valid/` of `files-toml-1.0.0` | 2 |
| L0 | `tests/toml_test_invalid.roc` (generated) | 463 | TT-INVALID | toml-test v2.2.0 `invalid/` of `files-toml-1.0.0`, UTF-8 only | 2 |
| L0 | `tests/print.roc` | 48 | P-STR1 to P-STR5, P-INT1, P-FLT1, P-FLT2, P-BOOL1, P-DT1, P-DT2, P-ARR1, P-INL1, P-KEY1, P-DOC1 to P-DOC10, P-RT1 | The accepted print format; P-RT1 is TESTING.md 4 | 3 |
| L0 | `tests/toml_test_roundtrip.roc` (generated) | 205 | TT-ROUND | TESTING.md 4 for each toml-test valid case | 3 |
| L0 | `tests/edit.roc` | 37 (13 new) | E-TXT1, E-BOM1 (new, Q10), E-KIND1 to E-KIND3 (new, Q6, 6 cases), E-KIND4 to E-KIND7 (new, Q13, 6 cases), E-REP1 to E-REP11, E-NO1 to E-NO4, E-LINE1 to E-LINE3 | R-H1, R-PK4, D7, Q6, Q10, Q13 | 4 |
| L0 | `tests/entries.roc` (new) | 54 | I-SEC1 to I-SEC3, I-KEY1, I-EOF1, I-CRLF1, I-DOT1, I-INL1 to I-INL3, I-NEW1 to I-NEW4, I-ROOT1 to I-ROOT4, I-VAL1, I-ERR1, I-ERR2, I-GET1 (insert, 30 cases); DEL1 to DEL12 (remove, 15 cases); REN1 to REN7 (rename, 9 cases) | R-H1 ("whole entries"), Q1 to Q5, Q7, Q11, Q12 | 5 |
| L1 | `fuzz/parse-total.roc` | 1 target | F-TOTAL | TESTING.md 4: parse never crashes | 2 |
| L1 | `fuzz/print-roundtrip.roc` | 1 target | F-ROUND | TESTING.md 4 | 3 |
| L1 | `fuzz/text-kept.roc` | 1 target | F-TEXT | R-H1: `parse(s).to_str() == s` | 4 |
| L1 | `fuzz/replace-span.roc` | 1 target | F-SPAN | R-H1: `replace` of each root scalar key: new table, text parses to it, lines before and after the entry stay | 4 |
| L1 | `fuzz/remove-entry.roc` (new) | 1 target | F-REMOVE | R-H1, Q4: `remove` of each root scalar key: table without the key, text parses to it, lines before the entry stay | 5 |

Total: 1196 L0 `expect`s, 5 L1 targets. On 10-14: each test and fuzz file passes `roc check` (exit 0, no warning) and `roc fmt --check`, each L0 file fails with "todo" only (0 passed, 0 compiler errors, no warning), and each L1 target builds and stops with exit 77 ("[roc crashed] todo").

`scripts/test.sh [ROC [FUZZ_ROC]]`: `ROC` (default `roc` on `PATH`) runs `roc check`, `roc fmt --check` and `roc test` (output in `.work/test-<name>.log`). `FUZZ_ROC` (default `ROC`) builds and runs each fuzz target with `--runs=$RUNS --seed=1 --time=0` and the dictionary (RUNS default 100000, TW6). Exit 0 only when all pass.

`scripts/gen-toml-test.py` writes the 3 generated files from `tests/fixtures/toml-test/`. Do not edit the generated files.

Test round after verify (2026-10-16): 11 `expect`s for the 5 gaps and M8 of "Verify results". Each fails with its mutation alone (`tools/mutate-roc-toml.py`), and `package/` is the same after.

| Ids | File | Checks | Mutation caught |
| --- | --- | --- | --- |
| S-ERR4 (3 cases) | `structure.roc` | Exact line and column: `v = 01` gives (1, 6), line 3 gives (3, 6), an indented line gives (2, 3) | M30, M31 |
| S-ERR5 | `structure.roc` | A BOM counts 3 bytes in the column: (1, 9) | M30, M33 |
| E-LINE4 (4 cases) | `edit.roc` | `Toml.line` of a key with a multi-line array or string, and of the key after it | M61 |
| DEL13 | `entries.roc` | Remove of the first entry keeps the BOM | M82 |
| V-INT8 (2 cases) | `values.roc` | `0b102`, `0b2` are errors | M8 |

Counts now: values 110, structure 69, edit 41, entries 55.

## Output (accepted at review round 1)

| Item | Format | Tests |
| --- | --- | --- |
| String | Basic string. `\b \t \n \f \r \" \\`. Other control characters `\uXXXX` (uppercase hex). Other characters as they are. | P-STR1 to P-STR5 |
| Integer | Decimal | P-INT1 |
| Float | `F64.to_str`, plus `.0` when the text has no `.` and no `e`. `inf`, `-inf`, `nan`. | P-FLT1, P-FLT2 |
| Date and time | `T` as separator, `Z` for offset 0, fraction only when not 0, no trailing zeros | P-DT1, P-DT2 |
| Array | `[1, "a"]`, `[]` | P-ARR1 |
| Inline table | `{ a = 1, b = 2 }`, `{}` | P-INL1 |
| Key | Bare when it is not empty and has only `A-Z a-z 0-9 _ -`, else a basic string | P-KEY1, P-DOC9, I-KEY1, REN3 |
| Document | Values first, then `[a.b]` sections, then `[[a.b]]` sections. No header for a non-empty table with only sub-tables. A blank line before each header, not at the start. `\n` line ends. Empty table: empty text. | P-DOC1 to P-DOC10 |
| Error | `TomlErr({ line, column, message })`, 1-based, the column counts bytes, the message text is free | S-ERR1 to S-ERR3 |

## Decisions (accepted at review round 1)

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | One nominal tag union `Value`. A table is `Dict(Str, Value)` (equality ignores the order). | `List((Str, Value))`: order-sensitive equality breaks the round trip. Tags for inline table or string kinds: not a value difference. |
| D2 | `Value.is_eq` by hand: two NaN are equal. | Derived `is_eq`: `F64.nan == F64.nan` is false on this compiler. |
| D3 | Nanoseconds (`U32`), more digits truncated. Offset in minutes (`I16`). | Milliseconds only. The source text of a date. |
| D4 | `Toml.parse` takes `Str`. 11 toml-test cases that are not UTF-8 are not written. | `List(U8)` |
| D5 | Error `[TomlErr({ line, column, message })]` | A tag for each error kind |
| D6 | Two public modules, `Value` (transparent) and `Toml` (opaque) | One module |
| D7 | `replace` and `line` work on `key = value` entries only (`NoEntry` else) | A general `set` |
| D8 | Vendor toml-test v2.2.0 (`files-toml-1.0.0`, 884 files, commit `ce08da1ddb075d1c7596d663c7fcba9a2ae02c5c`, MIT, `tests/fixtures/toml-test/LICENSE` and `SOURCE`), a script makes the test apps | Hand cases only; a JSON compare in Roc; toml-test `main` |
| D9 | Test files by slice | One file per module |
| D10 | L1 with `Fuzz.str` and a TOML token dictionary, no seed corpus | A typed `Value` generator; a corpus of TOML files |
| D11 | `Toml.get` paths are keys only, the empty path is the root | An index into arrays |
| D12 | LICENSE UPL-1.0 (table LIC). The toml-test notice is outside `package/`. | |

## Settled (review round 1, 2026-10-16: "use your slice proposals")

| # | Question | Answer | Where |
| --- | --- | --- | --- |
| Q1 | Insert a key into a table that has a `[t]` header: position and form | After the last entry of the `[t]` section, before the blank lines and comments that follow it. Text `key = value`, bare key when possible. A section with no entry: after its header line. | `Toml.insert`; I-SEC1 to I-SEC3, I-KEY1, I-EOF1, I-VAL1, I-ERR1 |
| Q2 | Insert into a table that is not in the text, or into a new file | A new `[t]` header at the end of the text, with one blank line before it, also for `[a.b]` when `[a]` exists. A new file (the empty text) is `Toml.print` of the table. | I-NEW1 to I-NEW4 |
| Q3 | Insert into a table made by dotted keys, an inline table, or an array of tables | Dotted keys: a new dotted line after the last one with that prefix. Inline table: `, key = value` after its last value. A table that is only a parent of other tables: as Q2. Array of tables: error `NotATable`. | I-DOT1, I-INL1, I-NEW3, I-ERR2 |
| Q4 | Remove an entry | The lines of the entry go, with the same-line comment and the newline. Comment lines above and an empty header stay. In an inline table: the entry, the comma after it and the spaces after that comma; for the last entry, from the comma before it. | `Toml.remove`; DEL1 to DEL11, F-REMOVE |
| Q5 | Rename a key | Only the bytes of the last key change, bare when possible. `KeyExists` when the table has the new key. | `Toml.rename`; REN1 to REN7 |
| Q6 | `replace` of a literal or multi-line string | Keep the kind when the new string can be written in it, else a basic string. Tests: one-line literal strings only (see Q13). | `Toml.replace` doc; E-KIND1 to E-KIND3 |
| Q7 | Newline of an inserted line | The newline of the first line end in the text, else `\n` | I-CRLF1, I-EOF1 |
| Q8 | CRLF inside a multi-line string | Kept in the value (`\r\n`) | V-STR15 |
| Q9 | Second 60 | Accepted on any date. Second 61 is an error. | V-DT12 |
| Q10 | BOM at the start | Skipped at the start only, and kept by `to_str`. A BOM in another place outside strings and comments is an error. In a comment it is valid (TOML 1.0.0 "Comment": only control characters are not permitted). | S-BOM1 to S-BOM4, E-BOM1 |

## Settled by slice proposal, after review 1 (human to confirm)

The human: "for the rest of the questions, use the slice proposals". Q14 the human answered.

| # | Question | Answer | Where |
| --- | --- | --- | --- |
| Q11 | Insert into the root table (no header, for example a top-level key of a config file) | With root entries: as Q1, after the last root entry, before the blank lines and comments after it. With no root entry and a header: on a new line before the first header, after the comment lines and blank lines directly above it, with a blank line between the new line and the header. With no root entry and no header: at the end of the text (this last row is an addition to the proposal: the proposal had no case without a header). | `Toml.insert` doc; I-ROOT1 to I-ROOT4 |
| Q12 | Inline table edge cases | `{}` becomes `{ key = value }`. A missing table under an inline table is a dotted key in it: `a = { x = 1 }`, path `a.b.c`, gives `{ x = 1, b.c = value }`. The only entry goes with the spaces around it: `{ a = 1 }` becomes `{}`. | `Toml.insert`, `Toml.remove` docs; I-INL2, I-INL3, DEL12 |
| Q13 | `replace` of an old multi-line string | Multi-line basic: no newline after the opening quotes, a raw newline for each newline of the string, the other characters as `Value.print`. Multi-line literal: kept when the new string has no `'''` and no control character other than tab and newline, else multi-line basic. | `Toml.replace` doc; E-KIND4 to E-KIND7 |
| Q14 | The nightly | The human: `nightly-2026-10-14-38a3029` for all checks and CI, one nightly. `.roc-version` has it. | `.roc-version`, `scripts/test.sh` |

## Proposals of the code agent (human to confirm)

| # | Item | Proposal | Reason | Tests |
| --- | --- | --- | --- | --- |
| N1 | Nesting limit | `Toml.parse` gives `TomlErr` when arrays and inline tables nest more than 128 levels. A pre-scan in `package/Internal/Doc.roc` counts them and skips strings and comments. TOML 1.0.0 gives no limit. | About 500 levels overflow the stack, and "parse never crashes" (TESTING.md 4) fails | S-DEEP1 (128 arrays parse), S-DEEP2 (129 arrays: error), S-DEEP3 (129 inline tables: error), S-DEEP4 (200 `[` in a string and in a comment do not count). Revert check: with the limit at 127, S-DEEP1 fails. |

## Questions (stop until answered, TW17)

| # | Question | Blocks | Proposal |
| --- | --- | --- | --- |
| Q15 | Q13 and Q8 together: in a CRLF file, the raw newline of Q13 is `\r\n` (the newline of `insert`), and Q8 keeps a CRLF in the value, so the value after `replace` is not the new value (`"a\nb"` reads back as `"a\r\nb"`). Also, a new string that starts with a newline loses it, because TOML trims a newline right after the opening quotes. No test covers these two cases. | `Toml.replace` of a multi-line string in a CRLF file, or with a new string that starts with a newline | A raw newline is always `\n` in the value text. A new string that starts with a newline gets one more newline after the opening quotes. |

## Design gaps (a design row that is wrong or incomplete)

| # | Row | Gap | Proposed change |
| --- | --- | --- | --- |
| G1 | R-CC7 | "each span that Talon edits has the same text (... in `talon.toml` each table that Talon changes)". A TOML table is not one span: dotted keys, `[a]` and `[a.b]` in other places, inline tables. | "each entry that Talon changes has the same text, and each table that Talon adds a key to has the same value (`Toml.get`)" |
| G2 | R-PK4 | R-TF4 needs the line of a key. R-PK4 lists parse, print and span edit only. | Add "and the line of each entry" to R-PK4 (`Toml.line`). |
| G3 | R-H1, R-PK4 | The settled Q1 to Q7 and Q11 to Q13 are TOML edit rules that the design does not state. | Add a TOML row next to R-H1 (or to R-PK4): insert position (Q1, Q2, Q3, Q11, Q12), remove extent (Q4, Q12), rename (Q5), the string kind on replace (Q6, Q13), the newline of a new line (Q7). Then R-AD25 ("creates the file") points to Q2: a new file is the print of the table. |
| G4 | R-TF4 | With Q10, a `talon.toml` or `config.toml` with a BOM at the start is valid. With Q8, a CRLF in a multi-line string is kept. R-TF4 says "not valid TOML" gives exit 19. | Add to R-TF4: "Talon reads a BOM at the start of the file and keeps it when it writes the file (roc-toml Q10)." |
| G5 | R-TF4 | With Q9, a time with second 60 is valid on any date. No Talon key is a time, so no Talon effect. | None. Record it in the roc-toml README. |
| G7 | R-GP5, TESTING.md 1 | Q14: the generic packages run on `nightly-2026-10-14-38a3029`, but R-GP5 says "the nightly that Talon pins" and LAYOUT.md has `nightly-2026-10-09-258ab27`. | Move the Talon pin (and LAYOUT.md) to 10-14, or name 10-14 in R-GP5 for the generic packages. |
| G6 | R-RV1, R-NI1 | R-RV1 removes "its `talon.toml` key and its `[overrides]` entry", R-NI1 renames a key. Q4 and Q5 fix the bytes. | Name Q4 in R-RV1 and Q5 in R-NI1 (as G3). |

## Proposed first version

`0.1.0` when slices 1 to 5 are green: the review asked for insert, remove and rename in the first release. Q15 is open only for a multi-line string in a CRLF file or with a leading newline; if it is not answered by then, `0.1.0` documents that case.

## Disputes (from the code agent)

None.

## Verify results

Verify agent, 2026-10-16, `nightly-2026-10-14-38a3029`. Script: `research/generic-packages/tools/mutate-roc-toml.py` (one mutation at a time, the L0 file(s) of the slice, and the fuzz target of the rule with 20000 runs and the dictionary). A mutation that the slice files do not catch was run again on all 8 L0 files (`ALL=1`). A fuzz leak report would get a `--no-cache` build again: no mutation gave one.

| Step | Result |
| --- | --- |
| 1 `scripts/test.sh` (clean `.work`) | Exit 0, ALL PASS, 2 min 1 s. `edit` 37, `entries` 54, `print` 48, `structure` 65, `toml_test_invalid` 463, `toml_test_roundtrip` 205, `toml_test_valid` 205, `values` 108 (1185 pass). Fuzz 100000 runs each: `parse-total`, `print-roundtrip`, `remove-entry`, `replace-span`, `text-kept` pass. |
| 2 `roc check package/main.roc` | 0 errors, 0 warnings |
| 3 `roc bundle` | `CjBfRJDXtoAKWh9P9p2qcumkDM8DWUbLqCu5UFYnoutG.tar.zst` (20188 bytes). Files: `main.roc`, `Toml.roc`, `Value.roc`, `Internal/Doc.roc`, `Internal/Edit.roc`, `Internal/Grammar.roc`, `Internal/Print.roc`, `Internal/Text.roc`, `Internal/Tree.roc`. Package files only. |
| 4 Revert check | 82 mutations: 75 caught (M8 only by `toml_test_invalid.roc`, M54 only by `replace-span`). 7 not caught: 5 gaps (M30, M31, M33, M61, M82), 2 equivalent or probably equivalent (M63, M28). |
| 5 R-GP1 grep | 1 match, in a comment, not in the API: `package/Internal/Grammar.roc:19` "probes/roc-toml/llvm-build in the Talon repository". The check "no match" fails on this line. |
| Restore | `diff -r package/ <copy from step 0>`: no difference. `.roc-fuzz/` put back from the copy of step 0 (`diff -r`: no difference). |

### Gaps (a rule that no test checks)

| Mutation | Rule | Behavior that no test checks | Probe |
| --- | --- | --- | --- |
| M30, M31 | Output "Error": the column is 1-based, in bytes (S-ERR1 to S-ERR3 check `line` only) | `column` of an error on line 1 and on a later line | `probes/roc-toml/verify-gaps.roc`: passes on the code, fails on M30, M31 |
| M33 | Q10 and Output "Error": the column counts the BOM bytes | `column` of an error in a file with a BOM | same probe, fails on M30, M33 |
| M61 | `Toml.line`: the line of the first byte of the key (R-TF4) | the line of an entry whose value has more than one line | same probe, fails on M61 |
| M82 | Q10 (`to_str` keeps the BOM) with Q4 (`remove`) | remove of the first entry of a file with a BOM keeps the BOM | same probe, fails on M82 |

Observation (not a gap of the tests): the error column is at the start of the line where the line parse stopped (`a = ?` gives line 1, column 1; with a BOM, column 4). The doc of `Toml.parse` says "where the parser stopped", so this agrees with the contract, but the column does not point to the bad byte.

### Mutations

| # | Mutation | File and line | Test that failed |
| --- | --- | --- | --- |
| M1 | V-STR2 escape \f gives U+000B | `Internal/Grammar.roc:305` | values.roc: 1 failed V-STR2 |
| M2 | V-STR5 surrogate \uD800 accepted | `Internal/Grammar.roc:332` | values.roc: 1 failed V-STR5 |
| M3 | ml literal: newline after ''' kept | `Internal/Grammar.roc:261` | values.roc: 1 failed V-STR12 |
| M4 | ml string: 5 quotes at close not accepted | `Internal/Grammar.roc:376` | values.roc: 1 failed V-STR11 |
| M5 | V-STR15 (Q8) CRLF in ml string becomes LF | `Internal/Grammar.roc:685` | values.roc: 2 failed V-STR15 |
| M6 | hex integer read as base 8 | `Internal/Grammar.roc:398` | values.roc: 3 failed V-INT5 V-INT7 |
| M7 | octal integer read as base 10 | `Internal/Grammar.roc:401` | values.roc: 1 failed V-INT5 |
| M8 | binary digit 2 accepted | `Internal/Grammar.roc:528` | not caught by `values.roc`; caught by `toml_test_invalid.roc` (1 TT-INVALID) in the second pass |
| M9 | double underscore accepted | `Internal/Grammar.roc:505` | values.roc: 1 failed V-INT3 |
| M10 | i64 range: radix overflow wraps | `Internal/Grammar.roc:512` | values.roc: 1 failed V-INT7 |
| M11 | leading zero accepted in decimal | `Internal/Grammar.roc:477` | values.roc: 3 failed V-FLT5 V-INT4 |
| M12 | -inf reads as inf | `Internal/Grammar.roc:431` | values.roc: 1 failed V-FLT3 |
| M13 | exponent sign dropped | `Internal/Grammar.roc:457` | values.roc: 2 failed V-FLT1 |
| M14 | offset minutes: hour * 100 | `Internal/Grammar.roc:620` | values.roc: 2 failed V-DT1 V-DT2 |
| M15 | nanoseconds rounded, not truncated | `Internal/Grammar.roc:640` | values.roc: 1 failed V-DT4 |
| M16 | V-DT12 (Q9) second 60 rejected | `Internal/Grammar.roc:659` | values.roc: 3 failed V-DT12 |
| M17 | V-DT12 (Q9) second 61 accepted | `Internal/Grammar.roc:659` | values.roc: 1 failed V-DT12 |
| M18 | leap year: every 4th year | `Internal/Grammar.roc:668` | values.roc: 1 failed V-DT8 |
| M19 | offset date-time and local date-time order | `Internal/Grammar.roc:542` | values.roc: 6 failed V-DT1 V-DT12 V-DT2 V-DT3 V-DT4 |
| M20 | Value.is_eq: NaN not equal | `Value.roc:65` | values.roc: 1 failed V-EQ1 |
| M21 | empty array not accepted | `Internal/Grammar.roc:183` | values.roc: 1 failed V-ARR4 |
| M22 | newline accepted in inline table | `Internal/Grammar.roc:214` | values.roc: 1 failed V-INL3 |
| M23 | array trailing comma not accepted | `Internal/Grammar.roc:181` | values.roc: 1 failed V-ARR3 |
| M24 | Toml.get: empty path is NotFound | `Toml.roc:36` | structure.roc: 1 failed S-GET3 |
| M25 | dotted key: no whitespace around the dot | `Internal/Grammar.roc:112` | structure.roc: 2 failed S-KEY4 S-TBL2 |
| M26 | table defined twice accepted | `Internal/Tree.roc:75` | structure.roc: 2 failed S-TBL4 S-TBL7; toml_test_invalid.roc: 10 failed TT-INVALID |
| M27 | key defined twice accepted | `Internal/Tree.roc:113` | structure.roc: 4 failed S-ERR1 S-INL2 S-KEY5 S-KEY6; toml_test_invalid.roc: 15 failed TT-INVALID |
| M28 | dotted key adds to a table of another section | `Internal/Tree.roc:135` | not caught (probably equivalent: no input found where a dotted key reaches a `Dotted(n)` table of another section; also not caught by all 8 L0 files) |
| M29 | [[a]] keys go to the first element | `Internal/Tree.roc:82` | structure.roc: 2 failed S-AOT1 S-AOT2 |
| M30 | error column on line 1 is 0-based | `Internal/Doc.roc:64` | not caught (gap: no test reads `column`) |
| M31 | error column after newline off by one | `Internal/Doc.roc:63` | not caught (gap: no test reads `column`) |
| M32 | error line is 0-based | `Internal/Doc.roc:53` | structure.roc: 3 failed S-ERR1 S-ERR2 S-ERR3 |
| M33 | error offset ignores the BOM | `Internal/Doc.roc:75` | not caught (gap: no test reads `column` of an error in a file with a BOM) |
| M34 | BOM not skipped | `Internal/Doc.roc:68` | structure.roc: 1 failed S-BOM1 |
| M35 | S-BOM4 BOM in a comment rejected | `Internal/Grammar.roc:705` | structure.roc: 1 failed S-BOM4 |
| M36 | N1 nesting limit 129 | `Internal/Doc.roc:178` | structure.roc: 2 failed S-DEEP2 S-DEEP3 |
| M37 | N1 nesting limit 127 | `Internal/Doc.roc:178` | structure.roc: 1 failed S-DEEP1 |
| M38 | S-DEEP4 '[' in a comment counts | `Internal/Doc.roc:224` | structure.roc: 1 failed S-DEEP4 |
| M39 | lone CR is a newline | `Internal/Grammar.roc:685` | structure.roc: 1 failed S-DOC4; toml_test_invalid.roc: 2 failed TT-INVALID |
| M40 | [a] after [[a]] accepted | `Internal/Tree.roc:76` | structure.roc: 1 failed S-AOT5; toml_test_invalid.roc: 1 failed TT-INVALID |
| M41 | print: U+007F not escaped | `Internal/Text.roc:28` | print.roc: 2 failed P-RT1 P-STR4 |
| M42 | print: lowercase hex in \u | `Internal/Text.roc:63` | print.roc: 1 failed P-STR4 |
| M43 | print: float without .0 | `Value.roc:122` | print.roc: 3 failed P-FLT1 P-RT1; print-roundtrip: parse(print(table)) is not the table |
| M44 | print: trailing zeros of fraction kept | `Value.roc:138` | print.roc: 2 failed P-DT1 P-DT2 |
| M45 | print: offset 0 as +00:00 | `Value.roc:144` | print.roc: 1 failed P-DT1 |
| M46 | print: offset sign reversed | `Value.roc:148` | print.roc: 2 failed P-DT1 |
| M47 | print: no header for an empty table | `Internal/Print.roc:41` | print.roc: 1 failed P-DOC5; print-roundtrip: parse(print(table)) is not the table |
| M48 | print: no blank line before a header | `Internal/Print.roc:14` | print.roc: 3 failed P-DOC3 P-DOC6 P-DOC7 |
| M49 | print: '-' not a bare key byte | `Internal/Text.roc:24` | print.roc: 1 failed P-KEY1 |
| M50 | print: sections before values | `Internal/Print.roc:48` | print.roc: 3 failed P-DOC3 P-DOC7 P-RT1; print-roundtrip: parse(print(table)) is not the table |
| M51 | print: inf as Infinity sign lost | `Value.roc:119` | print.roc: 1 failed P-FLT2; print-roundtrip: parse(print(table)) is not the table |
| M52 | to_str gives the print | `Toml.roc:53` | edit.roc: 15 failed E-BOM1 E-KIND1 E-KIND4 E-KIND5 E-KIND6 E-REP1 E-REP10 E-REP3 ...; text-kept: to_str is not the parsed text |
| M53 | E-BOM1 to_str drops the BOM | `Toml.roc:24` | edit.roc: 1 failed E-BOM1 |
| M54 | replace changes the byte before the value | `Internal/Edit.roc:16` | replace-span: roc-toml: the edited text does not parse (line 1: unexpected input) |
| M55 | replace eats the same-line comment | `Internal/Edit.roc:16` | edit.roc: 5 failed E-KIND1 E-REP1 E-REP3 E-REP4 E-REP5; replace-span: a line after the entry changed |
| M56 | Q6 literal string not kept | `Internal/Edit.roc:181` | edit.roc: 2 failed E-KIND1 |
| M57 | Q6 literal kept with a control character | `Internal/Edit.roc:196` | edit.roc: 1 failed E-KIND2 |
| M58 | Q13 ml literal read as literal | `Internal/Edit.roc:158` | edit.roc: 3 failed E-KIND5 E-KIND6 |
| M59 | Q13 ml basic: newline as \n | `Internal/Text.roc:56` | edit.roc: 1 failed E-KIND4 |
| M60 | Q13 ml literal kept with ''' | `Internal/Edit.roc:199` | edit.roc: 1 failed E-KIND6 |
| M61 | Toml.line gives the line of the value end | `Internal/Edit.roc:23` | not caught (gap: E-LINE1 to E-LINE3 use one-line values only) |
| M62 | NoEntry: path into an array of tables | `Internal/Edit.roc:71` | edit.roc: 1 failed E-NO4 |
| M63 | NoEntry: the empty path | `Internal/Edit.roc:68` | not caught (equivalent: no entry has an empty path, so `find` gives `NoEntry` anyway) |
| M64 | Q1 insert after the header, not the last entry | `Internal/Edit.roc:336` | entries.roc: 5 failed I-CRLF1 I-EOF1 I-SEC1 I-SEC2 |
| M65 | Q11 root insert: no blank line before the header | `Internal/Edit.roc:320` | entries.roc: 3 failed I-ROOT2 I-ROOT4 |
| M66 | Q11 root insert: at the top, not after the comments | `Internal/Edit.roc:319` | entries.roc: 1 failed I-ROOT2 |
| M67 | Q3 inline insert: no space after comma | `Internal/Edit.roc:306` | entries.roc: 2 failed I-INL1 I-INL3 |
| M68 | Q12 {} insert: no spaces | `Internal/Edit.roc:307` | entries.roc: 1 failed I-INL2 |
| M69 | Q7 CRLF text gets LF | `Internal/Edit.roc:145` | entries.roc: 2 failed I-CRLF1 I-ROOT4 |
| M70 | Q2 new header: no blank line before it | `Internal/Edit.roc:375` | entries.roc: 4 failed I-NEW1 I-NEW2 I-NEW3 |
| M71 | insert into an array of tables not NotATable | `Internal/Edit.roc:94` | entries.roc: 2 failed I-ERR2 |
| M72 | insert of an existing key not KeyExists | `Internal/Edit.roc:223` | entries.roc: 1 failed I-ERR1 |
| M73 | Q3 dotted insert: full path, not from the section | `Internal/Edit.roc:249` | entries.roc: 1 failed I-DOT1 |
| M74 | Q4 remove keeps the same-line comment | `Internal/Edit.roc:206` | entries.roc: 7 failed DEL1 DEL2 DEL3 DEL4 DEL6 DEL7 |
| M75 | Q4 remove takes the comment line above | `Internal/Edit.roc:206` | entries.roc: 5 failed DEL1 DEL2 DEL3 DEL5 DEL6; remove-entry: the table after remove is wrong for key k |
| M76 | Q4 remove last inline entry keeps the comma | `Internal/Edit.roc:214` | entries.roc: 1 failed DEL9 |
| M77 | Q4 remove inner inline entry keeps the comma | `Internal/Edit.roc:212` | entries.roc: 1 failed DEL8 |
| M78 | Q12 remove the only inline entry keeps spaces | `Internal/Edit.roc:210` | entries.roc: 1 failed DEL12 |
| M79 | Q5 rename without KeyExists | `Internal/Edit.roc:30` | entries.roc: 1 failed REN5 |
| M80 | Q5 rename: new key always quoted | `Internal/Edit.roc:34` | entries.roc: 5 failed REN1 REN2 REN3 REN4 |
| M81 | Q5 rename changes the first key of a dotted key | `Internal/Edit.roc:33` | entries.roc: 1 failed REN2 |
| M82 | Q10 remove of the first line drops the BOM | `Internal/Edit.roc:113` | not caught (gap: no test removes the first entry of a file with a BOM) |

## Slice 6 (0.2.0)

Status: done, 0.2.0 committed in roc-toml (`cad23df`), not released. P6-1, P6-2, Q16 to Q19, C1, C2 and S-COL14: confirmed by the human (2026-10-18). 0.1.0 is released (tag `0.1.0`). Compiler: `nightly-2026-10-14-38a3029`. Code estimate: 150 to 250 lines (a value check, and error offsets in the parser).

### Scope

| # | Change | Rule |
| --- | --- | --- |
| C1 | `InvalidValue` for `replace` and `insert` | A value is invalid when it has a date or time that `Toml.parse` rejects as TOML text: year 0 to 9999, month 1 to 12, a day that the month has (leap years: divisible by 4 and not by 100, or by 400), hour 0 to 23, minute 0 to 59, second 0 to 60 (Q9), offset -1439 to 1439 minutes (RFC 3339 `time-numoffset` hour 00 to 23, minute 00 to 59, as `Toml.parse` accepts). The check looks into arrays and inline tables. On `InvalidValue` the document does not change. Today `replace` and `insert` crash on a field with too many digits, and give `Ok` for `2023-02-30` or hour 99. |
| C2 | Error columns | Syntax error: the first byte at which the text can no longer be the start of any valid TOML document; at the end of the text, one past the last byte. Rule error (a key or a table defined two times, an integer out of the i64 range, a date that does not exist): the first byte of the key or the value that breaks the rule. 1-based, in bytes, on line 1 with the BOM bytes. Today `a = ?` gives column 1 (the line start). |

### Signatures (changed: the error unions only, `package/Toml.roc`, bodies not changed)

| Function | Signature |
| --- | --- |
| `Toml.replace` | `Toml, List(Str), Value -> Try(Toml, [NoEntry, InvalidValue])` |
| `Toml.insert` | `Toml, List(Str), Value -> Try(Toml, [KeyExists, NotATable, InvalidValue])` |

The doc comments of `Toml`, `Toml.parse`, `Toml.replace` and `Toml.insert` have the C1 and C2 rules. A new tag in the error union breaks an exhaustive `match` of a caller (the helpers of `tests/edit.roc` and `tests/entries.roc` got an `InvalidValue` arm), so the release is `0.2.0`, a new series below 1.0 (Design 4.1).

### Proposals (TW24): settled by slice proposal, confirmed by the human (2026-10-18)

| # | Proposal | Rejected options |
| --- | --- | --- |
| P6-1 | Payload: bare `InvalidValue`. The rule needs only "valid or not"; the caller has the value. | `InvalidValue(List(Str))` (the path inside the value): a nested value is rare, and the caller can find it. `InvalidValue(Str)` (a message): output text with no user now, it can be added in a later series. A tag for each field (`BadMonth`, ...): a large union. |
| P6-2 | Order of checks: `NoEntry`, `KeyExists` and `NotATable` come first, then `InvalidValue`. So the error for a wrong path does not depend on the value. | `InvalidValue` first: the caller then fixes the value and gets a path error next. |

### Tests

| Layer | File | Ids | Cases | On 0.1.0 code |
| --- | --- | --- | --- | --- |
| L0 | `tests/edit.roc` | E-INV1 (year), E-INV2 (month, day, leap year), E-INV3 (hour, minute, second), E-INV4 (offset), E-INV5 (nested in an array and an inline table) | 18 | All fail: a crash (year 10000) or `Ok` where `InvalidValue` is expected |
| L0 | `tests/edit.roc` | E-INV6 (the limits are valid: 9999-12-31, 2024-02-29, second 60, offset +23:59 and -23:59), E-INV7 (`NoEntry` first) | 6 | Pass (guards) |
| L0 | `tests/entries.roc` | I-INV1 (insert in a section, in a new table, nested) | 3 | All fail: `Ok` or a crash |
| L0 | `tests/entries.roc` | I-INV2 (`KeyExists`, `NotATable` first), I-INV3 (second 60 is inserted) | 3 | Pass (guards) |
| L0 | `tests/structure.roc` | S-ERR4 (changed: 3 cases), S-ERR5 (1 changed, 2 new: the BOM) | 6 | All fail: a wrong column |
| L0 | `tests/structure.roc` | S-COL1 (a bad byte in a value, 7), S-COL2 (a value that can still grow, 1), S-COL3 (key, 2), S-COL4 (table header, 3), S-COL5 (an unclosed string or array at the end, 5), S-COL6 (a missing newline, a bare CR, 2), S-COL7 (comment, 1), S-COL8 (redefinition, 3), S-COL9 (i64, 2), S-COL10 (a date that does not exist, also in an array, 3) | 29 | 21 fail with a wrong column. 8 pass, because 0.1.0 already gives the new column: `[a]x`, `a = 1 b = 2`, `# a<U+0001>b`, the 2 key redefinitions, the 3 dates. |
| L0 | `tests/edit.roc` | E-INV8 (Q17: nanosecond 1000000000 and 4294967295 are `InvalidValue`; 999999999 is valid) | 3 | 2 fail with `Ok`; the valid case passes (guard) |
| L0 | `tests/entries.roc` | I-INV4 (Q17: insert of nanosecond 1000000000) | 1 | Fails with `Ok` |
| L0 | `tests/structure.roc` | S-COL11 (Q18: a dotted key defined two times, also `[a.b]` and in an inline table: the part that is defined again) | 4 | All fail with a wrong column |
| L0 | `tests/structure.roc` | S-COL12 (Q19: hour 24, minute 60, second 61, offset +24:00, also in an array: the start of the value) | 5 | Pass: 0.1.0 already gives the start of the value (guards) |
| L1 | `fuzz/replace-date.roc` (new) | F-DATE: replace and insert of a random date or time (year from a list with 10000 and 65535, month 0 to 13, day 0 to 32, hour 0 to 25, minute 0 to 61, second 0 to 62, nanosecond from a list with 999999999, 1000000000 and 4294967295 (Q17), offset -1500 to 1499), alone, in an array, in an inline table, on 3 base texts (LF, CRLF, dotted keys). Valid (an oracle in the target, from the C1 rule): `Ok`, the new table, the text parses to it. Invalid: `InvalidValue`. Never a crash. | 1 target | Exit 77, "replace gave Ok for an invalid value". A copy that checks only the valid values passes 50000 runs on 0.1.0, so the oracle and the old rules agree. |

Each expected column was checked by hand against the C2 rule. Examples: `v = 01` can still be the start of `v = 01:02:03`, so (1, 7); `v = 012` can still be the start of `v = 0123-01-01`, so (1, 8); `a = 1\rb = 2`: a CR can still be the start of CRLF, so the `b`, (1, 7); `a = [1,\n` ends after the newline, so (2, 1); `a = { x = 1,\n y = 2 }`: the newline, (1, 13).

Counts now: `structure.roc` 109, `edit.roc` 68, `entries.roc` 62, total L0 1270. L1: 6 targets. All other files and the old tests pass on 0.1.0.

### Settled by slice proposal (confirmed by the human, 2026-10-18)

| # | Question | Blocks | Answer (the proposal) |
| --- | --- | --- | --- |
| Q16 | `Value.print` and `Toml.print` return `Str`, so they cannot fail. Today they write each field with its digits, and `Toml.parse` rejects the text: `10000-01-01`, `2023-02-30`, `2023-00-00`, `99:00:00`, `100:00:00`, offset 1440 as `+24:00`, 6000 as `+100:00`, -32768 as `-546:08` (probe `probes/roc-toml/print-invalid/p.roc`). Keep this (the doc says "parses back to an equal table when each date in it exists"), add `Toml.print_try : Dict(Str, Value) -> Try(Str, [InvalidValue])`, or change `print`? | The print contract of 0.2.0 | No change to `print`. The doc comments of `Value.print` and `Toml.print` say: a date or time that `Toml.parse` would reject is printed with its digits, and the output does not parse. No test. |
| Q17 | A nanosecond value over 999999999: `Value.print` writes `01:02:03.1` for 1000000000, and `parse` reads it as 100000000. `parse` does not reject the text, so C1 does not make it `InvalidValue`, but the value changes. | C1 for nanoseconds | `InvalidValue` for a nanosecond over 999999999 (doc of `Toml`). E-INV8, I-INV4, F-DATE. |
| Q18 | C2 for a dotted key that is defined two times (`a.b = 1\na.b = 2`): the first byte of the whole key (column 1) or of the part that is defined again (`b`, column 3)? The same for `[a.b]` two times. No test. | C2 for dotted keys | The part that is defined again (doc of `Toml.parse`). S-COL11. |
| Q19 | C2 for hour 24, minute 60, second 61, an offset of 24 hours: a syntax error (the byte where it can no longer be valid) or a rule error (the first byte of the value)? The TOML ABNF writes them as `2DIGIT` with the range in a comment. 0.1.0 gives the start of the value. No test. | C2 for times | A rule error, the first byte of the value (doc of `Toml.parse`). S-COL12. |

### Verify results (slice 6)

Verify agent, 2026-10-16, `nightly-2026-10-14-38a3029`. Script: `research/generic-packages/tools/mutate-roc-toml.py`, extended with M83 to M119 (one mutation at a time; Check.roc mutations run `edit.roc`, `entries.roc`, `values.roc` and `replace-date`; Edit.roc and Toml.roc mutations run `edit.roc`, `entries.roc` and `replace-date`; C2 mutations run `structure.roc` and `parse-total`; fuzz 20000 runs with the dictionary). A mutation that these do not catch was run again on all 8 L0 files (`ALL=1`). The 0.1.0 gaps M30, M31 and M33 (error column) were run again.

| Step | Result |
| --- | --- |
| 1 `scripts/test.sh` (clean `.work`) | Exit 0, ALL PASS. `edit` 68, `entries` 62, `print` 48, `structure` 109, `toml_test_invalid` 463, `toml_test_roundtrip` 205, `toml_test_valid` 205, `values` 110 (1270 pass). Fuzz 100000 runs each: `parse-total`, `print-roundtrip`, `remove-entry`, `replace-date`, `replace-span`, `text-kept` pass. |
| 1a Time of the fast set (TW20: 3 min) | Run 1 (clean `.work`): 2 min 39 s. Run 2 (same `.work`, compile cache): 2 min 30 s. Both in the limit; the margin is 21 s. The 6 fuzz runs are 91 s (run 1) and 92 s (run 2) of it. |
| 1b Leak on a cached rebuild | Run 1 and run 2: no fuzz log has "[roc-fuzz leak]". The 6 binaries of run 2 are byte-equal to run 1 (md5). A replay of the empty input on each run 2 binary: "Executed", no leak. |
| 1c Probe `llvm-build/twice.sh` | `SRC=<roc-toml>/.work/xdg/roc/packages`: `leak-named-thunk: build1=Executed build2=Executed` (no leak). Control `leak-lazy-cycle: build1=Executed build2=leak] 9` (the known leak, so the probe still sees it). Note: the root `.gitignore` line `llvm-build/` ignores the directory; `leak-named-thunk/` is not tracked (only `twice.sh`, `leak-lazy-cycle/` and `leak-step-function/` are), so it needs `git add -f`. |
| 2 `roc check package/main.roc` | 0 errors, 0 warnings |
| 3 `roc bundle` | `5QxzeJzCj8sTttPKVD3GCqfKZvYbVm3RV5StTRrNE8Lu.tar.zst` (22105 bytes). Files: `main.roc`, `Internal/Check.roc`, `Internal/Doc.roc`, `Internal/Edit.roc`, `Internal/Grammar.roc`, `Internal/Print.roc`, `Internal/Text.roc`, `Internal/Tree.roc`, `Toml.roc`, `Value.roc`. Package files only. |
| 4 Revert check | 37 slice 6 mutations: 36 caught (M87 only by `replace-date`), 1 not caught (M119, a gap). The 0.1.0 gaps M30, M31, M33 are now caught by S-ERR4, S-ERR5 and S-COL1 to S-COL12. |
| 5 R-GP1 grep | 1 match, in a comment, not in the API: `package/Internal/Grammar.roc:22` "probes/roc-toml/llvm-build in the" and `:23` "Talon repository". The check "no match" fails on these lines (as in 0.1.0, the line moved). |
| README | Not changed (it describes 0.1.0): `cmp` with the copy of step 0 is equal. |
| Restore | `diff -r package/ <copy from step 0>`: no difference. `tests/`, `fuzz/`: no difference. `.roc-fuzz/` put back from the copy of step 0 (`diff -r`: no difference). `dist/` has the 0.1.0 bundle `3icmt...` (built again from HEAD, the same hash) and the new `5Qxze...`. |

#### Tests added for the slice 6 gaps (test agent)

| Ids | File | Checks | Mutation caught |
| --- | --- | --- | --- |
| S-COL13 (3 cases) | `structure.roc` | A bad hex digit in `\u` (1, 10), in `\U` (1, 14), on line 2 (2, 10) | M119 (3 failed) |
| S-COL14 (2 cases) | `structure.roc` | Code agent proposal, confirmed by the human (2026-10-18): a surrogate `\uD800` and `\U00110000` give the first hex digit (1, 8) | (none planted) |
| S-COL15 | `structure.roc` | `d = 2023-11-31` is a rule error at (1, 5) | M87 |
| E-INV2 (1 more case) | `edit.roc` | `replace` with 2023-11-31 gives `InvalidValue` | M87 |

All pass on the slice 6 code. `diff -r` of `package/` after the mutations: no difference. Counts: `structure.roc` 115, `edit.roc` 69, total L0 1277.

#### Gaps (slice 6)

| Mutation | Rule | Behavior that no test checks | Probe |
| --- | --- | --- | --- |
| M119 | C2 (syntax): the first byte that no valid document can have | The column of a bad hex digit in a `\u` or `\U` escape (`a = "\u12G4"`: the code gives column 10, the `G`; the mutation gives 8, the first digit) | `probes/roc-toml/verify-gaps-s6/probe.roc`: passes on the code, 2 fail on M119 |
| M87 (L1 only) | C1 and the parse: a day that the month has | No L0 test has November 31 (or another 30-day month other than April). Only F-DATE (`replace-date`) catches it. The parse side (`d = 2023-11-31`) has no test in any L0 file. | same probe, 2 fail on M87 |

#### Mutations (slice 6)

| # | Mutation | File and line | Test that failed |
| --- | --- | --- | --- |
| M30 (again) | error column on line 1 is 0-based | `Internal/Doc.roc:63` | structure.roc: 32 failed S-COL1 to S-COL12, S-ERR4, S-ERR5 |
| M31 (again) | error column after newline off by one | `Internal/Doc.roc:62` | structure.roc: 12 failed S-COL1 S-COL5 S-COL8 S-COL11 S-ERR4 S-ERR5 |
| M33 (again) | error offset ignores the BOM | `Internal/Doc.roc:74` | structure.roc: 3 failed S-ERR5 |
| M83 | C1 year 10000 valid | `Internal/Check.roc:11` | edit.roc: 1 failed E-INV1; entries.roc: 1 failed I-INV1; replace-date: the edited text does not parse |
| M84 | C1 month 13 valid | `Internal/Check.roc:13` | edit.roc: 1 failed E-INV2; values.roc: 1 failed V-DT8; replace-date: Ok for an invalid value |
| M85 | C1 month 0 valid | `Internal/Check.roc:13` | edit.roc: 1 failed E-INV2; values.roc: 1 failed V-DT8; replace-date: Ok for an invalid value |
| M86 | C1 day 0 valid | `Internal/Check.roc:15` | edit.roc: 1 failed E-INV2; replace-date: Ok for an invalid value |
| M87 | C1 November has 31 days | `Internal/Check.roc:59` | replace-date: Ok for an invalid value. Not caught by the 8 L0 files (`ALL=1`) |
| M88 | C1 leap year: every 4th year (2100-02-29 valid) | `Internal/Check.roc:58` | edit.roc: 1 failed E-INV2; values.roc: 1 failed V-DT8 |
| M89 | C1 leap year: no 400 rule (2000-02-29 invalid) | `Internal/Check.roc:58` | values.roc: 1 failed V-DT8; replace-date: InvalidValue for a valid value |
| M90 | C1 hour 24 valid | `Internal/Check.roc:24` | edit.roc: 2 failed E-INV3 E-INV5; entries.roc: 1 failed I-INV1; values.roc: 1 failed V-DT9; replace-date |
| M91 | C1 minute 60 valid | `Internal/Check.roc:26` | edit.roc: 1 failed E-INV3; values.roc: 1 failed V-DT9; replace-date |
| M92 | C1 (Q9) second 60 invalid | `Internal/Check.roc:28` | edit.roc: 1 failed E-INV6; entries.roc: 1 failed I-INV3; values.roc: 3 failed V-DT12; replace-date |
| M93 | C1 second 61 valid | `Internal/Check.roc:28` | edit.roc: 1 failed E-INV3; values.roc: 1 failed V-DT12; replace-date |
| M94 | C1 (Q17) nanosecond 1000000000 valid | `Internal/Check.roc:30` | edit.roc: 1 failed E-INV8; entries.roc: 1 failed I-INV4; replace-date |
| M95 | C1 (Q17) nanosecond 999999999 invalid | `Internal/Check.roc:30` | edit.roc: 1 failed E-INV8; replace-date: InvalidValue for a valid value |
| M96 | C1 offset +24:00 valid | `Internal/Check.roc:38` | edit.roc: 1 failed E-INV4; replace-date: the edited text does not parse |
| M97 | C1 offset -24:00 valid | `Internal/Check.roc:38` | edit.roc: 1 failed E-INV4 |
| M98 | C1 offset +23:59 invalid | `Internal/Check.roc:38` | edit.roc: 1 failed E-INV6 |
| M99 | C1 offset date-time: time not checked | `Internal/Check.roc:45` | edit.roc: 1 failed E-INV8; replace-date |
| M100 | C1 local date-time: date not checked | `Internal/Check.roc:46` | edit.roc: 1 failed E-INV1; replace-date: the edited text does not parse |
| M101 | C1 nested: array not checked | `Internal/Check.roc:49` | edit.roc: 2 failed E-INV5; entries.roc: 1 failed I-INV1; replace-date |
| M102 | C1 nested: inline table not checked | `Internal/Check.roc:50` | edit.roc: 1 failed E-INV5; entries.roc: 1 failed I-INV1; replace-date |
| M103 | C1 replace writes an invalid value (no check) | `Internal/Edit.roc:14` | edit.roc: 20 failed E-INV1 to E-INV5, E-INV8; replace-date: the edited text does not parse |
| M104 | C1 insert writes an invalid value (no check) | `Internal/Edit.roc:57` | entries.roc: 4 failed I-INV1 I-INV4; replace-date: the edited text does not parse |
| M105 | P6-2 replace: InvalidValue before NoEntry | `Internal/Edit.roc:14` | edit.roc: 1 failed E-INV7 |
| M106 | P6-2 insert: InvalidValue before KeyExists and NotATable | `Internal/Edit.roc:56` | entries.roc: 2 failed I-INV2 |
| M107 | C1 replace on InvalidValue gives Ok with the document unchanged | `Toml.roc:92` | edit.roc: 20 failed E-INV1 to E-INV5, E-INV8; replace-date: Ok for an invalid value |
| M108 | C2 no furthest failure in a line (the 0.1.0 seal `Parser.custom` with `Parser.run` on `line`) | `Internal/Grammar.roc:65` | structure.roc: 23 failed S-COL1 to S-COL5, S-ERR4, S-ERR5 |
| M109 | C2 at the end of the text: the column of the last byte | `Internal/Doc.roc:46` | structure.roc: 8 failed S-COL2 S-COL5 S-ERR4 S-ERR5 |
| M110 | C2 line 1 column without the BOM bytes | `Internal/Doc.roc:63` | structure.roc: 2 failed S-ERR5 |
| M111 | C2 (Q18) dotted key: column of the first part | `Internal/Tree.roc:131` | structure.roc: 3 failed S-COL11 |
| M112 | C2 (Q18) `[a.b]` again: column of the first part | `Internal/Tree.roc:67` | structure.roc: 1 failed S-COL11 |
| M113 | C2 (Q18) inline table: column of the first key | `Internal/Doc.roc:147` | structure.roc: 1 failed S-COL11 |
| M114 | C2 table defined again: column of `[` | `Internal/Doc.roc:84` | structure.roc: 2 failed S-COL8 S-COL11 |
| M115 | C2 i64 overflow: a syntax error (`flatten`), not a rule error | `Internal/Grammar.roc:173` | structure.roc: 2 failed S-COL9 |
| M116 | C2 a value that breaks a rule: column of the value end | `Internal/Doc.roc:137` | structure.roc: 10 failed S-COL9 S-COL10 S-COL12 |
| M117 | C2 `word` matcher: failure at the start of the word | `Internal/Grammar.roc:769` | structure.roc: 2 failed S-COL1 S-COL6 |
| M118 | C2 bare CR: `Utf8.string("\r\n")`, not `word` | `Internal/Grammar.roc:802` | structure.roc: 1 failed S-COL6 |
| M119 | C2 bad `\u` escape: column of the first digit | `Internal/Grammar.roc:364` | not caught (gap: no test reads the column of a bad escape; also not caught by the 8 L0 files) |

Observation (C1 "the document does not change"): the error union has no document, so a caller keeps its old `Toml`. The closest mutation (M107: `Ok` with the old document) is caught.
