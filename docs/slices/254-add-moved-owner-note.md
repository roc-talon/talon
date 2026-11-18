# 254 `tln add` of a moved name, and the owner change note

Phase: P2 (the user ordered the client parts of R-PU29 and R-PU30 now, as Design Q632 did for R-PU28). Status: tests (phase 2). The user approved all recommended answers Q254-1 to Q254-14 and the texts T1 to T9 on 2026-11-18 (Design Q634).
Design ids (confirmed by TalonRegistry): slice 254, Design Q634, G-C264. Left open by Design Q632 (9) ("R-PU30 stays P3 on the client ... a known gap against R-SE14") and `docs/slices/PLAN-P2-CLI.md` line 47 (R-PU29, R-PU30 are P3).
Scope agent: 2026-11-18. Test agent: 2026-11-18 (section 12). No product code except one stub module.

## 1. Rules

| Rule | What it says for this slice |
| --- | --- |
| R-PU29 (Registry 7.3) | `tln add <owner>/<repo>` of a name with a successor does not follow it. When the old name has a candidate, Talon adds it and prints the note of R-PU28. When it has none (state `missing`, or each release withdrawn), Talon stops with exit code 2, and the message names the successor. A short name gives the successor already (R-AP33). |
| R-PU30 (Registry 7.3) | When the `repos` row of a header entry had a `transfer` or `recreate` event (R-TP13) after the release of the header value, `tln update` and `tln outdated` print one note: `json: the repository was made again by the same owner on <date>`, or `transferred to <owner> on <date>`. Reason: R-SE14. The data: the member `owner_changed` of a `repos` item: `null`, or `{"action": "transfer" \| "recreate", "at": <ms>}` of the LAST such event (Design Q626 (12)). |
| R-PU28 (Registry 7.3) | The note of R-PU29: `json: moved to acme/roc-json. Run: tln update json`. Slice 249 prints it as `warning:` on stderr (`AuditResolve.warn!`, R-AU14). |
| R-AP32 (Registry 4) | Each answer that has releases of a `github.com` name (R-AP1, R-AP2, R-AP13, R-AP14, R-AP17) has `repos`: `{name, state, successor, state_at, owner_changed}`. |
| R-AP33 (Registry 4) | A short name gives the end of the successor chain (`matched "json": acme/roc-json (moved from olduser/roc-json)`). So R-PU29 is for a full name only. No change in this slice. |
| R-TP9, R-TP13, R-TP18, Design Q381 | `transfer`: the same `repository_id`, another owner id. `recreate`: the same owner id, another `repository_id`. A transfer that also changes the full name gives the claimed row `transfer`, then `moved` with a successor (Q381). |
| R-AP50 | Each time on the wire is ms since 1970-01-01 UTC. `published_at` of a GitHub release is a multiple of 1000. |
| R-AD35 step 2, Design Q630 (3) (slice 250) | A name with releases, no selector, and each release yanked or withdrawn: exit 2 before the closure query (`PickFlow.each_yanked_check`, text `FullName.each_yanked`). R-PU29 changes the text of this stop for a name with a successor. |
| R-SE14 (Design 8) | "Talon shows a transfer or a new repository first (R-PU30)". This slice closes the gap of Design Q632 (9). |
| R-FL4, R-J2 (CLI) | `--quiet` hides notes. Warnings stay. Q254-4. |
| R-OUT1 to R-OUT5, TW24 | The texts and `--json` fields of section 7 are proposals. |

## 2. Scope: where the code is today

