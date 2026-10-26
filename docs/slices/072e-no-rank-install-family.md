# 072e No rank: install family, relative selector, proxy, `roc use`, `init`

Phase: P1. Status: done

Slice 072e is the plan row 072e of `PLAN-P1.md` (section 2c). It follows 072d (the core: `check_pin`, `HeldRoc`, `verify`, `probe`, `roc use` with step (b)). The design answers are in `DESIGN-GAPS-2026-10-26.md`, "Questions of slice 072d" (Q-D2 to Q-D5), and in the rules R-SO19, R-SO22, R-SO23, R-SL7, R-PX4, R-U3. The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files are in `research/slice-072e-revert/before/` (the private reference and the mutation scripts are deleted, after the review of 2026-10-26).

Review of 2026-10-26: the user added the rule R-SO24 (a compiler is always selected, `DESIGN-GAPS-2026-10-26.md`). "No compiler is selected" now means that nothing is installed. The steps (a) and (b) of R-SO14 are gone. This slice keeps only the behavior with nothing installed. The runs with installed compilers and no `default-roc` moved to slice 080 (section 12).

## 1. Size and split (proposal for the manager)

The slice has 5 parts. The private reference changes about 260 lines of code (without comments) in 14 files, so it is at the limit. If the code agent finds the slice too big, the parts can go in this order. Each part has its own cases.

| Part | Cases | Depends on |
| --- | --- | --- |
| A. Install family pick (Q-D2), the rule of a plain `install` (Q-E1), `upgrade` (Q-E2), `init` (Q-D6) | `install/in2-nocompiler`, `upgrade/ur7-nocompiler`, `init/it4-nocompiler`, `roc/so9-no-roc`, `roc/so9-hash-fails`, `resolve/rs-no-compiler` | none |
| B. The base of a relative selector (Q-D3, Q-E3) | `roc/bs2-no-pin`, `roc/bs3-range`, L3 `compilers/bs1-base-ranks` | the pure part of `NoRank` in a leaf module (see 4) |
| C. `roc use` with the pick and the new compiler both missing (Q-D5) | `roc/us5-both-missing` | part A (the pick as an id) |
| D. The proxy (Q-D4) | `proxy/px5-no-rank`, `proxy/px1-flow`, `tool/dl1-sweep`, L3 `compilers/px1-proxy` | part B (the hashes of the target header) |

## 2. Rules

| Rule | Text (short) | Where |
| --- | --- | --- |
| R-SO14, R-SO24 | No compiler is selected only when nothing is installed (no `roc` on `PATH`, no `default-roc`, no pin, no range, no `.roc-version`). The pick is the newest compiler in the channel with a recorded pass for each header hash that has a fact (at least one hash needs a fact), else the latest in the channel. A download makes the default. | `NoRank`, `Start`, `Proxy`, `RocUse`, `NightlyFlow` |
| R-SO19 | No pin and no compiler selected: the held nightly is the pick, before the index and before any write, only when a probe will run. `--no-check`, `--frozen` and `tln install` with no name whose `--frozen` check passes (R-LF1: the header satisfies `talon.toml`) pick nothing and need no compiler. The pick is an id. Its download is the first probe (R-SO22). R-RP3 writes it as the pin after the check passes. | `InstallFlow`, `RemoveFlow` |
| R-SO22, R-BL6 | The download is at the first probe. `--no-check` and `--frozen` run no probe. | `Start`, the flows |
| R-SO23 | Rows: install, add, remove, update, upgrade (two steps: the pass, the latest), the proxy (the same, no probe), a relative selector (the same, as an id only; with a range and no installed compiler in it: the newest release in the range). | the flows, `Proxy`, `RocInstall.offer!` |
| R-SO15, R-SO24 | A download that the command makes sets `default-roc` only when none is set. | `Start`, `Proxy`, `RocUse`, `NightlyFlow` |
| R-SL7, R-SO13 | With none selected, the base of `@-N` and `@+N` is the pick as an id (no download, no default). With a range of `talon.toml` and no installed compiler in it, the base is the newest release in the range, as an id (Q-E3). | `RocInstall.offer!`, `Base.selected!` |
| R-PX4, R-PX2, R-PX3 | The proxy has no hidden probe. It gets the hashes from the header of the target file. It prints no default-compiler line. | `Proxy` |
| R-U3 | `roc use <id>`: one prompt for the pick (the baseline) and the new compiler. The pick downloads first and becomes the default. | `RocUse` |
| R-UP6 | `upgrade` with the nightly free and no compiler: the pick is also the newest nightly. One download, one prompt (R-NI12, default yes). It becomes the default (Q-E2). | `NightlyFlow` |
| R-IN2, R-IN4 | `init` checks the template and writes the `roc:` pin, also when nothing moves. | `Init`, `InstallFlow.finish!` |
| R-SP21, R-LF1, R-EC18 | A plain `install` with no `talon.toml` resolves nothing. `--frozen` runs no probe. Exit 18 for "no compiler" is P0 only. | `InstallFlow` |

