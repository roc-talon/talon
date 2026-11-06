# 091 Prebuilt tool binaries: the pure parts (names, the `bin` key, `tool-binaries`, the allow decision)

Phase: P1. Status: done (closed by the manager, 2026-11-02).

Slice 091 is the first of three slices for prebuilt binaries of project tools (DESIGN-CLI.md 6.4, R-PT17 to R-PT25). 091 has the pure parts. 092 has the lock-time check (`ToolBinCheck`). 093 has the use (download, sha256 check, `talon/x/` entry). The three slices change no result of the slices 056 to 059: an entry with no `bin` builds from source as before (Design R-PH1, Q135).

## 1. What the design says

| Point | Rule | Text (short) |
| --- | --- | --- |
| Asset name | R-PT17 | `<hash>-<target>`, and `<hash>-x64win.exe`. `<hash>` is the bundle name without `.tar.zst`. 5 targets: `x64musl`, `arm64musl`, `x64mac`, `arm64mac`, `x64win`. The asset URL is the directory of `url` and the name (no API call). |
| The `bin` key | R-PT18, R-PT1 | An inline table (key: target, value: 64 lower case hex digits, no prefix) or `false`. Talon writes the keys in text order. `{}` is valid. Another key or form is exit code 19. |
| Which command writes | R-PT19 | The commands that write `url` (`add --tool`, `update`, `upgrade`, `install` of an entry with only `ref`), at the same write. A new `url` gets the new `bin` (also `{}`), or no `bin` key when the check does not run. `bin = false` is never written, changed or removed. `update` and `upgrade` with the same `url` add values for the targets with no value, and never change a value. `install` of an entry with `url`, `--frozen`, `run`, `x`, `--dry-run` never write `bin`. |
| Two opt-outs | R-PT25, R-LY4, Q134, R-SE20 | Machine: `tool-binaries` (boolean, default true) in `config.toml`. Project: `bin = false`. Binaries are allowed only when neither is false. A `bin` table never overrides `tool-binaries = false` (an exception to R-LY4). Another type of `tool-binaries` is exit code 19. No flag, no environment variable. |

The design is clear for all rows of the tests below. The open points are in section 8.

## 2. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-PT17 | The targets, the asset name, the asset URL | L0 `ToolbinTest` 1 |
| R-PT18, R-PT1, R-TF4 | The forms of `bin`: valid forms, and exit code 19 for the others. No unknown-key warning for `bin` | L0 `ToolbinTest` 2, 3 |
| R-PT18, R-PT19 | The write of the table (`put_bin`), the removal (`drop_bin`) | L0 `ToolbinTest` 4 |
| R-PT19, R-PT25 | `put` keeps `bin = false` and drops a `bin` table at a new `url` | L0 `ToolbinTest` 5 |
| R-PT25, R-LY4, R-SE20 | The allow decision of the two levels. The key `tool-binaries` is read | L0 `ToolbinTest` 6, 7 |
| R-PT19 | The targets to check, the merge, the table of each command | L0 `ToolbinTest` 8, 9 |

## 3. Public signatures (fixed by the tests)

New module `cli/lib/ToolBin.roc` (in `cli/lib/main.roc`). Stubs are `crash "todo: slice 091"`, and `all_targets` is `[]`. The name `targets` is a reserved word of Roc, so the list is `ToolBin.all_targets`.

