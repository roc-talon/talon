# 243 channel use, upgrade, update and GC

Phase: P2. Status: done (2026-11-12). Design Q612 (G-C242), Q615 item 6, Q616, Q617 item 8, Q619 (G-C249). The user accepted the tests and the TW24 texts on 2026-11-12, and the 4 `tln upgrade roc` outputs for a user pin (the skip note, `nothing to change`, the two `--json` shapes) with the commit approval. The user decided that `tln upgrade roc` on a user pin is in this slice (2026-11-12). Mutations: 21 of 21 non-equivalent caught, 1 equivalent (research/slice-243-revert/RESULT.md). Close run: check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only).

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CH14 | `tln roc use <id or ref>` on a user channel writes `[toolchain] roc = "=<id>"` and the `[channels.<name>]` table into the root `talon.toml`, and removes the header `roc:` entries. R-U2 to R-U6 apply. Back to `nightly`: header pin, and removes the `roc` key and an unused `[channels]` table. |
| R-CH15 | `tln upgrade roc` moves a user-channel pin to the newest build of that channel. `tln roc update [<name>]` installs the newest build of `<name>`; no name: the channel of `default-roc`, else as today. R-RU2 and R-RR1 move the default only inside that channel. `tln init`, `tln setup` and R-SO14 never pick a user channel. An install of a user build never sets the default. |
| R-CH16 | A user-channel build is local only (no registry row, no leaf, no bot, not shared). Tested in slice 241 (`ChannelrangeTest`, guard). Slice 243 adds no share path: `RocUse`, `RocManage` and `Gc` do not call `ShareHook`. |
| R-CH17 | Older `tln`: `[channels]` is an unknown key, `=reify-...` is exit 19, a `reify-*` dir is an unknown form. No format bump. GC treats a user-channel build as a nightly. |
| R-U1 to R-U6 | The rules of `roc use`: the ref, the download consent, the baseline check and the final ladder, `--no-check` is an error, the range and the switch, `ROC_TOOLCHAIN` has a higher priority (note). |
| R-RU1, R-RU2 | `roc update`: the newest build; the default moves when it is a nightly, a release or not set; a user-channel default moves only to a build of the same channel. |
| R-RR1 | `roc remove` of the default: the default moves to the newest installed build that the switch admits. A user build counts as a nightly here, and the default moves only inside its channel. |
| R-GC5 | A user-channel build follows the rule of a nightly. A build whose channel was removed is still a toolchain of that rule. |
| R-CC6, R-CC7 | Writes of `config.toml` and `talon.toml` are under the lock or guarded by the span text. |
| R-OUT1 to R-OUT5 | New output text is a proposal (TW24). |

Source: DESIGN-CLI.md 6.8, 6.6; research/compiler-channels/PROPOSAL.md (revision 4); row 243 of docs/slices/PLAN-P2-CLI.md.

## Scope (facts found in the code and by the first runs of the new cases, before any change)

| Fact | Where | Consequence for the tests |
| --- | --- | --- |
| `ManageUse.use_pinnable` refuses every id that `Pin.is_id` refuses, so `roc use <user id>` and `roc use reify@latest` are exit 2 (`does not take ...: a git, link or copy build`). The list and the ref are resolved before that (the first run of ch14-use-ref reads the list). | ManageUse.roc | Red: ChannelusepinTest 1, ch14-use, ch14-use-ref. |
| `Locked.Op` has no op that removes the `roc:` entry. `Remove(alias)` works on dependency rows only. | Locked.roc | New op `Unpin` (ChannelusepinTest 3). |
| `Manage.update_move` decides from the default alone. `Manage.kind_of` gives `Nightly` for a user id, so a user default moves to the newest nightly. `Manage.next_default` filters with `Pin.is_id`, so a user default (when removed) goes to a nightly, never to a build of its channel. | Manage.roc | Red: ChanneldefaultTest 1 and 2, ch15-update, ch15-remove run 1. |
| `roc update` takes no operand (`takes no operand, got 1`) and always reads the list of the nightlies. | ManageUpdate.roc, RocManage.roc | Red: ChanneldefaultTest 4 and 5, ch15-update. The old rows are changed (see "Changes to old tests"). |
| `roc remove <user id>` is `no compiler matches <id>` (exit 2): the install list of the remove flow has no user build. `roc default <user id>` works (slice 240). | RocManage.roc | Red: ch15-remove run 1. |
| `cache gc` lists `Compiler.installed` only, so a user build is not seen: never judged, never removed (the rule of an unknown form, R-GC5 older tln). The pure `Gc.toolchains` is right already (`Manage.kind_of` is `Nightly`). | CacheGc, Gc.roc | Red: ch17-gc. Green guard: ChanneldefaultTest 6. |
| `roc list` marks the default `*` for a user build and `(channel removed)` already (slice 242). | RocManage.roc | Guard (green): ch15-list. The "default marks" part of the plan row was already true. |
| `Compiler.newest_installed` filters with `Pin.is_id` and `Compiler.installed` drops user dirs. So `tln setup` (R-ST16), rank 6 and the pick of R-SO14 never take a user build. | Compiler.roc | Guard (green): ChanneldefaultTest 7. |
| `RocUse` and `RocManage` have no `ShareHook`; `Upgrade.run!` has (`ShareHook.send!`). | | R-CH16 stays a guard of slice 241. |