## 3. What the code does today

| Part | Today |
| --- | --- |
| `install`, `update`, `add`, `upgrade`, `remove` with checks, no compiler | `check_pin` stops with exit 18 (role `Lock`), also for a plain `install` that resolves nothing |
| `roc install @-N` with none selected | `Base.selected!` gives no base: exit 18 |
| The proxy with none selected | exit 18 |
| `roc use` with the pick missing | `RocUse.fallback!` calls `HeldRoc.held!`: the pick downloads at once, before the prompt of step 7, and the new compiler has its own prompt |
| `upgrade roc` with nothing installed | exit 18 (the same `check_pin` stop) |
| `roc install @-N` with a range and no installed compiler in it | exit 18 (`NoneInRange` is a failure of the step) |
| `init --platform` with the downloaded compiler already the newest | `nothing to change`: no ladder, no `+ roc:` (question Q-D6, cause in section 8) |

## 4. Where the code changes (for the code agent)

The reference was a proposal (it is deleted now). The code agent may choose another shape. The `calls.log` files fix the order of the calls. The reference had a few hacks that a real shape must replace (marked here). The steps (a) and (b) of `NoRank` stay in the code until slice 080: no test of this slice reaches them.

| # | Place | Change |
| --- | --- | --- |
| 1 | `NoRank` (new `pick_id!`) | The pick as an id: the installed list, then the id of `offer!`. No gate, no download, no default. |
| 2 | `HeldRoc.picked!` (new) | `pick_id!` for a command that holds the nightly. |
| 3 | `InstallFlow.install_with!` | After `ResolveLoad.prepared!`: when `decision.held` is `Err(NoCompiler)` and the run can probe (`will_probe`): `HeldRoc.picked!`, then `Pin.decide` again with the id as `loaded.selected` (reference: `ResolveLoad.decide`, rank `Default`). `will_probe` is false for `--no-check`, for `--frozen`, and for a plain `install` with no names that has no `talon.toml` or whose `--frozen` check passes (Q-E1 (a): the pure `Frozen.check` over `Vars.scope`, `built.wants` and the decision). `check_pin` gets `LockNoCheck` when no compiler is held and no probe will run. `request.selected` stays `""` (the compiler before the pick), so the first probe knows that no compiler was selected. |
| 4 | `RemoveFlow.remove!` | The same, when the check runs (`skip_check` is false). |
| 5 | `Start.offered!` (first probe) | When no compiler was selected: the prompt and the answer line of `NoRank.prompt`, the refusal text of `NoRank.gate`, and `RocInstall.first_default!` after the download. Hack in the reference: the marker `("TALON_PICKED", "1")` in `Start.Downloads.env`, set by `ResolveBase.ladder_downloads` when `request.selected == ""`. |
| 6 | `RocInstall.offer!`, `Base.selected!` | For a relative selector with none selected: the base is the pick as an id, with the hashes of the header of `main.roc` (`Base.Loaded` gets `hashes`; `Base.selected!` gives `{ base, hashes, pick, range }`). With a range and no installed compiler in it (`NoneInRange`): `Toolchain.range_pick` over the list gives the base (Q-E3). `NoRank` imports `RocInstall`, so the pure `pick`, `first` and `keys` go to a leaf module (reference: `NoRankPure`, copies). `NoRank.pick`, `first` and `keys` stay as they are: the L0 tests call them. |
| 7 | `Proxy.go!` | `Err(NoCompiler)`: the pick as an id with `loaded.hashes` (scope `Outside` when there are no hashes). The result has the rank `Picked` (new, text `no compiler is selected`). The existing `install_missing!` follows the consent rules of the proxy. After the download: `first_default!`. |
| 8 | `RocUse.fallback!`, `install_all!` | The pick is an id (`HeldRoc.picked!`). It is a missing baseline, so it joins the one prompt (`DownloadAsk.required!`), is first in the list and in the downloads, and is the default after its download. |
| 9 | `init` (`Update.request_of`, `InstallFlow.finish!`) | The new header is a change: the pin is a held move (`moved`), so `checked` has it and the ladder runs. Hack in the reference: the marker `request.add.as_alias == Ok("@init")` set from `args.typed == "init"`. |
| 10 | `NightlyFlow.known!` (Q-E2) | When `request.selected == ""` and the downloaded compiler is the held nightly (it is also the newest): `RocInstall.first_default!` after its download. The single prompt is `Consent.roc_install` with the question ending `It becomes the default compiler.` and the answer line ending `, the default compiler` (reference: `Consent.roc_install_default`). A pick that is another compiler than the newest: the existing `DownloadAsk.required!` prompt for both (the pick first), the pick is the default. Not tested. |