| Function or type | Signature |
| --- | --- |
| `ToolBin.Hash`, `ToolBin.Lock`, `ToolBin.Command`, `ToolBin.Write` | `{ target : Str, sha256 : Str }`, `[Off, Hashes(List(Hash))]`, `[AddTool, Update, Upgrade, InstallNoUrl, InstallUrl, Frozen, Run, X]`, `[Keep, Drop, Set(List(Hash))]` |
| `ToolBin.all_targets` | `List(Str)` |
| `ToolBin.asset_name` | `{ hash : Str, target : Str } -> Str` |
| `ToolBin.asset_url` | `{ url : Str, target : Str } -> Try(Str, [NotRelease])` |
| `ToolBin.is_sha256` | `Str -> Bool` (not tested alone: the test of `read_table` uses it) |
| `ToolBin.allowed` | `{ machine : Try(Bool, [Unset]), bin : Try(Lock, [Unset]) } -> Bool` |
| `ToolBin.to_check` | `Try(Lock, [Unset]) -> List(Str)` |
| `ToolBin.merge` | `{ old : List(Hash), found : List(Hash) } -> List(Hash)` |
| `ToolBin.write` | `{ command, url_changed : Bool, allowed : Bool, old : Try(Lock, [Unset]), ran : Try(List(Hash), [NotRun]) } -> Write` |
| `ToolsToml.read_table` | The result has a new field `bins : List({ key : Str, bin : ToolBin.Lock })` (stub: `[]`) |
| `ToolsToml.put_bin`, `ToolsToml.drop_bin` | `{ path, text, key, bin : List(Hash) } -> Try(Str, Fail)`, `{ path, text, key } -> Try(Str, Fail)` |
| `Intent.tool_bins` | New field of `Intent`: `List({ key : Str, bin : ToolBin.Lock })`. Stub: `tools.bins` of `read_table`. |
| `ConfigToml.Config.tool_binaries` | New field `Try(Bool, [Unset])`. The stub gives `Err(Unset)`. `Base.no_config` and `ResolveLoad` (the 2 other record literals) have the field. |

The reason for a new `bins` field and `Intent.tool_bins`, not a field `bin` of `ToolsToml.Entry`: the tests of slices 056 to 059 compare `Entry` records with literals (`{ key, ref, url, line }`), and a new field would change about 20 of those expected values. The code agent can merge the field into `Entry` later with a change of those tests, as a separate step.

## 4. Tests

All in `tests/unit/ToolbinTest.roc` (module in the driver `tests/unit/l0-4.roc`, the driver with the smallest time in `.work/l0-times`). 9 `expect`s.

| # | Case | Rule ids |
| --- | --- | --- |
| 1 | `all_targets`, `asset_name` for the 5 targets (`.exe` for x64win only), `asset_url` (the release directory), `NotRelease` for `.../archive/main.tar.zst` | R-PT17 |
| 2 | `Intent.read` of the valid forms: a table with keys out of order (the result is in text order), `false`, `{}`, no `bin`. No warning | R-PT18, R-PT1 |
| 3 | 7 refusals (exit 19): `true`, a string, a target that is not one of the 5, an upper case hex, a short hex, a number, the prefix `sha256:` | R-PT18, R-PT1, R-TF4 |
| 4 | `put_bin` (the table in the entry, the comment stays, `{}`, a second write replaces the table), `drop_bin`, a missing key | R-PT18, R-PT19 |
| 5 | `put` of a new `url`: `bin = false` stays, a `bin` table goes | R-PT19, R-PT25 |
| 6 | `allowed`: 8 rows (machine and project) | R-PT25, R-LY4, R-SE20 |
| 7 | `ConfigToml.read`: `tool-binaries` true, false, missing, and a string (exit 19) | R-PT25, R-TF4, R-LY4 |
| 8 | `to_check` (4 rows), `merge` (old values stay, found values added, text order) | R-PT19 |
| 9 | `write`: 18 rows. Each command, a new `url` and a `url` that stays, `NotRun`, not allowed, `Off`, an empty result | R-PT19, R-PT25 |

