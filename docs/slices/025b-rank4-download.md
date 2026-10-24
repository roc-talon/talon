# 025b Rank 4 download and optional downloads

Phase: P1. Status: done

Slice 025b is the second part of slice 025 (`docs/slices/025-download-consent.md`, section 9). Today a `[toolchain] roc` range with no installed compiler in it is a refusal (exit 13, `NoneInRange`). After this slice it is a required download (R-SO13, R-DL2, R-NI5): the newest release in the range that the `nightly` switch, `min-release-age` and the snapshot allow. The download follows the consent rules of slice 025 (one prompt, the flags, `TALON_AUTO_INSTALL`) with no change. The slice also fixes the text of the refusal (023b Q5), and it states why the optional download is not here (section 8). It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-025b-revert/before/` (with `NEW.txt`).

## 0. What this slice does and does not do

| Item | State |
| --- | --- |
| R-SO13 for the commands that resolve (`install`, `add`, `update`, `remove`, `verify`) | In scope. The list is read at the selection (the id must be known before the index and before any write, R-SO19). The download is at the first probe (R-SO22), by the code of slice 025. |
| R-SO13 for the `roc` proxy | In scope. R-NI5 and R-DL8 name the proxy, and 023b left the refusal for this slice (`docs/slices/023b-proxy-install.md`, Q5). |
| The text of `Compiler.failure(NoneInRange)` (023b Q5) | In scope. The old text says that tln never downloads a compiler for a run. |
| `--no-check` with a rank 4 range (025 Q3) | In scope (answer Q1, option a): the list is read, the newest release in the range is held for the index, nothing is downloaded, no pin is written. L2 runs 14 to 16. |
| The optional download (R-NI4 prompt, R-DL6, R-P5 cap) | Not in this slice: it has no producer in P1 today. Section 8 says why, and where it goes. |

## 1. Rules

| Id | Rule (short) | Where | Tested by |
| --- | --- | --- | --- |
| R-SO13 | Rank 4 has a range and no installed compiler is in it: the newest release in the range that the switch allows is a required download | `Toolchain.range_pick`, `RocInstall.range_id!`, `ResolveBase.choose!` (the proxy: `Proxy.go!`) | L0 `toolchain` (`range_pick`, 18 rows). L2 `consent/dl3-rank4` runs 3, 9 to 13. L2 `proxy/px2-install` runs 12, 17, 18. L3 `compilers/dl3-rank4-download` parts 1, 3, 6 |
| R-DL2 | The compiler of rank 4 is a required download (the stop and the prompt are the ones of a required download) | `Start.run!` (unchanged) | L2 `dl3-rank4` runs 3, 9. L3 `dl3-rank4-download` parts 1, 3 |
| R-DL1 | One prompt for the command, with the count and the size (here 1 compiler, and the size of the newest release in the range) | `Start.run!` (unchanged) | L2 `dl3-rank4` run 9 (prompt), run 3 (stop). `proxy/px2-install` run 12 (prompt). L3 part 1 (stop with `572 B`) |
| R-DL4 | No person and no answer: exit 13, the count and the size | `Start.run!` (unchanged) | L2 `dl3-rank4` run 3. L3 part 1 |
| R-DL5, R-DL10 | `TALON_AUTO_INSTALL=no` refuses with no prompt and before any request. A flag (`--allow-downloads`, `--yes`) wins over the variable (answer Q1 of slice 025) | `Consent.auto_refuses`, `Consent.range_refused` (the proxy: `Compiler.failure`) | L0 `consent` (`auto_refuses`, `range_refused`). L2 `dl3-rank4` runs 4, 10, 11. `proxy/px2-install` run 13. `proxy/px1-flow` run 14 (old). L3 part 2 |
| R-DL8, R-DL9 | The proxy with a range and no person: `ask` is the refusal that names the id, `yes` installs | `Proxy.go!` | L2 `proxy/px2-install` runs 12, 14, 17, 18. L3 part 6 |
| R-NS2, R-NS3 | The switch applies to rank 4. With the switch off the domain is the releases only, and there is none: exit 10, the text names the range, the switch and its source | `Toolchain.range_pick`, `Toolchain.range_failed` | L0 `toolchain`. L2 `dl3-rank4` run 5. `px2-install` run 16. L3 part 5 |
| R-NS1 | The newest by the order of R-NS1 (the day, a release over a nightly of its day, `published_at`, the tag) | `Toolchain.range_pick` | L0 `toolchain` (2 nightlies of one day, a release against a nightly) |
| R-NS7 | The range forms: `*`, `>=<id>`, `=<id>` (also in the other tag form), semver (releases only) | `Pin.admits` | L0 `toolchain`. L2 `dl3-rank4` runs 3, 6, 10 |
| R-C7 | `min-release-age` and the snapshot also limit the compiler that rank 4 selects (R-NS3). A compiler that is installed, or that the user names, is not limited (R-NS4) | `Toolchain.range_pick` | L0 `toolchain`. L2 `dl3-rank4` runs 7 (snapshot), 8 (age). `px2-install` runs 17, 18 (the time, `config.toml`). L3 parts 1, 6 (age) |
| R-DT4 | A snapshot hides the releases that are later than its time | `Toolchain.range_pick` | L2 `dl3-rank4` run 7 |
| R-DI12 | `--offline` with no cached list of compilers: exit 15 | `RocInstall.range_id!` | L2 `dl3-rank4` run 1 |
| R-SO22 | The download is at the first probe: the list is read at the selection, the install is in `Start.run!` | `ResolveBase.choose!` | L2 `dl3-rank4` run 3 (the order of the calls) |
| R-SO4 | An installed compiler in the range is used with no list and no download | `Compiler.select` (unchanged) | L2 `dl3-rank4` run 2. L3 part 4 |
| R-SO21, R-DL7 | `verify` and `remove` use the same selection | `VerifyFlow`, `RemoveFlow` (through `select!`) | L2 `dl3-rank4` runs 12, 13 |
| R-EC10, R-EC13 | The failure kinds: no release in the range is `no_tuple` (10), a refusal is `consent` (13) | `Toolchain.range_failed`, `Consent.range_refused` | L0 `toolchain`, `consent`. L2, L3 |
| R-DL6, R-NI4 (prompt and skipped line), R-P5 (cap) | The optional download | none | Not tested here: section 8 |

`MISSING=1 scripts/rules.sh R-SO R-DL R-NI R-P` lists R-DL6 and R-P5 (section 8) and no other id of this table. R-NI4 is named by the L0 tests of the flag of slice 025a.

## 2. Flow of a command with a rank 4 download (the calls that the L2 cases fix)

| Step | Call | Rule |
| --- | --- | --- |
| 1 | `ResolveBase.choose!` (unchanged until here): `list_dirs` of `<cache>/toolchains`, one `read_files` of the `.talon.json` of each installed id. `Compiler.select` gives `Err(NoneInRange)`. | R-SO4 |
| 2 | `Consent.auto_refuses({ auto, yes, flag })`. True: the failure `Consent.range_refused(<range text>)`, exit 13, no more calls. | R-DL5, R-DL10 |
| 3 | `ResolveBase.snapshot_of` (a bad `--snapshot` is the usage failure of today, now also in this path) | R-C7 |
| 4 | `RocInstall.range_id!`: `platform`, then the calls of `Nightlies.list!` (the cache of the list, one `http_get` when it is not cached). `--offline` with no cache: `Toolchain.offline_no_list` (exit 15). `Toolchain.range_pick` gives the id, or `Toolchain.range_failed` (exit 10). | R-SO13, R-DI12, R-NS2 |
| 5 | `selected` is `{ id: Ok(<id>), from: Range }`. The index, the pick and the header decision go on as for a pin. | R-SO19 |
| 6 | The first probe: `Start.run!` finds the id missing (`Compiler.find`) and does steps 0a to 0g of slice 025: `tty`, `clock`, `platform`, `config.toml`, the list again (from the cache: no request), the stop, or the prompt (`ask`), or the answer line, the lock, the install, the probes. | R-SO22, R-DL1 to R-DL5 |
| 7 | `InstallFlow.finish!` writes the id as the `roc:` pin (R-H6, `Pin.decide` with `held_from: Range`). `verify` writes no file. | R-RP3 |

The proxy (`Proxy.go!`): after `Proxy.select` gives `Err(NoneInRange)` (step 8 of its table, with the `roc` on `PATH` looked at, so it is no candidate): `Consent.auto_refuses` with `yes: Bool.False` and `flag: Err(NoFlag)`. True: `Compiler.failure(NoneInRange(<range text>))`. Else `RocInstall.range_id!` (with `Clock.now!` when `TALON_PROXY=0`, because `now` is 0 then), and the id is `Missing` with the rank `Range`. Steps 9a to 9f of the proxy (slice 023b) go on with it (`Proxy.want`, the offer, the prompt, `install_offer!`).

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Toolchain.roc` | +40 | Stub | `range_pick`, `range_failed` (type, doc table, `crash "todo"`) |
| `cli/lib/Consent.roc` | +16 | Stub | `auto_refuses`, `range_refused` (type, doc, `crash "todo"`) |
| `cli/lib/RocInstall.roc` | +22 | Stub | `range_id!` (type, doc table, `crash "todo"`) |
| `cli/lib/Compiler.roc` | doc only | Test agent | The doc of `failure` has the new text. The body keeps the old text (red). |
| `cli/lib/ResolveBase.roc`, `cli/lib/Proxy.roc` | none | None | The code agent changes them (section 7). The proxy `Loaded` needs 3 more fields (`toml_nightly`, `config_nightly`, `min_age`). |
| `tests/unit/toolchain.roc` | +80 | Test agent | 2 new `expect`s (`range_pick` 18 rows, `range_failed` 4 texts) |
| `tests/unit/consent.roc` | +24 | Test agent | 1 new `expect` (`auto_refuses` 6 rows, `range_refused`) |
| `tests/unit/compiler.roc` | +6 -2 | Test agent | The `failure` `expect` has the new text of `NoneInRange` |
| `tests/commands/cases/consent/dl3-rank4/` | 1 case | Test agent | L2, 16 runs (entry `commands`) |
| `tests/commands/cases/proxy/px2-install/` | +10 runs, 9 projects, 2 config dirs | Test agent | Runs 12 to 21 (19 to 21 after the code check, section 18) |
| `tests/scenarios/compilers/dl3-rank4-download/` | 1 case | Test agent | L3, 7 parts, the fake release server (4 archives) |
| 4 old cases | `fx/runs`, `fx/commands`, `cmd`, expected files | Test agent | Section 6 |
| `research/slice-025b-revert/` | | Test agent | `before/`, `NEW.txt`, `FILES`, `bk.sh`, `swap.sh`, `stubs/`, `mutate.py`, `mutate.out` |

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Toolchain.range_pick` | `{ releases : List(Nightlies.Release), req : Pin.Req, now : U64, min_age : U64, snapshot : Try(U64, [None]), nightly : Bool } -> Try(Str, [NoneKnown])` | R-SO13, R-NS1, R-NS3, R-NS7, R-C7 |
| `Toolchain.range_failed` | `{ req_text : Str, switch : { nightly : Bool, source : Pin.Source } } -> Fail` (kind `NoTuple`) | R-SO13, R-NS2 |
| `Consent.auto_refuses` | `{ auto : [Ask, Yes, No], yes : Bool, flag : Try(Answer, [NoFlag]) } -> Bool` | R-DL5, R-DL10 |
| `Consent.range_refused` | `Str -> Fail` (kind `Consent`, the range text in) | R-DL5, R-DL10, R-SO13 |
| `RocInstall.range_id!` | `Fx, { roots : Roots, net : Net.Settings, now : U64, offline : Bool, req : Pin.Req, req_text : Str, min_age : U64, snapshot : Try(U64, [None]), switch : { nightly : Bool, source : Pin.Source } } => Try(Str, Fail)` | R-SO13, R-DI12 |
| `Compiler.failure(NoneInRange(text))` | same type, new text (section 12) | R-DL10, 023b Q5 |

The rules of `range_pick` are in its doc table: candidates (one asset for the host), `Nightlies.visible` (age, snapshot), the switch, `Pin.admits`, the newest by `Pin.order` with the `published_at` rows of the list.

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/toolchain.roc`: `range_pick` (18 rows) | The age (exactly 2 days is visible), the snapshot (equal time is visible), `Any`, a lower bound that is met, not met, met only by a too new release, `=<id>` in the other tag form (the id of the list is the result), a release with no asset, the switch off (nightlies dropped, releases kept), an empty list, a semver range (releases only, not the newer series), 2 nightlies of one day (`published_at`, not the sha), a release against a nightly of its day (early and late), the newest release of all | R-SO13, R-NS1, R-NS2, R-NS3, R-NS7, R-C7, R-CV2 |
| L0 | `toolchain.roc`: `range_failed` | Kind `NoTuple` (10). The 4 texts (switch on, off by `TALON_NIGHTLY`, by `talon.toml`, by `config.toml`) | R-SO13, R-NS2, R-EC10 |
| L0 | `tests/unit/consent.roc`: `auto_refuses`, `range_refused` | 6 rows of the truth table (`no` with no answer refuses; `--yes`, `--allow-downloads`, both, `ask`, `yes` do not). The refusal text and kind | R-DL5, R-DL10, R-SO13, R-EC13 |
| L0 | `tests/unit/compiler.roc`: `failure` | The new text of `NoneInRange` | R-DL10, 023b Q5 |
| L2 | `consent/dl3-rank4` (new, 16 runs, entry `commands`) | See the list below | R-SO13, R-SO4, R-DL1 to R-DL5, R-DL7, R-DL10, R-DI12, R-NS2, R-NS3, R-NS7, R-C7, R-DT4, R-SO21, R-SO22, R-RP3 |
| L2 | `proxy/px2-install` (10 new runs, 12 to 21) | The proxy with a range: a person and Enter (download, prompt names the id and the size), `TALON_AUTO_INSTALL=no` (refusal text, no request), no person (refusal that names the id and the source `the compiler range`), no release in the range (exit 10), the switch off (exit 10 names it), `TALON_PROXY=0` (the time is the clock of Talon), `min-release-age` of `config.toml` | R-SO13, R-DL1, R-DL3, R-DL8, R-DL10, R-NS2, R-NS3, R-NS7, R-C7, R-LY4, R-PX7 |
| L3 | `compilers/dl3-rank4-download` (new, 7 parts) | The real binary, the real `curl` and `tar`, the fake release server. See the list below. | R-SO13, R-DL1, R-DL2, R-DL4, R-DL5, R-DL9, R-DL10, R-NS2, R-NS3, R-C7, R-SO4, R-SO15, R-SO22, R-PX4 |