Types that the L2 test app builds, and that the code agent must not change (a change breaks the compile of the tests, TW18): `Start.Downloads`, `NoRank.Run`, `NoRank.Probing`, `Fetch.Unbundler` (`tests/commands/main.roc`, `L2NoRank.roc`) and `ResolveBase.Request` (`L2Resolve.roc`). Each module stays at or under 490 lines (`RocInstall` has 446 lines today).

## 5. Tests

All are L2 (entry `commands`) unless the row says L3. No L0 change. Each home (h1, ...) has its own project (n1, ...), so facts and installed compilers of one run do not touch another run. In every run of this slice nothing is installed and no `default-roc` is set (R-SO24: no compiler is selected). The fixtures: the toolchains and the facts of `verify/vn1-nocompiler` (N1 `nightly-2026-10-14-38a3029`, N2 `nightly-2026-10-16-1df370f`, N3 `nightly-2026-10-18-5349569`, N4 `nightly-2026-10-19-0badf00`, the newest in the list).

### 5.1 New cases (4 cases, 18 runs)

| Case | Runs | Content | Rule ids |
| --- | --- | --- | --- |
| `install/in2-nocompiler` | 7 | Run 1 `update json`, no fact: the order is the pick (N4), the index, the download at the first probe, `default-roc`, the probes, `+ roc: N4`. Run 2 `TALON_AUTO_INSTALL=no`: exit 13 after the index, no write. Run 3 `--no-check`: no list of compilers, no download, no pin. Run 4 `remove json`: as run 1. Run 5 `install --frozen` with a `talon.toml`: no pick. Run 6 `update json` with facts for N1 and N2: the pick is N2, not N4. Run 7 plain `install` with a `talon.toml` that the header satisfies (Q-E1 (a)): no pick, `nothing to change`. | R-SO19 R-SO22 R-SO23 R-SO24 R-SO14 R-SO15 R-RP3 R-BL6 R-H6 R-DL2 R-DL5 R-LF1 R-SP21 R-P5 R-PP4 |
| `upgrade/ur7-nocompiler` | 2 | `upgrade roc`, nightly free, no pin, nothing installed (Q-E2). Run 1 (Enter): one `ask` (`Download 1 compiler, <size>: <N>? It becomes the default compiler.`), one download, `default-roc` is written, `nothing to change` (a missing `roc:` pin alone is no change, R-RP3). Run 2 (`n`): exit 13, nothing downloaded, no default. | R-UP6 R-NI12 R-SO14 R-SO23 R-SO24 R-SO15 R-DL1 R-DL3 R-RP3 |
| `roc/us5-both-missing` | 4 | `roc use <N1>` with nothing installed: the pick N4 and the new compiler N1 are missing. Run 1 (Enter): one `ask` that names N4 and then N1, N4 downloads, `default-roc` is written once, N1 downloads. Run 2 `TALON_AUTO_INSTALL=yes`. Run 3 `TALON_AUTO_INSTALL=no`: exit 13. Run 4 no answer: exit 13, 2 downloads. | R-U3 R-SO14 R-SO23 R-SO15 R-DL1 R-DL3 R-DL5 R-NI5 R-BL1 R-RP3 |
| `proxy/px5-no-rank` | 5 | `roc check` with nothing installed. Run 1 facts for N1 and N2 in the target header hashes: N2 downloads (not N4), `default-roc`, `exec`. Run 2 no target file: the latest (N4). Run 3 `TALON_AUTO_INSTALL=no`: exit 13. Run 4 a person (Enter): one prompt, default yes. Run 5 no person, no answer: exit 13. | R-PX4 R-SO14 R-SO23 R-SO24 R-SO15 R-DL1 R-DL3 R-DL8 R-DL9 R-DL10 R-NI5 R-PD7 |

