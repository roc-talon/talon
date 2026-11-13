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


---

# 244b `tln audit` with `direct`, and the privacy guard case

Phase: P2. Status: code (green). Design Q620 (G-C250) item 9, Design Q621 (G-C251): the answers of Q-244b-1 to Q-244b-4, as recommended. The code agent wrote `cli/lib/AuditDirect.roc`, `AuditFlow.registry!` and `AuditFlow.direct!`, `Github.audit_list!` and `PrivacyGuard.collect!`. L0 `l0-9` 180 of 180; L2 `audit/` 10 of 10 (2026-11-12, after the ruling below).

## Rules (244b)

| Rule | What it says for this part |
| --- | --- |
| R-AU1 | With `direct`, the state comes from the release list of R-DI2 for each group of the closure, transitive groups too (one list for each repository). |
| R-AU2 (`direct` column) | `release-missing`: the tag is not in the list (a draft too). `prerelease`: `prerelease` true. `asset-replaced`: the tag has another package asset (R-DI15). `repo-missing`: the list call answers 404. `moved`: the answer comes from another name (GitHub redirects a renamed repository). `yanked` has no `direct` source; an R-AP31 move has none either. |
| R-AU4, R-C6 | With `direct` the last line is `note: no yank and advisory data without a registry` (the R-C6 text; the registry text of Q620 item 2 is for a registry only). |
| R-DI2, R-DI3, R-DI4, R-DI11, R-DI13, R-DI15 | The list call, its cache of 60 s and its ETag; draft and prerelease; the package asset; another host has no index; the rate limit (exit 15); a re-release. |
| R-RG4, R-RG6, Q620 item 9 | With a registry: a repository that the guard refuses (404 or private, no kept public answer) is a `repo-missing` finding for `tln audit` only, and its hashes stay out of the closure query. `direct` sends no registry request, so it runs no guard. |

## Scope (facts found in the code before any change)

| Fact | Where | Consequence |
| --- | --- | --- |
| `AuditFlow.go!` stops with exit 1 `tln audit with direct is not built yet` for `direct`. | AuditFlow.roc | Red state of ad1 and ad2. |
| `PrivacyGuard.check!` returns `Err(refusal)` (exit 2) on the first refused repository and checks no later one. | PrivacyGuard.roc | Red state of ad9. The code needs a form that gives the refused repositories back. |
| `Github.releases!` turns any status other than 200, 304 or a rate limit into `status_failure` (exit 15): a 404 and a 301 stop the command. | Github.roc | `audit` needs a form that keeps a 404 (`NotFound`) and follows one redirect (Q-244b-1). |
| The real `Fx.http_get!` follows no redirect: basic-cli `Http.send!(request, {})` gives the first answer. GitHub answers a renamed repository with 301 and `Location: <api>/repositories/<id>/releases...`: the location has an id, not a name. | RealFx.roc, basic-cli Http.roc | Q-244b-1. |
| `Index.assets_of` gives the package assets of one release object (R-DI4 names). | Index.roc | `direct_finding` can use it. |
| With `direct`, the walk reads each package header from `packages/<hash>/` or downloads the archive (R-DI7). A package that is not in the cache and whose asset is gone stops the walk with exit 15 before the report. | Walk.roc, Gather.roc | Q-244b-3. All 244b fixtures have the packages in the cache. |

## Proposed names (TW24, for the code agent)

| Name | Type | Rule |
| --- | --- | --- |
| `AuditCheck.repos_of` | `List(Entry) -> List({ owner : Str, repo : Str })`: the `github.com` repository of each entry (URL), lower case, each once, in the order of the entries | R-AU1, R-DI2, R-DI11 |
| `AuditCheck.direct_finding` | `{ entry : Entry, list : [NotFound, Pages({ pages : List(Str), redirected : Bool })] } -> Try(Finding, [None, BadPage(U64)])` | R-AU2, R-AU13, R-DI3, R-DI4, R-DI15 |
| `AuditCheck.of_lists` | `{ entries : List(Entry), lists : List({ owner : Str, repo : Str, list : ... }) } -> Try({ checked : U64, findings : List(Finding), unindexed : List(Entry) }, Fail)`; a bad page is kind `Network`, `the release list of <owner>/<repo> (page <n>) is not a list of releases` (the text of `Init` and `FullName`) | R-AU1, R-DI11 |
| `AuditCheck.of_guarded` | `{ answer, entries, refused : List(Str) } -> { checked, findings, unindexed }` (`of_answer` with the lower-case `owner/repo` names that the guard refused) | Q620 item 9 |
| `AuditCheck.text` (changed) | with `index: Direct` the note of an unindexed entry is `note: not checked: <name> <version>: no index without a registry` | R-DI11, R-OUT2 |

Flow (part C, a guess): with `direct`, after the load and the talon.toml items: the walk of each member (`Ls.walk_loaded!` with the `Direct` index); `entries`; for each repository of `repos_of`, in order, the release list (a form of `Github.releases!` that gives `NotFound` for a 404, and on a 301, 302, 307 or 308 of page 1 follows the `Location` once when it is on the same API base, then `redirected` true); `of_lists`; `ignore`; the report with `index: Direct`. With a registry: the guard with a form that collects the refused repositories; their hashes out of the query; `of_guarded` in place of `of_answer`.

## Tests (244b)

### L0 (tests/unit/AuditcheckTest.roc, appended)

| # | Test | Rules | State now |
| --- | --- | --- | --- |
| b1 | `direct_finding`, 22 rows: 404; the tag with the header asset (and other assets); tag missing, empty list, `v2.1.0` is not `2.1.0`, a draft; prerelease; draft and prerelease; one other package asset (new hash); a prerelease with one other package asset and no header asset: `asset-replaced` (row 10b, mutation gap G1); no package asset; 2 other package assets; the header asset and another; the tag on page 2; redirect with a new name, with the same name in other case, with an empty list; redirect with prerelease and with a replaced asset (the successor stays); 2 bad pages | R-AU2 R-AU13 R-DI3 R-DI4 R-DI15 (Q-244b-1, Q-244b-2) | green |
| b2 | `repos_of`: each repository once, lower case, in entry order; another host is left out | R-AU1 R-DI2 R-DI11 | green |
| b3 | `of_lists`: `checked`, findings in entry order, `unindexed` (another host, a repository with no list), a bad page (exit 15 text) | R-AU1 R-AU2 R-DI11 | green |
| b4 | `of_guarded`: a refused repository gives `repo-missing` (counted, `since` null, in entry order, never unindexed); `of_answer` alone puts it in `unindexed` | Q620 item 9 | green |
| b5 | `text` with `index: Direct`: the note of an entry with no index, then the R-C6 note | R-AU4 R-DI11 R-OUT2 | green |