L2 runs of `dl3-rank4`. The ranges of the later runs ask for a compiler that is not installed yet, because each run that installs one changes the store (the order of the runs matters). The installed compiler at the start is `nightly-2026-10-09-258ab27`. The fake list has 12 nightlies (2026-10-07 to 2026-10-18). `TALON_NOW=2026-10-22T12:00:00Z` unless the run sets it.

| # | Run | Shows |
| --- | --- | --- |
| 1 | `p1` `--offline --allow-downloads`, range `>=nightly-2026-10-17-0000000`, no cached list | `platform`, the list cache read, exit 15 with the offline text. No lock, no write. |
| 2 | `p2`, range `>=nightly-2026-10-08-0000000` | The installed compiler meets the range: no list, no prompt, the probes run it, the header gets it as the `roc:` pin |
| 3 | `p3` (CI), range of `p1` | The list is read (one request) at the selection, the newest release (2026-10-18) is the download, the stop has `1 compiler download (73.0 MB)`. No `tty`, no lock, no write. |
| 4 | `p4`, `TALON_AUTO_INSTALL=no`, a person | `range_refused` before any request: no `platform`, no list, no `tty` |
| 5 | `p5`, `TALON_NIGHTLY=0`, range `*`, `--allow-downloads` | Rank 4 has none (the installed compiler is a nightly), the list has no release: exit 10 names the range, the switch and its source |
| 6 | `p6`, range `>=nightly-2026-10-25-0000000`, `--allow-downloads` | No release in the range: exit 10, no download |
| 7 | `p7`, `--snapshot 2026-10-12T20:00:00Z`, range `>=nightly-2026-10-10-0000000` | The snapshot limits the compiler: 2026-10-12-2664a27 (the packages are limited too) |
| 8 | `p8`, `TALON_NOW=2026-10-19T12:00:00Z`, range `>=nightly-2026-10-13-0000000` | `min-release-age` hides the 2 newest nightlies: 2026-10-16-1df370f |
| 9 | `p9`, a person, `y`, range `>=nightly-2026-10-17-0000000` | The prompt names 2026-10-18 with `73.0 MB`, the install, the probes, the `roc:` pin |
| 10 | `p10`, `TALON_AUTO_INSTALL=no`, `--allow-downloads`, range `=nightly-2026-10-15-38e6c42` | A flag wins over the variable. The exact range downloads its id. |
| 11 | `p13`, `TALON_AUTO_INSTALL=no`, `--yes`, range `=nightly-2026-10-10-abcdef0` | `--yes` wins over the variable too |
| 12 | `verify` `p11`, range `=nightly-2026-10-14-38a3029` | `verify` holds the compiler of rank 4: download, `verified`, no file written |
| 13 | `remove json` `p12`, range `=nightly-2026-10-11-1a2b3c4` | `remove` goes through the same selection |
| 14 | `p14`, `--no-check`, range `=nightly-2026-10-08-0a1b2c3` (not installed) | Q1: the list is read (cache), the index goes on, `check: skipped`, `0 probes`. No `tty`, no `ask`, no install, no `roc:` pin is written (R-H6). |
| 15 | `p15`, `--no-check`, range `>=nightly-2026-10-25-0000000` | Exit 10 as run 6 (D4) |
| 16 | `p16`, `--no-check`, `TALON_AUTO_INSTALL=no`, range `=nightly-2026-10-07-3f4e5d6` | Not refused (no download happens), the list is read, no pin is written |

