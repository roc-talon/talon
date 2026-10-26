# 063 The `talon` entry after a repair: `tln setup` makes it match the running `tln`

Phase: P1. Status: done

Slice 063 changes one decision of `tln setup` (CLI 6.5: R-IS6, R-S4; gap 052 G1, answer 3 of `PLAN-P1.md` 2c). Before: setup writes the `talon` entry of `tools.json` only when it is missing. After `install.sh --version <v>` (the repair, R-S4) the entry names the old version, so `tln tool update talon` reads the wrong version. Now: setup compares the entry with the running `tln` and writes it again when they differ.

Size (TW19): one pass for the code agent. The private reference (`research/slice-063-revert/reference/`) changes 1 function in `TalonUpdate` (6 lines, 1 new helper of 5 lines) and 1 function in `SetupFlow` (10 lines, 1 new helper of 4 lines). Nothing else changes in `cli/`. No module is over 490 lines (`SetupFlow` 411).

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-IS6 | `tln setup` makes the `talon` entry match the running `tln`. It matches when the version and the sha256 are those of the running binary. A missing or differing entry is written again as a prebuilt entry (version, release URL of that version, sha256 of the file in the data bin dir, target, install time). A matching entry is not changed. Another tool entry is not changed. | L0 `TalonUpdateTest` 13. L2 `setup/st1-flow` run 1 (differs), `st2-copy-fallback` and `st3-gaps` (match), `st5-talon-entry` (missing, unchanged) |
| R-S4 | The repair is `install.sh --version <v>`, and it runs `tln setup`: a repair to an older release, and to a newer one, makes the entry match | L0 `TalonUpdateTest` 13 (the entry is newer than the running `tln`, and older). L2 `setup/st1-flow` run 1 (entry 0.3.1, running 0.0.0) |
| R-S6 (read side) | The version of an entry is the `version` of a prebuilt entry, or the version of the tag ref of a git entry | L0 `TalonUpdateTest` 13 (git rows) |
| R-CC6, R-CC1 (as 052) | The entry is decided again under the lock of `tools.json`, one atomic write | L2 `setup/st1-flow` run 1 (the same calls as `st5`) |

Rule check: `MISSING=1 scripts/rules.sh R-IS R-S` lists only R-S7 (the release workflow, not part of this slice).

## 2. Public signatures

No change. The stubs of slice 052 stay: `TalonUpdate.setup_entry : { have : Try(ToolsJson.Talon, [None]), version : Str, os : Setup.Os, target : Str, sha256 : Str, now : U64 } -> [Keep, Put(ToolsJson.Talon)]`.

| Function | New contract (the body is the work of the code agent) |
| --- | --- |
| `TalonUpdate.setup_entry` | `Keep` only when `have` is `Ok(entry)` with the installed version equal to `version` and `entry.sha256` equal to `sha256` (text, exact). The installed version of a git entry is the version of its tag ref (`v0.3.4` is `0.3.4`). Every other field is not compared. Else `Put` the prebuilt entry as in 052 (also when the entry is newer than the running `tln`, and when it is a git entry). |
| `SetupFlow` step 10a | Decide on the facts of step 3 with `setup_entry` first (the clock is not needed to decide): `Keep` gives no call and no line. `Put`: `Clock.now!`, the lock, `read_files!` again, `setup_entry` again on that text, one `write_atomic!`, the line. The line is `TalonUpdate.recorded_text` for a rewrite too (proposal, section 4). |

The doc comments of `setup_entry` and of `SetupFlow` step 10a still say "an entry that is there stays" (052, question Q-R1): the code agent changes them.

## 3. Tests

| Layer | File and case | Checks | Rules | Today |
| --- | --- | --- | --- | --- |
| L0 | `tests/unit/TalonUpdateTest.roc` expect 13 (changed, 11 new rows): `Keep` for an entry with the version and the sha256 of the running `tln` (a prebuilt one, one with another URL, target, `hashes` and time, a git one with the tag ref). `Put` for: the sha256 differs only, the version differs only (lower, and higher: the repair goes back), a git entry with another sha256, a git entry with another tag. The 2 old rows (`old`, `src`) were `Keep` and are `Put` | R-IS6, R-S4, R-S6 | red: `setup_entry` keeps any entry |
| L2 | `setup/st1-flow` (changed, TW21): the given entry says 0.3.1 with another sha256, the running `tln` says 0.0.0. Run 1 writes it in place (`foo`, `bar`, `baz` stay): `clock`, `lock`, `read_files`, `write_atomic`, `unlock`, the first line `recorded talon 0.0.0 in <tools.json>`. Runs 2 to 13 find a matching entry: no call for it | R-IS6, R-S4, R-CC6 | red: no line, no calls, no change of `tools.json` |
| L2 | `setup/st2-copy-fallback`, `setup/st3-gaps` (given changed): the entry has version 0.0.0 and the sha256 of the file `tln` of the case. Setup keeps it. The expected files did not change | R-IS6 | green before and after |

Changed old tests (TW21): `tests/unit/TalonUpdateTest.roc`; in `setup/st1-flow`: `fx/commands` (comment), `expect/calls.log` (5 lines), `expect/stdout` (1 line), `expect/tree.diff` (1 hunk of `tools.json`); in `st2-copy-fallback` and `st3-gaps`: `given/home/.local/share/talon/tools.json` and the comment of `fx/commands`. Copies of the old files are in `research/slice-063-revert/before/`.