Checked against a copy of `cli/lib` with stubs of the 4 new names (`.tmp/`, deleted after): no type error; b1 to b4 fail with `todo`, b5 with the registry text; the 24 old expects pass. In the repo, `l0-9` makes the compiler stop with SIGSEGV (exit 139) until the 4 names exist (the same as 244a): the code agent adds them first.

### L2 (tests/commands/cases/audit/, made by `tests/tools/mk-audit.py`)

| Case | Runs | Rules | State now |
| --- | --- | --- | --- |
| ad1-direct | `TALON_REGISTRY=direct`. q1: pf (fine), json 2.1.0 (another package asset: asset-replaced, new hash), csv (404: repo-missing), xml (301 to `/repositories/42/...`, new list with `html_url` of acme/roc-xml: moved), pre (prerelease); json needs parser (fine) and util (tag 0.3.0 missing: release-missing). Run 1: report, exit 21. Run 2: `--json`, exit 21, the pages of run 1 are used with no request. | R-CM14 R-AU1 R-AU2 R-AU3 R-AU4 R-AU13 R-DI2 R-DI3 R-DI4 R-DI15 R-C6 R-OUT2 | green |
| ad2-direct-clean | `direct`, q2: pf and json fine, x is a loopback URL (no index, R-DI11). Human and `--json`, exit 0: the `not checked` note and the R-C6 note. | R-AU1 R-AU3 R-AU4 R-C6 R-DI11 | green |
| ad9-guard | A registry. p8: gone (`someone/roc-gone`) has no kept public answer and GitHub answers 404: a `repo-missing` finding, exit 21; the query has only the hashes of pf and json; the walk reads gone from the cache. | Q620 R-RG4 R-RG6 R-AU2 R-AU3 | green |

| ad10-redirect-host | `direct`, r1: pf (fine), xml: the list answers 301 with `Location: https://evil.example/repositories/42/releases?per_page=100` (another host; a route exists there). Exit 15, `GitHub answered 301 for <the list URL>`; no request to `evil.example` (mutation gap G2, d12: the token never goes to another host). | R-CM14 R-DI2 (Q621 item 1, Q-244b-1) | green |
| ad11-redirect-none | `direct`, r2: as ad10, but the 301 has no `Location` header. Exit 15, the same text, no second request. | R-CM14 R-DI2 (Q621 item 1) | green |

ad10 and ad11 were added after the 244b mutation check. They passed on the code as it was (no code change). Their calls.log is the guess of `mk-audit.py`; it is the same as the real `out/calls.log.n` (read by eye: 2 `http_get`, pfx and roc-xml only).

Run 2026-11-12 (after the mutation gaps): `l0-9` all passed; `tests/commands/run.sh audit/` 12 passed, 0 failed.

### Guessed calls.log lines (the code agent may dispute; the real lines are baked after the review)

| Part | Guess |
| --- | --- |
| Start | The real start of the 244a cases (as `od1-table`: no `read_files talon.toml` when the project has none). No guard and no closure query with `direct`. |
| Walk (direct) | `random`, `list_dirs packages`, then one `read_files` of the cached `main.roc` files for each level (level 1: the header hashes in header order; level 2: parser, util). |
| Lists | For each repository of `repos_of`, in entry order (pfx, json, roc-csv, roc-xml, pre, parser, roc-util): `list_dirs index/github/<o>/<r>`, `programs gh`, `http_get https://api.github.com/repos/<o>/<r>/releases?per_page=100` with `User-Agent`; then `write_atomic 1.json 1.meta` for a 200 list. The 404 writes nothing. The 301: a second `http_get https://api.github.com/repositories/42/releases?per_page=100`, and nothing is written. |
| ad1 run 2 | A kept page younger than 60 s: `list_dirs`, `read_files 1.meta 1.json`, no request. The 404 and the redirected list are asked again (they are not kept). |
| ad9 | The guard lines are the real start of the red run: `read_files` of the 3 `repo.json`, `programs gh`, `http_get https://api.github.com/repos/someone/roc-gone`. Then (guess) the query with 2 hashes, and the walk: `random`, `list_dirs packages`, `read_files <gone>/main.roc`. |

## Output (proposed, TW24)

| Where | Text or field |
| --- | --- |
| Line 1 with `direct` | `audit: <n> packages checked (direct)` (244a rule) |
| An entry with no index (`direct`) | `note: not checked: <name> <version>: no index without a registry` (`<name>` is `Closure.Row.name`: for a loopback URL `127.0.0.1:9/x/1.0.0`). `--json`: `{"kind":"not-indexed",...}` as 244a. |
| `asset-replaced` with `direct` | the 244a detail with the new hash: `GitHub has <first 6 of new>..., the header has <first 6 of old>...`; `new_hash` in `--json`. With 0 or 2+ other package assets: `the asset of the header is gone`, `new_hash` null (Q-244b-2). |
| `since` with `direct` | always null. |
| ad9 | the 244a texts (`repo missing` row, fix, failure line). |

## Questions (TW17): answered as recommended, Design Q621 (G-C251)

| # | Question | Answer (Q621) | Tests that follow it |
| --- | --- | --- | --- |
| Q-244b-1 | How does `direct` see `moved`? R-AU2 says "the release list answer comes from another name, because GitHub redirects a renamed repository". The `Fx` follows no redirect, and the 301 `Location` has a repository id, not a name. | `audit` follows a 301, 302, 307 or 308 of page 1 once, only to the same API base (`TALON_GITHUB_API` or `https://api.github.com`). The finding is `moved` (also with no successor). The successor is the `owner/repo` of the `html_url` of the first release of the new list, when it is not the old name (any case); else null. The pages of a redirected list are not kept (the cache dir has the old name). Other commands (a resolve) keep their exit 15 on a 301 (no change here; 244c or later). | L0 b1 rows 15 to 19; L2 ad1 |
| Q-244b-2 | The release of the header tag with 0 package assets, or with 2 or more (R-DI4: not a candidate). | 0 package assets: `asset-replaced`, `new_hash` null (as Registry R-PU20 for a release with no package asset). The header hash among 2+ package assets: no asset reason (its bytes are still there; R-DI4 stops only a new candidate). 2+ other package assets: `asset-replaced`, `new_hash` null. Exactly one other: `asset-replaced` with that hash. | L0 b1 rows 2, 3, 10 to 13 |
| Q-244b-3 | With `direct` (and for a refused repository with a registry, Q620 item 9) the walk needs the archive of each package (R-DI7). A package that is not in the cache and whose asset is gone (404) stops the walk with exit 15 before any finding is printed. | For `tln audit` only: such a node is a leaf. Its own finding comes from the list (or the guard); its deps are not checked, and one note says so: `note: not checked: the deps of <name> <version>: its archive is gone` (TW24). The exit code follows the findings. | none yet (all fixtures have the archives in the cache) |
| Q-244b-4 | R-AU1 says "the state of now", R-DI2 uses a kept page younger than 60 s with no request. Does `audit` use it? | Yes: R-DI2 as it is (60 s is "now" for an index that GitHub caches too), with `If-None-Match` for an older page. `--offline` stays exit 2 (Q620 item 8). | L2 ad1 run 2 |