## Behaviors

| # | Behavior | Exit | Rules |
| --- | --- | --- | --- |
| B1 | `roc use <user id>`: baseline check on the header pin, candidate check and build on the user build; then `[toolchain] roc = "=<id>"` and `[channels.<name>]` (from config.toml) go to the root talon.toml; the header `roc:` entry goes. No header pin: only talon.toml changes. | 0 | R-CH14, R-U1, R-U3, R-CH6, R-R4 |
| B2 | `roc use <name>@latest` and `<name>@-1`: the list is read, the ref gives the build (R-SL7: count from `@latest` in the channel), then B1. | 0 | R-CH14, R-CH8 |
| B3 | A new error in an app file with the user build: exit 11, nothing is written. | 11 | R-U3, R-H6 |
| B4 | `ROC_TOOLCHAIN` set: the note of R-U6 after the write. | 0 | R-U6 |
| B5 | `roc update` with no name and a user default: the list of that channel; the default moves inside the channel. | 0 | R-CH15, R-RU2 |
| B6 | `roc update <name>`: the list of `<name>`. `roc update nightly` with a user default: the default stays (note). | 0 | R-CH15, R-RU1, R-RU2 |
| B7 | `roc update` with `nightly = false` and a user default: exit 10, as `roc install reify`. | 10 | R-CH9, R-NS3 |
| B8 | `roc update` operand: none, or one name of R-CH3; a text that is no name, or 2 operands: exit 2. | 2 | R-CH15, R-CH3 |
| B9 | `roc remove` of a user default: the newest other build of its channel; never a nightly, never another channel. A nightly default never moves to a user build (not set when only user builds are left). | 0 | R-RR1, R-CH15 |
| B10 | `cache gc`: a user build is judged as a nightly (default, last day, age, else removed), also when its channel has no table. | 0 | R-GC5, R-CH17 |
| B11 | `tln upgrade roc` on `[toolchain] roc = "=<user id>"`: the pin moves up inside the channel (pure decision `Channel.pin_move`; the edit is `Channel.use_edit`). | 0 | R-CH15 |
| B12 | `roc list` marks a user default `*` and `(channel removed)`. | 0 | R-CH15, R-CH13 |
| B13 | No setup, init or R-SO14 pick of a user build. | n/a | R-CH15 |

## Proposed names (TW24, for the code agent)

Until the names exist, ChanneldefaultTest and ChannelusepinTest do not compile: the driver `l0-9` is red on purpose. E = `{ name : Str, source : Str, tag_prefix : Str }`.