### 5.2 Changed cases (they were green with exit 18 or `nothing to change`; the expected files change)

| Case | Change | Rule ids |
| --- | --- | --- |
| `init/it4-nocompiler` (Q-D6) | The expected result is the one of `init/it2-platform`: `check: passed`, `build: passed`, `+ roc: <id>`, `resolved at ..., 4 probes`, the ladder in `calls.log`, the pin in `main.roc`. | R-IN2 R-IN4 R-SO14 R-SO15 R-SO23 |
| `roc/so9-no-roc`, `roc/so9-hash-fails` (2 runs), `resolve/rs-no-compiler` run 1 | Old: exit 18. New: a plain `install` with no `talon.toml` resolves nothing, so no pick and no compiler: `nothing to change`, exit 0. The packages of the header are now in the cache of the homes (no unbundle). | R-SO19 R-SP21 R-SO9 R-EC18 |
| `roc/bs2-no-pin` (Q-D3) | Run 2 (`@-2`, nothing installed): the base is the latest in the channel as an id, the compiler installs (the first install is the default). New run 5 (home3): a fact says pass for the header hash on 2026-10-16, which is not the newest: the base is 2026-10-16, `@-1` is 2026-10-15. New `fx/jobs`, `given/home3`. | R-SL7 R-SO14 R-SO23 R-SO24 |
| `roc/bs3-range` run 2 (Q-E3) | The range has no installed compiler (home2: only 2026-10-12, the default, is below it). Old: exit 18. New: the base is the newest release in the range, 2026-10-18, as an id with no download. A fact for 2026-10-16 must not change the base. `@-6` is 2026-10-12, installed: `already installed`, exit 0. New `given/home2/.config/talon/config.toml` and `compat.tsv`. | R-SL7 R-SO13 R-SO4 |
| `proxy/px1-flow` (Q-D4) | The run with `TALON_IN_PROXY=1` and no compiler: exit 13 (the pick is a download that no person agrees to) in place of exit 18. New `fx/http` (the list). | R-PX4 R-EV17 R-SO23 |
| `tool/dl1-sweep` run 5 | The run `@roc --version` (no compiler) is now `@roc +nightly-2026-10-14-38a3029 --version` with `CI=true`: the sweep before the proxy is the rule of the run, not the compiler choice. Green with the old code. The proxy with no compiler is in `px5-no-rank`. | R-ST10 R-ST8 R-DL8 |
| L3 `compilers/bs1-base-ranks` run 9 | The base is the latest in the channel (2026-10-15): `@-1` installs 2026-10-14, the first install is the default. | R-SL7 R-SO14 R-SO23 |
| L3 `compilers/px1-proxy` (2 runs) | `TALON_IN_PROXY=1`, no compiler: exit 13 in place of exit 18. New `given/http` (the list). | R-PX4 R-EV17 R-SO9 |
| L3 `compilers/so9-launcher` | The last 2 runs end with `no download program: curl and wget are not on PATH` (exit 18, R-EC18): the fetch of the missing packages needs a compiler and the sandbox has no `curl`. | R-SO9 R-EC18 R-FE4 |

### 5.3 Cases that stay in the tree and are not part of this slice

| Case | State |
| --- | --- |
| `verify/vn2-step-b-project` | Green. It tests step (b), which R-SO24 removes. Not in the red state. Slice 080 deletes it (section 12). |

## 6. Output (proposed, TW24; the manager accepted all on 2026-10-26)