L2 runs of `px2-install` (the new ones). The state: the compilers of runs 1 to 11 are installed, the list is cached, the `roc` on `PATH` is `nightly-2026-09-01-abcdef0`.

| # | Run | Shows |
| --- | --- | --- |
| 12 | `@roc check p2/main.roc`, a person, Enter, range `>=nightly-2026-10-17-0000000` | The list, one prompt (`nightly-2026-10-18-5349569 (the compiler range) is not installed. Download 1 compiler, 73.0 MB? [Y/n]`), the install, the run |
| 13 | `p3`, `TALON_AUTO_INSTALL=no`, range `>=nightly-2026-10-19-0000000` | `Compiler.failure(NoneInRange)`: no `platform`, no list, no `tty` |
| 14 | `p4`, CI, range `=nightly-2026-10-12-2664a27` | The list is read, then the refusal of the proxy (`ask`, no person) that names the id and `the compiler range`. Exit 13. |
| 15 | `p5`, CI, `TALON_AUTO_INSTALL=yes`, range `>=nightly-2026-10-19-0000000` | No release in the range: exit 10, nothing runs |
| 16 | `p6`, `TALON_NIGHTLY=0`, range `*` | Exit 10, the text names the switch and `TALON_NIGHTLY` |
| 17 | `p7`, `TALON_PROXY=0`, CI, `TALON_AUTO_INSTALL=yes`, range `=nightly-2026-10-10-abcdef0` | The time is `TALON_NOW` (a `clock` call), not 0: the release is visible and is the download. No `.last-use`, no cache variables (R-PX7). |
| 18 | `p8`, `XDG_CONFIG_HOME` is `cfg2` (`min-release-age = "0d"`), `TALON_NOW` 1 hour after the release, CI, `TALON_AUTO_INSTALL=yes`, range `=nightly-2026-10-15-38e6c42` | The age of `config.toml` limits the compiler of the proxy: with the default of 2 days the release would be hidden (exit 10). It is the download. |

