# 233 Keep unknown `[tools]` keys

Phase: P2. Status: done (TW24 texts accepted by the user, 2026-11-08)

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-PT18 (Design Q607) | A key of the `bin` table that is not a target of R-PT17 gives a warning and stays. Talon does not check its value. It is removed with the whole table at a new `url`. A known target with a value that is not a sha256 is still exit 19. |
| R-PT19 | A write of an entry keeps each subkey that Talon does not know. A new `url` removes the `bin` table (also its unknown keys). |
| R-PT3 | `add --tool` of a key with the same app acts as `update <key>` and keeps `bin = false` and each unknown subkey. |
| R-TF4 | An unknown key gives a warning and the command goes on. |
| R-TF8 | An unknown key stays when Talon writes the file. Each exit 19 for a known key has the hint line (`Fail.newer_hint`, slice 231). |
| R-PT1, R-PT25 | Entry form. `bin = false` stays. |

Source: research/cli-format-audit/PLAN.md, findings F4 and F8. Row 233 of docs/slices/PLAN-P2-CLI.md.

## Scope

| Part | Code today | Wanted |
| --- | --- | --- |
| F4 read | cli/lib/ToolsToml.roc:251 to :257 (`read_bin`): a `bin` key that is not a target is exit 19 (`not a target`). | A warning `unknown key tools.<key>.bin.<name>`. No issue. The row of `tool_bins` has the known targets only. `read_hashes` (:265) ignores the unknown key. |
| F4 write | `edit_bin` (:237) keeps the other keys of the entry, but `bin_value` (:233) writes only the targets of the list. An unknown `bin` key is lost when `put_bin` runs. | `put_bin` keeps each unknown `bin` key with its old value (written as it is). |
| F8 write | `put` (:75) writes `{ ref, url }`, and `keep_off` (:226) adds `bin = false`. Each unknown subkey is lost. | `put` keeps each old key except `ref`, `url` and a `bin` table. |
| Unknown subkey on read | `read_fields` (:177) already gives the warning `unknown key tools.<key>.<name>` (R-TF4). The design is clear, so there is no question. | No change. The tests guard it. |

Out of scope: `[tools]` of `tools.json` (slice 232), the project record step (234), `config.toml` keys.

## Tests

| Layer | Test | Rules | State now |
| --- | --- | --- | --- |
| L0 | tests/unit/ToolbinTest.roc:179: unknown `bin` targets (a string, a number, `wasm32`, a wrong case) are warnings, the row has the known targets, no value check | R-PT18 R-TF4 | red: exit 19 `not a target` |
| L0 | same file :202: a known target with a bad value is still exit 19 with the hint line, also with an unknown target in the table (3 rows) | R-PT18 R-TF8 | red: the message is about the unknown target |
| L0 | same file :213: order of the warnings (subkeys sorted, then `bin` targets in file order), and the table form `[tools.a]` | R-TF4 R-PT1 R-PT18 | red: exit 19 (the last row, an unknown subkey only, is green) |
| L0 | same file :224: `put` keeps unknown keys (3 rows: one key, two keys around `bin = false`, an entry with `ref` only), the comment stays | R-PT3 R-TF8 R-PT25 | red: the keys are lost |
| L0 | same file :237: `put` at a new `url` drops the `bin` table with an unknown target and keeps `note`. Then `put_bin` writes the known targets only | R-PT19 R-PT18 R-TF8 | red: `note` is lost |
| L0 | same file :248: `put_bin` keeps unknown `bin` keys (known targets first, then the unknown ones in the old order, also for an empty list). `drop_bin` removes the whole table | R-PT18 R-PT19 R-TF8 | red: the unknown keys are lost |
| L2 | tests/commands/cases/ptool/pt15-keep-unknown: `update --tool` of an entry with an unknown `bin` target (run 1, `url` stays, the check adds 2 targets), and of an entry with `note` and an unknown target at a new `url` (run 2, home2 with `tool-binaries = false`) | R-PT18 R-PT19 R-TF4 R-TF8 | red: exit 19 with the hint line in both runs |
| L2 | tests/commands/cases/ptool/pt16-keep-subkey: `update --tool` at a new `url` of an entry with `note` and a known `bin` target | R-PT3 R-PT19 R-TF8 | red: only the file tree differs (`note` is lost) |

The existing rows that guard the other forms of `bin` stay and are green: the valid forms, the other bad forms (`true`, a string, a bad sha256), and `put_bin` and `put` of slice 091.

Not tested, and why: `tln install` of an entry with only `ref` and `add --tool` of the same app use the same `ToolsToml.put` and `put_bin`. The two L0 groups and pt15 and pt16 cover the write.