## Trickiest behaviors (for the mutation check later; not run)

| # | Behavior | Test that should catch a mutant |
| --- | --- | --- |
| 1 | The tag match is exact (`v2.1.0` is not `2.1.0`) | L0 b1 row 6 |
| 2 | A draft is `release-missing`, also when it is a prerelease | L0 b1 rows 7, 9 |
| 3 | The header hash among 2 package assets is no finding; 2 other assets give no new hash | L0 b1 rows 12, 13 |
| 4 | A redirect is `moved` even with no successor; the same name in other case is no successor | L0 b1 rows 15, 16 |
| 5 | Another reason wins over `moved` and keeps the successor | L0 b1 rows 18, 19 |
| 6 | All pages are read (the tag on page 2) | L0 b1 row 14 |
| 7 | Transitive repositories are listed, each repository once | L0 b2; L2 ad1 |
| 8 | A 404 is a finding, not exit 15; a bad page is exit 15 | L0 b1 row 1, b3; L2 ad1 |
| 9 | A refused repository is a finding, its hash is not in the query, the other hashes are | L0 b4; L2 ad9 calls.log |
| 10 | Another host is `unindexed` with the `direct` note text | L0 b3, b5; L2 ad2 |

## Notes after the code (2026-11-12)

| Item | Text |
| --- | --- |
| Dispute (ruled by the manager) | ad1-direct calls.log: the real walk (`ResolveBase.closure!`) does `random` and `list_dirs $HOME/.cache/roc/packages` for each level, not once for each walk. The real lines are accepted: copied from the run's `out/calls.log.n` (not `UPDATE=1`), kept by `mk-audit.py`. The stdout, stderr and exit of ad1, ad2 and ad9 were read: no exit-0 run has text on stderr, and no failure is baked as expected. ad2-direct-clean and ad9-guard match the real run as written. |
| A redirect to another host | Q621 item 1 follows a redirect only to the same API base. A `Location` on another host, or no `Location`, is not followed: the list call fails with exit 15, `GitHub answered <status> for <url>` (`Github.status_failure`). Tests: L2 ad10-redirect-host, ad11-redirect-none. |

## Mutation check (244b, research/slice-244b-revert/RESULT.md)

14 mutants: 12 caught, 2 not caught, no equivalent mutant. Tests added for the 2 gaps:

| Gap | Mutant | Test added |
| --- | --- | --- |
| G1 | d1: `prerelease` wins over `asset-replaced` (R-AU13, direct) | L0 b1 row 10b: a prerelease with no header asset and one other package asset gives `AssetReplaced` with the new hash |
| G2 | d12: a redirect to any location is followed (the token could go to another host) | L2 ad10-redirect-host (a `Location` on `evil.example`), ad11-redirect-none (no `Location`): exit 15, no second request |

## Out of scope (244b)

R-AU7, R-AU14, R-FE10 (244c); the behavior of Q-244b-3 (no test until it is answered); a 301 in the resolve commands; advisories (P3).

---

# Part 244c: the audit warnings of a resolve, and the download 404 message

Phase: P2. Status: code (green), 2026-11-13: L0 `l0-9` 186 of 186; L2 `audit/` and `registry/au7-install-warnings`, `registry/fe10-install-404` 14 of 14 (the other L2 cases pass). Design Q620 (G-C250) item 1 (P2 build, the phase is a constant of each `tln` release), Q621 (G-C251), Q622 (G-C252): the answers of Q-244c-1 to Q-244c-5 and the 244c texts, approved by the user on 2026-11-13.

The code (by the code agent):

| Part | Where |
| --- | --- |
| The 5 pure functions (`resolve_findings`, `resolve_direct`, `resolve_line`, `resolve_doc`, `download_failed`) | `AuditCheck`, `AuditReport` |
| `AuditResolve.roc` (new): the command code. `warn!` after `ResolveBase.closure_notes!`: one `warning: <line>` on stderr for each finding, from the closure answers of the run, no request; the R-FE10 message at a download failure | `cli/lib/AuditResolve.roc` |
| The hooks | `InstallFlow.finish!`, `VerifyFlow`, `Install`, `Update`, `Verify`, `AuditFlow` |
| `Fail.Ran.audit : List(JsonDoc)`: the `data.audit_warnings` elements travel with the run to the end of the command | `cli/lib/Fail.roc` |
| `from_p3 : {} -> Bool` (false in P2): the phase constant of Q-244c-4 (the `Run:` part, the fix with a successor, the fix of `moved`) | `cli/lib/AuditReport.roc` |

## Rules (244c)

| Rule | What 244c does |
| --- | --- |
| R-AU7 | A command that resolves prints one warning for each closure hash with a reason of R-AU2, from the release states that it has: the closure answer (registry), or the release lists that it read (`direct`). No extra request. The exit code does not change. The warning gives the reason and the fix of R-AU8. |
| R-AU14 | `moved` of a header entry: the warning is the note of Registry R-PU28, one line for each entry, not a second warning. `repo-missing` and `moved` of a rename start in P2. |
| R-AU6, R-FE6, R-FE10 | A download 404 of a closure URL: when the command has a state with `asset-replaced`, `repo-missing` or `release-missing`, the message gives the reason and the fix; else it names `tln audit` (done already, `Fetch.download_failed`). Exit 15. |
| R-FL4, R-J2, R-OUT4 | The warnings go to stderr, also with `--json`, and stay with `--quiet`. `data` holds each fact of the lines. |