| Fact | Where | Consequence |
| --- | --- | --- |
| The client decodes `owner_changed` (`Closure.Repo.owner_changed : Try(Closure.OwnerChanged, [None])`, `OwnerChanged : { action : [Transfer, Recreate], at : U64 }`). No CLI module reads it (grep `owner_changed` in `cli/lib`: no hit). | `packages/records/Closure.roc` lines 35 to 72 | R-PU30 needs no change in `records` or `worker/` (Design Q626, registry deployed since 2026-11-15). |
| The Worker gives the newest `transfer`/`recreate` event only (`worker/sql/closure/repos.sql`: `ORDER BY e.seq DESC LIMIT 1`). Prod has no repo with such an event yet. Non-null shapes: `worker/tests/cases/move/pu30-*` (`{"action":"recreate","at":1767200000000}`, `{"action":"transfer","at":1767100000000}`). | registry | The client compares `at` with the release time itself (Q254-1). |
| A release row of an answer has `published_at` (ms, R-AP50), `hash` and `repo` (lower-case name). The first closure answer holds the release of each header value (`hashes`, R-AP63). | `packages/records/Release.roc`, `ClosureRequest` | The time of the header value is in the answer: no new request. |
| `Fail.Ran` (the run record of `ShareHook`) has `answers : List(Wire.Answer)` and `headers : List({ hash, kind, names })`. `IndexNotes` (R-AP30) is a pure function over `answers` that `ShareHook.notes` and `ShareHook.with_index_notes` use in `update`, `upgrade`, `outdated`, `add`. | `Fail.roc` line 35, `IndexNotes.roc`, `ShareHook.roc` | A pure `OwnerNote` module over the answers and the header entries fits the same place. |
| `AuditResolve.warn!` prints the R-AU14 line (`warning: <alias>: moved to <successor>. Run: tln update <alias>`) for each header entry whose release is `moved`, after each resolve with a closure answer (`InstallFlow.finish!`: `add`, `install`, `update`, `upgrade`; also `verify`). Not `--offline`, not `--frozen`, not `direct`. | `AuditResolve.roc`, `AuditCheck.resolve_findings` | The first half of R-PU29 (a candidate: add it and print the note) is very probably on already for an online `add`. `sa1` is a guard (section 4). |
| `PickFlow.fresh_items!` reads each new full name of `add` and `install <names>` (`FullName.read_via!`, R-AP1), then `each_yanked_check` (exit 2, `<name> has no release that Talon can use: each release is yanked.`), then `FullName.closure_item` (a selector with no match: `Add.no_release`). The R-AP1 answer has the `repos` item of the name. | `PickFlow.roc` lines 199 to 271, `FullName.roc` | The second half of R-PU29 is a change of these texts only: the successor is in `releases.repos` of the same answer. |
| A name in the state `missing` has each release `withdrawn` = `repo-missing` (R-PU24). So `missing` reaches `each_yanked_check` too. | Registry R-TP11, R-PU24 | One stop for both reasons of R-PU29. |
| An R-AP1 404 (a name with no indexed release, for example a moved name made by `tln move` with no release, Design Q626 (6)) has no `repos` item. The client goes to GitHub and ingests (R-AD35 steps 3 to 8). | `FullName.read_via!` | No successor is known there. Out of scope (section 8). |
| `tln outdated`: `OutdatedFlow.report!` reads `repos` of the first answer (or the kept copies with `--offline`) for `Outdated.moved_names` (slice 252). The table text is `Outdated.text_moved`, `--json` is `Outdated.data_moved`, the index notes come after the table (`note:` lines, `--quiet` hides them). | `OutdatedFlow.roc` lines 52 to 135, `Outdated.roc` | The owner note uses the same `repos` list. |
| There is no function that writes a date (`YYYY-MM-DD`) in `cli/lib`. | grep | A new pure function (`OwnerNote.date_text`). |
| `direct` has no `repos` (Design Q406). | `PickIndex.roc` | No note and no change of text with `direct`. |

## 3. Behaviors

| # | Behavior | Rules |
| --- | --- | --- |
| B1 | `tln add <owner>/<repo>`, the R-AP1 item has a successor, the name has a candidate: the entry is added with the release of the OLD name (no follow), and the R-PU28 line is printed for the new alias. | R-PU29, R-PU28, R-AU14 |
| B2 | `tln add <owner>/<repo>`, the item has a successor, and each release is yanked or withdrawn (this includes the state `missing`): exit 2, nothing is written, and the message names the successor. | R-PU29, R-AD35 step 2, Q630 (3) |
| B3 | B2 with no successor: the text of slice 250 (no change). | Q630 (3) |
| B4 | `tln add <short>` is not changed (R-AP33 gives the successor). | R-AP33 |
| B5 | `tln update` (all forms) and `tln outdated`: for each header entry whose `repos` item has `owner_changed` with `at` after the time of the release of the header value, one owner note. | R-PU30, R-SE14 |
| B6 | No note: `owner_changed` is `null`; `at` is not after the release time; the entry has no `repos` item (`direct`, a host that is not `github.com`, a path or a foreign URL). | R-PU30, Q406 |
| B7 | The note does not change the exit code, the pick, or the files. | R-PU30 ("print one note") |
| B8 | `recreate` gives `the repository was made again by the same owner on <date>`. `transfer` gives `transferred to <owner> on <date>`. | R-PU30 |
| B9 | Only header entries (the packages and the platform of a header). A dependency of a package and a project tool (`[tools]`) get no note (Design Q632 (6): a tool is not a header entry). | R-PU30 |

