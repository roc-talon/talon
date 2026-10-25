# 043 Patches in resolve and the proxy

Phase: P1. Status: done

Slice 043 is the plan row 043 of `PLAN-P1.md`. It needs 036 and 042 (done). A patched entry is an anchor in `update` and `upgrade`. A move applies the diff of the copy to the new release. A stale patch is exit 14. `--replace-dep` is in the proxy and in the probes.
The private reference has about 430 lines of code without comments and empty lines (`Patched` about 60, `PatchApply` about 190, `PatchTree` about 60, and about 120 lines of wiring in 9 old modules). No module has more than 450 lines.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-PA4 | A patched entry is an anchor in `update` and `upgrade` (note `json: patched, held`). A command that names the entry frees it | L0 `VarsTest.roc` expect `patched` (9 rows), expect `workspace` (2 rows). L2 `pa2-resolve` runs 1, 2, 4 |
| R-PA5 | A move applies the diff of the copy to the new release in a temp copy. A release on which it does not apply is not a candidate. The header write replaces the copy and sets `base`. No candidate: exit 10, files listed, 2 fixes | L0 `PatchedTest.roc` expects `need`, `rebase`, `not_applied`. L2 `pa2-resolve` runs 4, 5, 6, 10 |
| R-PA6 | A `base` that is not the header hash is a stale patch. Proxy: exit 14. `install --frozen`: exit 14. `tln install` applies the patch to the header release and does not change the header | L0 `PatchedTest.roc` expects `entries`, `stale_fail`, `need`. L2 `pa2-resolve` runs 3, 7, 8. L2 `px3-patch` runs 5, 6. L3 `px3-proxy-patch` |
| R-PA10 | `--replace-dep <header URL> <path>` for each `[patch]` entry in the proxy and in the probes (baseline, candidate, build, `verify`) | L0 `PatchedTest.roc` expects `entries` (replaces), `with_patches`. L2 `pa2-resolve` runs 4, 6, 9. L2 `px3-patch`. L3 `px3-proxy-patch` |
| R-PX5 | The proxy adds `--replace-dep` for each `[patch]` entry. A stale patch stops it before the compiler, exit 14 | L0 `PatchedTest.roc` expect `proxy_args` (17 rows). L2 `px3-patch` all runs. L3 `px3-proxy-patch` |
| R-PX7, R-PX3 (as limits) | `TALON_PROXY=0` does no extra work. No `[patch]`: the arguments are as they are | L2 `px3-patch` runs 6 to 8. L3 `px3-proxy-patch` |
| R-SP6, R-SP23, R-PA12 (as used) | `upgrade` holds a patched entry. The `[patch]` table is read | L0 `VarsTest.roc`. L2 `pa2-resolve` run 2 |
| R-EC10, R-EC14, R-CC2, R-LF4, R-BL1, R-BL2, R-BL6, R-CM11, R-AL6 (as used) | exit 10 and 14, the temp dirs are deleted, `--dry-run`, the probes, `--no-check`, `verify` | L2 `pa2-resolve` |

## 2. Public signatures (stubs in `cli/lib/`, `crash "todo: slice 043"`)

