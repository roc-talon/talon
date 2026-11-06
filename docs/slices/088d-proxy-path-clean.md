# 088d Proxy path cleanup

Phase: P1. Status: done (closed by the manager, 2026-11-02).

Source: slice 088c "Out of scope" (`Launch.clean` with `Text.resolve("/", path)` is wrong for a Windows `\` path). The design answer is G-C31, Design Q212 and CLI R-PX6 (manager, 2026-11-02).

## 1. Scope

| Case of the cache path (`XDG_CACHE_HOME`, `ROC_CACHE_DIR`) | Right behavior (R-PX6, Q212) |
| --- | --- |
| The dir exists (`canonical!` gave `Ok`) | The canonical path of the system. No change |
| The dir does not exist | Text only, no file system call: the separator of the system (on Windows each `/` becomes `\`), each `.` part removed, each `..` part removes the part before it, no symlink resolved. Reason: with `..` in `XDG_CACHE_HOME`, roc prints "No errors found" for any app (Q15) |

Today the second case is `Text.resolve("/", path)`: it knows `/` only, so a Windows path keeps `/` and `\` mixed, and a `\..` part stays.

## 2. Rule ids

R-PX6, R-LY5, R-LY10 (the roots are absolute, so no current dir is joined).

## 3. Signatures

| Item | Choice |
| --- | --- |
| New pure function | `Launch.clean_text : { windows : Bool, path : Str } -> Str`. A stub: `crash "todo: slice 088d"`. Public, so L0 can test it |
| `Launch.child_env` | The facts get a new field `windows : Bool`. The private `clean` takes it (`clean : Bool, {path, canonical} -> Str`) |
| `Launch.child_env!` | Passes `windows: fx.windows!()`. Done in the stub (a plain wire, it does not change a result while `clean` is old) |
| `clean` (private) | Stub state: the `Err(Failed)` branch is still `Text.resolve("/", path)`, and its `windows` is not used. The code agent changes it to `Launch.clean_text({ windows, path })` |
| `Text.resolve` | No change (other callers) |

## 4. The text cleanup (what the rows fix)

| Step | Rule |
| --- | --- |
| Separator | Windows: `/` becomes `\`, and the split is at `\`. Other: the split is at `/` only (a `\` is a letter of a name) |
| Root | Linux `/`. Windows with a drive (`C:` as first part, 2 bytes, ends with `:`): `C:\`. Windows with no drive: `\` (the fake host has paths like `/w/home`) |
| Parts | `.` and the empty part are removed. `..` removes the part before it |
| Join | The root, then the parts with the separator |

The rows fix the result for a drive, `.`, `..`, mixed separators, a clean path, a path with no drive, and a `\` in a Linux name. The rows do not fix the 3 points of section 8.

## 5. Tests

| Layer | File and case | What | Rules | State |
| --- | --- | --- | --- | --- |
| L0 | `tests/unit/LaunchTest.roc`, last `expect` (driver `l0-1.roc`) | `Launch.clean_text`, 11 rows: Linux (`.` and `..`, a clean path, `..` back to `/`, a `\` in a name), Windows (drive and `..`, drive and `.`, a clean path, mixed separators, `/` only, lower case drive, no drive) | R-PX6, R-LY5 | red: `todo: slice 088d` |
| L0 | `tests/unit/LaunchTest.roc`, first `expect`, `env_rows` | 2 new rows of `Launch.child_env` with `windows: True`: a missing dir (`C:/Users/u/./x/../AppData/Local` gives `C:\Users\u\AppData\Local`, and the build path `C:/Users/u/AppData/Local\roc`), and a dir that exists (the canonical text stays). The helper `canon` has the new field `windows: False` | R-PX6 | red: the first row gives the `/C:/...` form (wrong value) |

Red output (before the code): 104 of 106 pass. The 2 fails: the new `expect` (`todo: slice 088d`) and the first `expect` (row "Windows, a dir that does not exist", got `XDG_CACHE_HOME=/C:/Users/u/AppData/Local`).

## 6. Why L0 is enough, and the 4 L2 cases that changed

| Point | Fact |
| --- | --- |
| The L2 fake host is Linux. Its paths are `<w>/home/...`. A Windows missing dir would show as `\tmp\talon-l2\<case>\home\...` in `calls.log` | The `normalize` of `tests/lib.sh` replaces `<w>` with `$HOME` only when it sees `/`. After the cleanup the text has `\`, so the expected file would hold the real work dir, and it would fail on macOS (another work dir). `tests/lib.sh` is not for this slice |
| So no L2 case can show the new rule in a portable way | The rule is a pure function of the text: L0 checks all of it |
| 4 existing Windows cases do reach the new branch: the parent of the cache root (`AppData/Local`) was not in the case, so `canonical!` gave `NotFound`. With the new code the line `env XDG_CACHE_HOME=...` would hold the real work dir | Changed: `ptool/pt4-bin-file`, `tool/dl2-tool-windows`, `tool/dl3-rename-edges`, `tool/dx2-source-windows` (`u1` and `u2`) get an empty file `given/home/AppData/Local/.keep` (in `home/u1`, `home/u2` for `dx2`). The dir exists, as `%LOCALAPPDATA%` does on a real host, so `canonical!` gives `Ok` and the expected files do not change |

Check with the private reference: the 4 cases show no diff of `XDG_CACHE_HOME` with the old code and with the new code. (The whole L2 run had other diffs, `tty` and `env_all` lines of slice 214 and `bin` fields of slice 092 and 093: not this slice.)

## 7. Revert check

The private reference (the right `clean_text` and the `clean` wire) is deleted. 4 hand mutations of the reference, all killed by L0 `l0-1` (each gave 104 of 106, and 105 of 106 for the third):

| Mutation | Killed by |
| --- | --- |
| 1. No drive detection (`C:` is a part, so the root is `\`) | the Windows drive rows |
| 2. The `/` to `\` change on Linux too | the Linux `\` row |
| 3. `clean` always passes `windows: False` | the first Windows `env_rows` row |
| 4. `..` removes nothing | the `..` rows of both systems |

The old files are in `research/slice-088d-revert/before/` (`NEW.txt` lists the new files).

## 8. Questions (TW17)

The design does not say these. The rows do not test them, and the code agent must not choose.

| Id | Question | Options |
| --- | --- | --- |
| Q1 | A `..` above the root (`/..`, `\..`, `C:\..`): what is the result? Q212 says "each `..` part removes the part before it", and the root has no part before it | (a) the root stays and the `..` is dropped (as the OS does, and as `Text.resolve` does today). (b) an error. (c) the `..` stays |
| Q2 | An empty part (`a//b`, a double `\`) and the trailing separator: Q212 does not name them. `Text.resolve` removes them, and the old L0 row (`/h/./b//c/../d` gives `/h/b/d`) needs it for Linux | (a) removed (the stub doc and section 4 say this as a proposal). (b) kept |
| Q3 | A UNC path (`\\server\share\x`), a drive with no separator (`C:x`) and a relative path (R-LY10 says the roots are absolute): what is the result? And the form of a drive root after the last `..`: `C:\` or `C:` | The stub treats the first empty part as the root `\`, so a UNC path loses a `\`. The manager decides |

## 9. Out of scope

| Item | Why |
| --- | --- |
| A portable L2 case with a missing Windows dir | Section 6 |
| `Text.resolve` | Other callers, unchanged |
| macOS | Same code as Linux (`windows: False`) |

## 10. For the code agent

1. `Launch.clean_text`: the body, by section 4. Do not edit the tests.
2. Private `clean`: `Err(Failed) => Launch.clean_text({ windows, path: dir.path })`, and the name `windows` in place of `_windows`. Update the doc comment of `child_env` (it says `Text.resolve`).
3. Run L0 (`l0-1`), then the 4 changed L2 cases, then the whole L2.

## 11. Code agent notes (2026-11-02)

| Item | Note |
| --- | --- |
| Done | `Launch.clean_text` has a body (section 4). The private `clean` calls it with `windows` for `Err(Failed)`. The doc of `child_env` names `Launch.clean_text`. |
| Choices for Q1 to Q3 | None made by design. What the code does by its shape, only for the manager to see: Q1 `..` above the root drops the `..` (the root stays); Q2 empty parts are removed; Q3 a UNC path loses a `\` (first empty part is the root), a relative path gets the root `/` or `\` as a prefix, a drive root is `C:\` after the last `..`. These are not tested. |
| Results | `roc test tests/unit/l0-1.roc`: 106 of 106 pass. `roc check cli/main.roc`: no errors. `roc fmt --check`: valid. |
| 4 L2 windows cases | Run with `tests/commands/run.sh` (the cases have the tag windows, so `scripts/test.sh l2` skips them). The `env XDG_CACHE_HOME` lines and `canonical` lines have no diff. The other diffs: `+tty`, `+env_all` (slice 214); the JSON line of `pt4-bin-file` (the `bin`, `binary`, `bin_skip`, `would_check` fields, 092 and 093). |
| `scripts/test.sh l2` | 182 passed, 73 failed. The diffs are `tty` and `env_all` lines (214). |
| `scripts/test.sh l3` | 89 passed, 1 failed (`tools/ti1-tool-install`, a tool flow case, and a `waiting for another tln: tools.json` line: 092 and 093). 3 skipped. |
| Revert check | Not repeated: the test agent did 4 mutations (section 7). |
| Final copy | `research/slice-088d-revert/code-final/` and `code-final.sha256` (`cli/lib/Launch.roc`). |

## Disputes (from the code agent)

None.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| l0-1 | 106 of 106 |
| 4 Windows L2 cases | No diff on the `XDG_CACHE_HOME` and `canonical` lines. Other diffs are red tests of slices 214, 092 and 093 (in work). |
| L3 `tools/ti1-tool-install` | Failed once in the code agent's full run (`waiting for another tln: tools.json`). It passes alone (manager re-run). The cause is test runs of several agents at the same time. |
| Follow-up | 088e: Q214 (G-C34) gives the UNC root, "a `..` never removes a root part", and the R-LY10 absolute check on Windows. |
