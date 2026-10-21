# Applied: the 5 design-gap decisions

Status: applied to `DESIGN.md`, `DESIGN-CLI.md`, `DESIGN-RESOLUTION.md`, `DESIGN-REGISTRY.md` on 2026-10-21. Not committed. No code, test or slice file is changed.

Sources: `G-closure-fetch.md` (CF), `G-never-change.md` (NC), `G-tie-names.md` (TN), `G-held-moves.md` (HM), `G-pin-gate.md` (PG).

## 1. Overlaps

| Rule or place | Decisions | Merge |
| --- | --- | --- |
| DESIGN.md 5, rule index | CF (R-AL), NC (R-H, R-AD, R-PA), TN (R-SC), HM (R-SP), PG (R-SO) | Different rows. HM and PG gave no index edit: rows R-SP and R-SO are updated here. |
| DESIGN.md 4.4, R-WS6, R-WS8, R-WS12 | TN (R-WS8), HM (R-WS6, R-WS12) | Different rows. No text overlap. |
| DESIGN.md 7, R-PH7, R-PH10 | PG (R-PH7), HM (R-PH10) | Different rows. CF R-AL9 cites R-PH10: the second search of HM still gives one tuple, so both hold. |
| Resolution 9 | HM (R-SP16, R-SP17, new R-SP23 to R-SP26), PG (R-SP1, R-RP2) | Different rows. R-SP23 "the nightly is never movable outside `upgrade`" agrees with the new R-RP2 list of PG. |
| CLI 7.3, R-DI1 | CF (last sentence), HM (work item: fetch the index of the movable groups) | Both applied. The first sentence also gets "the group of a movable variable in the second search of a held move (R-SP24)", else R-DI1 forbids the fetch that HM needs. |
| CLI 2, R-AD22 and R-SC16 | NC (unmanaged entry with a selector: exit 2), TN (`add X@sel` of a header entry moves) | Both hold: the alias finds the entry (R-SC6), then R-H9 gives exit 2. R-SC16 says so in one sentence. |
| CLI 2, R-SC6, R-SC16 and Design R-H4 | TN (path entry: the alias is the only name, no version), NC (unmanaged = path entry or foreign URL) | R-SC16 says "an unmanaged entry (a path entry or a foreign URL)" where TN said "a path entry". |
| Resolution 9, R-SP23 and Design R-H4 | HM (movable variables), NC (an unmanaged entry is no variable) | R-SP23 adds one sentence: an unmanaged entry is never movable. |

Conflicts in substance: none. `CONFLICTS.md` is not written.

## 2. Edits per decision

| Decision | Rule ids changed | Rule ids added | Index rows |
| --- | --- | --- | --- |
| CF | R-AL2, R-FE1, R-DI7, R-DI1, CLI 7.3 cost table (new row), Registry R-AP17 row `artifacts` | R-AL8, R-AL9 | R-AL1 to R-AL9 |
| NC | R-H4, R-H7, R-AD18, R-AD19, R-AD21, R-AD22, R-AD31, R-RV5 | R-H9, R-AD38, R-PA14 | R-H1 to R-H9, R-AD1 to R-AD38, R-PA1 to R-PA14 |
| TN | R-SC1, R-SC6, R-SC14, R-SC15, R-WS8, R-AU8 | R-SC16 | R-SC1 to R-SC16 |
| HM | R-SP16, R-SP17, R-WS12, R-WS6, R-PH10, R-EC13, R-DI1 (consistency) | R-SP23, R-SP24, R-SP25, R-SP26 | R-SP1 to R-SP26 |
| PG | R-SP1, R-RP2, R-NS4, R-NS5, R-SO17, R-PH7 | R-SO19, R-SO20, R-SO21, R-SO22, and the intro paragraph before them | R-SO1 to R-SO22 |

Each new id was free before the edit (`grep -w` over the design files, `TESTING.md`, `docs/slices`, `cli`, `tests`).

## 3. Adapted edits

