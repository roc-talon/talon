# 017 Held moves

Phase: P0. Status: done

This slice tests the decision `docs/design-gaps/G-held-moves.md` (applied to the design files: `docs/design-gaps/APPLIED.md`, rows HM1 to HM7). It also takes the items that the reviews of slices 009 and 016 moved here: G2 of slice 009 (R-WS6 for `update`), Q1 of slice 016 (the closure per member), K3, P5, P11, F2b and G3 of the slice 016 code review. It follows `docs/agents/BRIEF-tests.md`. The earlier slices are not committed: the pre-slice copies of the changed files are in `research/slice-017-revert/before/` (with `NEW.txt`).

The slice is one review (TW19): the reference of the test agent (deleted, see "Revert check") has about 330 lines of code: the second search and `Pick.moves` (about 130), the per-member closure (about 20), the second wave in `PickFlow` (about 60), the prompt in `InstallFlow` (about 20), `Vars` (about 30), `Consent` (about 30), `PickLoop` (about 20), the removal of `Add.check_held`. The parts for P1 and P2 are out of scope.

## Rules

R-SP16, R-SP17, R-SP23, R-SP24, R-SP25, R-SP26, R-WS6, R-WS12, R-PH10, R-EC13, R-NI3, R-DI1 (changed or new in the design). Also R-SP15 (the first search is unchanged), R-SP1, R-SP3, R-SP5, R-SP19 (what is held), R-VA5 and R-DI11 (anchors and fixed hosts never move), R-C1, R-C3, R-C7, R-C9 (the constraints of a moved variable), R-AL8, R-AL9 (the facts stay for the second search, the closure per member), R-WS1, R-WS2, R-WS3, R-WS11 (one value for one group, the move writes each member), R-NM3, R-NM8, R-NM10, R-J5, R-LF4, R-AD22, R-AD38, R-FE7, R-I5.

## What changes

| # | Before | After | Rule |
| --- | --- | --- | --- |
| 1 | `Pick.step` gives a held slot the one value `current`. With no tuple it fails with exit 10. `Add.check_held` stops `add` for a group that other members hold (text "which this version of tln cannot ask") | A slot is `Free`, `Held` or `Movable`. After a first search with no tuple, a second search (`second: true`) moves the `Movable` slots: they come first in the search, each tries `current`, then the nearest values. `Add.check_held` is removed | R-SP16, R-SP24, R-WS12 |
| 2 | `--allow-moves` is read and does nothing. `Consent.move_held` has no caller | After the ladder and before the write, the report of the moves, then the prompt R-NI3. Yes: the write. No: exit 13. No person and no flag: exit 13. `--dry-run`: no prompt, exit 0 | R-SP16, R-SP17, R-SP26, R-NI3, R-EC13 |
| 3 | The index is read for the free variables and the new names only | After a first search with no tuple, the index of the movable groups is read (one call for all, in the order of the slots). The facts of the first search stay (no second read) | R-DI1, R-AL8 |
| 4 | `Vars.build` fails with exit 2 for a key in no header with 2 members, also for `update` and `verify` (G2 of slice 009) | `build` does not fail. `Vars.check_keys` is the stop, and only `install` (and `add`, question Q1) calls it | R-WS6, R-I5 |
| 5 | `Scoped` has no `movable` | `Scoped.movable`: a held variable that the user did not name, except an anchor (a range with `=`) and a fixed host | R-SP23, R-VA5, R-DI11 |
| 6 | The closure of the pick gives every member all slots (an over-approximation). A path file of a member that does not use a group can make a conflict that `roc` does not see | A member has the slots that name it (`Slot.files`) and its own entries that no slot owns | R-AL9, R-WS1 |
| 7 | 2 slots of one group can have 2 values (`add` makes `=highest held` for the new entry) | 2 slots of one group have one value: the pick has no tuple for 2 URLs of one group. The new entry of `add` is a `Free` slot with its own range | R-WS2, R-WS3, R-WS12 |
| 8 | A version that the user names for `add X@1.2.3` is exempt from `min-release-age` for the new entry only | It is exempt for the variable of that group too (it may move to it). The `note:` lines have no repeat | R-C7 |

## Public signatures (stubs)

The stubs keep the old behavior (the bodies are the old bodies). A new decision is `crash "todo"`.

