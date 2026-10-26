# 070b Fetch of a patch base

Phase: P1. Status: done

Slice 070b is the plan row 070b of `PLAN-P1.md` (section 2c), from questions Q1 and Q3 of slice 070 and from the close note of slice 070 (`base_check!` and a URL with no GitHub name). Slice 070 made the exit 14 for a `base` that no release of the group has. Now, when a release of the group has the hash, Talon fetches that release by its hash (R-PA13). `tln patch --diff` uses the same missing-base rule. The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files are in `research/slice-070b-revert/before/` (`NEW.txt` lists the new files).

## 1. Rules

| Id | Text (short) | Tested by |
| --- | --- | --- |
| R-PA13 (Resolution 7), R-DI11 | The base `packages/<base>/` is not in the cache. Talon finds the URL in the release list of the group of the entry, and fetches it by hash. No release has the hash: exit 14 (base, alias, 2 fixes of R-PA5). `--offline` and no cached list: exit 15 | L2 `patch/pa4-base-missing` runs 4 to 7. L2 `patch/pa1-flow` run 15 |
| R-PA5 (as used) | The rebase of `tln install` needs the base. A base that a release has is fetched, and the failures are the failures of the fetch | L2 `pa4-base-missing` run 4 (the path of `PatchApply`) |
| R-PA3 | `tln patch <alias> --diff` prints the diff of the copy against `packages/<base>/`. A base that is not in the cache has the rule of R-PA13: fetch by hash, or exit 14 | L2 `pa4-base-missing` runs 5 and 6, `pa1-flow` run 15 |
| R-FE7, R-DA4 (as used) | `--offline` uses the cache only: the fetch of a base that is not in `packages/` stops with exit 15 (the text of `Fetch.offline_missing`) | L2 `pa4-base-missing` run 4 |
| R-EC14 (as used) | The missing base is kind `frozen` (exit 14) in `tln patch --diff` too | L2 `pa4-base-missing` run 6, `pa1-flow` run 15 |

`MISSING=1 scripts/rules.sh R-PA` lists no id after this slice that it listed before. No new L0 `expect`: the pure decisions (`Patched.base_release`, `Patched.base_missing`) exist from slice 070 and have their rows. This slice adds only command code (the fetch and the second caller).

## 2. Flow (what the L2 cases fix)

One function does the lookup for both commands: `PatchApply.base!` (section 3). Its calls, in order (the first 3 lines are the lines of slice 070, step 2a):

| Step | Call | Result |
| --- | --- | --- |
| 1 | One `list_dirs!` of `[packages/<base>]` | The dir is there: `Ok`, no more call |
| 2 | The repository of the group of the header URL of the entry (`Ident.of_url`: `name`, `group`), then `PickIndex.index!` for that name (the calls of `Github.releases!`, the `warning:` lines and the line `index: cached at <time>`) | A list that is `missing`: `Github.no_page_failure(<name>)` (exit 15) |
| 3 | `Patched.base_release({ urls, group, base })` | `Err(NoRelease)`: `Patched.base_missing` (exit 14) |
| 4 (new) | `Ok(url)`: one `Fetch.packages!` of `[url]` with the `offline` flag of the request, `unbundler: Choose({ selected, none })` of the request and the downloader of `request.net` (the calls of `fetch/fe-flow`: `random`, `list_dirs` of the packages dir, the download, `roc unbundle`, `rename`, `delete` of the temp dir) | `[Err(fail)]`: that failure (`--offline`: exit 15 `<name> <version> is not in the package cache and --offline is set (<url>)`). Else `Ok` |

| Caller | When | After the `Ok` |
| --- | --- | --- |
| `PatchApply.rebase_one!` (step 2a of `install`, `update`, `upgrade`) | For each entry that needs a rebase (as in slice 070) | The tree read of step 2 (`packages/<base>`, the copy, `packages/<new hash>`) |
| `PatchFlow.review!` (step 5b of `tln patch --diff`, new) | After the fetch of the header package, and only when the `base` of the entry is not the hash of the header entry (when it is, the fetch of the header package is the fetch of the base). `dir` is the copy dir with no `/` at the end | The 2 trees are read and the diff is printed |

