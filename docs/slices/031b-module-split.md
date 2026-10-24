# Slice 031b: module split

Five modules of `cli/lib` were close to the limit of about 600 lines. Each one is split by topic. No behavior change: no test, fixture or expected file changed, and `calls.log` is the same. Callers use the new module names. A one-line name stays in the old module only where a unit test calls it.

## Result

| Old module | Lines before | Lines after | New modules (lines) | What moved |
| --- | --- | --- | --- | --- |
| `Intent` | 571 | 325 | `TomlKeys` (84), `ConfigToml` (83), `IntentEdit` (123) | `TomlKeys`: `Note`, `compare_lines`, `key_line`, `days_of`, `read_probe` (shared by both files). `ConfigToml`: `Config` and its read (`read`). `IntentEdit`: `apply`, `spans`, `rename`, `remove`, `table_spans`, `table_name`, `Table`. |
| `Ladder` | 574 | 343 | `LadderJudge` (211), `LadderPlan` (43) | `LadderJudge`: `Owner`, `Report`, `baseline`, `check`, `build` and the texts of the blame. `LadderPlan`: `Plan`, `Replace`, `plan`, `plan_replace`. |
| `ResolveBase` | 579 | 333 | `ResolveLoad` (168), `ResolveSelect` (108) | `ResolveLoad`: `load!`, `prepared!`, the read of `config.toml` and the member files. `ResolveSelect`: `select!`, `snapshot_of`, the choice of the compiler. `no_names` and `no_facts` are public in `ResolveBase`. |
| `PickFlow` | 585 | 167 | `PickAsk` (229), `PickIndex` (197) | `PickAsk`: the names step (`asked!`, the lookup, the new entries, `unmanaged_of`, `range_of_selector`). `PickIndex`: the index step (`index!`, `slots_of`, `prepare!`). |
| `Setup` | 559 | 205 | `SetupFlow` (365) | `SetupFlow`: `run!` and all the command code of the steps 2 to 12. `Setup` has the pure decisions. `Run` calls `SetupFlow.run!`. |

## Names that stay in the old module

A unit test calls these names, so the old module keeps them as one line (`name = NewModule.name`).

| Old name | Value |
| --- | --- |
| `Intent.read_config` | `ConfigToml.read` |
| `Intent.apply`, `spans`, `rename`, `remove`, `table_spans` | `IntentEdit.<same name>` |
| `Ladder.baseline`, `check`, `build` | `LadderJudge.<same name>` |
| `Ladder.plan`, `plan_replace` | `LadderPlan.<same name>` |

`Setup.run!` has no test call: it moved to `SetupFlow.run!`. The names of `ResolveBase` and `PickFlow` that moved have no test call.

## Import rules

| Module | Imports | Why it is no cycle |
| --- | --- | --- |
| `ResolveLoad` | `ResolveBase`, `ResolveSelect` | `ResolveBase` imports neither |
| `ResolveSelect` | `ResolveBase` | same |
| `PickFlow` | `PickAsk`, `PickIndex`, `ResolveBase` | the two new modules do not import `PickFlow` |
| `SetupFlow` | `Setup` | `Setup` does not import `SetupFlow` |
| `Intent` | `ConfigToml`, `IntentEdit`, `TomlKeys` | none of them imports `Intent` |

## Checks

| Check | Result |
| --- | --- |
| `scripts/test.sh` | exit 0, no WARN |
| `OPT=speed scripts/test.sh` | exit 0 |
