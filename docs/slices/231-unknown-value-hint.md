# 231 Unknown value hint, lenient self-update

Phase: P2. Status: done

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-TF4 | A known key with a wrong value stops the command with exit 19. |
| R-TF8 (Design Q607) | A known key with a value form that this tln does not know: exit 19 and one more line `A newer tln may know this value. Update tln: tln tool update talon`. `tln tool update talon` reads `config.toml` with no stop: a bad value is a warning and the key is unset. |
| R-EC19 | Lists this case as exit 19. |

Source: research/cli-format-audit/PLAN.md, findings F3 and F13.

## Scope

| Part | What |
| --- | --- |
| Hint | The failure of a `talon.toml` or `config.toml` value that is an unknown form gets the hint as a second line of `message`. Places: `Intent.read` (cli/lib/Intent.roc:87 to :100, the `read_resolution` issues), `Intent.build_check` (:107, :118), `ConfigToml.read` (cli/lib/ConfigToml.roc:77, the `default-roc` issue). |
| Lenient self-update | `ToolManageFlow` (cli/lib/ToolManageFlow.roc:98) uses a lenient read of `config.toml`. Other commands keep `RocInstall.read_config!`. |
| `--json` | The design does not say where the hint goes. Proposal (TW24): it is part of `error.message` (one text with a new line). `error.kind` and `code` do not change (R-J5). Not tested at L2 (no case with `--json` and exit 19 for this). |

Out of scope: an unknown `source.kind` in `tools.json` and "never stops on an unknown entry of tools.json" (slice 232). The registry setting (see Questions).

## Which failures get the hint (decided by the user, 2026-11-08, Q-231a, Design Q609 G-C239)

| Failure | Hint |
| --- | --- |
| Each exit 19 for the value of a known key in `talon.toml` or `config.toml`: a wrong type, an unknown word, a prefix of an id, a range, a duration or a snapshot that does not parse, a bad `registry` text of `config.toml` | yes |
| Text that is not valid TOML | no |

## Tests

| Layer | Test | Rules | State now |
| --- | --- | --- | --- |
| L0 | tests/unit/NewerhintTest.roc: `Intent.read` unknown `strategy` word, message with hint | R-TF8 R-TF4 | red: no hint line |
| L0 | same file: `Intent.build_check` `wasm64` target | R-TF8 | red: no hint line |
| L0 | same file: `ConfigToml.read` `default-roc = "svn-1a2b3c4"` | R-TF8 | red: no hint line |
| L0 | same file: 9 rows of other value failures (wrong types, prefix, range, hours, in both files), and the bad `registry` of `config.toml` (`IndexQuery.setting`) | R-TF8 | red: no hint line |
| L0 | same file: text that is not TOML has no hint, in both files | R-TF8 R-TF4 | green (it guards the code) |
| L0 | same file: `ConfigToml.read_lenient`: a bad value is a warning and the key is unset, the good keys stay, two bad keys, unknown key still warns, bad TOML gives the empty config and a warning, a good text equals `ConfigToml.read` | R-TF8 | red: `read_lenient` does not exist (compile error, so all expects of l0-9 file fail to run as one unit) |
| L2 | tests/commands/cases/resolve/th1-config-unknown-value: `install`, `config.toml` `default-roc = "svn-1a2b3c4"`: exit 19 plus hint | R-TF8 R-TF4 R-EC19 | red: stderr has no hint line |
| L2 | tests/commands/cases/resolve/th2-talon-unknown-value: `install`, `talon.toml` `strategy = "middle"`: exit 19 plus hint | R-TF8 R-TF4 R-EC19 | red: stderr has no hint line |
| L2 | tests/commands/cases/tool/th3-self-update-bad-config: `tool update talon` with the same bad `config.toml`: warning on stderr, update to 0.3.4, exit 0 | R-TF8 | red: exit 19, no download |

NewerhintTest is imported by tests/unit/l0-9.roc (no new driver). The 3 cases are copies of `resolve/rs-exclude-bad-config` and `tool/ts1-update` (run 1 only) with one changed given file. The expected files of th1 and th2 differ from the copy only in `stderr`. The expected files of th3 are run 1 of ts1-update, with a changed `stderr` (the warning first).

