# 244 `tln audit`

Phase: P2 (Q-244-1). Status: 244a code (green except the Q-244-4 tests). Design Q620 (G-C250): the user approved the 10 answers, all TW24 texts and fields, and the split on 2026-11-12. The slice is 244a (registry mode, these tests), 244b (`direct`), 244c (resolve warnings). The code agent wrote `cli/lib/AuditTypes.roc` (the types, `Report` is here), `AuditCheck.roc` (the decisions; it re-exports the names of `AuditReport`), `AuditReport.roc` (`reason_text`, `fix`, `text`, `data`, `failure`) and `AuditFlow.roc` (the command), with a branch in `Run.dispatch!`.

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CM14 | `tln audit [--ignore <item>]... [--json]`. No operand. |
| R-AU1 | The hashes to check: each `Release` row of the closure of each member (the header entries and the deps of each package header, to the end), and the hash of the `url` of each project tool (only that hash, R-PT8). With a registry the state comes from the closure answer (R-AP17). The state of now: no snapshot (R-YK5). |
| R-AU2 | The 6 reasons and their sources. Registry: `yanked`, `withdrawn` (`deleted`, `unpublished`, `prereleased`, `edited`, `asset-replaced`, `repo-missing`), the `repos` item (`missing`, `moved` with `successor`). |
| R-AU3 | Exit 21 when a finding that is not ignored fails (`yanked`, `asset-replaced`, `repo-missing`). Else 0, and the others are warnings. |
| R-AU4 | `direct`, or a registry before P3: the note of R-C6 (not a finding). |
| R-AU5 | `--json` with exit 21: `ok` false, `error.kind` `findings`, the report in `error.details`. |
| R-AU8 | The fix text. |
| R-AU9 to R-AU12 | Ignore items: `[audit] ignore` (root talon.toml) and `--ignore`, joined. Item `<full name>@<version>:<reason>`. Ignored: a note. Unused: a note. Bad item: exit 19 (talon.toml), exit 2 (flag). |
| R-AU13 | One finding for each hash, the first reason in the order `yanked`, `asset-replaced`, `repo-missing`, `release-missing`, `prerelease`, `moved`. The successor is in the finding. |
| R-AU15 | Workspace: the closure of each member, one finding for each hash, the root `[audit]` only, R-AU11 across the members. |
| R-PT8 | The `url` of each project tool is a hash of `tln audit`. |
| R-OUT1 to R-OUT5 | The human text and the `data` fields are a proposal (TW24, below). |

Not in 244a: R-AU6 (has a test already: `tln install --frozen` makes no index call, registry/rg7-*), R-AU7 and R-AU14 (part 244c), the `direct` column of R-AU2 (part 244b).

Source: DESIGN-CLI.md "### `tln audit`" and the catalog row `audit` (CLI 3); DESIGN-RESOLUTION.md R-C6, R-C9; DESIGN-REGISTRY.md R-AP17, R-AP19, R-AP32, R-AP49, R-PU17, R-PU20, R-PU24, R-PU28, R-YK4, R-YK5, R-TP14; DESIGN.md R-WS5, R-PH5.

## Scope (facts found in the code before any change)

| Fact | Where | Consequence |
| --- | --- | --- |
| `audit` is a known command and `--ignore` is a flag of `audit` only (`Args.allows`). `Run.dispatch!` has no branch: `tln audit` is exit 1 `command 'audit' is not built yet`. | Args.roc, Run.roc | The red state of every L2 case. |
| The closure answer is read (`records.Closure.Answer`), with `releases` (`yanked`, `yank_reason`, `withdrawn`) and `repos` (`state`, `successor`, `state_at`). No CLI code reads `repos`. `ClosureIndex.candidates` drops a row with `withdrawn`. | ClosureIndex.roc, packages/records | `AuditCheck` reads both. No records change. |
| `tln why` sends the closure query with no `groups`, the header hashes and the held window, then walks the closure from the records of the answer (`Why.walk_indexed!`, `Ls.load_full!`, `Ls.walk_loaded!`). | Why.roc, Ls.roc, Walk.roc | The model of the flow of `tln audit` with a registry (Q-244-10). |
| `Intent.read` knows the table `[audit]` and does not read it ("P3: a known table, the content is not read"). It refuses `[audit]` in a member file (R-WS5, exit 19) for every command. | Intent.roc | `AuditCheck.toml_items` reads the key `ignore` (Q-244-6). The member guard exists. |
| No R-AU7 warning and no R-PU28 note exist in the resolve commands. `Fetch.download_failed` names `tln audit` in each 404 message. | Fetch.roc | 244c. |
| `Github.releases!` turns a 404 of the release list into a failure (`status_failure`). | Github.roc | 244b needs a form that keeps the 404 (R-AU2 `repo-missing`). |
| The closure answer has no time of a yank or a withdraw, no `by` of a yank, and no new asset hash. | R-AP49 | `since` is the `state_at` of `repos` only; `yank.by` is left out; `new_hash` is null with a registry (TW24 rows). |