L3 parts of `dl3-rank4-download` (`cmd` has the comments). The runner has `CI=true`, so no part has a person. `TALON_NOW=2026-10-15T12:00:00Z`.

| # | Part | Shows |
| --- | --- | --- |
| 1 | `tln verify`, range `>=nightly-2026-10-10-0000000`, empty store | One list request. `min-release-age` hides the 2 newest nightlies: the download is B (`2026-10-12-1b2c3d4`, `572 B`). Exit 13 with the stop. The store is empty. |
| 2 | `TALON_AUTO_INSTALL=no` | Exit 13, the range text, no new request |
| 3 | `--allow-downloads` | One answer line, one download (B only, A is not), the install, 3 probes run B with the cache variables, `.last-use`, `default-roc` is B |
| 4 | no flag, B is installed | No list request, no download, the same 3 probes |
| 5 | `TALON_NIGHTLY=0 --allow-downloads` | Exit 10 names the range, the switch and its source. No download. |
| 6 | the proxy in `p2` (range `>=nightly-2026-10-13-0000000`), `TALON_NOW=2026-10-15T20:00:00Z`, `TALON_AUTO_INSTALL=yes` | `min-release-age` hides A (29 hours old): N (`2026-10-13-0a1b2c3`) is the download, A is not. stdout is only the output of the compiler. |
| 7 | the end state | No temp dir and no lock |

## 6. Old tests that changed