## Scope (facts found in the code before any change)

| Fact | Where |
| --- | --- |
| `install`, `add`, `update`, `upgrade` and `init` resolve in `InstallFlow` (`finish!`); `verify` in `VerifyFlow`. `remove` resolves nothing. `outdated` and `why` send a query but resolve nothing. `--frozen` and `--offline` send no closure query. | `Resolve.roc`, `InstallFlow.roc`, `VerifyFlow.roc` |
| After the pick, `finish!` walks the new closure (`ResolveBase.closure!`) and prints `ResolveBase.closure_notes!` on stderr. The closure answer is `request.index` (`Answer(a)`), and the second answer of a held move is `probed.second`. So the closure and the states are there, with no extra request. | `InstallFlow.finish!` |
| `AuditCheck.entries`, `state_of`, `finding`, `of_answer`, `ignore`, `toml_items`, `fix` (244a) and `direct_finding` (244b) give the findings and the fix. | `AuditCheck`, `AuditReport`, `AuditDirect` |
| With a registry the resolve does not download an archive whose hash has an artifact record in the answer (`Gather.facts!`, R-AL8 source 2). So a 404 in a resolve with a registry comes only for a hash with no artifact record. With `direct`, `Gather` downloads every archive that is not in the cache. | `Gather.roc` |
| With `direct`, the resolve reads the release list of each free variable and each new name (R-DI1), and `Index.candidates` keeps only candidates: a chosen release is never a draft, a prerelease or a re-release. A finding comes only for another closure hash of a listed repository (for example a second series of the same repository). `Index.candidates` already prints the R-DI15 warning of a re-release (its own text). A list that answers 404 or 301 stops the resolve (exit 15, Q621 item 1). | `Index.roc`, `PickIndex.roc` |
| The client part of Registry R-PU28 (`tln update <alias>` follows a successor) is P3 (`PLAN-P2-CLI.md` line 47, Design Q406). No code follows a successor today. | `grep successor cli/lib` |

## Proposed names (TW24, for the code agent)

| Name | Does |
| --- | --- |
| `AuditCheck.resolve_findings : { answers, entries, items } -> List(Finding)` | Registry. For each entry, in order: the first answer of `answers` that has its release row gives the state (`state_of`, `finding`). An entry with no row gives nothing. A finding that an item of `items` ignores is dropped. An item that does not parse is skipped. |
| `AuditCheck.resolve_direct : { lists, entries, items } -> List(Finding)` | `direct`. `direct_finding` for each entry whose repository is in `lists`. `asset-replaced` with a new hash, and a bad page, give nothing. Items as above. |
| `AuditCheck.resolve_line : Finding -> Str` | The text of one warning (below). |
| `AuditCheck.resolve_doc : Finding -> JsonDoc` | One element of `data.audit_warnings`. |
| `AuditCheck.download_failed : { what, status, url, index, finding } -> Fail` | R-FE10. `Fetch.download_failed` keeps its text for the other cases. |

The flow (a proposal): in `InstallFlow.finish!` and `VerifyFlow`, after `ResolveBase.closure_notes!`: `AuditCheck.entries({ members: closures, tools: [] })`, the items of `[audit] ignore` of the root `talon.toml` (the text that the load read), then `resolve_findings` (answers `[second, first]`) or `resolve_direct` (the lists of the run), then one `warning: <line>` on stderr for each, and the docs in `Outcome`. The 404: where the flow gets a download failure, it looks for the release state of the hash of the URL and calls `download_failed`. The entry comes from the walk when it has one; else the alias of a header entry with that URL; else `via` is unknown.

## Questions (TW17): answered, Design Q622 (G-C252)

The user approved Q-244c-1, 2, 3 and 5 as recommended, and the texts. Q-244c-4: the answer is in the row and in "The fix before P3" below.

| # | Question | Answer | Tests that follow it |
| --- | --- | --- | --- |
| Q-244c-1 | Which commands print the R-AU7 warnings? | Each command that resolves: `install`, `add`, `update`, `upgrade`, `init` and `verify`. Not `--frozen` and not `--offline` (no closure answer; the kept copies of R-IX6 have no `repos`). Not `outdated`, `why`, `list`, `remove`: they resolve nothing. Reason: unlike the index notes (Q537), a warning shows only when there is a problem, so it is no noise in CI. | L2 `registry/au7-install-warnings` (`install`) |
| Q-244c-2 | Which hashes and which states? | The closure after the pick (with `--dry-run`, the planned closure), all members, no project tools (the resolve query has no tool hashes). With a held move, the second answer first, then the first answer. A hash with no release row gives nothing (no `not-indexed` note: that is `tln audit`). | L0 `resolve_findings` (2 expects) |
| Q-244c-3 | Does `[audit] ignore` apply to the warnings? | Yes: an ignored finding gives no warning (the user accepted it). An item that does not parse is skipped with no stop and no line (Q620 item 6: only `tln audit` stops). No `unused ignore` note. | L0 `resolve_findings` |
| Q-244c-4 | R-AU14 starts `moved` in P2 with the text `json: moved to acme/roc-json. Run: tln update json`. But `tln update <alias>` follows a successor only in P3 (R-PU28 client part, Q406). In P2 the `Run:` part tells the user to do a step that does not move the entry. | User (2026-11-13): drop `Run:` until P3, and change the 244a `tln audit` fix the same way in 244c. (a) Before P3 the line is `json: moved to acme/roc-json`, with no `Run:` part; from P3 it gets `. Run: tln update json`. (b) Before P3 a successor does not make the R-AU8 fix `tln update <alias>` (`tln update` does not follow a successor until P3): a finding with a successor gets the fix of its reason as if it had no successor, and `moved` has no fix. Texts: "The fix before P3" below. | L0 `resolve_line` (row `xml`), L2 `au7-install-warnings` |
| Q-244c-5 | `direct`: R-AU7 and R-DI15 give 2 lines for one re-released tag (the `asset-replaced` finding with a new hash, and the warning of `Index.candidates`). The catalog (CLI 3) gives one text for both. | One line: R-AU7 prints nothing for `asset-replaced` with a new hash, because the R-DI15 warning names the release and both hashes (the rule of R-AU14: not a second warning). The text of `Index.candidates` stays as it is (out of scope; changing it changes the `index/` cases). | L0 `resolve_direct` row 2 |

## Tests (244c)

### L0 (tests/unit/AuditcheckTest.roc, appended)

