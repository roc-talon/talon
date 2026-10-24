# 020 Compiler list

Phase: P1. Status: done

Slice 020 makes the list of compiler releases for `direct` mode: the release list of `roc-lang/nightlies` (the R-DI2 list call), the nightly tag forms and their order (R-NS1), the asset of a host (R-CV2, R-CV8), the sha256 from `digest` (R-CV3), the filter of `min-release-age` and of a time snapshot (R-C7), and the full id of the compiler that an argument of `tln roc ...` names: a prefix, `@latest`, `@-N`, `@+N` (R-SC10, R-SC11, R-SC13, R-SL5 to R-SL7). It also makes the fake nightly release tools (PLAN-P1 3.2). No command uses it yet (slice 021 and later). `flowprobe nightlies` and `flowprobe compiler` stand in for the commands (the style of slice 003). It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-020-revert/before/` (with `NEW.txt`).

Size (TW19): the private reference has about 260 lines of code (without comments and blank lines). No split.

## Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-CV1 (direct branch: the list, the 2 tag forms, the id is the tag text, the other form names the same nightly, R-DI3 applies) | CLI 6.2 | L0 `parts`, `releases`, `pick`. L3 `cl1`, `cl2` |
| R-CV2 (the asset of a host, 0 or 2 assets, other sha in the asset name) | CLI 6.2 | L0 `releases` (assets). L3 `cl1` |
| R-CV3 (the sha256 is the `digest` of the asset) | CLI 6.2 | L0 `releases` (digest). L3 `cl1`, `cl2` (the list and the archives agree) |
| R-CV7 (`.tar.gz` for Linux and macOS, `.zip` for Windows) | CLI 6.2 | L0 `releases`. L3 `cl1` (windows) |
| R-CV8 (the target of each host) | CLI 6.2 | L0 `target`. L3 `cl1` (3 hosts) |
| R-NS1 (order: date, then `published_at`, then tag text) | Resolution 1 | L0 `order`. L3 `cl1` |
| R-SC10, R-SC11, R-SC13 (prefix expansion to the full id, ambiguous prefix lists the ids) | CLI 2 | L0 `pick`. L3 `cl1` |
| R-C7 (compilers: `min-release-age` and the time snapshot hide new compilers, a named compiler is not hidden) | Resolution 2 | L0 `visible`, `pick`. L3 `cl1` |
| Also named in the tests, as their anchors: R-SL5, R-SL6, R-SL7 (`@latest`, `@<tag>`, `@-N`, `@+N` for compilers), R-NS3, R-NS4 (the switch and a named compiler), R-C9 (a kept id is never hidden), R-DT4 (time snapshot), R-RU1 (`at least 2 days old`), R-SO14 (no base: exit 18), R-DI2, R-DI3, R-DI10, R-DI12 | | |

## Files

| Path | Writer | State |
| --- | --- | --- |
| `cli/lib/Nightlies.roc` (132 lines) | Stubs from the test agent. Bodies from the code agent. | New module. Compiles. 8 bodies are `crash "todo"`. The contract is in the doc comments. |
| `cli/lib/main.roc` | Test agent | `Nightlies` in the exposes list |
| `cli/flowprobe.roc` (+113 lines) | Test agent (a test tool, glue only) | 2 new flows: `nightlies`, `compiler` |
| `tests/unit/nightlies.roc` (418 lines) | Test agent | 11 `expect`s, red |
| `tests/scenarios/compilers/cl1-nightly-list/`, `cl2-fake-nightly-tools/` | Test agent | 2 L3 cases, red |
| `tests/tools/mk-nightly.sh` (73 lines) | Test agent | The fake nightly release tool. Done (it is the fake, not code of `tln`). |
| `tests/fixtures/nightlies/` (`trim.py` 57 lines, `list-page1.json`, `list-page2.json`) | Test agent | 12 real releases of the live list of 2026-10-22, cut by `trim.py` |
| `research/slice-020-revert/before/` | Test agent | The 2 changed files, `NEW.txt` |

## Public signatures (`cli/lib/Nightlies.roc`)

| Item | Type | Rule |
| --- | --- | --- |
| `Host` | `[LinuxX64, LinuxArm64, MacosApple, MacosX64, WindowsX64, WindowsArm64]` | R-CV8 |
| `Asset` | `{ name : Str, url : Str, size : U64, sha256 : Try(Str, [None]) }` | R-CV2, R-CV3 |
| `Release` | `{ id : Str, published_at : U64, asset : Try(Asset, [NoAsset, Several(U64)]) }` | R-CV1, R-CV2 |
| `target` | `Host -> Str` | R-CV8 |
| `parts` | `Str -> Try({ year : U64, month : U64, day : U64, sha : Str }, [NotNightly])` | R-CV1 |
| `releases` | `{ host : Host, pages : List(Str) } -> Try(List(Release), [BadPage(U64)])`. In the order of `order`. | R-CV1 to R-CV3, R-DI3 |
| `order` | `List(Release) -> List(Release)`, the oldest first | R-NS1 |
| `visible` | `{ list, now, min_age : U64, snapshot : Try(U64, [None]), keep : List(Str) } -> List(Release)` | R-C7, R-C9, R-DT4 |
| `candidates` | `List(Release) -> List(Release)`: the nightlies with one asset on the host. A command builds `named` and `auto` of `pick` from them (review Q1). | R-CV2, R-CV8 |
| `PickError` | `[Empty, NoMatch(Str), Ambiguous({ text, ids }), NoBase, BaseNotListed(Str), OutOfRange({ base, step })]` | R-SC10, R-SL7 |
| `pick` | `{ text : Str, named : List(Str), auto : List(Str), base : Try(Str, [None]) } -> Try(Str, PickError)` | R-SC10, R-SC11, R-SC13, R-SL5 to R-SL7 |
| `failure` | `PickError -> Fail` | proposal |
| `list!` | `Fx, { net, roots, now, offline, host } => Try({ releases : List(Release), source : [Live, Cached(U64), Missing] }, Fail)`. One fetch: `Github.releases!` for `roc-lang/nightlies`, then `releases`. | R-CV1, R-DI2 |

The design of each function is in its doc comment (tables).

## Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/nightlies.roc` 1 (`parts`) | The 2 tag forms. All 12 month names give their number. 15 texts that are no nightly tag (`nightly-latest`, a release, no sha, a sha that is not hex, a sha of fewer than 7 digits (6 and 5), a lower case or short month name, 1 digit day, extra part, empty). | R-CV1 |
| L0 | 2 (`releases`, the list) | 2 pages. The id is the tag text in both forms. A draft and a prerelease are skipped. `v0.1.0` and `nightly-latest` are skipped. A nightly with no asset stays. The result is in R-NS1 order across the pages. No page: an empty list. | R-CV1, R-DI3, R-NS1 |
| L0 | 3 (`releases`, bad pages) | `BadPage(n)` for a page that is not an array, not JSON, a release with no `tag_name`, a nightly with no or a bad `published_at`, a release that is no object. No error for the time of a draft or of a tag that is no nightly. | R-CV1, R-DI3, R-DI10 |
| L0 | 4 (`releases`, the asset) | One release of 8 assets plus 3 tricky ones, for each of the 5 hosts. `linux_x86_64_musl`, a `.zip` for Linux and a `.tar.gz` for Windows are not the asset. The real release with another sha in the asset name. 2 assets: `Several(2)` for one host, an asset for another. No `assets` field, only source and wasm assets: `NoAsset`. The name, the size and the URL. `WindowsArm64` (`.zip`), and a nightly with no `windows_arm64` asset is `NoAsset`. `candidates`: only the nightlies with one asset (not `NoAsset`, not `Several`), for Linux x86_64 and Windows arm64. | R-CV2, R-CV7 |
| L0 | 5 (`releases`, the digest) | `sha256:` and 64 lower case hex gives the digits. No field, null, `sha1:`, short, long, a non-hex digit, no prefix, empty, a number: `Err(None)`. The digest of another asset does not count. | R-CV3 |
| L0 | 6 (`order`) | 11 real and made-up releases, in 3 input orders. Date first (October before November: numeric month). The real July-23 pair is in the order of `published_at`, not of the tag text. A later date with an earlier `published_at` is later. Equal time: the tag text. | R-NS1 |
| L0 | 7 (`visible`) | `min_age` of 2 days: exactly 2 days is visible, 1 second less is not. 0 hides nothing. Snapshot: at the time is visible, after is hidden. Both. `keep` ids stay. The order stays. | R-C7, R-C9, R-DT4, R-RU1 |
| L0 | 8 (`target`) | The 6 targets. | R-CV8 |
| L0 | 9 (`pick`, relative) | `@latest`. `@-1`, `@+1`, `@-2`, `@+2` in the order of R-NS1 (2 nightlies of one date are 2 steps). A base in the other tag form. `OutOfRange` both ends. `NoBase`. `BaseNotListed`. `Empty`. A name is looked up in `named`: the 2 newest nightlies are not in `auto`, and the full id of the newest gives itself. | R-SL5, R-SL7, R-NS3, R-NS4, R-CV1, R-NS1 |
| L0 | 10 (`pick`, names) | A full id. A unique prefix. An ambiguous prefix (ids in the order of `named`). `git-` ids. No match. The other tag form of a full id gives the tag text, also with `@`. Another sha: no match. An exact id wins over a longer id that it prefixes (7 and 8 digit shas), and a shorter prefix of both is ambiguous (Q4). | R-SC10, R-SC11, R-SC13, R-CV1, R-SL6 |
| L0 | 11 (`failure`) | The kind and the text of the 7 errors. Exit codes 10 and 18. | proposal (TW24), R-NS2, R-SO14 |
| L3 | `compilers/cl1-nightly-list` | The real fixture (12 releases, 2 pages) on the fake API. List for Linux x86_64 in R-NS1 order (the digests and sizes were checked against the fixture with an independent script). Windows and macOS assets (`.zip`, `.tar.gz`, no asset). 1 request per page, the second run from the cache. `--min-age` and `--snapshot` filters. `@latest` with and without `--min-age`. A named hidden nightly. Prefix, other form, `@<tag>`. Steps. The 4 failures (exit 2, 2, 18, 2). The 2 cache pages. Offline, and offline with no cache. Only candidates count (Q1): `@-1` and `@+1` step over the real nightly of 2025-11-03 that has no asset, its id and a prefix of it name nothing. Windows arm64: only 2 old nightlies have the asset, so `@latest` is 2026-02-10 and the newest nightly is no name. | R-CV1, R-CV2, R-CV3, R-CV7, R-CV8, R-DI2, R-DI3, R-NS1, R-NS3, R-NS4, R-SC10, R-SC11, R-SC13, R-SL5 to R-SL7, R-C7 |
| L3 | `compilers/cl2-fake-nightly-tools` | `mk-nightly.sh` output (3 nightlies, one with `+baddigest`, one with `+nodigest`). The list and the archives agree: size, sha256, one file `roc`. A page that is not a release list: exit 15, nothing cached, and a second call asks the server again (2 requests in `http.log`, G3). | R-CV1, R-CV2, R-CV3, R-NS1, R-DI2 |