These 4 runs had a range that no installed compiler meets, and they expected the refusal of slice 023. Now that is a download, so each gets `TALON_AUTO_INSTALL=no` (R-DL5, R-DL10: the refusal, as in slice 025 D7). Only the text of the refusal changes in the expected files (read, 1 line each). The `px2-install` expected files only get the new runs (the old lines are the same, checked with `diff`).

| File | Change | Why |
| --- | --- | --- |
| `tests/commands/cases/roc/so1-ranks/fx/runs` (`r4n`), `rules` | The word `auto-install=no` | R-DL10 |
| `tests/commands/cases/resolve/rs-no-compiler/fx/runs` (run 3), `rules` | The word `auto-install=no` | R-DL10 |
| `tests/commands/cases/proxy/px1-flow/fx/commands` (run 14, `p13`), the comment | `env:TALON_AUTO_INSTALL=no` | R-DL10 |
| `tests/scenarios/compilers/so2-ranks/cmd` (`w5`) | `env TALON_AUTO_INSTALL=no` | R-DL10 |
| `expect/stderr` and `expect/stdout` of these 4 cases | The `== ...` line, and the text `no installed compiler is in [toolchain] roc (<range>). TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id> for an id in the range, ...` (the proxy: no `--allow-downloads`) in place of `... This version of tln does not download a compiler for a run.` | 023b Q5 |
| `tests/unit/compiler.roc` | The `failure` row has the new text | 023b Q5 |

## 7. Notes for the code agent

| Item | Note |
| --- | --- |
| `ResolveBase.choose!` | The branch `Err(NoneInRange)` becomes the steps 2 to 5 of section 2. `settings_of` gives `min_age`, `nightly` and `nightly_from`. The `request.downloads` and `request.prompt.yes` facts are in the request. `ranged!` skips the refusal of step 2 when `request.no_check` is true (no probe, so no download: runs 14 to 16). Steps 3 to 5 are the same with `--no-check`. `Start` does not run with `--no-check`, so nothing is downloaded. |
| `RocInstall.range_id!` | It is not a part of `offer!`: `offer!` takes a text (an id, a prefix, `@latest`). Do not make a copy of the list read: use `Nightlies.list!`. It calls `platform` and `Nightlies.list!` only (the `clock` and the `config.toml` are the facts that the caller gives). |
| The second list read | `Start.run!` calls `RocInstall.offer!` with the id. It reads the list again, and the cache gives it (no request). The L2 expected `calls.log` fixes this. Do not pass the offer from `choose!` to `Start`. |
| The proxy | `Loaded` needs `toml_nightly`, `config_nightly` and `min_age` (`config.min_release_age ?? 172800`). With `TALON_PROXY=0` `now` is 0, so the branch calls `Clock.now!`. The `roc` on `PATH` is looked at before the branch (it can meet the range). |
| The order of the checks | `auto_refuses` first (no request), then `snapshot_of`, then the list. A failure of `snapshot_of` in this branch is the usage failure of today. |
| `Compiler.failure` | The new text is for the proxy only. A command that resolves uses `Consent.range_refused` (3 ways, with the flag). |
| Compiler limits that the reference met | `roc build` exits 2 on an unused variable: a mutation that drops the use of a variable must still use it. |

## 8. The optional download: no producer, so it is not here

The brief for this slice asks for the first optional download in the one prompt of R-DL1 (count and size). It has no real producer in P1 today, so the slice lands no code for it (no code with no consumer).

| Fact | Evidence |
| --- | --- |
| An optional download only widens a probe search (R-DL2, R-P5) | CLI 6.2 R-DL2 |
| A command that resolves holds the nightly (R-RP2, R-SO19) and probes on it. Each compiler that a run needs is the held one: a required download (R-DL2, R-BL3). | Slice 025a, slice 017 |
| No code compares compilers: the second search of slice 017 moves variables, not the compiler. `upgrade` (R-UP6) and `tln probe --range` (R-PB3, R-PB4) do not exist. | `cli/lib/`, `docs/slices/PLAN-P1.md` rows 036 to 039 |
| `--probe-downloads` is parsed (slice 025a) and no code reads it. The cap `probe.max-toolchains` is not read by any code (`grep` of `cli/lib`). The probe budget keys are the work of slice 031. | `docs/slices/025-download-consent.md` 8, `Opts.roc` |

Proposal for the plan (the manager decides, `docs/slices/PLAN-P1.md` is the manager file):

| Piece | Goes to | Why there |
| --- | --- | --- |
| The `[probe]` keys (`max`, `timeout`, `slots`, `max-toolchains`) read from `talon.toml` and `config.toml`, R-P5 | 031 (unit probes, the budget) | It reads the other keys of R-P5 |
| The list of candidates that need a download, the cap (R-DL6, `max-toolchains = 0` offers nothing and R-NI4 does not show), the line `skipped N compiler downloads (<size>), pass --probe-downloads` (R-DL4, non-interactive with no flag), `--probe-downloads` and `--yes` inside the cap, and the one prompt of R-DL1 with the count and the total size of the required and optional downloads | 036 (the oracle loop: the first loop whose `Need` names probes on compilers that are not installed) | The first slice that has the facts (candidates, sizes from the list) and the consumer |
| The same function for `tln probe --range`, and for `upgrade` (R-UP6: "all other compiler downloads are optional probe downloads") | 037, 038, 039 | They call the function of 036 |