| Name | Signature | File |
| --- | --- | --- |
| `Patched.Entry` | `{ alias, url, hash, base, path, file, dir }` (all `Str`) | `cli/lib/Patched.roc` |
| `Patched.entries` | `{ rows : List(Locked.Row), patches : List(Intent.PatchEntry), toml : Str } -> List(Patched.Entry)` | same |
| `Patched.replaces` | `List(Patched.Entry) -> List(LadderPlan.Replace)` (stub: `[]` for `[]`) | same |
| `Patched.stale` | `List(Patched.Entry) -> List(Patched.Entry)` (stub: `[]` for `[]`) | same |
| `Patched.stale_fail` | `{ entries, by : [Proxy, Frozen] } -> Fail` | same |
| `Patched.proxy_args` | `{ args, target : [File(Str), Main, NoFile], replace } -> List(Str)` (stub: the arguments when `replace` is empty) | same |
| `Patched.need` | `{ entries, chosen : List({ alias, url }), install : Bool } -> List({ entry, url, hash })` | same |
| `Patched.rebase` | `{ base, copy, target : List(Diff.File) } -> Try(List(Diff.Applied), List(Str))` | same |
| `Patched.not_applied` | `{ alias, name, version, hash, dir, files } -> Fail` | same |
| `PatchTree.read!` | `Fx, { dirs : List(Str), copy : Str } => Try(List(List(Diff.File)), Fail)` | `cli/lib/PatchTree.roc` |
| `PatchApply.Member`, `Rebased`, `Done` | records, see the file | `cli/lib/PatchApply.roc` |
| `PatchApply.none`, `entries`, `member` | `none : Done`. `entries : Vars.Member -> List(Patched.Entry)` (stub `[]`). `member : Done, Str -> { base, candidate }` (done: no patch gives empty lists) | same |
| `InstallWrite.write!` | new last parameter `PatchApply.Done` (the stub ignores it). The code agent adds the `talon.toml` edits of `done.rebased` to the second read, the check and the write | `cli/lib/InstallWrite.roc` |
| `PatchApply.run!`, `finish!`, `clean!` | `run! : Fx, Request, Loaded, { scoped, chosen } => Try(Done, Fail)`. `finish! : Fx, Request, Done => Try(List(Str), Fail)`. `clean! : Fx, Done => {}` | same |
| `Vars.Var.patched` | new field `Bool` (the stub gives `False`) | `cli/lib/Vars.roc` |
| `Base.Loaded.patch` | new field `{ replace : List(LadderPlan.Replace), stale : List(Patched.Entry) }` (the stub gives `[]`, `[]` in `patch_of`) | `cli/lib/Base.roc` |
| `LadderPlan.with_patches` | `{ plan, base, candidate } -> Plan` (stub: the plan for 2 empty lists) | `cli/lib/LadderPlan.roc` |
| `Ladder.Member.patch`, `Ladder.Checked.patch` | `{ base, candidate }`, `List(Replace)` | `cli/lib/InstallWrite.roc` (types) |

Wired already (the code agent keeps them): `main.roc` has `PatchApply`, `PatchTree`, `Patched` in its module list. `InstallFlow.finish!` calls `PatchApply.run!` before the ladder, the new `settle!` runs the ladder, the report of the moves, the write and `PatchApply.finish!`, and `PatchApply.clean!` runs after it also after a failure. `InstallFlow.frozen!` uses `Patched.stale(PatchApply.entries(m))`. `Proxy` uses `loaded.patch` and `Patched.proxy_args`. `InstallWrite.ladder_member`, `VerifyFlow.checked_members`, `RemoveFlow` give the patch fields. `PatchFlow.roc` is the file of slice 042: the code agent moves its tree reader to `PatchTree.read!` (the calls of `tln patch --diff` do not change).
The code agent writes: the bodies of `Patched`, `PatchApply`, `PatchTree`; `Vars.is_patched` with the changes of `scoped_one` and `movable_of`; `Base.patch_of` (it uses `Patched.entries`); `LadderPlan.with_patches`; and the bodies behind the pairs: `PatchApply.member` (used by `InstallFlow.ladder_member`) and `PatchApply.entries` (used by `Patched.replaces` in the verify list of `Ladder.roc`); the stubs give empty lists. `Ladder.probe_in_copy!` and `probe_in_place!` already call `with_patches`. The unit probes stay as they are (Q3).

## 3. The tested reading (the rules of the code)