| Item | Signature |
| --- | --- |
| `Pick.Slot` | `free : Bool` becomes `hold : [Free, Held, Movable]`. New field `files : List(Str)` (the member files that have an entry of the group, the empty list is every member) |
| `Pick.step` input | New field `second : Bool` |
| `Pick.moves` (new, stub `crash "todo"`) | `{ slots : List(Slot), chosen : List(Chosen), facts : List({ url : Str, release : Release }) } -> List({ id : Str, from : Str, to : Str, why : Str })` |
| `Vars.Scoped` | New field `movable : Bool` (the stub gives `Bool.False`) |
| `Vars.check_keys` (new, stub `crash "todo"`) | `List(Want) -> Try({}, Fail)` |
| `Consent.Move` (new) | `{ alias : Str, name : Str, from : Str, to : Str, why : Str, members : List(Str) }` |
| `Consent.move_held` | `List(Consent.Move) -> { prompt : Prompt, report : Str, details : JsonDoc }`. The stub has the old report (the `why` lines) and `details: JsonDoc.Null` |
| `Consent.declined` (new, stub `crash "todo"`) | `List(Consent.Move) -> Fail` |
| `ResolveBase.Request.prompt` | New field `allow_moves : Try(Answer, [NoFlag])`. `Install.roc` and `Update.roc` pass `opts.allow_moves`, `Remove.roc`, `Ls.roc` and `Verify.roc` pass `Err(NoFlag)` |
| `PickLoop.Input` | New field `second : Bool` (the stub gives `Bool.False`) |
| `PickFlow.slots_of` | New last parameter `current_file : Str`. It fills `Slot.files` (the stub fills it for all slots) |

The test app `tests/commands/main.roc` has the word `allow-moves` for its `resolve` entry (a fake, not Talon code).

## Files

| File | Change |
| --- | --- |
| `cli/lib/Pick.roc` | `Slot.hold`, `Slot.files`, `second`, `Pick.moves` (stub), the docs of `step` (the second search, one value for one group, the closure of a member) |
| `cli/lib/Vars.roc` | `Scoped.movable`, `check_keys` (stub), the doc of `build` |
| `cli/lib/Consent.roc` | `Move`, `move_held` (new input and output), `declined` (stub) |
| `cli/lib/ResolveBase.roc`, `Install.roc`, `Update.roc`, `Remove.roc`, `Ls.roc`, `Verify.roc` | `Request.prompt.allow_moves` |
| `cli/lib/PickFlow.roc`, `PickLoop.roc` | `hold` and `files` in the slots, `Input.second` (compile only) |
| `tests/unit/pickmoves.roc` | New: 3 expects (the second search, the order of the values and one value for one group, `Pick.moves`) |
| `tests/unit/pickclosure.roc` | The helpers have the new fields. 1 new expect (the closure per member) |
| `tests/unit/pick.roc` | The helpers have the new fields (no row changed) |
| `tests/unit/vars.roc` | Expect 2 changed (R-WS6: `build` does not fail, `check_keys` does). 2 new expects (`movable`, `check_keys`) |
| `tests/unit/consent.roc` | The expect of `move_held` changed (the new input, `report`, `details`, `declined`) |
| `tests/unit/add.roc` | The expect of `check_held` removed (the code agent removes the function) |
| `tests/commands/cases/moves/hm1-noninteractive/` | New case: 6 runs (CI=true) |
| `tests/commands/cases/moves/hm2-interactive/` | New case: 3 runs (interactive) |
| `tests/commands/cases/workspace/ws1-closure-keys/` | New case: 6 runs (4 small projects) |
| `tests/commands/main.roc` | The word `allow-moves` of the `resolve` entry |
| `tests/fixtures/add/make.py` | New repo `acme/yaml` (1.1.0 names the platform pfx 0.1.1), `PFDEPS`, 3 new cases |
| `tests/scenarios/install/in1-workspace-frozen-rename/` | `cmd` (comment), `expect/stdout`, `stderr`, `roc.log`: the row `add --file apps/b/main.roc acme/json@2.2.0` changes from exit 10 to exit 13 |
| `research/slice-017-revert/` | `before/` (with `NEW.txt`), `cli-pre.sha256`, `cli-stub.sha256`, `mutate.py`, `results.md`, `red.md` |

## Tests