| Item | Proposal |
| --- | --- |
| Install family, first probe with a pick that is not installed | stderr line `downloading <id> (<size>), the default compiler` (the text of slice 072b, `NoRank.prompt` answer line). The prompt text is `NoRank.prompt`. |
| The same, `TALON_AUTO_INSTALL=no` | exit 13, `no compiler is selected. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install @latest, then tln roc default <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.` (the text of `NoRank.gate`) |
| The pick as an id (header, `--no-check`, relative selector base) | No line. |
| `upgrade` with the nightly free (Q-E2) | The prompt `Download 1 compiler, <size>: <N>? It becomes the default compiler. [Y/n]`. The answer line `downloading <N> (<size>), the default compiler`. (New in the review. The design says that the prompt adds the line `It becomes the default compiler.`; the place of the line is a proposal.) |
| `roc use`, the pick and the new compiler | The prompt of `Consent.use_download` with the pick first: `Download 2 compilers, <size>: <pick>, <new>? [Y/n]`. The answer line `downloading 2 compilers (<size>)`. The refusals are the existing texts (`download_refused`, `download_stop`). |
| Proxy with a pick | The refusal `the compiler <id> (no compiler is selected) is not installed. Run: tln roc install <id>, or set TALON_AUTO_INSTALL=yes.` The prompt `<id> (no compiler is selected) is not installed. Download 1 compiler, <size>? [Y/n]`. The answer line `downloading <id> (<size>)`. No default-compiler line (R-PX3). |
| `init` | The output of `init/it2-platform`. |
| `--json` | No new `data` field. |

## 7. Out of scope

| Item | Reason |
| --- | --- |
| `add` with no compiler | It uses the same flow as `update` (`InstallFlow.install_with!`). It needs a new package fixture. |
| `upgrade` when the pick is not the newest nightly (one prompt for both, the pick first) | With nothing installed the pick is the latest, so the newest nightly is the pick. The case needs a range or a switch that moves one of them. Not tested. |
| `tln install` with a `talon.toml` that the header does not satisfy | It picks like `update` (Q-E1 (a)). The tests have only the satisfied case (run 7 of `in2`) and `--frozen`. |
| `probe.max` shared between the pick and the probes of the install family | With the step (b) gone (R-SO24), the pick spends no probe. |
| `--offline` with a pick that is not installed | The design says nothing about the pick and `--offline`. The reference gave exit 15 (`offer!`). No case. |
| The crash between the write of `default-roc` and the final rename (R-SO24 case 4) | The tests cannot crash the fake Fx at a call. Slice 080. |

## 8. Findings

| Item | Result |
| --- | --- |
| Q-D6, why `init/it4-nocompiler` showed `nothing to change` | The compiler of `init` is the one that the fetch downloaded (the default, the newest nightly). The start platform release is the newest too. So the resolve of `upgrade` has no change and no move of the nightly. R-RP3 writes the pin only for another change, so the old code ran no ladder and wrote no pin. R-IN2 and R-IN4 need the check and the pin for the new header. In `it2-platform` the compiler on `PATH` is older, so the nightly moves and the ladder runs. The tests fix the result of `it2-platform` for `it4`. |
| `HeldRoc.held!` and `--no-check` (Q-D2, 072d close) | It agrees. `held!` has no role. Its callers (`VerifyFlow`, `ProbeFlow`, `RocUse`) never call it with `--no-check`. `check_pin` with `LockNoCheck` is `Ok` for no compiler, so the install family picks nothing. `install/in2-nocompiler` run 3, `remove/rm3-nocompiler` and `verify/vn1-nocompiler` run 5 test it. |
| `upgrade roc` with no pin and nothing installed (Q-E2) | The result is one download, the default, and `nothing to change` (R-RP3: a missing pin alone is no change). The compiler is not written as a pin. This follows the rules. If the user wants `+ roc:` here, it is a design change. |
| Gap of mutation c5 (`vn2`) | Moot. Step (b) is removed by R-SO24. Slice 080 deletes `vn2`. |
| Proxy with installed compilers that have no fact | Moot (R-SO24: such a state is not allowed). Slice 080. |

## 9. Questions (TW17)

All three questions of the test step are decided (manager, 2026-10-26, `DESIGN-GAPS-2026-10-26.md` "Questions of slice 072e"). No open question.