Count: 11 L0 `expect`s, 2 L3 cases.

## Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| `Empty` | `tln: error[no_tuple]: no compiler release is known` (exit 10, R-NS2). The caller adds the switch and its source when the switch is off (R-NS2). |
| `NoMatch` | `tln: error[usage]: no compiler matches <text>` |
| `Ambiguous` | `tln: error[usage]: <text> matches <n> compilers: <id>, <id>. Use a longer prefix or the full id.` |
| `NoBase` | `tln: error[environment]: no compiler is selected, so a relative step has no start. Run: tln roc install @latest and tln roc default <id>` (the 2 commands are those of R-SO14) |
| `BaseNotListed` | `tln: error[usage]: <id> is not in the list of compilers, so a relative step has no start` |
| `OutOfRange` | `tln: error[usage]: no compiler is 1 step older than <base>`, `no compiler is 3 steps newer than <base>` |
| Bad page | `tln: error[network]: page <n> of roc-lang/nightlies is not a release list` (exit 15) |
| `flowprobe nightlies` | `nightly <id> <published_at> <size> <sha256 or none> <url>`, `nightly <id> <published_at> no asset`, `nightly <id> <published_at> <n> assets`, `no cached page`. stderr: `index: cached at <time>`. |
| `flowprobe compiler` | `compiler <id>`, or the failure line and its exit code |

## Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `releases` keeps each nightly of the list. The host only decides the `asset` field (`NoAsset`, `Several(n)`). The list does not depend on the host. | A list of the candidates of the host only: a later message could not say "no asset for linux_x86_64" or "2 assets" (R-CV2 says "not a candidate" for both). |
| D2 | The order is the oldest first. `@+N` is the index plus N. | The newest first |
| D3 | `pick` has 2 lists: `named` (the full list: a name is never hidden, R-NS4, R-C7) and `auto` (the domain of `@latest` and the steps after the switch, `visible` and the range, R-NS3). | One list: then `min-release-age` hides a name, or `@latest` ignores it. |
| D4 | `Host` has 6 variants, with Windows arm64 (`windows_arm64`, `.zip`, the review and R-CV8). The host from the system (`Env.platform!`) is slice 021. | A host with `Err(Unsupported)` |
| D5 | `parts` reads a sha of 7 or more hex digits and a month name with a capital letter in full (the rule of `Selector`, slice 004 D5). | Any text for the sha |
| D6 | A sha256 is only `sha256:` and 64 lower case hex digits. Any other digest is `Err(None)` (R-CV4: exit 16 at install). | Accept upper case or another algorithm |
| D7 | A nightly that is no draft and no prerelease and has no readable `published_at` is `BadPage(n)`, as in `Index` (slice 003). | Skip the release, or time 0 |
| D8 | One leading `@` of an argument is dropped. `latest` and a step need the `@` (R-SL5, R-SL7 write `@latest`, `@-1`). A bare text is an id or a prefix (R-SC9). | A bare `latest` or `-1` as a selector (`-1` would be a flag) |
| D9 | `visible` has the field `keep` for ids that are never hidden (R-C9). `flowprobe compiler` passes `--base` there: a base of 1 day age stays in `auto`. | No `keep`: `@-1` from a young base would give `BaseNotListed` |
| D10 | The fixture is a real trimmed copy of the live list (`trim.py`), with the asset URLs on the fake server. The only made-up data is in L0 (marked in the comments) and in `cl2` (the output of `mk-nightly.sh`). | A hand-written list (TW14) |
| D11 | The cache of `Nightlies.list!` is the cache of `Github.releases!` (`talon/index/github/roc-lang/nightlies/`). The cache key has no API base, so a second API base within 60 s gets the cached page (the `cl2` case removes it before the bad page). | A cache of its own |