| Layer | File and case, and what it checks | Rules |
| --- | --- | --- |
| L0 | `tests/unit/pickmoves.roc` expect 1 (11 rows): `json` is free with the range `=2.3.0` (the selector), `json 2.3.0` names the platform 0.26.0, the platform is held at 0.25.0. The first search has no tuple. The second search moves a `Movable` platform to 0.26.0 (the nearest value that works, not 0.27.1), with `Highest` and `Lowest`, with the facts in any order. A `Held` platform stays: no tuple. A movable slot keeps its value when a tuple exists, also when a free slot could be newer. The movable slots come first: `core` keeps 1.0.0, so `web` takes 1.0.0 and only the platform moves (4 slots). The ranges (R-C1) and `min-release-age` (R-C7) apply to a movable slot. With no facts, `Need` has the URLs in the order of the slots | R-SP24 R-SP15 R-SP16 R-SP23 R-PH10 R-VA6 R-C1 R-C7 R-C9 R-DT2 |
| L0 | `pickmoves.roc` expect 2 (8 rows): `core` is held at 1.2.0 by another member (movable), the new entry of `add` is a free slot of the same group that the index offers at some versions. 2 slots of one group have one value. The first search has no tuple. The second search takes the nearest value: `Highest` 1.3.0 (not 1.4.0), `Lowest` 1.1.0 (not 1.0.0), the lower values from high to low when only lower values are offered. The held version offered: no move. A `Held` core: no tuple | R-SP24 R-WS12 R-WS2 R-WS3 R-DI9 |
| L0 | `pickmoves.roc` expect 3 (5 rows): `Pick.moves` gives one row for each `Movable` slot that moved, with `why`: R-C3 `json 2.3.0 needs pf 0.26.0`, R-C2 `web 2.0.0 needs core >= 1.1.0`, R-C1 `core 1.2.0 is outside =1.3.0` (the range of the new entry of the group), R-AL9 `core 1.0.0 does not fit the closure of the new tuple` (a path file names core 1.1.0). A free slot that moves and a movable slot that keeps its value have no row | R-SP16 R-SP23 R-C1 R-C2 R-C3 R-AL9 R-WS2 |
| L0 | `tests/unit/pickclosure.roc` new expect (6 rows): 2 members. `b` has a path entry whose file names `core 1.1.0`, and `b` does not use `core` (held in `a`): no conflict (Q1, the old step found one). `b` uses `core`: a conflict (P11). `core` free in both: the next tuple. 2 members that need the same release: the `Need` list has it once (P5). A slot with no `files` is in every member | R-AL9 R-C2 R-AL8 R-WS1 R-WS2 R-DT2 |
| L0 | `tests/unit/vars.roc` expect 2 (changed): `build` of 2 members with a key in no header gives the wants (no failure), and `Vars.check_keys` gives the old failure (R-WS6 text) | R-WS6 R-I5 R-WS5 |
| L0 | `vars.roc` expect `movable` (new, 7 rows): `Scoped.movable` for `install` with no names, `update`, `update X Y`, `update fixed`, `update X@sel`, an anchor (`parser = "=2.0.0"`), and `install` in a workspace | R-SP23 R-SP3 R-SP4 R-SP7 R-SP19 R-WS12 R-VA5 R-DI11 R-SP2 R-SP5 |
| L0 | `vars.roc` expect `check_keys` (new, 6 rows): `check_keys`: a stale key is no failure, a short name and a full name with 2 members fail (the first key that fails, the line numbers), one member under the file is no failure, no want is no failure | R-WS6 R-I5 R-WS5 R-PD5 |
| L0 | `tests/unit/consent.roc` expect (changed): `move_held` with the new input: the decision of each mode, the texts, the report (2 lines for each move), `details` (the JSON), `declined` (1 and 2 variables, the details) | R-NI3 R-SP16 R-SP17 R-SP25 R-SP26 R-NM8 R-NR2 R-J5 R-EC13 |
| L2 | `moves/hm1-noninteractive` (6 runs, CI=true, workspace `ws`, root key `lex = "=1.0.0"`): run 1 `add acme/json@2.2.0 --file ws/apps/b/main.roc` (a holds json 2.0.0, b has no json): the second search, the index of the movable groups after the first search, the ladder (6 probes), the report, exit 13, nothing written. Run 2 the same with `--json`: the envelope with `error.details.moves[]`. Run 3 `--dry-run`: the report, the header diff, no prompt, exit 0. Run 4 `add acme/lex@1.1.0`: the anchor does not move: exit 10, no prompt. Run 5 `--allow-moves`: the move is written to a, and b gets the new entry. Run 6 `update yaml@1.1.0 --yes` (yaml 1.1.0 names the platform 0.1.1): the platform moves in 2 members that have it under 2 aliases (`pf`, `base`) | R-SP16 R-SP17 R-SP23 R-SP24 R-SP25 R-SP26 R-WS12 R-WS11 R-PH10 R-EC13 R-EC10 R-NI3 R-NM3 R-NM10 R-DI1 R-C7 R-C1 R-C3 R-J5 R-LF4 R-AD22 R-AD23 R-VA5 |
| L2 | `moves/hm2-interactive` (3 runs, stdin and stderr are a terminal): run 1 the same `add` as run 1 of hm1, the person presses Enter: the default is No, exit 13, nothing written, the prompt is after the 6 probes. Run 2 `y`: both members are written. Run 3 `install --file ws2/apps/a/main.roc` (the key `yaml = "^1.1"` of `talon.toml` frees yaml, the platform is movable), `y`: the platform moves in 2 members | R-NI3 R-SP16 R-SP17 R-SP24 R-SP25 R-NM8 R-NM3 R-NR2 R-EC13 R-WS12 R-SP20 R-LD4 |
| L2 | `workspace/ws1-closure-keys` (6 runs, CI=true, `--no-check`). w3: the root key `newdep` is in no header, 2 members are under it. Run 1 `update pf`: exit 0, the platform moves in a and b, the path file of b (names json 2.2.0) is no conflict for the json of a (Q1, G2). Run 2 `install`: exit 2, `tln add --file`. Run 3 `verify`: exit 0 (the key has no effect). w4: Run 4 `update`: the second member has the problem (a path file names core 1.1.0, the key is `=1.0.0`): exit 10 (P11). w5: Run 5 `add acme/util --as local`: the file of the replaced entry is not read, the file of the same alias in b is read (K3, F2b). solo: Run 6 `install`: a path file is not there: exit 18 (G3) | R-AL9 R-AL8 R-C2 R-WS1 R-WS2 R-WS6 R-WS11 R-I5 R-EC2 R-EC10 R-EC18 R-FE7 R-AD38 R-H7 R-SP3 R-DT2 R-CM11 |
| L3 | `tests/scenarios/install/in1-workspace-frozen-rename` (1 row changed): `add --file apps/b/main.roc acme/json@2.2.0` was exit 10 (Q9 of slice 007). Now the check runs, the report is on stderr and the exit code is 13 (CI=true, no flag). Nothing is written | R-WS12 R-SP16 R-SP17 R-SP23 R-SP24 R-NI3 R-EC13 |