| # | Test | Rules | State now |
| --- | --- | --- | --- |
| c1 | `resolve_findings` with one answer: the findings in entry order, an ignored item dropped, a bad item skipped | R-AU7 (Q-244c-2, Q-244c-3) | red (no name) |
| c2 | `resolve_findings` with 2 answers: the first answer with the row wins, with its own `repos` | R-AU7 (Q-244c-2) | red |
| c3 | `resolve_direct`, 7 rows: prerelease; asset-replaced with a new hash (nothing); no package asset; tag not in the list; ignored; bad page; no list | R-AU7 R-DI15 (Q-244c-5) | red |
| c4 | `resolve_line`, 11 rows: each reason, header and transitive, `moved` with and with no successor (no `Fix:` part for `moved`) | R-AU7 R-AU8 R-AU14 R-PU28 (Q-244c-4) | red |
| c5 | `resolve_doc` of a transitive finding | R-OUT4 R-J6 | red |
| c6 | `download_failed`, 10 rows: the 3 reasons (registry), `direct`, a transitive entry with an unknown `via`, other reasons, no state, status 500 | R-FE10 R-FE6 R-AU6 R-AU8 | red |

Checked against a copy of `cli/lib` with stubs of the 5 new names (`.tmp/`, deleted after): no type error; 180 old expects pass, the 6 new ones fail. In the repo, `l0-9` does not compile until the 5 names exist (the code agent adds them first).

### L2 (made by `tests/tools/mk-audit.py`, copies of `registry/di1-install-no-free`, project u1: pf, json, parser, all held, no `talon.toml`)

| Case | Runs | Rules | State now |
| --- | --- | --- | --- |
| registry/au7-install-warnings | The answer: `acme/json` is `missing`, `acme/parser` is `moved` to `acme/roc-parser`. `install --no-check --dry-run`: 2 warning lines on stderr, exit 0. `--json`: `data.audit_warnings`, the lines on stderr. `--quiet`: the lines stay. | R-AU7 R-AU14 R-FL4 R-J2 R-OUT4 | green |
| registry/fe10-install-404 | The answer has the row of json 2.0.0 with `withdrawn: asset-replaced` and no artifact record; the archive is not in the cache; the download answers 404. Exit 15 with the reason and the fix. | R-FE10 R-FE6 R-AU6 R-AU8 | green |
| registry/au7-no-finding | The answer of di1 (all active). `install --no-check --dry-run --json`: `data` has no `audit_warnings` member, the output of di1 as it is (mutation gap G3). | R-AU7 R-J6 | green |
| registry/au7-ignore | The answer of au7-install-warnings; `u1/talon.toml` has `[audit] ignore = ["acme/json@2.0.0:repo-missing", "bad"]`. No line for json, the parser line stays, no stop and no line about the bad item, exit 0 (mutation gap G2). | R-AU7 R-AU9 (Q-244c-3) | green |
| registry/au7-held-move | Run 1 of registry/ap30-held-move-notes (`update yaml@1.1.0`, a held move of pf). The first answer says acme/json is active (with the row of json 2.0.0), the second answer says it is missing: one `repo-missing` line for json (mutation gap G1). | R-AU7 R-AP16 R-SP24 (Q-244c-2) | green |

Run 2026-11-13 (capped, `TMPDIR` in `.tmp/tmp`): both cases fail only on stdout/stderr text; `calls.log` and `tree.diff` match the code of today. That shows R-AU7: no extra request.

Not tested at L2: `direct` (not fed yet: slice 244d), `add`, `upgrade`, `init`, `verify` (the same code place as `install` and `update` in `finish!`; `verify` is another flow: a review point), `--frozen` and `--offline` (no warning, Q-244c-1).

The 3 cases of the mutation gaps (added 2026-11-13) passed on the code as it was. Their calls.log: au7-no-finding is run 1 of di1 as it is; au7-held-move is run 1 of ap30-held-move-notes as it is; au7-ignore is the real run (one more `read_files $PROJECT/u1/talon.toml` in the project search, because the file now exists), baked after a check by eye: 2 requests (the guard `http_get` of acme/parser and the one closure query), as in di1, so R-AU7 sends no extra request. In au7-held-move the warning is on stderr before the lines of the held move (the real order: after the closure notes).

### Guessed calls.log lines

None are new. Run 1 of each case is run 1 of `di1-install-no-free` with `tty` (a human run). Runs 2 and 3 of `au7-install-warnings` drop the writes of `projects.json` and `path-roc.json` and the GitHub request for `acme/parser` (kept after run 1). `fe10-install-404` adds the download calls of `fetch/fe-flow` (`random`, `list_dirs`, `programs curl wget`, `make_dirs`, `spawn_all` with the curl job, `delete`). All match the code of today.

## Output (proposed, TW24)

| Item | Text |
| --- | --- |
| A warning (stderr) | `warning: <head>: <name> <version> <state>. Fix: <fix of R-AU8>.` `<head>`: the alias, or `<edge> via <aliases>`. |
| `<state>` | `is yanked ("<reason>")` or `is yanked (no reason given)`; `has a replaced asset (the asset of the header is gone)`; `is in a deleted or private repository`; `has a deleted release`; `is a prerelease`; `is withdrawn (<value>)`; `is in a repository that moved` (` to <successor>` when known) |
| `moved` of a header entry with a successor | `warning: json: moved to acme/roc-json` (P2, Q-244c-4); from P3 `. Run: tln update json` is added |
| Place | After the closure notes, before the ladder lines. In the order of the closure walk. |
| `--json` | `data.audit_warnings`: `[{name, group, version, hash, alias, via, reason, successor, text}]`, after `written` (`index_notes` stays last, Q540). Left out when there is no warning, so no output of today changes (R-J6). |
| 404 with a state | `download of <what> failed: 404 (<url>). The registry says: <state>. <Fix as a sentence>.` With `direct`: `GitHub says:`. `<state>`: `the asset was replaced`, `the repository is deleted or private`, `the release was deleted`. A fix that starts with `tln ` gets `Run `. An entry with an unknown `via`: `Update the package that needs it (tln why <name>), or use [overrides].` |

### The fix before P3 (Q-244c-4, TW24 proposal; shown to the user at commit time)

