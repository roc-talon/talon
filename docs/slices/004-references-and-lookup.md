# 004 References and lookup

Phase: P0. Status: verify

Slice 004 makes the pure decisions about names: the grammar of a reference and its selector, the scope of each command, the lookup of a name with no registry (`direct`), the default alias and its checks, the identity of a release, and the plan that `tln add X[@sel]` gives for the header and for `talon.toml` (as data). It has no effect and no index call. The `Fx` record does not change. The decisions are stubs (`crash "todo"`) and their tests are red.

## Rules

| Group | Ids | Design | Where tested |
| --- | --- | --- | --- |
| Reference grammar | R-SL1, R-SL2 | CLI 2 | `ref.roc` |
| Selectors | R-SL3 to R-SL13, R-SL15 | CLI 2 | `selector.roc`, `ref.roc`, `sl-bad-refs` |
| Scopes | R-SC1 to R-SC5 | CLI 2 | `ref.roc` (`Scope.of_command`) |
| Forms of a name | R-SC6 to R-SC9, R-SC14 | CLI 2 | `lookup.roc`, `ref.roc` (R-SC9 parse only) |
| Lookup in `tln add`, no registry | R-AD1, R-AD2, R-AD6, R-AD7 | CLI 2 | `lookup.roc` |
| Default alias and checks | R-AD8 to R-AD19 | CLI 2 | `alias.roc`, `add.roc` |
| Entry in the header | R-AD20 to R-AD22, R-I9 | CLI 2, Design 4.3 | `add.roc` |
| What `tln add` writes to `talon.toml` | R-AD23 to R-AD28 | CLI 2 | `add.roc`, `sl-bad-refs` (R-AD28) |
| `tln add --platform` | R-AD29 to R-AD33 | CLI 2 | `add.roc` |
| Identity | R-ID1 to R-ID5 | Design 4.1 | `ident.roc` |
| Security | R-SE7 (notice for a platform change) | Design 8 | `add.roc` |

## Files

| Path | Writer | State |
| --- | --- | --- |
| `cli/lib/Scope.roc`, `Selector.roc`, `Ref.roc`, `Ident.roc`, `Alias.roc`, `Lookup.roc`, `Add.roc` | Stubs from the test agent. Bodies from the code agent. | Compile. Doc comments hold the contract. |
| `cli/lib/main.roc` | Slice 001 owns it. This slice added the 7 module names to the exposes list and the 2 package entries below. | Release URLs only (R-GP3) |
| `tests/unit/selector.roc`, `ref.roc`, `ident.roc`, `alias.roc`, `lookup.roc`, `add.roc` | Test agent | 18 `expect`s, red ("todo") |
| `tests/scenarios/refs/sl-bad-refs/` | Test agent | 1 L3 case, red |

Package entries added to `cli/lib/main.roc` (the URLs of `docs/slices/PLAN.md`):

| Alias | Package | Used by |
| --- | --- | --- |
| `header` | `roc-app-header` 0.1.0 | `Ident` (`PackageUrl.parse`, `url_form`, `group`, `series`) |
| `semver` | `roc-semver` 0.1.0 | `Selector` (`Semver.parse`, `VersionReq.parse`) |

The generic packages are not tested again (R-GP5). The tests check the Talon use of them.

## Public signatures

Each module is a pure type module in `cli/lib/`. No function has an effect. The doc comment of each stub has the full contract, the rule ids and the message texts.

