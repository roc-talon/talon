# 078 `tools.json` records the bin dir entries

Phase: P1. Status: done

Slice 078 is the plan row 078 of `PLAN-P1.md` (section 2c). Source: the design decision C2 (U1 (a)) of `DESIGN-GAPS-2026-10-26.md`, and the text of R-T4, R-ST9, R-ST11 and R-TF2 after it. `tools.json` gets the optional field `bin`: the sha256 of each bin dir entry that Talon made. An entry with a recorded sha256 is Talon's also when it is stale, and `tln setup` repairs it. `format` stays 1. The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files, the stubs and the private reference are in `research/slice-078-revert/`.

## 1. Rules

| Id | Text (short) | Where |
| --- | --- | --- |
| R-T4 (CLI 6.4) | `tools.json` records for each tool the sha256 of each bin dir entry that Talon made (`bin`, a new field: `format` does not change). | `BinRecord`, the 4 writers (section 4) |
| R-ST11 (CLI 6.7) | An entry is Talon's when its sha256 is the one of its file in the data bin dir (1) or the one that `bin.<name>` records (2). Talon writes `bin.<name>` each time it makes an entry. A name has no `.exe`. The `talon` entry has `tln` and `roc`. An entry with no record: only (1) counts. An entry with neither: foreign, R-ST2 and R-ST6 keep it. | `BinRecord`, `Setup.judge_bin`, `ToolInstall.verdict_bin`, `ToolManage.fate_bin` |
| R-ST9 | `tln setup` repairs a stale entry (an entry that a stopped step left on the old file). It is Talon's by R-ST11 (2), so setup replaces it with no prompt. | `SetupFlow` |
| R-ST6 | Talon never overwrites or deletes a file that it did not write. | L2 `st9`, `st10` |
| R-TF2 | A new field does not change `format`. A field that Talon does not know stays, in its place. | `BinRecord.set` |
| R-S6, R-S3, R-B4, R-ST7, R-CC6 | The writers: `tool update talon` (prebuilt and `--from-source`), the install of a tool, the take-over of an `x` entry, `tln setup`. Each record is written under the lock of `tools.json`. | section 4 |

## 2. What the code does today

| Part | Today |
| --- | --- |
| `Setup.judge` | An entry is Talon's only when its sha256 is the one of its source: a stale entry is `Foreign` (kept with a warning). |
| `ToolInstall.verdict`, `ToolManage.entry_fate` | The same test with `old`, the sha256 of the data file. |
| Writers | No `bin` record. |

## 3. Public signatures (the code agent keeps them)

New module `cli/lib/BinRecord.roc` (listed in `cli/lib/main.roc`). It is a new module because `ToolsJson.roc` has 460 lines. The stubs are `crash "todo: slice 078"`.