The prompt of slice 025a already takes `count` and `size`. Question for slice 036, not for this one: with one prompt (R-DL1) for a required download and optional ones, how does a person accept the required download and refuse the optional ones? R-NI4 and R-NI5 are two prompt rows with two kinds. The design does not say. (It is not blocking for 025b.)

## 9. Out of scope

| Id | Reason |
| --- | --- |
| R-DL6, R-NI4 (prompt and skipped line), R-P5 (cap) | Section 8: no producer. R-NI4 is named in the tests of slice 025a for the flag only. |
| `tln upgrade` and `tln roc use` baseline downloads (R-U3, R-NI12) | Slices 026, 038, 039 |
| `tln roc update`, `@latest` (they use `Nightlies.pick`, not the range) | Slice 026 |
| The `log:` form of the snapshot for compilers (Registry 3) | P2 (R-C7). The time form is in this slice. |
| A release from a source other than `roc-lang/nightlies` | R-CV1: Talon knows no source of compiler releases yet. `range_pick` is generic, and the L0 rows have releases. |

## 10. Decisions that the design does not state, with the rejected options

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The list is read at the selection (`choose!`), because the id of the held compiler must be known before the index and before any write (R-SO19). The download is at the first probe (R-SO22). The list is read again in `Start.run!` (from the cache). | A download in `choose!` (breaks R-SO22 and the one prompt). Pass the `Offer` from `choose!` to `Start` (a new field in `Loaded` and `Ladder.Request`, for no request saved). |
| D2 | The proxy downloads too (R-NI5 and R-DL8 name it, and 023b Q5 left it for this slice). `Compiler.select` and `Toolchain.range_pick` are shared. | The proxy keeps the refusal (a different rule for one rank). |
| D3 | `TALON_AUTO_INSTALL=no` with no flag refuses before the list (the id is not known, so no request). A new pure function `Consent.auto_refuses`. | Read the list first and refuse with `download_refused(<id>)` (a request for a run that refuses). A copy of `required_want` row 2 in two callers. |
| D4 | No release in the range in the list: kind `NoTuple` (exit 10), as R-NS2 and R-SO19 give for a compiler that the switch or the range does not admit. With the switch off the text names the switch and its source (R-NS2). | Exit 13 (a refusal is not what this is). Exit 18 (the fix is not on the machine). |
| D5 | `min-release-age` and the snapshot limit the pick (R-NS3 lists rank 4, R-C7). An installed compiler in the range is used as it is, whatever its age (it costs nothing, R-P5). | No limit (a 2-hour-old nightly would be the download). |
| D6 | The refusal text of the commands names 3 ways (the range, `tln roc install <id>` for an id in the range, `--allow-downloads`, `TALON_AUTO_INSTALL=yes`) as slice 025 Q4. The proxy text has no flag (the proxy has none). | One text for both (names a flag that the proxy does not have). |
| D7 | `RocInstall.range_id!` takes facts (time, age, snapshot, switch) from the caller. The caller has them already (`settings_of`, the proxy `Loaded`). | The function reads the clock and `config.toml` again (as `offer!`): two more calls, and a wrong source for the switch (`talon.toml` is not read by `offer!`). |
| D8 | The old refusal tests keep their meaning with `TALON_AUTO_INSTALL=no` (as slice 025 D7). | A list and a person in each old case. |
| D9 | With `--no-check`, `TALON_AUTO_INSTALL=no` does not refuse (the refusal is of a download, and none happens). A consequence of Q1, option a. | Refuse as for a run with a check. |

## 11. Questions (TW17)

| # | Question | Answer (manager, 2026-10-23) |
| --- | --- | --- |
| Q1 | `--no-check` with a rank 4 range and no installed compiler in it (025 Q3) | Option a. See the review. L2 runs 14 to 16. |

## 12. Output proposals (TW24, for the review)

| Where | Proposal |
| --- | --- |
| The refusal of a command (`TALON_AUTO_INSTALL=no`, no flag), exit 13, kind `consent` | `no installed compiler is in [toolchain] roc (<range>). TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id> for an id in the range, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.` |
| The refusal of the proxy (`Compiler.failure(NoneInRange)`), exit 13, kind `consent` (the 023b Q5 text fix) | `no installed compiler is in [toolchain] roc (<range>). TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id> for an id in the range, or set TALON_AUTO_INSTALL=yes.` |
| No release in the range, exit 10, kind `no_tuple` | `no compiler release is in [toolchain] roc (<range>)` |
| The same with the switch off, exit 10, kind `no_tuple` | `no compiler release is in [toolchain] roc (<range>), and nightly is false (set by TALON_NIGHTLY)`. The source text is that of `Pin.source_text`: `[toolchain] nightly in talon.toml`, `nightly in config.toml`, `the default`. |
| The prompt, the stop and the answer line of a rank 4 download | The texts of slice 025 (section 12 of that file). No new text. The proxy prompt names the source `the compiler range`: `<id> (the compiler range) is not installed. Download 1 compiler, <size>? [Y/n]`. |
| `--json` | No new `data` field. `data.downloads` is the count of slice 025 (1 after a rank 4 download). |

## 13. Red output (the stub tree)

`scripts/test.sh` on the stub tree (the stubs are `research/slice-025b-revert/stubs/`). check and fmt pass. The failures are the new tests, and the 4 old runs and the 1 L0 row whose expected text changed (section 6).