## Out of scope

| Id | Reason |
| --- | --- |
| R-CV1 and R-CV3, registry branches (`GET /v1/toolchains`) | P2 |
| R-CV4, R-CV5 (the install, `.talon.json`) | Slice 021. `cl2` makes the bad and the missing digest for it. |
| R-CV6 (first sha256 seen, `compat.db`) | Slice 030 |
| R-NS2, R-NS3 (the switch itself), R-NS7 (the `[toolchain] roc` range) | The command decides `auto` (slices 022, 026, 036). Only the argument of `tln roc` is here. |
| R-C7: the sources of `min-release-age` (`talon.toml`, `config.toml`), its default `2d`, the note with the age of a named release | The command reads them. `visible` takes seconds. |
| R-C9 for header entries | Slice 036 |
| The host of the machine | Slice 021 (a new `Fx` call or `Env.platform!`) |
| R-SC9 "interactive use only" for a prefix, R-SC12 (a prefix in `ROC_TOOLCHAIN` or a pin is an error) | R-SC12 is slice 012 (`Compiler.toolchain_of`, `Pin.is_id`). R-SC9 needs the mode of the command. |
| R-SL12 for compilers (close versions in the error of an unknown selector) | The design gives no text for compilers. Question Q6. |
| Releases that are no nightlies (R-NS1 "the release is newer on the same date") | The design has no compiler release yet (R-NS2). `order` has no release branch. |
| The `ETag` and 60 s rules, the rate limit | Slice 003 (`Github.releases!`) |