| Id | Decision | Test |
| --- | --- | --- |
| Q-E1 | (a): a plain `install` with no name whose `--frozen` check passes picks nothing. Else it picks. | `in2` run 7 (the pick case: no test) |
| Q-E2 | (a): one download, one prompt (R-NI12, default yes), when the pick is the newest nightly. It becomes the default, with the line `It becomes the default compiler.` | `ur7` |
| Q-E3 | (a): the base is the newest release in the range, as an id, with no download. | `bs3-range` run 2 |

## 10. Red output

With the old code (`cli/lib` as before the slice), `scripts/test.sh` gives (the other slices are in the tree and pass):

| Step | Result |
| --- | --- |
| check, fmt, l0, selftest, l1 | pass (no `.roc` file changed) |
| l2 | FAIL, 11 of 205 cases (194 pass) |
| l3 | FAIL, 3 of 84 cases (81 pass, 3 skipped) |

| Case | Old result (wrong value, not a crash) |
| --- | --- |
| `init/it4-nocompiler` | `nothing to change` in place of the ladder and `+ roc:` |
| `install/in2-nocompiler` | runs 1, 2, 4, 6 and 7: exit 18 in place of the update, the refusal 13 and `nothing to change`. Runs 3 and 5 pass: they guard `--no-check` and `--frozen` (a green regression guard). |
| `upgrade/ur7-nocompiler` | exit 18 in place of the prompt, the download and `nothing to change` (run 1), and in place of exit 13 (run 2) |
| `roc/us5-both-missing` | the pick downloads before the prompt, two prompts, so the `ask` lines, the order and the texts differ |
| `proxy/px5-no-rank` | all 5 runs: exit 18 in place of exit 0 (the run of `roc`, runs 1, 2 and 4) or exit 13 (runs 3 and 5) |
| `proxy/px1-flow` | exit 18 in place of 13 (one run) |
| `resolve/rs-no-compiler`, `roc/so9-no-roc`, `roc/so9-hash-fails` | exit 18 in place of `nothing to change` and exit 0 |
| `roc/bs2-no-pin` | run 2: exit 18 in place of the install, and run 5: exit 18 in place of the install of 2026-10-15 |
| `roc/bs3-range` | run 2: exit 18 in place of `already installed`, exit 0 |
| L3 `compilers/bs1-base-ranks`, `compilers/px1-proxy`, `compilers/so9-launcher` | exit 18 or its text in place of the new result |

Green with the old code and the new expected files: `tool/dl1-sweep`, `in2` runs 3 and 5, and `verify/vn2-step-b-project` (not part of this slice).

With the private reference (now deleted): `scripts/test.sh` passed all steps (L2 205 passed, L3 84 passed with 3 skipped).

## 11. Revert check (TW12)

The 14 changes of the first test step (m1 to m13, m10b) ran on the earlier runs. The runs of `in2` moved, and three of the changes (m5, m10, m10b) are about the steps (a) and (b), so they are void. After the review, only the new tricky rows have a change. One change of the reference at a time, with a filtered L2 run each. All caught.

| Id | Change | Caught by |
| --- | --- | --- |
| e1 | A plain `install` with a `talon.toml` that the header satisfies still picks (Q-E1) | `in2` run 7 |
| e2a | The download of `upgrade` sets no default (Q-E2) | `ur7` run 1 |
| e2b | The `upgrade` prompt has no default line | `ur7` |
| e3a | A range with no installed compiler in it gives no base (Q-E3) | `bs3-range` run 2 |
| e3b | The same, the base is the pick of R-SO14 and not the range | `bs3-range` run 2 (the fact for 2026-10-16) |
| e4 | The base of a relative selector ignores the recorded passes | `bs2-no-pin` run 5 |
| e5 | The proxy pick ignores the hashes of the target header | `px5` run 1 |

## 12. For slice 080 (the invariant R-SO24; not tested now)

Slice 080 gets these items. The test agent of 080 deletes or rewrites the cases below, and the code agent removes the dead code.