An entry with no GitHub name (a release URL of another host, `Ident.name` is `Err`) and a base that is not in the cache (manager answer Q1, 2026-10-26): no list can exist for that host (R-DI11), so it is not a missing-cache case. Step 1 is as above, then no index call: `Patched.base_missing` with `group.form` (the URL form of the group) as `name`, exit 14, also with `--offline`. A URL that is not a release is no `[patch]` entry (R-PA14, `Patched.entries`): `Ok`, unreachable.

## 3. Public signatures (the code agent keeps them)

| Function | Signature | Stub |
| --- | --- | --- |
| `PatchApply.base!` | `Fx, ResolveBase.Request, { alias : Str, url : Str, base : Str, dir : Str } => Try({}, Fail)` (`url` is the header URL of the entry, `dir` is the copy dir with no `/`, for the failure text) | `crash "todo: slice 070b"`. Nothing calls it yet |

The code agent writes: the body (the private `base_check!` of slice 070 has steps 1 to 3; step 4 is new; `base_check!` goes away), the call in `PatchApply.rebase_one!` (in place of `base_check!`), and the call in `PatchFlow.review!` after `fetch!(fx, facts)?`: `if entry.base != facts.target.hash { PatchApply.base!(fx, facts.request, { alias, url: facts.target.url, base: entry.base, dir: copy.drop_suffix("/") })? }`. No other module changes. `PatchFlow` gets the import `PatchApply`.

## 4. Files

| Path | Lines | State |
| --- | --- | --- |
| `cli/lib/PatchApply.roc` | 295 | The stub `base!`, docs of step 2a |
| `cli/lib/PatchFlow.roc` | 155 | Docs only (step 5b) |
| `tests/commands/cases/patch/pa4-base-missing/` | 7 runs (+4) | The new projects `p2` (a copy of `p1` with the base of json 2.1.0) and `p3` (a release URL of another host), `fx/commands` (3 new lines), `fx/jobs` (the fake download and unbundle of the base), `fx/programs` (`curl`), new expected files, the `rules` text |
| `tests/commands/cases/patch/pa1-flow/` | 15 runs | New `fx/http` (the release list of acme/json), run 15 changes, the `rules` text |

## 5. Tests

| Layer | File and case | Content | Rule ids |
| --- | --- | --- | --- |
| L2 | `patch/pa4-base-missing` run 4 | `install --offline` on `p2`: the base (json 2.1.0, DBH2...) is not in the cache, the cached list has a release with that hash, so the fetch starts and `--offline` stops it: exit 15, the line `index: cached at <time>`, no download call, no write but `projects.json`. This is the path of `PatchApply` | R-PA13 R-PA5 R-FE7 R-DI12 |
| L2 | same, run 5 | `patch json --diff` on `p2`, online: the list is requested again, the base is fetched by hash (download, `roc unbundle`, `rename` in `calls.log`), the 2 dirs are read, the diff of the copy against the base is printed (the base files hold the fake text `fake`), exit 0. `tree.diff` has the base package and the index pages and no project file | R-PA3 R-PA13 R-DI2 |
| L2 | same, run 6 | `patch json --diff` on `p1` (the base that no release has): exit 14, the text of `Patched.base_missing`, `tree.diff` has the index pages only. It was exit 18 | R-PA3 R-PA13 R-EC14 R-PA5 |
| L2 | `patch/pa1-flow` run 15 (changed) | The base of `p7` is not in the cache, not the header hash: the list is requested (the new `fx/http`), no release has the hash: exit 14 (it was exit 18 `cannot read <dir>`) | R-PA13 R-PA3 R-EC14 |
| L2 | same, run 7 | `install --offline` on `p3` (a header release URL of `example.org`, a base that is not in the cache): exit 14, `Patched.base_missing` with the name `example.org/acme/json/releases/download/{v}/`, no index call, no fetch. Not exit 15 (offline) and not exit 18 | R-PA13 R-DI11 R-EC14 |