## Questions (TW17)

The tests do not fix these points, unless a row says so.

| # | Question | Tested default | Other option |
| --- | --- | --- | --- |
| Q1 | Candidates only (answered in the review). | Tested: L0 `candidates`, L3 `cl1` (steps over the nightly of 2025-11-03, Windows arm64) | All nightlies |
| Q2 | A prefix is a byte prefix of the tag text (answered). | None | |
| Q3 | A relative step, and the base is not in `auto` (gone from the list, a `git-` build, hidden by age): an error, or a step from the nearest date? | `BaseNotListed`, exit 2 (L0 rows 9 and 11) | Step from the nearest date |
| Q4 | The exact id wins (answered). | Tested: L0 `pick` names | Ambiguous |
| Q5 | The exit code and text when `auto` is empty for `@latest`. R-NS2 gives exit 10 and names the switch only for the switch off. A list that `min-release-age` or a snapshot empties is not stated. | `Empty` is exit 10 (`no_tuple`), text `no compiler release is known` (L0 row 11) | Exit 2 for a hidden list |
| Q6 | A name that matches no compiler: the exit code and the text. R-SL12 is for packages (3 close versions, `use --git`). | Exit 2, `no compiler matches <text>` (L0 row 11) | The list of 3 close ids |
| Q7 | A nightly with 2 or more assets for the host: a warning (as R-DI4 for packages), or none? R-CV2 only says "not a candidate". | No warning | A warning that names the assets |
| Q8 | A prefix after `@` is allowed (answered). | None | |

## Design gaps found

| # | Gap |
| --- | --- |
| G1 | (Moved to slice 022 by the review.) `Pin.admits` (slice 012, `AtLeast`) orders 2 nightlies of one date by the tag text, as P0 has no `published_at`. R-NS7 says "orders at or after that id" by R-NS1, which uses `published_at` first. For the real pair of 2026-07-23 the 2 orders differ. A later slice (022) must use the list. Also `Pin.admits` `Exactly(a)` compares the text, so a pin in the other tag form (R-CV1: the same nightly) is "not equal". |
| G2 | (Fixed in R-CV8 by the review: the code sorts the list.) The live list (338 releases, 2026-10-22) is not in `published_at` order (`desc` is false), so the order of the answer is no order. `windows_arm64` assets exist in 211 older nightlies. R-CV8 says it has none "in these nightlies" (the nightly of 2026-10-14). No digest is missing (0 of 338 releases). 3 releases have no asset, and 3 have another sha in the asset name, as DESIGN.md says. |
| G3 | (A bug of `Github.releases!`, the code agent fixes it. Now tested in `cl2`.) A bad page is cached by `Github.releases!` (the body is written before it is parsed), so for 60 s the same bad page is used. It is the behavior of slice 003. R-DI2 does not say. |

## Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| A local value with the name of a method of the same type module is a "duplicate definition" (`releases` inside `Nightlies`) | Use another name (`listed`) |
| `roc fmt` rewrites a long record literal in a row of a list | The tests are formatted by `roc fmt` |

## Red output