| Module | Function | Type | Rules |
| --- | --- | --- | --- |
| `Scope` | `of_command` | `List(Str) -> Try(Scope, [NoScope])`. Tags: `Install`, `Project`, `Tool`, `X`, `Roc` | R-SC1 to R-SC5 |
| `Selector` | `parse` | `Str, Bool -> Try(Selector, [Empty, Unknown])`. The `Bool` is `--git`. Tags: `Exact(Str)`, `Range(Str)`, `Latest`, `Nightly(Str)`, `Step(I64)`, `GitSha(Str)`, `GitRef(Str)` | R-SL3 to R-SL13, R-SL15 |
| `Ref` | `parse` | `Str, Scope, Bool -> Try(Ref, Fail)`. `Ref` has `form : [Bare, Full, HostPath]`, `name : Str`, `selector : Try(Selector, [None])` | R-SL1, R-SL2, R-SL6, R-SL7, R-SL12, R-SL13, R-SC7, R-SC9 |
| `Ident` | `of_url` | `Str -> Try(Ident, [Foreign])`. Fields: `url`, `name`, `version`, `series`, `group`, `label`, `hash` | R-ID1 to R-ID5 |
| `Ident` | `series_of` | `Str -> Try(Str, [BadVersion])` | R-ID1 |
| `Alias` | `default` | `Str -> Str` (full name to the unchecked default alias) | R-AD8 to R-AD12, R-AD15 |
| `Alias` | `check` | `Str -> Try({}, [NotName, Reserved])` | R-AD14, R-AD16, R-AD17 |
| `Alias` | `choose` | `{ name, url, is_platform, as_alias, header } -> Try(Alias, Fail)`. `Alias` is `New(Str)` or `Existing(Str)` | R-AD13, R-AD16 to R-AD20, R-I9 |
| `Lookup` | `find` | `Scope, Ref, List({ alias, name, note }) -> Try(Lookup, { fail : Fail, block : Str })`. `Lookup` is `Existing({ alias, name })` or `New(Str)` | R-SC6 to R-SC8, R-SC14, R-AD1, R-AD2, R-AD6, R-AD7 |
| `Add` | `decide` | `{ selector, chosen : { name, url, kind }, platform_flag, no_pin, as_alias, header } -> Try(Add, Fail)` | R-AD20 to R-AD33, R-SE7 |
| `Add` | `decide_alias` | `{ alias, selector, no_pin, header } -> Try(Add, Fail)` (the ref is a header alias) | R-AD21, R-AD22 |
| `Add` | `check_names` | `{ names : U64, as_alias } -> Try({}, Fail)` | R-AD28, R-FL12 |

`Add` is the plan: `alias`, `header : [Insert, Replace, Keep, Update]`, `url`, `toml : Try({ key, value }, [Nothing])`, `note : Try(Str, [None])`.

The header rows (`header` in `Alias.choose` and `Add`) are `{ alias, url, is_platform }`, one for each entry of the header. A path entry has its path in `url`. `Ident.of_url` gives `Foreign` for it. Slice 005 (the header read) gives these rows.

## Rules for the code agent

### Selector and reference (R-SL, R-SC)

| # | Rule | Source |
| --- | --- | --- |
| S1 | `Selector.parse` order, `git` not set: empty, `latest`, nightly tag, step, `Semver.parse` (Exact), `VersionReq.parse` (Range), hex of 7 or more characters (GitSha), else `Unknown`. With `git`: any non-empty text is `GitRef`. | R-SL9 to R-SL13 |
| S2 | `Range(text)`: the typed text. A bare version with 1 or 2 parts (digits and dots only) gets `^` in front. | R-SL15, R-AD26 |
| S3 | `Ref.parse`: cut the text at the first `@`. The name has no `/` (`Bare`), one `/` with 2 non-empty parts (`Full`), or 2 or more `/` with no empty part and a `.` in the first part (`HostPath`). Else a failure. | R-SL1, D6 |
| S4 | Scope `Roc`: `@sel` is `roc-lang/roc@sel`. A full nightly tag with no `@` is `roc-lang/roc@<tag>`. Other texts parse as in the other scopes (a prefix such as `git-dd03` is `Bare`). | R-SL2, R-SC9 |
| S5 | Other scopes: a text that starts with `@` is a failure. `Nightly` and `Step` are a failure. | R-SL2, R-SL6, R-SL7 |
| S6 | `Lookup.find`, `Install`: form 1 only looks in the entities. A full name is `New`. A short name is the R-AD6 failure. Other scopes: forms 1, 2, 3 in order. Form 3 matches the repo name or the repo name minus a leading `roc-`, only for a name with exactly one `/`. 2 or more matches are a tie. | R-SC6 to R-SC8, R-SN3 |
| S7 | A header entry with no group (`Foreign`) still holds its alias. | R-H4, R-AD18 |

### Wiring in `Run.run!` (slice 001 owns `Run.roc`: the code agent of 004 edits it after 001 is done)

| # | Rule |
| --- | --- |
| W1 | After `Args.parse`, for the commands `install`, `update`, `upgrade`, `remove`, `why`, `patch`: take `Scope.of_command(args.command)`, and parse each operand with `Ref.parse(operand, scope, git)`. `git` is true when `options` has `--git`. The first failure goes to `Out.fail` (kind `Usage`, exit 2). |
| W2 | `probe` is not in W1: its operand can be a path to a bundle file (R-SC1). `tool`, `x` and `roc` are P1. |
| W3 | For `install`, then call `Add.check_names` with the number of operands and the value of `--as`. |
| W4 | The checks of W1 and W3 run before the project file is read, and before any index call (R-SL13). After them, a known command still gives the skeleton failure of slice 001 (`command '<name>' is not built yet`). Slice 007 replaces it. |

