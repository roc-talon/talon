# roc-app-header: header parse, span edit, import scan, package URL, group key, MVS

Phase: P0 (generic package, R-GP2). Status: review accepted, tests updated for the settled questions (2026-10-16). Next: code.

| Item | Value |
| --- | --- |
| Repository | `github.com/Karakatiza666/roc-app-header` (future). Local: `../roc-app-header/` (`git init -b main`, no commit) |
| Compiler | `.roc-version` still says `nightly-2026-10-09-258ab27`. Checked on `nightly-2026-10-15-38e6c42` and `nightly-2026-10-14-38a3029`: `roc check` (0 errors, 0 warnings), `roc fmt --check` and `roc test` (all red on `todo`, 0 compiler errors). The fuzz targets build and run on 10-14 only: roc-fuzz 0.4.3 is broken on 10-15 (`../nightly-1015-check/README.md`). 10-09 also passes the same checks. |
| Check | `scripts/test.sh ROC [FUZZ_ROC]`: check, fmt, L0 with `ROC`, L1 build with `FUZZ_ROC` (default `ROC`; `RUNS`, default 20000, `--seed=1 --time=0`, TW6). Use `scripts/test.sh <10-15 roc> <10-14 roc>`. A work dir for each compiler: `.work/<nightly>/`. On the stubs: all checks and the fmt check pass, every L0 test fails with `todo`, every fuzz target builds and fails with `todo` (exit 77). |
| Seed check | `scripts/seeds-check.sh ROC` makes the expected values again with another roc and compares them. 10-15 and 10-14: the 13 sidecars are the same, and 14 of 15 `roc fmt` outputs are the same. In `roc-ray-0.10.0.fmt.roc.txt`, `roc fmt` writes its own nightly in the `roc:` pin (R-H2). The tests leave out the `roc:` value, so they do not change. 10-09: all the same. |
| Seeds | `scripts/seeds.sh` copies the seeds from the roc cache and makes the expected values with roc (sidecar, `roc fmt`). `tests/fixtures/seeds/SOURCES.tsv` has the source path, release URL, license and copyright line of each seed. |
| License | `LICENSE`: the copyright line of table LIC, then the UPL-1.0 text of the Talon `LICENSE` (the same text as `roc-lang/roc`), R-GP7 |

## Rules

| Source | Rows |
| --- | --- |
| Design 6.1, 6.2 | R-PK5, R-GA7, R-GP1, R-GP3, R-GP5, R-GP7 |
| Design 2 | Group key row, MVS row, app pin rows (lower fails, higher wins), "Conflicting Package Contents", one hash many labels, platforms not solved, hash form |
| Design 4.1, 4.2 | R-ID1 (series), R-ID2 (group), R-H1 (span edit), R-H3, R-H6, R-H7 |
| CLI 7.3 | R-DI5 (one `X.Y.Z` run, no run, two runs, `0.0.0`, tag text in the group) |
| CLI | R-FE8 (schemes), R-AD18, R-AD24, R-AD30, R-AD31, R-RV1, R-RV2 (the header edits that the commands need) |
| Resolution 4 | R-UM1 (lexical scan of `import` lines), R-LD7 (a package or platform file: scan every module) |
| TESTING.md 4 | Two L1 targets: (a) header parser and span edit, (b) MVS and group key |

The roc-syntax corpus (topics `imports`, `app_header`, `packages`, `platforms`, `modules`) gives the syntax of headers and `import` lines. No roc compiler code was read (R-GA7).

## Public API

No Talon concept in a name or a doc comment (R-GP1). Names avoid the Roc reserved words `exposes`, `package`, `imports`, `platform` (the compiler refuses them as names).

