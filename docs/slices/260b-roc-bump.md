# 260b Roc compiler bump (candidate B)

Phase: P2 (part of slice 260, CI green, group G6). Status: phase 1 done; the user answered Q1 to Q3 on 2026-11-23 (section 12). The 3 releases exist (section 6). The diff uses their URLs. Not applied to the Talon tree (it lands after 260a and 262). Design id: none yet (ask the coordinator). Plan id: G-C269 (the id of slice 260).
Research: `research/roc-bump-260b/RESULT.md` (candidates A and B). Prepared diff: `research/roc-bump-260b/candidate-b.diff`.

## 1. Decision (the user, 2026-11-23)

| Item | Value |
| --- | --- |
| New `ROC_TAG` | `nightly-2026-11-13-03dce41` (candidate B) |
| `ROC_TAG_WORKER` | not changed: `nightly-2026-11-06-34f137a` |
| Platform | basic-cli `0.28.1`: `https://github.com/roc-lang/basic-cli/releases/download/0.28.1/7brgwR8YUqfeGrkdfF1V4GPPN7DnP7ftqub9KcrTEZtr.tar.zst` (not 0.27.0: basic-cli issue #555, a compile crash on Windows; 0.28.1 says "Use nightly-2026-11-13-03dce41 or later") |
| Fuzz platform | roc-fuzz `0.7.0` (the user, 2026-11-23): `https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.7.0/HBigHQhVZWEF2EkLxpYK35u8P6UNsAmPYxpNFTxXK1Br.tar.zst`. roc-fuzz 0.4.3 does not link with 03dce41 (`ld.lld: relocation R_X86_64_32 ... recompile with -fPIC`). |
| New warning | `duplicate definition`: a local name that shadows a top-level name of the module. `check`, `l0`, `l2`, `l3` fail on a warning. Fix each site by a new local name. |
| Generic packages | New releases roc-semver 0.2.1, roc-app-header 0.1.1, roc-toml 0.2.0 (R-GP2, R-GP5), each in its own repo, before Talon moves. The user approved the 3 releases (2026-11-23). |

## 2. Steps

| Step | Who | Work | State |
| --- | --- | --- | --- |
| 1 | lead | This file | done |
| 2 | lead | In each generic package repo: warning fixes, pinned nightly, `roc fmt`, roc-fuzz 0.7.0, `--time` bound (section 6). Local `main` is fast-forwarded to these commits. | done locally |
| 3 | user (or an agent with push permission) | `git push origin main` in each repo (a fast-forward), wait for CI on `main`, then `gh workflow run release.yml --ref main -f release_version=X.Y.Z` (roc-semver 0.2.1, roc-app-header 0.1.1, roc-toml 0.2.0). Record each asset URL. Then the README URL commit of each repo. | done: the coordinator pushed with the user's approval, CI passed, the 3 releases ran. README URL commits are local (roc-semver `dcc46f3`, roc-app-header `cf23715`, roc-toml `009d73f`), to be pushed by the coordinator. |
| 4 | test agent | T1 to T6 (section 4), the platform URL in `tests/commands/main.roc`, the L1 targets (section 5). At landing: re-bake `registry/ap20-closure-errors` (T4, Q1). | prepared in `candidate-b.diff` (T4 not: it is re-baked at landing) |
| 5 | human review | | |
| 6 | code agent | `scripts/env.sh`, C1 to C5, the 26 warning sites (section 3), the 3 new release URLs in `cli/lib/main.roc` and `packages/resolve/main.roc` (roc-semver 0.2.1, roc-app-header 0.1.1, roc-toml 0.2.0) | prepared in `candidate-b.diff`, with the release URLs |
| 7 | code agent + test agent | `roc fmt` with 03dce41: 322 files (section 7), one commit, at a time slot that the coordinator gives (other sessions have uncommitted work) | not in the diff |
| 8 | verify | `scripts/test.sh` (all fast steps), then CI on a branch: the Windows job first, then `nightly.yml` by hand (the merge run, G6 gone) | |

Order of the dependency: steps 3 before 6. The diff keeps the old release URLs of the 3 packages; step 6 puts in the new URLs. Never commit a path entry (R-GP3, R-GP4).

## 3. The 26 warning sites in Talon (re-checked with 03dce41)

All in `cli/lib/`. `roc check cli/main.roc` gives exactly these 26 (and `tests/commands/main.roc` the same 26). `bot/main.roc` gives 13, `cli/flowprobe.roc` 10, `cli/fxprobe.roc` and `cli/real.roc` 1 each: all of them are in this list. `packages/resolve` has none of its own. After the fixes: 0 warnings.

| # | Site | Local name | It shadows | New name in the diff |
| --- | --- | --- | --- | --- |
| 1 | `AuditReport.roc:19` | `text` (in `Other(text)`) | `text` (60) | `other` |
| 2 to 4 | `BuildSkip.roc:82, 83, 84` | `row` (lambda arg) | `row` (91) | `fact` |
| 5, 6 | `ClosureRequest.roc:59, 63` | `ends` | `ends` (98) | `span` |
| 7 | `Gc.roc:111` | `entries` (arg of `zig_dirs`) | `entries` (137) | `listing` |
| 8 | `Link.roc:125` | `target` (in `JsonDoc.Text(target)`) | `target` (117) | `link_target` |
| 9, 10 | `Matrix.roc:59, 90` | `found` (fold accumulator) | `found` (123) | `acc` |
| 11 | `MoveCheck.roc:70` | `text` (in `job`) | `text` (348) | `repo_text` |
| 12, 13 | `MoveCheck.roc:143, 147` | `text` (in `Ok(text)`) | `text` (348) | `value` |
| 14 | `MoveCheck.roc:250` | `answer` (in `Ok(answer)`) | `answer` (283) | `got` |
| 15 | `Nightlies.roc:354` | `via` (arg of `via`) | `via` (354) | `source` (the field stays `via: source`) |
| 16 | `ProbeSmoke.roc:43` | `text` | `text` (123) | `operand` |
| 17 | `Publish.roc:88` | `token` | `token` (175) | `token_text` (the field stays `token: token_text`) |
| 18 | `Publish.roc:177` | `answer` | `answer` (322) | `got` |
| 19 | `Publish.roc:262` | `answer` (in `Ok(answer)`) | `answer` (322) | `got` |
| 20 | `Publish.roc:292` | `answer` (in `Ok(answer)`) | `answer` (322) | `got` |
| 21 | `Roots.roc:78` | `item` (arg of `item`) | `item` (78) | `it` |
| 22, 23 | `TalonRemove.roc:242, 297` | `file` (in `Profile(file)`) | `file` (339) | `profile` |
| 24 | `TalonRemove.roc:333` | `file` (lambda arg) | `file` (339) | `one` |
| 25 | `ToolManageFlow.roc:101` | `tools_file` | `tools_file` (132) | `tools_path` |
| 26 | `YankCheck.roc:140` | `answer` (in `Ok(answer)`) | `answer` (157) | `got` |

Only local names change. No text, no field name and no behavior changes. The code agent can choose other names.

## 4. Code and test fixes (from `RESULT.md` section 4, re-checked with 03dce41)

| # | File | Owner | Fix | Still needed on 03dce41? |
| --- | --- | --- | --- | --- |
| C1 | `cli/main.roc`, `cli/fxprobe.roc`, `cli/flowprobe.roc`, `cli/real.roc`, `bot/main.roc`, `tests/commands/main.roc` | code agent (`tests/commands/main.roc`: test agent) | basic-cli 0.26.0 URL to the 0.28.1 URL (6 lines) | yes |
| C2 | `cli/lib/AuditCheck.roc` 327 | code agent | reuse the binding `first` (two `rows.first()` calls give two incompatible `first` methods) | yes (applied, check passes) |
| C3 | `cli/lib/ShareLogin.roc` 357 | code agent | remove the unreachable last line after `while Bool.True` | yes |
| C4 | `cli/lib/Outdated.roc` 34 | code agent | rename `Outdated.Range` to `Outdated.NightlyRange` (builtin `Range`) | yes |
| T1 | `tests/unit/AddTest.roc` | test agent | `url : Str, Str -> Str`; each `none` becomes `Err(None)` (value restriction) | yes |
| T2 | `tests/unit/ProberangeTest.roc` | test agent | `cell : Str -> Str`; a `match` for the outcome | yes |
| T3 | `tests/tools/ciscan.py` 406, 407 | test agent | the pin text `nightly-2026-10-14-38a3029` becomes `nightly-2026-11-13-03dce41` (selftest row `ci/pin` checks `ROC_TAG` against this fixed text) | new |
| T4 | `tests/commands/cases/registry/ap20-closure-errors/expect/stderr` line 5 | test agent: **re-bake at landing** (the user, Q1) | the text after `is not a closure answer:` comes from the builtin JSON decoder. 03dce41 gives `InvalidJson("Missing field: artifacts")`, 34f137a gave `MissingRequiredField("artifacts")`. The new text is accepted. | new; not in the diff (the only L2 change of 759 cases) |
| T5 | `tests/fuzz/*.roc`, `scripts/test.sh` (l1), `tests/selftest.sh` (the fake roc-fuzz target, the `l1` rows) | test agent | roc-fuzz 0.7.0 and `--time=$L1_TIME` (section 5) | new |
| T6 | `tests/unit/ShareTest.roc` (2 rows) | test agent | roc-toml 0.2.0 gives the line of an error at the end of the text as one past the last byte: `share = [\n` is now line 2, not 1. `${path}:1: not valid TOML` becomes `${path}:2: not valid TOML` (rows of `Share.setting` and `Share.edit`). | new (roc-toml 0.2.0) |
| C5 | `cli/lib/Manage.roc` 196 (`default_set`) | code agent | `Toml.replace` in roc-toml 0.2.0 can give `Err(InvalidValue)` (only for a date or time value). The match had `Err(NoEntry)` only (non exhaustive); now `Err(_) => Err(cannot_write(facts.path))`, as the `Toml.insert` branch. A string value never gives `InvalidValue`, so the behavior does not change. All other Talon uses of `Toml.replace`/`Toml.insert` (`Channel`, `IntentEdit`, `Share`, `Toolchain` and others) already map every error with `map_err(\|_\| ...)` or `Err(_)`. | new (roc-toml 0.2.0) |

Scripts: `scripts/env.sh` line 6 `ROC_TAG=${ROC_TAG:-nightly-2026-11-13-03dce41}` (code agent). The comment on line 5 does not change.

## 5. Talon L1 on roc-fuzz 0.7.0

The 3 Talon targets (`tests/fuzz/diff.roc`, `epochs.roc`, `pubgrub.roc`) use roc-fuzz 0.4.3 and do not link with 03dce41. The changes in the diff:

| File | Change |
| --- | --- |
| `tests/fuzz/*.roc` | the 0.7.0 platform URL; `examples: [],` in `Fuzz.target_with` (a new required field). No target has a nominal input type, so no `parser_for`/`encoder_for` is needed. |
| `scripts/test.sh` l1 | new `L1_TIME` (default 120): each run gets `--time="$L1_TIME"` (Q2); `--artifact-dir="$d/art"` (removed in 0.7.0) becomes `--report-dir="$d/rep"`; the result line is the line with `exploration` (0.7.0 prints `<name>: passed; ...; exploration passed (attempted N, ...)`, no `Done` line); the replay loop reads `"$d"/rep/failures/*`; the comment on line 137 |
| `tests/selftest.sh` | the fake target reads `--report-dir` and writes `<dir>/failures/crash-abc`, prints a 0.7.0 summary line; the rows `limit l1` and `l1` look for `--time=120 --report-dir` and `rep/failures/crash-abc` (the row `l1` checked "no `--time`" before) |

`--time` (Q2): in roc-fuzz 0.7.0 a run that reaches `--time` ends with exit 0 and outcome `passed`; the summary line gives the count it tried (tested: `epochs run --runs=100000000 --time=5` gave exit 0, `exploration passed (attempted 23767, ...)`). The value is **120 s** for each target, in Talon and in the generic packages: below the l1 process limit (`TEST_TIMEOUT` default 180 s for l1), and 5 or 6 targets x 120 s fit the 30 min fuzz job of the generic package CI. Locally a small count stops first. Note: TW6 says "a fixed count"; with the bound, a slow run tries fewer inputs (the user accepted this, Q2).

Result: each target checks, builds (`roc build --fuzz`, default mode) and runs 2,000 inputs with seed 1: all pass. The `l1` step itself was not run here: it builds with `--opt=speed` (not allowed locally). Not verified: the path of a real failure file under `rep/failures/` (the selftest fake uses that path).

## 6. Generic packages (each repo, local branch `roc-03dce41`, not pushed)

| Repo | Base | Commits | Warning sites fixed | Planned version | Why |
| --- | --- | --- | --- | --- | --- |
| `roc-semver` | `8cdb94d` (main, = origin/main, after 0.2.0) | `0aa823b` fix and pin, `bf83277` fmt, `de65da8` roc-fuzz 0.7.0, `540a5fb` `--time` | 15 in `Semver.roc` (`new`, `parse_lazy`, `to_str`, `to_key`, `from_key`) | **0.2.1** | patch: no API change, no behavior change |
| `roc-toml` | `cad23df` (local main, "0.2.0 (not released)", one commit ahead of origin/main `89aa0c3`) | `1038492` fix and pin, `4c094db` fmt, `7691b51` roc-fuzz 0.7.0, `--time`, CHANGELOG 0.2.0 | 2 in `Toml.roc` (`table` in `parse` and in `reread`) | **0.2.0** | minor: the API change of `cad23df` (`InvalidValue`, error columns), folded in by the user (Q3) |
| `roc-app-header` | `943a355` (= the 0.1.0 tag and origin/main) | `eb85508` fix and pin, `3acbd84` fmt, `2d6e8e5` roc-fuzz 0.7.0, `cce9dc9` `--time` | 1 in `PackageUrl.roc` (`parse`: `hash`) | **0.1.1** | patch |

Releases (2026-11-23):

| Package | URL |
| --- | --- |
| roc-semver 0.2.1 | `https://github.com/Karakatiza666/roc-semver/releases/download/0.2.1/6BPnjRNpioc4pS8vxuiYDV3kNi13wMC6emA4qiPHK75L.tar.zst` |
| roc-app-header 0.1.1 | `https://github.com/Karakatiza666/roc-app-header/releases/download/0.1.1/Ev4sYWkY8XDbQsPxtaaXZaARYjH9KS2x2dbmVch2d4qS.tar.zst` |
| roc-toml 0.2.0 | `https://github.com/Karakatiza666/roc-toml/releases/download/0.2.0/2jDX3pSSC7cpPb3iuoemnX1BkYJfsxQTHB2p2vBsUzz7.tar.zst` |

History of the push (kept for the record): State of the repos before the push: local `main` of each repo is fast-forwarded to the last commit above (4 commits ahead of `origin/main`; for roc-toml `cad23df` plus 3). The branch `roc-03dce41` (roc-semver, roc-app-header) and `roc-03dce41-v020` (roc-toml) point at the same commits. The old roc-toml branch `roc-03dce41` (on 0.1.0, `f88c791`) is not used any more. **`git push origin main` was refused by the permission system** (auto mode classifier, "Unsanctioned Communication"), so nothing is pushed, no CI ran on `main`, and no release exists. The user must push (or allow the push) and then run the 3 releases.

Each branch changes: the locals, `.roc-version`, `ROC_NIGHTLY` in `ci.yml` and `release.yml` (`nightly-2026-11-13-03dce41`), `roc fmt` with 03dce41, the fuzz targets on roc-fuzz 0.7.0 (URL, `examples: []`, `parser_for : _` and `encoder_for : _` on each nominal `Input`), `--report-dir` in `scripts/test.sh` and `ci.yml`, `--time="$FUZZ_TIME"` (default 120; `FUZZ_TIME: "120"` in `ci.yml`), roc-fuzz 0.7.0 in the README. No repo uses basic-cli as a platform (only as test data), so there is no basic-cli URL to change. The README release URL changes after the release (the hash is known then).

Test results (`scripts/test.sh`, `RUNS=2000`, caches under `.tmp/roc-bump-b/`):

| Repo | 03dce41 | 38a3029 (the current Talon pin) |
| --- | --- | --- |
| `roc-semver` | ALL PASS (check, fmt, L0 25 + 103 + 146, L1 5 targets x 2,000) | check pass, L0 pass. fmt fails on `tests/key.roc` (the new fmt breaks a long `and` chain). L1: the targets build, each run crashes (exit 139): roc-fuzz 0.7.0 does not run with 38a3029. |
| `roc-toml` (0.2.0 tree) | ALL PASS (L0 8 files: 69, 62, 48, 115, 463, 205, 205, 110; L1 6 targets) | not re-run on the 0.2.0 tree (the 0.1.x tree: check, fmt, L0 pass; L1 exit 139) |
| `roc-app-header` | ALL PASS (L0 5 files, L1 5 targets) | check, fmt, L0 pass. L1: each run exit 139. |

So the package code builds and its tests pass on both compilers. Only the fuzz platform needs 03dce41.

| Note | Text |
| --- | --- |
| N1 | roc-toml: the user folded the work into 0.2.0 (Q3). The fix, the fmt and the roc-fuzz change were made again on top of `cad23df`. The CHANGELOG heading is now `## 0.2.0` (the line about the planned asset name on 38a3029 is replaced: the release gives the name). |
| N2 | `roc-base58` (Talon uses 0.1.0, not changed by this slice): no warning on 03dce41. It needs: roc-fuzz 0.7.0 (4 targets, 3 nominal `Input` types), `--report-dir` in `scripts/test.sh` and `ci.yml`, `roc fmt` (2 files), the pinned nightly. Not changed. |
| N3 | `roc-jwt` (pinned `nightly-2026-10-31-f7bef6b`, used by `worker/`): 1 error on 03dce41: `package/Jwt.roc:207` `claims_as = \|token\| Json.parse(token.payload)...` type mismatch (the builtin `Json.parse` type changed). It needs that fix and roc-fuzz 0.7.0 (1 target with a nominal `Input`). Not changed; the Worker stays on 34f137a. |

## 7. Results in the Talon worktree (`.tmp/roc-bump-b-wt`, from HEAD `53985149`, removed after)

The fixed packages were copied into the worktree and the 3 dependency lines pointed at them as local paths (only in the worktree; not in the diff).

| Step | Result | Note |
| --- | --- | --- |
| check | pass (1.5 s) | 0 errors, 0 warnings after the 26 renames |
| fmt | FAIL before `roc fmt` | `roc fmt` with 03dce41 changes **322 files** (cli/lib 222, cli 7, bot 3, packages/resolve 9, tests/unit 67, tests/commands 11, tests/fuzz 3), 2552 lines. After it: pass. Not in the diff. |
| l0 | pass (14.9 s, budget 10) | |
| l2 (OPT=dev) | 758 passed, 1 failed | `registry/ap20-closure-errors` (T4) |
| l3 (OPT=dev) | 99 passed, 1 failed, 19 skipped | `tools/tx1-x-run`: the known G10 (260a fixes it) |
| w0 | pass (13.7 s) | `packages/records` on 03dce41 and 34f137a |
| wbuild | pass (169.5 s, cold cache) | Worker on 34f137a, not changed |
| selftest | 80 passed, 2 failed | both from the local paths only: the `packages` row (R-GP3 guard: "a path entry of a generic package") and the `unit guard` row (its copy has no `.localpkgs/`). With release URLs they go away. The `ci/pin` row passes after T3. The l1 rows pass with T5. |
| l1 | not run as a step (`--opt=speed`) | section 5: 3 targets build and run 2,000 inputs each in default mode |

Second run (after Q1 to Q3: roc-toml 0.2.0 from local `main`, `--time`, C5, T6; the 3 packages from local `main` as local paths):

| Step | Result |
| --- | --- |
| check | first: 1 error, `Manage.roc` 194 non exhaustive match (`Err InvalidValue`), fixed by C5; then pass, 0 warnings |
| l0 | first: `ShareTest.roc` 2 rows (`:1:` is now `:2:`), fixed by T6; then pass (15.6 s) |
| l2 | 758 passed, 1 failed (`registry/ap20-closure-errors`, T4, re-baked at landing). roc-toml 0.2.0 changes no other L2 case. |
| l3 | 99 passed, 1 failed (`tools/tx1-x-run`, G10), 19 skipped |
| w0 | pass (12.3 s) |
| wbuild | pass (up to date from the first run: the Worker sources did not change) |
| selftest | 80 passed, 2 failed (only the local path rows, as before); the `l1` rows pass with `--time=120` |

Third run (the diff with the 3 release URLs, a new `WORK` dir, so roc downloaded the 3 packages: no download was refused):

| Step | Result |
| --- | --- |
| check | pass (10.7 s, cold cache), 0 warnings |
| l0 | pass (16.1 s) |
| l2 | 758 passed, 1 failed: `registry/ap20-closure-errors` (T4, re-baked at landing) |
| l3 | 99 passed, 1 failed (`tools/tx1-x-run`, G10, fixed by 260a), 19 skipped |
| w0 | pass (15.1 s) |
| wbuild | pass (107.5 s) |
| selftest | **pass**: 82 passed, 0 failed, 1 skipped (the path entry rows pass with the release URLs) |

`candidate-b.diff`: 36 files, 145 lines added, 137 removed. It is relative to `53985149` and `git apply --check` passes on the current tree (with the uncommitted 260a, 261, 262 work). It has no `roc fmt` change and no path entry. It has the 3 release URLs in `cli/lib/main.roc` and `packages/resolve/main.roc`. `worker/` keeps its old URLs (the Worker stays on 34f137a).

## 8. `packages/records` and the 257 modules (03dce41, a copy in `.tmp/roc-bump-b/rcopy`)

| Check | Result |
| --- | --- |
| `roc check packages/records/main.roc` | no error, no warning |
| `roc check packages/records/tests/w0.roc` | no error, no warning |
| `roc fmt --check` of records | pass (no file changes) |
| `roc test packages/records/tests/w0.roc` | 181 passed |
| 257 modules in records (`Tlog.roc`, `tests/TlogTest.roc`) | no warning |
| `worker/lib/main.roc` (with 03dce41, for information: the Worker stays on 34f137a) | 16 warnings, all in released packages (roc-semver 0.2.0: 15, roc-app-header 0.1.0: 1); 1 error in roc-jwt 0.0.1 (N3). The 257 modules `LogPath.roc`, `LogStep.roc`, `LogTrigger.roc`, `Login.roc` have no warning of their own. |

## 9. CI notes

| Place | Change |
| --- | --- |
| `ci.yml`, `nightly.yml` | none. The cache key has `ROC_TAG`, so the first run downloads 03dce41 again. CI downloads 2 nightlies (03dce41 and 34f137a), as today. |
| `release.yml`, `compat-bot.yml` | none (they use `scripts/get-roc.sh`) |
| Package cache key | changes by itself (new basic-cli and package URLs) |
| Windows job (`check fmt l0`) | the reason for candidate B (#555). Look at it first on the branch. |
| L1 on CI | the targets build with `--opt=speed` on the new platform; see Q2 for `--time` |
| Generic package CI | each branch pins 03dce41 in `ci.yml` and `release.yml`; `setup-roc` gets the nightly by tag |

## 10. Plan row (proposal for `docs/slices/PLAN-P2-CLI.md`)

| # | Slice | Content | Rule ids | Design refs | Depends on (CLI / registry) | Lines | Model |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 260b | Roc bump to 03dce41 | (status: phase 1, file 260b-roc-bump.md) `ROC_TAG` `nightly-2026-11-13-03dce41`, basic-cli 0.28.1, roc-fuzz 0.7.0, the 26 `duplicate definition` sites, C2 to C5, T1 to T6, `--time=120` for each fuzz run, new releases roc-semver 0.2.1, roc-toml 0.2.0 (its API), roc-app-header 0.1.1, `roc fmt` of 322 files; at landing re-bake `registry/ap20-closure-errors` (the new JSON decoder text, accepted by the user) | TW28, TW31, TW6, R-GP2 to R-GP5 | G-C269 (Q: ask) | 260a, 262 / none | 150 + fmt | Sonnet |

## 11. Text that names the old tag (for the TalonRegistry session)

| File | Place | Now | Change |
| --- | --- | --- | --- |
| `docs/slices/PLAN.md` | table "Compiler" row | `nightly-2026-10-14-38a3029`, path in `cloudflare-workers/.cache/nightlies/` | `nightly-2026-11-13-03dce41`. The rows "Platform" (basic-cli 0.25.0) and `roc-semver` 0.1.0 are already old; update them to basic-cli 0.28.1 and the new package releases. |
| `docs/registry/PLAN.md` | line 22 "Nightly of Talon CLI" | `nightly-2026-10-14-38a3029` | `nightly-2026-11-13-03dce41` |
| `docs/registry/PLAN.md` | line 240 (G5, a quote of TW28 with the tag) | the old tag | a history note; change only if the row is still live |
| `TESTING.md` TW28, TW31 | no tag in the text | | no change. Optional note: "the two tags are different again" is not needed (they were different before). |
| `DESIGN-CLI.md` R-CV8 (1166, 1177) | `nightly-2026-10-14-38a3029` as the example of asset targets | | no change: an example of a real release, not the pin |
| `DESIGN.md` Q59 (670) | "the CLI pins `nightly-2026-10-14-38a3029`" | | history of a settled question; a note "(slice 260b: 03dce41)" is optional |
| `DESIGN-REGISTRY.md` 982 | "the list is the same on `38a3029` and `f7bef6b`" | | a fact about those nightlies; check `RocTarget` on 03dce41 only if the table must name the pin |
| `tests/tools/ciscan.py` 406, 407 | fixed pin text | | T3 (in the diff) |
| `tests/unit/*Test.roc`, L2/L3 fixtures, `tests/tools/mk-*.sh` | `38a3029` as test data | | no change (data, not the pin) |

## 12. Questions (TW17)

| Q | Question | Proposal |
| --- | --- | --- |
| Q1 | T4: the stderr text of `registry/ap20-closure-errors` has the raw text of the builtin JSON decode error, which changed in 03dce41. | **Settled (the user, 2026-11-23):** accept the new text; re-bake the case when Talon lands. |
| Q2 | roc-fuzz 0.7.0 `run` stops after 60 s by default. What bound for each fuzz run? | **Settled:** a time limit with `--time=<s>`. Chosen value: 120 s (section 5), in Talon l1 (`L1_TIME`) and the 3 generic packages (`FUZZ_TIME`). |
| Q3 | roc-toml: 0.1.1 first, or fold into 0.2.0? | **Settled:** fold into 0.2.0; Talon moves to the 0.2.0 API (C5, T6). |