| Decision | Edit | How it was adapted |
| --- | --- | --- |
| CF | E2, R-AL8 and R-AL9 | Put after the step table of Resolution 5, before "Example failure output", as the file says. |
| NC | E11, R-AD38 | Put after the R-AD20 table, before the heading "What `tln add` writes to `talon.toml`". |
| NC | E14, R-PA14 | A row after R-PA8 in the patch table. |
| NC | E4, index R-H | The topic also says "unmanaged entries". |
| TN | E3, R-SC14 | The note "(The second block is the output of `tln update roc-lang/http@3`)" is a line of the design between the 2 blocks. |
| TN | E5, R-SC16 | "A path entry has no version" became "An unmanaged entry (a path entry or a foreign URL, Design 4.2, R-H4) has no version" (NC). Added the last sentence: "When the one match is an unmanaged entry, Design 4.2, R-H9 applies (exit code 2)." |
| HM | R-SP23 to R-SP26 | Put after the paragraph R-SP22, not after R-SP17: the R-SP18 to R-SP21 block is between them, and the ids stay in order. R-SP23 adds: "An unmanaged entry (Design 4.2, R-H4) is no variable, so it is never movable." (NC) |
| HM | R-DI1 (no edit in HM) | Added the movable groups to the list of R-DI1, from the HM work item "fetch the index of the movable groups". |
| HM | Index R-SP | Not in HM. Range R-SP1 to R-SP26, topic adds "held moves". |
| PG | Index R-SO | Not in PG. Range R-SO1 to R-SO22, topic adds "the held nightly". |
| PG | E7 | The intro paragraph and the table go after the R-SO17, R-SO18 table, at the end of Resolution 13. |

## 4. Open questions and the defaults in the design

| Decision | Question | Default that the design now states | Where |
| --- | --- | --- | --- |
| CF Q1 | With a registry, does `tln list` send the closure query? | No. No index call (R-DI1). | CLI 7.3, R-DI1 |
| NC Q1 | Does `--as <alias>` over an unmanaged entry ask a prompt? | No prompt. | CLI 2, R-AD38 |
| NC Q2 | Does Talon write path entries (`tln add ../util/main.roc`)? | No. Path entries are hand edits. | Design 4.2, R-H4 ("never writes a new one") |
| TN Q1 | In a command that does not move, is `X@sel` a version filter or a series filter? | A version filter (cargo). | CLI 2, R-SC16 |
| TN Q2 | Does the tie text of a moving command name `tln update <alias>@<sel>`? | Yes, with the first direct match (R-OUT2 proposal). | CLI 2, R-SC14 |
| HM Q1 | Does a moved held variable go to the nearest value that works, or the newest? | The nearest value. | Resolution 9, R-SP24 |
| PG H1 | With a pin, `ROC_TOOLCHAIN` set to another id: a note, or exit 2? | A note. The pin is held. | Resolution 13, R-SO20 |

New open items found in the merge (TW17, not decided here):

| # | Item | Why |
| --- | --- | --- |
| O1 | Registry 4.1, R-AP16 field `groups`: the second search of a held move (R-SP24) needs the releases of the movable groups. The design does not say if the client sends them in the first closure query or in a second query. | HM is written for `direct`. CF makes step 2 one request. P2 only. |
| O2 | R-H9 row 1 cites R-I5 for "a key of an unmanaged alias is no constraint". The rule that would make it a range is R-I3. | Text only. The behavior is clear. |

Found by the checks, not made by these edits: the rule ids R-AP45, R-AP46, R-AP47, R-CF1 and R-CR1 are each defined twice in the design files, and the index row R-SE says R-SE1 to R-SE15, but R-SE16 exists (DESIGN.md 8).

## 5. Follow-up work (code and tests)

The test agent writes the tests first, then the code agent (TW18). Rows that share a file are linked in the column "Shares with".

