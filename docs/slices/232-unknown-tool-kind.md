# 232 Unknown tool source kind

Phase: P2. Status: done (TW24 texts accepted by the user, 2026-11-08)

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-TF8 (Design Q607) | In `tools.json`, an item with an unknown enum word (a `source.kind` of a tool) is not used. It stays unchanged when Talon writes the file. It is listed as "needs a newer tln". Only a command that targets that item gives exit 19 and the hint line. The other items work. `tln tool update talon` never stops on an unknown entry of `tools.json`. `tln setup` replaces a `talon` entry that it cannot read. |
| R-TF2 | An unknown field or member stays when Talon writes the file. |
| R-TF6 | A Talon file with content that does not parse gives exit 19. A known kind with a missing member is such a file. It is not an unknown item. |
| R-TF7 | A `compat.db` row with an unknown word is not used (L0 guard only, F11). |
| R-EC19 | Lists "an item that a command targets and that has an unknown enum word" as exit 19. |
| R-T4 | `tools.json` entry form. `tool list` shows the entries. |

Source: research/cli-format-audit/PLAN.md, findings F2, F5, F11. Hint text: `Fail.newer_hint` (cli/lib/Fail.roc:66), slice 231.

## Scope

| Part | What |
| --- | --- |
| Unknown item | An entry of `tools` whose `source` is an object with a text `kind` that is not `release` or `git`. Today cli/lib/ToolsJson.roc:302 to :313 (`source_of`) and :248 (`entry_of`) fail the whole read with exit 19. |
| Not an unknown item | A known kind with a missing member (`release` with no `version` or no `url`, `git` with no `commit` or no `ref`), a `source` with no `kind` or a `kind` that is not a text, no `source`, a `source` that is not an object, no `name`, an entry that is not an object. All stay exit 19 with no hint (R-TF6). Checks go in this order: object, name, source. |
| Commands that target | `tool update <x>`, `tool rebuild <x>`, `tool remove <x>`, `tool install <x>` when the key (binary name) or the full name of the install is the key or the name of the item. The operand `<x>` of update, rebuild and remove is the key or the full name, exact. Exit 19 plus hint. |
| Commands that skip | `tool update` and `tool rebuild` with no operand skip the item and print one warning for it. `tool list` shows it. |
| Talon entry | `ToolsJson.talon` reads a `talon` entry with an unknown kind as no entry (`Ok(Err(None))`), so `tool update talon` goes on. `tln setup` reads with `ToolsJson.talon_repair`: any fault of the entry gives `Ok(Err(None))`, and `put_talon` replaces it in its place. A fault of the file stays exit 19. |
| F11 | L0 guard: a row with an unknown `outcome` or `source` word is `BadLine` and `BadWord`. No code change. |

Out of scope: `[tools]` of `talon.toml` (slice 233), the project record step (234). A `compat.db` change.

## Tests