| Item | What 080 does |
| --- | --- |
| `verify/vn2-step-b-project` | Delete (it tests step (b) only). |
| `verify/vn1-nocompiler` runs 1, 2 and 6 (steps (a) and (b), the budget of step (b)) | Delete or turn into R-SO24 case 3 (rank 6 gives the newest installed compiler, with one note). |
| `probe/pn1-nocompiler` runs 1 and 2, `roc/us4-nocompiler` runs 1 and 2 | The same. |
| `norank/nr1-order` runs 1 to 4, 6, 7 (installed compilers, step (b) probes), `NoRank` L0 rows of the steps (a) and (b) | Delete the rows of the steps (a) and (b). Keep the rows of the two steps that stay. |
| The runs of 072e that had installed compilers and no `default-roc` (removed from this slice) | `in2` old run 1 (step (a): installed N1, N2, N3, facts for N1 and N2, `update json`: the pick was N2, no download, no default) and old run 2 (step (b): N2 and N3 installed, no fact, the platform unit fails on N3, N2 is the pick). `px5` old run 1 (the same facts as `in2` run 1, `roc check`: `exec` runs N2, no download) and old run 2 (N2 and N3 installed, no fact: the proxy ran no probe and downloaded N4; the installed compilers were not used). `bs2-no-pin` old run 5 (2 installed, a fact on the older one: the base was that one). Under R-SO24 each is case 3: rank 6 gives the newest installed compiler, one note, no file written on a read (`tln setup` writes the default). The old homes are deleted. The toolchains (the `.talon.json` files) and the facts are those of `verify/vn1-nocompiler` homes h1 and h2 (080 decides about that case too), so the test agent of 080 can rebuild them. |
| Code | The default is written on every install path (R-SO24 table). `RocRemove` and `RocManage` (R-RR1): the default moves to the newest admitted compiler, else the newest of any kind. The rank 6 fallback with one note. `tln setup` repair (R-ST16). Removal of `NoRank` steps (a) and (b), `NoRank.Probing`, and the step (b) closure in `HeldRoc` (`probe_one!`). The test app builds `NoRank.Probing` (`L2NoRank.roc`), so that type changes with the tests of 080. |

## Review (manager, 2026-10-26)

| Item | Result |
| --- | --- |
| R-SO24 | Applied. Every run with installed compilers and no `default-roc` is outside this slice: `in2` old runs 1 and 2, `px5` old runs 1 and 2, `bs2-no-pin` old run 5. They are in section 12. |
| `vn2` | The case tests step (b) only. It stays in the tree as a green case, outside the red state, and 080 deletes it. |
| Facts that stayed as tests of live code | The facts for the pick (the pass, not the latest) are now tested with nothing installed: `in2` run 6, `px5` run 1, `bs2-no-pin` run 5. |
| Q-E1 (a) | `in2` run 7. |
| Q-E2 (a) | `upgrade/ur7-nocompiler`. The case with two compilers (the pick is not the newest nightly) has no cheap fixture: not tested. |
| Q-E3 (a) | `roc/bs3-range` run 2 (the base is the newest release in the range; the fact for another release is ignored). |
| TW24 proposals | All accepted. One new: the place of the line `It becomes the default compiler.` in the prompt of `upgrade` (section 6). |
| Split | Not needed if the code stays at about 250 lines. The reference had about 260 lines (without comments) in 14 files. The split of section 1 is ready. |
| Reference and `mutate*.py` | Deleted. `before/` stays in `research/slice-072e-revert/`. |
| Red state | Confirmed: L2 11 of 205 fail, L3 3 of 84 fail, all with a wrong value (section 10). |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| Item | Decision | Rejected |
| --- | --- | --- |
| Where "no compiler was selected" is known at the first probe | `request.selected == ""` (the compiler before the pick, plain data). `PickLoop.begin!` calls the new `Start.run_picked!`, `RemoveFlow.removal_ladder!` starts the pick itself with `Start.run_picked!` and gives it to `Ladder.run!` in `loop.started` (same call order). | A marker in `Start.Downloads.env` or an alias field (the brief forbids it). A new field in `Ladder.Request` (7 constructors). |
| Import cycle (`Start`, `RocInstall` need the pick, the gate, the prompt; `NoRank` imports both) | New leaf module `NoRankPure` (`pick`, `first`, `keys`, `gate`, `prompt`). `NoRank.pick`, `first`, `keys`, `gate`, `prompt` are one-line wrappers, so the L0 tests do not change. | Copies of the functions. |
| `NoRank.pick_id!` | The installed list, the facts of step (a) (`first_of!`, shared with `ensure!`), then `NoRank.offer!` for the id. No gate, no download, no default. | A pick that ignores the installed compilers. |
| `HeldRoc.picked!` with installed compilers and no default (the state that R-SO24 forbids) | Until slice 080 it runs the old steps (a) and (b) (`ensured!`), so `roc/us4-nocompiler` stays green. With nothing installed it is `pick_id!`. Slice 080 removes the branch. | Dropping the steps now (it breaks `us4` run 2). |
| `init` (R-IN2, R-IN4) | `InstallFlow.install_fresh!` (`Update.resolve!` gets `fresh : Bool`). `finish!` treats the pin of the held compiler as a move (`fresh_pin`) when no release moves, so the ladder checks it. | A marker in `request.add.as_alias`, or `args.typed == "init"`. |
| `check_pin` role in `InstallFlow.resolve!` | `LockNoCheck` when `--no-check` or when no compiler is held. The pick step runs before, so no compiler is held only when no probe will run. | A second flag. |
| `Base.selected!` result | `Base.Basis { base, hashes, range }`. `Base.listed!` gives the base from the list: range pick (Q-E3) or `NoRankPure.pick` over the facts of the header hashes (Q-D3). `Base.Loaded` has the new field `hashes`. | |
| Proxy | `Base.Rank` has the new tag `Picked` (text `no compiler is selected`). The proxy reads the installed list after `path_roc`, picks (`pick_id!`), and after `install_missing!` calls `first_default!`. | |
| `roc use` | `fallback!` gives `{ id, picked }`. `install_all!` puts the pick first in the prompt and in the installs, and calls `first_default!` right after its install. | |
| `upgrade` (Q-E2) | `NightlyFlow.known!` puts the pick first when `request.selected == ""`, calls `first_default!` after its install, and the single prompt is the new `Consent.roc_install_default` (475 lines in `Consent`). | |