| # | Rule | Source |
| --- | --- | --- |
| 1 | A patch entry is a `[patch]` entry whose key is the alias of a managed release entry that is not the platform. Other keys are skipped, with no failure (Q5). The order is the order of the `[patch]` lines | R-PA12, R-PA14 |
| 2 | `update` and `upgrade` with no names hold the patched variable (note `<alias>: patched, held`, never movable). A name frees it | R-PA4, R-SP6, R-SP23 |
| 3 | `Patched.need`: rebase when the new hash is not `base`, and the URL changes, or the command is `install` with no names | R-PA5, R-PA6 |
| 4 | `PatchApply.run!` makes no call when no member has a patch. With a rebase: `PatchTree.read!` of `[packages/<base>, copy, packages/<new>]`, `Patched.rebase`, then `random`, temp root `TalonTmp(patch-<hex>)/<alias>`, `copy_tree`, `write_atomic`, `delete`, `make_dirs`, `copy_file` | R-PA5, R-PA13, R-CC2 |
| 5 | A diff that does not apply: `Fail.of_tuple` (kind `NoTuple`, `again`): `InstallFlow.attempts!` drops the release. The last failure is the exit 10 text with the files and the 2 fixes | R-PA5, R-AL6, R-EC10 |
| 6 | The new `base` is an edit of `talon.toml` in `InstallWrite.write!`: the same second read, the same Guard check (R-CC7, span = the value of the key of the alias in `[patch]`, `IntentEdit.table_spans` with table `Patch`) and the same `write_atomic` as the keys (`IntentEdit.add_patch`, same path, new `base`). A conflict is exit 17 and nothing is written. Then `finish!`: delete the copy, `copy_tree` of the temp dir to it. With `--dry-run`: no write, no copy replaced, the same lines | R-PA5, R-LF4, R-CC7, R-EC17 |
| 7 | Probes: baseline check `--replace-dep` of the current copy; candidate check and build `--replace-dep` of the temp dir (rebased entry, new URL) or of the copy. `verify`: all three probes with the copies | R-PA10 |
| 8 | Proxy: after the read of the files, a stale patch is exit 14 (no toolchain list, no `.last-use`, no `exec`). Else the flags go at the end of the arguments before the first `--`. `TALON_PROXY=0`: no check, no flag | R-PX5, R-PA6, R-PX7 |
| 9 | `install --frozen`: a stale patch is exit 14 (before the other frozen checks of the member list) | R-PA6, R-EC14 |

## 4. Tests