## 4. Tests (plan; written in phase 2, after the answers)

### 4.1 L0 (pure): `tests/unit/OwnerNoteTest.roc`, new pure module `cli/lib/OwnerNote.roc` (stub with `crash "todo"`)

| Function (proposal) | Expects | Rules |
| --- | --- | --- |
| `OwnerNote.date_text : U64 -> Str` (ms to `YYYY-MM-DD`, UTC) | `0` is `1970-01-01`; `1767200000000` is `2025-12-31` (16:53 UTC, so a local time zone of UTC+8 or more would give 2026-01-01: the UTC rule is tested); `1767225600000` is `2026-01-01`; `1709164800000` is `2024-02-29` (leap day); `951868800000` is `2000-03-01` (after the 400-year leap day); `1767225599999` is `2025-12-31` (rounds down) | Q254-proposal T3 |
| `OwnerNote.find : { entries : List({ alias : Str, name : Str, hash : Str }), repos : List(Wire.Repo), releases : List(WireRelease.Row) } -> List(OwnerNote.Note)` | recreate after the release: one note; transfer after: one note; event before: none; event at the same ms: none (Q254-1); `null`: none; no item for the name: none; names in mixed case match; the hash is not in `releases` (Q254-2); two aliases of one repository (Q254-8); the same alias in 2 members, the same value: one note (Q254-8); a header value of another repo with an event: only that one | R-PU30, B5, B6 |
| `OwnerNote.text : OwnerNote.Note -> Str` | the recreate text; the transfer text with the owner of the successor; the transfer text with no successor (Q254-3) | R-PU30, B8 |
| `OwnerNote.doc : OwnerNote.Note -> JsonDoc` | the `--json` item of section 7 | R-OUT2 |
| `FullName.each_yanked_moved : { name : Str, successor : Str } -> Fail` (or a new optional member of `each_yanked`; the code agent chooses, the L2 text is the test) | the text of section 7 row 1, kind `Usage` | R-PU29, B2 |

### 4.2 L2 (`tests/commands/cases/registry/`)