Not coded (not in the tests of this slice): `upgrade --no-check` with a free nightly and nothing installed still stops with exit 18 (`InstallFlow.resolve!`, the old rule of slice 039). The design says `--no-check` needs no compiler (R-SO22), so this may be a question for the manager (TW17).

## Verify results (code agent)

`scripts/test.sh`: check, fmt, l0, l1, l2 (205 of 205), l3 (84 of 84, 3 skipped), selftest all pass. Files: `research/slice-072e-revert/code-final/` and `code-final.sha256`. 12 changes, one at a time, with a filtered view of `scripts/test.sh l2`. The code was compared with a copy after the last change (same).

| Id | Change | Caught by |
| --- | --- | --- |
| m1 | A plain `install` with nothing to change still picks (`will_probe`) | `install/in2-nocompiler` run 7, `resolve/rs-no-compiler`, `roc/so9-no-roc`, `roc/so9-hash-fails` |
| m2 | `PickLoop.begin!` uses `Start.run!` (no pick text, no default) | `install/in2-nocompiler` |
| m3 | A range with no installed compiler gives no base | `roc/bs3-range` |
| m4 | The base pick ignores the hashes (scope `Outside`) | `roc/bs2-no-pin` run 5 |
| m5 | The proxy sets no default after the download | `proxy/px5-no-rank` |
| m6 | `roc use` puts the new compiler before the pick | `roc/us5-both-missing` |
| m7 | `upgrade` prompt has no default line | `upgrade/ur7-nocompiler` |
| m8 | `init` writes no pin when no release moves | `init/it4-nocompiler` |
| m9 | A picked first probe with `TALON_AUTO_INSTALL=no` gives the plain refusal text | `install/in2-nocompiler` run 2 |
| m10 | `resolve!` always uses `Lock` | the 4 cases of m1 |
| m11 | `remove` does not pick | `install/in2-nocompiler` run 4 |
| m12 | `HeldRoc.picked!` without the old steps (a) and (b) | `roc/us4-nocompiler` |

Caught 12 of 12. Not caught: none.

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `grep -rn 'crash "todo' cli packages` | none; no `TALON_PICKED` or `@init` marker in `cli/lib` |
| `scripts/test.sh` (manager) | rc=0: check, fmt, l0, l2, l3, selftest, l1 pass |
| Disputes | none |
| Code agent question: `upgrade --no-check`, free nightly, nothing installed, exit 18 | Manager answer: a bug by R-SO22 (`--no-check` needs no compiler). Fix and test in slice 080. |
| `HeldRoc.picked!` steps (a) and (b) with installed compilers | Removed in slice 080 (R-SO24). |