## Tests

L0 (18 `expect`s, `roc test`). Each `expect` checks a table of cases and prints the wrong rows with `dbg`. A failure of a case is compared as the text of its stderr line.

| File | `expect`s | Checks |
| --- | --- | --- |
| `tests/unit/selector.roc` | 2 | Selector forms with no `--git`: version, range, series, `latest`, 2 nightly forms, steps, sha, 4 error rows (R-SL3 to R-SL7, R-SL9, R-SL10, R-SL12, R-SL13, R-SL15). With `--git` (R-SL8, R-SL9, R-SL11, R-SL13). |
| `tests/unit/ref.roc` | 4 | Name forms and selector in a package scope (R-SL1, R-SL4, R-SL5, R-SC6, R-SC7, R-ID3). Scope `Roc`: `@sel`, nightly tag, prefix, `--git` (R-SL2, R-SL6, R-SL7, R-SL8, R-SL11, R-SC9). 11 bad refs with their messages (R-SL1, R-SL2, R-SL6, R-SL7, R-SL12, R-SL13, R-EC2). `Scope.of_command` (R-SC1 to R-SC5). |
| `tests/unit/ident.roc` | 2 | Identity of 4 GitHub releases and 4 foreign values, group of another host (R-ID1 to R-ID5). `series_of` (R-ID1). |
| `tests/unit/alias.roc` | 3 | Default alias of 9 names (R-AD8 to R-AD12, R-AD15). `check` (R-AD14, R-AD16, R-AD17). `choose`: new, platform, `--as`, 3 failure kinds with default and `--as` texts, a path entry, `Existing` (R-AD13, R-AD16 to R-AD20, R-AD30, R-I9). |
| `tests/unit/lookup.roc` | 3 | `Install` with no registry (R-SC2, R-SC6, R-SC7, R-AD1, R-AD2, R-AD6). `Project`: alias before short name, full name, short name with and without `roc-`, `host/path` never short, the tie of the design example (R-SC1, R-SC6 to R-SC8, R-SC14). `Tool` and `X` (R-SC3, R-SC4, R-AD7). |
| `tests/unit/add.roc` | 4 | New entries: `talon.toml` value for none, `latest`, exact, exact with `--no-pin`, range, series, `--as`, alias failure (R-AD23 to R-AD28, R-SL5, R-AD8, R-AD11). In the header: `Keep` and `Update` by alias and by group under another alias (R-AD20 to R-AD22, R-I9). Platform: replace, add, `--as`, 2 failures, notice (R-AD29 to R-AD33, R-AD25, R-AD26, R-SE7). `check_names` (R-AD28, R-FL12). |

Deep test (1 case):

| Layer | Case | Checks | State |
| --- | --- | --- | --- |
| L3 | `tests/scenarios/refs/sl-bad-refs` | 7 command lines, each exit 2 with its error line, no network, no change to the project: a typo `owner/app@mian` (R-SL12, R-SL13), `@1.2.0` outside `tln roc` (R-SL2), a nightly selector and a step outside `tln roc` (R-SL6, R-SL7), an empty selector, a bad name `a/b/c` (R-SL1), `--as` with 2 names (R-AD28). R-EC2, R-E4. | red |

### Planned deep cases for slice 007

These need the index (003) and the header edit (005), so they are not written now. Slice 007 writes them (L3, with the fake GitHub, or L2 for the call log). Each keeps the rule ids, so the coverage is not lost.

| # | Case | Rules |
| --- | --- | --- |
| P1 | `tln add owner/app`: a full name, a new header entry, the default alias, no `talon.toml` and no file created. A second run: `Keep`, exit 0, the note. | R-AD1, R-AD2, R-AD8 to R-AD12, R-AD20, R-AD21, R-AD24, R-SL14, R-H3 |
| P2 | `tln add owner/app@1.2.3`, `@^1.2`, `@1`, `@latest`, `--no-pin`: the header and the `talon.toml` file (created when it is missing, a key added when it exists). An exact version that no release has: exit 2. | R-SL3 to R-SL5, R-AD25 to R-AD28 |
| P3 | `tln add json` and `tln add json@^3` for a header alias: no change, then a move inside the selector with the `talon.toml` value. | R-AD20 to R-AD22, R-SC6 |
| P4 | `tln add --platform`: replace, new `pf`, a package as platform (exit 2), a platform with no flag (exit 2), the notice. | R-AD29 to R-AD33, R-SE7, R-C3, R-C4 |
| P5 | `tln add parser` and `tln add yaml` with `TALON_REGISTRY=direct`: exit 2, the full name is asked. `tln add owner/9lives`, `--as app`, `--as parser` (taken): exit 2 and no write. | R-AD6, R-AD14 to R-AD19 |
| P6 | `tln why basic-webserver` with two packages of that repo name in the closure: exit 2 and the list. `tln update zzz`: the error of question Q7. | R-SC1, R-SC8, R-SC14 |
| P7 | The git ref: `tln add owner/app@dd03c09e` (question Q3). `tln tool install --git owner/app@main` is P1. | R-SL8, R-SL10 |