| Step | Result | Seconds | Budget | Failures |
| --- | --- | --- | --- | --- |
| check | pass | 4.1 | 10 | |
| fmt | pass | 0.1 | 5 | |
| l0 | FAIL | 6.3 | 10 | `toolchain.roc`: `range_pick` and `range_failed` crash with `todo`. `consent.roc`: `auto_refuses`, `range_refused` (`todo`). `compiler.roc`: `failure` (the old text). 3 of 58 files. |
| l2 | FAIL | 9.0 | 30 | 5 of 53: `consent/dl3-rank4` (run 1 gives exit 13 in place of 15, the other runs refuse), `proxy/px2-install` (run 12 gives exit 13), and the old `roc/so1-ranks`, `resolve/rs-no-compiler`, `proxy/px1-flow` (the refusal text only). 48 pass. |
| l3 | FAIL | 9.4 | 60 | 2 of 45: `compilers/dl3-rank4-download`, `compilers/so2-ranks` (the refusal text only). 42 pass, 1 skipped as today. |
| selftest | pass | 3.8 | 20 | |

With the private reference all steps pass (check 3.6 s, fmt 0.1 s, l0 6.3 s, l2 7.7 s, l3 9.2 s, selftest 5.3 s). The budgets hold (TW26): check 10, l0 10, l2 30, l3 60, selftest 20.

## 14. Revert check (TW12)

`research/slice-025b-revert/mutate.py` made one change in the private reference (which is kept in `research/slice-025b-revert/reference/`, deleted in the review), ran `roc check`, then only the tests that should catch it (`mutate.out`: L0 first; `mutate-deep.out`: L2 and L3 only, to show that the deep cases catch a change without the unit tests). 37 changes (3 added for the answer to Q1: N1 to N3). 36 are caught by the test run. The deep cases alone catch 34 of 37. The 2 that only L0 catches are pure rows with no command that shows them: the order of 2 nightlies of one day (T6, the fake list has no 2 nightlies of one day) and a release with no asset for the host (T7, each fake release has an asset). The 1 that nothing catches is equivalent (B7): the `from` of the held compiler is `Range` or `Path`, and the gate passes for both because the id is in the range by construction.

| Group | Changes | Caught by |
| --- | --- | --- |
| `Toolchain.range_pick` (T1 to T7) | age, snapshot, switch, range, oldest, order of one day, no-asset | L0 `toolchain`. L2 for T1 to T5 |
| `Toolchain.range_failed` (T8, T9) | kind, the switch in the text | L0, L2 |
| `Consent.auto_refuses`, `range_refused` (C1 to C5) | `--yes`, `--allow-downloads`, flags over the variable, a run with no variable, the flag in the text | L0 `consent`, L2 `dl3-rank4` |
| `Compiler.failure` (K1) | the old text | L0 `compiler`, L2 |
| `RocInstall.range_id!` (R1, R2) | `--offline` with no cached list, the range text | L2 `dl3-rank4` |
| `ResolveBase.ranged!` (B1 to B10, N1 to N3) | no refusal for `no`, the flag, `--yes`, the snapshot, the age, the source of the switch, the range text, `--offline`, the held compiler, `--no-check` refused by `no` (N1), `--no-check` keeps exit 13 (N2), `--no-check` holds no compiler (N3) | L2 `dl3-rank4` (B3, `--yes` over the variable, has its own run 11). B7 is equivalent. |
| `Proxy.ranged!` (P1 to P7) | no refusal for `no`, the time of `TALON_PROXY=0`, the age (L3 part 6), the switch, the source text, the range text, `min-release-age` of `config.toml` | L2 `proxy/px2-install`, L3 |

Two mutations did not compile at first (an unused variable gives exit 2): they keep the variable in use now (`research/slice-025b-revert/mutate.py` has the final text).

## 15. Review (manager, 2026-10-23)

D1 to D8, the output proposals and the old-test changes are accepted. The plan change for the optional download is accepted (the manager updates `PLAN-P1.md`: the `[probe]` keys with `max-toolchains` go to 031; the optional list, the cap R-DL6, the skipped line, and the combined prompt R-NI4/R-DL1 go to 036).

Q1: option (a). With `--no-check`, rank 4 with nothing installed reads the list (cache rules as usual), holds the newest allowed release in the range for the index (R-SO19), downloads nothing and writes no pin (R-H6), as a held pin that is not installed needs no compiler with `--no-check` (R-SO22). No release in range: exit 10 as D4.

Done by the test agent after the review: L2 runs 14 to 16 of `consent/dl3-rank4` pin this (D9: `TALON_AUTO_INSTALL=no` does not refuse a `--no-check` run). No pure function changed, so no new L0 row. The reference was updated, all tests passed with it (check 4.1 s, fmt 0.1 s, l0 6.3 s, l2 8.4 s, l3 9.3 s, selftest 3.8 s), the 3 new mutations were run (section 14), and `research/slice-025b-revert/reference/` is deleted. `mutate.py` and `mkstubs.py` need a green tree and the reference, so they cannot run again. `scripts/test.sh` on the stub tree is red as in section 13: l0 3 files, l2 5 of 53, l3 2 of 45 (the new run 14 to 16 fail with the stubs because `choose!` still refuses).

## 16. Code result (code agent, 2026-10-23)

The 6 stubs and the old text are replaced. `scripts/test.sh` exits 0 (section 17). No test, fixture or expected file was changed (no dispute rows).

