# 252 Follow a successor with `tln update <alias>`

Phase: P2 (the registry has `repos` with `state` and `successor`, slices 119, 247). Status: done (2026-11-17). The user approved Q252-1 to Q252-10, the texts and the `outdated` proposal (Design Q632, G-C262). R-PU29 and R-PU30 client parts stay P3.
Design ids (pending, the manager writes them): Q632, G-C262. Left open by Design Q629 (14) and Q406 (the client reads nothing from `repos` before this slice).
Test agent: 2026-11-17. No product code except one stub module (section 9).

## 1. Rules

| Rule | What it says for this slice |
| --- | --- |
| R-PU28 (Registry 7.3) | `tln update` and `tln upgrade` with no names do not follow a successor: they print one note for each such entry. `tln update <alias>` and `tln upgrade <alias>` follow it: Talon replaces the entry under the same alias with a release of the successor, as for a new series (Resolution 10, R-UP3), and runs the full resolve with its checks (Resolution 5). `min-release-age` (Resolution 2, R-C7) applies to the successor release. The text is a proposal. |
| R-UP3 (Resolution 10) | A new series is a new group. Talon replaces the header entry under the same alias. It never adds a second entry. A move to a successor repository uses the same replace. |
| R-TP14, R-SN8 (Registry 7.3) | A successor is a link from an old name to another `github.com` name. It changes no URL in a header. The client follows a chain of successors up to 4 links. A cycle stops the chain, and the client prints a note. |
| R-AP32 (Registry 4) | Each answer that has releases of a `github.com` name has `repos`: `{name, state, successor, state_at, owner_changed}`. `state` is `active`, `missing` or `moved`. |
| R-AU8, R-AU14 (CLI) | The fix text and the moved line are `tln update <alias>` and `json: moved to acme/roc-json. Run: tln update json` (on since slice 249). This slice makes the command do what the text says. |
| R-AD35 (CLI 2) | The read of a new full name (R-AP1, then one closure query for its group). Q252-1 asks if the follow uses it. |
| R-C7 (Resolution 2) | `min-release-age` hides a young release. It applies to the successor release. |
| R-MV5, R-CM22 | A user follows a successor with `tln update <alias>` (the text of `tln move`, slice 251). |
| Q40, R-SE14 (Design) | "A person must name the alias to follow a move". So the name of the alias is the consent. No extra prompt (section 6, F4). |
| R-PU29, R-PU30 | Out of scope: their client part stays P3 (the user's decision). See section 8. |

## 2. Scope: where the code is today

| Fact | Where | Consequence |
| --- | --- | --- |
| The client decodes `repos` (`records` `Closure.Repo`, with `owner_changed`). Only the audit reads it: `AuditCheck.state_of` and `AuditCheck.finding` (the `successor` of a finding). The pick reads nothing from it (Design Q406). | `AuditCheck.roc`, `Closure.roc` | The pick has no successor today. New code is needed in the flow of `update`. |
| A resolve with a registry prints the R-AU14 line `json: moved to acme/roc-json. Run: tln update json` for each header entry whose release has the state `moved` (and the R-AU7 warning for the other reasons with the fix `tln update <alias>`). | `AuditResolve.roc`, `AuditReport.resolve_line` | Plain `update` and `upgrade` already print the note (R-PU28 sentence 2). It is a guard in this slice: `su1` run 1. |
| `tln update json` with a moved `json` today: exit 0, `nothing to change` (or a move inside the old group), and the same warning `Run: tln update json`. The text sends the user in a circle. | `su1` run 2 before the slice | The red state of `su1` and `su2`. |
| The pick path of every resolve command: `IndexQuery.groups(scoped)` makes the groups of the first closure query from the header (`PickFlow.prepare!`). A new full name of `add` and `install <names>` goes through `fresh_items!`: the R-AP1 read (`FullName.read!`), then the item for the closure query. | `PickFlow.roc`, `IndexQuery.roc`, `FullName.roc` | A follow has the same need: the group of the successor is known only after the first answer (the `repos` item). Q252-1. |
| `InstallPlan.replace_edit` gives the line of a replaced entry: `~ <alias>: <old> -> <name> <version>` for an entry that is not a release URL, and `~ <alias>: <from.name> <from.version> -> <to.version>` for a release URL. The second form hides a change of repository. | `InstallPlan.roc` | The report line of a follow needs the name of the new repository (section 7). `data.moved` already has `from.name` and `to.name`. |
| The facts of the old release (`known`, R-C9) stay in the domain: the header value `someone/roc-json 2.0.0` is a value of the variable. | `PickFlow.roc`, `PickIndex.roc` | A follow replaces the variable (the group changes), as a new series does (R-UP3). |
| `direct` has no `repos` (Design Q406, R-DI1): no successor is known. | `PickIndex.roc` | `tln update json` with `direct` is a normal update. No note, no follow. |
| A kept R-AP1 copy (`--offline`, R-IX6) holds `repos` too. A closure answer is never kept for `--offline`. | `ClosureIndex.offline!` | Q252-8. |

## 3. Behaviors

| # | Behavior | Rules |
| --- | --- | --- |
| B1 | `tln update <alias>` and `tln upgrade <alias>`, with a registry, when the `repos` item of the repository of the alias has a successor: the entry is replaced under the same alias by a release of the successor. The header gets the URL of that release. The alias, the order and the other entries do not change. | R-PU28, R-UP3 |
| B2 | `tln update` and `tln upgrade` with no names, or with other names, do not follow. They print the R-AU14 line, one line for each such entry. The header entry stays (a move inside the old group is as before). | R-PU28, R-AU14 |
| B3 | `min-release-age` applies to the successor release: a release of the successor that is younger than the age is not chosen. `min-release-age-exclude` applies as always (R-C15). | R-PU28, R-C7 |
| B4 | After the follow, the closure of the result has no moved release, so the R-AU14 line of that entry is not printed. | R-AU14 |
| B5 | The full resolve with its checks runs on the new tuple (the ladder, the whole-app check, `--no-check`, `--dry-run`, the prompts of the held moves), as for any `update`. | R-PU28, Resolution 5 |
| B6 | An alias whose repository has no successor, or has no `repos` item (`direct`, a host that is not `github.com`), is a normal update. No request for a successor. | R-PU28, Design Q406 |
| B7 | A successor is followed when the item has one, whatever the state of the old name (`moved`, or `missing` with a successor), because the fix text of R-AU8 is `tln update <alias>` for each reason when the name has a successor. | R-AU8, R-PU28 |
| B8 | A chain of successors is followed up to 4 links. The walk is R-SN8: it goes on while the current name is `moved`, fewer than 4 links are taken, and the next name is not yet on the walk. A cut chain and a cycle print a note (section 7). | R-TP14, R-SN8 |
| B9 | `--json`: `data.moved` has the item `{alias, from: {name, version}, to: {name, version}}` with the two names. No new field. | R-OUT3 (proposal) |

## 4. Tests

| Layer | Case | Checks | Red state |
| --- | --- | --- | --- |
| L0 | `tests/unit/SuccessorTest.roc`, in driver `l0-4.roc`: `Successor.walk`, 8 expects: A to B active; A to B missing; no link; 4 links and the fifth active; 5 links (cut, end after 4 links, `Moved`); A-B-A cycle (end B); A-B-C-A cycle (end C); names in any case | R-TP14, R-SN8, R-AP32, B8 | 8 fail: `crash "todo"` (stub) |
| L0 | same file: `Successor.decide`: no names gives `Stay`, named with a successor gives `Follow`, `missing` with a successor gives `Follow`, named with no successor gives `Stay`, no `repos` item gives `Stay` | R-PU28, R-AU8, B1, B2, B6, B7 | 5 fail: todo |
| L0 | same file: `Successor.chain_note`: the cycle text, the cut text, no note when the chain ends | R-TP14, B8 | 3 fail: todo |
| L2 | `registry/su1-update-follow`, run 1: `update` with no names: `nothing to change` and the R-AU14 line on stderr, no request for the successor | R-PU28, R-AU14, B2 | passes now (a guard) |
| L2 | same case, run 2: `update json` (u1: json on someone/roc-json 2.0.0, moved to acme/roc-json): the line `~ json: someone/roc-json 2.0.0 -> acme/roc-json 2.0.1` (2.0.2 is too young), no warning, the requests of Q252-1 (a) | R-PU28, R-UP3, R-C7, B1, B3, B4 | fails: `nothing to change`, the warning again |
| L2 | same case, run 3: `update pf`: no successor, a normal update | R-PU28, B6 | passes now (a guard) |
| L2 | `registry/su2-upgrade-follow`: `upgrade json` follows too (the successor 2.0.1, not 2.0.2) | R-PU28, R-UP13, R-C7, B1, B3 | fails: `nothing to change`, the warning |

Tests after the answers (2026-11-17):

| Layer | Case | Checks | Red state |
| --- | --- | --- | --- |
| L2 | `registry/su3-series-limit`, run 1: `update json` keeps the series of the header value: 2.0.1, not 3.0.0 | R-PU28, R-UP10, Q252-2 | fails: `nothing to change` |
| L2 | same case, run 2: `update json@3` crosses: 3.0.0, and the line `json = "^3"` for talon.toml | R-PU28, R-UP11, Q252-2, Q252-6 | fails: exit 10 (no release of the old group matches ^3) |
| L2 | same case, run 3: `upgrade json` crosses: 3.0.0, the line ends with ` new series` (the series changed, R-UP3, D8) | R-PU28, R-UP12, R-UP13, Q252-2 | fails: `nothing to change` |
| L2 | `registry/su4-named-forms`, run 1: `update json@2` follows (alias with a selector) | R-PU28, R-UP11, Q252-6 | fails: only the talon.toml line, no move |
| L2 | same case, run 2: `update someone/roc-json` (the full name) follows | R-PU28, R-SC6, Q252-6 | fails: `nothing to change` |
| L2 | `registry/su5-follow-no-release`: the successor has only a release that `min-release-age` hides. Exit 2, the text of Q252-3, no `--dry-run`: the tree.diff shows that the header is not written | R-PU28, R-C7, R-EC2, Q252-3 | fails: exit 0, `nothing to change` |
| L2 | `registry/su6-follow-cycle`: A moved to B, B moved to A. The command follows to B (R-SN8 row 5), prints the cycle note on stdout, and the R-AU14 line for the moved B on stderr | R-PU28, R-TP14, R-SN8, Q252-5 | fails: `nothing to change` |
| L2 | `registry/su7-follow-chain`: A to B to C (active), 2 links. The entry gets the release of C, no note | R-PU28, R-TP14, R-SN8, Q252-5 | fails: `nothing to change` |
| L2 | `registry/su8-platform-follow`: `update pf`, the platform moved: it follows, with the note `platform changes: someone/pfx 0.1.0 -> acme/pfx 0.1.1` | R-PU28, R-UP3, Q252-7 | fails: `nothing to change` |
| L2 | `registry/su9-follow-offline`: `update json --offline` follows from the kept R-AP1 copies (no request) | R-PU28, R-IX6, R-AD37, Q252-8 | fails: `nothing to change` |
| L2 | `registry/su10-follow-offline-missing`: the copy of the successor is missing: exit 15, `the index of acme/roc-json has no cached page and --offline is set. Run the command without --offline.` | R-PU28, R-IX6, R-AD37, Q252-8 | fails: exit 0 |
| L2 | `registry/su11-outdated-successor`: `outdated` shows the row of a moved entry, also when it is at its newest release (text proposal, section 7a); `--json` has `successor`; a project with no moved entry is unchanged (run 3, a guard) | R-PU28, R-MV5, R-CM6, Q252-9 | runs 1 and 2 fail: `all packages are up to date`, `packages: []` |
| L2 | `registry/su12-follow-second-alias`: `json2` is on the successor already. `update json` replaces the named entry only: two aliases, one group | R-PU28, R-UP3, Q252-10 | fails: `nothing to change` |

Not written (reason):

| Part | Reason |
| --- | --- |
| Q252-7, a project tool does not follow | A `[tools]` run needs the tool fixture of `ptool/pt3-move` (a source tarball, probes, a build) with a registry and a moved repository. The tool flow (`ToolFlow`) reads no `repos` today, so such a case would pass before and after unless the code agent adds a follow there. A mutant that does so is for the verify step: add a `[tools]` check to the revert list. |
| A cut chain (5 links) in a run | The L0 `walk` and `chain_note` tests give the rule (R-SN8 row 4). A run needs 5 answers; `su6` and `su7` give the cycle and the chain in a run. |
| L0 for the outdated text | The row type `Outdated.Row` has no member for a successor. A new member breaks each literal of `OutdatedTest` (TW18: the code agent cannot edit tests). The code agent adds a separate pure function (for example a list of `{alias, successor}` that `Outdated.text` and `Outdated.data` read) and keeps `Row` as it is. The L2 case `su11` checks the text. |

Why the first L2 cases were few (before the answers). `update json@sel`, a cut chain in a run, `--offline`, an end that is missing, and `outdated` waited for the answers of section 6 (TW17). They have tests now (the table above).

The `calls.log` of `su1` run 2 and of `su2` is a guess for Q252-1 (a), with the range and the series of Q252-2 (b) in the second query of `su1`. The `tree.diff` has the kept R-AP1 answer of the successor (the file name `cc762e9f...` is the one that `add acme/roc-json` makes). If the code agent finds that another request pattern is right after the answers, it writes a dispute (TW18). The fixtures serve a second closure answer (`closure.POST.2`) and the R-AP1 read, so (a) and (b) of Q252-1 both find data. The `stdout` line and the empty `stderr` are the same for every answer of Q252-1.

## 5. Facts that the design gives (no question)

| # | Fact | Source |
| --- | --- | --- |
| F1 | Following needs the name of the alias. `update` and `upgrade` with no names never follow. | R-PU28, Design Q40, R-SE14 |
| F2 | The entry stays under the same alias, and the replace is the replace of a new series. | R-PU28, R-UP3 |
| F3 | `min-release-age` applies. The full resolve with its checks runs. | R-PU28 |
| F4 | No prompt and no flag: naming the alias is the act (Design Q40: "a person must name the alias to follow a move", rejected: "an automatic follow of a move"). `--yes`, `--dry-run` and `--json` work as for any `update`. | Design Q40, R-SE14 |
| F5 | A chain has at most 4 links. A cycle stops it and prints a note. | R-TP14, R-SN8 |
| F6 | The releases of the old name keep their state. New releases come under the successor. | R-TP11 |
| F7 | The registry part (`repos`, `successor`, `owner_changed`) is built (slices 119, 247). No change in `worker/` or `records`. | Design Q626 |

## 6. Questions (answered by the user 2026-11-17: all recommendations accepted, pending Design Q632)

Answers: Q252-1 (a), Q252-2 (b), Q252-3 (a), Q252-4 (a), Q252-5 (a), Q252-6 (a), Q252-7 (a), Q252-8 (a), Q252-9 (a, `outdated` shows the successor in this slice), Q252-10 (a). The tests of section 4 follow these answers.

| Id | Question | Options | Recommendation and reason | Effect now |
| --- | --- | --- | --- | --- |
| Q252-1 | How does the client get the releases of the successor? The first closure answer has the `repos` item with the successor name. The group of the successor (the URL form of its releases) is not in that answer. | (a) As `tln add <successor>` (R-AD35 steps 1 to 5): the R-AP1 read of the successor, then a second closure query for its group. For a chain, the same for each link, at most 4. (b) A second closure query only, with the group made from the old group by a change of `owner/repo`. No R-AP1 read. (c) The Worker adds the releases of the successor to the first answer (a registry change, Registry R-AP17). | (a). Reason: the group of a repository can have another tag form (`v{v}` and `{v}`), so a made group can be wrong, and (a) is the code and the requests that `add` has (guard, cache, `--offline` copy, the 429 notes). (b) saves one request but needs a guess. (c) changes the registry. | `su1` and `su2` assume (a). Only the `calls.log` and the `tree.diff` depend on it. |
| Q252-2 | Which releases of the successor are candidates? | (a) All releases, in any series (as `tln upgrade <alias>`). (b) The series (and the range) of the header value, as `tln update <alias>` does for its own group (R-UP10); `tln update <alias>@<sel>` and `tln upgrade <alias>` cross the series (R-UP11, R-UP12). (c) The newest release, whatever the series. | (b). Reason: `update` never crosses a series without a selector (R-UP10), and the move is one change. The user who wants more writes `tln update json@latest`. The whole-app check still runs (B5). R-PU28 says "as for a new series" for the replace of the entry, not for the choice of the release. With (a) a rename that is also a major release makes `update json` break the app. | `su1` run 2 uses `range` and `series` in the second query of its `calls.log` guess. The results are equal for (a) and (b) (all releases of the fixture are in series 2). |
| Q252-3 | The successor has no release that Talon can use (state `missing` at the end of the chain, each release yanked or withdrawn, all younger than `min-release-age`, or none in the series of (b) of Q252-2). | (a) Stop with exit 2 and change nothing. The message names the successor: `json: acme/roc-json has no release that Talon can use. The header is not changed.` (a proposal, TW24). (b) Fall back to a normal update of the old group, with a note. (c) Exit 10, the failure of `Pick.step` (R-PH13). | (a). Reason: the user named the alias to follow. A fall back would print "nothing to change" again and hide the stop. R-PU29 stops in the same way (exit 2, "the message names the successor"). | No test. |
| Q252-4 | The condition. R-PU28 says "an entry whose name has a successor". R-SN8 starts a walk only at a name in the state `moved`. R-AU8 (slice 249) says `tln update <alias>` for each reason when the name has a successor, also `repo-missing`. | (a) Follow when the item has a successor, whatever its state. (b) Follow only when the state is `moved`. | (a). Reason: the fix text of `tln audit` and of the resolve warning says it for `repo-missing` with a successor (the slice 249 case `audit/au13-successor-fix`), so the command must do it. A `missing` item with a successor is rare (R-TP11 keeps the successor of a `moved` row). | One L0 `expect` (a). |
| Q252-5 | A cut chain (5 links or more) and a cycle (R-SN8): does the command change the header? | (a) Follow to the end that R-SN8 gives (the name after 4 links, or the last name before the cycle) and print the note of section 7. Those names are `moved`, so the releases there are old ones, but they are real candidates. (b) Stop with exit 2 and the note, no change. | (a). Reason: R-TP14 and R-SN8 define the end, and the Worker uses it for a short name. A user who sees the note can run `tln update` again. | The L0 `walk` and `chain_note` tests. No L2 case. |
| Q252-6 | `tln update <alias>@<sel>` and the full name (`tln update someone/roc-json`) for a moved entry. | (a) A named entry follows, in each form of R-SC1 to R-SC8 (alias, name, name with selector). The selector applies to the releases of the successor. (b) Only the bare alias follows. | (a). Reason: R-PU28 says "tln update <alias>", and `update X@sel` is the same command for the same alias (R-UP11). One rule is easier to learn than two. | No test. |
| Q252-7 | Entries that are not packages: the platform (`pf`), and a project tool (`[tools]`, R-PT5) whose repository moved. | (a) The platform follows as a package (it is a header entry; R-IN10 and the held move rules apply). A project tool does not follow in this slice. (b) Both follow. (c) Neither. | (a). Reason: R-PU28 says "each header entry". A tool is not a header entry, and its selection is R-PT4, not this search. | No test. |
| Q252-8 | `--offline` with a registry. | (a) The follow uses the kept R-AP1 copies (`Offline`, R-IX6): the copy of the old name has the `repos` item, and the copy of the successor must be there too. Without it: exit 15, `<successor> has no kept index: run again without --offline` (as R-AD37). (b) No follow offline: `update <alias> --offline` is a normal update with a note. | (a). Reason: R-IX4 and R-IX6 give offline the same pick as online with the kept data. | No test. |
| Q252-9 | `tln outdated`. R-PU28 says it shows `moved to <successor>` in the row of each header entry whose name has a successor. Design Q629 (14) names only `tln update <alias>` for this slice. | (a) In slice 252: one more cell in the table, from the same first answer, with no new request. (b) A later slice. | (a). Reason: the text is in R-PU28, the data is in the answer that `outdated` already reads, and R-MV5 says "a user sees the successor in `tln outdated`". The form is a proposal: a note line under the table, `json: moved to acme/roc-json`, and `data.rows[].successor` (a string or null). | No test (the user can choose (b)). |
| Q252-10 | Two entries (two aliases) that use the repository of the successor already, or a second alias on the old repository. | (a) The replace is done for the named alias only. A header with two aliases of one group is allowed (it is today). (b) Stop with exit 2. | (a). Reason: R-UP3 says the replace never adds an entry; it does not forbid two aliases. | No test. |

No question about the confirmation (F4), `--json` (B9: the existing field), `direct` (B6), and the R-PU30 note (out of scope).

## 7. Output (proposed, TW24)

| Case | Text | Reason |
| --- | --- | --- |
| The report line of a follow (`update` and `upgrade`) | `  ~ json: someone/roc-json 2.0.0 -> acme/roc-json 2.0.1` | The form of the line for a change of name (`InstallPlan.replace_edit`, first form with the name of the new repository). No suffix: `upgrade` prints ` new series` only for a new series (R-UP3, D8), and the two names show the move. |
| The note of a plain `update` and `upgrade` | `warning: json: moved to acme/roc-json. Run: tln update json` | The text of slice 249 (R-AU14). Not changed. |
| A cut chain (Q252-5) | `json: the successors of o/a have more than 4 links. Talon stops at o/e.` | `Successor.chain_note` (L0 test). A `note:` on stderr, as the other notes of the pick. |
| A cycle (Q252-5) | `json: the successors of o/a go in a circle. Talon stops at o/b.` | The same. |
| The stop of Q252-3 (a) | `tln: error[usage]: json: acme/roc-json has no release that Talon can use. The header is not changed.` | Exit 2. Waits for the answer. |
| `--json` | `data.moved[]`: `{"alias":"json","from":{"name":"someone/roc-json","version":"2.0.0"},"to":{"name":"acme/roc-json","version":"2.0.1"}}` | The existing field (`Report.data`). No new field. |

One run holds a warning on stderr with exit 0 (`su1` run 1): it is the R-AU14 note, not an error.

### 7a. The `outdated` text (proposal, pending user review, TW24)

Reason: R-PU28 says `tln outdated` shows `moved to <successor>` in the row of each header entry whose name has a successor (R-AP32), and R-MV5 says a user sees the successor there. The current table has the columns `package`, `current`, `wanted`, `latest`, `nightly range` and shows only a row that is behind. The data comes from the first closure answer that `outdated` already reads: no new request.

| Item | Proposal | Reason |
| --- | --- | --- |
| Which rows | A row is shown when the entry is behind (as today) or its name has a successor | An entry at its newest release in the old group is the case of a moved package: it has no newer release there, but a successor has them |
| The cell | The `latest` cell ends with ` (moved to <successor>)`, after ` (new series)` when both hold: `latest` is `2.0.0 (new series) (moved to acme/roc-json)` | The form of ` (new series)`. The columns keep their widths rule (the widest cell + 2 spaces) |
| `wanted` and `latest` | The values of the old group, as today | The releases of the old name keep their state (R-TP11). `tln update <alias>` shows what the successor gives |
| The successor shown | The `successor` member of the `repos` item (the first link), not the end of a chain | One answer, no extra request. A chain is followed by `tln update <alias>` (B8) |
| `--json` | A new member `successor` (a full name) in the item of `packages`, after `new_series`, only for a package with a successor. The other items keep their members | `data.audit_warnings` is left out when empty in the same way (Design Q622). Old cases do not change |
| `--offline` | The same, from the kept copy that holds the `repos` item | R-IX6 |
| `direct` | No successor, no change | Design Q406 |
| Example | see below | |

```text
$PROJECT/u1/main.roc
  package  current  wanted  latest                          nightly range
  json     2.0.0    2.0.0   2.0.0 (moved to acme/roc-json)  -
```

```json
{"alias":"json","name":"someone/roc-json","current":"2.0.0","wanted":"2.0.0","latest":"2.0.0","new_series":false,"successor":"acme/roc-json","nightly_range":{"state":"unread"}}
```

The other texts of 252 (the report line, the cycle and cut notes, the stop of Q252-3) are approved (section 7). One change of the table in section 7: `upgrade` into another series ends the line with ` new series` also for a follow (the series changed): the case `su3` run 3 has it. The note of a cycle is on stdout as `note: <text>` (as the other notes of the pick).

## 8. Out of scope

| Item | Why |
| --- | --- |
| R-PU29 (`tln add <owner>/<repo>` of a name with a successor) | P3 (the user's decision) |
| R-PU30 (the `owner_changed` note: `the repository was made again by the same owner on <date>`, `transferred to <owner> on <date>`) | P3 (the user's decision). The client decodes `owner_changed` and reads nothing from it. Risk: R-SE14 says Talon shows a transfer or a new repository first. A follow in 252 shows no such note, so an owner takeover is visible only in the registry (`repo_events`). The user accepted this by the order of the slices. |
| `tln move` (slice 251, R-CM22) | Its own slice. It runs after 252. |
| A project tool that moved (R-PT5) | Q252-7 |
| `tln install`, `verify`, `list`, `why`, `audit` | No pick of a new value. `audit` and the resolve warning keep their texts (slice 249). |
| A change of `worker/`, `packages/records`, `sql/` | None needed (F7) |

## 9. Files of the test agent

| File | Change |
| --- | --- |
| `tests/unit/SuccessorTest.roc` | New: 18 `expect`s |
| `tests/unit/l0-4.roc` | One line: `import SuccessorTest` |
| `tests/commands/cases/registry/su1-update-follow/` | New L2 case: 3 runs |
| `tests/commands/cases/registry/su2-upgrade-follow/` | New L2 case: 1 run |
| `tests/commands/cases/registry/su3-series-limit/` to `su14-follow-cut/` | 12 new L2 cases (section 4, second table; `su13-follow-missing`: the item is `missing` with a successor, B7; `su14-follow-cut`: a chain of 5 links, the cut note). `su9` and `su10` have `fx/mtimes`. |
| `cli/lib/Successor.roc` | New stub module: `walk`, `decide`, `chain_note` (`crash "todo"`). The code agent replaces them. |
| `cli/lib/main.roc` | One line in the module list: `Successor` (the stub must compile) |

No shared type changed. All 9 L0 drivers compile, and the old tests pass.

## 10. Red results and final state

| Run | Result | Reason |
| --- | --- | --- |
| First red state (test agent, 2026-11-17) | `l0-4`: 117 pass, 16 fail (the stubs). L2: 701 pass, 2 fail (`su1`, `su2`). After the answers: L2 701 pass, 12 fail (`su1` to `su12`; runs 1 and 3 of `su1` and run 3 of `su11` were guards) | `nothing to change` and no successor request |
| Dispute round (2026-11-17) | 5 cases fixed by the test agent: the numbered closure answers (the fake counts `closure.POST.<n>` over all runs of a case), the `su1` stderr, the `calls.log` of `su1`, `su3`, `su4`, the exit file of `su5` and `su10`. The code was right in each point. | none (the fixes are in the tests) |
| Mutation check (`research/slice-252-revert/RESULT.md`) | 13 mutants, 13 caught, after the tests `su13-follow-missing`, `su14-follow-cut` and 2 L0 expects for names in mixed case | G1, G2, W2 closed |
| Final state (2026-11-17) | `l0-4`: 135 pass, 0 fail. All L0 drivers pass. L2 (`tests/commands/run.sh`): 715 pass, 0 fail (cases `su1` to `su14`) | green |

## 11. Design text changes (for TalonRegistry, after the answers)

| Spot | Old | New |
| --- | --- | --- |
| `DESIGN-REGISTRY.md` line 703, the row `repos` states | `Slice 210 shows no `repos` state. R-PU28 to R-PU30 are P3 (client part). The client decodes `repos` and reads nothing from it before P3.` | `Slice 210 shows no `repos` state. R-PU28 (client part: `tln update <alias>` and `tln upgrade <alias>` follow a successor) is built in P2, CLI slice 252 (Design Q632). R-PU29 and R-PU30 are P3 (client part). The client decodes `repos`, and before P3 it reads the `successor` only, for R-PU28 and R-AU14, and nothing of `owner_changed`.` |
| `DESIGN-REGISTRY.md` R-PU28 (about line 1697) | `... follow it: Talon replaces the entry under the same alias with a release of the successor, as for a new series (Resolution 10, R-UP3), and runs the full resolve with its checks (Resolution 5). `min-release-age` (Resolution 2, R-C7) applies to the successor release. The text is a proposal (CLI 3, R-OUT2).` | The same, and after the second sentence: `The candidates are the releases of the successor that the command would choose for the same entry in its own group (Design Q632, Q252-2): the series of the header value for `update <alias>`, any series for `update <alias>@<sel>` and `upgrade <alias>`. A successor chain is followed up to 4 links (R-TP14); a cut chain and a cycle print a note. A successor with no usable release stops the command with exit code 2, and nothing is written.` (the exact text follows the answers of the user) |
| `DESIGN-CLI.md` R-UP3 note, R-MV5, R-CM22 | `A user sees the successor in `tln outdated`, and follows it with `tln update <alias>` (Registry R-PU28).` | The same, with the phase mark `P2` for the follow and, for `outdated`, the answer of Q252-9. |
| `DESIGN-RESOLUTION.md` R-UP3 | `A move to a successor repository (Registry 7.3, R-PU28) uses the same replace.` | The same, and: `The candidates of the successor are chosen by Registry R-PU28 (Design Q632).` |
| `DESIGN-CLI.md` R-CM6 (`tln outdated`) and the output catalog | The table has the columns `package`, `current`, `wanted`, `latest`, `nightly range`; a row is shown when the entry is behind | The same, and: `A row is also shown for a header entry whose name has a successor (Registry R-PU28, R-AP32). Its `latest` cell ends with ` (moved to <successor>)`. With `--json` the item has the member `successor` (a proposal, section 7a of docs/slices/252-successor-follow.md, R-OUT2).` |
| `DESIGN-CLI.md` R-UP3 (CLI, update of the platform) and R-IN10 | none | A platform entry follows a successor as a package does (Design Q632, Q252-7). A project tool (`[tools]`, R-PT5) does not follow in P2. |
| `DESIGN-REGISTRY.md` R-PU28, second addition | (see the row above) | `With --offline, the follow uses the kept R-AP1 copies of the old and the new name (CLI R-IX6); a missing copy of the successor is exit code 15 (R-AD37).` |
| `DESIGN.md`, Q406 row | `... The client decodes `repos` and reads nothing from it in P2 (decided 2026-11-03, Registry R-AP30).` | The same, and: `R-PU28 is built in P2 by CLI slice 252 (Design Q632).` |
| `DESIGN.md` Q629 row, item (14) | `(14) The client part of Registry R-PU28 (`tln update <alias>` follows a successor) is its own CLI slice 252 (Design Q632, G-C262).` | The same (no change). |
| `DESIGN.md`, a new row | none | `Q632 | G-C262: the client part of R-PU28 (CLI slice 252)? | Decided by the user, <date> (reasons in docs/slices/252-successor-follow.md, Q252-1 to Q252-10): ...` |

## 12. Plan row (for `docs/slices/PLAN-P2-CLI.md`, the manager adds it)

| 252 | Follow a successor with `tln update <alias>` | Tests for R-PU28, R-UP3, R-TP14, R-SN8, R-C7. The pure module `Successor` (`walk`, `decide`, `chain_note`), the read of the successor release (Q252-1), the replace of the entry under the same alias, the report line with both names, and the stop of Q252-3. | R-PU28, R-UP3, R-TP14, R-SN8, R-AU8, R-AU14, R-C7 | G-C262 (Design Q632) | none / none | 60 | Sonnet |
