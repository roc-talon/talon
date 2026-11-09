# 239 github-release shape

Phase: P2. Status: done (2026-11-10). Design Q614 (G-C244) answered the 8 Open questions. The user accepted the TW24 texts on 2026-11-10. Mutations: 16 of 16 caught (research/slice-239-revert/RESULT.md; the L2 variant m13b is not caught, because no command installs a user channel before slice 240). Close run: check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only).

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CH4 (Design Q612 = G-C242, CLI 6.8) | Shape `github-release` has `source` (`owner/repo`) and `tag-prefix`. A build is a release that is not a draft and not a prerelease (R-DI3) with the tag `<tag-prefix><date>-<sha>`. Asset prefix: `"roc_" + <tag-prefix> + <target> + "-"` (R-CV2). sha256: the GitHub `digest` (R-CV3). URL: `https://github.com/<source>/releases/download/<tag>/<asset>`. |
| R-CH5 | Id: `<name>-<date>-<sha>`. A `nightly` id is the tag text. The id is read from the right (sha, day, month, year); the rest is the name. A user-channel id never parses as a nightly or release id. The id is the `toolchains/` dir name. |
| R-CH9 | Each channel is ordered alone (R-NS1). A user-channel build counts as a nightly for the switch. `min-release-age` uses `published_at`. The R-C15 name is the channel `source`. |
| R-CV1, R-CV2, R-CV3, R-CV7 | Edited by 6.8: the `nightly` source is one channel. Behavior for `nightly` does not change (main guard). |
| R-LY1, R-CH17 | The kind of an installed dir. GC treats a user-channel build as a nightly. |
| R-C15 | The name for `min-release-age-exclude`. |

Design Q614 (G-C244) changes R-CH3, R-CH4, R-CH5, R-CH9 in 6.8 (the answers are below).

Source: research/compiler-channels/PROPOSAL.md (1.1, 1.4), DESIGN-CLI.md 6.8, row 239 of docs/slices/PLAN-P2-CLI.md.

Out of scope (later slices, not tested here): install and trust (240), selection and ranges (241), the `tln roc channel` commands (242), use, upgrade, GC (243). So this slice has L0 tests only. An L2 case needs a command that lists or installs a user channel, and none exists before 240.

## Scope

Facts found in the code (before any change). Each row is one nightly assumption.

| Assumption | Where | Callers | Test |
| --- | --- | --- | --- |
| The tag literal `nightly-` | `Nightlies.parts` (Nightlies.roc:78), `Selector.is_nightly_tag` (Selector.roc:102), `PinOrder.nightly_key` (PinOrder.roc:108) | `Nightlies.releases` (read_release), `same_nightly`, `sort_key`, `from_rows`, `row_changes`, `Selector.parse`, `Pin.is_nightly` | ChannelreleaseTest 1, 2, 7, 8 |
| The id is the tag | `Nightlies.releases` (read_release) | `Nightlies.order`, `pick`, `pins`, `list!` | ChannelreleaseTest 3, 7 |
| Asset prefix `roc_nightly-<target>-` | `Nightlies.releases` (read_release; the text is in the function body) | the asset choice of each list | ChannelreleaseTest 4, 7 |
| Download URL `https://github.com/roc-lang/nightlies/releases/download/...` | `row_release` (private, Nightlies.roc:~262), used by `from_rows` | `list_registry!` | none (Design Q614 item 8: the URL is `browser_download_url`; `row_release` is the registry path and does not change) |
| The list source `roc-lang`, `nightlies` | `Nightlies.list!` (call of `Github.releases!`) and its failure text | `list_of!`, then each command that lists compilers | not L0 (a fetch). Slice 240. |
| Order by the date of `parts` | `sort_key` (Nightlies.roc) | `Nightlies.order` | ChannelreleaseTest 9. Red now: a `reify-...` id has the key `[0,0,0,published_at]`. |
| Name `roc-lang/nightlies` | `Age.compiler_name` (Age.roc:56) | `Nightlies.visible` (exclude), `Age.note` callers | ChannelidTest 7, ChannelreleaseTest 10 |
| `Pin.is_nightly` is the form of the tag only | `PinOrder.is_nightly` (PinOrder.roc:11), `Pin.is_nightly` (Pin.roc:50) | 12 callers in cli/lib, see Q5 | ChannelidTest 3 (guard), 4 |
| Kind by `starts_with("nightly-")` | `TalonRemove.kind_of` (TalonRemove.roc:357, private) | `TalonRemove.describe_compilers` (count words use prefixes too, :99 to :106) | ChannelidTest 6 |
| Kind by `Pin.is_nightly` | `Manage.kind_of` (Manage.roc:50) | `Manage.rows`, `roc list` | ChannelidTest 5 |
| `Pin.local_build` prefixes `git-`, `link-`, `copy-` | Pin.roc:327 | `Pin`, `Manage.kind_of` | see Q4 |

