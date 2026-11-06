# 211 Short names

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Plan row 211 of `PLAN-P2-CLI.md`. The new module is `cli/lib/ShortNames.roc` (exposed in `cli/lib/main.roc`). `Lookup` (`cli/lib/Lookup.roc`) gains 2 functions: `needs_registry` and `registry`. The reads go through `RegistryCache.get!` (slice 202), the limit is `ClosureRequest.check_shorts` (slice 205), the failures are `Registry.refuse` (slice 201). The wire types are `records.Short` (`decode_matches`, `decode_packages`: slice 104e). No change of the `Fx` record. No guard call: `?short=` and `?q=` carry only what the user typed (R-RG4).

## Seam and scope

`Lookup` has a seam for the short name result, in two places: `install_missing` (the `Install` scope, form `Bare`, R-AD6: "no index of short names") and `missing` (the `Tool` and `X` scopes, R-AD7). Both stay as they are for `direct`. This slice adds the registry versions as new functions, so no caller changes:

| Function | Job |
| --- | --- |
| `Lookup.needs_registry(scope, ref, entities)` | Does this name go in the one `?short=` request of the command (R-I8: all keys first)? |
| `ShortNames.lookup!` | The one request, the hide of `log:N`, the outcome of each name, the `?q=` suggestions for each name with no match |
| `Lookup.registry(scope, ref, found)` | The result of one name: use it with the matched line (R-AD3), or the failure with its list (R-AD4, R-AD5, R-AD7) |

Out of scope (the command wiring): `PickFlow.asked!`, `InstallFlow` (R-I8: collect all keys first, write nothing, list each key), `ToolFlow`, `RunFlow` and the printing of the matched line and the block, the choice of registry or `direct` (R-AD6, slice 206), the `Source.Short` call of the guard (not needed: R-RG4). The L2 word `short` of `tests/commands/L2Registry.roc` stands in for the command.

## Rules

R-AD3, R-AD4, R-AD5, R-AD7, R-AD34, R-SN1 (the limit of 50), R-SN4, R-SN5, R-SN6, R-AP33, R-I8, R-AP24 and R-IX6 (the read cache and `--offline`), R-RG4 (no guard), R-E6, R-EC15, R-EC2 (exit 2).

## Public signatures (stubs, `crash "todo: slice 211"`)

| Name | Signature |
| --- | --- |
| `ShortNames.State`, `Item`, `Hit`, `Outcome`, `Found` | `[Active, Missing, Moved]`; `{ name, first_log_index, state, moved_from : Try(Str, [None]) }`; `{ name, first_log_index, state }`; `[One(Item), Many(List(Item)), NoMatch]`; `{ short, outcome, suggest : List(Hit) }` |
| `ShortNames.short_path` | `List(Str) -> Str`: `/v1/packages?short=a&short=b` with `Registry.encode`, repeats kept |
| `ShortNames.search_path` | `Str -> Str`: `/v1/packages?q=<text>` |
| `ShortNames.entries` | `{ origin, body, shorts } -> Try(List(List(Item)), Fail)`: entry i for value i, exit 15 for a bad body or a wrong count |
| `ShortNames.hits` | `{ origin, body } -> Try(List(Hit), Fail)` |
| `ShortNames.visible_items`, `visible_hits` | `{ items or hits, snapshot : Try(U64, [None]) } -> List(...)`: hide `first_log_index > N` |
| `ShortNames.outcome` | `List(Item) -> Outcome` |
| `ShortNames.matched_line`, `list_lines` | `{ short, item } -> Str`; `List(Item) -> Str` |
| `ShortNames.lookup!` | `Fx, { roots, origin, version, now, offline, snapshot, shorts } => Try(List(Found), Fail)`. The doc has the table of the calls |
| `Lookup.needs_registry` | `Scope, Ref, List(Lookup.Entity) -> Bool` |
| `Lookup.registry` | `Scope, Ref, ShortNames.Found -> Try({ lookup : Lookup, matched : Try(Str, [None]) }, { fail, block })` |