| Case | Runs | Checks | Red state (expected) |
| --- | --- | --- | --- |
| `sa1-add-moved` | `add someone/roc-json` (moved to acme/roc-json, 2.0.0 active): the entry gets someone/roc-json 2.0.0, and stderr has `warning: json: moved to acme/roc-json. Run: tln update json`; run 2 `--json` | R-PU29, R-PU28, B1 | probably passes now (a guard). The test agent checks; if it fails, it is red for the right reason |
| `sa2-add-moved-withdrawn` | `add someone/roc-json`, each release withdrawn (`repo-missing`), the item `moved` with a successor: exit 2, the text of section 7 row 1, no write (tree.diff) | R-PU29, B2 | fails: the text has no successor |
| `sa3-add-missing-successor` | the item `missing` with a successor (B7 of slice 252): the same stop | R-PU29, B2 | fails: the text |
| `sa4-add-yanked-no-successor` | each release yanked, no successor: the slice 250 text (a guard) | B3 | passes now |
| `sa5-add-selector-moved` | `add someone/roc-json@2.0.0`, 2.0.0 withdrawn, a successor: per Q254-12 | R-PU29 | per answer |
| `sa6-add-offline` | `add someone/roc-json --offline` from the kept copy: per Q254-13 (the stop with the successor; the note) | R-PU29, R-IX6 | per answer |
| `sa7-install-names-moved` | `install someone/roc-json` with each release withdrawn: per Q254-14 | R-PU29 | per answer |
| `oc1-update-recreate` | run 1 `update` (no names): `json` on someone/roc-json 2.0.0 (published 2025-06-01), item `active`, `owner_changed` recreate at 2025-12-31: the owner line; run 2 `--json`: `data.owner_changes`; run 3 `--quiet` (Q254-4) | R-PU30, B5, B8 | fails: no line |
| `oc2-update-transfer` | `json`'s item `moved` to acme/roc-json with a transfer event after the release: the R-AU14 line and the transfer line `transferred to acme on ...` | R-PU30, Q254-3 | fails |
| `oc3-event-before` | the event is before the release: no line (a guard) | R-PU30, B6 | passes now |
| `oc4-outdated` | `outdated`: the line after the table, also for an entry that is not behind; run 2 `--json`; run 3 a project with no event (a guard: no change) | R-PU30, B5 | runs 1, 2 fail |
| `oc5-upgrade` | `upgrade json` (the named form: a plain `upgrade --no-check` stops with exit 2 because it moves the nightly): the line is printed | R-PU30, Q254-5 | fails: no line |
| `oc6-update-named` | `update json` that takes 2.0.1 (published after the event): the line is printed (Q254-7) | R-PU30 | fails |
| `oc7-offline` | `update --offline` and `outdated --offline` with kept copies that have the event: per Q254-6 | R-PU30, R-IX6 | per answer |
| `oc8-two-aliases` | `json` and `json2` on the same repo: per Q254-8 | R-PU30 | fails |
| `oc9-platform` | the platform repo was recreated: one line for the platform alias | R-PU30, B9 | fails |
| `oc10-install-no-note` | `install` with the event of oc1: no line (Q254-5 (a), a guard) | R-PU30, Q254-5 | passes now |

Fixture times: `published_at` and `at` in the fixtures are fixed ms values; `now` comes from `fx` (TW15). The `--json` cases use the field names of section 7 (a proposal).

## 5. Facts that the design gives (no question)

| # | Fact | Source |
| --- | --- | --- |
| F1 | `tln add <owner>/<repo>` never follows a successor. | R-PU29 |
| F2 | A short name is not changed (R-AP33 gives the end of the chain). | R-PU29, R-AP33 |
| F3 | The stop of R-PU29 is exit 2, and nothing is written. | R-PU29 |
| F4 | The data of R-PU30 is `owner_changed` of the `repos` item, the LAST `transfer`/`recreate` event. No registry change. | R-PU30, Design Q626 (12) |
| F5 | The note does not stop the command and needs no consent. | R-PU30 ("print one note") |
| F6 | `direct` has no `repos`: no note, no change of text. | Design Q406 |
| F7 | Only header entries. Not a dependency of a package, not a `[tools]` key. | R-PU30 ("a header entry"), Design Q632 (6) |
| F8 | No change in `worker/`, `packages/records`, `sql/`. | Design Q626, TalonRegistry 2026-11-18 |

## 6. Questions (decided by the user 2026-11-18: all recommendations accepted, Design Q634)

Answers: Q254-1 (a), Q254-2 (a), Q254-3 (a), Q254-4 (a), Q254-5 (a), Q254-6 (a), Q254-7 (a), Q254-8 (a), Q254-9 (a), Q254-10 (a), Q254-11 (a), Q254-12 (a), Q254-13 (a), Q254-14 (a). The texts T1 to T9 of section 7 are approved.