`install/test.sh` is not changed: its `tln` is a shell script that records its arguments, so it cannot show the entry. The rows `repair`, `--version` and `latest release` already check that the script runs `tln setup` after the install (R-S4, R-IS6). The L3 case `setup/st1-setup-real` is not changed: its step 3 (setup again with the real file) already needs a matching entry for `cmp` to pass.

Fail output (2026-10-25, red state):

| Test | Fail text |
| --- | --- |
| L0 `TalonUpdateTest` 13 | `[dbg]` lists 8 rows: `("Keep", "Put({ hashes: [], installed_at: \"2026-10-22T12:00:00Z\", ... sha256: \"S0\", source: Prebuilt({ ... version: \"0.3.4\" }) ... })")`. 87 of 88 pass |
| L2 `setup/st1-flow` | stdout: the line `recorded talon 0.0.0 in $HOME/.local/share/talon/tools.json` is missing. Calls: `clock`, `lock`, `read_files`, `write_atomic`, `unlock` are missing. Tree: `tools.json` still has the entry 0.3.1 |

`tests/commands/run.sh setup/`: 6 pass, 1 fails (`st1-flow`). Old tests: the other L0 and L2 setup cases pass. A full `scripts/test.sh` was not run (the run of slice 064 was in progress).

Revert check (private reference `research/slice-063-revert/reference/`: `tree/` is a copy of `cli/`, `packages/`, `scripts/` and the setup tests with the reference code, `mut.py` runs the mutations; the reference passes L0 driver 1 and the 7 setup cases):

| Mutation | Caught by |
| --- | --- |
| M1: compare the version only | L0 13 (`mirror`/sha rows) |
| M2: compare the sha256 only | L0 13 (version rows, the repair rows) |
| M3: the version of a git entry is the whole ref text (`v0.3.4`) | L0 13 (git rows) |
| M4: the clock is read for a matching entry | L2 `st1-flow`, `st2-copy-fallback`, `st3-gaps`, `st5-talon-entry` |

## 4. Output (proposed, TW24)

| Output | Text |
| --- | --- |
| A rewrite of a differing entry | The same line as for a missing entry: `recorded talon <version> in <path of tools.json>`, first line on stdout (stderr with `--json`). `--json` `data` has no new field |

## 5. Decisions that the design does not fix (the test agent chose)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The rewrite prints the same line as a first write | A second text (`updated talon 0.3.1 to 0.0.0`): more output with no rule |
| D2 | The sha256 compare is exact text (the sha256 of an entry is written by Talon in lower case hex) | A case-folded compare |
| D3 | A matching git entry (tag ref equal to the version, same sha256) stays as it is (a `--from-source` build that runs) | A rewrite as prebuilt (it would drop the commit that `tool update talon --from-source` needs) |
| D4 | The decision is made on the facts of step 3 first, so a matching entry costs no `clock` and no lock (the calls of the old cases stay) | A lock for each setup |

## 6. Out of scope and questions

| Item | Reason |
| --- | --- |
| A differing entry on a machine with no release target (`BuildSkip.target` unknown) | R-IS6 says "no entry and no error" for that machine, and does not say whether a differing entry stays. No test. Q-1 (TW17), manager answer (2026-10-25): keep the differing entry, there is nothing to write |
| A git entry whose ref is not a tag (Talon does not write one) | R-S6 gives no version for it. No test. Q-2 (TW17), manager answer (2026-10-25): the version is empty, so the entry is written again |
| The `.del` rename or any change of the data bin file | Not part of setup |

## 7. Manager review (2026-10-25)

D1 to D4 and the 2-field compare (version and sha256) are accepted. Q-1: keep the differing entry when there is no release target. Q-2: rewrite (empty version). The private reference was deleted at this review; `before/` stays.

## 8. Verify results (code agent, 2026-10-25)

| Item | Result |
| --- | --- |
| Code | `TalonUpdate.setup_entry` (new helper `matches_running`), `SetupFlow.record_talon!` (new helper `decide_talon`), doc comments of both changed. `TalonUpdate` 369 lines, `SetupFlow` 420 lines |
| `roc test tests/unit/l0-1.roc` | 88 of 88 pass (expect 13 green) |
| `tests/commands/run.sh setup/` | 7 of 7 pass (`st1-flow` green) |
| `scripts/test.sh` | check, fmt, l0, selftest, l1 pass. l2 and l3 fail only in cases of slice 064 (roc/, consent/, tool/, upgrade/, probe/, init/, proxy/, compilers/, exit/ex3): the fetch flows of the other agent, in progress. No `setup/` case fails |
| M1: compare the version only (drop the sha256) | caught: L0 13 |
| M2: compare the sha256 only (drop the version) | caught: L0 13 |
| M3: `Clock.now!` for a matching entry | caught: 4 of 7 `setup/` cases (`clock` line in `calls.log`) |
| Code after the mutations | same as before (`cmp`) |

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-063-revert/code-final.sha256` | 3 files OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, with 062 and 063 both in) | Exit 0, all 7 steps |
| Gap step | Skipped: 3 of 3 (4 with the test agent's) mutations caught, no new decision |