| Module | Function | Signature |
| --- | --- | --- |
| `PackageUrl` | `parse` | `Str -> Try(PackageUrl, [BadScheme, NoHash, NoVersion, ManyVersions, ZeroVersion])` |
| | `to_str` | `PackageUrl -> Str` |
| | `version` | `PackageUrl -> { major : U64, minor : U64, patch : U64 }` |
| | `hash` | `PackageUrl -> Str` |
| | `url_form` | `PackageUrl -> Str` (`github.com/roc-lang/unicode/releases/download/{v}/`) |
| | `series` | `PackageUrl -> Str` (`4`, `0.25`) |
| | `group` | `PackageUrl -> { form : Str, series : Str }` |
| | `is_eq`, `to_hash` | derived |
| `Mvs` | `select` | `List({ url : PackageUrl, is_platform : Bool }), (PackageUrl -> List({ url : PackageUrl, is_platform : Bool })) -> Try(List(PackageUrl), [Cycle(List(PackageUrl)), RootConflict(List(PackageUrl)), ContentConflict(List(PackageUrl)), VersionConflict(List({ pinned : PackageUrl, needed : PackageUrl, by : PackageUrl })), PlatformMismatch(List(PackageUrl))])` (S1, S3: `Cycle`, `RootConflict` are new) |
| `Header` | `parse` | `Str -> Try(Header, [NoHeader, BadHeader({ offset : U64 })])` |
| | `kind` | `Header -> [App, Package, Platform(Str)]` |
| | `exposed` | `Header -> List(Str)` |
| | `entries` | `Header -> List({ name : Str, value : Str, is_platform : Bool, span : { start : U64, end : U64 }, value_span : { start : U64, end : U64 } })` |
| | `span` | `Header -> { start : U64, end : U64 }` |
| | `set_value` | `Str, Str, Str -> Try(Str, [NoHeader, BadHeader({ offset : U64 }), NotFound, BadValue])` (source, name, value; S12: `BadValue` is new) |
| | `add_entry` | `Str, { name : Str, value : Str, is_platform : Bool } -> Try(Str, [NoHeader, BadHeader({ offset : U64 }), Exists, BadValue])` |
| | `remove_entry` | `Str, Str -> Try(Str, [NoHeader, BadHeader({ offset : U64 }), NotFound])` |
| `Imports` | `scan` | `Str -> List({ from : [Local, Package(Str)], name : Str, line : U64 })` |

Files: `package/main.roc`, `package/Header.roc`, `package/Imports.roc`, `package/Mvs.roc`, `package/PackageUrl.roc`. Each body is `crash "todo"`. The code agent can change the backing record of `Header` and `PackageUrl`, and adds `package/Internal/*.roc`.

## Tests

### L0 (`roc test`, 162 expects)