## Output (proposed, R-OUT2: human text and `data` fields)

The strings are fixed in the tests and in `tests/scenarios/refs/sl-bad-refs/expect/stderr`. The human accepts or changes them at the review. Every failure has the kind `usage` (R-EC2), and the line is `tln: error[usage]: <message>` (R-E4).

| Case | Message |
| --- | --- |
| A typo or a branch with no `--git` (R-SL12, R-SL13) | `bad selector '<sel>' in '<text>': use --git for a branch or tag` |
| `@sel` with no name, scope is not `Roc` (R-SL2) | `'<text>' has no name: a reference with only @selector is for 'tln roc'` |
| A compiler selector, scope is not `Roc` (R-SL6, R-SL7) | `selector '<sel>' in '<text>' is for a compiler: use it with 'tln roc'` |
| An empty selector (`owner/app@`) | `'<text>' has an empty selector after '@'` |
| A bad name | `'<text>' is not a package name: use a short name, owner/repo or host/path` |
| Short name, no registry (R-AD6) | `'<x>' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).` |
| Short name, `tool` or `x`, no local match (R-AD7) | `'<x>' matches no installed tool or cached app. Use the full name (owner/repo).` |
| Tie of a short name (R-SC14) | The failure line `"<x>" matches <n> packages. Use the full name.` Before it, on stderr, the block: `"<x>" matches <n> packages:`, then for each match 2 spaces, the name, spaces that pad to the longest name plus 6, the note. Each line ends with a newline. The design example is the test row. |
| Alias, default (R-AD16, R-AD17, R-AD18) | `the default alias '<a>' for '<name>' is not a valid name. Use --as <alias>.` / `... is a reserved word. Use --as <alias>.` / `... is used by another package in the header. Use --as <alias>.` |
| Alias, `--as` | `'<a>' is not a valid alias. Use letters, digits and _, and start with a lowercase letter.` / `'<a>' is a reserved word, not a valid alias.` / `alias '<a>' is used by another package in the header.` |
| `--as` with 2 or more names (R-AD28) | `flag '--as' names one entry: got <n> names` |
| Entry in the header, no selector (R-AD21), exit 0 | Two lines on stdout: `<alias>: <name> <version> is in the header` and `Run tln update <alias> to move it.` |
| `--platform` with a package (R-AD32) | `'<name>' is not a platform` |
| A platform with no `--platform` (R-AD33) | `'<name>' is a platform. Use tln add --platform <name>.` |
| Platform replaced (R-SE7) | `platform changes: <old name> <old version> -> <new name> <new version>` |
| `--json` `data` | None in this slice: no command prints data yet. Slice 007 proposes the fields of `tln add` (the plan: `alias`, `header`, `url`, `toml`). |

## Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Options rejected |
| --- | --- | --- |
| D1 | Each decision is a pure function in its own module. `Add.decide` gets the candidate that the index and the solver chose (`chosen`). It does not select a release. Reason: selection is slice 003 and 007. | One function that reads the index |
| D2 | The plan is data (`Add`): the header action, the URL, the `talon.toml` pair, a note. The command applies it. | Return the new header text (slice 005 owns the edit) |
| D3 | A group includes the series (R-SC15). So "the header has the group" compares the URL form and the series. | Compare the name only. Question Q11 asks for the case. |
| D4 | The selector text is read by roc-semver, with no new grammar. A version with 3 parts is `Exact`, other forms are `Range`. | A Talon parser |
| D5 | A full nightly tag: `nightly-`, 4 digits, `-`, 2 digits or an English month name, `-`, 2 digits, `-`, 7 or more hex digits (Design 2, R-CV1). | Only the 2 forms with a 7-character sha |
| D6 | Name forms: `Bare` has no `/`. `Full` has one. `HostPath` has 2 or more and a `.` in the first part. `github.com/o/r` is `HostPath` (R-SC7: other hosts use `host/path`). | A list of known hosts |
| D7 | Ref checks run before the project file and before the index (R-SL13 says a typo never starts a source build). Both cases give exit 2, so the order shows only in the message. The L3 case has a project file, so it holds with any order. | Check after the index read |
| D8 | An alias for a path or foreign entry is "taken" (R-AD18): a header holds one entry for each alias, so the add must not write a second one. | Ignore path entries |
| D9 | `Lookup.find` is the same function for all scopes. The caller gives the entities: header entries and closure (`Project`), header entries (`Install`), tools and `x` entries (`Tool`, `X`). | One function for each scope |
| D10 | `Add.decide` calls `Alias.choose` first for a package. The group check comes before the alias check when `--as` is not set. With `--as` and a group that is in the header, the result is `Existing` and `--as` is not checked (R-AD19: no entry is added). | Check `--as` first |
| D11 | The tie block is part of the error value (`block`), because the last stderr line must be the failure line (R-E4). | Put the list in the message |

