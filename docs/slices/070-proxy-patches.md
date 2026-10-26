# 070 Patches in the proxy for every rank, and a missing base

Phase: P1. Status: done

Slice 070 is the plan row 070 of `PLAN-P1.md` (section 2c), from the answers of the design agent to questions Q1, Q2 and Q8 of slice 043 (`DESIGN-GAPS-2026-10-25.md`): the proxy reads `[patch]` of the nearest `talon.toml` of the target file for every rank (also `roc +<id>` and `ROC_TOOLCHAIN`, R-PX5), and a `base` that no release of the group has gives exit 14 (it is exit 18 now, R-PA13). The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files, the stubs and the generators of the L2 cases are in `research/slice-070-revert/` (`before/NEW.txt` lists the new files).

## 1. Rules

| Id | Text (short) | Tested by |
| --- | --- | --- |
| R-PX5 (CLI 6.2) | The proxy adds `--replace-dep` for each `[patch]` entry of the nearest `talon.toml` of the target file (R-PD7, R-PD6), for each selected compiler: also rank 1 (`roc +<id>`) and rank 2 (`ROC_TOOLCHAIN`). A stale patch stops it before the compiler, exit 14 | L0 `ProxyTest` expect 7 (the files that are read). L2 `proxy/px4-patch-early` runs 1 to 8. Old L0 `PatchedTest` `proxy_args` (no change) |
| R-PD6, R-PD7, R-WS5 (nearest file, no merge) | A member with a `talon.toml` of its own: its `[patch]` is the one that counts, the root file is not merged. A member with none: the root file | L0 `ProxyTest` expect 7. L2 `px4-patch-early` runs 5 to 7. Old L2 `proxy/px1-flow` (a changed `read_files` line) |
| R-PA6, R-EC14 (stale patch, exit 14) | A stale patch stops the proxy for rank 1 and 2 too | L2 `px4-patch-early` run 3 |
| R-PX7, R-PX3 (as limits) | `TALON_PROXY=0` does no extra work (also for rank 1). No `talon.toml`: no read, the arguments are as they are | L2 `px4-patch-early` runs 4 and 8 |
| R-PA13 (CLI/Resolution 7) | The base of a patch that is not in the cache: the URL comes from the release list of the group of the entry. No release of the group has the hash: exit 14 with the base, the alias and the 2 fixes of R-PA5. `--offline` with no cached list: exit 15 | L0 `PatchedTest` expects 8 and 9. L2 `patch/pa4-base-missing` runs 1 to 3. Old L2 `pa2-resolve`, `pa3-buildfail` (a changed `calls.log`) |
| R-PA5, R-PA6, R-DI12 (as used) | The rebase that needs the base (`tln install` of a stale patch), the line `index: cached at <time>` | L2 `pa4-base-missing` runs 2, 3 |

`MISSING=1 scripts/rules.sh R-PX R-PA` lists no id after this slice that it listed before.

## 2. Flow (what the L2 cases fix)

### 2.1 The proxy (`Proxy.go!`, `Base.load!`)

| Case | Reads (one `read_files!`, after `Known.record_recent!`) | Result |
| --- | --- | --- |
| Not early (no `roc +<id>`, no `ROC_TOOLCHAIN`) | `Base.load_paths` with `Read`: the project file, the root `talon.toml` (the file of a workspace root or of a standalone project), the nearest `talon.toml` of the target file when it is another file (new: a member that has its own), `config.toml`, `.roc-version` | As before. `[patch]` comes from the nearest file, `[toolchain]` from the root file |
| Early, opted out (`TALON_PROXY=0`) | None, no project | No check, no flag (R-PX7) |
| Early, a project with a header and a `talon.toml` | `Base.load_paths` with `Patches`: the project file and the nearest `talon.toml` of the target file. Nothing else (no `config.toml`, no `.roc-version`, not the root file of a member that has its own) | `Base.Loaded` is `Base.no_facts` with `patch` only (the compiler is given). A stale patch: exit 14 (the check is before the list of the toolchains). Else `--replace-dep` at step 12 |
| Early, no `talon.toml` or no project file | None (no call: the calls are those of an early run before the slice) | No patch, the arguments are as they are |

`[patch]` is read with `Intent.read`: role `Root` for the root file (or the file of a standalone project), role `Member` for a member file of its own (R-WS5: the tables that it may have). A file that does not parse is exit 19 (question Q2).

### 2.2 The missing base (`PatchApply`, new step 2a)