| Function | Signature | Result |
| --- | --- | --- |
| `BinRecord.read` | `{ path : Str, text : Try(Str, [NotFound]) } -> Try(List((Str, Str)), Fail)` | The pairs (name, sha256) of the field `bin` of all entries, in the order of the text. A missing file, no `tools` field, an entry with no `bin`, a `bin` that is no object and a value that is no text: no pair (a bad record is no record). A bad text and a newer `format`: the failures of `ToolsJson.read` (kind `Input`, exit 19). |
| `BinRecord.set` | `{ path : Str, text : Try(Str, [NotFound]), key : Str, bin : List((Str, Str)) } -> Try(Str, Fail)` | The text after the names of `bin` are set in the entry `key`: a name that is there gets the new sha256 in its place, a new name is the last of `bin`, `bin` is a new last field. Everything else stays in its place (R-TF2). A missing file: the empty text (as `ToolsJson.drop`). Nothing to change (an empty list, a key that is not in `tools`, no `tools` field, the same sha256): the text byte for byte, so the flow writes no file. |
| `BinRecord.record_all` | `{ path : Str, text : Try(Str, [NotFound]), made : List({ entry : Str, sha256 : Str }) } -> Try(Str, Fail)` | `set` for the entries that setup made: `tln` and `roc` are in the entry `talon`, any other name in the entry of its key; one `.exe` is cut from the name (Windows); the pairs of one entry are set together in the order of `made`; an entry that is not in `tools` is left out. |
| `Setup.judge_bin` | `{ source : [Missing, Sha(Str)], recorded : Try(Str, [None]), have : [Absent, Dir, Unreadable, Sha(Str)] } -> [NoSource, Make, Keep, Repair, Foreign]` | `Repair`: the sha256 of `have` is the recorded one and not the one of the source. See the table in the doc comment of `cli/lib/Setup.roc`. |
| `ToolInstall.verdict_bin` | `{ old : Try(Str, [NotFound]), recorded : Try(Str, [None]), have : [Absent, Dir, Unreadable, Sha(Str)] } -> [Make, Foreign]` | `Make` for `Absent`, and for `Sha(h)` when `old` or `recorded` is `Ok(h)` (also when the data file is gone). |
| `ToolManage.fate_bin` | `{ old : Try(Str, [NotFound]), recorded : Try(Str, [None]), have : [Absent, Dir, Unreadable, Sha(Str)] } -> [Remove, Gone, Keep]` | `Remove` for `Sha(h)` when `old` or `recorded` is `Ok(h)`. |

`Setup.judge`, `ToolInstall.verdict` and `ToolManage.entry_fate` keep their signatures and their results (their old rows are not changed). They are the case `recorded: Err(None)`, so the code agent can write each as a call of the new function.

## 4. Flow (the code agent writes it)

The flows write the record. The calls that change are in the L2 expected files. The decision of the pre-download check (question Q1) is not in this table.

| Place | Change | New Fx calls |
| --- | --- | --- |
| `SetupFlow.gather!` (steps 3 and 5) | `BinRecord.read` on the text of step 3. `Setup.judge_bin` with `recorded` of the entry (the name without `.exe`). The row verdict has `Repair`. | none |
| `SetupFlow.write_entries!` (step 10) | `Repair` rows are made again, like `Make` rows (`random`, `hard_link` else `copy_file`, `rename`), with no prompt, also `roc` (no R-NI13 for a Talon `roc`). An entry that is repaired is reported as made (D6). | none |
| `SetupFlow` step 10b (new) | After the last entry and after the move of `roc` (step 10): when at least one entry was made, `Fx.locked!` on `tools.json` (`Wait`, R-CC3): `read_files!`, `BinRecord.record_all` (`made`: the name of each made entry and the sha256 of its source file: the `roc` entry has the sha256 of `tln`), one `write_atomic!` only when the text changes, unlock. A missing file gives no write. | `lock`, `read_files`, `write_atomic` (when changed), `unlock` |
| `ToolBuild.install!` (tool install, update, rebuild, `--git`, `--from-source`, project tool take-over by build) | After `ToolsJson.put`, `BinRecord.set` with the key of the tool and `[(<file without .exe>, sha)]`: the `talon` source build has the key `talon` and the file `tln`. The same single write of `tools.json`. | none |
| `XTake.taken!` (R-B4) | The same, with the sha256 of the manifest. | none |
| `TalonUpdateFlow.installed!` (prebuilt) | After `ToolsJson.put_talon`, `BinRecord.set` with the key `talon` and the entries made (`tln`, `roc`: the names of `made.make` without `.exe`), sha256 of the new file. The same single write. A foreign `roc` that is kept (`ts4`) is not recorded. | none |
| `TalonUpdateFlow.built_from_source!` | `tln` is recorded by `ToolBuild.install!`. The `roc` entry is made after it, outside that lock: one more locked step with `BinRecord.set` on `talon` (`roc`, sha256 of the file `tln`): `lock`, `read_files`, `write_atomic` (when changed), `unlock`, after the `rename` of the `roc` entry and before the delete of the scratch dir (D5). | the 4 calls |