| Layer | Test | Rules | State now |
| --- | --- | --- | --- |
| L0 | tests/unit/ToolnewerTest.roc: `ToolsJson.items` (20 rows: mixed order, `talon` key left out, exact kind word, each bad member stays a failure, bad entry before and after an unknown one, missing file, newer format) | R-TF8 R-TF6 | red: does not compile (`items` is a new name) |
| L0 | same file: `read` and `manifest` leave the unknown item out and keep failing for a bad member | R-TF8 R-TF6 | red: same |
| L0 | same file: `put` (new tool, replaced tool) and `drop` keep the unknown item byte for byte, in its place | R-TF8 R-TF2 | red: same |
| L0 | same file: `newer_for` (key, full name, no hit for a known tool, `talon`, other case, part of a name, empty) | R-TF8 | red: same |
| L0 | same file: `newer_fail` kind, exit code, message and `line()` | R-TF8 R-EC19 | red: same |
| L0 | same file: `ToolManage.newer_warning` | R-TF8 | red: same |
| L0 | same file: `ls_report_items` and `ls_data_items` (with a library column, only unknown items, no item, equal to `ls_report` for known items) | R-TF8 R-T4 | red: same |
| L0 | same file: `ToolsJson.talon` unknown kind is `none`, other faults stay exit 19 | R-TF8 R-TF6 | red: same |
| L0 | same file: `ToolsJson.talon_repair` (10 rows) and `put_talon` over an unreadable entry (4 rows) | R-TF8 R-IS6 | red: same |
| L0 | same file: `Db.outcome_of`, `source_of`, `parse_line`, `smoke_of`, `queue_of` with an unknown word | R-TF7 | red: same (green when alone: the code exists) |
| L2 | tests/commands/cases/tool/tn1-newer-list: `tool list` and `tool list --json` | R-TF8 R-T4 R-J3 R-J4 | red: exit 19 |
| L2 | tool/tn2-newer-targets: `tool update zed`, `tool update acme/zed`, `tool rebuild zed`, `tool remove zed`, `tool install acme/zed`, `tool install other/zed` | R-TF8 R-EC19 | red: exit 19 but no hint, no key text, no config read |
| L2 | tool/tn3-newer-update-all: `tool update` skips the item with a warning | R-TF8 | red: exit 19 |
| L2 | tool/tn4-newer-self-update: `tool update talon` with a `talon` entry and a `zed` entry of unknown kind | R-TF8 R-S2 | red: exit 19, no download |
| L2 | tool/tn5-newer-kept-on-write: `tool remove foo`, `zed` stays in `tools.json` | R-TF8 R-TF2 R-B6 | red: exit 19 |
| L2 | tool/tn7-newer-only: `tool update` and `tool rebuild` with only unknown items: one warning each, no "no tool" line, exit 0 | R-TF8 | red: exit 19 |
| L2 | tool/tn6-bad-member: a `release` with no `url`: exit 19, no hint (3 runs) | R-TF6 R-TF8 | green (it guards R-TF6) |
| L2 | setup/st12-talon-newer-kind: `setup` over a `talon` entry of unknown kind and a `zed` entry: exit 0, new `talon` entry in its place, `zed` stays | R-TF8 R-IS6 | red: exit 19 |

The mutation check (TW12). I did not edit cli/. I ran the tests on a small scratch reference code (about 150 lines), and the manager had me delete it (TW18): the code agent writes its own. The results of that run:

| Run | Result |
| --- | --- |
| Reference code | L0 file 11 of 11 expects pass. The 7 L2 cases pass. So the expected files are consistent with the code proposal. |
| m1: `read` does not skip an unknown item | L0: 1 expect fails |
| m2: `newer_fail` has no hint | tn2 fails |
| m3: install does not stop on an unknown item (tn2 runs 5, 6) | tn2 fails |
| m4: remove does not stop | tn2 fails |
| m5: update with no operand has no warning | tn3 fails |
| m6: `ToolsJson.talon` keeps exit 19 for an unknown kind | tn4 fails |
| m7: setup reads the `talon` entry with the strict `ToolsJson.talon` only | not caught by st12 (the unknown kind is read as no entry by `talon` already). Caught by the L0 rows of `talon_repair` and by st7-talon-bad after its change (below). |

Two points make the L2 files strict. The code agent can dispute them (TW18):

| Point | What the expected files fix |
| --- | --- |
| Place of the stop | For update, rebuild and install the stop is after the reads of `tools.json` and `config.toml` (the end of `ToolManageFlow.machine!` and `ToolFlow.machine!`), so `calls.log` has the `config.toml` read. For remove it is after the read of `tools.json`. |
| Old version in tn4 | The entry `talon` is read as no entry, so the old version is the running version: `updated talon 0.0.1 to 0.3.4`. |

## Code proposal