## Out of scope

| Id | Reason |
| --- | --- |
| R-AD3, R-AD4, R-AD5, R-AD34, R-AD35, R-AD36 | Need the registry (P2). `Lookup.find` adds a result and a parameter then. |
| R-AD37 | `--offline` sends no request: the index (R-DI12, slice 003). |
| R-SC10, R-SC11, R-SC13 | Prefix expansion of compiler ids: `tln roc` (P1, CLI 6.6). `Ref.parse` only keeps a prefix as a `Bare` name (R-SC9). |
| R-SC12 | The full id in the `roc:` pin, `ROC_TOOLCHAIN`, `.roc-version` and `talon.toml`: slice 005 (header, `talon.toml`) and P1. |
| R-SC15 | An explanation. The open case is question Q12. |
| R-SL14 | The meaning of "no selector" in each command (`strategy`, the newest series, a build that exists): the resolver and slice 007. The `talon.toml` part (nothing written) is tested through R-AD24. |
| R-SL4 (the newest match), R-SL5 (the newest release that is not yanked), R-SL9 rule 1 (matches a release), R-SL12 (close release versions) | Need the release list: slices 003 and 007. The syntax part is tested. Question Q1. |
| R-ID6 | The build id (resolved hashes, nightly, target): slice 006. |
| R-ID7 | Facts per content id, labels as pointers: the registry (P2) and the index. |
| R-SE1 | The hash check of a fetch: slice 003. |
| R-SE2, R-SE5, R-SE10, R-SE11, R-SE14, R-SE15, R-SE16 | Registry, log and sharing: P2 and P3. |
| R-SE3 | `min-release-age` (R-C7, slice 005) and the provenance display (P2). |
| R-SE4 | Probes: slice 006. |
| R-SE6 | The mirror: P3. |
| R-SE8, R-SE12, R-SE13 | Global tools, git refs, Talon download: P1. |
| R-SE9 | The unpack checks: slice 003 and `roc unbundle`. |
| R-SE7 | Covered for the notice of `tln add --platform` (`add.roc`). The notice of `tln update` is slice 007. |

## Questions (stop until answered)

Each question has the default that the stub contract and the tests use. The code agent does not decide these. A test that depends on a default is named. The others are not tested.