## 5. Tests

| Layer | File and case | Content | Rule ids |
| --- | --- | --- | --- |
| L0 | `BinrecordTest` expect 1 (line 37), 14 rows | `BinRecord.read`: no file, no `tools`, no tool, a tool with no `bin`, an empty entry, one tool, a tool and `talon` in the order of the text, `bin` not the last field, a `bin` that is a number, a text or a list, a value that is a number or null, an unknown field, and the 3 failures (no JSON, newer `format`, `tools` not an object) | R-T4 R-ST11 R-TF2 R-TF3 |
| L0 | `BinrecordTest` expect 2 (line 63), 14 rows and 5 byte-for-byte rows | `BinRecord.set`: a new `bin` is the last field, an empty entry, a name in place, the other names stay, a name in place and a new name last, 2 new names in order, only the entry of the key changes (the other entry, a top-level field and an unknown field stay), the unknown field stays before the new `bin`, `bin` in the middle stays in its place, a value that is no text, a `bin` that is no object (replaced by an object, Q2), no file, no JSON, newer `format`. Byte for byte: the same sha256, 2 names the same, an empty list, a key that is not there, no `tools` | R-T4 R-ST9 R-ST11 R-TF2 |
| L0 | `BinrecordTest` expect 3 (line 106), 9 rows and 3 byte-for-byte rows | `BinRecord.record_all`: `tln` and `roc` in `talon`, Windows names, a tool, a tool on Windows, an empty entry, tln plus a tool plus an entry that is not in `tools`, one name of `talon` (the other stays), no file, no JSON. Byte for byte: no entry made, the same sha256, an entry that is not in `tools` | R-ST9 R-ST11 R-S6 |
| L0 | `BinrecordTest` expect 4 (line 138), 13 rows | `Setup.judge_bin`: the table of the doc comment, with `Repair` for the recorded sha256, `Foreign` for no record, another record, `Dir` and `Unreadable` | R-ST11 R-ST9 R-ST6 R-ST7 |
| L0 | `BinrecordTest` expect 5 (line 162), 13 rows | `ToolInstall.verdict_bin`: a stale recorded entry is `Make`, also when the data file is gone; no record, another record, `Dir`, `Unreadable`: `Foreign` | R-ST11 R-ST9 R-ST6 R-T4 |
| L0 | `BinrecordTest` expect 6 (line 185), 11 rows | `ToolManage.fate_bin`: a stale recorded entry is `Remove`; no record, another record, `Dir`, `Unreadable`: `Keep` | R-ST11 R-RM6 R-RM11 R-ST6 |
| L2 | `setup/st9-stale-recorded` (new), 2 runs | Run 1: `tln`, `roc` and `foo` are stale (the old file, v1) and recorded: setup makes them again, no prompt, also `roc` (3 `random`, `hard_link`, `rename`), then one locked write of `tools.json` gives each made entry the sha256 of the data file (the old record is replaced; `qux` keeps its old record). `baz` (no record, other content), `qux` (a record, but the entry is another file) and `bar` (no record, and the content of the record of `foo`: a record is for one name) stay with a warning. Run 2 (`--json`): `kept` for the 3, `skipped` for the 3 foreign, no lock, no write. | R-ST9 R-ST11 R-T4 R-ST6 R-CC6 R-CC1 R-ST7 R-ST12 |
| L2 | `setup/st10-no-record` (new), 2 runs | `tools.json` has no `bin` (an older Talon): `tln`, `roc` and `foo` are old files with no record, so they are foreign: 2 warnings and the note for `roc` (no prompt in CI, the default of R-NI13 is No). Nothing is made, no lock, no write, the tree has no change. Run 2 is the same. This case passes with the old code too (it is a guard for the sentence "an entry with no record: only (1) counts"). | R-ST11 R-ST6 R-NI13 R-T4 |
| L2 | 25 changed cases (section 6) | The writers record `bin`: the tree of `tools.json` has `bin` for each entry that the run made (tool install, update, rebuild, take-over, `tool update talon`, setup). 8 `calls.log` files have the new calls of steps 10b and the `roc` record of the source build. | R-T4 R-ST11 R-ST9 R-S3 R-B4 |
| L3 | `setup/st1-setup-real` (changed `cmd` and `stdout`) | The real `tln setup`: `tools.json` has `bin` for `talon` (`tln`, `roc`: the sha256 of the file `tln`) and for `foo` (the sha256 of the file `foo`). The case checks the values against `sha256sum` of the files. The record of a file that the user replaced (step 7) does not make it Talon's: `foo` is kept. | R-T4 R-ST11 R-ST6 |
| L3 | 5 changed scenarios (`tools/ti1`, `ti3`, `tx1`, `ts1-update-talon`, and the trees of `ti2`, `ptools/pt2-x`) | The real `tln` writes `bin` in `tools.json` (the printed file and the tree diff). | R-T4 R-ST11 |