| Step | Call | Result |
| --- | --- | --- |
| 2a-1 | For each entry that needs a rebase, before the tree read of step 2: one `list_dirs!` of `[packages/<base>]` | The dir is there: step 2, as before |
| 2a-2 | The dir is missing: the repository of the group of the header URL of the entry (`Ident.of_url(entry.url)`: `name`, `group`), then `PickIndex.index!` for that name (the calls of `Github.releases!`, the `warning:` lines and the line `index: cached at <time>` of the pick) | A list that is `missing` (`--offline`, no cached page): `Github.no_page_failure(<name>)`, exit 15 |
| 2a-3 | `Patched.base_release({ urls: <the URL of each candidate>, group, base })` | `Err(NoRelease)`: `Patched.base_missing`, exit 14. A release with the hash: see Q1 |

`Patched.base_missing` is of kind `Frozen` (exit 14), not a `NoTuple`: `InstallFlow.attempts!` must not try another release, no other release helps. The extra `list_dirs` is in every rebase, so the `calls.log` of `pa2-resolve` and `pa3-buildfail` has one more line for each rebase (section 7).

## 3. Public signatures (the code agent keeps them)

| Function | Signature | Stub |
| --- | --- | --- |
| `Base.load_paths` | `{ source : [Read, Given, Patches], files : List(Str), root : List(Str), nearest : Try(Str, [NoToml]), config : Str, versions : List(Str) } -> List(Str)` (the doc has the table) | `crash "todo: slice 070"` |
| `Base.load!` | the last parameter is `[Read, Given(ConfigToml.Config), Patches]` (was without `Patches`) | the `Patches` arms `crash "todo: slice 070"` |
| `Patched.base_release` | `{ urls : List(Str), group : { form : Str, series : Str }, base : Str } -> Try(Str, [NoRelease])` | same |
| `Patched.base_missing` | `{ alias : Str, name : Str, base : Str, dir : Str } -> Fail` | same |

Docs only (the tables of the steps): `Proxy` (step 6), `PatchApply` (step 2a). The code agent writes: the 3 bodies; in `Base.load!` the use of `load_paths` and of the `[patch]` of the nearest file (a private function, the `read_toml` of the root file keeps `[toolchain]`); `Proxy.go!` (`Patches` for an early run that is not opted out: today `read = if early Ok(Base.no_facts) else ...`); `PatchApply.rebase_one!` (step 2a, a private function). No other module changes. A guard in `Base.load!`: with `Patches` and no path, no `read_files!` call (a `Read` or `Given` run keeps its calls, also an empty one).

## 4. Files

| Path | Lines | State |
| --- | --- | --- |
| `cli/lib/Base.roc` | 337 | `load_paths` (stub), `Patches` in `load!` (stub arms), docs |
| `cli/lib/Patched.roc` | 142 | `base_release`, `base_missing` (stubs) |
| `cli/lib/Proxy.roc`, `cli/lib/PatchApply.roc` | 293 and 252 | Docs only (step 6, step 2a) |
| `tests/unit/PatchedTest.roc` | 333 (+45) | 2 new `expect`s, at the end (`l0-1`) |
| `tests/unit/ProxyTest.roc` | 231 (+25) | 1 new `expect`, at the end (`l0-6`) |
| `tests/commands/cases/proxy/px4-patch-early/` | 8 runs | New (generator `gen-px4.py`) |
| `tests/commands/cases/patch/pa4-base-missing/` | 3 runs | New (generator `gen-pa4.py`) |
| Old expected files | 3 L2 cases | Section 7 |

## 5. Tests

| Layer | File and case | Content | Rule ids |
| --- | --- | --- | --- |
| L0 | `PatchedTest` expect 8 | `Patched.base_release` (8 rows: the oldest release, the header release, a hash that no release has, a release of another series, of another repository, no URL, a URL that is no release is skipped, 2 releases with the hash: the first) | R-PA13 |
| L0 | `PatchedTest` expect 9 | `Patched.base_missing` (the line with the base, the alias, the repository, the copy dir and the 2 fixes; the exit code 14) | R-PA13 R-PA5 R-EC14 |
| L0 | `ProxyTest` expect 7 | `Base.load_paths` (11 rows: `Read` standalone, member of the root file, member with its own file, no `talon.toml`, no project; `Given` with no config; `Patches` standalone, member with its own file (not the root), member of the root file, no `talon.toml`, no project file) | R-PX5 R-PD6 R-PD7 R-WS5 R-SO3 R-SO4 R-SO5 |
| L2 | `proxy/px4-patch-early` runs 1 to 8 | `roc +<id>` (rank 1), `ROC_TOOLCHAIN` (rank 2), a stale patch for rank 1 (exit 14, no `exec`), no `talon.toml` (no read), a member with its own `talon.toml` (rank 3: root and nearest read, the flag has the copy of the member), the same with rank 1 (only the member file is read), a member with no file of its own (the root file counts), `TALON_PROXY=0` with rank 1 (no read, no flag) | R-PX5 R-PD6 R-PD7 R-WS5 R-PA6 R-PA10 R-PX7 R-PX3 R-SO1 R-SO2 R-EC14 |
| L2 | `patch/pa4-base-missing` runs 1 to 3 | `install` of a stale patch whose base is not in the cache and that no release has: `--offline` with no cached list (exit 15), the live list (2 index files written) and exit 14, `--offline` again from the cached list (exit 14 and `index: cached at <time>` from `fx/mtimes`) | R-PA13 R-PA5 R-PA6 R-DI12 R-EC14 R-DI2 |