| # | Question | Default | Depends |
| --- | --- | --- | --- |
| Q1 | R-SL12 says the error lists the close release versions, and the brief says a typo is a usage failure before any network call (R-SL13). The list needs the index. Is the list added when a release list is at hand, and left out when the failure comes at parse time? | The failure comes at parse time with no list. Slice 007 adds the list where it has the releases. | `ref.roc` expect 4, `sl-bad-refs` line 1 |
| Q2 | A full nightly tag with no `@` in a package scope (R-SL2 says the short forms are valid only in `tln roc`): a short name, or a failure? | A short name (`Bare`). `tln add` then gives the R-AD6 failure. | Not tested |
| Q3 | A git ref (`GitSha`, `GitRef`) in the scopes `Install` and `Project`: R-SL8 does not limit the scope, but R-H3 says the header gets release URLs only. | A failure of kind `usage`: a git ref is for `tool`, `x` and `roc`. | Not tested. The slice 004 stub contract of `Ref.parse` leaves it open. P7 of the plan for 007. |
| Q4 | A selector of 7 or more decimal digits is a range (`^N`, rule 1) and a hex text (rule 2). Rule 2 says "and no release matches", which needs the index. | `Selector.parse` gives `Range`. The command falls back to a git ref when no release matches. | Not tested |
| Q5 | The reserved words of R-AD17: the design gives 7 examples. Which is the full list? Is `roc` in it (it is the compiler pin key)? | The 7 names of the design. | `alias.roc` expect 2 uses only these 7 |
| Q6 | The name of a release on a host other than `github.com`: R-ID3 gives `owner/repo` for GitHub only, and R-SC7 says `host/path`. Which path text? Is `github.com/o/r` the same as `o/r`? | `Ident.name` is `Err(NoName)` for a URL that is not a GitHub release URL. `github.com/o/r` is a `HostPath` name. | `ident.roc` tests no name for another host |
| Q7 | `tln update X`, `remove X`, `why X`, `patch X` where X matches nothing in the project (R-AD5 is for the registry). Exit code and message? | Kind `usage`, `'<x>' is not in the project`. | Not tested |
| Q8 | `--no-pin` with a range selector, or with no selector (R-FL12: "with an exact version")? | Ignored: the range is written. | Not tested |
| Q9 | `tln add json@latest` for a header alias. R-SL5 says the same as no selector in `tln add`. R-AD22 says a selector is `tln update`. | Not decided. Not tested. | Not tested |
| Q10 | The text that `talon.toml` gets for a range that is not `^` or a bare series (`2.x`, `>=1.2, <1.5`, `=1.2.3`). Also an exact version with a pre-release (`0.26.0-rc1`: another group, R-DI5). | The typed text. A pre-release is not `Exact` here: `Selector.parse` follows `Semver.parse` and the group rule stays with the index. | Not tested |
| Q11 | `tln add roc-lang/http@2` when the header has `http` at series 1 under the alias `http`. By D3 it is a different group, so R-AD18 stops and asks for `--as`. R-AD20 and R-AD22 can also be read as an update of that entry. | R-AD18 (stop, `--as`). | Not tested |
| Q12 | R-SC15 says the series is part of the name (`roc-lang/http@2`). R-CM4 says `tln update http@3` moves to a new series. With 2 entries of one repo, how does `tln update roc-lang/http@2` pick the entry? | Not decided. `Lookup.find` does not read the selector. | Not tested |
| Q13 | Exit code of R-AD6 and R-AD7 (short name, no registry). R-AD7 says exit 2 for `tool` and `x`. R-AD6 has no code. | `usage`, exit 2 for both. | `lookup.roc` expect 1 (kind only through the line) |
| Q14 | `--as` that is invalid, with a group that is in the header: which failure first? D10 chooses `Existing`. | D10. | Not tested |
| Q15 | `tln add --platform X --as a` when the header has a platform (R-AD31 says "under the same alias"). A replace with the same URL: `Replace` or `Keep`? | `--as` is ignored. The same URL gives `Replace` with no note. | Not tested |

## Review (manager, 2026-10-18)

The manager accepted the tests and the output proposals. The answers below are the manager's proposals. The user did not confirm them yet. The code agent follows them.

| # | Answer |
| --- | --- |
| Q1 to Q4, Q6 to Q8, Q10, Q13 to Q15 | The defaults of the slice. |
| Q5 | The reserved words are all keywords of Roc on the pinned nightly (get the list from the roc-syntax MCP), and `roc` (the key of the compiler pin in the header). |
| Q9 | R-SL5 wins: `tln add json@latest` for a header alias is the same as `tln add json` (R-AD21: no change, exit 0). |
| Q11 | A full name with no series names the header entry of that repository when the header has exactly one. So `tln add roc-lang/http@2` with `http` at series 1 is R-AD22: the same as `tln update http@2`, a move to series 2. To keep both series, the user gives `--as`. |
| Q12 | When a full name matches two or more header entries (two series), the series of the selector picks the entry (R-SC15): `roc-lang/http@2` is the series-2 entry, with no selector. No match of the series is a tie (R-SC14). A move of such an entry to another series uses its alias (`tln update http2@3`). |

## Added by the code agent (2026-10-18)

The brief of the manager asked for one L0 row for each of Q11 and Q12. The rows are in the tables of the matching `expect`. The tests were not changed in any other way.

| Question | File | Rows | Rules |
| --- | --- | --- | --- |
| Q11 | `tests/unit/add.roc`, `expect` 2 | `tln add roc-lang/http@2`, header has `http` at series 1: `Update` of `http`, `talon.toml` `^2`. The same with `--as http2`: `Insert` under `http2`. | R-AD22, R-AD18, R-AD19 |
| Q12 | `tests/unit/lookup.roc`, `expect` 2 | The closure has `roc-lang/http@1` and `roc-lang/http@2`. `roc-lang/http@2` and `roc-lang/http@^1.2` pick the entry by series. `roc-lang/http` and `roc-lang/http@3` are a tie (the block lists both). | R-SC14, R-SC15 |

