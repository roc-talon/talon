# 205 Closure request

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Plan row 205 of `PLAN-P2-CLI.md`. Pure, L0 only. The module is `cli/lib/ClosureRequest.roc`. It builds the body of `POST /v1/closure` (R-AP16). The type of the body is `records.Closure.Request` and the codec is `records.Closure.encode_request` (R-PK7): records has the type, so there is no local type. The dependency and the `Wire` alias are as in slice 201 (the module name `Closure` is taken by `cli/lib/Closure.roc`). `Registry.closure_url` (slice 201) is the URL. The module takes plain facts, not the big `ResolveBase.Request`, so the seam in slice 206 builds `Facts` from it.

## Rules

R-AP16, R-AP60, R-AP61, R-ID7, R-DI1 (registry part), R-AP78, R-AP46 (the client limits). As used: R-NS1, R-NS2, R-NS3, R-NS7, R-C7, R-C15, R-DT3, R-DT4.

## Public signatures (stubs, `crash "todo: slice 205"`)

| Name | Signature |
| --- | --- |
| `ClosureRequest.Group` | `{ group : Str, series : Try(Str, [None]), range : Try(Str, [None]) }` |
| `ClosureRequest.Row` | `{ id : Str, published_at : U64, log_index : U64 }`, a row of the compiler list (R-AP5) |
| `ClosureRequest.Snapshot` | `[None, Time(U64), Log(U64)]` |
| `ClosureRequest.Domain` | `{ rows, nightly : Bool, req : Try(Str, [Unset]), now, min_age, exclude, snapshot }` |
| `ClosureRequest.Window` | `[None, Held(Str), Free(Domain)]` |
| `ClosureRequest.Facts` | `{ groups, entries : List(Str), window }` |
| `ClosureRequest.request` | `Facts -> Try(Wire.Request, [NoCompiler])` |
| `ClosureRequest.body` | `Facts -> Try(Str, [NoCompiler])` |
| `ClosureRequest.check` | `{ groups, hashes, bytes : U64 } -> Try({}, Fail)`: R-AP78 limits, exit 1 |
| `ClosureRequest.check_shorts` | `U64 -> Try({}, Fail)`: more than 50 short names, exit 2 (slice 211 calls it) |

## The tested reading

| # | Topic | Reading |
| --- | --- | --- |
| 1 | `groups` | As given, in order (the caller orders the variables; R-AP16 lists which groups) |
| 2 | `hashes` | One for each entry that is a release URL (`Ident.of_url`), in the order of `entries`, a repeat is kept (the Worker reads it once, R-AP59). A path entry or a URL with no version gives none (R-ID7: hand edits still work, the rest is slice 208) |
| 3 | Window `None` | `tln probe --range`: no `compilers` member |
| 4 | Window `Held(id)` | `from` = `to` = the pin as written: a listed nightly, an unlisted nightly or a release (R-AP60). The list is not read |
| 5 | Window `Free(domain)` | The oldest and the newest row that stays, in the order of R-NS1 (`Pin.order`): a nightly only with the switch on (R-NS2: the list has nightlies only, so a switch off leaves nothing); the `[toolchain] roc` range (`Pin.admits`, R-NS7: a semver range matches no nightly); `min-release-age` with `min-release-age-exclude` (`Age.hides`, R-C7, R-C15); the snapshot (`Time(t)`: `published_at <= t`, `Log(n)`: `log_index <= n`, R-DT3, R-DT4) |
| 6 | No compiler stays | `Err(NoCompiler)`. R-AP61 says that the client sends an empty window in this case, but not which one (Q3) |
| 7 | Body text | The members in the order of the codec of `records` (`compilers`, `groups`, `hashes`), an absent optional member left out |

## Tests (`tests/unit/ClosurerequestTest.roc`, driver `l0-8.roc`)