Count: 6 new L0 expects (pickmoves 3, pickclosure 1, vars 2), 2 L0 expects changed (vars 1, consent 1), 1 expect removed (`add.roc`). Deep: 3 new L2 cases (15 runs, 7 small projects), 1 L3 row changed.

## Output (proposed, TW24, for the review)

| Item | Proposal |
| --- | --- |
| The report of the moves (stderr, before the prompt, also for exit 13 and `--dry-run`) | 2 lines for each moved variable: `~ <alias>: <name> <from> -> <to> (held): <why>` and `  writes <file>, <file>` (the member files that have an entry of the group). The proposal of the gap file |
| `<why>` (R-SP16: "why") | R-C1: `<id> <version> is outside <range>`. R-C2: `<id> <version> needs <id> >= <version>`. R-C3: `<id> <version> needs <id> <version>`. Else: `<id> <version> does not fit the closure of the new tuple`. The first conflict that the old value has in the final tuple, in this order (`Pick.moves`) |
| The stop with no answer (exit 13) | `moving the held variable <alias> needs consent. Pass --allow-moves or --yes.` (the text of `Prompt.decide`), with `error.details` = `{ "moves": [{ "alias", "name", "from", "to", "why", "members": [...] }] }` |
| The answer No | `the held variable <alias> stays. Nothing was written.` (`the held variables <a>, <b> stay. ...` for 2 or more), kind `consent`, the same `details` |
| `--dry-run` | The report on stderr. The header diff with the moves on stdout as for a write (`~` lines of each member). `data.moved` has the moved entries (no new field). Exit 0 |
| The answer line | The line of `Consent.move_held` on stderr when a flag or `--yes` answers (`moved the held variable pf`) |
| The prompt text | `Move the held variable json? [y/N] ` (the old proposal of slice 001) |

## Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `Slot.free : Bool` becomes `hold : [Free, Held, Movable]` (the plan of the gap file). `Slot.files` is new | A new `movable : Bool` next to `free` (fewer edits of old tests, but 2 fields say one thing) |
| D2 | The closure per member (Q1 of slice 016) is a field of the slot: `files`, the members that have an entry of its group. The empty list is every member (the L0 rows of one member) | The slot ids in each `unmanaged` row (ids are aliases, and one alias can name 2 groups in 2 members, R-WS8) |
| D3 | 2 slots of one group have one value (R-WS2, R-WS3): in `Pick.step`, 2 choices whose URLs are in one group and differ are a conflict. So the new entry of `add` for a group that other members hold is a `Free` slot (the gap file says `Movable`), tied to the held slot by this rule. No selector: the new entry gets the held version (R-WS12). `=2.2.0`: no first tuple, then the second search moves the group | The range of the new entry joins the ranges of the group variable (R-WS2 as it reads). R-C1 would then apply to a held slot in the first search, and R-SP15 ("a tuple exists with all held variables fixed") breaks for a header value that is out of its key range. The old `=highest held` range. A `Movable` new entry (it has no current value) |
| D4 | The second search runs only after the first search ended with "do not fit together" (each slot has a release) and a variable is movable | After each failure (a slot with no release in its ranges has no move that helps, and the index calls of old cases would change) |
| D5 | The facts and the path nodes of the first search stay for the second search (R-AL8, source 1): no file is read twice | A second search that starts with the facts of the start (the calls.log would have the reads again) |
| D6 | The index of the movable groups is read after the first search fails: one call for all, in the order of the slots, for the groups that have no page yet. A group that is free has its page already | Before the first search (R-SP1: a held variable needs no index call; R-DI1 lists the movable group for the second search only) |
| D7 | A version that `add` names for a new entry (`X@1.2.3`) is named for the variable of that group too. Else a young release cannot be the target of the move (the L3 row would stay exit 10), and `min-release-age` would hide the version that the user asked for. `note:` lines have no repeat (as the platform notes) | `min-release-age` hides it for the moved variable (the user could never add a young release to a group that another member holds) |
| D8 | A variable is not movable when it has a range with `=` (an anchor, R-VA5), also a range of `talon.toml` that is not the selector of the command, and when its host is fixed (R-DI11) | Only R-DI11 (R-SP23 names the anchor) |
| D9 | `Vars.check_keys` is a new pure function. `build` does not fail. `ResolveBase.prepared!` calls it when the command is `Install` (also `install --frozen`) | A field `command` in the input of `build` (9 call sites of the L0 tests change) |
| D10 | A failure of the second search is the failure of the first search (the same text, exit 10), as R-SP16 says "as before" | The text of the second search (the same format, but the slot order differs) |
| D11 | Interactive No: kind `consent`, exit 13 (R-EC13), message and details as `Consent.declined`. A flag or `--yes` prints the answer line of the prompt (R-NM6) | A usage failure, or exit 0 |
| D12 | The report goes to stderr (as the report of R-NI1) and the header diff to stdout. `--json` has no new `data` field: `data.moved` has the moved entries | A new `data.moves` list |
| D13 | The tests use `commands` entry (`Run.run!`) for the new L2 cases: `--allow-moves`, `--yes`, `--dry-run` and `--json` are real flags. The mode is set by `CI=true` (hm1, ws1) or by `fx/tty` (hm2) | The `resolve` entry (it needs a Request field for each flag) |
| D14 | `Request.prompt` has `allow_moves`. The L2 `resolve` entry of the test app has the word `allow-moves` | None |
| D15 | A held `Movable` variable whose value is out of its ranges has no `current` in the second search (R-C1 applies as for a free slot): it must move. No test | The value stays (R-C1 is not true for it) |

## Out of scope

| Rule or case | Reason |
| --- | --- |
| R-SP6 to R-SP9, R-UP4, R-UP5, R-RP4, the nightly as a movable variable | `upgrade` is P1. The nightly is no variable in P0 (R-RP2 is tested in slice 013) |
| R-PA4, R-PA14 (a patched entry never moves) | `tln patch` is P1 |
| R-DI11 as an L2 run | A fixed host has no index: its domain is `current` with or without the rule. The L0 row of `Vars.scope` (`movable` false) is the test. An anchor in L2 (run 4 of hm1) gives the same exit 10 with and without the rule (the revert check shows it) |
| P1: the second search as a PubGrub decision order, R-AL5 (a failed probe changes the set), R-P5 (the budget covers both searches) | P1 |
| O1 of `APPLIED.md` (the registry answer for the movable groups) | P2 |
| `--allow-moves` and `--yes` together with `--json` in interactive mode | `--json` makes the mode non-interactive (R-NM1), tested in hm1 run 2 |
| `verify` and `update -i` with moves | `verify` frees each variable (nothing is movable). `update -i` gives names to the same path as `update X Y` (L0 `movable` row) |
| `remove` | `remove` resolves nothing |