Each new row was checked with a mutation (Verify results, rows Q11 and Q12): a test fails.

## Decisions of the code agent (the slice does not fix them)

| # | Decision | Options rejected |
| --- | --- | --- |
| C1 | Q12 and the signature of `Lookup.find`: the entity row has no series field. When a repo has 2 or more series in the closure, the caller gives the name as `owner/repo@series` (`roc-lang/http@2`, R-SC15). `find` compares names without `@series`, and the selector (`Exact` or `Range`) gives the series that picks the entry. Slice 007 builds the rows this way. | A new `series` field in the row (changes the test records) |
| C2 | Q11 is in `Add.decide`, before the alias check: with no `--as`, a header entry with the same repo name (`Ident.name`), when there is exactly one, is the entry (`decide_alias`). With 2 or more entries and no group match, `Alias.choose` runs (R-AD18). | Put it in `Alias.choose` (it has no selector and must keep its contract) |
| C3 | Q5: the reserved words are the 33 words of the "naming" topic of roc-syntax (header words and code words), and `roc`. The tokenizer of the roc source also has `imports`: it is not in the list. | Add `imports` (not in the MCP list) |
| C4 | Q3: a `GitSha` or `GitRef` in `Install` or `Project` is a usage failure: `git ref '<sel>' in '<text>' is not for this command: use it with 'tln tool install', 'tln x' or 'tln roc'`. The text is a proposal (R-OUT2). | Allow it |
| C5 | `Add.decide_alias` for an alias that is not in the header: usage failure `'<alias>' is not in the header`. Not in the tests. | Crash |
| C6 | The nightly tag month: the 12 English names with a capital letter (`July`), as the roc source reads them. The sha part is 7 or more hex digits (D5). | Any case |
| C7 | `Ident.name` for a GitHub URL: the URL form must be `github.com/<owner>/<repo>/releases/download/<tag with the version>/`. Any tag text is allowed (`v{v}`). | Only a tag that is the bare version |
| C8 | W1 uses the words `install`, `update`, `upgrade`, `remove`, `why`, `patch` in `Run.check_refs`. `--git` is read from `options`. The commands accept no `--git` today (R-FL14), so it is false there. | |

## Disputes (from the code agent)

None.

## Verify results

Result of `scripts/test.sh` (2026-10-18): check, fmt, L0, L2, L3 and selftest all pass.

| Layer | Result |
| --- | --- |
| L0 | 12 files, all pass. Slice 004: selector 2, ref 4, ident 2, alias 3, lookup 3, add 4 (18 `expect`s) |
| L2 | 3 passed |
| L3 | 9 passed (with `refs/sl-bad-refs` and `help/q7-no-command`) |
| selftest | 23 passed |

Code change for Code Q13 of slice 001: `Run.run!` prints `tln: error[usage]: no command` after the usage on stderr. The expected stderr of `tests/scenarios/help/q7-no-command` has the new last line (one added line). Mutation 91 below checks it.

Revert check (TW12). Method: a script changed one small place of one file in `cli/lib`, ran `scripts/test.sh l0` and, if L0 passed, `l3`, and put the file back. A mutation that did not compile was replaced by one that compiles. 92 mutations. Caught: 86. Not caught: 6. After the run, `cli/` was compared with a copy made before the run (`diff -r`): the same. `tests/` also the same as before the revert check.