| Name | Type | Rule |
| --- | --- | --- |
| `Manage.update_move_to` | `{ default : Try(Str, [Unset]), id : Str } -> [Move, Stay]` (the old `update_move` stays) | R-RU2, R-CH15 |
| `Manage.update_name` (`ManageUpdate.update_name`, re-exported as `read_update` is) | `Args -> Try(Try(Str, [NoName]), Fail)` | R-CH15, R-CH3 |
| `Channel.update_ref` | `{ name : Try(Str, [NoName]), default : Try(Str, [Unset]) } -> Str` (`<name>@latest`, else `@latest`) | R-CH15, R-CH8 |
| `Locked.Op` tag `Unpin` | removes the whole `roc:` entry (as `Remove` does for a dependency). No entry: failure kind internal `roc is not in the header`. | R-CH14 |
| `Channel.use_edit` | `{ path, text, id, table : E } -> Try(Str, Fail)` | R-CH14, R-CH6 |
| `Channel.unuse_edit` | `{ path, text } -> Try([Same, Set(Str)], Fail)` | R-CH14 |
| `Channel.pin_move` | `{ text, newest, times } -> [NotUser, Same, Move(Str)]` (`Move` has the id; the caller writes `=<id>` with `use_edit`) | R-CH15 |
| `Manage.unset_note` | `{ removed : Str } -> Try(Str, [None])` (the note when the removed default was a user build and its channel has no other build; `Err(None)` for every other id) | R-RR1, R-CH15 (5), Q619 R1 |
| `Channel.toml_pin` | `Str -> Try(Str, [None])` (the id of `[toolchain] roc = "=<id>"` in a root talon.toml text; `Err(None)` for no pin or a range) | R-CH17, R-PD12, Q619 G1 |
| `Gc.toolchains` field `pinned` | optional field of a row: the ids that a root `talon.toml` pins (from `Channel.toml_pin`); such a build stays at any age, as a header pin keeps it | R-GC5, R-CH17, Q619 G1 |
| `ManageUpdate.update_report` tag `NoDefault` | the report for `roc update <user name>` when the default is a nightly, a release or unset (U1): the default stays, the note names `tln roc default <id>` | R-CH15 (1), Q619 U1 |
| `Pin.use_gate` (changed) | a user build against an existing `[toolchain] roc` of `=<user id>` or `>=<user id>` is `Ok`; against any other range it is exit 10 (C1) | R-U5, R-CH14 (1), Q619 C1 |

Changed behavior, no new name: `ManageUse.use_pinnable` (a user id is a pin), `ManageUse.use_plan` (a user id: op `Unpin` for a member with a `roc:` entry, `Err(Same)` for a member without), `Manage.next_default` (a user default), `ManageUpdate.update_report` (`Stay` of a user id), the router for `roc update <name>`, the install list of `roc remove`, the toolchain list of `cache gc`.

## Tests

### L0 (new files, imported by tests/unit/l0-9.roc)

| # | File | Test | Rules | State now |
| --- | --- | --- | --- | --- |
| 1 | ChanneldefaultTest | `Manage.update_move_to`, 13 rows: nightly, release, git, link, copy defaults; user default with a build of the same channel, a nightly, another channel; `my` and `my-fork` read from the right; U1: a nightly, release or unset default with a user id is `Stay`. | R-RU2 R-CH15 R-CH5 | red (no name) |
| 2 | ChanneldefaultTest | `Manage.next_default`, 10 rows: newest of the channel, second newest, no nightly and no other channel, channel from the right, switch off, 2 builds of one day (`published_at`, then sha), and 3 guards (a nightly default never moves to a user build); R1: a user default with no other build of its channel gives no default (no nightly, no other channel). | R-RR1 R-CH15 R-CH9 | red (the user rows) |
| 3 | ChanneldefaultTest | `ManageUpdate.update_report`: the note of a `Stay` user default; U1: the `NoDefault` report (default a nightly, a release, unset); the old `Stay`, `Moved`, `Same` texts (guards). | R-RU2 R-OUT2 | red (user note) |
| 4 | ChanneldefaultTest | `Manage.update_name`, 13 rows: none, flags, a name, `nightly`, bad names (`Reify`, `@latest`, `a`, `reify-`, an id), 2 and 3 operands. | R-CH15 R-CH3 R-CM19 | red (no name) |
| 5 | ChanneldefaultTest | `Channel.update_ref`, 13 rows: the channel of the default (from the right), `@latest` for the other defaults, a name wins. | R-CH15 R-CH8 | red (no name) |
| 6 | ChanneldefaultTest | `Gc.toolchains` on user rows (default, last day, age, no time, old, exactly the age; G1: a row with `pinned` stays at any age; green guards, the `pinned` expect is red) and `Manage.kind_of`. | R-GC5 R-CH17 | green |
| 7 | ChanneldefaultTest | GUARD `Compiler.newest_installed`, `Compiler.installed`, `Compiler.installed_users`: no pick takes a user build. | R-CH15 R-SO14 | green |
| 8 | ChannelusepinTest | `ManageUse.use_pinnable`: user ids ok; git, link, copy still refused (guards). | R-U1 R-CH14 R-R4 | red (user ids) |
| 9 | ChannelusepinTest | `ManageUse.use_plan` with a user id (`Unpin`, `Err(Same)`), a nightly id (guard), no compiler (guard). | R-CH14 R-BL1 | red (no `Unpin`) |
| 10 | ChannelusepinTest | `Locked.edit` with `Unpin`: last entry, middle entry, no entry. | R-CH14 R-H1 | red (no `Unpin`) |
| 11 | ChannelusepinTest | `Channel.use_edit`, 8 rows + not TOML (exit 19); C1: an existing `=<user id>` or `>=<user id>` pin is replaced in place; C3: a pin that moves to another channel removes only the old `[channels.<old>]`; C5: empty text gives a new file with only `[toolchain]` and `[channels.<name>]`. | R-CH14 R-CH6 R-CC6 | red (no name) |
| 12 | ChannelusepinTest | `Channel.unuse_edit`, 10 rows + not TOML (exit 19); C2: an empty `[toolchain]` goes with the blank line before it; C3: only the table of the channel that the pin leaves goes. | R-CH14 R-CC6 | red (no name) |
| 13 | ChannelusepinTest | `Channel.pin_move`, 11 rows; U2: `>=<user id>` does not move (`NotUser`), only `=<user id>` moves. | R-CH15 R-UP8 | red (no name) |
| 14 | ChannelusepinTest | `Pin.use_gate`: C1: an existing `=<user id>` / `>=<user id>` pin and a user build is `Ok`; `*`, a semver range and `>=nightly-...` with a user build is `Err(10)`; nightly cases are guards. | R-U5 R-CH14 | red (user pin is exit 10 today) |
| 15 | ChanneldefaultTest | `Manage.unset_note` (R1): the note text, the channel name from the right (`my-fork`), `Err(None)` for a nightly, a release, `link-dev`. | R-RR1 R-CH15 R-OUT2 | red (no name) |
| 16 | ChanneldefaultTest | `Channel.toml_pin` (G1): `=<user id>` gives the id; a range, a nightly pin, no key, a comment give `Err(None)`. | R-CH17 R-PD12 | red (no name) |

