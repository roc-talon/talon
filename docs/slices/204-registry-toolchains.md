# 204 Compilers from the registry

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Plan row 204 of `PLAN-P2-CLI.md`. The new module is `cli/lib/RegistryToolchains.roc` (exposed in `cli/lib/main.roc`). `Nightlies` (`cli/lib/Nightlies.roc`) gains 3 functions for the registry source. They use `records.Toolchain` (`Wire.Page`, `Wire.encode_row`, `Wire.decode_page`: slice 104e is done), `Registry.refuse`, `Registry.no_answer` (slice 201), `RegistryCache.origin_dir`, `read_headers`, `unusable` (slices 202, 202b), `Facts.pin_all!` and `Db.Pinned` (slice 030b). No change of the `Fx` record.
No command calls the registry source yet: the choice between `Nightlies.list!` (GitHub) and `Nightlies.list_registry!` is slice 206 (the resolve seam) and the flows that list compilers. This slice gives the function and its test through the L2 entry `registry`.

## Rules

R-CV1, R-CV2, R-CV3, R-CV5, R-CV6 (registry branches), R-AP5, R-AP47, R-AP19 (toolchain rows), R-AP50 (ms to s), R-IX4, R-IX5, R-IX6 (the rows offline), R-TF3, R-TF6, R-NS1 (the order of the list), R-AP45, R-RG3, R-E6, R-EC15.

## Public signatures (stubs, `crash "todo: slice 204"`)

| Name | Signature |
| --- | --- |
| `RegistryToolchains.Row`, `Source` | `{ tag, target, asset_name, sha256, published_at : U64, log_index : U64 }` (as `records.Toolchain.Row`). `Source` is `[Live, Cached(U64), Missing]` |
| `RegistryToolchains.path` | `{ roots, origin } -> Str`: `<index>/registry/<origin dir>/toolchains.json` (R-IX4) |
| `RegistryToolchains.file_text` | `List(Row) -> Str`: `{"format":1,"rows":[...]}` and a line end |
| `RegistryToolchains.parse_file` | `Str -> Try(List(Row), [Bad, Newer])` |
| `RegistryToolchains.after_of` | `List(Row) -> U64`: the `log_index` of the last row, 0 for none |
| `RegistryToolchains.page_url` | `{ origin, after } -> Str`: `<origin>/v1/toolchains?after=<n>` |
| `RegistryToolchains.page` | `{ origin, body } -> Try(Wire.Page, Fail)`: kind `Network` for a body that does not decode |
| `RegistryToolchains.next` | `{ origin, after, page } -> Try([More(U64), Done], Fail)`: `Err` for a page that never ends |
| `RegistryToolchains.merge`, `visible` | `{ kept, fresh } -> List(Row)`; `{ rows, log : Try(U64, [None]) } -> List(Row)` |
| `RegistryToolchains.bad_file_warning` | `{ path, origin } -> Str` |
| `RegistryToolchains.list!` | `Fx, { roots, origin, version, offline } => Try({ rows, source : Source }, Fail)`. The doc has the table of the calls |
| `Nightlies.from_rows` | `{ host, rows } -> List(Release)` |
| `Nightlies.registry_pins` | `{ host, releases } -> List(Db.Pinned)`: `pins` with the source `Registry` |
| `Nightlies.list_registry!` | `Fx, { roots, origin, version, offline, host, log } => Try({ releases, source, changed, dropped }, Fail)` |