How the expected values were made: from the design text. A private reference (deleted at the manager's order, 2026-11-02) passed all 9 `expect`s and all 8 of slice 092 (together 17 in 0.75 s).

## 5. Red output (test agent, 2026-11-02)

`roc test tests/unit/l0-4.roc --no-cache`: 97 tests, 80 pass (the old ones), 17 fail (9 of 091, 8 of 092), 0 compile errors. Reason of each failure of 091:

| # | Reason |
| --- | --- |
| 1, 4, 6, 8, 9 | `crash "todo: slice 091"` |
| 2, 3 | Wrong value: `read_table` gives no `bins`, and it warns `unknown key tools.a.bin` for a valid `bin` |
| 5 | Wrong value: `put` drops `bin = false` |
| 7 | Wrong value: `tool-binaries` gives the warning `unknown key tool-binaries`, and `tool_binaries` is `Err(Unset)` |

## 6. Output (proposed, TW24, R-OUT2)

| Output | Text |
| --- | --- |
| `bin` is not a table or `false` (exit 19) | `talon.toml:<n>: tools.<key>.bin: must be a table of target hashes, or false` |
| A key of the table is not a target | `talon.toml:<n>: tools.<key>.bin.<target>: not a target (arm64mac, arm64musl, x64mac, x64musl, x64win)` |
| A value is not a sha256 | `talon.toml:<n>: tools.<key>.bin.<target>: must be 64 lower case hex digits` |
| `tool-binaries` is not a boolean (exit 19) | `config.toml:<n>: tool-binaries: must be true or false` |

The `<n>` of a `bin` problem is the line of the entry (inline tables are on one line). A key that the table has more than once (a TOML error) is not tested.

## 7. Out of scope

| Item | Why |
| --- | --- |
| The write of `bin` in the commands (`add --tool`, `update`, `upgrade`, `install`), `--dry-run`, `--json` fields | Slice 092 (the flow). `ToolBin.write` is the decision. |
| `RunTools.Table` and `ToolsStep` do not carry `bins` yet | Slice 093 reads `bin` at use time. |
| `bin` on a `[tools]` entry that is `Bad` (another issue first) | The first problem of an entry is its one issue (`ToolsToml` rule). |
| A hand edit of `url` that leaves a stale `bin` (R-PT18 last sentences) | The use time check (slice 093: exit code 16). |
| `ToolBin.is_sha256` has no own row | It is used by rows 3 and by `ToolBinCheck.release_assets` (092, the row with a bare hex digest). |

## 8. Questions (TW17)

| # | Question | Where |
| --- | --- | --- |
| Q1 (answered, Design Q230, G-C15, 2026-11-02) | `tln add --tool` for a key with `bin = false` and the same app. | Answer: it acts as `tln update <key>`, and `bin = false` stays. Test: row 5 of section 4 already checks that `put` keeps `bin = false`. The flow part (`add --tool` calls the update path) is a flow case (slice 092, F3). No new L0 row is needed. A possible row, not added because 091 is in its code step: `ToolBin.write` with `command` `AddTool`, `url_changed` true and `old` `Ok(Off)` gives `Keep` (already in row 9: `Upgrade` with `Off`). |
| Q2 | The tests give one line number for each `bin` problem (the line of the entry). R-TF4 does not say it. A proposal, not a question, unless the human wants the line of the inner key (the same line for an inline table). | row 3 |

## 9. Disputes (from the code agent)

None.

## 10. Verify results

Revert check (test agent): 10 mutations of the private reference of 091 and 092, all caught (results in `research/slice-091-revert/results.txt`; the script and the reference of 091 are deleted, 092 keeps its reference). Mutations of 091: m1 (a `bin` table overrides the machine opt-out), m2 (`merge` changes an old value), m3 (a stale table stays at a new `url`), m4 (`bin = false` is changed), m5 (`.exe` on the wrong target), m6 (`put` drops `bin = false`). The first run found that m9 (a bare hex digest counts, 092) was not caught: the row was added to the test of `release_assets`.

Setup of the work dir of `mutate.py`: a tree with `cli/` and `tests/unit/` copied from the repository, `packages` and `tests/fixtures` as links to the repository, the driver `tests/unit/mine.roc` (`app [main!] { lib: "../../cli/lib/main.roc" }`, imports of `ToolbinTest` and `ToolbincheckTest`, `main! = |_args| Ok({})`). The script copies the reference files over `cli/lib/`.

## 11. Code agent result (2026-11-02)

`roc test tests/unit/l0-4.roc --no-cache`: 97 tests, 89 pass (the 9 of 091 and the 80 old), 8 fail (all of slice 092, `crash "todo: slice 092"`). `roc check cli/main.roc`: 0 errors. L2: 224 pass, 15 fail, all from slice 088 (Windows form `$HOME\.cache\roc` in the fake `Fx` calls of `Roots`, or the host zig and compiler cases). The revert check is not done yet.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo: slice 091"` | None |
| L0 `l0-4.roc` | 89 pass. The 8 failures are the red tests of slice 092. |
| L2 | 224 pass, 15 fail. The 15 are Windows test worlds with only `HOME`, after the 088b caller wiring (slice 088b). None are from 091. |
| Revert check | The test step ran 6 mutations (m1 to m6) on the reference, and all were caught. The code step ran none (TW12, only tricky behaviors). |
| G-C15 (Q230) | `add --tool` for the same app acts as `update`, so `bin = false` stays. This is the behavior of `put`. No new test. |