| Place | Before (244a, 244b) | Now (P2) |
| --- | --- | --- |
| `AuditCheck.fix` of a header finding with a successor (any reason but `moved`) | `tln update <alias>` | The fix of its reason with no successor. Example: `repo-missing` with a successor: `tln remove csv, then tln add another package, or add the item to [audit] ignore`. |
| `AuditCheck.fix` of `moved` (header, transitive, tool; with or without a successor) | `tln update <alias>` (header) | No fix: `""`. It does not fail, and the old URL still works (R-AU3). The `successor` field and the detail cell (`successor: <name>`) keep the new name. |
| The `fix:` line of `tln audit` | Items for the failing findings and for the findings with a successor | Items for the failing findings only (a successor adds no item). No item: no `fix:` line. |
| `--json` `findings[].fix` | Always text | `null` for `moved`. Text for the other reasons. |
| The R-AU7 line of `moved` (resolve) | — | Header entry with a successor: `<alias>: moved to <successor>`. Else: `<head>: <name> <version> is in a repository that moved[ to <successor>].` with no `Fix:` part. |
| From P3 (the phase constant) | — | The fix of R-AU8 with a successor (`tln update <alias>`) and the `. Run: tln update <alias>` part come back. |

Changed tests (they are red until the code changes): L0 the `fix` expect (rows `csv` with a successor, `xml`, and 3 new `moved` rows), the human text expect (no `xml:` item), the `--json` data expect (`"fix":null`), the not-indexed text expect (no `fix:` line), c4 rows `xml` with no successor and `util` moved (no `Fix:` part). L2 (by `mk-audit.py`): `audit/au1-findings`, `au3-warnings` (no `fix:` line), `au9-ignore`, `ad1-direct`: no `xml:` item, `"fix":null` for xml.

## Trickiest behaviors (for the mutation check later; not run)

| # | Behavior | Test |
| --- | --- | --- |
| 1 | No extra request: the warnings come from the answer that the resolve has | L2 calls.log of `au7-install-warnings` |
| 2 | The first answer of the list wins, with the `repos` of the same answer | L0 c2 |
| 3 | An ignored finding gives no line; a bad item does not stop | L0 c1 |
| 4 | `moved` of a header entry: the R-PU28 line, not a second warning; a transitive `moved` keeps the warning form | L0 c4 |
| 5 | `direct`: no line for `asset-replaced` with a new hash | L0 c3 row 2 |
| 6 | The exit code stays 0 with warnings; `--quiet` keeps them | L2 `au7-install-warnings` |
| 7 | 404 message: only the 3 reasons and only status 404 | L0 c6 |
| 8 | A transitive entry with an unknown `via` is not given the fix of a project tool | L0 c6 row 4 |
| 9 | Before P3 a successor does not change the fix, and `moved` has no fix item (Q-244c-4) | L0 `fix` expect, L2 `audit/au3-warnings` |

## Notes after the code (2026-11-13)

| Item | Text |
| --- | --- |
| `direct` is not fed yet (manager decision) | `resolve_direct` is built and L0-tested (c3), but a resolve with `direct` prints no R-AU7 line yet. The pick does not keep the pages of the release lists (`Index.candidates` keeps only the candidates). To feed it, `ResolveBase.Candidates` needs a `pages` field (4 constructors in `PickIndex` and `ClosureIndex`). This moves to slice 244d (below), with Q-244b-3: both change shared walk and pick code. |
| `--frozen` and `--offline` | They print no R-AU7 warning (Q-244c-1: no closure answer). No test. |

## Mutation check (244c, research/slice-244c-revert/RESULT.md)

11 mutants: 8 caught, 3 not caught, no equivalent mutant. Tests added for the 3 gaps:

| Gap | Mutant | Test added |
| --- | --- | --- |
| G1 | c1: `warn!` searches the first answer before the second (held move) | L2 registry/au7-held-move |
| G2 | c3b: a bad `[audit] ignore` item drops all items | L2 registry/au7-ignore (L0 cannot: `lenient_items` is private) |
| G3 | c11: `audit_warnings: []` in every `--json` run with a closure answer | L2 registry/au7-no-finding |

Run 2026-11-13 after the gap tests (capped, `TMPDIR` in `.tmp/tmp`): `l0-9` 186 of 186; `tests/commands/run.sh audit/ registry/au7 registry/fe10` 17 of 17.

## Size

Estimate before the code: about 200 lines of code: `AuditCheck` about 90 (5 functions), `InstallFlow` and `VerifyFlow` about 40 (the call after the closure notes, the `Outcome` member, `Report` data), the 404 path about 40 (the state of a hash at the failure), the release lists of a `direct` run about 30.

## Out of scope (244c)

The follow of a successor (R-PU28 client part, P3); the text of the R-DI15 warning of `Index.candidates` (Q-244c-5); yank data (P3); mirrors (R-FE6, P3); a 404 during `roc check` (the compiler downloads, not Talon).

---

# Part 244d: `direct` feeds of the walk and the pick

Phase: P2. Status: code in (2026-11-13: `l0-9` 187 of 187; L2 392 of 393 before the rulings below). Design Q621 (G-C251) item 3, Q622 (G-C252) items 1, 2, 5, Q623 (G-C253): the answers of Q-244d-1 to Q-244d-4 and the 244d texts.

## Items

| # | Item | Rules, decisions |
| --- | --- | --- |
| 1 | The R-AU7 warnings of a resolve with `direct`: the pages of the release lists that the pick read go to `AuditCheck.resolve_direct` (built and L0-tested in 244c, c3) in `AuditResolve.warn!`. No extra request. | R-AU7, Q622 items 1, 2, 5 |
| 2 | For `tln audit` only: a package that is not in the cache and whose archive is gone (download 404) is a leaf. Its own finding is reported, its deps are not checked, and one note: `note: not checked: the deps of <name> <version>: its archive is gone`. With `direct`, and with a registry for a repository that the privacy guard refused (Q620 item 9). Other commands keep exit 15 (R-FE6, R-FE10). | Q621 item 3 (Q-244b-3), R-AU1, R-DI7 |
| 3 | (cheap) `--frozen` prints no audit warning | Q622 item 1 (Q-244c-1) |

## Scope (facts found in the code before any change)

