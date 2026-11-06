# 088f Windows test worlds and Q216 rows

Phase: P1. Status: done (closed by the manager, 2026-11-02).

Source: slice 088e section 10 (the dispute), CLI R-LY10 and R-PX6, Design Q214 and Q216. 088e made a Windows root variable that is not absolute count as not set. The Windows L2 cases had `HOME`, `LOCALAPPDATA` and `APPDATA` as `{w}/home/...`: no drive, so not absolute, so exit 18 (`LOCALAPPDATA is not set`). Q216 rejects the option "accept `/x` on Windows".

## 1. Scope

| Part | Content |
| --- | --- |
| A. The test worlds | 15 L2 cases with a Windows run use values that are absolute on Windows and real paths on the Linux and macOS host |
| B. The Q216 rows | 9 L0 rows in `LaunchTest` and 7 in `RootsTest` for the details that Q216 decided |

## 2. The chosen form

| Option | Result |
| --- | --- |
| (a) Drive form through a dir `C:` | Works with one change of the runner. The fake host passes the path text to the file system as it is, and the process of the app does not run in the case dir, so a relative `C:/x` was the file `<cwd>/C:/x`. `tests/commands/run.sh` now (1) makes the link `<W>/C:` -> `home` for a case whose `fx/` has the text `C:/`, and (2) runs the app in `<W>` for that case. Then `C:/AppData/Local` is the dir `home/AppData/Local`, so the given files and the tree diff (`home`) do not change |
| (b) UNC `//{w}/...` | Not chosen. The code of 088e does not take `//` as UNC yet (a row below), and the path of a missing dir is cleaned to `\\tmp\talon-l2\...`: a work dir path in `calls.log`, not portable (macOS has another work dir) |
| (c) Mapping in the fake Fx | Not needed. It would change about 25 `Path.utf8` calls of `FakeFiles` and `FakeJobs`, which all cases use |

Why (a): the log has the short portable text (`C:/AppData/Local\talon/tools.json`, no work dir), a `u<n>` home is `C:/u1/AppData/Local`, no `given/` file moves, and the change is one place in `run.sh`. The `C:` link and the `cd` happen only for a case with `C:/` in `fx/`, so other cases have the same process as before.

Forms in the cases:

| Case kind | Env |
| --- | --- |
| All runs Windows (`tool/dl1b-denied`, `dl1-sweep`, `dl2-tool-windows`, `dl3-rename-edges`, `dx1-xtake-windows`, `ts5b-winfresh`, `ts5-windows`) | `fx/env`: `HOME=C:/`, `LOCALAPPDATA=C:/AppData/Local`, `APPDATA=C:/AppData/Roaming`. `USERPROFILE` stays `{w}/home/u` (the bin dir of R-LY8 is no root variable) |
| One home for each run (`tool/dx2-source-windows`, `rm3-windows`, `rm5-win-path`, `rm6-tools-windows`) | the `env:` words of each `fx/commands` line: `env:HOME=C:/u1 env:LOCALAPPDATA=C:/u1/AppData/Local env:APPDATA=C:/u1/AppData/Roaming` |
| Mixed (`ptool/pt4-bin-file` run 2, `roc/ri1-flow` run 4, `zig/zi1-install` run 3, `zig/zs1-search` run 7) | `LOCALAPPDATA` and `APPDATA` left `fx/env`; the 2 `env:` words are on the Windows run only. The Linux runs keep `HOME={w}/home` |

## 3. What changed in the expected files

`UPDATE=1` on the 15 cases, then each file was compared with the old one after the map `C:/` -> `$HOME/`. The only differences: the path text (`C:/...` for `$HOME/AppData/...`), the `env:` words in the `== ` lines of `stdout`, and the lines of the slice 214 hook (`env_all`, `tty`). `pt4-bin-file` stdout also shows the new `data.tools` fields of slice 092 and 093 (`bin`, `binary`, `bin_skip`, `would_check`), because the binary has them. No expect file was dropped (the runner removes an empty file: none was). The rules file of each case has a paragraph "Slice 088f".

## 4. Red rows (L0)

| File | Rows | State |
| --- | --- | --- |
| `tests/unit/LaunchTest.roc`, last `expect` (driver `l0-1`) | 10: a bare UNC root `\\srv\sh` gives `\\srv\sh\`; with a `\` at the end; UNC root with `..`; `//srv/sh` is UNC; `//srv/sh/a`; a leading `..` stays on Windows (`..\a`, `../a` gives `..\a`, `a\..\..\b` gives `..\b`) and on Linux (`../a`, `a/../../b` gives `../b`) | red: 9 of 10 rows (`//srv/sh/a` passes) |
| `tests/unit/RootsTest.roc`, new `expect` before the layout `expect` (driver `l0-8`) | 7, as (cache, config, data, build): a relative `ROC_CACHE_DIR` is not set (`x\b`, `/x/b`, `C:b`); `D:\b` is kept; `//srv/sh` is UNC; `C:\` is absolute (the check is before the `\` is dropped); a bare UNC root with a `\` at the end is absolute | red: 4 rows (the 3 relative `ROC_CACHE_DIR` rows and `//srv/sh`) |

Red output: l0-1 107 passed, 1 failed; l0-8 124 passed, 1 failed. The `C:\` row and the bare UNC value row pass: they guard the new code.

## 5. Out of scope

| Item | Reason |
| --- | --- |
| L3, and a `//` world at L2 | Windows CI runs `check fmt l0` only. No L2 case uses `//` |
| Linux `ROC_CACHE_DIR` | no change |

## 6. Questions

None.

## 7. Revert check

A private reference of `Roots.roc` (`windows_absolute` also takes `//`, and `ROC_CACHE_DIR` uses `root_of`) passed all 125 rows of l0-8. It is deleted. There is no private reference of `Launch.clean_text`: the Launch rows come from Q216. 3 hand mutations of the reference, all killed: (1) the absolute check after the `\` is dropped: the `C:\` row; (2) `//` is not UNC: the `//srv/sh` row; (3) `ROC_CACHE_DIR` not checked: the 3 relative rows. The old files are in `research/slice-088f-revert/before/` (`NEW.txt` lists the new file).

## 8. For the code agent

1. `Launch.clean_text`: a bare UNC root ends with `\`; `//srv/sh` is UNC; a leading `..` of a relative path stays (Windows `..\a`, other systems `../a`).
2. `Roots.windows_absolute`: a value that starts with `//` is absolute. `windows_roots`: `ROC_CACHE_DIR` uses `root_of` (a relative value is not set). Update the doc comments (Q3 of 088e).
3. Do not edit the tests or `run.sh`. Run `l0-1`, `l0-8` and the whole L2.

## 9. Results

L2: the 15 cases pass with the 088e code (the whole set: 239 passed and 18 failed: 16 `ptool/*`, `gc/gc6-prebuilt-entries` and `upgrade/ur5-optional` fail for slices 092 and 093, not for this slice).

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| l0-1, l0-8 | 108 and 125 pass (code agent) |
| The 15 Windows L2 cases, run by name (manager) | 15 of 15 pass. Note: `scripts/test.sh l2` skips the tag `windows`, so a whole-step run does not show them. |
| Full L2 (code agent) | 240 pass. The 17 failures are `gc/gc6` and 16 `ptool/*` of slices 092 and 093 (in work). L3 passes. |
| Revert check | Test step: 3 mutations caught. |