| Id | Question | Options | Recommendation and reason |
| --- | --- | --- | --- |
| Q254-1 | "After the release of the header value": which time of the release does the client compare with `at`? | (a) `published_at` of the release row in the answer (the GitHub time, R-AP50), note when `at > published_at` (the same ms: no note). (b) The time of the log leaf (when the registry took the label): not in any answer, so it needs a registry change. (c) `at >= published_at`. | (a). Reason: the value is in the first answer already (R-AP63 keeps the header value), and GitHub sets it, so a new owner cannot make it older. Both are ms (R-AP50). The same ms is not "after". |
| Q254-2 | The header value is not in the answer (an unknown release, R-C9 / `unknown`), so it has no `published_at`, but the item of its repository has `owner_changed`. | (a) Print the note (it cannot be shown that the event was before). (b) No note. | (a). Reason: R-SE14 wants the change shown first; the note states a true fact of the repository. A value that the registry does not know is already rare. |
| Q254-3 | `transferred to <owner>`: `owner_changed` has no owner. Where does `<owner>` come from? | (a) The owner part of the `successor` of the item when it has one (a transfer that changes the full name makes the row `moved`, Q381); with no successor: `transferred to another GitHub account on <date>`. (b) A registry change: `owner_changed` gets the new login. (c) Always `transferred to another GitHub account on <date>`. | (a). Reason: no registry change, and the usual transfer has the successor (the R-AU14 line names it too). The row with no successor is the case where a new account has the old login: "another GitHub account" is the true and the safe text there. (b) is better data but is a registry slice. |
| Q254-4 | Prefix, stream and `--quiet`. R-PU30 says "note", but R-PU28 also says "note" and slice 249 prints that as `warning:` on stderr. | (a) `warning: <text>` on stderr, `--quiet` keeps it (R-FL4), as the R-AU14 line. (b) `note: <text>` on stdout with the rules of R-AP30 (after the other notes, `--quiet` hides it). | (a). Reason: R-SE14 is a security row, and a user with `--quiet` in a script must still see an owner change. The same form as the R-PU28 line next to it. |
| Q254-5 | Which commands print it? R-PU30 names `tln update` and `tln outdated`. R-PU28 names `upgrade` too. | (a) `update` (all forms), `upgrade` (all forms), `outdated`. (b) Only `update` and `outdated`. (c) (a) and also `install`, `add`, `verify`, `audit`. | (a). Reason: `upgrade` is the update across series (R-UP12), and it can take a new release from the new owner too. `install` and `verify` take no new value; `audit` shows findings of releases, not repository events (it could come later). |
| Q254-6 | `--offline`: the kept R-AP1 copies have `repos` with `owner_changed` and the releases. | (a) No note with `--offline` (as the R-AU7/R-AU14 lines, `AuditResolve.warn!`: "Not `--offline`"). (b) The note from the kept copies. | (a). Reason: the same rule as the other repository warnings of a resolve, and a kept copy can be old. `outdated --offline` reads the kept `repos` for the successor cell (slice 252), so (b) is also cheap for `outdated` only; the user can choose (b). |
| Q254-7 | Which header value is compared: the value before the command, or the value that the command writes? | (a) The value before the command (the one the user has). The note is printed also when the command moves to a release published after the event. (b) The value after the command. | (a). Reason: the rule's reason is "a person can see an owner change before an update takes a new release". With (b), the update that takes the first release of the new owner prints nothing, and that is the case to show. |
| Q254-8 | How many notes? Two aliases on one repository (allowed, Q252-10); one alias in several members of a workspace. | (a) One note for each (alias, name) pair, once in a run, sorted by alias (bytes). (b) One note for each repository, with the first alias. | (a). Reason: "one note" for each header entry, and the text starts with the alias. A workspace repeats the same entry, so one line for each pair. |
| Q254-9 | Is the note printed after a failure of the command (for example exit 10, no solution)? R-AP30 index notes are printed also after an error. | (a) Only when the command reaches its report (the place of `AuditResolve.warn!`). (b) Also after an error, as R-AP30. | (a). Reason: one place in the code with the R-AU lines; the error is the main message then. (b) shows it more often; the user can choose it. |
| Q254-10 | `tln update <alias>` that follows a successor (slice 252): also check the `owner_changed` of the successor row? | (a) No: the row of the name of the header value only (the rule says "the repos row of a header entry"). (b) Also each row of the chain. | (a). Reason: the release of the successor is new to this project, so "after the release of the header value" has no meaning for it, and the follow already prints the change of name. |
| Q254-11 | R-PU29: which successor does the exit-2 message name? | (a) The `successor` member of the item (the first link): no extra read. (b) The end of the chain (R-SN8), with an R-AP1 read of each link. | (a). Reason: the R-AP1 answer has one `repos` item only (the name itself). The user's next `tln add <successor>` or `tln add <short>` gets the rest. The same choice as the `outdated` cell (Q252-9). |
| Q254-12 | R-PU29 with a selector (`tln add someone/roc-json@2.0.0`, the release yanked or withdrawn; `Add.no_release`, Design Q430). | (a) The same sentence about the successor is added to the text of `Add.no_release` when the item has a successor. (b) No change: R-PU29 is for the plain name. | (a). Reason: the same person needs the same hint; the item is in the same answer. |
| Q254-13 | R-PU29 with `--offline` (the kept R-AP1 copy, R-IX6). | (a) The exit-2 stop names the successor (from the kept copy). The R-PU28 note is not printed (as `AuditResolve.warn!`, Q254-6). (b) Both from the kept copy. (c) Neither. | (a). Reason: the stop text uses the answer that `add` reads anyway; the note follows the rule of the other resolve warnings. |
| Q254-14 | R-PU29 for `tln install <names>` (the same code path, `PickFlow.fresh_items!`). | (a) The same behavior as `add`. (b) `add` only. | (a). Reason: one code path, and `install <names>` adds entries as `add` does (Q252 said only that it does not follow). |