## Questions (TW17)

| # | Question | Default (the tests follow it) |
| --- | --- | --- |
| Q1 | R-WS6 says "Only `tln install` runs this check". Does `tln add` (the same code, a command with names) run it? A key in no header with 2 members under it is a want of the pick of `add` too | Yes: the check is for `request.command == Install`, so `install`, `add` and `install --frozen`. No test has `add` with such a key |
| Q2 | K3 of the slice 016 review was written as "the replaced alias is dropped in each member". R-AD38 and R-WS12 say that `add --as <alias>` replaces the entry of the current member only. A path entry of the same alias in another member is not replaced, so it stays a root of the closure of that member | The current member only. Run 5 of ws1 has `local` in 2 members, and the log shows that the file of b is read. If the answer is "each member", this run changes (1 line of calls.log, the order of the reads) |
| Q3 | D7: the named version of a new entry is named for the variable of its group (so a young named release can be the target of a move). The design says only that a named version is exempt (R-C7) | D7 |
| Q4 | D3: 2 slots of one group have one value (also `add X --as other` when the header has X: before, the new entry could have another version than the old one, which R-WS3 does not allow for the members of a workspace) | D3. No old test changed |
| Q5 | R-SP23 says that a moved variable keeps R-C1. A held variable with a header value out of its key range (a hand edit of `talon.toml`) has no value in the second search, so a move is the only way, and `update X` would then ask to move it | D15 (no test) |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Notes for the code agent

The test agent ran the whole fast set with a private reference (deleted). Its shape, as a hint:

| # | Note |
| --- | --- |
| 1 | `Pick`: `Choice` has the index of the slot. `search` gets the slots in the search order (the movable first, only with `second`), the result is sorted by the index of the slot (`sorted_by_slot`), also before `closure_of`. `domain_of`: a `Movable` slot is open (like a `Free` slot) only with `second`, and its values come from `nearest` (`Index.order(cands, Lowest)`, then `current`, the higher and the lower lists). `conflicts` has the rule of one group, one URL. `closure_of` keeps the slots whose `files` is empty or has the file of the member. `moves` and `why_of` are about 60 lines |
| 2 | `PickLoop.run!` gives `Err({ fail, facts, paths })`, so the second search starts with the facts and the path nodes of the first (D5). Each `?` of the loop becomes a `match` that returns the facts |
| 3 | `PickFlow.pick!`: after `Err(stuck)` and `second_wanted` (kind `NoTuple`, the text has `do not fit together`, a `Scoped.movable`): `index!` for the names of the movable variables that have no page yet, `slots_of` again with `found.concat(more)`, `second: Bool.True`, `PickLoop.run!` with `stuck.facts` and `stuck.paths`. An `Err` of the second run gives the first failure (`with_close_versions`). `moves_of` joins `Pick.moves` with the `Scoped` (the name, the files of the uses). `Picked` has `moves`. `slots_of`: `hold` is `Free` for a free variable with an index, `Movable` for `s.movable`, else `Held`. `fresh_of`: no `Add.check_held`, `range` is the typed range (`highest_version` goes). `fresh_version`: the `named` of the variable of the group. Remove `Add.check_held` from `Add.roc` |
| 4 | `InstallFlow.finish!` has `moves`. `confirm_moves!` is after `ladder!` and before `write!`: print `Consent.move_held(moves).report` on stderr, return with `--dry-run`, `Prompt.ask!` with `flag: request.prompt.allow_moves`, an `Err` gets `details`, `No` is `Consent.declined`. `pick_notes` has no repeat |
| 5 | `Vars`: `wants_of` has no failure. `check_keys` is the old condition and text. `movable_of`. `ResolveBase.prepared!` calls `Vars.check_keys` for `Install` |
| 6 | `Consent.move_held`: the report and `details_of` (a `JsonDoc`), `declined` |
| 7 | The stubs of `Request.prompt.allow_moves` and the `Install`, `Update` lines are already in the tree |

## Old tests that changed

| Test | Change | Rule |
| --- | --- | --- |
| `tests/unit/pick.roc`, `pickclosure.roc` | The helpers `slot` and `step` have `hold`, `files` and `second`. The 4 rows with `free: Bool.False` have `hold: Held` | R-SP1 |
| `tests/unit/vars.roc` expect 2 | `build` of 2 members with a key in no header gives no failure. `Vars.check_keys` gives the failure | R-WS6 |
| `tests/unit/consent.roc` | The expect of `move_held` has the new input and output | R-NI3 |
| `tests/unit/add.roc` | The expect of `check_held` is removed (R-WS12 is now a move) | R-WS12 |
| `tests/scenarios/install/in1-workspace-frozen-rename` | The row `add --file apps/b/main.roc acme/json@2.2.0`: exit 13 in place of exit 10 (`stdout`, `stderr`, `roc.log`) | R-WS12 |
| `tests/commands/main.roc` | The word `allow-moves` of the `resolve` entry | |