| Id | Slice | Change | Files | Rules | Shares with |
| --- | --- | --- | --- | --- | --- |
| PG1 | pin gate | `Compiler.select`: no `require` for `ROC_TOOLCHAIN`, return rank 2 and the `roc` on `PATH` apart | `cli/lib/Compiler.roc` | R-SO22 | |
| PG2 | pin gate | `Pin.decide` gets `toolchain`, `role : [Lock, Verify]`, gives `held_from`, `note`. `Pin.gate` runs only with no pin, exit 10 for `Env`, 13 for `Path` | `cli/lib/Pin.roc`, `cli/lib/Install.roc`, `cli/lib/ResolveBase.roc` (`check_pin`) | R-SO19 to R-SO21 | CF1 (ResolveBase) |
| PG3 | pin gate | `verify` probes on `held` of role `Verify` | `cli/lib/VerifyFlow.roc`, `cli/lib/Verify.roc` | R-SO21 | |
| PG4 | pin gate | Tests: L0 `pin.roc`; L2 `rs-no-compiler` (G5), new run (I1), `rs-frozen` (F1); L3 `vf1-verify` change; R-RP2 names in the outside-pin rows of `add`, `update`, `remove` | `tests/` | R-SO19 to R-SO22, R-RP2, R-NS5, R-SO17 | |
| TN1 | one name model | Entity gets `series` and `version : Try(Str, [None])`. Pick of R-SC16 with a "moves" parameter. One printer of the R-SC15 names. New tie texts. Unmanaged entries are entities with the alias as their only name and no version (R-SC6) | `cli/lib/Lookup.roc` | R-SC14 to R-SC16, R-SC6 | NC2, NC3, NC5 |
| TN2 | one name model | One shared entity builder replaces `Why.entities`, `PickFlow.entities_of` and the builder of `RemoveFlow.removal_plans!`. Notes `direct (<alias>)` | `cli/lib/Why.roc`, `cli/lib/PickFlow.roc`, `cli/lib/RemoveFlow.roc` | R-SC1, R-SC14 | CF1, NC5, HM3 (PickFlow) |
| TN3 | one name model | R-WS8 uses the R-SC14 list | `cli/lib/Vars.roc:244` | R-WS8 | HM1 (Vars) |
| TN4 | one name model | Tests: `lookup.roc`, `why.roc`, `vars.roc`, `wy1-why` stderr, new L2 run in `remove/rm1-flow` | `tests/` | R-SC14 to R-SC16, R-RV1 | |
| NC1 | unmanaged entries | `Locked.edit` op `Replace({ alias, url })`: any row, R-H3 URL, keyword kept. `Set` still refuses an unmanaged row | `cli/lib/Locked.roc` | R-H4, R-H9, R-AD38 | NC4 |
| NC2 | unmanaged entries | `Alias.choose`: `--as` on an unmanaged entry gives `Unmanaged(alias)`. Default alias stays `Taken` with the R-AD18 text | `cli/lib/Alias.roc` | R-AD18, R-AD19, R-AD38 | TN1 |
| NC3 | unmanaged entries | `Add.decide`: `Unmanaged` gives `Replace`. `decide_alias` of an unmanaged row: `Keep` with no `tln update` line, usage failure with a selector | `cli/lib/Add.roc` | R-AD21, R-AD22, R-AD31, R-AD38 | TN1, HM4 (Add) |
| NC4 | unmanaged entries | `Replace` of an unmanaged row uses the NC1 op (fixes exit 1 of `add --platform` on a path platform) | `cli/lib/InstallFlow.roc` | R-AD31, R-AD38 | HM6 (write path) |
| NC5 | unmanaged entries | The R-H4 refusal covers `Foreign` rows and names `tln add <name> --as X` (slice 009 G3) | `cli/lib/PickFlow.roc:126-128` | R-H9 | TN2, CF1, HM3 |
| NC6 | unmanaged entries | Tests: `locked.roc`, `alias.roc`, `add.roc`, `vars.roc` (key of an unmanaged alias), L3 path platform replace and `add --as` over a path entry, `up1-update-entries` foreign run. Retag "R-RV5 wins" comments to R-H4, R-H9. Doc of `Removal.roc` | `tests/`, `cli/lib/Removal.roc` | R-H4, R-H9, R-RV5 | |
| CF1 | one closure model | One need loop: `pick_loop!` and `Walk.level!` call one function that gets the facts of a list of nodes (sources 1, 3, 4). One fact type for a release and a path file | `cli/lib/PickFlow.roc:476`, `cli/lib/Walk.roc`, `cli/lib/ResolveBase.roc:251` | R-AL8, R-FE1, R-DI7 | TN2, NC5, HM3 (PickFlow), PG2 (ResolveBase) |
| CF2 | one closure model | `Pick.step` checks R-C2, R-C3 with the closure rule of `Closure` (path entries count). A closure-rule problem is a conflict of that tuple, not a `Fail` | `cli/lib/Pick.roc:59-68`, `:251` | R-AL9, R-C2, R-H7 | HM2 (Pick.step) |
| CF3 | one closure model | Tests: L0 `pickclosure` (path file names `json 2.2.0` with `strategy lowest`; two candidates, first bad), L2 `closure/cl1-flow`, `cl2-chain` calls.log, a winner in `packages/` gives no download. Slice 010 Q16 answered by R-AL9; retag `tests/unit/closure.roc` rows | `tests/`, `docs/slices/010-closure-list.md` | R-AL8, R-AL9 | |
| HM1 | held moves | `Scoped.movable`. `Vars.build` no longer stops for R-WS6 in `update` (slice 009 G2); the stop moves to `install` | `cli/lib/Vars.roc` | R-SP23, R-WS6 | TN3 |
| HM2 | held moves | `Slot.free` becomes `hold : [Free, Held, Movable]`. `step` gets `second`: order and value order of R-SP24. Pure `Pick.moves` with `why` | `cli/lib/Pick.roc` | R-SP23, R-SP24, R-SP16 | CF2 |
| HM3 | held moves | On `NoTuple` with a movable slot: fetch the index of the movable groups, run the loop with `second`. Remove the `Add.check_held` call; the R-WS12 entry is a `Movable` slot | `cli/lib/PickFlow.roc` | R-SP16, R-WS12, R-DI1 | CF1, TN2, NC5 |
| HM4 | held moves | Remove `check_held` and its text | `cli/lib/Add.roc` | R-WS12 | NC3 |
| HM5 | held moves | `Consent.move_held` gets `from`, `to`, `members` | `cli/lib/Consent.roc` | R-SP16, R-NI3 | |
| HM6 | held moves | After the ladder: `Prompt.decide` with `Consent.move_held`. Yes: write each member (R-SP25). No: exit 13. `--dry-run`: no prompt, exit 0 | `Resolve`, `cli/lib/InstallFlow.roc` | R-SP16, R-SP17, R-SP25, R-SP26, R-EC13 | NC4 |
| HM7 | held moves | Tests: L0 `Pick` second search, `Vars.scope` movable; L2 `add`, `update X@sel`, `install` consent rows, workspace write of 2 members, anchor (10), `--dry-run` (0), slice 009 G2 run. Old: `add.roc` `check_held` expect goes, `in1-workspace-frozen-rename` held run changes | `tests/` | R-SP16, R-SP17, R-SP23 to R-SP26, R-NI3, R-WS6, R-WS12 | |
| P1 | later | R-PA14 refusal (with `tln patch`), the `upgrade` row of R-H9 (with `tln upgrade`), the second search as a PubGrub decision order | | R-PA14, R-H9, R-SP24 | |
| P2 | later | Registry answer as source 2, `unknown` hash to source 4; `--frozen` and `list` make no index call with a registry; O1 | | R-AL2, R-AL8, R-AP28, R-DI1 | |

## 6. Order proposal

| Step | Slice | Why this place |
| --- | --- | --- |
| 1 | pin gate (PG1 to PG4) | Independent of the others (`Pin`, `Compiler`, `Verify`). Small. Most of R-RP2 is built already. |
| 2 | one name model (TN1 to TN4) | Gives the shared entity builder. NC needs alias-only entities for unmanaged entries, and it changes `PickFlow` before CF and HM do. |
| 3 | unmanaged entries (NC1 to NC6) | Uses the TN entities in `Lookup` and `Alias`. Changes `Add` and the write path before HM changes them. R-SP23 of HM relies on "an unmanaged entry is no variable". |
| 4 | one closure model (CF1 to CF3) | Merges the 2 loops in `PickFlow` and `Walk`, and puts the closure rule in `Pick.step`. HM then reuses the one loop. |
| 5 | held moves (HM1 to HM7) | Largest. Changes `Pick.step` again (slot holds, second search) and the write path. Builds on the CF loop and the NC `Add` changes. |