| Layer | File and case | Content | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/PatchedTest.roc` expect `entries` (the rows: managed entries in table order, a path, platform, foreign URL, unknown key; `replaces`; `stale`) | the facts of the entries | R-PA12 R-PA14 R-PX5 R-PA10 R-PA6 |
| L0 | same, expect `stale_fail` | kind `Frozen`, the two texts | R-PA6 R-EC14 |
| L0 | same, expect `proxy_args` (17 rows) | the flags at the end, before `--`, no target, a first word that is no command, `-` options, `.roc` file, empty `replace`, order | R-PX5 R-PX3 R-PX7 R-PA10 |
| L0 | same, expect `need` (10 rows) | move, no move, `install`, a hash that is the base, a URL that is no release, `chosen` of another alias | R-PA4 R-PA5 R-PA6 |
| L0 | same, expect `rebase` (5 rows) | applies, moved hunks, a file that fails, binary, an added and a deleted file | R-PA5 R-PA7 |
| L0 | same, expect `not_applied` (3 rows) | kind `NoTuple`, `again` holds the hash, the text names the files and the 2 fixes | R-PA5 R-AL6 R-EC10 |
| L0 | same, expect `with_patches` (8 rows) | pairs at the end of the baseline, of the candidate and of the build, a plan with no build, empty lists | R-PA10 R-BL1 R-BL2 R-CM11 |
| L0 | `tests/unit/VarsTest.roc` expect `patched` (9 rows), expect `workspace` (2 rows), both new | `scope` in `update`, `upgrade`, a name, `NightlyOnly`, a range, `install`, a platform key, a key in a member `talon.toml` | R-PA4 R-SP6 R-SP23 R-PA12 |
| L2 | `patch/pa2-resolve` runs 1 to 12 | `update`, `upgrade` (held), `install` (no rebase), `update json` (2.3.0 dropped, 2.2.0 applies, probes with `--replace-dep`, copy replaced, base set), `update json@^2.3` (exit 10), `--dry-run`, `install --frozen` stale (exit 14), `install` stale (rebase on the header release), `verify`, `--no-check`, run 11 (an editor changes the `[patch]` entry during the probes: exit 17, nothing written), run 12 (an editor changes a comment: Talon applies its edit to the new text) | R-PA4 R-PA5 R-PA6 R-PA10 R-CC7 R-EC17 |
| L2 | `proxy/px3-patch` runs 1 to 8 | one patch, `build` with an option, before `--`, 2 patches in table order, stale (exit 14, no `.last-use`), `TALON_PROXY=0`, no `[patch]`, `version` | R-PX5 R-PA6 R-PA10 R-PX7 R-PX3 |
| L3 | `compilers/px3-proxy-patch` | the real launcher: 2 patches, a stale patch (exit 14), none | R-PX5 R-PA10 R-PA6 R-EC14 R-PX7 R-PX3 |

Deep cases: 3 (`pa2-resolve` 12 runs on 9 projects, `px3-patch` 8 runs, `px3-proxy-patch` 3 projects). The world of `pa2-resolve` is `research/slice-043-revert/gen-pa2.py` (`acme/pf 0.1.0`, `acme/json 2.1.0` the base, 2.2.0 takes the diff, 2.3.0 does not). `gen-px3.py` makes `px3-patch`.
Old tests that changed: `tests/unit/VarsTest.roc` (2 new expects at the end), `tests/unit/l0-1.roc` (the line `import PatchedTest`). No expected file of an old case changed (TW21 checked: the `UPDATE=1` runs were filtered to `patch/pa2-resolve` and `proxy/px3-patch`).

## 5. Output proposals (TW24, for the human review)

| Output | Text | In the test |
| --- | --- | --- |
| Held note | `json: patched, held` (the design gives it, R-PA4) | `pa2-resolve` runs 1, 2 |
| Rebase lines | `rebased: <dir>/ (the patch of <alias>, now on <name> <version>)` and `<toml>: ~ [patch] <alias> (base <hash>)`. Also with `--dry-run` | runs 4, 6, 8, 10 |
| Stale, proxy | `stale patch: <alias> (base <b>, the header has <h>), .... Run: tln install` | `px3-patch` run 5, L3 |
| Stale, frozen | `stale patch: ... tln install --frozen does not rebase a patch. Run: tln install` | `pa2-resolve` run 7 |
| Not applied | `no tuple works: the patch of <alias> does not apply to <name> <version>: <files>. Edit the copy <dir>/, or remove the [patch] entry <alias>.` | runs 4 (as the dropped tuple note), 5 |
| `--json` | no new `data` field. `written` has `talon.toml`, not the copy dir | none |

## 6. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | `PatchApply.run!` is just before the ladder, after the pick. A failed apply is a ladder failure (`Fail.of_tuple`): the tuple is dropped | An apply filter in the index domain (before the pick): the diff needs the files of each release, which the pick does not read (Q10) |
| D2 | One rule `Patched.need` for a move and for `tln install` (stale) | 2 functions |
| D3 | The probes get the pairs through the new `LadderPlan.with_patches`, not through new fields of `plan` | A new field in the old `plan` inputs (it changes old tests) |
| D4 | The new `base` is written with `IntentEdit.add_patch` (replaces the key), in the Guard read and write of `InstallWrite` (Review, Q11) | A new `IntentEdit` function. A second read of `talon.toml` with no Guard |
| D5 | The proxy gives the flag to `check build run test docs deps` and the bare form `roc [options] [file]` | Every command (roc refuses the flag for `fmt`, `bundle`, `repl`, Q4) |
| D6 | The temp root is `TalonTmp(patch-<hex>)`, with one dir for each alias | The ladder temp dir (it collides with the ladder copy) |
| D7 | `Frozen.check` is not changed. `InstallFlow.frozen!` has its own stale check | A new field in `Frozen.check` |

## 7. Questions (TW17, stop that part)

| Id | Question | In the stub and tests |
| --- | --- | --- |
| Q1 | The early rank of the proxy (`roc +id`, `ROC_TOOLCHAIN`) reads no file, so it has no patches. Does it need the flags? | Not changed, not tested |
| Q2 | The base package is not in the cache and is not the header entry: no URL to fetch it. The reference gives an Environment failure `cannot read <dir>` | Not tested |
| Q3 | Unit probes of a patched release | Unchanged, not tested |
| Q4 | Which `roc` commands take the flag (`fmt`, `bundle`, `repl`) | D5. No row in `proxy_args` |
| Q5 | A `[patch]` key that is no managed header entry: skipped, or an error? | Skipped (the rows of `entries`) |
| Q6 | A stale patch in `update`, `upgrade`, `verify`, `add`, `remove`: not rebased, the entry is held, the probes use the copy as it is | `need` rows |
| Q7 | R-PA10 in `tln remove`, `tln roc use`, `tln probe`: no flags | The reference passes empty lists |
| Q8 | A workspace: the proxy reads only the root `talon.toml`. A `[patch]` in a member `talon.toml`, 2 aliases of one group | `VarsTest` workspace rows only |
| Q9 | `tln install` that rebases a stale patch runs no probe (the ladder runs only when a header changes) | `pa2-resolve` run 8 |
| Q10 | The apply is checked after the pick (the tuple is dropped), not as a filter of the index domain | D1 |
| Q11 | `rebased:` lines with `--dry-run`. The base is written without Guard R-CC7 | Answered by the manager: see Review |

Design gaps: R-PA13 says Talon fetches `packages/<base>/` when it needs a diff, but `PatchApply.run!` has no URL for a base that is not a header entry (Q2). R-PA10 names probes and the whole-app check but not the unit probes (Q3).

## 8. Red run (stubs)

`scripts/test.sh` with the stubs (log: `research/slice-043-revert/red-run.log`). The old tests all pass.

| Step | Result | The new tests |
| --- | --- | --- |
| check, fmt | pass | The stubs compile |
| l0 | FAIL | `PatchedTest.roc`: 7 of 7 expects fail with `todo: slice 043` (`l0-1`: 53 passed, 7 failed). `VarsTest.roc`: expects `patched` (line 471) and `workspace` (line 542) fail by value: the stub has `patched: False` and no hold note (`Ok("json: patched, held")` wanted, `Err(None)` got) |
| l2 | FAIL (103 passed, 2 failed) | `patch/pa2-resolve` (12 runs): `[ROC CRASHED] todo: slice 043` (`PatchApply.run!` has a member with a patch). `proxy/px3-patch`: no flag in `exec` (4 runs), run 5 has exit 0 and no `stale patch` line, and the calls go on to `exec` |
| l3 | FAIL (63 passed, 1 failed, 1 skipped) | `compilers/px3-proxy-patch`: the same, the `ran ...:` lines have no `--replace-dep`, the stale project has exit 0 |
| selftest, l1 | pass | |

## 9. Revert check (mutations of the private reference)

13 mutations of the private reference (`mutate.py`, log `mutate.log`, A13 by hand after the review, each compile-checked, filtered runs only, the tree equal to the reference after the run). All are caught.

| Id | Mutation | Caught by |
| --- | --- | --- |
| A1 | `update` frees a patched entry | L0 vars, L2 `pa2-resolve` |
| A2 | A patched entry is movable | L0 vars |
| A3 | A failed diff has no `again` | L2 `pa2-resolve` |
| A4 | The temp copy keeps a file that the diff deletes | L2 `pa2-resolve` |
| A5 | `update` rebases a stale patch | L0 |
| A6 | The proxy stops with another exit kind | L0, L2 `px3-patch`, L3 |
| A7 | The flags go after `--` | L0, L2 `px3-patch`, L3 |
| A8 | The baseline check gets the pairs of the candidate | L2 `pa2-resolve` |
| A9 | `base` is not set to the new hash | L2 `pa2-resolve` |
| A10 | `TALON_PROXY=0` checks and flags | L2 `px3-patch`, L3 |
| A11 | `install --frozen` has no stale check | L2 `pa2-resolve` |
| A12 | `verify` has no pairs | L2 `pa2-resolve` |
| A13 | The Guard has no span of the `[patch]` entry (the editor change of run 11 is overwritten) | L2 `pa2-resolve` run 11 |

## 10. Compiler limits met

`package` is a reserved word (no variable of that name in the tests). A closed record parameter does not take a wider record. `roc test` segfaults when an `Err` record has a `Bool` field (the `rebase` rows use `Str` lists). A local name equal to a method of a type module is a duplicate. `roc build` exits 2 on a warning, so an unused import in a stub is an error.

## 11. Files

| File | Lines | State |
| --- | --- | --- |
| `cli/lib/Patched.roc`, `PatchApply.roc`, `PatchTree.roc` | 71, 77, 14 | new stubs |
| `tests/unit/PatchedTest.roc` | 288 | new (7 expects) |
| `tests/unit/VarsTest.roc`, `l0-1.roc` | n/a | 2 new expects, 1 import |
| `tests/commands/cases/patch/pa2-resolve/`, `proxy/px3-patch/` | 81, 29 files | new |
| `tests/scenarios/compilers/px3-proxy-patch/` | 14 files | new |
| `cli/lib/Vars.roc`, `Base.roc`, `Proxy.roc`, `InstallFlow.roc`, `InstallWrite.roc`, `Ladder.roc`, `LadderPlan.roc`, `VerifyFlow.roc`, `RemoveFlow.roc`, `PatchFlow.roc`, `main.roc` | n/a | changed (wiring, types, stubs). Copies of the old files: `research/slice-043-revert/before/` |
| `research/slice-043-revert/` | n/a | `before/`, `stubs/`, `swap.sh` (mode `stub` and `check`), `mutate.py`, `gen-pa2.py`, `gen-px3.py`, logs. The private reference is deleted (slice step 3 done) |

## Review (manager, 2026-10-24)

The manager accepted the slice with no split. D1 to D7 and the TW24 texts are accepted.

| Id | Answer |
| --- | --- |
| Q1, Q2, Q4, Q5, Q6, Q7, Q9, Q10 | Accepted as the reference does and as tested |
| Q2, Q3, Q8 | Design gaps (the manager records them in the design) |
| Q3, Q8 | Out of scope, as written in this file |
| Q11 | Changed. A write of `talon.toml` for a new `base` uses the same Guard (R-CC7) as the other writes of `talon.toml`. With `--dry-run`, the `rebased:` lines print, but nothing is written (no copy replaced, no `base` written). The dry-run case of a rebase is pinned by run 6 of `pa2-resolve` |

Changes after the review (the test agent): `pa2-resolve` has 2 new runs at the end (run 11: the editor changes the `[patch]` entry, exit 17, nothing written; run 12: the editor changes a comment, Talon applies its edit to the new text). The hooks are in `fx/hooks` (the 10th and the 12th `probes` call of the case). The `calls.log` of runs 4, 8 and 10 changed in the order of the calls: the `read_files` and `write_atomic` of `talon.toml` are now in the call of `InstallWrite.write!` (`talon.toml` first, then the header), and the copy is replaced after them. The old expected files were copied before the change (TW21): only these lines, the lines of runs 11 and 12, and the `projects.json` line of `tree.diff` changed. Run 11 has the proposal text `$PROJECT/p8/talon.toml changed while tln ran. Nothing was written. Run the command again.` (Guard text).

## Verify results (code agent, 2026-10-24)

`scripts/test.sh` exits 0: check 1.4 s, fmt 0.1, l0 7.0 (units 419 tests in 8 drivers, plus the package tests), l2 7.2 (105 cases, `patch/pa2-resolve` 12 runs, `proxy/px3-patch` 8 runs), l3 9.8 (64 passed, 1 skipped; `compilers/px3-proxy-patch` green), selftest 2.8 (68), l1 37.4. No `crash "todo` is left in `cli/` or `packages/`. No test was changed (no dispute rows). No public signature was changed.