| Fact | Where |
| --- | --- |
| `Index.candidates` keeps only the candidates; the pages are not kept after the pick. A `pages` field on `ResolveBase.Candidates` (4 constructors in `PickIndex` and `ClosureIndex`) carries them (the code agent of 244c). | `Index.roc`, `PickIndex.roc`, `ClosureIndex.roc` |
| With `direct` the walk of `tln audit` gets the facts of each package from `Gather.get!`: `Fetch.packages!` for the URLs that are not in `packages/`, then one `read_files!`. The first failure stops the walk (today: exit 15, `download of <what> failed: 404 (<url>). Run tln audit to see why.`). | `Gather.roc`, `Walk.roc` |
| With a registry, the hash of a refused repository is not in the query (Q620 item 9), so the walk downloads its archive. | `AuditFlow.roc` |
| A two-series header (`json` 2.x, `json1` 1.0.0, `json3` 3.0.0 of `acme/json`) resolves today with `update json` in `direct`: one list request, the R-DI15 warning for json3, the R-C8 note of 3 series, exit 0. | L2 `update/au7-direct-series` (run of today) |

## Questions (TW17): answered, Design Q623 (G-C253)

| # | Question | Answer (Q623) | Tests that follow it |
| --- | --- | --- | --- |
| Q-244d-1 | Which download failures make a leaf (item 2)? | Only an HTTP 404 answer of the download (`Http(Ok(404))`), as R-FE10 ("gone"). Another status, a network error, `--offline` with no archive, or an unbundle failure stop `tln audit` as today (exit 15, 16 or 18): Talon cannot say that the archive is gone. | L2 `ad12`, `ad13` (404 only) |
| Q-244d-2 | A header entry whose archive is gone: a leaf too (not only a transitive one)? | Yes, any node of the walk. Its own finding comes from the list (direct) or the answer or the guard (registry); with no reason it has no finding, only the note. | L2 `ad12` (a header entry), `ad13` |
| Q-244d-3 | Item 1: which pages? A run can read a list twice (the second search of a held move, a fall back). | Every list that the run read, the last read of each repository. The run sends no request for the warnings. `--offline` (kept pages) prints none (Q622 item 1). | L2 `update/au7-direct-series`, `update/au7-direct-held-move` |
| Q-244d-4 | Item 2: a second run of `tln audit` downloads the gone archive again (no record of a 404 is kept). Keep it? | Yes. A 404 can be a short fault of the host, and Talon keeps no negative cache of downloads (R-FE1). One request per run and package. | L2 `ad12` run 2 (the download again) |

## Tests (244d)

### L0 (tests/unit/AuditcheckTest.roc)

| # | Test | Rules | State now |
| --- | --- | --- | --- |
| d2 | `Fetch.gone_url` (mutation gap G2): the URL of a download 404 (with or without the R-FE10 state); `Err(None)` for 500, `HTTP error`, a transport error, kind `Integrity`, the offline text | Q623 item 1 | green |
| d1 | `Report` gets `gone : List({ name, version, hash })` (NEW). `text`: one `note: not checked: the deps of <name> <version>: its archive is gone` for each, after the no-index notes, before the R-AU4 note. `data`: one `{"kind":"deps-not-checked","name","version","hash"}` for each, after the `not-indexed` notes. Exit code from the findings. The 5 old `Report` literals get `gone: []`. | Q621 item 3, R-OUT2, R-OUT4 | red (no field: the file does not compile) |

Checked against a copy of `cli/lib` with the field added (`.tmp/`, deleted after): no type error; 186 old expects pass, d1 fails.

### L2 (made by `tests/tools/mk-audit.py`)

| Case | Runs | Rules | State now |
| --- | --- | --- | --- |
| update/au7-direct-series | Item 1. The world of `registry/ap30-update-notes`, `TALON_REGISTRY=direct`, with `json1` (acme/json 1.0.0: the list has no tag 1.0.0) and `json3` (acme/json 3.0.0: the tag has another package asset). `update json --no-check --dry-run`: the output of today plus `warning: json1: acme/json 1.0.0 has a deleted release. Fix: tln update json1.` after the closure notes; no R-AU7 line for json3 (Q622 item 5). | R-AU7 R-DI2 R-DI15 | red (only the new stderr line) |
| audit/ad12-archive-gone | Item 2, `direct`. q3: pf (cached), json 2.1.0 (not cached, download 404; the tag has another package asset). Report: the `asset-replaced` row with the new hash, the fix line, the note, exit 21. `--json`: the note kind `deps-not-checked`. | Q621 R-AU1 R-AU2 R-DI7 R-OUT2 | red (exit 15 today) |
| audit/ad13-guard-gone | Item 2, registry: the world of `ad9-guard`, gone not cached, download 404. The `repo-missing` row, the note, exit 21. | Q621 Q620 R-RG4 R-AU2 | red (exit 15 today) |
| registry/au7-frozen | Item 3. `install --frozen` with the answer of `au7-install-warnings`: `the header satisfies talon.toml`, no warning, no request, exit 0. | R-AU7 R-AU6 R-LF1 (Q622 item 1) | green |
| update/au7-direct-held-move | Q623 item 3 (Q-244d-3). `direct`, u1: pf, json (acme/json 2.0.0), json1 (acme/json 1.0.0), yaml (acme/yaml 1.0.0). `update yaml@1.1.0 --no-check --dry-run`: the first search lists acme/yaml; yaml 1.1.0 needs json 2.1.0 and json is held, so the second search frees json and lists acme/json and acme/pfx. The list of acme/json (read only by the second search) has no tag 1.0.0: `warning: json1: acme/json 1.0.0 has a deleted release. Fix: tln update json1.` after the closure notes. | R-AU7 R-SP16 R-SP24 R-DI2 | red (the code feeds only the lists of the first search) |
| verify/au7-direct | Mutation gap G3 (e9). `direct`, `verify --no-check`: verify frees every header variable, so the finding is on a transitive entry: each json 2.x header needs acme/json 1.0.0 (alias `old`), and the list has no tag 1.0.0. Expected `warning: old via json: acme/json 1.0.0 has a deleted release. Fix: tln update json (tln why acme/json@1), or use [overrides].` | R-AU7 R-CM11 | red: CODE BUG, the run prints `warning:  via json: ...` (the edge alias of a transitive entry is empty in the resolve flow) |
| update/au7-direct-offline | Mutation gap G4 (e11), Q623 item 3. The world of au7-direct-series. Run 1 keeps the pages (the json1 line). Run 2 `--offline` reads the kept pages (`fx/mtimes` fixes the `index: cached at` time): no request, no audit line. | R-AU7 R-DI12 | green |
| audit/ad14-archive-500 | Mutation gap G2 (e6), Q623 item 1. The world of ad12, the download answers 500: exit 15, `download of acme/json 2.1.0 failed: 500 (<url>). Run tln audit to see why.`, no leaf, no note. | Q623 R-FE6 R-FE10 | green |
| audit/ad15-archive-net | Mutation gap G2, a transport error (curl exit 6): exit 15, `download of acme/json 2.1.0 failed: curl: (6) Could not resolve host: github.com (<url>)`, no note. | Q623 R-FE6 R-DA7 | green |
| audit/ad16-why-404 | Mutation gap G1 (e3). The project of ad12, `why json`: the walk stops on the 404 with exit 15 and the text of today; no leaf, no note (only `tln audit` makes a leaf). | Q623 R-FE6 R-FE10 | green |