The date form (UTC `YYYY-MM-DD`) and the `--json` fields are proposals (TW24, section 7), not questions.

## 7. Output (approved 2026-11-18, Design Q634)

| # | Case | Human text | `--json` |
| --- | --- | --- | --- |
| T1 | R-PU29 stop, each release yanked or withdrawn (also `missing`), with a successor | `tln: error[usage]: someone/roc-json has no release that Talon can use: each release is yanked or withdrawn. Its successor is acme/roc-json. Run: tln add acme/roc-json` (exit 2) | the error object of R-J3 with this `message`, kind `usage` |
| T2 | R-PU29 stop with a selector (Q254-12 (a)) | the text of `Add.no_release`, then ` Its successor is acme/roc-json. Run: tln add acme/roc-json` | the same `message` |
| T3 | The date | `YYYY-MM-DD` of `at` in UTC (ms rounded down to the day) | `at` as ms (R-AP50) |
| T4 | R-PU30 recreate | `warning: json: the repository was made again by the same owner on 2025-12-31` (stderr, Q254-4 (a)) | `data.owner_changes[]`: `{"alias":"json","name":"someone/roc-json","action":"recreate","at":1767200000000,"owner":null,"text":"json: the repository was made again by the same owner on 2025-12-31"}` |
| T5 | R-PU30 transfer, the item has a successor | `warning: json: transferred to acme on 2025-12-30` | the same item, `"action":"transfer"`, `"owner":"acme"` |
| T6 | R-PU30 transfer, no successor (Q254-3 (a)) | `warning: json: transferred to another GitHub account on 2025-12-30` | `"owner":null` |
| T7 | The `--json` member | | `data.owner_changes` is the last member of `data` before `index_notes` (`update`, `upgrade`: after `audit_warnings`; `outdated`: after `members`). It is left out when the list is empty, so no existing output changes (the rule of `index_notes`, R-AP30). Its texts are not in `data.notes` (as `audit_warnings`). |
| T8 | Order on stderr | The owner lines come after the R-AU7/R-AU14 lines of the same run, sorted by alias (bytes) | |
| T9 | R-PU29 with a candidate (B1) | `warning: json: moved to acme/roc-json. Run: tln update json` (the R-AU14 line, no change) | the `audit_warnings` item of slice 249 (no change) |

## 8. Out of scope

| Item | Why |
| --- | --- |
| A moved name with no indexed release (R-AP1 404) | No `repos` item, so no successor is known. The client ingests from GitHub as for any new name (R-AD35 steps 3 to 8). A registry change could give `repos` in the 404 body; not asked. |
| `tln audit` showing an owner change | Not in R-PU30 (Q254-5). |
| An owner note for a dependency of a package or a `[tools]` key | F7. |
| A note for each older event | The Worker gives the last event only (F4). |
| `worker/`, `packages/records`, `sql/` | F8. |

## 9. Files of the test agent (phase 2, plan)

| File | Change |
| --- | --- |
| `tests/unit/OwnerNoteTest.roc` | New: the expects of 4.1 |
| `tests/unit/l0-5.roc` | One line: `import OwnerNoteTest` |
| `cli/lib/OwnerNote.roc` | New stub module (`date_text`, `find`, `text`, `doc`: `crash "todo"`) |
| `cli/lib/main.roc` | One line in the module list: `OwnerNote` |
| `tests/commands/cases/registry/sa1-*` to `sa7-*`, `oc1-*` to `oc10-*` | 17 new L2 cases (4.2) |