| Rule ids | Mutation | Caught by |
| --- | --- | --- |
| R-SL3 | `Exact` gives `Range` | `selector.roc` 1, `ref.roc` 1 |
| R-SL4, R-SL15 | no `^` for a bare version. The `^` for 1 part only | `selector.roc` 1, `ref.roc` 1 |
| R-SL5 | `latest` not read | `selector.roc` 1, `ref.roc` 1 |
| R-SL6 | a nightly tag: year of 5 digits, no month name, sha as digits | `selector.roc` 1 (`ref.roc` 2 for 2 of them) |
| R-SL7 | a step with no sign change, a `+` not read | `selector.roc` 1, `ref.roc` 2 |
| R-SL10 | sha limit of 6 | `selector.roc` 1 |
| R-SL8, R-SL11, R-SL13 | `--git` not read | `selector.roc` 2, `ref.roc` 2 |
| R-SL9, R-SL12 | empty text not an error. Unknown text gives a git ref | `selector.roc` 1, `ref.roc` 4 |
| R-SL1 | `HostPath` with no dot, `Full` as `Bare`, empty part allowed, `Bare` refused | `ref.roc` 1, 4, `lookup.roc` 2 |
| R-SL2, R-SC9 | scope `Roc` not special, `@sel` with no name allowed, nightly tag with no `@` not read | `ref.roc` 2, 4 |
| R-SL6, R-SL7 | compiler selector allowed outside `Roc` | `ref.roc` 4 |
| Q3 | git ref allowed in `Install` and `Project` | `ref.roc` 4 |
| R-SL13, R-SL1, R-EC2 | texts of the bad selector and the empty selector | `ref.roc` 4 |
| R-SC1 to R-SC5 | the scope of `probe`, `install`, `tool`, `x`, `roc` | `ref.roc` 5 |
| R-ID1 to R-ID5 | series of 1.0, group without series, no GitHub name, label, hash, series text | `ident.roc` 1, 2 (`add.roc` for 2 of them) |
| R-AD8 to R-AD12, R-AD15 | repo name not cut, `roc-` prefix, suffix drop, `.` and `-` not changed | `alias.roc` 1 (`add.roc` 1 for 2 of them) |
| R-AD14, R-AD16 | first letter, `_`, texts | `alias.roc` 2, 3 |
| R-AD17 | reserved words not checked | `alias.roc` 2 |
| R-AD18 | no check of a taken alias | `alias.roc` 3 |
| R-AD13, R-AD30 | platform alias not `pf` | `alias.roc` 3 |
| R-AD19, R-AD20, R-I9 | group of the header not compared | `alias.roc` 3, `add.roc` 2 |
| R-SC6 | alias not compared | `lookup.roc` 1 |
| R-SC7, R-AD1, R-AD2 | full name not matched, `New` gives a failure | `lookup.roc` 1, 2, 3 |
| R-SC8, R-SN3 | no `roc-` drop, no repo match, `host/path` matched | `lookup.roc` 2 |
| R-SC14 | tie gives a match, pad width, 2 spaces, first match wins | `lookup.roc` 2 |
| R-AD6, R-AD7 | the texts | `lookup.roc` 1, 3 |
| Q12 (new row) | series pick not done, `^` not read | `lookup.roc` 2 |
| R-AD23 to R-AD28, R-SL5 | `=` missing, `--no-pin` not read, `^` added, `latest` gives a value, no selector gives a value | `add.roc` 1, 2 |
| R-AD21, R-AD22 | no-selector not `Keep`, `Update` as `Keep`, note text | `add.roc` 2 |
| R-AD29 to R-AD33 | no platform check, no `--platform` check, `Insert` for `Replace`, `--as` ignored | `add.roc` 3 |
| R-SE7 | note always, text | `add.roc` 3 |
| R-AD28, R-FL12 | limit of 3, wrong tag | `add.roc` 4 |
| Q11 (new row) | one entry of the repo not used, `--as` not read | `add.roc` 2 |
| R-AD20, R-AD21, R-AD8, R-AD23 | existing group gives `Insert`, alias `x` | `add.roc` 2, 1 |
| W1, R-SL13 | the ref check dropped, `update` dropped from the commands | `refs/sl-bad-refs` |
| W3, R-AD28 | `check_names` dropped | `refs/sl-bad-refs` |
| R-E4, Code Q13 | no `tln: error[usage]: no command` line | `help/q7-no-command` |

Not caught (6):

| Mutation | Why |
| --- | --- |
| Q5: the word `roc` removed from the reserved list | No test names `roc` (the tests use the 7 words of the design). Add `roc` to `alias.roc` expect 2 (test agent). |
| Q7: the text `'<x>' is not in the project` changed | Q7 has no test. Slice 007 (P6) tests it. |
| Q9: `add json@latest` for a header alias gives `Update` | Q9 has no test. Slice 007 (P3) tests it. |
| R-AD31: the header platform found by the alias `pf`, not by `is_platform` | The tests have the platform under the alias `pf`. A row with another alias is needed (test agent). |
| W2: `probe` added to the commands of W1 | No test gives `probe` a path operand. Slice 007 tests it. |
| `Alias.choose` runs the `--as` text through `default` | An equivalent change for the tested aliases (`default("yml")` is `yml`). |

## Review of the code (manager, 2026-10-18)

`scripts/test.sh` passes (17 s). The not-caught mutations are accepted: Q7 text and Q9 go to slice 007 (P6, P3). The R-AD31 row with another platform alias and the `probe` path operand (W2) go to slice 007 too.

Status: done (2026-10-18).