## Proposed names (TW24, for the code agent)

A name that the design does not give is a proposal. The code agent may change a name with the test agent. Until the names exist, the two new test files do not compile: red on purpose (as slices 236 and 238).

| Name | Type | Rule |
| --- | --- | --- |
| channel entry | the record `{ name : Str, source : Str, tag_prefix : Str }` (shape `github-release`, as `Channel.builtin`) | R-CH4 |
| `Nightlies.parts_of` | `Str, Str -> Try({ year, month, day, sha }, [NotNightly])` (tag-prefix, tag). `parts(tag)` = `parts_of("nightly-", tag)` | R-CH4, R-CV1 |
| `Nightlies.id_of` | `{ name, tag_prefix, tag } -> Try(Str, [NotBuild])` | R-CH5 |
| `Nightlies.asset_prefix` | `{ tag_prefix, host } -> Str` | R-CH4, R-CV2 |
| `Nightlies.releases_of` | `{ host, pages, channel } -> Try(List(Release), [BadPage(U64)])`. `releases(f)` = `releases_of` with the `nightly` entry. `Release` does not change. | R-CH4 |
| `Nightlies.visible` | new optional fields `channels ?: List(entry)` and `recorded ?: List({ id, source })` | R-CH9, R-C15 |
| `Channel.parse_id` | `Str -> Try({ name, year, month, day, sha }, [NotChannelId])` | R-CH5 |
| `Pin.counts_as_nightly` | `Str -> Bool`: nightly tag or user-channel id (R-CH9). `Pin.is_nightly` keeps the tag form only (R-CH5) | R-CH5, R-CH9 |
| `Age.compiler_name_in` | `{ tables, recorded : Try(Str, [None]) }, Str -> Try(Str, [NoName])` | R-C15, R-CH9 |
| `Channel.source_check` | `Str -> Try({}, [BadSource])` | R-CH4 |
| `Channel.tag_prefix_check` | `Str -> Try({}, [BadTagPrefix])` | R-CH4 |

`Manage.kind_of` and `TalonRemove.describe_compilers` keep their names and types.

## Tests

All tests are L0. Four new files (ChannelreleaseTest, ChannelidTest, ChannelswitchTest are new; ChannelTest and ChannelreadTest get new expects) are imported by the existing driver tests/unit/l0-9.roc (no new driver). The values are the design text (Design Q612, Q614), not the code. Expects that use a new name do not compile until the code agent adds it: red on purpose (as slices 236 and 238).