L0 count: 3 new `expect`s in 2 files (`PatchedTest`, `ProxyTest`). Deep cases: 2 new L2 cases (8 and 3 runs).

## 6. Output (proposed, TW24, R-OUT2)

| Output | Text | Where |
| --- | --- | --- |
| No base, exit 14 | `the patch of <alias> has the base <base>, and no release of <name> has that hash, so Talon cannot take the diff of the copy. Edit the copy <dir>/, or remove the [patch] entry <alias>.` (kind `frozen`) | L0 expect 9, `pa4-base-missing` run 2 |
| Offline, no list, exit 15 | `the index of <name> has no cached page and --offline is set. Run the command without --offline.` (the old text of `Github.no_page_failure`, kind `network`) | `pa4-base-missing` run 1 |
| The proxy | No output. The flags are in the `exec` call. The stale text is the old text of slice 043 | `px4-patch-early` run 3 |

No new `data` field. `--json` of `install` gives the failure as for any other failure.

## 7. Changes of old tests (TW21)

The old expected files were copied to `research/slice-070-revert/before/` first. Each changed file was read (the diff of each file with its copy): only added lines, and 1 changed line.

| Case | File | Change |
| --- | --- | --- |
| L2 `patch/pa2-resolve` | `calls.log` | 12 new lines `list_dirs $HOME/.cache/roc/packages/<base>`, one before the tree read of each rebase (also each repeat of a rebase after a dropped release). Nothing else changes (`stdout`, `stderr`, `tree.diff` are the same) |
| L2 `patch/pa3-buildfail` | `calls.log` | 2 new lines of the same kind |
| L2 `proxy/px1-flow` | `calls.log` | The run in a workspace member that has a `talon.toml` of its own (`pw/apps/a`): its file is in the `read_files` call (the nearest `talon.toml`, after the root file) |
| L3 `compilers/px3-proxy-patch` | none | The real launcher, no early run with a `talon.toml`: no change |

No other old case changes (the run of `scripts/test.sh` with the reference was green).

## 8. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | An early run reads only the project file and the nearest `talon.toml`, and `Loaded` is `Base.no_facts` with `patch`. A broken `config.toml` or `.roc-version`, or a pin, does not matter for a given compiler (R-SO1, R-SO2) | The full read (R-SO3 to R-SO6) for every rank: it costs reads and can stop `roc +<id>` for a file that the rank does not use |
| D2 | No `talon.toml` (or no project file): no read at all, so the old early runs keep their calls | A read of the project file only |
| D3 | The nearest file of a member is read with the role `Member`. The root file of a member that has its own file is not read in an early run (R-WS5: no merge) | The root file always (it would give a patch that the member does not own) |
| D4 | One extra `list_dirs!` of `packages/<base>` before the tree read, in every rebase. The calls fix it, so the code agent has no choice about it | A structured failure of `PatchTree.read!` (no extra call, but a change of the signature of `PatchTree.read!`, which `PatchFlow` also uses) |
| D5 | The lookup uses `PickIndex.index!` for the repository of the entry (the calls, the warnings and the offline line of the pick), with `known: []` | A new reader of the pages |
| D6 | `base_missing` is of kind `Frozen` (exit 14). It is not a `NoTuple`: `InstallFlow.attempts!` would try the next release for nothing | Kind `NoTuple` (exit 10) |
| D7 | The group of the entry is the group of its header URL (`Ident.group`: the URL form and the series). A release of another series, with the same hash, does not count. A hash is a content id, but R-PA13 says "the release list of the group" | The whole repository |

## 9. Out of scope

| Part | Reason |
| --- | --- |
| A base that a release of the group has (R-PA13: Talon fetches it by hash) | PLAN row 070 names the exit 14 only. A download in L2 needs the fake jobs of `fetch/fe-flow` and a base tree that the diff can use. Question Q1. The reference goes on to the tree read, so the failure is `cannot read <dir>` (exit 18) as before |
| `tln patch --diff` with a missing base (`PatchFlow`, slice 042) | Question Q3 |
| A `talon.toml` that does not parse, in an early run | Question Q2 |
| The `[patch]` of a member in `update`, `upgrade`, `verify` (Q8 of slice 043 for the commands that resolve) | The row names the proxy. `PatchApply.entries` reads the table of the member (`Vars.Member.toml`) as before |
| L3 | The L2 cases are the contract. The real launcher has the old case `px3-proxy-patch` (no early run) |