Files of the code (lines, with comments): `Patched` 130, `PatchApply` 251, `PatchTree` 76 (the tree reader of `PatchFlow`, now for any number of dirs), `PatchFlow` 154 (the reader is replaced by a call of `PatchTree.read!`). Changed bodies: `Vars` (`is_patched`, `scoped_one`, `movable_of`), `Base.patch_of`, `LadderPlan.with_patches`, `InstallWrite.write!` and `changed_files!` (new `with_bases`). No module is over 500 lines (`Ladder` 400, `InstallFlow` 261).

Decisions that the slice does not fix:

| Topic | Decision | Rejected |
| --- | --- | --- |
| `upgrade` with a patched entry that also has a `=` range | The note is `<alias>: patched, held` (the patch is named first) | `anchor, held` |
| A patched entry with a `Fixed` host in `update` | The note is the note of the fixed host, not `patched, held` | both notes |
| URL of an entry after the command | The `Pick.Chosen` value of its variable when its `change` is `Move`, else the URL of the header entry (`Keep`) | the `chosen.url` always (a `Keep` variable whose members have different versions would look like a move) |
| `Patched.need` `install` flag | `request.command == Install and request.names.is_empty()` (`tln add` has names, so it does not rebase: Q6) | a field in `Request` |
| `delete!` of step 3 | The paths of `Remove` and of `FromCopy` (`copy_tree!` put the file of the new release there, and `copy_file!` does not overwrite). `calls.log` of `pa2-resolve` has this | `Remove` only |
| Two patches with the same alias in 2 members | The temp dir of the second one is `<alias>-<n>` (D6 gives one dir for each alias; the same alias twice would collide) | an error |
| A failure after the temp root exists (`build!`) | `build_all!` deletes the root before it returns the failure | only `clean!` (it does not run for a failed `run!`) |
| `Rebased` record | Not changed. The new URL for the candidate probes comes from the `Found` record inside `run!` (`Rebased` has no URL) | a `url` field |