| File | Case | Source |
| --- | --- | --- |
| `tests/package_url.roc` (38) | Version, hash and URL form of the unicode 4.2.0 URL | R-ID2, Design 2 |
| | Series: `4.2.0` gives `4`, `0.25.1` gives `0.25`, `1.0.0` gives `1`, `0.0.5` gives `0.0` | R-ID1 |
| | Group of basic-cli 0.25.0 is `{ form, series: "0.25" }` | R-ID2 |
| | Tag `v1.9.0-rc2`: version 1.9.0, form `.../v{v}-rc2/` | Design 2 |
| | `v1.2.0` and `1.2.0` are two groups. `0.26.0-rc1` is not in the group of `0.26.0` | R-DI5 |
| | Same group: 4.2.0 and 4.3.1, 0.25.0 and 0.25.3. Other group: 4.2.0 and 5.0.0, 0.25.0 and 0.26.0 | R-ID1, R-ID2 |
| | The host is in the group. The scheme is not. The hash is not. | Design 2 |
| | The run in a segment before the last: form `example.com/pkgs/{v}/linux/` | Design 2 |
| | Loopback with port, and the prefix `greet-` | `research/roc-http-fetch`, R-FE8, R-DI5 |
| | Errors: no run, the real tag `x` (seed template-zig-x), two runs, `0.0.0`, no `<hash>.tar.zst`, `ftp://`, a path entry | R-DI5, R-H3, R-FE8, R-H7 |
| | `to_str` gives the input back | R-H1 |
| | S5: `1.2.3.4` has no run. `1.2.3x`, `a.1.2.3` are runs (the text stays in the form). `01.2.3` is 1.2.3. A part above `U64`: no run. | Settled S5 |
| | S6: the host is searched (`1.2.3.example.com`). The host `127.0.0.1` is not a run (4 parts). | Settled S6 |
| | S8: error order: `BadScheme` before `NoHash` before the version errors. `ManyVersions` before `ZeroVersion`. | Settled S8 |
| | S9: an empty hash is `NoHash` | Settled S9 |
| `tests/mvs.roc` (28) | No root: empty result | Design 2 MVS |
| | Highest wins. Only the winner's deps are followed. A deep raise wins. | Design 2 MVS |
| | Two series are two groups (1.2.0 and 2.0.0, 0.3.0 and 0.4.0). 0.3.5 wins over 0.3.0. 1.10.0 wins over 1.9.0. | R-ID1, Design 2 |
| | App pin higher wins. App pin lower: `VersionConflict([{ pinned, needed, by }])`. Equal: no conflict. | Design 2 app pin rows |
| | Winning version with two hashes: `ContentConflict` | Design 2 |
| | One hash with labels 1.0.0 and 2.0.0: two groups | Design 2 |
| | Platform deps join MVS. Same platform from a package: accepted. Another platform version: `PlatformMismatch` | Design 2 platforms |
| | S1: `Cycle` for `a -> b -> a`, for a package that names its own group, and for a cycle through a version that is not selected. `a 1.0.0 -> a 2.0.0` is no cycle (two series). | Settled S1 |
| | S2: two hashes on a version that is not selected: `ContentConflict` | Settled S2 |
| | S3: two root edges of one group with two versions: `RootConflict`. The same root URL twice: no conflict. | Settled S3 |
| | S4: the root text wins. With no root edge, the first text in byte order (`http://`) wins. | Settled S4 |
| | Error order: `Cycle` before `VersionConflict`, `RootConflict` before `VersionConflict`, `ContentConflict` before `VersionConflict` | Settled S1 to S3 |
| `tests/header.roc` (41) | App header (Design 4.2 example with a comment): kind, list, entries with `pf: platform`, URL, path entry, `roc:` | R-PK5, R-H7 |
| | One-line package header. Platform header (name, `exposes`, `packages`). Package that names a platform. `app [main!] {}` | R-PK5, roc-syntax topics |
| | Headerless app and type module: `NoHeader`. Cut header: an error, not a crash | R-PK5 |
| | Header span: the bytes before and after it (app, platform with `targets:`) | R-H1 |
| | `set_value`: exact output (prefix, new value, suffix) for a URL entry, the platform entry (keyword stays), `roc:`, a one-line header. `NotFound`, `NoHeader` | R-H1, R-AD31, R-H6 |
| | `remove_entry`: other entries keep order and text, bytes outside the header stay, `NotFound`, last entry of a one-line header | R-H1, R-RV1 |
| | `add_entry`: old entries keep order, new one is there, comment and old entry text stay, bytes outside stay, platform entry, empty record, platform `packages` record, `Exists` | R-H1, R-AD18, R-AD24, R-AD30 |
| | S10: exact `add_entry` output: many lines (after the last entry, its indent, a `,`), a comma added after a last entry with none, after a comment at the end of the last line, the indent of a platform `packages` record, one line, `{}`, `name: platform "value"` | Settled S10 |
| | S11: exact `remove_entry` output: many lines (the whole line goes, the comment line above stays, a comment at the end of the line goes), one line (the entry and one `, `), the only entry (`{}` stays) | Settled S11 |
| | S12: `"`, `\`, `${`, a line break in a value: `BadValue` for `set_value` and `add_entry` | Settled S12 |
| | S13: `\u(41)` in a value is not decoded | Settled S13 |
| `tests/imports.roc` (12) | `pf.Stdout`, `Helper`, nested type, `/` path, `as`, `exposing`, path prefixes, file imports skipped | R-UM1, roc-syntax `imports` |
| | Not an import: in a comment, a doc comment, a string, a multi-line string, `importer` | R-UM1 (lexical) |
| | Type module, no import, seed app-webserver (4 imports), seed roc-ray (35 imports, 3 in a doc comment do not count) | R-UM1, R-LD7, R-RV2 |
| `tests/seeds.roc` (43) | 13 seeds: kind and entries (not `roc:`) equal the roc sidecar `<hash>.deps.json`, in order | R-PK5, Design 2.2 |
| | 15 seeds: the same kind, list (as a set) and entries (as a set, `roc:` value left out) after `roc fmt` | R-PK5, R-GA7 |
| | 15 seeds: each span points at its text | R-H1 |

### L1 (roc-fuzz 0.4.3, one property each)

| Target | Property | Oracle | TESTING 4 |
| --- | --- | --- | --- |
| `fuzz/header-total.roc` | `Header.parse` and `Imports.scan` never crash | A seed with a cut and an insert, or any text | (a) |
| `fuzz/header-edit-span.roc` | `set_value` changes only the value span: output = prefix + new value + suffix | 30 seed files (15 seeds and their `roc fmt` form) | (a) |
| `fuzz/header-edit-reparse.roc` | Parse after `set_value`, `remove_entry` or `add_entry` gives the edited value. Kind and list stay. | The same seeds | (a), "parse after print" (see G4) |
| `fuzz/group-key.roc` | `PackageUrl.parse` of a URL made from parts gives the parts, the URL form and the series. No run, two runs, `0.0.0` give their errors. | The rule text of Design 2 and R-ID1 in the target | (b) |
| `fuzz/mvs-oracle.roc` | `Mvs.select` equals a clean-room oracle on random graphs of up to 7 groups (2 groups share a URL form with 2 series). Most edges go to a later group; an edge back to an earlier or the same group has odds 1 in 16, so some graphs have a cycle (S1). In 200 random inputs: 167 Ok, 12 Cycle, 21 VersionConflict. | The rule text of Design 2 and the S1 rule (cycle over the reached packages, then the groups in dependency order), checked by hand on 14 graphs | (b) |

### Seeds (`tests/fixtures/seeds/`)

| Seed | Kind | Why |
| --- | --- | --- |
| unicode-4.2.0, http-1.0.0, roc-random-0.9.2, roc-ansi-0.13.0 | package | Multi-line lists, no deps |
| path-4.0.0 | package | `expect` lines after the header |
| roc-parser-2.0.0 | package | Doc comment before the header, one dep |
| roc-s2-geometry | package | License comment before the header |
| basic-cli-0.25.0, basic-cli-0.29.0 | platform | Comments inside `packages` and `requires`, `hosted` |
| basic-webserver-0.17.0 | platform | `[Context : context] for` in `requires` |
| roc-ray-0.10.0 | platform | `roc:` entry in `packages`, `## import` lines in a doc comment, 35 imports |
| template-zig-1.0.0 | platform | Old `requires {} { ... }` form, 4-space indent |
| template-zig-x | platform | A cache entry whose URL has no version |
| app-webserver, app-print | app | Talon repository files (no app is in the cache) |

## Decisions (for the review)

| # | Decision | Options rejected |
| --- | --- | --- |
| D1 | MVS uses only the numeric compare of the `X.Y.Z` run. No roc-semver. In one group all versions have the same series, and the tag text around the run (`-rc1`) is part of the group (R-DI5), so no prerelease order is needed. | roc-semver order: it would put `0.26.0-rc1` before `0.26.0` in one group, but roc gives two groups |
| D2 | No dependency. | roc-base58 for a hash check (Q9) |
| D3 | No run, two runs and `0.0.0` are `parse` errors (R-DI5). | `Ok` with an optional version |
| D4 | The group is a record `{ form, series }`, with the form text of R-ID2 and Registry R-AP15 | An opaque `Group` type. One joined string. A record of the text before and after the run (it has no collision with a literal `{v}` in a URL, but the design names the form text) |
| D5 | An edit takes the source text and gives the new text. It parses again inside. | An edit on a `Header` value (the value and the text can differ) |
| D6 | A span is `{ start, end }` in bytes, `end` not included. `value_span` is the text between the quotes. | Spans with the quotes. Line and column |
| D7 | No `print` function. R-H1 forbids a reprint. TESTING 4 "parse after print" is read as "parse after an edit" (G4). | A printer in `roc fmt` form: no design row needs it, and `roc fmt` keeps the one-line or many-line layout of the input, so one printer cannot match it |
| D8 | `Imports.scan` gives module imports only. `name` keeps a path prefix and drops a nested type (`Url.ParseErr` gives `Url`). | Also file imports. Also `as` and `exposing` |
| D9 | `Mvs.select` lists all conflicts of a kind, in no fixed order. The tests compare sets. | The first conflict only (depends on the walk order) |
| D10 | Seeds: UPL-1.0 sources only, with the fixture names `*.txt` so that `roc fmt --check tests` and `roc check` skip them | Apache-2.0 and MIT seeds (allowed with the notice, not needed) |
| D11 | The `roc fmt` oracle compares sets, because `roc fmt` sorts the list and the record entries and moves the `roc:` pin (all seeds, G5) | An ordered compare |
| D12 | 5 L1 targets, one property each | 3 targets with 2 or 3 properties each |

## Output (accepted at the review, TW24)

Accepted: the error tags and the byte spans (`end` not included). New since the review, from the settled questions: `Cycle(List(url))`, `RootConflict(List(url))`, `BadValue`. Error tags: `BadScheme`, `NoHash`, `NoVersion`, `ManyVersions`, `ZeroVersion`, `NoHeader`, `BadHeader({ offset })`, `NotFound`, `Exists`, `VersionConflict(List({ pinned, needed, by }))`, `ContentConflict(List(url))`, `PlatformMismatch(List(url))`. The `VersionConflict` payload is tested. The other payloads are not.

## Out of scope

| Item | Reason |
| --- | --- |
| Content of `requires`, `provides`, `hosted`, `targets:` | The parser skips them. No design row needs them. |
| `module` (deprecated) and `hosted` headers | R-PK5 names app, package, platform |
| MVS with path entries (R-H7) and with URLs that have no version | S15, S17 |
| The `http://` loopback check of R-FE8 | A fetch rule, not a group rule |
| A package or platform file as the MVS root | S16 |

## Questions (stop until answered)

None open. Q1 to Q18 were answered at the review: "use the slice proposals". Where the slice had no proposal, the proposal below was made after the review and is marked "new". Sn answers Qn. The tests name it in their comment as `Settled Qn`.

## Settled

| # | Question | Answer | Tests |
| --- | --- | --- | --- |
| S1 | MVS with a group cycle | New. A package is reached when the root or a reached package names it, at any version. When the groups of the reached packages form a cycle, the result is `Cycle(List(url))`. With no cycle, the groups are done in dependency order. | 4 L0, `mvs-oracle` |
| S2 | Two hashes on a version that is not selected | Two followed edges with one group and version and two hashes are `ContentConflict`, also when that version is not selected (the rule in the `Mvs` doc of the review) | 2 L0 |
| S3 | Two root edges in one group | New. Two versions: `RootConflict(List(url))`. The same URL twice: no conflict. | 3 L0 |
| S4 | One group, version and hash with two URL texts | New. The text of the root edge, else the first text in byte order | 2 L0 |
| S5 | Run limits | New. A dotted number is the longest text of digit groups with one `.` between them. A run is a dotted number with exactly 3 parts. A letter, `-` or `.` after a letter can touch it. A part is read as a number (`01` is 1). A part above `U64`: not a run. | 5 L0 |
| S6 | Is the host searched? | New. Yes, all of the URL after the scheme (R-DI5 "in the URL"). `127.0.0.1` has 4 parts, so it is not a run. This agrees with `research/roc-http-fetch`. | 2 L0 |
| S7 | `0.0.0` | `parse` gives `ZeroVersion` (D3) | 1 L0 (from the review) |
| S8 | Error order of `parse` | New. The order of the error table: `BadScheme`, `NoHash`, `NoVersion`, `ManyVersions`, `ZeroVersion` | 3 L0 |
| S9 | Hash check | New. Only "not empty". The characters are not checked. No dependency on roc-base58. A full check (base58, 32 bytes) needs roc-base58 and changes the release order: not done, for the coordinator to decide. | 1 L0 |
| S10 | `add_entry` layout | After the last entry. `{}` gives `{ name: "value" }`. One line: `, name: "value"` before ` }`. Many lines: a new line after the line of the last entry (after its end comment), with its indent and a `,`. A `,` is added after a last entry with none. | 7 L0 |
| S11 | `remove_entry` bytes | One line: the entry and one `, `. Many lines: the whole line with its line break and an end comment. A comment line above stays. | 4 L0 |
| S12 | Values with `"`, `\`, `$`, a line break | New. `BadValue` for `set_value` and `add_entry`. No escape. | 2 L0 |
| S13 | Escapes in source values | New. `value` is the raw text. Not decoded. | 1 L0 |
| S14 | Result order of `Mvs.select` | No order (D9) | All MVS tests compare sets |
| S15 | Path-entry headers in MVS (R-H7) | Out of scope for 0.1.0 | None |
| S16 | A package or platform root | Out of scope for 0.1.0. The API says "root". | None |
| S17 | URLs with no version in MVS | Out of scope for 0.1.0: `Mvs.select` takes versioned URLs only | None |
| S18 | Seed weaver (no license) | Not copied | None |

## Design gaps (proposed changes)

| # | Row | Problem | Proposed change |
| --- | --- | --- | --- |
| G1 | Design 2, group key row | It gives no text for a URL with no run or with two runs | Add: "A URL with no `X.Y.Z` run is its own package. Two runs give `ambiguous package version`." (roc-syntax `packages` topic; check in `conformance/`) |
| G2 | Design 2, MVS row | No order and no cycle rule (Q1) | Add the DAG reading ("the groups in dependency order; the winner of a group is final before its deps are read") and the cycle rule, after a conformance test |
| G3 | R-CF1, `conformance/` | No group key or MVS case exists yet ("the tests from section 2 are its first fixtures") | Add L5 cases: `v1.2.0` and `1.2.0`, `0.26.0-rc1`, two runs, no run, `0.0.0`, the winner-only case of `tests/mvs.roc` with `roc deps` and `roc check` |
| G4 | TESTING.md 4, target (a) | "Parse after print" names a printer that no design row needs | "Parse after an edit gives the edited value" |
| G5 | Design 2, `roc:` row (R-H2) | `roc fmt` also sorts the header list and the dependency record (all 15 seeds) | Add this fact: one more reason for R-H1 and R-H2 |
| G7 | Design 2, MVS row (S1) | No cycle rule | Add: "A cycle in the groups of the reached packages, at any version, is an error. With no cycle, the groups are done in dependency order." Check it against roc in `conformance/` (roc-syntax `packages` topic: "package cycle"). |
| G8 | Design 2, MVS and app pin rows (S2, S3, S4) | Not stated: two hashes on a losing version, two root edges in one group, two URL texts of one release | Add the three rules of S2, S3, S4, and the error order `Cycle`, `RootConflict`, `ContentConflict`, `VersionConflict`, `PlatformMismatch`. Each needs an L5 case: roc can disagree. |
| G9 | Design 2, group key row, and CLI 7.3 R-DI5 (S5, S6, S8) | "The one `X.Y.Z` run" has no exact form | Add the dotted-number rule of S5, "the run is searched after the scheme, the host included" (S6), and the error order (S8). L5 cases: `1.2.3.4`, `1.2.3x`, `01.2.3`, a host run. |
| G10 | CLI 7.3 R-DI4 (S9) | R-DI4 says the hash is base58 of 32 bytes, but the parser does not check it | Say where the check is: in `tln` (after the download, the BLAKE3 compare checks it anyway) or in roc-app-header with roc-base58 (a change of the release order) |
| G11 | Design 4.2 R-H1 (S10, S11, S12) | "Whole entries" has no layout | Add the add and remove layout of S10 and S11, and "a value that needs an escape is refused" (S12) |
| G12 | Design 7 or `.roc-version` | roc-fuzz 0.4.3 does not run on 10-15, so L1 needs an older nightly than check and L0 | Say which nightly each layer uses until roc-fuzz works on the pin (TW7 is the fallback) |
| G6 | TESTING.md 4, seeds | "46 on this machine": the cache has 47 package dirs now, and only some have a license that allows a copy | Name the seed list file (`tests/fixtures/seeds/SOURCES.tsv`) |

## Proposed first version

`0.1.0`. Reason: the API is new and not reviewed in use. Below 1.0 each minor is its own group (R-ID1), so a breaking change in `0.2.0` does not raise a consumer that names `0.1.x` (Design 2 MVS). Tag `0.1.0` with no prefix, so the group form is `github.com/Karakatiza666/roc-app-header/releases/download/{v}/` (R-DI5).

## Disputes (from the code agent)

## Verify results

Verify agent, 2026-10-16, `nightly-2026-10-14-38a3029` for all layers. Script: `research/generic-packages/tools/mutate-roc-app-header.py` (one mutation at a time, all 5 L0 files and all 5 fuzz targets at 20000 runs, seed 1).

| Step | Result |
| --- | --- |
| 1 `scripts/test.sh` (clean `.work`) | Exit 0. L0: `header` 41, `imports` 12, `mvs` 28, `package_url` 38, `seeds` 43 (162 pass). L1: 20000 runs each, all pass: `group-key`, `header-edit-reparse`, `header-edit-span`, `header-total`, `mvs-oracle`. check and fmt pass. |
| 2 `roc check package/main.roc` | 0 errors, 0 warnings |
| 3 `roc bundle` | `HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU.tar.zst` (12845 bytes). Files: `main.roc`, `Header.roc`, `Imports.roc`, `Internal/Lex.roc`, `Mvs.roc`, `PackageUrl.roc`. Package files only. |
| 4 Revert check | 72 mutations. 68 caught, 3 not caught, 1 equivalent (M35). |
| 5 R-GP1 grep (`talon`, `registry`, `probe`, `evidence`, `compat`) | No match |
| R-GA7 grep | No Zig syntax, no `package_resolution`, no `.zig` name in `package/`. Only `main.roc:3` and `Mvs.roc:3` say "the rules of the Roc compiler" (a description, not copied text). |
| Restore | `diff -r package <step-0 copy>`: same. `.roc-fuzz/corpus` put back (1202 files, `diff -r` same). |

Note: a mutation to `if Bool.False` gives the warning "unconditional condition". Then `roc test` fails for each test file that imports the module and the fuzz builds fail, with no real catch. These 11 mutations were run again with a false condition that depends on the data (M3, M23, M26, M28, M31, M32, M49, M55, M60, M63, M70). The table has the second run.

### Not caught

| # | Mutation | File:line | Rule | Gap |
| --- | --- | --- | --- | --- |
| M36 | `RootConflict` check before the `Cycle` check | `package/Mvs.roc:39` | S1, S3, G8 error order (`Cycle` before `RootConflict`) | No test has a cycle and a root conflict together |
| M38 | `PlatformMismatch` check before the `VersionConflict` check | `package/Mvs.roc:53` | G8 error order (`VersionConflict` before `PlatformMismatch`), `Mvs` doc | No test has a version conflict and a platform mismatch together |
| M75 | No word end after `import` (only `starts_with`) | `package/Imports.roc:61` | R-UM1 (lexical scan) | The test lines `importer = 5`, `imports = [1]` give no module anyway. A line such as `importFoo = 1` gives `Local "Foo"` with the mutation. |
| M35 | `PlatformMismatch` ignores the hash | `package/Mvs.roc:309` | Design 2 platforms | Equivalent: two platform edges with one group and version and two hashes are always a `ContentConflict` first. Not a gap. |

### Caught

| # | Mutation | File:line | Failed tests (file:line, rule) |
| --- | --- | --- | --- |
| M1 | Two runs accepted | `PackageUrl.roc:42` | `package_url:105,159` (R-DI5, S8); `group-key` |
| M2 | No run gives `ManyVersions` | `PackageUrl.roc:41` | `package_url:99,102,123,141,150` (R-DI5, S5, S6); `group-key` |
| M3 | `0.0.0` accepted | `PackageUrl.roc:45` | `package_url:108` (R-DI5); `group-key` |
| M4 | `1.2.3.4` is a run | `PackageUrl.roc:171` | `package_url:77,90,96,123,150` (S5, S6, R-FE8) |
| M5 | Leading zero part is not a run | `PackageUrl.roc:171` | `package_url:138` (S5) |
| M6 | Part above `U64` is a run | `PackageUrl.roc:138` | `package_url:141` (S5) |
| M20 | Host not searched | `PackageUrl.roc:166` | `package_url:144` (S6) |
| M7 | Series of `1.x` is `0.minor` (`>= 1` to `> 1`) | `PackageUrl.roc:70` | `package_url:41` (R-ID1); `mvs` 11; `group-key`, `mvs-oracle` |
| M15 | Group series is the major only | `PackageUrl.roc:75` | `package_url:47,68` (R-ID1, R-ID2); `mvs:95`; `group-key`, `mvs-oracle` |
| M8 | Hash segment in the group form | `PackageUrl.roc:106` | `package_url` 10, `mvs` 15; `group-key`, `mvs-oracle` |
| M9 | Tag prefix `v` not in the group | `PackageUrl.roc:105` | `package_url:50,56` (R-DI5); `group-key` |
| M10 | Tag suffix `-rcN` not in the group | `PackageUrl.roc:106` | `package_url:50,59` (R-DI5); `group-key` |
| M11 | `to_str` drops `https://` | `PackageUrl.roc:53` | `package_url:120` (R-H1); `mvs` 26; `group-key`, `mvs-oracle` |
| M12 | `version` swaps minor and patch | `PackageUrl.roc:57` | `package_url` 6 (R-ID2, S5, S6); `group-key` |
| M13 | `hash` keeps `.tar.zst` | `PackageUrl.roc:96` | `package_url:29` (R-ID2); `group-key` |
| M14 | `url_form` has the scheme | `PackageUrl.roc:66` | `package_url` 8 (R-ID2, R-DI5); `group-key` |
| M16 | `NoHash` before `BadScheme` | `PackageUrl.roc:37` | `package_url:117,153` (R-H7, S8) |
| M17 | `ZeroVersion` before `ManyVersions` | `PackageUrl.roc:40` | `package_url:159` (S8) |
| M18 | `NoVersion` before `NoHash` | `PackageUrl.roc:38` | `package_url:156` (S8) |
| M19 | Empty hash accepted | `PackageUrl.roc:95` | `package_url:162` (S9) |
| M21 | Lowest version wins | `Mvs.roc:227` | `mvs` 6 (Design 2, R-ID1); `mvs-oracle` |
| M22 | Minor compares by its first digit | `Mvs.roc:241` | `mvs:109` (1.10.0 over 1.9.0); `mvs-oracle` |
| M23 | Deps of all reached versions followed | `Mvs.roc:206` | `mvs:66` (winners only); `mvs-oracle` |
| M24 | A self group edge is no cycle | `Mvs.roc:109` | `mvs:209` (S1); `mvs-oracle` |
| M25 | `Cycle` given as `RootConflict` | `Mvs.roc:42` | `mvs:202,209,216,272` (S1); `mvs-oracle` |
| M26 | `RootConflict` check removed | `Mvs.roc:45` | `mvs:246,279` (S3) |
| M27 | The same root URL twice is a `RootConflict` | `Mvs.roc:193` | `mvs:255` (S3) |
| M28 | `ContentConflict` check removed | `Mvs.roc:50` | `mvs:142,234,286` (Design 2, S2) |
| M29 | `ContentConflict` only for the selected version | `Mvs.roc:49` | `mvs:234,286` (S2) |
| M30 | `VersionConflict` when the dep is lower than the pin | `Mvs.roc:292` | `mvs:116,123,177`; `mvs-oracle` |
| M31 | `VersionConflict` check removed | `Mvs.roc:54` | `mvs:123`; `mvs-oracle` |
| M32 | Root edge does not win in its group | `Mvs.roc:222` | `mvs:258` (S4) |
| M33 | Last URL text in byte order wins | `Mvs.roc:250` | `mvs:265` (S4) |
| M34 | `PlatformMismatch` checks root edges only | `Mvs.roc:308` | `mvs:177` (Design 2 platforms) |
| M37 | `VersionConflict` before `ContentConflict` | `Mvs.roc:49` | `mvs:286` (S2 order) |
| M41 | Package header kind is `App` | `Header.roc:37` | `header:102` (R-PK5); `seeds` 14 |
| M42 | Platform name keeps the quotes | `Header.roc:194` | `header:108` (R-PK5) |
| M43 | Platform `exposes` list empty | `Header.roc:178` | `header:108` (R-PK5) |
| M44 | Exposed list drops the last name | `Header.roc:231` | `header:93,102,108`; `seeds` 4 (R-PK5) |
| M45 | Entry span `end` - 1 | `Header.roc:284` | `header` 35, `seeds` 19 (R-H1); `header-edit-reparse`, `header-edit-span` |
| M46 | `value_span` includes the closing quote | `Header.roc:284` | `header:145`, `seeds` 7 (R-H1); `header-edit-reparse` |
| M47 | `is_platform` always false | `Header.roc:284` | `header:99,114,145,170,204` (R-PK5, R-H1) |
| M48 | Header span `end` - 1 (app, package) | `Header.roc:148` | `header:133` (R-H1) |
| M49 | Platform header span starts at 0 | `Header.roc:194` | `seeds:184,193,202,211` (R-H1) |
| M69 | `NoHeader` given as `BadHeader` | `Header.roc:41` | `header:124,127,167` (R-PK5) |
| M51 | `set_value` trims the end of the file | `Header.roc:85` | `header-edit-span` only (no L0 test) |
| M53 | `$` in a value accepted | `Header.roc:289` | `header:267` (S12) |
| M54 | Line break in a value accepted | `Header.roc:289` | `header:267` (S12) |
| M55 | `set_value` `BadValue` check removed | `Header.roc:82` | `header:267` (S12) |
| M63 | `add_entry` `BadValue` check removed | `Header.roc:105` | `header:270` (S12) |
| M56 | Add, one line: no space after `,` | `Header.roc:324` | `header:234,240` (S10) |
| M57 | Add, many lines: a fixed tab indent | `Header.roc:331` | `header:249` (S10) |
| M58 | Add, many lines: no `,` after a last entry with none | `Header.roc:332` | `header:243` (S10) |
| M59 | Add to `{}`: no spaces | `Header.roc:309` | `header:237` (S10) |
| M60 | `add_entry` `Exists` check removed | `Header.roc:102` | `header:218` (R-H1) |
| M62 | Add after the first entry | `Header.roc:112` | `header:231` (S10) |
| M64 | Remove, many lines: the line break stays | `Header.roc:355` | `header:252,255` (S11) |
| M65 | Remove, many lines: the line above goes too | `Header.roc:352` | `header:252,255` (S11) |
| M66 | Remove, many lines: the end comment stays | `Header.roc:351` | `header:255` (S11) |
| M67 | Remove, one line: the space after `,` stays | `Header.roc:360` | `header:258` (S11) |
| M68 | Remove the only entry: the spaces stay | `Header.roc:358` | `header:264` (S11) |
| M70 | Remove the last entry of one line: the `,` before stays | `Header.roc:363` | `header:258` (S11) |
| M71 | Package import is `Local` | `Imports.roc:82` | `imports` 6 (R-UM1) |
| M72 | Local nested type kept | `Imports.roc:90` | `imports:17` (R-UM1) |
| M73 | Package nested type kept | `Imports.roc:79` | `imports:17` (R-UM1) |
| M74 | `import` in a comment counts | `Imports.roc:59` | `imports:29,47` (R-UM1) |
| M76 | Line numbers from 0 | `Imports.roc:18` | `imports` 10 (R-UM1) |
| M77 | Local path prefix dropped | `Imports.roc:92` | `imports:23` (R-UM1) |

Fuzz notes: the `mvs-oracle` target did not catch M26, M28, M29, M32, M33, M34, M37 (root conflicts, hash conflicts, URL text choice, platform edges). L0 catches all of them. M51 is caught only by `header-edit-span`: no L0 `set_value` input ends with white space, so the trim changes no L0 output.