L0 count: none new. Deep cases: 2 L2 cases (4 new runs in one, 1 changed run in the other).

## 6. Output (proposed, TW24, R-OUT2)

| Output | Text | Where |
| --- | --- | --- |
| Other host, base not in the cache (run 7) | `the patch of <alias> has the base <base>, and no release of <URL form of the group> has that hash, ...` (the text of `Patched.base_missing`; the name is `group.form`) | run 7 |
| Offline, the base is not in the cache | `acme/json 2.1.0 is not in the package cache and --offline is set (<url>)` (the old text of `Fetch.offline_missing`, kind `network`) | run 4 |
| `--diff` with no release that has the base | The text of `Patched.base_missing` (slice 070), kind `frozen`: `the patch of <alias> has the base <base>, and no release of <name> has that hash, so Talon cannot take the diff of the copy. Edit the copy <dir>/, or remove the [patch] entry <alias>.` | run 6, `pa1-flow` run 15 |
| The diff of run 5 | The unified diff of R-PA7 (the old text of `PatchCmd.shown`) | run 5 |

No new `data` field and no new human line.

## 7. Changes of old tests (TW21)

The old expected files were copied to `research/slice-070b-revert/before/` first. Each changed file was read (the diff of each file with its copy).

| Case | File | Change |
| --- | --- | --- |
| L2 `patch/pa1-flow` | `calls.log` (run 15), `stderr`, `stdout`, `tree.diff` | Run 15: the call `list_dirs <base> <copy>` is now `list_dirs <base>`, then `list_dirs` of the index dir, `programs gh`, `http_get` of the list (no token), `write_atomic` of the 2 index files. The failure is the `base_missing` text (exit 14, it was `cannot read <dir>`, exit 18). `tree.diff` has the index page. No other run changes: the base is the header hash in the runs 9 to 11 (no new call) |
| L2 `patch/pa4-base-missing` | all expected files | The 3 new runs at the end. The old runs 1 to 3 are the same |

No other old case changes (the run of all 180 L2 cases with the reference was green).

## 8. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `tln patch --diff` makes the index calls and the fetch of the base. They write cache files (the index pages, `packages/<base>`), and no file of the project. R-PA3 "It writes nothing" is read as "no project file, no patch file" | A lookup with the cached pages only (a `--diff` with no cached list would be exit 15 for no reason: the user did not say `--offline`) |
| D2 | `--diff` looks up the base only when the `base` is not the hash of the header entry. A `base` that is the header hash is the package that `fetch!` already has (the calls of the runs 9 to 11 do not change) | The lookup in every `--diff` (an extra `list_dirs` in each run: 3 more changed calls.log files) |
| D3 | The fetch of the header package stays before the lookup of the base in `--diff` (the old order of the calls) | The lookup first (it changes the calls of the runs where the header package is missing) |
| D4 | Run 5 and run 6 use the same case as run 4 (the same list, the same home), so the cache that run 3 filled (`index: cached at`) is the start of the runs 4 to 6. An online run asks for the list again (the cached page has no ETag in the fixture) | A new case (more fixtures, the same rows) |
| D5 | The fake base package has the text `fake` in each file (the fake `roc unbundle` makes items with that text), so the diff of run 5 shows the whole copy as a change. It checks that the base was read, not the content of a real package | A base with real files (the fake jobs table can only make items with the text `fake`) |

## 9. Out of scope

| Part | Reason |
| --- | --- |
| A fetch that fails for a reason other than `--offline` (a 404, a bad hash, no download program) in `base!` | The code is `Fetch.packages!`, tested by `fetch/fe-flow`. `base!` passes the failure as it is |
| The online run of `install` that fetches the base and goes on to the rebase | The path after the fetch is the tree read of slice 043 (`pa2-resolve`). The fetch is shared code (`base!`), tested by run 5, and `PatchApply` is wired by run 4 (mutation m4 of section 12). A full run needs the ladder tables of `pa2-resolve` |
| L3 | The L2 cases are the contract. The L3 fake HTTP serves release assets only for `tools`, not for a `[patch]` base |
| A release list with a registry (P2) | Design 7: P2 |