L0 count: 6 new `expect`s (74 rows, in the new module `BinrecordTest`, driver `l0-6`). Deep cases: 2 new L2 cases (4 runs), 25 changed L2 cases, 7 changed L3 scenarios.

## 6. Changes of old tests (TW21)

The copies are in `research/slice-078-revert/before/`. I made the new trees from the work dirs of the last run of the old code, with `research/slice-078-revert/regen.py`: the script adds `bin` to each entry that the run made, and writes the tree diff again. For each case it first checks that the old work dir gives the old expected file. After the change, the private reference (section 12) gives all these files with no difference: they are the output of the reference and I read the diffs.

| Group | Files | Change |
| --- | --- | --- |
| L2 `expect/tree.diff` (25) | `setup/st1-flow`, `st2-copy-fallback`, `st3-gaps`, `st5-talon-entry`, `st6-talon-in-file`, `st8-first-default`; `tool/dl3-rename-edges`, `dx1-xtake-windows`, `dx2-source-windows`, `tg1-git`, `ti1-install`, `ti2-refusals`, `ti3-compiler`, `tk1-takeover`, `tk2-takeover-project`, `tr1-rebuild`, `ts1-update`, `ts2-stops`, `ts4-rocforeign`, `ts5-windows`, `ts5b-winfresh`, `ts6-source`, `ts8-attest`, `tu1-update`, `tu2-updatestops` | `"bin":{...}` is the last field of each entry that the run made: a tool `{"<key>":"<sha256>"}` (the sha256 is the one of its `sha256` field), `talon`: `{"tln":"<sha256>","roc":"<sha256>"}` (`ts4`: `tln` only, `roc` is foreign). A new `tools.json` hunk in `st2`, `st3` (the file is the same but for `bin`). The Windows names have no `.exe`. |
| L2 `expect/calls.log` (8) | `setup/st1-flow` (2 runs), `st2-copy-fallback`, `st3-gaps`, `st5-talon-entry`, `st6-talon-in-file`, `st8-first-default` (4 runs: `HOME`, `HOME2`, `HOME3`, `HOME4`); `tool/ts6-source`, `dx2-source-windows` (2 runs) | Step 10b: `lock`, `read_files`, `write_atomic`, `unlock` of `tools.json` after the last entry of the run. The source build: the same 4 lines after the `rename` of the `roc` entry. |
| L3 `expect/tree.diff` (5) | `tools/ti1-tool-install`, `ti2-tool-compiler`, `ts1-update-talon`, `tx1-x-run`, `ptools/pt2-x` | `bin` in the new `tools.json` (the order of `ts1`: `tln`, `roc`). |
| L3 `expect/stdout` (4) | `tools/ti1`, `ti3`, `tx1`, `ts1-update-talon` | The lines that print `tools.json` (`cat`) have `bin` for each tool that Talon made. |
| L3 `setup/st1-setup-real` | `cmd`, `expect/stdout` | `shown()` masks the sha256 of `tln`, `roc` and `foo` in `bin`. 2 new check lines (`bin of talon ...`, `bin of foo ...`). The line of `tools.json` has `bin`. |
| Not changed | The old rows of `SetupTest` (`Setup.judge`), `ToolTest` (`verdict`), `ToolManageTest` (`entry_fate`); `tool ls --json` (D8); the cases that make no entry | |

