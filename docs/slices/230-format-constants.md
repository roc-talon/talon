# 230 Format constants

Phase: P2. Status: done

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-TF1 | Each JSON file that Talon writes has a top-level integer `format`. |
| R-TF2 (Design Q607) | A release never changes the meaning of a field. `format` does not change unless the design shows a worse UX. A new field does not change `format`. No migrate function. |
| R-TF3 | A file with a newer `format` is exit 19, or is ignored for a file that Talon can make again. A `.talon.json` with a newer `format` reads as no fields (slice 235). |
| R-CC2 (Design Q607) | The temp name forms are fixed for all releases (F15, below). |
| R-ST10 | `<name>.<16hex>.del` on Windows. The sweep owns it (tests/unit/DelTest.roc). `tln cache gc` never chooses it. |
| R-CC12 | `<item>.lock.<16hex>.stale` |

Source: research/cli-format-audit/PLAN.md, findings F9 and F15.

## Scope

| Part | Who | What |
| --- | --- | --- |
| F9 code | Code agent, later | One exposed format constant for each JSON file kind. Every reader and writer of the kind uses it. No behaviour change: all values stay 1. |
| F15 tests | Test agent, now | L0 tests of each fixed temp form, the age edge, and a negative case. No code change (Temp.old already has these forms). |
| F9 tests | Test agent, now | L0 tests that tie each reader to its writer, with and without the constants. |

Out of scope: a `.talon.json` reader that reads a newer `format` as no fields (slice 235), the hint line (231).

## Tests

| Test | File | Rules | State now |
| --- | --- | --- | --- |
| `tools.json`: 4 writers (`ToolsJson.add`, `ToolsJson.put_talon`, `BinRecord.set`, `BinRecord.record_all`) give one `format`. The 3 readers (`ToolsJson.read`, `BinRecord.read`, `Setup.tool_names`) take each text. Each refuses the text with `format` plus 1. `BinRecord.set` refuses it too. | tests/unit/FormatTest.roc | R-TF1, R-TF3 | green |
| Manifests in `talon/x/`: `XCache.manifest_text` and `ToolBinUse.manifest_text` give one `format`. `XCache.read` and `ToolBinUse.read_manifest` take their text. A newer text is `Ignore`, `NotPrebuilt`, and `XCache.read_any` gives `Ignore`. | tests/unit/FormatTest.roc | R-TF1, R-TF3, R-B9 | green |
| `.talon.json`: `Toolchain.meta`, `Zig.meta`, `GitBuild.meta`, `Link.meta` (link and copy) give one `format`. `Link.target` takes the link text and refuses the newer text. | tests/unit/FormatTest.roc | R-TF1, R-TF3, R-CV5, R-LK4 | green |
| Each writer gives the constant: `ToolsJson.format`, `TalonFile.manifest_format`, `TalonFile.record_format`. | tests/unit/FormatconstTest.roc | R-TF1 | red: the 3 constants do not exist (compile error `does not exist`, 8 places) |
| The readers refuse or ignore `constant + 1` and read `constant`. | tests/unit/FormatconstTest.roc | R-TF3 | red: same reason |
| All 6 stale forms (`.tmp` file and dir, `.trash`, `.lock.<16hex>.stale`, `talon/tmp/<16hex>`, `talon/tmp/<16hex>.locks`) are chosen after 1 day plus 1 s, not at exactly 1 day, not when young. | tests/unit/TempTest.roc | R-CC2, R-GC6, R-CC12 | green (the code has the forms) |
| Negative: `x.<16hex>.bak` (file and dir), `.old`, `.stale.bak`, an upper case stamp, 15 and 17 digit stamps, no dot before the stamp, `.del`, `talon/tmp/<16hex>.bak`, an upper case probe copy and `.locks.bak` are never stale. | tests/unit/TempTest.roc | R-CC2, R-ST10 | green |

FormatTest and FormatconstTest are both imported by `tests/unit/l0-6.roc` (no new driver: the L0 budget). Until the code agent adds the constants, l0-6 does not compile, so all its tests are red.

Checked by a mutation (then reverted): `newer` that does not add 1 fails 3 tests of l0-6. A stale `.trash` name in the negative list fails TempTest.

Existing tests of the forms that I did not repeat: `.tmp` age and edge, probe copy age and edge, `.locks` age and edge (tests/unit/TempTest.roc), `.del` names (tests/unit/DelTest.roc).

## Code

Proposal for the code agent (names are a proposal, see Open).

| Constant | Module | Used by |
| --- | --- | --- |
| `ToolsJson.format : U64` (`format = 1`) | cli/lib/ToolsJson.roc | ToolsJson (`open_file` :228, `render_fields` :393, and the read check of :230), BinRecord (:49, :76), Setup (:229) |
| `TalonFile.manifest_format : U64` | cli/lib/TalonFile.roc | XCache (:78, :100), ToolBinUse (:85, :98) |
| `TalonFile.record_format : U64` | cli/lib/TalonFile.roc | Toolchain (:313), Zig (:295), GitBuild (:70), Link (:102, :123) |

| Point | Decision |
| --- | --- |
| Why `TalonFile.manifest_format` | A manifest is not part of tools.json. TalonFile is the shared file module, next to `record_format`. It is also not `XCache.format`: | XCache imports ToolBinUse. ToolBinUse needs the number, so `ToolBinUse` would import XCache: a cycle. `ToolsJson` is imported by both and by no cycle. |
| Why not `ToolchainRecord.format` | A new module is not needed. `TalonFile` is below Toolchain, Zig, GitBuild and Link, and all of them import it. |
| BinRecord and Setup | Add `import ToolsJson`. ToolsJson does not import them (no cycle). |
| RocInstall.roc | Writes no `.talon.json` itself (it calls `Toolchain.meta_from`). No change. |
| Projects, ShareJson, Db | Have a constant already. No change. |
| The docs of each function | Replace `format` 1 with the constant name. |
| Tests | Do not edit (TW18). A wrong test goes to Disputes. |

## Mutations (research/slice-230-revert/mutate.sh)

The unchanged mirror passes l0-6 (139) and l0-3 (118) first.

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | `BinRecord` writes a literal format 2 | l0-6, 4 failed |
| m2 | `Link.target` accepts format + 1 | l0-6, 2 failed |
| m3 | `XCache` writes a literal format 2 | l0-6, 2 failed |
| m4 | `RegistryToolchains` reads format + 1 | l0-3, 1 failed |

## Verify

check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only). `MISSING=1 scripts/rules.sh R-TF R-CC`: R-TF8, R-TF9, R-TF10 have no test yet (slices 231 to 236).

## Open

| Item | Owner |
| --- | --- |
| Constant names and modules: the design does not give them. The plan proposed `ToolsJson.format`, `XCache.format` and a `.talon.json` module. This file changes the 2nd and 3rd for the reasons above. Manager review: `TalonFile.manifest_format`. | Decided (manager): `ToolsJson.format`, `TalonFile.manifest_format`, `TalonFile.record_format`, and `RegistryToolchains.format` (found by the code agent) |
| `Compiler.published_at_of` and `GitBuild.built_at` do not read `format`. A `.talon.json` with a newer `format` must read as no fields (R-TF3). A test for it belongs to slice 235 and is red there. Not tested here. | Slice 235 |
| `tln cache gc` and `.del`: R-CC2 says gc deletes "the other temps, the `.trash` dirs and `talon/tmp/<16hex>/`". `.del` is not in that list, so the negative test says gc never chooses it. | Confirmed (manager): `.del` is swept at each start by R-ST10, never by gc |

No TW17 question blocks the tests.