| Layer | Case | Rules |
| --- | --- | --- |
| L0 | Groups, hashes (path and foreign entries skipped, a repeat kept), no window, exact text, the empty request | R-AP16, R-ID7, R-DI1 |
| L0 | Held: listed, unlisted nightly, release, exact text | R-AP16, R-AP60 |
| L0 | Free: default age (2 days), no age, exclude pattern, other pattern, one row | R-AP16, R-NS1, R-NS3, R-C7, R-C15 |
| L0 | Free: `>=` and `=` range, time snapshot, log snapshot, log and range | R-NS7, R-C7, R-DT3, R-DT4 |
| L0 | Limits: 300, 1000 and 262144 valid, one more is exit 1 with item, count and limit, the check order body, groups, hashes | R-AP78, R-AP46 |
| L0 | 50 short names valid, 51 is exit 2 | R-AP78, R-AP46, R-SN1 |
| L0 | No compiler: switch off, semver range, all young, snapshot before the first, `log:0`, empty list, the body | R-AP61, R-NS2, R-NS7 |

Red result: 7 `expect`s fail with `todo: slice 205` (log `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red.log`).

Revert check (`research/slice-205-revert/before/`; the reference and `mutate.py` are deleted): reference green, then 4 mutations (and 1 of `check`, `>=` for `groups`) each caught: M7 held `to` missing, M8 no `min-release-age`, M9 `log_index < n`, M10 the switch ignored.

## Output (proposed, R-OUT2)

| Case | Kind | Message |
| --- | --- | --- |
| Over a limit | internal (1) | `the closure query has <count> <item>, over the limit of <limit>: the project is past what Talon supports now` |
| More than 50 short names | usage (2) | `<count> short names are over the limit of 50: use full names (owner/repo) or run 2 commands` |

## Out of scope

| Item | Reason |
| --- | --- |
| The second query of a held move (R-SP24) and the `log:N` of the first `log_size` | Slice 207 |
| The `groups` of each variable (which groups, which `series`) and the join of 2 or more ranges | Slice 206 (the seam). Q2 |
| The `hashes` of a header value on a private host, and the 429 or label cases | Slice 208 |
| R-AP59 (a text that is not a hash) | Worker rule. The client sends the hash of a URL only |

## Questions

| # | Question | State |
| --- | --- | --- |
| Q1 | Client limits | Answered (Design Q204, R-AP78): check before the send, no split. Groups, hashes, body: exit 1. More than 50 short names: exit 2. `check` and `check_shorts`, tested. The order of the checks and the message text are proposals. |
| Q2 | One `range` text for a variable with 2 or more ranges | Answered (Design Q196, R-AP74 row 3): the distinct ranges, joined with `, `, `*` dropped. `join_ranges`, slice 205b. |
| Q3 | What the client sends when no compiler is allowed (R-AP61) | Answered (Design Q197, R-AP74 row 4): exit 10 for a command that chooses, no `compilers` for a report. Slice 205b. |
| Q4 | `hashes`: all entries, or only those that no group gives | Answered (Design Q198, R-AP74 row 5): all entries with a hash, each once. Slice 205b changes reading 2. |
| Q5 | Does the registry list compiler releases | Answered (Design Q199, R-AP74 row 6): nightlies only. Slice 205b. |

## Disputes (from the code agent)

None. Note: `roc test` prints a warning "duplicate definition" for `groups` in the last-but-one `expect` of `ClosurerequestTest.roc` (line 116 shadows line 22). The test passes. The test agent may rename the local.

## Verify results

Code agent: no mutation run yet (step 4 of the manager). L0 (`roc test tests/unit/l0-8.roc`): 106 passed. `roc check cli/main.roc` and `tests/commands/main.roc`: no errors. Code copy: `research/slice-NNN-revert/code-final/`.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo` of this slice | None |
| `roc test tests/unit/l0-8.roc --no-cache` | 106 pass, exit 0 (after the test agent renamed a local `groups` that gave a duplicate-definition warning, exit 2) |
| `roc check` of `cli/main.roc` and `tests/commands/main.roc` | No errors |
| Revert check | Test step: mutations caught, as listed in the test sections. The code step ran none (TW12). |
| Open | G-C24 to G-C29 (API design agent). The 2 or 19 exit code by the source of the setting goes to a flow slice. |