## 7. Output (proposed, TW24)

| Item | Proposal | Rejected |
| --- | --- | --- |
| A repaired entry in the human text | The same line as a made entry: `made <bin>/<name> (hard link)` (or `(copy)`). | A new word (`repaired`): the type `SetupText.Act` has no such tag, and a new tag would change each `match` on it. |
| A repaired entry in `--json` | `entries[].action` is `made` (no new value). | `repaired`: it is a new value of an enum (R-J6 does not forbid it, but each reader would change). |
| `tln tool ls --json` | No `bin` in `data.tools[]`. The record is for Talon, not for the user. | Add `bin`: a new `data` field that the design does not give (R-OUT3). |
| New messages | None. | |

## 8. Out of scope

| Part | Reason |
| --- | --- |
| The use of the record by the tool path: the check before the download and under the lock (R-S3, R-T28 foreign `tln`, `tool install`, `update`, `rebuild`, the take-over), and the removal (R-RM6, R-RM11 (3), `tool remove`, `tool remove talon`) | Slice 078b (review of Q1, option b). The pure decisions `ToolInstall.verdict_bin` and `ToolManage.fate_bin` are tested here, and not used by a flow in this slice. |
| `tln setup` on Windows (`.exe` names in `BinRecord.record_all` have an L0 row) | The Windows CI job (TESTING.md section 5). |
| `BinRecord.set` on an entry that is no object | No design text (no test). A `bin` that is no object has an L0 row (Q2). |
| A new `tln` release for old `tools.json` files | `format` stays 1 (R-TF2): an older Talon ignores `bin` and keeps it (R-TF2: no test of an old Talon). |

## 9. Decisions of the test agent that the design does not fix (for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `bin.<name>` is the sha256 of the data file at the time of the write: for a tool it is the value of its `sha256` field. For `talon`, `tln` and `roc` have the sha256 of the file `tln`. | A sha256 of the entry that is read again after the link (one more `sha256_file` call in each flow, and the same value). |
| D2 | A bad record is no record: `BinRecord.read` skips a `bin` that is no object and a value that is no text. The entry is then foreign (R-ST6 keeps it, the safe side). It is no exit 19. | Exit 19 for a bad `bin` (a bad field of a file that an older or a newer Talon may write would stop `tln setup`, R-IS7). |
| D3 | `bin` is the last field of a new entry (R-TF2: an unknown field stays in its place, so `put` of a replaced tool keeps the old `bin` and `BinRecord.set` replaces the sha256 in place). | The place after `libs` (the order of the table of `ToolsJson` would change for each old file). |
| D4 | The record is written after the entry is made (a stop between the 2 steps leaves an entry that equals the data file, R-ST11 (1)), and it replaces the old sha256 of the name. | Before the entry (a stop would remove the record of the old file, and the stale entry would be foreign). |
| D5 | Setup writes the record in one more locked step after all its entries (step 10b), and the source build of `tln` writes the `roc` record in one more locked step. Both are 4 new calls. | Move the `roc` link of the source build into the lock of `ToolBuild.install!` (the order of the calls of `ts6` and `dx2` would change, and `ToolBuild.install!` would need the layout of `roc`). A write of the record before the entries in setup (D4). |
| D6 | A repaired entry is reported as made (section 7). | A new `Act`. |
| D7 | Setup records only an entry that exists in `tools.json` (`record_all` leaves the others out). With no `talon` entry (no release target, R-IS2) nothing is recorded for `tln` and `roc`, and the entries are Talon's by R-ST11 (1) only. | Make the entry `talon` for the record (R-IS6 says setup writes it only for a machine that has a release target). |
| D8 | `Setup.judge`, `ToolInstall.verdict` and `ToolManage.entry_fate` stay (the record-less case), so the old rows and all old callers compile. The code agent may delete them when no caller is left, but must then keep the old rows true (the rows call the new functions: TW18 forbids to edit tests, so the old functions stay until the manager says). | New arguments on the old functions (each old test and flow would not compile with the stubs). |