### L2 (tests/commands/cases/channels/)

All use the `commands` entry (`exit N` is printed), fake hosts, no token.

| Case | Runs | Rules | State now |
| --- | --- | --- | --- |
| ch14-use | 6 runs: `use <user id>` with a header pin; `--json`; `ROC_TOOLCHAIN` note; C1 back to a nightly from `=<user id>` (key, table and header move); C2 user to user, same channel (only the value changes); C5 no talon.toml (it is created) | R-CH14 R-U1 R-U3 R-U6 R-CH6 R-R4 | red (exit 2: `does not take`) |
| ch14-use-stop | C1: `[toolchain] roc = "*"` and a user build: exit 10, no file written | R-CH14 R-U5 | red (exit 2) |
| ch14-use-unknown | C4: a user id with no table in `config.toml` and no project file: exit 2, the unknown-channel text | R-CH14 R-CH8 | red (exit 2, other text) |
| ch14-use-fail | a new error with the user build: exit 11, nothing written | R-CH14 R-U3 R-H6 | red (exit 2) |
| ch14-use-ref | `reify@latest`, `reify@-1` (the list is read, then cached) | R-CH14 R-CH8 R-SL7 | red (exit 2 after the list) |
| ch15-update | 6 runs: no name with a user default (moves inside the channel); again (nothing); `reify --json`; `nightly` with a user default (stays, note); U1: `reify` with a nightly default (installs nothing new, the default stays, note); U1: `reify` with no default (stays unset, note) | R-CH15 R-RU1 R-RU2 | red (`takes no operand`, the nightly list is read) |
| ch15-update-switch | `nightly = false` and a user default: exit 10 | R-CH15 R-CH9 R-NS3 | red (the nightly list is read) |
| ch15-update-errors | 3 runs: U3 no name and the default channel has no table (exit 2); U4 a table that only the project has (exit 19, the `channel add` hint, no write); a name with no table (exit 2) | R-CH15 R-CH8 R-CH11 R-RU3 | red (`takes no operand`) |
| ch15-upgrade | `tln upgrade roc` on `[toolchain] roc = "=<user id>"` (user decision of 2026-11-12, R-CH15): run 1 a newer build passes the check loop and the pin moves (`~ [toolchain] roc: =<old> -> =<new>`); run 2 the newest build is pinned already (`<id> is the newest`); run 3 the move with `--json`; run 4 the newest with `--json`. The list of the channel is read direct, then cached. | R-CH15 R-UP6 R-RP1 R-U3 R-CH9 R-J3 | green (code in; calls.log baked from the real run and reviewed) |
| ch15-upgrade-errors | `upgrade roc` with a pin of a channel that only the project talon.toml has: exit 19, the R-CH11 lines with the `channel add` hint, before any request, no write | R-CH15 R-CH11 | green; calls.log baked and reviewed (stops after the config read, no request) |
| ch15-upgrade-fallback | the fallback of `upgrade roc` on a user pin, with 3 builds A < R < B installed and listed, both projects pin `=A`. Run 1: B has a new error (duplicate definition), R passes: a note for B, then the move to R (`5 probes`). Run 2: B and R both fail: a note for each, then `nothing to change`, talon.toml unchanged. | R-CH15 R-UP6 R-SP12 | green; all files baked from the real run and reviewed |
| ch15-upgrade-young | a newer build younger than min-release-age is no candidate of `upgrade roc` on a user pin (mutation check up3) | R-CH15 R-C7 | green |
| ch15-upgrade-switch | `TALON_NIGHTLY=0`: `upgrade roc` on a user pin is exit 10, nothing written (mutation check up4) | R-CH15 R-CH9 R-NS3 | green |
| ch15-remove | 4 runs in 4 homes: a user default; a nightly default with only a user build left (guard); a nightly default with another nightly and a user build (guard); R1: a user default with only a nightly left (the default becomes unset, a note) | R-RR1 R-CH15 | red (run 1: exit 2; run 3: the `.talon.json` read list; run 4: exit 2) |
| ch15-list | 3 runs: `roc list` with a user default; `--json`; a default of a removed channel | R-CH15 R-CH13 | green (guard) |
| ch17-gc | dry run, real run, dry run: 2 user builds go (one with a channel that has no table), 3 builds stay | R-GC5 R-CH17 R-CH13 R-CH9 | red (user builds are not listed) |
| ch17-gc-pin | G1: dry run and real run; a known project pins `=reify-2026-08-01-aaaaaaa` in its root talon.toml (old build, kept); two old builds go | R-GC5 R-CH17 R-PD12 | red (user builds are not listed) |
| ch17-gc-ws | G1 for a workspace member: the member has its own talon.toml with no pin, the ROOT talon.toml pins `=reify-2026-08-01-aaaaaaa`; the build stays (mutation check g1c) | R-GC5 R-CH17 R-PD12 | green |