Revert check (`research/slice-043-revert/agent-mutate.py`, results in `agent-results.md`): caught 16 of 16 runs (15 mutations, A6 run in 2 layers). Filtered runs only (one `roc test` driver, `scripts/test.sh l2` or `l3`).

| Id | Mutation | Caught by |
| --- | --- | --- |
| A1 | `update` with no names frees a patched entry | `l0-2` (`VarsTest`) |
| A2 | a held patched entry is movable | `l0-2` |
| A3 | `tln install` does not rebase a stale patch (`Patched.need`) | `l0-1` (`PatchedTest`) |
| A4 | a diff that does not apply is no failure | `l0-1` |
| A5 | `install --frozen` has no stale check | l2 `pa2-resolve` |
| A6, A6b | the proxy does not stop on a stale patch | l2 `px3-patch`, l3 `px3-proxy-patch` |
| A7 | `TALON_PROXY=0` checks a stale patch | l2 `px3-patch` |
| A8 | the baseline check gets the pairs of the candidate | `l0-1` |
| A9 | the proxy flags go after `--` | `l0-1` |
| A10 | the Guard of the base write has no span of the `[patch]` entry | l2 `pa2-resolve` (run 11) |
| A11 | `--dry-run` replaces the copy | l2 `pa2-resolve` (run 6) |
| A12 | the diff is made against the new release, not the base | l2 `pa2-resolve` |
| A13 | `base` is not set to the new hash | l2 `pa2-resolve` |
| A14 | the candidate probes get the copy, not the temp tree | l2 `pa2-resolve` |
| A15 | the temp root is not deleted | l2 `pa2-resolve` |