## 10. Questions (stop until answered)

| Id | Question | Options | Recommended |
| --- | --- | --- | --- |
| Q1 (answered, see section 11) | Where do the flows use the record? The check of the entry before the download (R-S3: "A foreign `tln` ... stops the update with exit code 2 before the download"; `tool install`, `update`, `rebuild`, the take-over) has no text of `tools.json` in hand. The removal (`tool remove`, `tool remove talon`) has it. Without a read before the download, a stale recorded entry would stop the command before the lock, where `ToolInstall.verdict_bin` would accept it. | (a) Read `tools.json` before the download in each tool flow (the calls.log of about 40 L2 cases get one `read_files`). (b) Read it only when the entry is not Talon's by R-ST11 (1) (the first check as today): 5 L2 cases that stop with a foreign entry (`ti2-refusals`, `tg2-gitstops`, `tr2-rebuildstops`, `ts3b-foreign`, `ts4-rocforeign`) get one `read_files`. (c) Both in a follow-up slice 078b (tests: one L2 row for a stale recorded entry in `tool update` and in `tool remove`). | (b), in slice 078b, with the removal (no new call there). Slice 078 stays small: the record, setup and the writers. |
| Q2 (answered, see section 11) | `BinRecord.set` on an entry whose `bin` is no object (for example `"bin":5`), or on a key whose entry is no object. The design says nothing (R-TF2 keeps unknown fields). The reference replaced the bad `bin` by an object, and leaves an entry that is no object as it is. No test. | (a) As the reference. (b) Exit 19 (kind `Input`). | (a): the record is Talon's own field, and a repair must not stop an install. |

## 11. Review (manager, 2026-10-26)