`scripts/test.sh` with the stubs (2026-10-22):

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt, l2, selftest | pass | |
| L0 old files | pass | |
| L0 `tests/unit/nightlies.roc` | red: 0 passed, 11 failed | `Roc application crashed ... todo` |
| L3 `compilers/cl1-nightly-list`, `cl2-fake-nightly-tools` | red | `[ROC CRASHED] todo`, the stdout, the exit code and the `http.log` differ |
| L3 old cases (26) | pass | |

## Check against the design (TW21)

The expected files of the 2 L3 cases were made by a private reference (deleted, TW18) and read by eye against the design. The digests and sizes of `cl1` were also checked by a separate script against the fixture. With the reference, the 11 `expect`s and the 2 cases pass.

Revert check (TW12), on the reference: 44 mutations of the code, each in one small way (the script was private and is deleted). 43 are caught.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `parts`, `releases` (month number, draft, prerelease, non-nightly kept, order, bad page number, asset prefix without `-`, Windows extension, extension unchecked, 2 assets take the first, sha length, sha algorithm, size, URL, no-asset dropped) | 15 | L0 |
| `order` (ignores `published_at`, by tag text, text before time) | 3 | L0 |
| `visible` (age strict, snapshot strict, `keep` ignored) | 3 | L0 |
| `pick`, `step`, `failure` (latest is first, step sign, other form not found, ambiguous takes first, prefix over `auto`, step over `named`, latest over `named`, base not canonical, `@` not dropped, out of range value, older and newer swapped, empty kind) | 12 | L0 |
| `target` (macOS swapped) | 1 | L0 |
| `list!` (wrong repository, bad page kind) | 2 | L3 only |
| The digest of another asset is used | 1 | Not caught: the mutation was a no-op (equal behavior), not a test gap |
| Review rows: `candidates` keeps all, or the nightlies with 2 assets; a prefix is read before an exact other form; a sha of fewer than 7 digits is accepted; the `windows_arm64` target or extension is wrong | 5 | L0 |
| Review row: a bad page stays cached (the reference removes the cache pages in `list!` when a page is bad) | 1 | L3 `cl2` only |

Known gap: the `.zip` of a source archive is covered only by the real fixture.

## Review answers applied (2026-10-22)

| Answer | Change |
| --- | --- |
| `Host` has Windows arm64 | 6th variant in the stub, `target`, the extension, L0 rows 4 and 8, `flowprobe --host windows_arm64`, `cl1` |
| Q1: candidates only | New `candidates`. `flowprobe compiler` builds `named` and `auto` from it. L0 row 4, L3 `cl1` |
| Q4: exact id wins | L0 row 10 (7 and 8 digit shas) |
| L0 gap: a short sha | L0 row 1 (6 and 5 digits) |
| G3: a bad page is not cached | `cl2`: the cache has no page after a bad page, and a second call makes a second request. The fix may be in `Github.releases!` or in `Nightlies.list!` (the reference removes the pages in `list!`). |

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | `cli/lib/Pin.roc` has private helpers (`nightly_key`, `month_number`) that read the 2 tag forms, and `Selector` has the tag check. Reuse them, or move them to `Nightlies`. A test must not change (TW18). |
| N2 | `Nightlies.list!` calls `Github.releases!` once. `flowprobe` passes the real clock for the cache age and `TALON_NOW` for `visible`. |
| N3 | `Host` is not yet read from the system. Slice 021 adds that. |
| N4 | `order` is a total order, so use `sort_with`. The 3 input orders of L0 row 6 give one result. |
| N5 | Local names must not equal the names of the methods of `Nightlies` (`releases`, `order`, `pick`, ...). |

## Review (manager, 2026-10-22)

D1 to D11 are accepted, with one change: `Host` gets a 6th variant, Windows arm64 (`windows_arm64`, `.zip`). The manager changed R-CV8: it lists the target, and a nightly with no asset for the host is not a candidate on that host (R-CV2).