### Changes to old tests (the rule changed: `roc update` takes a channel name now)

| File | Change |
| --- | --- |
| tests/unit/ManageTest.roc | The two rows `roc up @latest` and `roc update <id> x` (`takes no operand`) are removed from the `read_update` block. They are in ChanneldefaultTest 4 with the new texts. The rows with no operand stay. |
| tests/commands/cases/roc/up1-update | Run 9 (`roc update nightly-2026-10-18-5349569`) still exits 2. The line in `expect/stderr` is the new text of a bad name. The comment of the run is changed. |
| tests/scenarios/compilers/ru1-update | The last stderr line has the new text (L3, text only; not run in this round). |

### Run results (TMPDIR in `.tmp/tmp`, capped scope `MemoryMax=16G`, nothing died at the cap)

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` (after the code, 2026-11-12) | All 151 tests pass. |
| `tests/commands/run.sh channels/ gc/ roc/ upgrade/` (after the code, 2026-11-12) | 121 cases, 121 pass. |
| `MISSING=1 scripts/rules.sh R-CH R-U R-RU R-RR R-GC` | no id is missing. |

## How the expected files were made (read this for the review)

| File | Source |
| --- | --- |
| `expect/tree.diff` | Built with `tree_diff` (tests/lib.sh) over the copy of `given/` and an expected final tree (a script edits a copy; no hunk by hand). `home2` and `home3` are outside the diff (the runner diffs `home` and `project`). |
| `expect/stdout`, `stderr` | From the design examples and the TW24 texts below. A run with exit 0 has no failure text on stderr. Failing runs are in their own cases (ch14-use-fail, ch15-update-switch). The human text of a `--json` run is on stderr (R-J3), as in us1-use and up1-update. |
| `expect/calls.log` | ch15-list: the real run (guard), read. ch14-use, ch14-use-fail, ch14-use-ref: the real run of the same commands with a nightly id (or `nightly@latest`, `nightly@-1`) on the current code, with the ids and the repo changed, plus the guessed lines below. ch15-update and ch15-update-switch: the first 10 lines are the real start of `roc update` (the first run of ch15-update on the current code showed it), then the lines of ch11-install (list, first-seen rows) and up1-update (move of the default). ch17-gc and ch15-remove: the real run of the current code with the user builds added to the lists. |

### Guessed calls.log lines (the code agent may send a dispute, TW18)

| Part | Guess |
| --- | --- |
| Write step of `roc use` on a user channel (ch14-use, ch14-use-ref) | One `read_files <member> <root talon.toml>` and one `write_atomic <root talon.toml> <member>`: the new pin source first, then the header entry goes. For a nightly the old step is `read_files <member>` and `write_atomic <member>`. |
| `.last-use` order and probes of `roc use <user id>` | As us1-use: the new compiler first, then the baseline. The probe lines are those of the nightly id. |
| `roc use reify@latest` (ch14-use-ref) | The lines of the real run of `nightly@latest`, with the list of reify (`pinned=2`, first-seen rows, `compat.tsv` rows sorted by id). |
| ch14-use-fail | Stops after the candidate check, as us1-use run 14. |
| ch14-use runs 4 to 6 (C1, C2, C5) | The lines of run 1 with the ids changed (baseline = the old pin, new compiler first in the `.last-use` writes). Run 4 (back to a nightly): the write step is `write_atomic p3/talon.toml p3/main.roc`. Run 5 (user to user): only `write_atomic p4/talon.toml` (the header has no entry). Run 6 (no talon.toml): the project search has no read of `p6/talon.toml`, and the write step is `write_atomic p6/talon.toml p6/main.roc` after a read that finds no talon.toml. |
| ch14-use-stop, ch14-use-unknown | The stop comes right after the read of `main.roc talon.toml config.toml`: no compiler list, no probe, no `.last-use` write. The gate (C1) and the channel test (C4) need no list. |
| ch14-use runs 4 and 5 (p3, p4: a `[toolchain] roc` pin and no header pin) | After the first `list_dirs toolchains`: `read_files` of the 4 `.talon.json` files, `list_dirs toolchains`, the same `read_files` (the select-time and the gate-time read, as in us1-use p12). Written by hand from the code agent's report; re-bake from the real run. |
| ch17-gc-pin | After `read_files projects.json`, one `read_files $PROJECT/p1/main.roc` and one `read_files $PROJECT/p1/talon.toml` (the root talon.toml of each known project, in the order of the entries). The sizes line `901 B` is 472 + 429. |
| ch17-gc-ws | G1 for a workspace member: the member has its own talon.toml with no pin, the ROOT talon.toml pins `=reify-2026-08-01-aaaaaaa`; the build stays (mutation check g1c) | R-GC5 R-CH17 R-PD12 | green |
| ch17-gc-pin end | The real run ends with `unlock $HOME/.cache/roc/talon/gc`, as every GC case. |
| GC logs of Q619 (gc1-select, gc3-caches, gc5-project-tools, gc6-held-no-package, gc6-prebuilt-entries, ch17-gc-pin) | Baked from the real run, then compared with the old files: the only new lines are the project search (`list_dirs <project dir>`, `$PROJECT`, `$WORK`) and the read of `<project>/talon.toml` where one exists (gc5, gc6). stdout, stderr and tree are unchanged. |
| `roc update` with a name or a user default (ch15-update) | The start of the real run (10 lines), the list of the channel (fetch: `list_dirs index`, `programs gh`, `http_get`, `write_atomic 1.json 1.meta`, `db_query`, `db_write`; cached: `read_files 1.meta 1.json`, `db_query`), the move of the default as in up1-update run 11 (`lock`, 2 reads, `write_atomic`, `unlock`). No project search when config.toml has the table (R-CH15 (4)). |
| `roc update` with a user default and `nightly = false` (ch15-update-switch) | The start and the fetch of the list of reify, then the stop (a guess: the list is read before the switch is checked, as in ch11-switch-off). |
| `roc remove` (ch15-remove) | The `.talon.json` read list has every installed id, user builds too. In runs 2 and 3 (guards) this is the only red line. |
| `cache gc` (ch17-gc) | The toolchain list is the sorted union of nightlies and user builds (the id order `mine`, `nightly`, `reify`); the `read_files`, `tree_info` and lock lines follow it. The `compat` field is null, so no compat dir is deleted. |

## TW24 texts (all accepted by the user on 2026-11-12; the stop text of C1 was changed by the user)

| Where | Text |
| --- | --- |
| `roc use <user id>` stdout | After `check: passed` and `build: passed`: `<root talon.toml>` then `  + [toolchain] roc: =<id>` (or `  ~ [toolchain] roc: =<old> -> =<id>`), `  + [channels.<name>]` (only when the table was added); then `<member file>` and `  - roc: <old header pin>` for each member that had one; last line `the roc pin is now =<id> (in talon.toml)`. |
| `roc use <nightly>` over a user pin (ch14-use run 4) | After `check: passed` and `build: passed`: `<root talon.toml>`, `  - [toolchain] roc: =<old>`, `  - [channels.<name>]`; then `<member file>` and `  + roc: <id>`; last line `the roc pin is now <id>`. |
| `roc use --json` of a user build | The envelope of `roc use`. `data.id` is the id of the build. `data.files` has the root talon.toml first (`previous` is the old `[toolchain] roc` text or null), then the members with their old header pin. |
| `roc use`, user to user (ch14-use run 5) | `  ~ [toolchain] roc: =<old> -> =<id>` under the root talon.toml; last line `the roc pin is now =<id> (in talon.toml)`. |
| `upgrade roc` on `=<user id>` (ch15-upgrade run 1; accepted 2026-11-12) | `check: passed`, `build: passed`, the root talon.toml path, `  ~ [toolchain] roc: =<old> -> =<new>`, then `resolved at <time>, <n> probes` (the line of the nightly flow; n = 3 is a guess). |
| `upgrade roc` on the newest `=<user id>` (ch15-upgrade run 2; accepted 2026-11-12) | `<id> is the newest` (the line of `roc update`). |
| `upgrade roc`, project-only table (ch15-upgrade-errors, exit 19; NEW) | The two lines of R-CH11, as `roc update`. |
| `upgrade roc` on `=<user id>`, a build is skipped (ch15-upgrade-fallback; accepted 2026-11-12) | `note: roc <id> is not used: <reason>`, one line for each build that fails, newest first, before the `check:` lines. The reason is the failure text of the check, e.g. `a new error in an app file: main.roc (type redeclared). The app is not a free variable: fix it, or pass --no-check.` |
| `upgrade roc` on `=<user id>`, no build passes (ch15-upgrade-fallback run 2; accepted 2026-11-12) | The notes, then `nothing to change` (the line of the nightly flow). Exit 0. |
| `upgrade roc --json` on `=<user id>` (ch15-upgrade runs 3, 4; accepted 2026-11-12) | A move: `{"schema":1,"command":"upgrade","ok":true,"data":{"id":"<new>","files":[{"path":"<talon.toml>","previous":"=<old>"}],"probes":3,"downloads":0,"check":"passed","build":"passed","notes":[]},"error":null}` (the shape of `roc use`; `previous` has the `=`). The newest: `"data":{"id":"<id>","changed":false}`. The human text is on stderr. |
| `roc use`, no talon.toml (ch14-use run 6) | The same lines as a new pin: `  + [toolchain] roc: =<id>`, `  + [channels.<name>]`. The file is new; the text does not say so. |
| `roc use`, a range that does not take a user build (C1; ch14-use-stop, exit 10) | `tln: error[no_tuple]: talon.toml has [toolchain] roc = "<range>", which does not take the user build <id>. Only an =<id> or >=<id> pin of channel <name> does. Change [toolchain] roc first.` The range is written as in the file. Accepted 2026-11-12. |
| `roc use`, unknown channel (C4; ch14-use-unknown, exit 2) | `tln: error[usage]: unknown compiler channel <name>. Add it: tln roc channel add <name> <URL>` (the text of R-CH8). |
| `roc update <user name>`, default is a nightly, a release or unset (U1; ch15-update runs 5 and 6) | Nightly default: `note: the default compiler <default> is not a build of the channel <name>, so it stays. To change it, run: tln roc default <id>`. Unset: `note: no default compiler is set, and <id> is a build of the channel <name>, so it is not made the default. To use it, run: tln roc default <id>`. |
| `roc update`, unknown channel (U3), project-only table (U4) | exit 2: the text of R-CH8; exit 19: the two lines of R-CH11 with the `channel add` hint. See ch15-update-errors/expect/stderr. |
| `roc remove` of a user default, no other build of the channel (R1; ch15-remove run 4) | On stderr: `note: <removed> was the default and no other build of the channel <name> is installed, so no default is set. Install one with tln roc install <name>, then run: tln roc default <id>` (`Manage.unset_note`). |
| Note of `ROC_TOOLCHAIN` | The text of `ManageUse.use_note`, with `id` the plain id. |
| `roc update` bad operand (exit 2) | `<text> is not a channel name. A name is a-z, 0-9 and -, starts with a letter, has 2 to 24 characters and does not end with -.` (the text of `tln roc channel add`). |
| `roc update` 2 or more operands (exit 2) | `tln roc update takes at most one channel name, got <n>` |
| `roc update`, a user default stays | `note: the default compiler <default> is a build of the channel <name>, so it stays. To change it, run: tln roc default <id>` (the note for a git, link or copy default stays as it is). |
| `roc update <name>`, the other lines | The old lines: `<id> is the newest` / `installed <id>`, `the default compiler moved from <old> to <id>`. `--json`: the old `data` (`id`, `path`, `installed`, `previous`, `changed`). |
| `roc remove` | The old lines (`removed <id>`, `the default compiler is now <id>`, `no default compiler is set now`). |
| `cache gc` | The old lines. A user build is named by its id. |

## Answers (Design Q619, G-C249; the user answered on 2026-11-11, DESIGN-CLI.md R-CH14, R-CH15, R-CH17, R-PD12)

| # | Answer | Tests |
| --- | --- | --- |
| U1 | `roc update <user name>` with a nightly, release or unset default installs the newest build and does not move the default. A note says to run `tln roc default <id>`. | ChanneldefaultTest 1, 3; ch15-update runs 5, 6 |
| U2 | `tln upgrade roc`: `>=<user id>` works as a `>=nightly-...` range (does not move); only `=<user id>` moves to the newest build of its channel. | ChannelusepinTest 13 |
| U3 | `roc update` with no name and a default whose channel has no table: exit 2, the unknown-channel text (R-CH8). | ch15-update-errors run 1; ChanneldefaultTest 5 |
| U4 | `roc update <name>` reads the project talon.toml only when config.toml has no table; a project-only table is exit 19 with the `channel add` hint; no project file is written. | ch15-update-errors runs 2, 3 |
| R1 | `roc remove` of a user default with no other build of its channel: the default is unset, with a note; never a nightly. | ChanneldefaultTest 2, 15; ch15-remove run 4 |
| C1 | An existing `=<user id>` or `>=<user id>` pin is replaced; any other range stops as R-U5 (exit 10, no edit). Back to a nightly from a user pin works. | ChannelusepinTest 11, 14; ch14-use runs 4, 5; ch14-use-stop |
| C2 | An empty `[toolchain]` after the key goes is removed too. | ChannelusepinTest 12; ch14-use run 4 keeps `nightly = true`, so the table stays there |
| C3 | A pin that moves from one channel to another removes only the old `[channels.<old>]`. | ChannelusepinTest 11, 12 (L0 only: an L2 case needs a second channel installed) |
| C4 | A user id with no table in either file: exit 2, the unknown-channel text. | ch14-use-unknown |
| C5 | A project with no talon.toml: Talon creates it with only `[toolchain]` and `[channels.<name>]`. | ChannelusepinTest 11; ch14-use run 6 |
| G1 | GC keeps a build that a known project pins with `[toolchain] roc = "=<id>"` in its root talon.toml, at any age. | ChanneldefaultTest 6, 16; ch17-gc-pin |

No open question is left.

## Coverage gaps (not questions)

| Gap | Why | What to do |
| --- | --- | --- |
| R-U2 for a user build (missing build, list, consent, download, then the check) | The lines are the download of ch11-install, the prompt of us1-use, and the check: more than 60 guessed lines. | Same. |
| `roc use` in a workspace (each member, root talon.toml) | The rows of `use_plan` are tested (L0 9); the L2 log of a 3-member workspace is long. | Same. |
| `tln init` and `tln setup` with a user build installed | L0 guards on `Compiler.newest_installed`, `Compiler.installed`. An L2 case would need the setup or init flow. | Add if the human wants it. |
| R-CH17 older `tln` | Only the current `tln` can run. GC and the format (`"format":1` in `.talon.json`, tested in ch11-install) are the part that can be checked. | None. |