## Behaviors (part 244a)

| # | Behavior | Exit | Rules |
| --- | --- | --- | --- |
| B1 | The hashes: each release row of the walk of each member, and each tool URL; a path entry and a foreign entry are not checked. | n/a | R-AU1, R-PT8 |
| B2 | One closure query (as `tln why`), the walk from the records. The state of a hash: the release row with its hash, URL form and version; the `repos` item of its `repo`. | n/a | R-AU1, R-AP17, R-AP32 |
| B3 | The reason of a row (registry column), one reason for each hash in the order of R-AU13. | n/a | R-AU2, R-AU13 |
| B4 | Exit 21 when a finding that fails is not ignored; else 0. | 0, 21 | R-AU3, R-EC21 |
| B5 | `[audit] ignore` and `--ignore` joined; an ignored finding is a note; an item with no finding is a note; the reason must match. | 0, 21 | R-AU9 to R-AU11 |
| B6 | A bad item: exit 2 for the flag (before any read), exit 19 for talon.toml (after the load, before the query). An operand: exit 2. | 2, 19 | R-AU12, R-CM14 |
| B7 | `--json`: `data` (exit 0), or `error.details` with the same object (exit 21). | 0, 21 | R-AU5, R-J4, R-J5 |
| B8 | The note of no yank data (Q-244-1, Q-244-2). | 0, 21 | R-AU4, R-C6 |
| B9 | The state of now: `[resolution] snapshot` hides no release. | n/a | R-AU1, R-YK5 |
| B10 | Workspace: one entry for each hash, `members` lists the member files (Q-244-5). L0 only. | n/a | R-AU15 |

## Proposed names (TW24, for the code agent)

A new module `cli/lib/AuditCheck.roc` (pure, part A) and a command module (name free, for example `AuditFlow.roc`, part C) with a branch in `Run.dispatch!`. The name `Audit` is not used: `packages/records` has a module `Audit` (the bot imports it).

| Name | Type | Rule |
| --- | --- | --- |
| `AuditCheck.Reason` | `[Yanked, AssetReplaced, RepoMissing, ReleaseMissing, Prerelease, Moved, Other(Str)]` | R-AU2, Q-244-3 |
| `AuditCheck.Entry` | `{ url, name, group, version, hash : Str, alias : Try(Str, [None]), edge : Str, via : List(Str), tool : Try(Str, [None]), members : List(Str), why : Str }` | R-AU1, R-AU15, R-SC15 |
| `AuditCheck.Finding` | `{ entry : Entry, reason : Reason, ignored : Try(Str, [None]), since : Try(U64, [None]), yank_reason : Try(Str, [None]), new_hash : Try(Str, [None]), successor : Try(Str, [None]) }` (`since` in ms, `ignored` is the item as written) | R-AU2, R-AU10, R-AU13 |
| `AuditCheck.Report` (in the code: `AuditTypes.Report`) | `{ index : [Registry, Direct], checked : U64, findings : List(Finding), unused : List(Str), no_yank_data : Bool, unindexed : List({ name : Str, version : Str, hash : Str }) }` (`unindexed` added by the review, Q-244-4) | R-OUT2, Q620 |
| `AuditCheck.entries` | `{ members : List({ file : Str, walked : Closure.Walked }), tools : List({ key : Str, url : Str }) } -> List(Entry)` | R-AU1, R-AU15, R-PT8 |
| `AuditCheck.state_of` | `{ answer : records.Closure.Answer, entry : Entry } -> Try({ row : records.Release.Row, repo : Try(records.Closure.Repo, [None]) }, [NotIndexed])` | R-AU1, R-AP17 |
| `AuditCheck.reason_of` | `{ row, repo } -> Try(Reason, [None])` | R-AU2, R-AU13 |
| `AuditCheck.finding` | `{ entry, row, repo } -> Try(Finding, [None])` | R-AU2, R-AU13 |
| `AuditCheck.of_answer` | `{ answer, entries } -> { checked : U64, findings : List(Finding), unindexed : List(Entry) }` | R-AU1, Q-244-4 |
| `AuditCheck.reason_text`, `AuditCheck.fails` | `Reason -> Str`, `Reason -> Bool` | R-AU2, R-AU3 |
| `AuditCheck.parse_item` | `Str -> Try({ name : Str, version : Str, reason : Str }, [BadItem])` | R-AU9, R-AU12 |
| `AuditCheck.read` | `Args -> Try({ items : List(Str) }, Fail)` | R-CM14, R-AU12 |
| `AuditCheck.toml_items` | `{ path : Str, text : Str } -> Try(List(Str), Fail)` | R-AU9, R-AU12 |
| `AuditCheck.ignore` | `{ findings, items } -> { findings, unused : List(Str) }` | R-AU9 to R-AU11 |
| `AuditCheck.code` | `List(Finding) -> I32` | R-AU3 |
| `AuditCheck.fix` | `Finding -> Str` | R-AU8 |
| `AuditCheck.text`, `AuditCheck.data`, `AuditCheck.failure` | `Report -> Str`, `Report -> JsonDoc`, `Report -> Fail` | R-OUT2, R-AU5 |