The code after the runs is the same as `research/slice-043-revert/code-final/` (`sha256sum -c research/slice-043-revert/code-final.sha256` from the repo root: 14 files OK).

Open points for the manager: Q1 (early rank of the proxy has no patch flags), Q2 (base not in cache: Environment failure `cannot read <dir>`, as coded) and Q3 are as the review set them. No new question.

## Gap tests (test agent, 2026-10-24)

The code is not changed (`sha256sum -c research/slice-043-revert/code-final.sha256`: OK after each mutation). No code bug was found. Old expected files: the 12 runs of `pa2-resolve` did not change (the copy was kept and diffed: only the new run and the `projects.json` and index lines of `tree.diff` changed).

| Gap | Row | Mutation (hand, then restored) | Result |
| --- | --- | --- | --- |
| `upgrade` of a patched entry with a `=` range: the note is `patched, held` | `VarsTest.roc` expect `patched`, new row 1 | the note says `anchor` when the range is `=` | the row fails, the others pass |
| `update` of a patched entry with a fixed host: the note is the fixed-host note, no `patched, held`, not free | same expect, new row 2 | `held_patch` does not need `indexed` | the row fails, the others pass |
| `tln add` does not rebase a stale patch (Q6) | L2 `pa2-resolve` run 13 (`add acme/util --no-check`, p10 has a stale patch): the output has the new entry only, no `rebased:`, the copy and `base` stay | `Patched.need` `install` is true for `add` (the `names.is_empty()` test removed in `PatchApply.run!`) | run 13 fails (`rebased:` line) |
| A failure in the build step deletes the temp root | L2 `patch/pa3-buildfail` (new case, 1 run: the home has `talon/tmp/patch-0123456789abcdef/json/left.txt`, so `copy_tree` of the build gives `Exists`): exit 18 (`cannot copy ... to <root>/json`), `calls.log` has `delete <root>`, no probe, no write of the header, the copy or `talon.toml` | `build_all!` does not delete the root | the case fails (the `delete` line is missing) |

Not added: two members with the same alias (no cheap row: it needs a workspace case). The fake gives the same name to each temp root, so the deleted root of `pa3-buildfail` is shown by the `delete` call only (`tree.diff` does not list a deleted file of `given`). `pa3-buildfail` has its own case because the temp root of the home is shared by all runs of a case.

## Close (manager, 2026-10-24)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-043-revert/code-final.sha256` | OK, 14 lines |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.2, fmt 0.2, l0 7.0, l2 6.9, l3 9.9, selftest 3.1, l1 41.5 s |
| Gap tests | 4 rows, 4 hand mutations, all caught; no code bug |