The mutation check (TW12) is by the red state: each new test fails now. I did not edit cli/, so no revert run.

## Code proposal

| Item | Proposal |
| --- | --- |
| Constant and helper | `Fail.newer_hint : Str` (the hint text) and `Fail.with_hint : Fail -> Fail` (adds `"\n" + hint` to `message`, kind stays) in cli/lib/Fail.roc |
| `Intent` | The notes of `read_resolution` (and `read_build`) tell which issue is an unknown word. `Intent.read` and `Intent.build_check` call `Fail.with_hint` for it. |
| `ConfigToml` | `default-roc` issue: hint when the id kind is unknown (rule of the table above). New `ConfigToml.read_lenient : { path : Str, text : Str } -> { config : Config, warnings : List(Str) }`. A bad value is a warning `<path>:<line>: <key>: <why> (ignored)`, no hint. Not TOML: the empty config and the warning `<path>:<line>: not valid TOML (ignored)`. Warnings are in the order of lines. |
| Code result (differs) | `Intent.read` gives the hint to every issue except the "table not allowed" ones (so also `[tools]`, `[patch]`, probe and exclude values). `ConfigToml.read` gives it to every issue. `IndexQuery.setting` (config source) gives it. `ToolManageFlow.machine_lenient!` (and the private `machine_with!`) is used only by `TalonUpdateFlow`. |
| `RocInstall` | New `RocInstall.read_config_lenient!` (prints the warnings as `warning: ...`). `ToolManageFlow` line 98 uses it. |

## Existing tests and cases that will change (the manager decides)

| Test or case | Why |
| --- | --- |
| tests/unit/IntentTest.roc, row "an unknown strategy" (about line 112) | expects the message with no hint |
| tests/unit/IntentTest.roc, row "a local build of roc" (`debug-3f9a1c2`, about line 363) | the kind `debug` is unknown: hint under the proposal |
| tests/commands/cases/target/tg1-ladder/expect/stderr (line 3, `wasm64`) | hint after the line |
| tests/scenarios/update/tg1-wasm-platform/expect/stderr (line 1, `wasm64`) | same |
| tests/scenarios/compilers/so2-ranks/expect/stderr (line 7, `debug-1a2b3c4`) | hint after the line |

Under the decided rule more existing tests change: each existing test or case with an exit 19 for a value of `talon.toml` or `config.toml` (for example the rows of IntentTest "a range that does not parse", `tests/unit/IndexqueryTest.roc` row 6 of R-RG7 from `config.toml`). The manager lists them after the code run.

## Questions

None open. Q-231a (every value failure of a known key gets the hint, only not-TOML text has none) and Q-231b (the lenient read goes on for text that is not TOML: a warning and the empty config) are decided by the user, 2026-11-08 (Design Q609, G-C239). The hint text is `A newer tln may know this value. Update tln: tln tool update talon`.

## Changed expectations (manager review)

Each diff adds only the hint line. L0: IntentTest (8 rows), ToolbinTest (2), IndexqueryTest (1), ToolsplanTest (1). L2: gc1-select, pa5-unsafe-patch, cv1-proxy-range-bad-registry, rg7-remove-bad-config, rg7-share-bad-config, rs-exclude-bad, rs-exclude-bad-config, tg1-ladder, ti7-exclude-bad-config. L3: ri2-refusals, so2-ranks, tg1-wasm-platform, up3-exclude-age. Two `expect/facts.tsv` files that the update run made (ri2-refusals, so2-ranks) are out of scope and were removed.

## Mutations (research/slice-231-revert/mutate.sh)

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | `Fail.with_hint` adds nothing | th1, th2 |
| m2 | `tool update talon` reads config.toml strictly | th3 |
| m3 | Text that is not TOML gets the hint | l0-9 |
| m4 | The bad `registry` text has no hint | cv1-proxy-range-bad-registry |
| m5 | The lenient read drops its "(ignored)" warnings | l0-9 |

## Verify

check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only). `MISSING=1 scripts/rules.sh R-TF`: R-TF9 and R-TF10 have no test yet (slices 234, 236).

## Open

| Item | Owner |
| --- | --- |
| The warning text of the lenient read and the `--json` placement (hint in `error.message`) are accepted (TW24, Design Q609) | Done |