`ShortNames` does not import `Lookup` (`Lookup` imports `ShortNames`). Do not name a local `outcome`, `entries`, `hits` or `path` in `ShortNames`: names of the type block share the scope (duplicate definition error).

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/ShortnamesTest.roc` (driver `l0-2.roc`), 11 `expect`s. `short_path` and `search_path` (repeat, encoding, none). `entries` with the real bodies (one, two with an empty entry, moved_from, states, entry i by position). `entries` bad: 8 bad bodies and 2 wrong counts. `hits`. `visible_items` and `visible_hits` (the border at N). `outcome`. `matched_line` and `list_lines`. `Lookup.needs_registry` (the table of 5 scopes and 3 forms). `Lookup.registry`: `Install` with one match (also moved), many, none (with and without suggestions), `Tool` and `X` (one, many, none) | R-SN6, R-AP69, R-SN5, R-AP33, R-SN9, R-AP51, R-E6, R-SN4, R-AD34, R-AD3, R-AD4, R-AD5, R-AD7, R-I8, R-AD1, R-AD2, R-SN3, R-SC6 to R-SC8, R-EC2 |
| L2 | `tests/commands/cases/registry/sn6-short-names` (entry `registry`, word `short`): 17 runs. One name (use, the one request, no guard, no `Authorization`). Two names in ONE request with entry i for value i, and `moved_from`. Many (list, exit 2). None (the `?q=` request, the suggestions, exit 2). `tool` and `x` (one and many matches listed, never picked, from the copy). `log=5` (the item above 5 hidden from the copy: one match). `log=0` (both hidden, the `?q=` hits hidden too). A repeated value. A name that is an alias is not asked (R-I8). Offline with no copy (exit 15) and with a copy. 51 names (exit 2, no call). 0 entries for 1 name (exit 15). A 400 (exit 1). All names local (no call). Full and `host/path` names are not asked | R-AD3, R-AD4, R-AD5, R-AD7, R-AD34, R-SN1, R-SN4, R-SN5, R-SN6, R-AP33, R-I8, R-RG4, R-AP24, R-IX6, R-E6, R-EC15 |

## Readings that the design implies (tested)

| # | Reading |
| --- | --- |
| 1 | One request for all names of a command that need a search (R-SN6, R-AD34). A name that is a header alias (`Install`) or has a local match (`Tool`, `X`) is not asked, so the `short=` list is the asked names only (R-I8: "all such keys") |
| 2 | Entry i of `matches` is for value i, whatever its `short` text says, and also for 2 equal values (R-SN6) |
| 3 | The hide of `log:N` is made on the answer: the copy in `get/` keeps all matches (R-SN4, R-AD34), so the same copy serves each snapshot |
| 4 | `Missing` and `Moved` items count as matches (R-SN2: too wide is safe) |
| 5 | `tln tool install` and `tln x` never use a registry match (R-AD7), also one match. They list it and stop with exit 2 |
| 6 | No match: the `?q=` result is only listed (R-SN5, R-AD34: never selected) |
| 7 | `--offline` uses the copy of the `?short=` answer at any age. No copy: exit 15 (R-IX6) |
| 8 | More than 50 values: exit 2 before any request (R-AD34, R-SN1, `check_shorts`) |

## Decisions that the design does not fix (for the review)

| # | Decision | Rejected |
| --- | --- | --- |
| 1 | `?q=` is read only for a name with no match, one request for each such name, one after the other, with the same cache and `--offline` rules. It needs no guard (R-RG4 lists the guarded requests: `?q=` is not one) | A `?q=` for each name. A guard for `?q=` |
| 2 | The `?q=` hits are hidden above `log:N` as the matches are (R-SN6 says their `first_log_index` is as R-SN4 says) | Show all hits |
| 3 | `short_path` does not remove a repeated value: the caller gives the values (the 50 limit counts them, R-SN7 row 2 and R-AP46 count values) | Remove repeats in `short_path` |
| 4 | A wrong number of entries is exit 15 (R-E6 last row, R-AP51 "a missing member"), because entry i could not be read | Read the entries by their `short` text |
| 5 | A list line is `  <full name>` and, for `moved_from`, ` (moved from <old>)`. The `state` of an item is not shown (the R-TP14 note of a `moved` item and the R-AP32 notes are a later slice) | Show `state` |
| 6 | Local names are skipped by `needs_registry`. A tie of local matches in `Tool` or `X` is "a match": the old `Lookup.find` tie text is the result, no search | Search also a tie |
| 7 | `Lookup.registry` for `Install` keeps `ref.name` as typed in the matched line (`Parser` stays `Parser`) | The lower-case name |

## Output (proposed, TW24)

| Case | Kind | Text |
| --- | --- | --- |
| R-AD3 | note (stream: the flow decides) | `matched "<short>": <name>` and ` (moved from <old>)` for a replaced name (R-AP33) |
| R-AD4, `Install` | usage (2), block then line | block `"<x>" matches <n> packages:` and `  <name>` lines. Line `"<x>" matches <n> packages. Use a name from the list.` |
| R-AD5, `Install` | usage (2) | `"<x>" matches no indexed package. Use the full name (owner/repo).` With suggestions, block `Similar names:` and `  <name>` lines |
| R-AD7, `Tool` and `X` | usage (2) | `'<x>' matches no installed tool or cached app. Use the full name (owner/repo).` (the text of `Lookup.missing`), with the block `Registry matches for "<x>":` and `  <name>` lines when the registry has a match |
| `--offline`, no copy | network (15) | `the registry <origin> is not asked (--offline) and Talon has no kept answer for <v1>, <v2>. Run the command with no --offline.` |
| A body that does not decode, a wrong count | network (15) | `the answer of the registry <origin> is not a short-name answer: <reason>` (`<n> entries for <m> names`), `... is not a package search answer: <reason>` |
| More than 50 | usage (2) | the text of `ClosureRequest.check_shorts` (slice 205) |

`--json` `data` (proposal): the use of a match is `notes[]` with `{"kind":"matched","short":<text>,"name":<text>,"moved_from":<text or absent>}`. A failure has no new `error.details` field.

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | R-I8 for `tln install` with several short keys: the keys that fail are all listed in one stop. Does the stop print the blocks of all failing keys before one failure line (the `block` of each, then one line), and which line? The functions give one failure for one name | Open, G-C44, flow wiring (out of scope) |
| Q2 | A short name with a selector (`tln add parser@2`, R-SC16): the registry is asked with the name only, and the selector applies to the chosen package. This slice reads `ref.name` | Open, G-C44, flow |
| Q3 | A `?q=` read that fails (no answer, 5xx, `--offline` with no copy, a bad body): no suggestion and exit 2 (the reference), or the failure of that read (15)? R-SN5 says suggestions are only for display | Open, G-C44, untested |
| Q4 | The hide of the `?q=` hits above `log:N` (R-SN6 says `first_log_index` is as R-SN4 says). The tests hide them | Proposal used (accepted by the manager) (L2 run 8) |
| Q5 | Does `needs_registry` also give true for a short name in the `Project` scope (`update parser`, `why parser`)? R-SC1 to R-SC8 say these commands look only in the project. The tests say no | Proposal used (accepted by the manager) (reading of R-SC1) |

## Disputes (from the code agent)

None yet.

## Red result

| Layer | Result |
| --- | --- |
| L0 (`roc test tests/unit/l0-2.roc --no-cache`) | 86 expects: 75 pass, 11 fail. All 11 `ShortnamesTest` expects fail with `todo: slice 211`. Log `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red211-l0.log` |
| L2 (`tests/commands/run.sh registry/`) | `registry/sn6-short-names` fails with `[ROC CRASHED] todo: slice 211`. Log `.../scratchpad/red211-l2.log` |

## Revert check

`research/slice-211-revert/before/` has the files that the slice changed (`cli/lib/main.roc` and `cli/lib/Lookup.roc` as they were before this slice, `tests/commands/L2Registry.roc` and `PLAN-P2-CLI.md` after slice 204, `tests/unit/l0-2.roc`) and `NEW.txt`. `research/slice-211-revert/reference/` has the private green reference (`ShortNames.roc`, `Lookup.roc`): all 86 L0 and the L2 case pass with it (the expected files come from it). Mutations of the reference, each caught:

| # | Mutation | L0 | L2 |
| --- | --- | --- | --- |
| M1 | The hide keeps an item at N (`<` for `<=`) | fail | pass |
| M2 | Entry i is found by its `short` text, not by position | fail | pass |
| M3 | `needs_registry` of `Tool` and `X` is always true | fail | pass |
| M4 | `?q=` is read for each name, not only for no match | pass | fail |
| M5 | The limit of 50 is checked after the request | pass | fail |

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| Tests (code agent) | l0-2 86 of 86. `registry/sn6-short-names` passes. `scripts/test.sh check` passes. |
| Expected exits (manager check) | 2 for the short-name stops (several matches, none, tool and x list, 51 names, alias), 15 for offline with no copy and a bad answer, 1 for a 400. All are rules. |
| Revert check | Test step: M1 to M5 caught. |
| Follow-up | 204b: Q223 (one R-I8 stop that lists every failing name; the selector is kept on the match). |