Other commands keep exit 15 on a 404: `fetch/fe-flow`, `registry/fe10-install-404` (unchanged).

### calls.log

| Case | Source |
| --- | --- |
| update/au7-direct-series | The real run of today (one `http_get` of the list of acme/json), baked: item 1 sends no extra request. |
| registry/au7-frozen | The real run, baked after a check by eye: no `http` call. |
| audit/ad12-archive-gone | The real run, baked (ruling of the manager, 2026-11-13): after the 404 the walk reads the level again without the gone package, through `Gather.facts!` and `Fetch.packages!`, so `random` and `list_dirs $HOME/.cache/roc/packages` come before the read of the pf header. Checked by eye: 2 list requests in run 1, none in run 2, one download in each run (Q-244d-4), no extra request. |
| update/au7-direct-held-move | The real run of today, baked: 3 list requests (acme/yaml in the first search; acme/json, acme/pfx in the second). The R-AU7 line adds none. |
| audit/ad13-guard-gone | Guessed: the calls of ad9-guard, with the download calls of gone (404) in place of the `read_files` of its header. The calls of today match. |

## Output (proposed, TW24)

| Item | Text |
| --- | --- |
| The note (human) | `note: not checked: the deps of <name> <version>: its archive is gone` (Q621 item 3), after the `not checked: ... no index` notes, before the R-AU4 note, in the order of the entries |
| The note (`--json`) | `data.notes[]`: `{"kind":"deps-not-checked","name":"acme/json","version":"2.1.0","hash":"..."}`, after the `not-indexed` notes |
| The R-AU7 line with `direct` | The 244c text (`resolve_line`), on stderr after the closure notes (after the R-C8 note) |

## Trickiest behaviors (for the mutation check later; not run)

| # | Behavior | Test |
| --- | --- | --- |
| 1 | Item 1 sends no request: the pages are the ones that the pick read | L2 au7-direct-series calls.log |
| 2 | No R-AU7 line for `asset-replaced` with a new hash (the R-DI15 warning is there) | L2 au7-direct-series (json3) |
| 3 | Only `tln audit` makes a leaf; a resolve keeps exit 15 | L2 registry/fe10-install-404, fetch/fe-flow |
| 4 | The leaf keeps its own finding (direct from the list; registry from the guard) | L2 ad12, ad13 |
| 5 | The deps of a leaf are not walked (no download, no read of parser and util) | L2 ad12 calls.log |
| 6 | Only a 404 makes a leaf | (Q-244d-1: no L2 case for another status yet; a mutation may find it) |

## Rulings and notes after the code (2026-11-13)

| Item | Text |
| --- | --- |
| ad12 calls.log (both runs) | The real lines are accepted: the second read of the level after the 404 (`random`, `list_dirs` of the packages dir, then the pf header). |
| Gap against Q623 item 3 | The code feeds the R-AU7 lines of `direct` only from the lists of the first search; the lists that the second search of a held move reads (`second_index!`) are not kept. New red case `update/au7-direct-held-move`. A list that both searches read cannot differ in a fake world (the second read uses the pages of the first, R-DI2: 60 s), so the case uses a repository that only the second search reads. |

## Mutation check (244d, research/slice-244d-revert/RESULT.md)

12 mutants: 8 caught, 4 not caught. Tests added (2026-11-13). Every calls.log of these cases is the real run, read by eye before it was baked: verify lists acme/json, acme/parser, acme/pfx (the pick; the warning adds no request); the offline run 2 sends no request; ad14, ad15, ad16 stop after the one download.

| Gap | Mutant | Test added |
| --- | --- | --- |
| G1 | e3: a leaf in every command | L2 audit/ad16-why-404 |
| G2 | e6: any status of a download makes a leaf | L2 audit/ad14-archive-500, audit/ad15-archive-net; L0 d2 (`Fetch.gone_url`) |
| G3 | e9: verify is not fed | L2 verify/au7-direct (red: a code bug, below) |
| G4 | e11: `--offline` prints direct warnings | L2 update/au7-direct-offline |

Code bug found by verify/au7-direct: the R-AU7 line of a transitive entry in a resolve has an empty head edge (`warning:  via json: ...`). `tln audit` gives `util ... via json` for the same kind of entry (ad1-direct), so the entries of the resolve flow lose the alias of the edge (the walk rows or links that `AuditResolve` passes to `AuditCheck.entries`). The other 244c/244d cases have no transitive finding in a resolve, so they did not show it.

The same bug in the registry path (244c): L2 `registry/au7-transitive` (u1 of di1; the record of json 2.0.0 needs util, someone/roc-util 0.3.0, withdrawn `deleted`) expects `warning: util via json: someone/roc-util 0.3.0 has a deleted release. Fix: tln update json (tln why someone/roc-util), or use [overrides].`; the run prints `warning:  via json: ...` (red). L0 (AuditcheckTest, last expect): `AuditCheck.entries` takes `edge` from the walk row (`row.alias`); a transitive row with an empty alias gives `edge` "", not the alias of the first link that names it (`util`) as `AuditTypes.Entry` says (red: `[("", ["json"])]`). The calls.log of au7-transitive is run 1 of di1 with `tty`, and the run matches it: no extra request.

Run 2026-11-13 (capped, `TMPDIR` in `.tmp/tmp`): `l0-9` 188 of 188; `audit/ update/au7 registry/au7 verify/au7` 25 of 26 (verify/au7-direct red: the bug).

## Size

About 150 lines: the `pages` field and its 4 constructors and the feed to `warn!` about 50, the leaf in the walk of `tln audit` (the 404 of `Gather`, a flag that only `AuditFlow` sets) about 60, `Report.gone` text and data about 30.

## Out of scope (244d)

A negative cache of downloads; mirrors (R-FE6, P3); the text of the R-DI15 warning of `Index.candidates`.