## Red output

The tree has the stubs (`cli-stub.sha256` matches). Full output: `research/slice-017-revert/red.md`.

| Step | Result | Why it is red |
| --- | --- | --- |
| `check`, `fmt`, `selftest` | pass | The stubs and the tests compile |
| L0 | 4 files fail, all other files pass | `pickmoves` 3 of 3 expects (the second search is not there: no tuple; `Pick.moves` crashes with `todo`). `pickclosure` 1 of 5 (the new per-member expect: the old step finds the conflict of Q1). `vars` 3 of 6 (`movable` gives False, `check_keys` crashes with `todo`, `build` still fails R-WS6). `consent` 1 (the old report, `details` is Null, `declined` crashes with `todo`) |
| L2 | 32 of 35 pass, the 3 new cases fail | `hm1`, `hm2`: exit 10 `no_tuple` with the old text in place of the report and the prompt. `ws1`: `update pf` does not move the platform (the old closure), `install` and `update` differ for R-WS6 |
| L3 | 25 of 26 pass, 1 skipped | `in1-workspace-frozen-rename`: exit 10 in place of exit 13 (the changed row) |

## Revert check

Method: a private reference of the slice (about 330 lines, deleted, the tree has the stubs) was in `cli/`. `research/slice-017-revert/mutate.py` puts 29 small changes in it, one at a time, runs only the tests that should catch the change, and puts the file back (TW12, no full sweep). Result: `research/slice-017-revert/results.md`.

| Group | Changes | Caught by |
| --- | --- | --- |
| Search order and values (R-SP24, R-C1, R-C7) | S1 to S5 | `pickmoves` |
| One group one value, closure per member (R-WS2, Q1, P5, P11) | S6 to S9 | `pickmoves`, `pickclosure`, L2 `moves`, L2 `workspace` |
| `Pick.moves` rows and texts (R-SP16) | S10, S11 | `pickmoves` |
| What is movable (R-SP23, R-DI11, R-VA5) | V1 to V3 | `vars`, L2 `hm2` |
| R-I8 stale key, R-WS6 only `install` | V4, B1 | `vars`, L2 `workspace` |
| Second search and flow (R-SP16, R-C7, R-AL8, K3, R-SP25) | F1 to F6 | L2 `moves`, L2 `workspace`, L3 `in1-workspace-frozen-rename` |
| The prompt (R-SP16, R-SP26, R-NI3, R-J5, note dedupe) | I1 to I5 | L2 `hm1`, `hm2` |
| The report and the failure text (R-SP25) | C1, C2 | `consent`, L2 `moves` |

All 29 changes are CAUGHT. S7, B1, F1, F4, I2 and C2 did not compile at the first run (a warning), and were written again. Not tested by a change: the `hold` of an anchor in L2 (same exit 10 with and without the rule, see Out of scope).

## Next step

The human reviews the 3 new L0 expects of `pickmoves`, the new `pickclosure` expect, the 2 new and 1 changed `vars` expects, the changed `consent` expect, the 3 new L2 cases (15 runs, 7 small projects, the expected files that the reference made: `calls.log`, `stdout`, `stderr`, `tree.diff`), the changed L3 row, the output proposals, D1 to D15 and Q1 to Q5. Then the code agent (notes 1 to 7).

## Review (manager, 2026-10-21)

D1 to D15 and the output proposals (TW24) are accepted.

| # | Answer |
| --- | --- |
| Q1 | Yes: `add` is a form of `install` (R-CM2), so it runs the R-WS6 check, as the tests do. |
| Q2 | The design wins (R-AD38, R-WS12: the current member only). The manager's K3 note asked for each member; it is withdrawn. |
| Q3 | Yes: R-C7 says `min-release-age` does not hide an exact version that the user names. |
| Q4 | Yes |
| Q5 | Yes, a movable variable out of its range must move. No test. |

Status: code.

## Paused (manager, 2026-10-21)