## 12. Red state (test agent, 2026-11-18)

| Run | Result | Reason |
| --- | --- | --- |
| L0 `tests/unit/l0-5.roc` | 135 tests: 110 pass, 25 fail (the 25 expects of `OwnerNoteTest`, each `crash "todo"`) | the stub |
| L2 `tests/commands/run.sh` (all) | 736 pass, 12 fail: `oc1`, `oc2`, `oc4`, `oc5`, `oc6`, `oc8`, `oc9`, `sa2`, `sa3`, `sa5`, `sa6`, `sa7`. Each fails on stdout/stderr only (no owner line, no `owner_changes`, the stop text with no successor) | red for the right reason |
| Guards | `oc3`, `oc7`, `oc10`, `sa1`, `sa4` pass now | B1 is on since slice 249 (`AuditResolve.warn!` in `add`) |
| `roc fmt --check` | the new and changed Roc files are valid | |

Notes for the code agent and the review:

| # | Note |
| --- | --- |
| N1 | The `calls.log` and `tree.diff` of the 17 cases are the calls of the code before the slice. The slice adds no request and no write (the note reads the answers that the run has; the R-PU29 stop is at the same step). The `stdout` and `stderr` files have the approved texts T1 to T9, written by hand. |
| N2 | T1 says `each release is yanked or withdrawn` for a name with a successor. The text of slice 250 for a name with no successor stays `each release is yanked.` (`sa4`, `yf5c`). The two texts are different for the same condition. This is what the user approved; the review can make them equal. |
| N3 | No `direct` guard case: `direct` has no `repos` item (Design Q406), so it cannot have the data. The L0 expect "no `repos` item" covers it. |
| N5 | Review (TW12, 2026-11-18): new case `oc11-failed-no-note`. `update json` (with the check) takes 2.0.1, and the whole-app check finds a new error in main.roc: exit 11. Q254-9 (a) says no owner line after a failed command. The first code prints the line at the step of `AuditResolve.warn!` (before the ladder), so `oc11` is red against it (2 extra warning lines on stderr, in the plain and the `--json` run). Mutation check: `research/slice-254-revert/RESULT.md` (14 mutants: 12 killed, m7 killed after one new L0 expect (a recreate with a successor has no owner; `OwnerNoteTest` has 26 expects now, l0-5 136/136 with the code), m8 equivalent). |
| N4 | With `--json` the warnings are also on stderr (R-J2), as the R-AU14 line of slice 249. The cases expect the owner line on stderr in the `--json` runs. |

## 10. Design text changes (for TalonRegistry, after the answers)

| Spot | Change |
| --- | --- |
| `DESIGN-REGISTRY.md` line 703 (`repos` states) | R-PU29 and R-PU30 (client part) are built in P2, CLI slice 254 (Design Q634). The client reads `owner_changed`. |
| `DESIGN-REGISTRY.md` R-PU29, R-PU30 | The details of the answers (Q254-1 to Q254-14), as Q632 did for R-PU28. |
| `DESIGN-REGISTRY.md` R-PU28 (9) | Remove "R-PU30 stays P3 on the client ... (a known gap against R-SE14)". |
| `DESIGN.md` R-SE14 | No change of text. |
| `DESIGN.md` new row | `Q634 \| G-C264: the client parts of R-PU29 and R-PU30 (CLI slice 254)? \| Decided by the user, <date> ...` |
| `docs/slices/PLAN-P2-CLI.md` line 47 | Remove R-PU29 and R-PU30 from the P3 row; add the row of slice 254. |

## 11. Plan row (for `docs/slices/PLAN-P2-CLI.md`, the manager adds it)

| 254 | `tln add` of a moved name, and the owner change note | The pure module `OwnerNote` (`date_text`, `find`, `text`, `doc`), the R-PU29 stop text with the successor, the R-PU30 line in `update`, `upgrade`, `outdated` | R-PU29, R-PU30, R-SE14, R-AP32 | G-C264 (Design Q634) | 252 / 247b | 150 | Sonnet |