### Mutation check (TW12)

I did not edit cli/. The expected value of each test is the design text or a proposal below. A test is red now because of the named reason, so it catches the old behavior (the code of the parent commit is the revert). The code agent runs `scripts/revert-check.sh` or the mutations below at the verify step.

| Id | Mutation (after the code is green) | Caught by |
| --- | --- | --- |
| m1 | `read_bin` gives exit 19 for an unknown key again | L0 :179, pt15 run 1 |
| m2 | `put_bin` drops the unknown `bin` keys | L0 :248, pt15 run 1 |
| m3 | `put` writes `{ ref, url }` only | L0 :224, :237, pt16 |
| m4 | `put` keeps the old `bin` table (also the unknown key) | pt15 run 2, L0 :237 |
| m5 | The unknown `bin` keys come before the known ones | L0 :248, pt15 run 1 |
| m6 | The warning of an unknown `bin` key is missing | L0 :179, :213, pt15 |

## Changed expectations

| Test | Change |
| --- | --- |
| tests/unit/ToolbinTest.roc, the row `{ x64glibc = "<sha256>" }` of the test "the other forms of `bin` are exit code 19" | Removed. It said exit 19 for a key that is not a target. R-PT18 now says warning. The new rows in the same file replace it. |

No existing L2 or L3 case changes. A grep of tests/ for `not a target` finds only `probe` cases (a different message: the targets of a platform).

## Code proposal

| Item | Proposal |
| --- | --- |
| `read_bin` (ToolsToml.roc:251) | Return the unknown `bin` keys with the result, not an `Err`. `read_fields` (:177) adds one warning for each, `unknown key tools.<key>.bin.<name>`, on the line of the key, after the subkey warnings. |
| `read_hashes` (:265) | No change (it reads the 5 targets by name). |
| `put` (:75) | New value = `ref`, `url`, then each old key of the entry in file order, except `ref`, `url` and a `bin` table. `bin = false` stays at its old place. `keep_off` is not needed any more. |
| `put_bin` and `edit_bin` (:237) | `bin_value` also takes the old unknown keys of the table (read from the doc, values as written), after the known targets. |
| `drop_bin` | No change. |
| Size | About 40 lines in ToolsToml. |

## Text proposals (TW24)

| Item | Text |
| --- | --- |
| Warning for an unknown `bin` target | `<path>:<line>: unknown key tools.<key>.bin.<name>` (stderr, before the other output of the command, once for each run) |
| Warning for an unknown subkey | `<path>:<line>: unknown key tools.<key>.<name>` (exists today) |
| Order of the warnings | Unknown subkeys of the entry (sorted by name), then unknown `bin` targets (in file order, not sorted). Entries in the order of their lines. |
| Order of the keys after a write | `ref`, `url`, the old unknown keys in file order. In `bin`: the known targets in text order, then the unknown keys in the old order. |

## Mutation results (research/slice-233-revert/mutate.sh)

The unchanged mirror passes l0-4 (117).

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | `put` drops the unknown keys of the entry | l0-4 (3 failed); L2 pt15, pt16 (m1b) |
| m2 | `put` keeps the `bin` table at a new `url` | l0-4 (2 failed) |
| m3 | `put_bin` drops the unknown `bin` keys | pt15 |
| m4 | No warning for an unknown `bin` target | l0-4 (2 failed) |

## Verify

check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only).

## Open

| Item | Owner |
| --- | --- |
| The texts of the Text proposals table (TW24) and the key order after a write | Human review |
| Does a TW17 question exist? No. R-PT18 and R-PT19 say that the key stays, and R-TF4 says that an unknown key gives a warning. The order of the kept keys is not in the design: it is a proposal above, not a decision of the command. | Done |
| Code agent: the warning order test (L0 :213) needs a stable sort of the warnings by line, or an explicit order. If a sort cannot give it, write a dispute. | Code agent |
| The `rules` files of pt15 and pt16 state the runs. The `calls.log` of pt15 run 1 is the one of pt8 run 1. Run 2 of pt15 and pt16 are the flow of pt8 run 4 in a home that has no cached release list (an extra `http_get`). | Done |

## Verify results

Not run yet (code step). Red now: 6 L0 expects in tests/unit/ToolbinTest.roc (`roc test tests/unit/l0-4.roc`: 111 pass, 6 fail, 0 compile errors), `ptool/pt15-keep-unknown` and `ptool/pt16-keep-subkey` (`tests/commands/run.sh ptool`: 17 pass, 2 fail).