The flow (part C, a guess for the review): `AuditCheck.read`; the steps of `Why.walk_indexed!` (begin, record, load, guard and the closure query with the tool hashes added to `hashes`, the walk); `AuditCheck.toml_items` of the root talon.toml after the load and before the guard; `entries`, `of_answer`, `ignore`; print `text` (stdout) and exit 0, or `failure` with `Common.failed!` (exit 21); with `--json` the envelope only. No write except `projects.json`. No share hook, no `compat.db` read, no probe.

## Tests

### L0 (new file tests/unit/AuditcheckTest.roc, imported by tests/unit/l0-9.roc)

| # | Test | Rules | State now |
| --- | --- | --- | --- |
| 1 | `entries`: the rows of a walk (header, transitive with 2 header aliases in `via`, a path and a foreign row left out) and a tool URL | R-AU1 R-PT8 R-SC15 | green |
| 2 | `entries`: `url`, `name`, `group`, `version` | R-AU1 | green |
| 3 | `entries` in a workspace: one entry for each hash, `members`, `via` union, a tool URL that is also a closure hash | R-AU15 (Q-244-5) | green |
| 4 | `entries`: `why` adds `@<series>` for 2 series of one name | R-SC15 R-AU8 | green |
| 5 | `reason_of`: 18 rows: each source, an unyank, the order of R-AU13 | R-AU2 R-AU13 R-AP49 | green |
| 6 | `reason_of`: an unknown `withdrawn` value | R-AU2 (Q-244-3) | green |
| 7 | `reason_text`, `fails` | R-AU2 R-AU3 | green |
| 8 | `state_of`: hash, URL form and version (decoys before the true row: the same hash in another tag form, the same hash and group at another version (G1); and a row of another release with a hash of the closure). The release key is the label (group, version) with its hash (Registry R-SG1, R-RE2 `UNIQUE`); the `repos` item, any case; not indexed | R-AU1 R-AP17 R-AP32 | green |
| 9 | `finding`: `since`, `yank_reason`, `successor` (also for a yank), no finding | R-AU2 R-AU13 | green |
| 10 | `of_answer`: the findings in the order of the entries, `checked`, `unindexed` | R-AU1 (Q-244-4) | green |
| 11 | `parse_item`: 18 texts | R-AU9 R-AU12 R-SC7 (Q-244-3) | green |
| 12 | `read`: the flags, the operand | R-CM14 R-AU12 | green |
| 13 | `toml_items`: 9 texts | R-AU9 R-AU12 R-TF4 (Q-244-6) | green |
| 14 | `ignore`: the match (case, version, reason), `unused`, a repeated item | R-AU9 R-AU10 R-AU11 | green |
| 15 | `code`: 8 rows | R-AU3 R-AU10 R-EC21 | green |
| 16 | `fix`: 10 rows | R-AU8 R-SC15 R-PU28 (Q-244-7) | green |
| 17 | `text`: the full report (the design example with these fixtures) | R-AU3 R-AU10 R-AU11 R-OUT2 | green |
| 18 | `text`: the new hash of `direct`, a yank with no reason, 2 `via`, a tool, singular counts | R-AU2 R-DI15 R-OUT2 | green |
| 19 | `text`: the R-AU4 note (direct, registry), no finding | R-AU4 R-C6 (Q-244-1, Q-244-2) | green |
| 20 | `data`: the `--json` object | R-OUT2 R-OUT4 R-AU10 R-AU11 R-AU13 | green |
| 21 | `failure`: kind `findings`, the message, `details` | R-AU5 R-J4 R-J5 R-EC21 | green |
| 22 | Q-244-4: `Report.unindexed` (NEW field `List({ name, version, hash })`): the note lines in `text` (after the `fix:` line, before the R-AU4 note) and the `not-indexed` notes in `data` (after `unused-ignore`) | Q620 R-AU1 R-OUT2 R-OUT4 | red (the field does not exist: the module does not compile) |
| 23 | `ignore`: an item of `f_json` with another reason (`asset-replaced`) ignores nothing and is unused (mutation gap G2, mutant a3b) | R-AU9 R-AU11 | green |
| 24 | `ignore`: a repeated item with no finding is in `unused` once (mutation gap G3, mutant a6b) | R-AU11 | green |