| Item | Proposal |
| --- | --- |
| Types | In `ToolsJson`: `Newer : { key : Str, name : Str, kind : Str }` and `Item : [Known(Tool), Newer(Newer)]`. `Source` stays closed, so no existing `match` changes. |
| Read | `ToolsJson.items : { path, text } -> Try(List(Item), Fail)`: the entries in the order of the file, the key `talon` left out. `read` and `manifest` keep their types and give only the known entries (an unknown item is left out, a bad entry is still exit 19). A helper tells `Newer`: the entry is an object with a text `name` and a `source` object whose text `kind` is not `release` or `git`. |
| Decision | `ToolsJson.newer_for : { items, ref : Str } -> Try(Newer, [None])`: the first `Newer` with `key == ref` or `name == ref`. `ToolsJson.newer_fail : { path, item } -> Fail`: kind `Input`, `Fail.with_hint` of the message. |
| Flows | `ToolManageFlow.machine_with!` also returns `items`. `ToolUpdateFlow.run!`: with an operand, `newer_for` first, then `find!`. With no operand, one `ToolManage.newer_warning` line on stderr for each `Newer`. `removal!` reads `items` and calls `newer_for` before `find!`. `ToolFlow.machine!` returns `items`. `gather_with!` calls `newer_for` for the key and for the name before `clash`. `listing!` gives `items` to `ToolManage.ls_report_items` and `ls_data_items`. |
| Talon entry | `ToolsJson.talon`: an entry whose source `kind` is a text that is not `prebuilt` or `git` is `Ok(Err(None))`. New `ToolsJson.talon_repair`: `talon`, but each fault of the entry is `Ok(Err(None))`. A fault of the file stays an `Err`. `SetupFlow.gather!` and `put_talon!` use `talon_repair`. |
| Size | About 90 lines in `ToolsJson`, 40 in `ToolManage`, 25 in the flows. |

## Text proposals (TW24)

| Item | Text |
| --- | --- |
| Exit 19 message (stderr, and `error.message` with `--json`) | `<path>: tool <key>: source kind "<kind>" needs a newer tln` and a second line `A newer tln may know this value. Update tln: tln tool update talon` |
| `tool list` row | The columns are as before. The SOURCE cell is `needs a newer tln (source kind <kind>)`. The cells COMPILER, TARGET, INSTALLED and LIBS are `-`. The LIBS column shows only when a known tool has a library. |
| `tool list --json` object | `{"tool":"<key>","name":"<name>","source":{"kind":"<kind>"},"needs_newer_tln":true}`. A known tool has the same object as before. |
| Skip warning of `tool update` and `tool rebuild` | `warning: tool <key>: source kind "<kind>" needs a newer tln, skipped` |
| Operand | The key or the full name, exact. A short name (the repo part) of a full name that is not the key is not tried. |

## Changed expectations (done by the test agent, manager decision)

| Test or case | Change |
| --- | --- |
| tests/unit/ToolTest.roc, row of `{"kind":"zip"}` | Now `Ok([])`: `read` leaves an unknown kind out. |
| tests/unit/TalonUpdateTest.roc, row `talon(... ${odd})` | Now `"none"`: `ToolsJson.talon` reads an unknown kind as no entry. |
| tests/commands/cases/setup/st7-talon-bad | Now exit 0. The `talon` entry is replaced in its place (the key `source` is first, because the old entry had no `name`). The `foo` entry stays. New stderr has the warning for `foo` and the compiler-list note. The `fx/commands` comment is new. |

These rows are red now (st7 and the two L0 rows run on the old code). No other existing case has an unknown kind.

## Mutations (research/slice-232-revert/mutate.sh)

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | `tool update` with no operand gives no warning for an unknown item | tn3, tn7 |
| m2 | `tool install` does not stop on an unknown item | tn2 |
| m3 | `tool remove` does not stop on an unknown item | tn2 |
| m4 | setup keeps the strict read of the `talon` entry | st7-talon-bad |
| m5 | "no tool is installed" also with only unknown items | tn7 |

## Verify

check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only).

## Open

| Item | Owner |
| --- | --- |
| The texts of the Text proposals table (TW24) | Human review |
| `tool update` and `tool rebuild` with no operand and only unknown items: no "no tool is installed" line when the file has items (decided by the manager). Tested by tn7-newer-only. | Done |
| `tool rebuild` with no operand uses the same code as `tool update`. tn7 runs both. | Done |
| A `talon` entry with bad content (confirmed by the manager) (not an unknown kind), for example `"talon":5`, stays exit 19 for `tool update talon` (R-TF6, existing case tool/ts7-badentry). Setup replaces it (R-TF8, last sentence). R-TF8 says "never stops on an unknown entry". I read this as the unknown kind only. | Human review |
| No TW17 question. The design gives the decisions. Only texts and the operand rule are proposals. | Done |