The user paused the work. The code agent had made `scripts/test.sh` pass (manager run: all steps pass) and was in its revert check. The manager stopped it and its mutation script. One file held a mutation when the script stopped (`InstallFlow.roc`, the `--dry-run` line); the manager restored it from the code agent's copy, which equals the code before the mutations. To do on resume: the revert check of the code (research/slice-017-revert/code-mutate.py, run it again from the start), the code agent's report (decisions, the slice file sections), and the manager review of the code.

## Code decisions (code agent)

| # | Decision | Rejected option |
| --- | --- | --- |
| C1 | New module `cli/lib/PickMoves.roc` (26 lines, in `main.roc`): `second_wanted` (D4) and `moves_of` (`Pick.moves` joined with `Scoped`: name, member files). `PickFlow.roc` stays under 600 lines | The functions inside `PickFlow` (585 lines would become about 620) |
| C2 | `PickLoop.run!` gives `Err(Stuck)`: `{ fail, facts, paths }`. A failure of a read (`Gather`, `Release.read`, `platform_wants`) is also a `Stuck`, with the facts at that time | A new error tag |
| C3 | The second search ends with an `Err`: kind `NoTuple` gives the failure of the first search (D10). Another kind (a read of the second wave, for example `Environment` or `Network`) is returned as it is | Always the first failure (it hides a network or file error behind a `no_tuple` text) |
| C4 | `Pick.moves` `why` for R-C1 reads the ranges of each slot whose chosen URL has the group of the moved slot (the slot itself, the new entry of `add`) | Ranges of the moved slot only (the row `core 1.2.0 is outside =1.3.0` needs the range of the new entry) |
| C5 | `ResolveBase.prepared!` runs `Vars.check_keys` when `role == Lock` and `command == Install` (so `install`, `add`, `install --frozen`) | A check in `Vars.build` (G2 of slice 009) |
| C6 | `Vars.build` keeps its `Try` type (the tests match `Ok`/`Err`), but it has no failure path now | A new signature (9 test call sites) |
| C7 | `Picked` has `moves : List(Consent.Move)`. `InstallFlow.finish!` has a new last parameter `moves`, and `confirm_moves!` is after `ladder!` and before `write!` | None |
| C8 | `PickFlow.fresh_of` has no `vars` parameter (it was used only for `check_held`). `Add.check_held` and `highest_version` are removed. The doc row 3 of `Resolve.install!` is changed | None |
| C9 | G3 (a path file that cannot be read gives `Environment`, exit 18): `Gather.get!` already gives this kind. ws1 run 6 passes with no change of code | None |

## Verify results (code agent)

`scripts/test.sh` exits 0 on the final tree (check, fmt, L0, L2 35 of 35, L3 26 of 26 with 1 skipped, selftest). Revert check: `research/slice-017-revert/code-mutate.py`, results in `research/slice-017-revert/code-results.md`. 26 mutations, filtered runs, 26 CAUGHT, 0 not caught. `cli/lib` after the run equals the copy before it.

| Group | Mutations | Caught by |
| --- | --- | --- |
| Search order and values (R-SP24, R-C1) | P1 to P4 | `pickmoves` |
| One group one value (R-WS2) | P5 | L2 `moves` (the L0 rows pass without the rule: the cause was not checked, probably `Closure.step` also refuses 2 values of one series) |
| Closure per member, order of the result, `Pick.moves` rows and texts (Q1, P5, R-SP16) | P6 to P10 | `pickclosure`, `pickmoves` |
| Movable, stale key (R-SP23, R-I8) | V1 to V3 | `vars` |
| R-WS6 only for `install` | R1 | L2 `ws1-closure-keys` |
| Second search and flow (R-SP16, R-C7, R-AL8, R-SP23, R-DI1, R-SP25) | F1 to F6 | L2 `moves` (hm1, hm2) |
| The prompt (R-SP26, R-NI3, R-J5, R-SP16, notes) | I1 to I5 | L2 `moves` |
| The report (R-SP25) | C1 | L0 `consent` |

Note: P5 is not caught by L0. The L0 tests of `pickmoves` pass without the group rule (probably the closure already refuses 2 values of one series: not checked). L2 `hm1` catches it. L3 `in1-workspace-frozen-rename` was not needed for any mutation.

## Review of the code (manager, 2026-10-22)

`scripts/test.sh` passes (manager run: l0 14.2 s, l2 80.2 s, l3 9.3 s). The revert check of the code caught 26 of 26. C1 to C9 are accepted. P5 (one group, one value) is caught by L2 only: accepted. Note for the P1 plan: the l2 step grew from 30 s (slice 005) to 80 s, and the fast set is about 114 s of the 180 s limit (TW20).