| File | Lines (now) | Change |
| --- | --- | --- |
| `cli/lib/Toolchain.roc` | 401 | `range_pick` (candidates, `Nightlies.visible`, the switch, `Pin.admits`, the newest by `Pin.order`), `range_failed` |
| `cli/lib/Consent.roc` | 286 | `auto_refuses`, `range_refused` |
| `cli/lib/RocInstall.roc` | 371 | `range_id!` (`Toolchain.host`, `Nightlies.list!`, `range_pick`). No copy of the list read. |
| `cli/lib/Compiler.roc` | 243 | The body of `failure(NoneInRange)` has the new text |
| `cli/lib/ResolveBase.roc` | 559 | New `ranged!` (steps 2 to 5 of section 2). The branch `Err(NoneInRange)` of `choose!` calls it. Under 600, no split. |
| `cli/lib/Proxy.roc` | 484 | `Loaded` has `toml_nightly`, `config_nightly`, `min_age`. New `ranged!` (the refusal, `Clock.now!` for `TALON_PROXY=0`, `Pin.switch`, `RocInstall.range_id!`). The id is `Missing` with the rank `Range`. |

Decisions that section 10 does not fix:

| Item | Choice | Rejected |
| --- | --- | --- |
| `now` for `Nightlies.list!` in `range_id!` | The `now` of the caller (`request.now`, the proxy `now`), for the cache of the list and for the age | A second `Clock.now!` for the cache. `offer!` passes the real clock to the cache, but the L2 `calls.log` has no extra `clock` call here. The tests pass with the caller `now`. |
| `loaded.intent.toolchain.roc` is `Err(Unset)` in `ranged!` | `Any` (the branch cannot happen: `Compiler.select` gives `NoneInRange` only with a range) | `crash`, a failure |
| Position of the `--no-check` test | In the refusal row only (`refused and !request.no_check`). Steps 3 to 5 are the same. | Skip the whole branch (the list is needed for the index, Q1) |

## 17. Verify results (code agent, 2026-10-23)

| Step | Result | Seconds | Budget |
| --- | --- | --- | --- |
| check | pass | 4.7 | 10 |
| fmt | pass | 0.1 | 5 |
| l0 | pass | 6.6 | 10 |
| l2 | pass | 10.1 | 30 |
| l3 | pass | 9.3 | 60 |
| selftest | pass | 3.7 | 20 |

`OPT=speed scripts/test.sh`: all steps pass (l2 74.2 s, over its budget of 30 s with the LLVM build: a WARN only, as TW26 allows for `OPT=speed`).

Revert check (`research/slice-025b-revert/code-mutate.py`, results in `code-results.md`): 48 small mutations, 44 caught, 4 not caught. Before each mutation the 6 code files were restored from `research/slice-025b-revert/code-final/`. At the end the 6 files are the same as `code-final/` (`cmp`).

| Not caught | Kind | Short reason |
| --- | --- | --- |
| B7 `from: Range` to `from: Path` in `ResolveBase.ranged!` | Equivalent | The gate of `Path` checks the range and the switch that `range_pick` already holds |
| P8, P9 the proxy ignores `nightly` of `talon.toml` or `config.toml` for the pick | Test gap | `px2-install` run 16 uses `TALON_NIGHTLY=0` only |
| P11 the proxy reads the list with `offline: true` | Test gap | The list is cached in each proxy run with a range |

The test gaps are for the manager and the test agent (the code agent does not edit tests, TW18). Details and proposals in `research/slice-025b-revert/code-results.md`.

## 18. Gap rows (test agent, 2026-10-23)

The code check (section 17) found 3 test gaps. The test agent added 3 runs to `tests/commands/cases/proxy/px2-install/` (now 21 runs). No code file was changed. Rule ids: R-NS9 and R-NS10 are added to `rules`.

| Run | Input | Expected | Shown mutation |
| --- | --- | --- | --- |
| 19 | `p9`: `[toolchain] roc = "*"` and `nightly = false` in `talon.toml`. `CI`, `TALON_AUTO_INSTALL=yes` | Exit 10, text names the range and `[toolchain] nightly in talon.toml`, nothing installed | P8 |
| 20 | `p10`: range `*`, config dir `cfg3` with `nightly = false` | Exit 10, text names `nightly in config.toml` | P9 |
| 21 | `p4`: exact range, `HOME=home2` (no compiler, no cached list), `CI` | One `http_get` for the list, then the refusal of run 9, exit 13 | P11 |

Revert check by hand (one change in `cli/lib/Proxy.roc` each, `tests/commands/run.sh proxy/px2-install`, then the file restored):

| Id | Change | Result |
| --- | --- | --- |
| P8 | `toml: loaded.toml_nightly` to `toml: Err(Unset)` | FAIL (run 19) |
| P9 | `config: loaded.config_nightly` to `config: Err(Unset)` | FAIL (run 20) |
| P11 | `offline: Bool.False` to `offline: Bool.True` in `ranged!` | FAIL (run 21) |

After the 3 changes `cmp` and `sha256sum -c research/slice-025b-revert/code-final.sha256` show the 6 code files equal to `code-final/`. `scripts/test.sh` exits 0 with no WARN (check 5.0 s, fmt 0.1 s, l0 6.3 s, l2 9.3 s, l3 9.3 s, selftest 3.9 s). Revert result of section 17: 47 of 48 are now caught. Only B7 (equivalent) is not.

## Close (manager, 2026-10-23)

The code agent decisions are accepted. P8, P9 and P11 are caught by the gap runs. B7 is equivalent. `scripts/test.sh` exits 0 with no WARN. Status: done.