Names inside a type module block share one scope with the locals of a body: a local named `path`, `page` or `target` is a duplicate definition error in `RegistryToolchains` and `Nightlies`.

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/RegtoolchainsTest.roc` (driver `l0-3.roc`), 9 `expect`s. File: path, text, round trip, 11 bad texts, `Newer`, unknown members. `after_of` and the URL. The page reader (8 bad bodies). `next` (done, more, 3 stuck pages). `merge` and `visible` (the border at N). The warning text. `Nightlies.from_rows` (7 rows: other target, month-name tag, bad sha256, unsafe asset name, non-nightly tag, a second row of a tag, order of R-NS1). `registry_pins` | R-IX4, R-IX1, R-TF1, R-TF3, R-TF6, R-TF2, R-AP5, R-AP47, R-AP19, R-AP51, R-AP69, R-CV2, R-CV3, R-CV5, R-CV6, R-AP50, R-NS1, R-E6 |
| L2 | `tests/commands/cases/registry/ap5-toolchain-rows` (entry `registry`, word `toolchains`): 11 runs. Cold read with 2 pages (`after` is the last log index 11, not the count), the file written once after the last page. Warm read: `after=14`, an empty page, no write. Offline (the file, its mtime, no request). `log=11`. A kept file (origin 10): `after=22`, 1 new row appended. A bad file (origin 11): deleted, warning, read from 0. A second page with no answer (12): exit 15, no write. A 400 (13): exit 1. Offline with no file (14): `missing`. A 301 (15): exit 15. Offline with `log=10` | R-CV1, R-AP5, R-AP47, R-AP19, R-IX4, R-IX5, R-IX6, R-TF6, R-AP45, R-RG3, R-E6, R-EC15 |
| L2 | `tests/commands/cases/registry/cv1-registry-nightlies` (word `nightlies`): 6 runs. 6 rows (bad sha256, month-name tag, other target, newest, unsafe name, non-nightly): the 4 releases, the 2 pins with the source `registry` in `compat.tsv`. A warm run (`after=6`, no write, `pinned=2`). Another host. `log=2` (the query holds 1 pinned row: hidden rows are not seen). Offline. A GitHub digest pin with another sha256 for the same tag (origin 10): `changed` and `dropped` | R-CV1, R-CV2, R-CV3, R-CV5, R-CV6, R-AP5, R-AP19, R-AP47, R-AP50, R-NS1, R-IX4 |

The new L2 words are in `tests/commands/L2Registry.roc` (`toolchains`, `nightlies`). They are the stand-in of the commands until slice 206.

## Readings that the design implies (tested)

| # | Reading |
| --- | --- |
| 1 | `after` of the next request is the `log_index` of the last row of the page, and of the file, not a count (R-IX4). The log has leaves of other kinds, so the first row of a registry can have any index |
| 2 | The file is written once, after the last page, with the kept rows and all new rows (R-IX4 "never has a gap"). A failure of any page: nothing is written |
| 3 | The file keeps all rows. `--snapshot log:N` hides at the use, with `visible` (R-AP19). The request is the same with or without a snapshot |
| 4 | `--offline` reads only the file (R-IX6). The age of the list is the mtime of the file (`Cached(mtime)`) |
| 5 | A file that does not parse is deleted with a warning on stderr, and the read starts at `after=0` (R-IX4, R-TF6) |
| 6 | The sha256 of a row is recorded as a pin with the source `registry`. A row with another sha256 than the recorded one (from either source) is `changed` (R-CV3, R-CV6) |

## Decisions that the design does not fix (for the review)

| # | Decision | Rejected |
| --- | --- | --- |
| 1 | The toolchain pages are not kept as copies in `get/` (R-IX2 says each 200 `GET` is a copy, R-IX4 gives the rows their own store). The request is one `http_get!` with the `User-Agent` only | A `RegistryCache.get!` for each page (2 stores of the same rows). See Q2 |
| 2 | No age rule: each online command asks once (`after=<largest>`, a small answer). R-AP24 freshness is not applied, because the file is not rewritten when no row is new | The `max-age=300` of the answer as a freshness of the file. See Q2 |
| 3 | No new row: no write, also when there is no file (no empty `{"format":1,"rows":[]}`) | Write the empty file |
| 4 | A `Release` for a registry row exists only for a row of the target of the host. A tag with rows for other targets only gives no release on this host (a `NoAsset` release is not listed) | A `NoAsset` release for each tag of the other targets |
| 5 | A `sha256` that is not 64 lower-case hex digits is `Err(None)` (R-CV4 then stops the install with exit 16). An `asset_name` that is not a safe path part is `NoAsset` (R-CV2, R-SE18). A tag that is not a nightly tag is skipped (R-CV1). The registry should not send these, so this is a defence | Trust the registry |
| 6 | A page with `more` true that has no row, or that does not move `after` forward, is exit 15 (a loop guard) | No guard |
| 7 | `Nightlies.list_registry!` records pins for the visible rows only (Q4) | All rows |
| 8 | The L2 words print `source: ...` and the releases in the form of `flowprobe nightlies` | |

## Output (proposed, TW24)

| Case | Kind | Text |
| --- | --- | --- |
| A file that does not parse | warning on stderr | `warning: <path> is not a toolchain list file and is removed: Talon reads the list again from <origin>` |
| A page that does not decode | network (15) | `the answer of the registry <origin> is not a toolchain list: <decoder text>` |
| A page that does not move on | network (15) | `the registry <origin> gave a toolchain page that does not move on after <after>. Try again later.` |
| 3xx, no answer, another status | network or internal | the texts of `RegistryCache.unusable`, `Registry.no_answer`, `Registry.refuse` (slices 201, 202b) |
| A failed write | environment | `cannot write <path>` |

`--json`: no `data` field in this slice (the commands that list compilers have their own).

## Out of scope

| Item | Reason |
| --- | --- |
| The choice of the registry or GitHub for a command, `Toolchain.domain`, `tln roc` and the probe search using `list_registry!` | Slice 206 and the command slices. `list!` stays the GitHub source |
| `tln roc update`, the closure `compilers` list from the rows (`ClosureRequest.Row`) | Slice 205 (done) and 206 |
| The `index: cached at <time>` line (R-IX6) | Slice 206. `Cached(mtime)` is the fact for it |
| `tln cache clean` and GC of the rows file (R-GC12, R-GC15), the migration of an older `format` (R-TF3, there is only 1) | The cache slices |
| `.talon.json` `source: registry` (R-CV5, the record of an install) | The install slice that calls `Nightlies.list_registry!`. The pin source is tested here |
| The 429 and `Retry-After` of a read (R-AP25) | Slice 208. A 429 is exit 15 by `Registry.refuse` |
| The Worker side (R-AP5 paging, ETag, `target`) | W2 cases `worker/tests/cases/toolchains/*` |

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | The download URL and the size of a registry row (R-CV3, R-DA6). A row has `tag`, `target`, `asset_name`, `sha256`, `published_at`, `log_index` and no URL or size. `Nightlies.Asset` needs `url` and `size`. The tests use `https://github.com/roc-lang/nightlies/releases/download/<tag>/<asset_name>` and size 0 (unknown). The design says neither | Open, G-C42. Proposal used (accepted by the manager) |
| Q2 | R-IX2 says each 200 `GET` answer is a copy in `get/`, R-AP24 says a copy younger than `max-age` is used with no request, R-IX4 says the rows are in `toolchains.json`. Does a toolchain page also get a copy in `get/`, and is there a freshness rule for the file (the `max-age=300` of the Worker)? The tests: no copy, one request for each online command | Open, G-C43. Proposal used (accepted by the manager) |
| Q3 | R-TF3: a `toolchains.json` of a newer `format` is "ignored: it works with no cache". Does the read also overwrite the file with `format` 1, or leave it? `parse_file` gives `Newer` (tested). The flow for `Newer` has no L2 run. The reference reads no row and writes no file | Open, G-C43, flow untested |
| Q4 | `--snapshot log:N` with the TOFU pins (R-CV6): are the pins of the hidden rows recorded? R-CV6 says "the first time Talon sees a sha256". The tests: hidden rows are not seen, so not recorded (the L2 run `log=2` has `pinned=1`) | Proposal used (accepted by the manager) |
| Q5 | R-TF2 says a field that Talon does not know is kept when it writes the file. For `toolchains.json` (a cache that Talon can make again) the reference keeps only the members of R-AP49, and no unknown member of a row or of the top object. `parse_file` ignores them (tested), the write is not tested | Open, G-C43, untested |
| Q6 | A tag with 2 rows of one target: `from_rows` keeps the first (the registry keeps one row for a tag and target, R-RE4). No design text names the case | Open, G-C43. Untested in L2 (one L0 row) |

## Disputes (from the code agent)

None for the tests. Not a dispute: records slice 104h gave `Toolchain.Row` a required `size`, so `RegtoolchainsTest` (l0-3, 7 expects do not compile) and the L2 cases `registry/ap5-toolchain-rows` and `registry/cv1-registry-nightlies` fail with `MissingRequiredField("size")`: fixture needs size (slice 204b). `RegistryToolchains.Row` is now `Wire.Row`. `from_rows` keeps `size` 0 as the slice says, until 204b.

## Red result

| Layer | Result |
| --- | --- |
| L0 (`roc test tests/unit/l0-3.roc --no-cache`) | 102 expects: 93 pass, 9 fail. All 9 `RegtoolchainsTest` expects fail with `todo: slice 204`. Log `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red204-l0.log` |
| L2 (`tests/commands/run.sh registry/`) | `registry/ap5-toolchain-rows` and `registry/cv1-registry-nightlies` fail with `[ROC CRASHED] todo: slice 204`. The whole L2 run: 242 pass, 20 fail: these 2, `registry/sn6-short-names` (slice 211) and the 17 of slices 092 and 093 (`ptool/*`, `gc/gc6`). Log `.../scratchpad/red204-l2.log` and `.../scratchpad/l2-all-204-211.log` |

## Revert check

`research/slice-204-revert/before/` has the files that the slice changed (`cli/lib/main.roc`, `cli/lib/Nightlies.roc`, `tests/commands/L2Registry.roc`, `tests/unit/l0-3.roc`, `PLAN-P2-CLI.md`) and `NEW.txt`. `research/slice-204-revert/reference/` has the private green reference (`RegistryToolchains.roc`, `Nightlies.roc`): all 102 L0 and the 2 L2 cases pass with it (the expected files come from it). Mutations of the reference, each caught:

| # | Mutation | L0 | L2 |
| --- | --- | --- | --- |
| M1 | `next` goes on from `after + row count`, not the last log index | fail | fail |
| M2 | The file is written also when no row is new | pass | fail (both cases) |
| M3 | A failed second page writes the rows of the first page (a gap) | pass | fail |
| M4 | `from_rows` keeps the last row of a tag, not the first | fail | pass |
| M5 | `list_registry!` does not hide the rows above `log:N` | pass | fail |

Verify results: cases pass after 204b

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c` | `RegistryToolchains.roc` and `Nightlies.roc` changed in 204b, so the 204b code-final is the record now. |
| Tests | After 204b: l0-3 104 of 104, `registry/ap5-toolchain-rows` and `registry/cv1-registry-nightlies` pass. Before 204b they failed only because the fixtures had no `size` (records 104h). |
| Revert check | Test step: M1 to M5 caught. |