| # | Answer |
| --- | --- |
| Q1 | Only the nightlies with an asset for the host count for `@latest`, `@-N`, `@+N` and names: a nightly that cannot be installed on the host is not a candidate (R-CV2). Add rows. |
| Q2 | No: a prefix is a prefix of the tag text. |
| Q3 | The default (`BaseNotListed`, exit 2). |
| Q4 | Yes: an exact id wins over a longer id that it prefixes (as a git ref). Add a row. |
| Q5 | The default for the pure function. The command adds the switch and its source (R-NS2) in slice 022. |
| Q6, Q7, Q8 | The defaults (Q8: a prefix after `@` is allowed, as with no `@`). |
| G1 | A bug of `Pin.admits` and `Exactly`: R-NS1 orders 2 nightlies of one date by `published_at`. Moved to slice 022 (selection ranks). |
| G2 | Fixed in the design (R-CV8). The code sorts the list; it does not trust the API order. |
| G3 | A bug of `Github.releases!` (slice 003): a bad page must not be cached. The test agent adds a run that shows it; the code agent of this slice fixes it. |
| L0 gap | Add a row with a sha shorter than 7 digits. |
The added rows are accepted. G3: the fix goes in `Github.releases!` (a page that does not parse is not written to the cache), so every caller gets it, not only `Nightlies.list!`. Status: code.

## Code agent results (2026-10-22)

`scripts/test.sh`: exit 0 (check, fmt, l0 184 expects in 54 files, l2 36 cases, l3 28 passed and 1 skipped, selftest 39). `OPT=speed scripts/test.sh`: exit 0.

### Verify results

Revert check (TW12): 33 mutations of `cli/lib/Nightlies.roc` and `cli/lib/Github.roc`, run with the filtered tests (`research/slice-020-revert/code-mutate.py`, results in `code-results.md`). Caught 33 of 33.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `target`, `parts`, `releases` (month index, non-nightly kept, draft, prerelease, bad page number) | T1, T2, R1 to R4 | L0 `nightlies` |
| the asset and the digest (prefix without `-`, Windows arm64 extension, each extension accepted, 2 assets give the first, sha256 length, no `sha256:`, size, URL) | A1 to A8 | L0 |
| `order`, `visible`, `candidates` | O1, O2, V1 to V3, C1 | L0 |
| `pick`, `failure` (latest, step sign, base in the other form, base not listed, step in `OutOfRange`, other form with another sha, ambiguous takes first, `@` kept, kind of `Empty`, older and newer) | P1 to P8, F1, F2 | L0 |
| `list!` (repository, kind of a bad page) | L1, L2 | L3 `cl1`, `cl2` |
| `Github.releases!` (a page that is no array is cached, G3) | G1 | L3 `cl2` |

Equal behavior (not a gap): `named.contains(text)` in `by_name` can be removed with no change for nightly ids. It matters only for an id that is no nightly and prefixes another id.

### Decisions of the code agent (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | G3: `Github.releases!` does not write a 200 body that does not parse as a JSON array (body and meta of that page). The page stays in `pages`, so the caller reports it. `list!` does no cache work. | Remove the pages in `list!`. A check of the release fields in `Github` (that is the work of `Index` and `Nightlies`). |
| C2 | `pick` with an empty text (also `@`) is `NoMatch("")`. | Ambiguous with all ids |
| C3 | The base of `OutOfRange` is the id of `auto` (the canonical form), not the text of the caller. | The text of the caller |
| C4 | A prefix is matched after the exact id and the other tag form, in that order. | Prefix first |
| C5 | An asset with no `size` or no `browser_download_url` has size 0 or the empty URL. | `BadPage` |

## Review of the code (manager, 2026-10-22)

`scripts/test.sh` passes (manager run). `OPT=speed` passes too (code agent run). The revert check caught 33 of 33. C1 to C5 are accepted. Moved: the `named.contains(text)` branch of `by_name` matters only for a non-nightly id that prefixes another id (a `git-` pair): slice 045 (git builds) adds a row. Note: in an `OPT=speed` run the l2 step warns over its 30 s budget (the LLVM build); TW26 budgets are for the fast set, so slice 021 can make the warnings apply to `OPT=dev` only.