## 10. Questions and manager answers (2026-10-26)

Decisions D1 to D5 are accepted. Answers:

| # | Question | Answer |
| --- | --- | --- |
| Q1 | A base that is not in the cache, for an entry with a release URL of a host other than `github.com` (no `owner/repo`) | Option (a): exit 14, `Patched.base_missing` with the URL form of the group as the name, online and offline. No list can exist for that host, so it is not a missing-cache case (not exit 15). Done in this slice: L2 run 7, mutation m6, section 2 |

## 11. Red output

Run with the stub in the tree and the private reference away.

| Step | Result |
| --- | --- |
| check, fmt | pass (the stub compiles, `roc fmt --check` exits 0) |
| l2 | FAIL: `patch/pa4-base-missing` (runs 4 to 7: exit 18, `cannot read <dir>`, in place of 15, 0, 14 and 14) and `patch/pa1-flow` (run 15: exit 18 in place of 14, and the calls of the lookup are missing). The other 178 cases pass |
| l0, l1, l3, selftest | not run for this slice (no file of them changes) |

With the reference in the tree all 180 L2 cases pass.

## 12. Revert check (TW12)

6 changes of the private reference, one at a time, compile-checked, with the filtered run of `patch/` (L2). The reference is put back after each change All 6 are caught. The script and the reference are deleted (manager, 2026-10-26).

| Id | Change | Caught by |
| --- | --- | --- |
| m1 | The fetch of the base ignores `--offline` (`offline: Bool.False`) | L2 `pa4-base-missing` run 4 |
| m2 | `--diff` does not call `base!` | L2 `pa1-flow` run 15, `pa4-base-missing` run 6 |
| m3 | The fetch takes the header URL in place of the URL of the release that has the hash | L2 `pa4-base-missing` runs 4, 5 |
| m4 | `rebase_one!` does not call `base!` (no lookup for `install`) | L2 `pa4-base-missing` run 4, `pa2-resolve`, `pa3-buildfail` (the `list_dirs` of the base is missing) |
| m5 | `--diff` calls `base!` also when the base is the header hash (D2) | L2 `pa1-flow` (an extra `list_dirs` in runs 9 to 11) |
| m6 | An entry with no GitHub name skips the lookup (the old behavior: exit 18) | L2 `pa4-base-missing` run 7 |

## 13. Next step

The manager accepted the tests and answered Q1 (section 10). The code agent writes the body of `base!` (with the other-host rule of section 2) and the 2 calls (section 3). The private reference is deleted.

## 14. Disputes (from the code agent)

None. No test, fixture or expected file changed.

## 15. Decisions of the code agent

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `PatchApply.base!` first checks `Ident.safe_part(base)` (slice 076: the base is a part of a cache path). A base that is not safe: failure kind `Usage`, `the base <base> of the patch <alias> is not a hash`. `Intent` already refuses such a base (R-PA12), so no command reaches this failure | No guard in `base!` (the module would join a text from outside into a path with no check of its own) |

## 16. Verify results (code agent, TW12)

5 mutations, one at a time, each put back (the files are equal to `research/slice-070b-revert/code-final/`), run with the L2 step.

| Id | Mutation | Result |
| --- | --- | --- |
| m1 | The fetch of the base gets `offline: Bool.False` | Caught: L2 `patch/pa4-base-missing` |
| m3 | The fetch takes the header URL in place of the URL of the release that has the hash | Caught: L2 `patch/pa4-base-missing` |
| m4 | `rebase_one!` does not call `base!` | Caught: L2 `patch/pa2-resolve`, `pa3-buildfail`, `pa4-base-missing` |
| m5 | `--diff` calls `base!` also when the base is the header hash | Caught: L2 `patch/pa1-flow` |
| m6 | An entry with no GitHub name skips the lookup | Caught: L2 `patch/pa4-base-missing` |

Not caught: none.

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-070b-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, both slices in) | Exit 0, all 7 steps |
| Gap step | Skipped: 11 of 11 code-agent mutations caught, no new decision that needs a test |