| # | File | Test | Rules | State now |
| --- | --- | --- | --- | --- |
| 1 | ChannelreleaseTest | `parts_of`: nightly, reify (`nightly-reify-`) and `v-` forms; the tag of another channel is `NotNightly` for each table; a month name is a build for the `nightly` table only; `-safe`, short sha, sha not hex, day of 1 digit, lower-case month, extra part, prefix only. | R-CH4 R-CH5 R-CV1 | red on purpose |
| 2 | ChannelreleaseTest | Main guard: `Nightlies.parts` equals `parts_of("nightly-", t)` for the old tag forms. | R-CV1 R-CH2 | red on purpose (same file) |
| 3 | ChannelreleaseTest | `id_of`: nightly id = tag text (both forms); `reify-<date>-<sha>`; `mine-...` for `v-`; another table, `-safe`, a version and a user month name tag are `NotBuild`. | R-CH5 | red on purpose |
| 4 | ChannelreleaseTest | `asset_prefix` for 6 hosts, `nightly-`, `nightly-reify-`, `v-`. | R-CH4 R-CV2 R-CV8 | red on purpose |
| 5 | ChannelreleaseTest | `releases_of` with reify over 2 pages: draft, prerelease, nightly tag, `-safe`, month name tag, nightly asset, source asset skipped or `NoAsset`; `Several(2)`; `.zip` on Linux does not count; id, the digest, and the URL = `browser_download_url`. | R-CH4 R-DI3 R-CV2 R-CV3 | red on purpose |
| 6 | ChannelreleaseTest | Main guard: the `nightly` entry through `releases_of` equals `releases`. | R-CH4 R-CV1 R-CV2 | red on purpose |
| 7 | ChannelreleaseTest | `BadPage(n)` for a user channel. | R-CH4 R-DI3 | red on purpose |
| 8 | ChannelreleaseTest | `Nightlies.order` of reify ids (ISO dates): by date, then `published_at`, then text. | R-CH9 R-NS1 | red (fails now) |
| 9 | ChannelreleaseTest | `Nightlies.visible` with `channels`: age lifted by the `source` pattern; a nightly keeps `roc-lang/nightlies`. | R-CH9 R-C7 R-C15 | red on purpose (type error) |
| 10 | ChannelreleaseTest | `visible` with `channels: []` and `recorded`: the recorded `source` gives the name; none recorded: hidden by the age. | R-C15 Q614-6 | red on purpose (type error) |
| 1 | ChannelidTest | `Channel.parse_id`, 31 rows: nightly and user ids, names with `-`, `gitfork` and `my-nightly` free; no id for a month name user id, `nightly-reify-...`, `git-fork-...`, releases, local builds, bad date/sha, bad or reserved names. | R-CH5 R-CH3 Q614-4,7 | red on purpose |
| 2 | ChannelidTest | The name of 4 ids (ISO date). | R-CH5 | red on purpose |
| 3 | ChannelidTest | A user id is not nightly for `Pin.is_nightly`, `Selector.parse`, `PinOrder.is_release`; nightly forms are (guard). | R-CH5 | red on purpose (same file) |
| 4 | ChannelidTest | `Pin.counts_as_nightly`, 14 rows. | R-CH9 | red on purpose |
| 5 | ChannelidTest | `Manage.kind_of`: user build `Nightly`; `gitfork-...` `Nightly`; `git-fork-...` and `git-2026-...` `Git`. | R-LY1 R-CH17 | red (fails now) |
| 6 | ChannelidTest | `TalonRemove.describe_compilers` counts user builds with the nightlies. | R-CH17 | red (fails now) |
| 7 | ChannelidTest | `Age.compiler_name_in`: table, record, no record (`Err(NoName)`), a table wins over a record, release, nightly. | R-C15 R-CH9 Q614-6 | red on purpose |
| 8 | ChannelidTest | Main guard: `Age.compiler_name`. | R-C15 | red on purpose (same file) |
| 1 | ChannelswitchTest | `Toolchain.range_allowed`, switch off: a user build is dropped like a nightly; a release stays. | R-CH9 R-NS3 | red (fails now) |
| 2 | ChannelswitchTest | `Pin.use_gate`: user id with the switch off is a stop; with the switch on, none. | R-CH9 R-NS3 R-U5 | red (fails now) |
| 3 | ChannelswitchTest | Guard: `Compiler.kind` gives `Local` for a user id (not a nightly for roc's version). | R-SO10 R-SO11 | red on purpose (same file) |
| 4 | ChannelswitchTest | `ClosureRequest.window_of`: a user row never stays in a registry window. | R-CH16 | red (fails now) |
| new | ChannelTest | Names with a reserved start and `-` are `Reserved` (11 names); `Git-x` and `git-` are `BadName`; the old valid-names expect loses `stable-1` and gains `my-git-fork`, `x-stable-1`. | R-CH3 Q614-4 | red (fails now) |
| new | ChannelTest | `Channel.source_check` (7 good, 17 bad). | R-CH4 Q614-1 | red on purpose |
| new | ChannelTest | `Channel.tag_prefix_check` (7 good, 11 bad; the 40-character limit both sides). | R-CH4 Q614-2 | red on purpose |
| 16 | ChannelreadTest | A table named `git-fork`, `nightly-reify`, `stable-1`, `compat-x`: exit 19, `is a reserved channel name`, no hint, both files; `my-nightly` and `gitx` are free. | R-CH3 R-CH10 | red (fails now) |
| 17 | ChannelreadTest | A bad `source` or `tag-prefix`: exit 19, line of the key, no hint, both files. | R-CH4 R-CH10 | red (fails now: no check) |
| 18 | ChannelreadTest | Two faults in a file: the first by line. | R-CH10 | red (fails now) |

### Run results (TMPDIR in `.tmp/tmp`, capped scope, `$ROC` of scripts/env.sh)

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` | 95 tests: 70 pass, 10 fail, 15 compiler errors (97 errors). The failures: ChannelTest (reserved start), ChannelidTest 5 and 6, ChannelreleaseTest 8, ChannelswitchTest 1, 2 and 4, ChannelreadTest 16, 17, 18. The compile errors: `does not exist` for `Nightlies.parts_of`, `id_of`, `asset_prefix`, `releases_of`, `Channel.parse_id`, `source_check`, `tag_prefix_check`, `Pin.counts_as_nightly`, `Age.compiler_name_in`; and 2 type mismatches for the new fields of `Nightlies.visible` (`channels`, `recorded`). No other error. |
| `roc fmt --check` of the Channel*.roc files | clean |
| `MISSING=1 scripts/rules.sh R-CH3 R-CH4 R-CH5 R-CH9 R-CH16` | no rule without a test |
| `tests/commands/run.sh` (all) | 578 passed, 0 failed (run before the Q614 changes; no L2 file changed since) |

An `expect` in a file with a compile error does not run, so the guards in the red files cannot show green before the code agent adds the names. I checked their values by hand. No UPDATE=1. No L2 case is added or changed.

### Mutation check (TW12)

The code agent runs these after the code is green.

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | A tag prefix is matched with no date check (`nightly-reify-...` read by `nightly` as name `reify`) | ChannelreleaseTest 1, 6 |
| m2 | The asset prefix is `roc_nightly-` for every table | ChannelreleaseTest 4, 5 |
| m3 | The id keeps the tag text for a user channel | ChannelreleaseTest 3, 5 |
| m4 | `sort_key` stays on `parts` | ChannelreleaseTest 8 |
| m5 | `Pin.is_nightly` is true for a user id | ChannelidTest 3 |
| m6 | `counts_as_nightly` accepts a reserved name, a 6-digit sha or a month name user id | ChannelidTest 4 |
| m7 | `parse_id` reads from the left | ChannelidTest 1 |
| m8 | A user month name tag is a build | ChannelreleaseTest 1, 3, 5 |
| m9 | `name_check` tests the reserved start with no `-`, or after the syntax | ChannelTest (new), ChannelidTest 1 (`gitfork`, `my-nightly`) |
| m10 | `source_check` allows `.git`, a start with `.`, or a `/` at the end; `tag_prefix_check` has 41 or 39 as limit, or no `-` at the end | ChannelTest (new) |
| m11 | The `source`/`tag-prefix` fault has the R-TF8 hint | ChannelreadTest 17 |
| m12 | `compiler_name_in` uses the recorded source before the table, or a prefix match | ChannelidTest 7 |
| m13 | `Toolchain.range_allowed` or `use_gate` keep `is_nightly` | ChannelswitchTest 1, 2 |
| m14 | `Compiler.kind` uses `counts_as_nightly` | ChannelswitchTest 3 |
| m15 | `ClosureRequest.staying` keeps a user row | ChannelswitchTest 4 |

## Changed expectations

None. No existing test or case changes. `l0-9.roc` gets two imports.

## Answers (Design Q614)

All 8 questions of the first version were answered by the user. No Open question is left.

| Q | Answer | Tests |
| --- | --- | --- |
| Q1 `source` | `owner/repo`, 2 parts. Each part: `A-Z a-z 0-9 . _ -`, no start with `.`. No `.git` at the end, no `/` at the end. Case kept. | ChannelTest `source_check` (7 good, 17 bad), ChannelreadTest 17 |
| Q2 `tag-prefix` | 1 to 40 characters of `a-z 0-9 . _ -`, ends with `-`. | ChannelTest `tag_prefix_check` (7 good, 11 bad), ChannelreadTest 17 |
| Q3 where the check fails | At the table read: exit 19, no R-TF8 hint (as a missing key). The built-in `nightly` table is not checked (a user cannot declare it: it is reserved; nothing to test). Texts: TW24 below. | ChannelreadTest 17, 18 |
| Q4 names | A name that starts with a reserved word and `-` is refused as a reserved name (`git-`, `link-`, `copy-`, `zig-`, `nightly-`, `stable-`, `debug-`, `local-`, `compat-`). `my-nightly`, `gitx` stay valid. | ChannelTest (the old expect 4 loses `stable-1`; new expect), ChannelreadTest 16, ChannelidTest 1 |
| Q5 R-CH9 scope | A user build counts as a nightly only where the rule is the `nightly` switch (R-NS3). For the header pin, roc's version, consent and the registry it is local only (R-CH16). See the table of callers. | ChannelswitchTest, ChannelidTest 4 |
| Q6 unknown table | The R-C15 name is the `source` in `.talon.json`. None recorded: no pattern matches. | ChannelidTest 7, ChannelreleaseTest 10 |
| Q7 tag form | User-channel tag: `<tag-prefix><YYYY-MM-DD>-<sha>`. An English month name is no build. A user id has the ISO date only. | ChannelreleaseTest 1, 3, 5, 8; ChannelidTest 1, 4 |
| Q8 URL | `browser_download_url` of the answer. So `Nightlies.download_url` is dropped (the test is removed). | ChannelreleaseTest 5 |

### The 12 callers of `Pin.is_nightly` (Design Q614 item 5)

| # | Caller | What it decides | Class | After 239 | L0 test |
| --- | --- | --- | --- | --- | --- |
| 1 | `Compiler.kind` (Compiler.roc:25) | R-SO10, R-SO11: the kind of roc's own version | header/roc version | keeps `is_nightly`; a user id is `Local` | ChannelswitchTest 3 (guard, green once the file compiles) |
| 2 | `Compiler.in_range` (Compiler.roc:229) | R-NS3: the newest installed compiler in the range under the switch | switch | `counts_as_nightly`. But `Pin.is_id` is false for a user id, so it is never a candidate here. Slice 241 (selection). | none |
| 3 | `Toolchain.range_allowed` (Toolchain.roc:138) | R-NS3: the range pick under the switch | switch | `counts_as_nightly` | ChannelswitchTest 1 |
| 4 | `Frozen.pin_finding` (Frozen.roc:57) | R-NS5, R-SO17: a `roc:` header pin against the switch | header pin | keeps `is_nightly` (R-CH6: a header never holds a user id) | none (no change) |
| 5 | `Pin.outside_failure` (Pin.roc:184) | R-RP2: a header pin outside the range or the switch | header pin | keeps `is_nightly` | none (no change) |
| 6 | `Pin.use_gate` (Pin.roc:223) | R-U5: `tln roc use <id>` against the switch | switch | `counts_as_nightly` | ChannelswitchTest 2 |
| 7 | `Pin.gate` (Pin.roc:273) | R-SO19: a held compiler against the switch | switch | `counts_as_nightly`. Today `Pin.is_id` is false for a user id, so `gate` returns `Ok({})` before the switch. The change is in slice 241 with `is_id`. | none |
| 8 | `Pin.outside_pin` (Pin.roc:343, private) | R-RP2: a header pin | header pin | keeps `is_nightly` | none (no change) |
| 9 | `NightlyFlow` (NightlyFlow.roc:108) | R-NS2: a missing baseline needs a source (`Compiler.require`) | consent | keeps `is_nightly`: a user build has no source here (local only) | none (no change) |
| 10 | `ClosureRequest.staying` (ClosureRequest.roc:79) | R-AP16: the window of a registry request. Today `!is_nightly or switch` keeps any id that is not a nightly, so a user id would stay. | registry | keeps `is_nightly` for the switch test, and the row must be dropped: a user build is never in a registry window (R-CH16) | ChannelswitchTest 4 (red: with only user rows the window is a compiler, it must be `NoCompiler`) |
| 11 | `RocUse.missing_baselines` (RocUse.roc:281) | R-NS2: a missing baseline needs consent and a source | consent | keeps `is_nightly` | none (no change) |
| 12 | `Consent` row 1 (Consent.roc:309) | R-NS2: no source of releases for an id that is not a nightly tag | consent | keeps `is_nightly`; the download of a user channel is slice 240 | none (no change) |
| 13 | `Manage.kind_of` (Manage.roc:56) | R-LY1: the kind in `tln roc list` | listing | Not one of the 5 classes. R-CH17 and R-GC5 say GC treats a user build as a nightly, so the test gives `Nightly`. Please confirm at the review. | ChannelidTest 5 |
| 14 | `PinOrder` (id_kind, nightly_key, at_least, PinOrder.roc:25, 52, 108) | R-NS1 order and R-CV1 identity inside one channel | order | not changed. `Nightlies.order` has its own key (ChannelreleaseTest 9). `Pin.order` over user ids is slice 241. | none |

(The count is 12 callers in other files, plus `Manage.kind_of` and `PinOrder`, which sit in the same grep. `TalonRemove.kind_of` and its count words are a prefix test, not `Pin.is_nightly`: ChannelidTest 6.)

## Output (TW24)

New fault texts (accepted by the user 2026-11-10, both files, exit 19, no hint line, at the line of the key): `channels.<name>.source: '<value>' is not owner/repo`, and `channels.<name>.tag-prefix: '<value>' is not a tag prefix`. A name with a reserved start has the text of a reserved name.

This slice adds no other output text. The new names above are proposals for the code agent. The words of `tool remove` (`nightlies` for user-channel builds) follow R-CH17; the user accepted them on 2026-11-10.