### L2 (tests/commands/cases/audit/, entry `commands`, the registry `http://127.0.0.1:9` of config.toml, `TALON_NOW`, no token)

The cases are made by `tests/tools/mk-audit.py` (run from the repo root). The expected texts are literal in that file. tree.diff comes from `tree_diff`.

| Case | Runs | Rules | State now |
| --- | --- | --- | --- |
| au1-findings | p1: pf, json (yanked), csv (repo-missing), xml (moved), old (yanked, no reason); json needs parser (asset-replaced) and util (deleted). Run 1: the report, exit 21. Run 2: `--json`, exit 21, `error.details`. | R-CM14 R-AU1 R-AU2 R-AU3 R-AU4 R-AU5 R-AU8 R-AU13 R-AP17 R-AP32 R-AP49 R-EC21 R-J4 R-J5 R-OUT2 | green |
| au3-clean | p2: no finding. Human and `--json`, exit 0, the note | R-CM14 R-AU3 R-AU4 R-C6 R-OUT2 | green |
| au3-warnings | p3: moved, unpublished, edited: 3 warnings, exit 0; `--json` | R-CM14 R-AU2 R-AU3 R-AU8 R-OUT2 | green |
| au9-ignore | p4 = p1 with `[audit] ignore` (3 used, 1 unused) and `[resolution] snapshot = "log:1"`. Run 1: `--ignore` of parser too, exit 0. Run 2: `--json`. Run 3: toml items only, exit 21. Run 4: an item of parser with another reason (upper case name): exit 21, 2 unused. | R-AU9 R-AU10 R-AU11 R-AU12 R-AU3 R-AU1 R-YK5 R-OUT2 | green |
| au12-bad-items | Run 1: a talon.toml item with no reason: exit 19. Run 2: the flag: exit 2. Run 3: an operand: exit 2. | R-AU12 R-AU9 R-EC2 R-EC19 R-CM14 | green |
| au1-tool | p6 with `[tools] fmt` whose release is yanked: exit 21, the tool hash in the query | R-AU1 R-PT8 R-AU3 R-AU8 R-OUT2 | green |
| au4-not-indexed | p7: web is in `unknown` of the answer. Run 1: the `not checked` note in the report on stdout, exit 0. Run 2: `--json`, the `not-indexed` note in `data.notes`. Run 3: `--offline`, exit 2. | Q620 (Q-244-4, Q-244-8) R-AU1 R-OUT2 R-OUT4 R-CM14 R-EC2 | red (runs 1, 2: the code prints the note on stderr and not in `data`); run 3 green |

### Run results (TMPDIR in `.tmp/tmp`, capped scope `MemoryMax=16G`, nothing died at the cap)