| Item | Answer |
| --- | --- |
| Q1 | (b) in a follow-up slice 078b: the tool flows and the remove path read `tools.json` only when the entry is not Talon's by the data-file sha. Slice 078 keeps `ToolInstall.verdict_bin` and `ToolManage.fate_bin` as L0-only: no flow uses them in this slice. |
| Q2 | `BinRecord.set` replaces a `bin` that is no object by an object (`tools.json` is Talon's file; the same fail-safe as "a bad record is no record"). One L0 row is added to `BinrecordTest` expect 2 ("a bin that is no object is replaced by an object"). The reference passes it. |
| D1 to D8 | Accepted, with "a repaired entry is reported as made", no `bin` in `tool ls --json`, the module `BinRecord`, and the extra locked write steps. |

## 11a. Disputes (from the code agent)

None.

## 12. Red output

With the stubs in the tree (the private reference away), after slice 077 (its stubs are in the tree too: the 87 L2 failures include the 72 of slice 077).

| Step | Result |
| --- | --- |
| check, fmt | pass. `roc fmt --check` of the changed `.roc` files: exit 0. The stubs compile. |
| l0 | FAIL: the 6 `expect`s of `BinrecordTest` (`todo: slice 078`). The 7 of slice 077 are red too. All other `expect`s pass. |
| l2 | FAIL. 26 cases of this slice: the 25 changed ones (`tree.diff` and `calls.log` differ) and `setup/st9-stale-recorded` (the old code makes only the stale entries it takes for `Foreign`, and writes no record). `setup/st10-no-record` passes with the old code (a guard). |
| l3 | FAIL: `setup/st1-setup-real`, `tools/ti1`, `ti2`, `ti3`, `tx1`, `ts1-update-talon`, `ptools/pt2-x` (no `bin` in `tools.json`). |
| selftest, l1 | pass |

With the private reference in the tree (slice 077 and 078 bodies), `scripts/test.sh check fmt l0 l2 l3 selftest` passes: l0 pass, l2 183 of 183, l3 pass.

## 13. Revert check (TW12)

12 changes of the private reference, one at a time (`research/slice-078-revert/mutate.py`), steps check, l0, l2, l3. All 12 are caught. The reference and the script are deleted after the review (section 14).

| Id | Change | Caught by |
| --- | --- | --- |
| m1 | `judge_bin` gives `Foreign` for a recorded stale entry (the record is ignored) | L0 `BinrecordTest` expect 4. L2 `st9` |
| m2 | `judge_bin` gives `Repair` for any other file (no record check) | L0. L2 `st10`, `st1`, `st2`, `st3`, `st9`. L3 `st1-setup-real` |
| m3 | `SetupFlow` passes no record to `judge_bin` | L2 `st9` only (L0 passes: wiring) |
| m4 | `SetupFlow` has no step 10b | L2 `st1`, `st2`, `st3`, `st5`, `st6`, `st8`, `st9`. L3 `st1-setup-real` |
| m5 | `BinRecord.set` puts a new name before the old ones | L0 expect 2. L2 `st1`, `ts6`, `dx2` |
| m6 | `BinRecord.set` replaces the whole `bin` (the other names go) | L0. L2 `st1`, `ts6`, `dx2` |
| m7 | `record_all` does not cut `.exe` | L0 expect 3 (L2 has no Windows setup) |
| m8 | `ToolBuild.install!` records the name `talon` and not `tln` for the source build | L2 `ts6`, `dx2` (L0 passes: wiring) |
| m9 | The `roc` record of the source build is not written | L2 `ts6`, `dx2` |
| m10 | `verdict_bin` ignores the record | L0 expect 5 |
| m11 | `fate_bin` ignores the record | L0 expect 6 |
| m12 | `read` takes a number as a record | L0 expect 1 |

## 14. Next step

The review is applied (section 11). The code agent writes the bodies of section 3 and the flows of section 4 (status `code`). The private reference and the mutation script are deleted (the manager's order of 2026-10-26); `before/`, `stubs/` and the helper scripts `regen.py`, `analyze.py` stay.

## 15. Verify results

Code agent, 2026-10-26: `scripts/test.sh` passes (check, fmt, l0, l2, l3, selftest, l1). New code: `BinRecord` (read, set, record_all), `Setup.judge_bin`, `ToolInstall.verdict_bin`, `ToolManage.fate_bin`. Flows: `SetupFlow` (`Repair` verdict, step 10b `record_bin!`), `ToolBuild.install!`, `XTake.taken!`, `TalonUpdateFlow.installed!` and `record_roc!` (source build). The old `judge`, `verdict` and `entry_fate` stay (D8). Revert check: 9 mutations, all caught, the code is the same after them (compared with `cmp`).

| Mutation | Test that failed |
| --- | --- |
| `set` puts a new name before the old ones | L0 `BinrecordTest` |
| `judge_bin` ignores the record | L0 |
| `record_all` does not cut `.exe` | L0 |
| `SetupFlow` has no step 10b | L2 `setup/st9`, `setup/st1-flow` |
| `SetupFlow` passes no record to `judge_bin` | L2 `setup/st9` |
| The `roc` record of the source build is not written | L2 `tool/ts6` |
| `ToolBuild.install!` records the key and not the file name (`talon`, not `tln`) | L2 `tool/ts6` |
| `XTake` writes no record | L2 `tool/tk1` |
| `TalonUpdateFlow.installed!` records only the first made entry | L2 `tool/ts1` |

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK (tree and `code-final/`) |
| `grep -rn 'crash "todo' cli packages` | none |
| `scripts/test.sh` (manager) | rc=0: check, fmt, l0, l2, l3, selftest, l1 pass |
| Disputes, questions | none |
| Gap step | skipped: every mutation was caught, no new decision |