## 10. Questions and manager answers (2026-10-25)

Decisions D1 to D7 are accepted. Answers:

| # | Question | Answer |
| --- | --- | --- |
| Q1 | Is the fetch of a base that a release has part of slice 070? | Out of scope. The manager adds a follow-up row: fetch a base that a release has (R-PA13). Until then the failure is `cannot read <dir>` (exit 18) |
| Q2 | A `talon.toml` that does not parse, in an early run | Exit 19, as the other ranks. No test |
| Q3 | `tln patch --diff` with a missing base | Out of scope. The same follow-up row: `tln patch --diff` uses `Patched.base_missing` too |

## 11. Red output

Run with the stubs of this slice in the tree (the private reference away; the reference of slice 068 in the tree, so that only this slice is red).

| Step | Result |
| --- | --- |
| check, fmt | pass (the stubs compile) |
| l0 | FAIL (8.3 s): `l0-1` (`PatchedTest`) 91 passed, 2 failed, `l0-6` (`ProxyTest`) 1 failed: the 3 new expects (`todo: slice 070`). All other files pass |
| l2 | FAIL (8.6 s): 172 passed, 5 failed: `proxy/px4-patch-early` (no flag for rank 1 and 2, no exit 14), `patch/pa4-base-missing` (exit 18 in place of 14 and 15), and the 3 old cases of section 7 (a wrong value: the new `calls.log` lines) |
| l3, selftest, l1 | pass |

The old tests of section 7 are red on purpose. All other old tests pass. With the reference in the tree `scripts/test.sh` exits 0 (check 2.7 s, l0 9.2 s, l2 11.1 s, l3 10.1 s, selftest 3.5 s, l1 34.7 s).

## 12. Revert check (TW12)

6 changes of the private reference, one at a time, each compile-checked, with filtered runs only (L0 `l0`, L2 `proxy/` and `patch/`). The reference is put back after each change. All 6 are caught. The script, the logs and the reference are deleted (manager, 2026-10-25).

| Id | Change | Caught by |
| --- | --- | --- |
| n2 | `[patch]` is read from the root file, not from the nearest file | L2 `px4-patch-early` runs 5 and 6 |
| n3 | `ROC_TOOLCHAIN` (rank 2) reads no patch (only rank 1 does) | L2 `px4-patch-early` run 2 |
| n4 | `--offline` with no cached list is "no release has it" (exit 14, not 15) | L2 `pa4-base-missing` run 1 |
| n5 | `base_release` does not check the group (series and repository) | L0 `PatchedTest` expect 8 |
| n6 | A stale patch stops only the proxy runs of rank 3 and later | L2 `px4-patch-early` run 3 |
| n7 | `Patches` with no `talon.toml` still makes an empty `read_files` call | L2 `px4-patch-early` run 4 |

## 13. Next step

The manager reviewed the slice (section 10). The code agent writes the bodies of section 3 and the wiring. The private reference is deleted.

## 14. Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## 15. Verify results (code agent)

Code: `cli/lib/Base.roc` (`load_paths`, `Patches` in `load!`, the private `patch_table`, `unread`, `no_config`), `cli/lib/Patched.roc` (`base_release`, `base_missing`, the private `in_group`), `cli/lib/Proxy.roc` (the `Patches` read of an early run that is not opted out), `cli/lib/PatchApply.roc` (step 2a: the private `base_check!`, which calls `PickIndex.index!`). `scripts/test.sh` exit 0. 5 mutations, one at a time, with filtered runs only. The code is the same as before the mutations (compared with `cmp`).

| Mutation | Result |
| --- | --- |
| `ROC_TOOLCHAIN` (rank 2) reads no patch | Caught: L2 `px4-patch-early` |
| `--offline` with no cached list gives `base_missing` (exit 14) in place of exit 15 | Caught: L2 `pa4-base-missing` run 1 |
| `base_release` does not check the group | Caught: L0 `PatchedTest` (`l0-1`: 1 failed) |
| A stale patch stops only a run that is not early | Caught: L2 `px4-patch-early` run 3 |
| The `[patch]` of a member that has its own `talon.toml` comes from the root file | Caught: L2 `px4-patch-early` |

Question for the manager: the base that a release has is not fetched (Q1, out of scope): step 2a goes on to the tree read, which fails with `cannot read <dir>` (exit 18), as the slice file says.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-070-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, both slices in) | Exit 0, all 7 steps, 177 L2 cases |
| Gap step | Skipped: 9 of 9 code-agent mutations caught, no new decision that needs a test |
| `base_check!` with no GitHub name or a foreign URL | Skips the lookup, so the failure stays `cannot read <dir>` (exit 18). Added to row 070b. |