After the review (2026-11-12):

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` (the repo) | Does not compile: type mismatch at each `AuditCheck.text`/`data`/`failure` call, because the test `Report` records have the new field `unindexed` and `AuditTypes.Report` has not. This is the red of L0 22 (Q-244-4). |
| The same against a copy of `cli/lib` where only `unindexed` is added to `AuditTypes.Report` (`.tmp/stub244b/`, not in the repo) | `AuditcheckTest`: 21 passed, 1 failed (L0 22, the note lines and the `not-indexed` notes). So only the new Q-244-4 test is red. |
| `tests/commands/run.sh audit/` | 7 cases: 6 pass, au4-not-indexed fails on stdout and stderr only (the note is on stderr and not in `data.notes`). Its calls.log is the real one. |

First round (before the code):

| Command | Result |
| --- | --- |
| `roc check tests/unit/l0-9.roc` (the repo) | The compiler stops with SIGSEGV (exit 139): `l0-9` imports a module of `lib` that does not exist (`AuditCheck`). No error text. All 18 modules of `l0-9` are red until `AuditCheck.roc` exists. |
| The same against a copy with a stub `AuditCheck.roc` (`crash "todo"` bodies, the signatures above, the module in the package list; in `.tmp/stub244/`, not in the repo) | `roc check`: no errors. `roc test`: each of the 21 expects of `AuditcheckTest` fails with `todo`. So the tests type-check against the proposed signatures. |
| `tests/commands/run.sh audit/` | 6 cases, 6 fail: each run is exit 1, `command 'audit' is not built yet`. The guessed start of the early failures (`args`, `env_all`, `tty`) is the real start. |
| `MISSING=1 scripts/rules.sh R-AU R-CM14` | Missing: R-AU7, R-AU14 (part 244c). |

Recommendation for the code agent: first add `cli/lib/AuditCheck.roc` with the names above and `crash "todo"` bodies, and the module in `cli/lib/main.roc`. Then `l0-9` compiles and the old modules of `l0-9` are green again.

## Output (proposed, TW24, R-OUT2: for the human review)

| Where | Text or field |
| --- | --- |
| Line 1 (stdout) | `audit: <checked> packages checked (registry)` or `(direct)` |
| Rows of the findings that fail | An aligned table. Each column is as wide as its longest cell and 2 spaces; the last column is not padded (the design example has the same columns with hand-made widths). Cells: the reason words (`yanked`, `asset replaced`, `repo missing`, or the text of an unknown value), `<edge alias> <version>`, the full name, the detail, the place. |
| Detail cell | `yanked`: `"<reason>"`, or `no reason given`. `asset-replaced`: `GitHub has <first 6 of new>..., the header has <first 6 of old>...` when the new hash is known (`direct`), else `the asset of the header is gone`. `repo-missing`: `the repository is deleted or private`. An unknown value: `withdrawn: <text>` (Q-244-3, not tested). |
| Place cell | `header: <alias>`, `via <alias>, <alias>`, or `tool: <key>` |
| Warning rows | `warning: <reason words>  <edge> <version>  <full name>  [successor: <name>  ]<place>` (2 spaces between cells, as the design example) |
| Ignored, unused | `ignored: <item as written>` for each ignored finding (order of the findings), then `unused ignore: <item>` (order of the items, talon.toml first). A repeated item (the same text in talon.toml and the flag, or twice in one source) is one item: it prints one `unused ignore` note and one `unused-ignore` JSON note (TW24 proposal, after the mutation check; the code does this already). |
| Count line | `<n> findings, <m> warnings, <k> ignored.` (`1 finding`, `1 warning`) |
| Fix line | `fix: <edge>: <fix>. <edge>: <fix>.`: one item for each finding that is not ignored and that fails or has a successor (the design example has no item for a `release-missing` warning). Not printed when there is no item. |
| `fix` texts | Header entry: `tln update <alias>`; with a successor (any reason) the same. `asset-replaced` header: `ask the author to release a new version, then run tln update <alias>`. `repo-missing` header with no successor: `tln remove <alias>, then tln add another package, or add the item to [audit] ignore`. Transitive: `tln update <via> or tln update <via> (tln why <R-SC15 name>), or use [overrides]`, and for `asset-replaced` `; ask the author to release a new version`. Tool: `tln update --tool <key>` (Q-244-7). The design example writes `tln why parser`; R-AU8 and R-SC15 say the full name, so the proposal uses the full name. |
| Not indexed (Q-244-4, accepted) | `note: not checked: <name> <version>: the registry has no release of it`, one line for each, on stdout after the `fix:` line and before the R-AU4 note. `--json`: `{"kind":"not-indexed","name":...,"version":...,"hash":...}` in `notes`, after the `unused-ignore` notes. |
| Offline (Q-244-8, accepted) | `tln: error[usage]: tln audit reads the index of now, so it does not take --offline` |
| The R-AU4 note (last line) | `direct`: `note: no yank and advisory data without a registry` (R-C6). Registry before P3: `note: the registry has no yank and advisory data yet` (Q-244-2). |
| Exit 21 (stderr) | `tln: error[findings]: findings that fail: <item>, <item>. To accept one, add it to [audit] ignore in talon.toml` (the items in the order of the findings, in the form of an ignore item, so a user can copy one) |
| Bad flag item (exit 2) | `tln: error[usage]: --ignore: '<item>' is not <full name>@<version>:<reason>, for example roc-lang/json@2.1.0:yanked` |
| Bad talon.toml item (exit 19) | `tln: error[input]: <path>:<line of the key>: audit.ignore: '<item>' is not <full name>@<version>:<reason>, for example roc-lang/json@2.1.0:yanked`; not a list of strings: `<path>:<line>: audit.ignore: must be a list of strings` |
| Operand (exit 2) | `tln: error[usage]: tln audit takes no operand` |
| `--json` | stdout is the envelope only. Exit 0: nothing on stderr. Exit 21: stderr has the failure line (`Out.fail`). |
| `data` | `index`, `checked`, `notes[]` (objects: `{"kind":"no-yank-data"}`, `{"kind":"unused-ignore","item":...}`), `findings[]` in the order of the walk: `name`, `group`, `version`, `hash`, `alias`, `via`, `tool` (NEW: the key of `[tools]`, or null), `members` (NEW: the member files that have the hash, `[]` for a tool; Q-244-5), `reason`, `fails`, `ignored`, `since` (a UTC time text: the `state_at` of the `repos` item for `repo-missing` and `moved`, else null), `yank` (`{"reason": text or null}` for `yanked`, else null; the catalog's `by` is left out because the closure answer has no `by`), `new_hash` (null with a registry), `successor`, `fix`. |

## Questions (TW17): all answered, Design Q620 (G-C250), approved by the user on 2026-11-12 as recommended

| # | Question | Answer (approved, Q620) | Tests that follow it |
| --- | --- | --- | --- |
| Q-244-1 | R-PH5, R-CM14 and the plan (PLAN-P2-CLI 1.2) say `tln audit` is P3. This slice builds it in P2. Also R-AU4 says "a registry before P3", but no member of the wire tells the phase: R-AP49 only says `yanked` is "always `false` before P3". How does `tln` know? | Build `tln audit` in P2: the P2 registry already sends `withdrawn` and `repos`, so 5 of the 6 reasons work now (R-AU14 already starts `repo-missing` and `moved` in P2). The phase is a constant of the `tln` release (a P2 `tln` has no yank data from any registry, so it prints the note with each registry); the P3 release changes the constant. No wire change. R-PH5 and the P3 row of the plan change to "P2, yank data P3". | L0 19; all L2 cases (last line) |
| Q-244-2 | R-AU4 says to print "the note of Resolution 2, R-C6", whose text is `no yank and advisory data without a registry`. With a registry that text is wrong. | The same note id (`no-yank-data`), with its own text for a registry: `note: the registry has no yank and advisory data yet`. | L0 19; L2 au1, au3, au9, au1-tool |
| Q-244-3 | A `withdrawn` value that this `tln` does not know (R-AP49: "kept as text, not a candidate (R-AU2)"): is it a finding, does it fail, where is it in the order of R-AU13? And may an ignore item name a reason that `tln` does not know? | A finding with `reason` = the text. It fails (Talon cannot judge it, and a release that is not a candidate is a defect for a new build), and it comes after `repo-missing` and before `release-missing`. The reason of an item is any text of `a-z`, `0-9` and `-` that starts with a letter, so an item for a new value works with an older `tln`; an item of an unknown reason with no finding is only `unused ignore` (a typo of a known reason still shows: the finding stays). | L0 6, 7, 11, 15 |
| Q-244-4 | A closure hash with no release in the closure answer (in `unknown`, or a host with no index, R-DI11, R-PU40): what does `audit` do? Send the ingest of R-AP28? | No finding, not counted in `checked`, no ingest (audit writes nothing to the registry). One note for each: `note: not checked: <name> <version>: the registry has no release of it` (JSON `{"kind":"not-indexed","name","version","hash"}`, a proposal). Exit code unchanged. | L0 10, L0 22; L2 au4-not-indexed runs 1, 2 |
| Q-244-5 | R-AU15 says "with the members in `via`", but the catalog says `via` is "the header aliases that need it, `[]` for a header entry". Which? And `alias` when one member has the hash as a header entry and another as a transitive one? | Keep `via` as the header aliases (the union over the members). Add `members` (the member files that have the hash). `alias` is the first header alias of a member in member order; `via` keeps the aliases of the members where it is transitive. | L0 3; the `members` field in all `--json` runs |
| Q-244-6 | R-TF4 makes a known key with a bad value exit 19 for every command. Does a bad `[audit] ignore` item stop `tln install` too, or only `tln audit` (R-AU12)? | Only `tln audit`. `Intent.read` keeps `[audit]` as "known, not read", so a typo in an audit item does not stop the build of a team. | L0 13; L2 au12 run 1 |
| Q-244-7 | A project tool (R-PT8): which `alias`, `via` and fix? R-AU8 has no case for a tool. | `alias` null, `via` `[]`, the new field `tool` (the key), the place cell `tool: <key>`, the fix `tln update --tool <key>`. The tool hash goes in `hashes` of the one closure query, after the header hashes (no other request). | L0 1, 16, 18; L2 au1-tool |
| Q-244-8 | `tln audit --offline`: R-AU1 says "the state of now". Use the kept copies (R-IX6), or stop? | Exit 2 (usage): `tln audit reads the index of now, so it does not take --offline`. | L2 au4-not-indexed run 3 |
| Q-244-9 | The privacy guard (R-RG4) refuses a repository that GitHub answers 404 for (deleted or private) when no public answer is kept, and the command stops before the query. So an audit cannot report `repo-missing` for such a repository. | For `tln audit` only: a refused repository is a `repo-missing` finding for each hash of it (the source is the 404 of the guard), and its hashes are left out of the query (R-RG4 holds). The other hashes are checked. | Moved to 244b (review ruling): not tested in 244a. All 244a fixtures keep a public answer. |
| Q-244-10 | The body of the closure query of `audit` (groups, hashes, window). | The body of `tln why` (Design Q499, Q502): no `groups`, the header hashes then the tool hashes, the held nightly as the window when the members agree. The answer is the smallest, and the reasons do not depend on the window. | L2 calls.log of all cases |

## Split (proposal)

| Part | Content | Rules | Lines (guess) |
| --- | --- | --- | --- |
| 244a (these tests) | `AuditCheck` (pure) and the command with a registry. With `direct` (the setting, `--registry direct`, or the fallback of R-RG9) the command is not done: a temporary exit 1 (`tln audit with direct is not built yet`, no test). | R-CM14, R-AU1 to R-AU5, R-AU8 to R-AU13, R-AU15, R-PT8 | 450 (300 pure, 150 flow). Over TW19 (400): the human may move `text` and `data` into their own module or accept the size. |
| 244b | Q-244-9 (Q620: a repository that the privacy guard refuses is a `repo-missing` finding, its hashes stay out of the query). `direct`: the release list (R-DI2) of each repository of the closure, also the transitive groups; a 404 is `repo-missing` (a `Github.releases!` form that keeps the 404); a tag not in the list or a draft is `release-missing`; `prerelease` true; another package asset (R-DI15) is `asset-replaced` with `new_hash`; a redirect is `moved`. | R-AU1, R-AU2 (`direct` column), R-AU4, R-DI2, R-DI11, R-DI15 | 200 |
| 244c | The R-AU7 warnings of each resolve (from the answer or the lists that it read, no extra request), the R-AU14 note for `moved` (= the R-PU28 note), and the R-FE10 404 message with the reason. | R-AU7, R-AU14, R-AU6, R-FE10, R-PU28 (the note) | 200 |

Questions for 244b (not for this review): how `direct` sees a redirect (`moved`): the `Fx` has no final URL, so the recommended source is the `owner/repo` of the `html_url` of the release objects; a tag with no package asset, and a tag with 2 package assets of which one is the header hash (R-DI4). Questions for 244c: R-AU14 starts `moved` in P2 for a rename, but the plan puts the client part of R-PU28 in P3.

## How the expected files were made (read this for the review)

| File | Source |
| --- | --- |
| `expect/tree.diff` | `tree_diff` (tests/lib.sh) over a copy of `given/` and the same copy with the one change: `projects.json` gets the project (R-PD9, as cm7-why-registry). `mk-audit.py` does this. |
| `expect/stdout`, `expect/stderr`, `expect/exit` | The TW24 texts above, literal in `mk-audit.py`. A run with exit 0 has nothing on stderr. The `--json` runs print only the envelope; exit 21 also prints the failure line on stderr. |
| `expect/calls.log` | Baked from the real run after the review (2026-11-12), and read: the guess below plus the real `read_files $PROJECT/<p>/talon.toml` after the two `list_dirs` lines (the project finder reads a talon.toml that exists: au9-ignore, au12-bad-items, au1-tool), and the read of the cached header of the unindexed web in au4-not-indexed (`random`, `list_dirs packages`, `read_files <hash>/main.roc`). `mk-audit.py` keeps a baked calls.log and writes the guess only for a case that has none. |
| Closure answers | `fx/http/127.0.0.1%3A9/v1/closure.POST`: records for each closure hash (json has the deps parser and util), release rows with the states, `repos` items. The package headers are also in the cache, in case the walk reads them. |

### Guessed calls.log lines (the first round; now replaced by the real lines, see above)

| Part | Guess |
| --- | --- |
| Start | The lines of cm7-why-registry: `args`, `env_all`, `tty` (not with `--json`), the begin, the record of the project (`write_atomic projects.json` on the first run only), the load `read_files <main.roc> <talon.toml> <config.toml>`. |
| Guard | One `read_files` of the kept `repo.json` of each repository of the header entries, then of the tools, in the order of the header. |
| Query | One `http_send POST /v1/closure`: `compilers` from = to = the pin of the header, `groups` `[]`, `hashes` the header hashes in header order, then the tool hashes (Q-244-10). Then no other call: the walk takes the facts from the records. No `db_query` (no evidence). |
| au12 run 1 | Stops after the load: no guard, no query. |
| au12 runs 2, 3 | `args`, `env_all`, `tty` (the real start of the red run). |
| au9 | `[resolution] snapshot` adds no call (a guess). |

## Trickiest behaviors (for the mutation check later; not run)

| # | Behavior | Test that should catch a mutant |
| --- | --- | --- |
| 1 | R-AU13 order: `repo-missing` before `release-missing`, `yanked` first | L0 5 rows 13 to 18 |
| 2 | The release of an entry is matched by hash, URL form and version, not by hash only | L0 8 (decoy rows) |
| 3 | An ignore item needs the same reason; the name matches with any case; the version must be equal | L0 14; L2 au9 run 4 |
| 4 | Exit 21 only for a finding that fails and is not ignored | L0 15; L2 au9 runs 1, 3 |
| 5 | `via` is every header alias whose paths reach the row (not only `Row.via`) | L0 1 (parser via json and web) |
| 6 | One entry for each hash across members; `unused` counts across all findings | L0 3, 14 |
| 7 | The tool hash is in the query and checked, its closure is not | L0 1; L2 au1-tool |
| 8 | `checked` leaves out a hash with no release | L0 10 |
| 9 | `[resolution] snapshot` hides no release in `audit` | L2 au9 (parser and util have log index 7 and 8) |
| 10 | The flag is checked before any read; the talon.toml items before the query | L2 au12 calls.log |

## Out of scope

`direct` (244b), Q-244-9 (the privacy guard gives `repo-missing`: moved to 244b by the review), R-AU7, R-AU14, R-FE10 text (244c), advisories and the scanner hook (P3), the design example of CLI 3 as an L3 case (TW16: after 244b, because its note line is the `direct` note).

## Mutation check (research/slice-244-revert/RESULT.md)

21 mutants, 16 caught first. The gaps G1 (a2, a2b), G2 (a3b, caught at L2 only) and G3 (a6b) got L0 8 (decoys moved before the true row, one new decoy), L0 23 and L0 24 on 2026-11-12. All pass on the current code (`l0-9`: 175 of 175). G4 (behavior 9, `[resolution] snapshot`) has no mutant of the flow: L2 au9-ignore stays its guard.

## Disputes (from the code agent) and rulings (the manager, 2026-11-12)

| # | Dispute | Ruling | Change to the tests |
| --- | --- | --- | --- |
| D1 | L0 16 and L0 17 treat util as a header entry, but `f_util` is built from the p1 entry, where util is transitive (via json), as in au1-findings. | The tests are wrong. | L0 16: `f_util` has the transitive fix `tln update json (tln why someone/roc-util), or use [overrides]`, and a new row `util_header` (util as a header entry) keeps `tln update util`. L0 17: the util warning row ends with `via json`. |
| D2 | au9-ignore runs 3 and 4: the `fix:` items were in the order parser, xml; the rule is the order of the findings (xml comes before parser). | The tests are wrong. | `fix: xml: tln update xml. parser: ...` in `mk-audit.py`. |
| D3 | calls.log of au9-ignore, au12-bad-items run 1 and au1-tool: the real run reads `$PROJECT/<p>/talon.toml` after the two `list_dirs` lines. | Accept the real line. Bake the real lines after the review. | All calls.log files are the real run, read by eye. Every stdout, stderr and exit was read: no exit-0 run has text on stderr, and no failure is baked as expected. |
| D4 | Q-244-4: the code prints the note on stderr only, because `Report` has no field for it. | Add tests; the code agent adds a `Report` field. | L0 22 and au4-not-indexed runs 1, 2 (red). The note text of the code is accepted. |

