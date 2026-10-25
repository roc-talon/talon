# 048 Tool list, update, rebuild, remove, and the git source

Phase: P1. Status: done

Slice 048 adds the other commands of `tln tool` and the git source of a tool (CLI 6.4: R-T7, R-T23 to R-T25, R-B6). Slice 046 made `tool install` for a release and slice 047 made the compiler choice. Now `tool list` (`ls`), `tool remove` (`rm`), `tool rebuild`, `tool update` and `tool install --git` work. `tool ... talon` is for slices 050 and 051 (the commands say `is not built yet`).

Size (TW19): the plan row says 350 lines. The private reference has 1394 lines in 6 new modules (`ToolGit` 251, `ToolGitFlow` 197, `ToolManage` 222, `ToolManageFlow` 216, `ToolUpdate` 186, `ToolUpdateFlow` 322), and 149 more lines in `ToolsJson.roc`, 5 in `ToolBuild.roc`, 23 in `ToolFlow.roc` and 10 in `Run.roc`. About 40 percent of the lines are doc comments (tables of the calls and of the rules). This is clearly over 500 lines of code, so the slice file proposes a split (section 12). The tests are written per part, so a split is cheap.

Live reads: none. No real network and no real long build in L0 to L3. The L3 case uses a fake compiler (a shell script), the real `curl`, the real `tar` and the real `roc unbundle`.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-T7 | `tool rebuild` builds again from the manifest, with the same build id (the source of `tools.json` and the compiler of `tools.json`). The bin dir entry is made again (R-ST9) | L0 `ToolSourceTest` origin (the source of a release tool and of a git tool, the failures of kind input), `ToolManageTest` read. L2 `tr1-rebuild` runs 1, 3, 4, 5, `tr2-rebuildstops` runs 1 to 6. L3 `ti3-tool-git` step 6 |
| R-T23 | `tool install --git owner/app@ref [--path dir]`: the commit of the ref, the source archive (R-R3, R-R7), `main.roc` in the app dir, then the build as for a release. `tools.json` has the commit and the ref that the user typed | L0 `ToolSourceTest` read, key, reuse, layout, needs_curl, no_main, not_app, data. L2 `tg1-git` runs 1 to 7, `tg2-gitstops` runs 1 to 9. L3 `ti3-tool-git` steps 1, 3, 7 |
| R-T24 | `tool update app`: a branch builds the new head. A commit: no change, `pinned to commit dd03c09e`. A release: the newest release, as `tool install app@latest` (R-B2) | L0 `ToolSourceTest` way and moved, the texts of the lines, data. L2 `tu1-update` runs 1 to 6. L3 `ti3-tool-git` steps 4, 5, 7 |
| R-T25 | `tool update` with no name updates each tool with the rule of its source. One prompt covers the downloads of all tools (R-DL1) | L0 `ToolSourceTest` downloads, want, prompt. L2 `tu1-update` runs 1 to 3 (one prompt for 2 compilers). L3 `ti3-tool-git` step 4 |
| R-B6 | `tool rm` deletes the binary. Nothing goes back to the `x` cache | L0 `ToolManageTest` entry_fate, remove texts, drop. L2 `tm1-manage` runs 7 to 9. L3 `ti3-tool-git` steps 7, 8 |

Other rules that the tests name (the behavior is used here, the rule is owned by an older slice): R-CM16, R-CM19, R-FL12 (the flags of `tool rm talon` and `tool update talon`), R-SC3, R-AD6 (the lookup of an installed tool), R-SL8, R-SL10, R-SL11, R-SL13 (a git ref, a sha selector), R-T2, R-T4, R-T5, R-T8, R-T26, R-T27, R-T28 (reuse, replace, binary name), R-ST6, R-ST11 (a bin dir entry that Talon did not write), R-ST9, R-CC1, R-CC2, R-CC6 (temp dirs, the lock of `tools.json`), R-DA3, R-SE12 (curl, no redirect to http), R-DL1 to R-DL5, R-NM5, R-NM9 (one consent for the command), R-HF1 (one `tty!`), R-J1 to R-J4, R-OUT2, R-OUT4, R-PT12 (`tool rm` reads no project data: `calls.log` of `tm1-manage` shows it).

## 2. Files

New files (also in `research/slice-048-revert/before/NEW.txt`). The code agent writes the bodies of the stubs.

| File | Lines (stub, reference) | Content |
| --- | --- | --- |
| `cli/lib/ToolGit.roc` (stub) | 94, 251 | Part A, pure: the line of `tool install` as a git source, the key, reuse, the paths, the failures, `data` |
| `cli/lib/ToolGitFlow.roc` (stub) | 41, 197 | Part C: `run!` (`tool install`), and `head!`, `check_curl!`, `source!` that `ToolUpdateFlow` also uses. The calls: the table in its doc comment |
| `cli/lib/ToolManage.roc` (stub) | 88, 222 | Part A, pure: the line of `list`, `remove`, `update`, `rebuild`, the table, the fate of the bin dir entry, the reports, `data` |
| `cli/lib/ToolManageFlow.roc` (stub) | 42, 216 | Part C: `list!`, `remove!`, and `machine!`, `facts_of`, `find!` for `ToolUpdateFlow`. The calls: the table in its doc comment |
| `cli/lib/ToolUpdate.roc` (stub) | 106, 186 | Part A, pure: the way of a tool, the lines, the origin of a rebuild, the downloads, the consent, the prompt |
| `cli/lib/ToolUpdateFlow.roc` (stub) | 24, 322 | Part C: `update!`, `rebuild!`. The calls: the table in its doc comment |
| `tests/unit/ToolManageTest.roc` | 257 | 10 `expect`s (L0) |
| `tests/unit/ToolSourceTest.roc` | 330 | 12 `expect`s (L0) |
| `tests/commands/cases/tool/tm1-manage/` | 18 files | L2: 11 runs |
| `tests/commands/cases/tool/tg1-git/` | 23 files | L2: 7 runs |
| `tests/commands/cases/tool/tg2-gitstops/` | 23 files | L2: 9 runs |
| `tests/commands/cases/tool/tr1-rebuild/` | 23 files | L2: 5 runs |
| `tests/commands/cases/tool/tr2-rebuildstops/` | 20 files | L2: 6 runs |
| `tests/commands/cases/tool/tu1-update/` | 36 files | L2: 8 runs |
| `tests/scenarios/tools/ti3-tool-git/` | `cmd` 62, 18 files | L3: 8 steps |
| `tests/tools/mk-tool-git.sh` | 33 | Makes the commit routes and the real source archives (`tar.gz`) of a tool app for the L3 case |
| `research/slice-048-revert/` | | The stubs (`stubs/lib/`), `restore.sh`, `mkstubs.py`, `gen-manage.py` (writes only the 6 new L2 cases), `mutants.py`, `mutants.log`, `red-all.log`, `before/`, `expect-before/` |

Changed files (a copy of each is in `research/slice-048-revert/before/`):

| File | Change |
| --- | --- |
| `cli/lib/main.roc` | exposes the 6 new modules |
| `cli/lib/Run.roc` | dispatches `tool list`, `tool remove`, `tool update` and `tool rebuild` to the new flows. `tool install` stays `ToolFlow.run!` in the stub state: the code agent changes it to `ToolGitFlow.run!` (section 10) |
| `cli/lib/ToolsJson.roc` | 4 stubs added: type `Tool`, `manifest`, `put`, `drop` (section 3). `read`, `add`, `clash`, `entities` stay as they are |
| `cli/lib/ToolBuild.roc`, `cli/lib/ToolFlow.roc` | not changed in the stub state. The code agent changes them (section 10) |
| `tests/unit/l0-3.roc` | `import ToolManageTest` (the driver with the lowest time in `.work/l0-times`) |
| `tests/unit/l0-4.roc` | `import ToolSourceTest` (the driver with the next lowest time) |

Old expected files: no old `expect/` file changed. `research/slice-048-revert/expect-before/` has the copy of all old `expect/` files (594 files). `diff -rq` against `tests/commands/cases` after the generator run shows only the new case dirs. `ToolInstall.read` keeps its refusals (`--git`, `--path`, `--resolve`, a sha selector), so the rows of `ToolTest` stay as they are: `ToolGit.read` runs first and gives `NotGit` for every other line.

Module plan (TW19, the manager may change it): `ToolFlow.roc` is 296 lines now and 319 in the reference, `ToolBuild.roc` is 217 and 222, `ToolsJson.roc` is 203 and 352, `ToolUpdateFlow.roc` is 322. All stay under 490.

## 3. Public signatures

The doc comment of each stub has the rule, the table of cases and the texts. Only the signatures are here.

`ToolsJson` (new items):

```roc
Tool : { key : Str, name : Str, source : Source, path : Try(Str, [None]), hashes : List(Str), nightly : Str, target : Str, sha256 : Str, libs : List(Str), installed_at : Str }
manifest : { path : Str, text : Try(Str, [NotFound]) } -> Try(List(Tool), Fail)
put : { path : Str, text : Try(Str, [NotFound]), tool : Tool } -> Try(Str, Fail)
drop : { path : Str, text : Try(Str, [NotFound]), key : Str } -> Try(Str, Fail)
```

`ToolGit`:

```roc
Plan : { ref : Ref, source : GitRef.Source, path : Try(Str, [None]), as_name : Try(Str, [Unset]), roc : [Auto, Pinned, Installed] }
read : Args -> Try(Try(Plan, [NotGit]), Fail)
key : { plan : Plan, installed : Try(Str, [None]) } -> Str
reuse : { installed : Try(ToolsJson.Entry, [None]), sha : Str } -> [Keep(Str), Build]
source_text : { ref : Str, sha : Str } -> Str
layout : { roots : Roots, hex : Str, path : Try(Str, [None]) } -> { temp : Str, archive : Str, src : Str, dir : Str, file : Str }
needs_curl : {} -> Fail
no_main : { source : GitRef.Source, path : Try(Str, [None]) } -> Fail
not_app : GitRef.Source -> Fail
data : { how : ToolInstall.How, key : Str, name : Str, ref : Str, commit : Str, path : Try(Str, [None]), bin : Str, built : Try({ nightly : Str, target : Str, sha256 : Str, entry : [HardLink, Copy] }, [None]) } -> JsonDoc
```

`ToolManage`:

```roc
Cmd : { verb : [Ls, Update, Rebuild, Remove], ref : Try(Ref, [None]) }
read : Args -> Try(Cmd, Fail)
pick : { tools : List(ToolsJson.Tool), found : Lookup } -> Try(ToolsJson.Tool, Fail)
source_text : ToolsJson.Tool -> Str
ls_report : List(ToolsJson.Tool) -> { stdout : List(Str), stderr : List(Str) }
ls_data : List(ToolsJson.Tool) -> JsonDoc
entry_fate : { old : Try(Str, [NotFound]), have : [Absent, Dir, Unreadable, Sha(Str)] } -> [Remove, Gone, Keep]
kept_warning : Str -> Str
remove_report : ToolsJson.Tool -> Str
remove_data : { tool : ToolsJson.Tool, removed : List(Str), kept : List(Str) } -> JsonDoc
```

`ToolUpdate`:

```roc
Outcome : { tool : Str, name : Str, how : [Updated, UpToDate, Pinned, Rebuilt], from : Try(Str, [None]), to : Str }
way : ToolsJson.Tool -> [Release, Branch, Commit]
moved : { tool : ToolsJson.Tool, sha : Str } -> [Same, Moved]
pinned_text : { key : Str, commit : Str } -> Str
up_to_date_text : ToolsJson.Tool -> Str
updated_text : { tool : ToolsJson.Tool, new : Str } -> Str
rebuilt_text : { tool : ToolsJson.Tool } -> Str
data : List(Outcome) -> JsonDoc
origin : ToolsJson.Tool -> Try([Bundle({ url : Str, hash : Str }), Archive({ owner : Str, repo : Str, commit : Str, path : Try(Str, [None]) })], Fail)
downloads : { pins : List(Str), installed : List(Str) } -> List(Str)
want : { ids : List(Str), auto : [Ask, Yes, No], yes : Bool, mode : Mode } -> [Download, Ask, NeedTty, Stop(Fail)]
refused : Str -> Fail
foreign_failure : Str -> Fail
consent_stop : List(Str) -> Fail
prompt : { ids : List(Str), size : U64 } -> Prompt
declined : List(Str) -> Fail
```

The flows:

```roc
ToolGitFlow.run! : Fx, Args => I32
ToolGitFlow.head! : Fx, Net.Settings, GitRef.Source, U64 => Try(Str, Fail)
ToolGitFlow.check_curl! : Fx, Net.Settings => Try({}, Fail)
ToolGitFlow.source! : Fx, ToolBuild.Facts, { source : GitRef.Source, sha : Str, path : Try(Str, [None]) } => Try({ bundle : ToolBuild.Bundle, temp : Str }, Fail)
ToolManageFlow.list! : Fx, Args => I32
ToolManageFlow.remove! : Fx, Args => I32
ToolManageFlow.machine! : Fx => Try({ facts : ToolBuild.Facts, tools : List(ToolsJson.Tool) }, Fail)
ToolManageFlow.facts_of : ToolBuild.Facts, ToolsJson.Tool -> ToolBuild.Facts
ToolManageFlow.find! : Fx, { ref : Ref, tools : List(ToolsJson.Tool) } => Try(ToolsJson.Tool, Fail)
ToolUpdateFlow.update! : Fx, Args => I32
ToolUpdateFlow.rebuild! : Fx, Args => I32
```

Public signatures that the code agent adds to existing modules (not in the stub state, section 10):

```roc
ToolBuild.Bundle : { version : Str, url : Str, hash : Str, dir : Str, source : ToolsJson.Source, path : Try(Str, [None]), pin : Try(Str, [NoPin]), pf : Try(Str, [None]), hashes : List(Str) }
ToolBuild.probe_timeout : ConfigToml.Config -> U64
ToolFlow.gather_for! : Fx, ToolInstall.Plan => Try(ToolBuild.Facts, Fail)
ToolFlow.release_list_for! : Fx, Args, ToolBuild.Facts => Try(List(Index.Candidate), Fail)
ToolFlow.notes_for! : Fx, ToolBuild.Facts, ToolInstall.Picked, Index.Candidate => {}
ToolFlow.first_app_for! : Fx, Args, ToolBuild.Facts, List(Index.Candidate) => Try(ToolBuild.Bundle, Fail)
ToolFlow.platform_for! : Fx, Args, ToolBuild.Facts, ToolBuild.Bundle => Try({}, Fail)
ToolFlow.compile_for! : Fx, Args, ToolInstall.Plan, ToolBuild.Facts, ToolBuild.Bundle => Try(ToolBuild.Done, Fail)
ToolFlow.bundle_for! : Fx, Args, ToolBuild.Facts, { version : Str, url : Str, hash : Str } => Try(Try(ToolBuild.Bundle, [NotApp]), Fail)
ToolFlow.package_text_for! : Fx, Args, ToolBuild.Facts, { url : Str, hash : Str } => Try(Str, Fail)
```

## 4. Tests

| Layer | File | Case | Rule ids |
| --- | --- | --- | --- |
| L0 | `ToolManageTest` 1 | `read`: `ls`/`list`, `rm`/`remove`, operand counts, a version, `talon`, `--dry-run`, `--remove-tools`, `--keep-all`, `--from-source` (23 rows) | R-CM16, R-CM19, R-FL12, R-T7, R-T25, R-B6, R-SC3 |
| L0 | `ToolManageTest` 2 | `pick`: an installed tool, a full name that no tool has | R-SC3, R-T7 |
| L0 | `ToolManageTest` 3 | `source_text` of a release, a git tool | R-T4, R-T10, R-T23, R-T27 |
| L0 | `ToolManageTest` 4 | `ls_report`: the table (widths, the column LIBS, `--path`, empty) | R-T4, R-T5, R-T8, R-OUT2 |
| L0 | `ToolManageTest` 5 | `ls_data` | R-J3, R-J4, R-OUT4 |
| L0 | `ToolManageTest` 6 | `entry_fate` (7 rows) | R-B6, R-ST6, R-ST11 |
| L0 | `ToolManageTest` 7 | the report, the warning and `remove_data` | R-B6, R-ST6, R-OUT2, R-J3, R-J4, R-OUT4 |
| L0 | `ToolManageTest` 8 | `ToolsJson.manifest` (all fields, a git `path`, the failures) | R-T4, R-T7, R-T5, R-LY2, R-TF1, R-TF3 |
| L0 | `ToolManageTest` 9 | `ToolsJson.put` (a new tool, replace in place, a git tool, unknown fields) | R-T4, R-T23, R-T26, R-T27, R-TF2, R-CC6 |
| L0 | `ToolManageTest` 10 | `ToolsJson.drop` (9 rows) | R-B6, R-TF2, R-TF3, R-CC6 |
| L0 | `ToolSourceTest` 1 | `ToolGit.read` (29 rows: `--git`, a sha selector, `--path`, `NotGit`, the failures) | R-T23, R-SL8, R-SL10, R-SL11, R-SL13, R-FL12, R-FL14, R-SE12, R-T28, R-T6 |
| L0 | `ToolSourceTest` 2 | `ToolGit.key` | R-T28, R-T26, R-T27, R-ST15 |
| L0 | `ToolSourceTest` 3 | `ToolGit.reuse`, `source_text` | R-T26, R-T27, R-B10, R-T4 |
| L0 | `ToolSourceTest` 4 | `ToolGit.layout` | R-T23, R-CC1, R-CC2, R-R3, R-R7, R-SE12 |
| L0 | `ToolSourceTest` 5 | `needs_curl`, `no_main`, `not_app` | R-DA3, R-SE12, R-T23, R-T10 |
| L0 | `ToolSourceTest` 6 | `ToolGit.data` | R-J3, R-J4, R-OUT4 |
| L0 | `ToolSourceTest` 7 | `ToolUpdate.way`, `moved` | R-T24, R-SL10, R-B2 |
| L0 | `ToolSourceTest` 8 | the lines of update and rebuild, `ToolUpdate.data` | R-T24, R-T7, R-T5, R-OUT2, R-J3, R-J4, R-OUT4 |
| L0 | `ToolSourceTest` 9 | `ToolUpdate.origin` | R-T7, R-T5, R-T23, R-SE12 |
| L0 | `ToolSourceTest` 10 | `ToolUpdate.downloads` | R-T25, R-DL1, R-DL2, R-T5 |
| L0 | `ToolSourceTest` 11 | `ToolUpdate.want` (12 rows) | R-T25, R-DL1 to R-DL5, R-NM5, R-NM9, R-HF1 |
| L0 | `ToolSourceTest` 12 | `ToolUpdate.prompt`, `declined`, `foreign_failure` | R-ST6, R-ST11, R-T25, R-DL1, R-NR2, R-NR6, R-NM5, R-NM6 |
| L2 | `tool/tm1-manage` | 11 runs: `ls`, `ls --json`, 4 refusals, `rm` of a Talon entry, a foreign entry, a missing entry, the empty list, a tool that is gone | R-T4, R-T5, R-T8, R-B6, R-ST6, R-ST11, R-CC6, R-PT12, R-SC3, R-FL12 |
| L2 | `tool/tg1-git` | 7 runs: `--git` replaces a release tool, `Present`, a sha selector with `--path`, a new ref with `--json`, `--as` clash, a package, no `main.roc` in the path | R-T23, R-T26, R-T27, R-T28, R-SL10, R-SE12, R-CC2, R-CC6 |
| L2 | `tool/tg2-gitstops` | 9 runs: no `main.roc` at the top, 422, `--offline`, wget, no ref, bad `--path`, a name clash, a foreign entry, `--resolve` | R-T23, R-DI12, R-DA3, R-SE12, R-ST6, R-T28 |
| L2 | `tool/tr1-rebuild` | 5 runs: the recorded compiler (not the header pin), no consent (exit 13), `--yes` downloads again, all tools with `--json`, a build with errors | R-T7, R-T5, R-T25, R-DL1, R-DL4, R-CC2 |
| L2 | `tool/tr2-rebuildstops` | 6 runs: a foreign entry, a bad URL, a bad git name, all tools with one stop (nothing built), an unknown tool, `talon` | R-T7, R-ST6, R-ST11, R-TF1, R-SC3 |
| L2 | `tool/tu1-update` | 8 runs: no consent, No answer, Yes answer (one prompt, 2 compilers, 5 lines), all current with `--json`, one release tool, a pinned commit (no request), an unknown tool, `talon` | R-T24, R-T25, R-T9, R-T26, R-DL1, R-DL4, R-NM5 |
| L3 | `tools/ti3-tool-git` | 8 steps with the real Fx, curl, tar and unbundle: install `--git`, a release tool, `ls`, `Present`, update with no change, the branch moves, rebuild all (no commit request), `rm`, a sha with `--path` | R-T23, R-T24, R-T25, R-T7, R-B6, R-SL10, R-SE12, R-CC1, R-CC2, R-DA3 |

Run `MISSING=1 scripts/rules.sh R-T R-B`: R-T7, R-T23, R-T24, R-T25 and R-B6 have tests. The ids that still show with no test are outside this slice (section 7).

## 5. Output (proposed, R-OUT2, TW24)

The design gives only `pinned to commit dd03c09e` (R-T24). All other texts and the `data` fields are proposals for the human review. The doc comment of each function has the exact text.

| Where | Text |
| --- | --- |
| `tool ls` | a table with the columns TOOL NAME SOURCE COMPILER TARGET INSTALLED (and LIBS only if a tool has libraries). SOURCE is the version, or `git <ref>@<8 digits>` and the path. No tool: `no tool is installed. Run: tln tool install owner/app` |
| `tool ls --json` | `data.tools`: tool, name, source (kind and fields), nightly, target, sha256, libs, installed_at |
| `tool rm` | `removed <key> <source> (<name>)`. A kept entry: `warning: <path> is not a file that tln wrote, so tln keeps it` on stderr. `--json` data: tool, name, source, version, removed, kept |
| `tool update` | `updated <key> <old> to <new> (<name>)`, `<key> <source> is up to date`, `<key>: pinned to commit <8 digits>` (the prefix `<key>: ` is the proposal) |
| `tool rebuild` | `rebuilt <key> <source> (<name>) with <compiler id>` |
| `update` and `rebuild --json` | `data.tools`: one object for each tool: tool, name, how (`updated`, `up_to_date`, `pinned`, `rebuilt`), from, to |
| `tool install --git` | `installed <key> git <ref>@<8 digits> (<name>)` (the lines of 046 with the version text `git <ref>@<8 digits>`). `--json` data as 046 plus commit, ref and path, and `source` is `git` |
| the consent of update and rebuild | the prompt `Download <n> compilers, <size>: <ids>?` (id `tool-download`, yes/no, default yes), the stop `<n> compiler downloads are needed (<ids>). Pass --yes or set TALON_AUTO_INSTALL=yes.`, the refusal with `TALON_AUTO_INSTALL=no`, the decline `the download of <ids> was declined. No tool was changed.` |
| foreign entry (update, rebuild) | `<path> is not a file that tln wrote, so tln does not replace it. Move or remove that file, then run the command again.` |
| git failures | `<repo>@<ref> has no main.roc at its top. Use --path <dir> ...`, `... has no main.roc in <path>`, `main.roc of <repo>@<ref> is not an app ...`, the text of wget (exit 18) |

## 6. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Options rejected |
| --- | --- | --- |
| D1 | `tool rebuild` with no name rebuilds all tools (R-T7 has no operand rule, R-T25 is for update). `tool rm` takes exactly one name. `update` and `rebuild` take at most one | `rebuild` needs a name (too narrow for the repair that R-T7 means: all tools after an OS upgrade). `rm` with no name removes all tools (too dangerous) |
| D2 | A selector on any of these commands is refused (`foo@1.2`): exit 2 | `update foo@1.2` as a version change (R-T24 gives no such rule) |
| D3 | `tool rm`, `update` and `rebuild` of `talon` give `is not built yet` (exit 2). `--dry-run`, `--remove-tools`, `--keep-all` with another `rm`, and `--from-source` with another `update`, are exit 2 (R-FL12 read literally) | Accept and ignore the flags |
| D4 | `ToolGit.read` runs before `ToolInstall.read`. `--path` needs a git source. A sha selector with no `--git` is a git source (R-SL10) | Teach `ToolInstall.read` the git forms (its refusals and L0 rows would change) |
| D5 | The same commit is installed: `Present`, no build (R-T26 read for a git tool). A release install replaces a git tool and the reverse (R-T27). Another commit of the ref: build and replace | Always rebuild a git install (R-T26: an install that finds the same source does not build again) |
| D6 | The commit request is the request of slice 045 (the token, the media type). The archive goes to `<cache>/talon/tmp/<hex>/src` with its own `random!` value. `--path` is relative with no `..`. The path is recorded in `tools.json` as the optional field `path` of `source` | A path outside the source (R-SE12) |
| D7 | `update`: the way of a tool is `Release` (as `install app@latest`, with `min-release-age`), `Branch` (the head of the ref; a tag is a branch; the same commit is up to date), `Commit` (the typed ref is hex, 7 digits or more: no change, no request) | Ask the API what a ref is |
| D8 | A plan for all tools first (the sources are fetched, the platform is checked), then one consent, then the builds one by one. So one prompt covers all downloads (R-T25). The source of a git tool is fetched before the consent: a refused consent leaves nothing built or changed | Fetch and build tool by tool (one prompt for each tool, against R-T25) |
| D9 | The consent counts the compilers that are not installed (the pin of the new header for `update`, the recorded compiler for `rebuild`) and does not look at the evidence (R-DL1: a download "can happen"). The prompt is `Required`, default Yes. No person and no flag is exit 13. The text names `--yes` and `TALON_AUTO_INSTALL=yes`, not `--allow-downloads` (R-FL12: `tool update` refuses it). No option 2 and no evidence pass for these commands | Reuse the prompt of 047 (it has the options of a build with a missing pin for one app) |
| D10 | `rebuild` builds with the recorded compiler (R-T5). A recorded compiler that is not installed is downloaded again (same consent). The source is not changed. `sha256` and `installed_at` are new (R-ST9) | Rebuild with the header pin |
| D11 | A header with no `roc:` pin on `update` is exit 2 (D3 of 046) | Use the default compiler |
| D12 | `rm` order: the files first, `tools.json` last, all under the lock (R-CC6). A missing binary is no failure. A stop between gives a tool with no files, and `rm` can run again. The last tool leaves `"tools":{}` | `tools.json` first (a stop gives files that nothing owns) |
| D13 | The bin dir entry is deleted only when it is the file that Talon wrote (the sha256 of the data bin file, R-ST11). Else it is kept with a warning, and the manifest entry still goes | Refuse to remove the tool |
| D14 | Output is printed for each tool when it is done (`--json` collects one envelope). A failure in the build phase ends the command: the tools that were done before stay changed (question Q-U2) | Undo the earlier tools |
| D15 | The closure of the evidence digest for a git tool is the commit (`Bundle.hash`). `Done.how` of a replaced git tool keeps the old text `git <ref>` (046 `ToolBuild.source_text`) | |
| D16 | `tools.json` source of a git tool: `{"kind":"git","commit","ref"}` and `"path"` only with `--path` | |

## 7. Out of scope

| Rule or item | Reason |
| --- | --- |
| R-T22 (a prebuilt binary of Talon) | Talon only. The plan row for 048 has no R-T22 |
| R-T8 reading of `libs` (NEEDED entries) | `libs` is still `[]`. `ls` shows `libs` if the file has them (L0 row) |
| R-B1 to R-B5, R-B7 to R-B10, R-X | Slice 049 (`tln x`, the `x` cache) |
| R-PT | Slice 056. R-PT12 is asserted only: `tool rm` reads no project data |
| R-S, R-RM (`tool ... talon`) | Slices 050 and 051. The commands say `is not built yet` |
| R-ST10 (the Windows `.del` rule) | Slice 050 |
| `tool install --resolve` | Still `is not built yet` |
| `--roc` for `update` and `rebuild` | Not in the design (R-FL12) |

## 8. Questions (TW17) and design gaps

| # | Question or gap | What the slice does now |
| --- | --- | --- |
| Q-U1 | R-T25 names R-DL1 for the downloads of `tool update`, but R-NI8 (the prompt) is for `install` and `x`, R-DL3 gives no default for update, and R-FL12 does not allow `--allow-downloads` for tool commands. Which prompt, which default, which flags? | D9: one `Required` yes/no prompt, default Yes, `--yes` or `TALON_AUTO_INSTALL=yes` |
| Q-U2 | What happens when one tool fails in `update` or `rebuild` of all tools? | The plan stops at the first failure and nothing is built (tested: `tr2-rebuildstops` run 4). A build failure ends the command, earlier tools stay changed (untested, D14) |
| Q-U3 | `ToolInstall.foreign_failure` says `Use --as <name> ...`. For `update` and `rebuild` there is no `--as` | Changed at the review: `ToolUpdate.foreign_failure` names the file and says to move or remove it (L0 `ToolSourceTest` 12, L2 `tr2-rebuildstops` runs 1 and 4) |
| Q-U4 | `rebuild` of a tool whose recorded compiler is not a nightly tag (`git-...`, `link-...`) cannot be downloaded | `the compiler <id> is not installed. Run: tln roc install <id>.` (exit 13, L0 row) |
| Q-U5 | A branch named like a sha (`decade`, `abcdef1`) is seen as a commit by `update` | R-SL10 decides: 7 hex digits or more is a commit |
| Q-G1 | `--git` with a short name, a `host/path` name or no ref (as Q2 of slice 045) | Exit 2 (L0 rows, `tg2-gitstops` run 5) |
| Q-G2 | The text of `replaced` for a git tool: `replaced gapp git main with git v2@bbbbbbbb (acme/gapp)` shows the old ref without the commit (046 `ToolBuild.source_text`), the new one has the commit | Kept (tested in `tg1-git` run 4). `ToolManage.source_text` gives the other form |
| Q-T1 | The entry of `talon` in `tools.json` has a source kind that `ToolsJson.read` and `manifest` do not know (exit 19 `has no source that tln knows`) | Slices 050 and 051 decide the kind. Until then a `tools.json` with `talon` makes `tool ls` fail |
| Q-T2 | `tool rm --dry-run` for a tool that is not `talon` | Exit 2 (D3) |

## 9. Compiler and tool limits met

| Limit | Effect |
| --- | --- |
| `app` is reserved as a record field | the field is `dir` |
| `{ x }` alone is a block, not a record | write `{ x: x }` |
| `==` on a `Try` does not compile; a partial record pattern on a `Try` fails | match both arms |
| Effectful functions do not work in `map_try` | `for` loops with `var $x` |
| `match` arm `A => $x = ...` is a syntax error | `A => { $x = ... }` |
| A narrower tag union argument does not widen to a wider closed union in a function annotation | the helper takes the full union |
| `roc check` warns on an unused variable and exits 2; `roc test` runs anyway | the reference has no unused variable |
| The L2 `random` is one value: the scratch dir of a git source and the temp dir of the build have the same path in the fake | `calls.log` of a git install has 2 `delete` lines for it; the real `random!` gives 2 dirs |
| A `delete!` of the last lock releases the empty `talon/tmp` (existing behavior of `RealLocks`) | the L3 case does not list `talon/tmp` after `tool rm` |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Where | the 6 stubs of section 2, `ToolsJson.roc` (4 stubs), `Run.roc`, `ToolBuild.roc`, `ToolFlow.roc`. `main.roc` is done |
| `Run.roc` | `["tool", "install"]` must call `ToolGitFlow.run!` (it forwards a line that is not a git source to `ToolFlow.run!`) |
| `ToolBuild.roc` | `Bundle` gets the fields `dir`, `source`, `path` (section 3). `attempt!` uses `{ ..layout, dir: bundle.dir }`. `install!` builds a `ToolsJson.Tool` from `ctx.bundle.source`, `.path`, `.hashes`, the compiler id and the new `sha256`, and writes it with `ToolsJson.put` (the Release rows of 046 must give the same `tools.json` text). Add `probe_timeout` (moved from `ToolFlow`) |
| `ToolFlow.roc` | `read_app!` becomes `read_bundle!` (version, url, hash) and `read_app!` calls it. Add the public wrappers of section 3 (each calls the private step with the same name). The `Bundle` of a release has `dir` = the package dir, `source` = `Release`, `path` = `Err(None)` |
| Order of the calls | The tables in the doc comments of `ToolGitFlow`, `ToolManageFlow` and `ToolUpdateFlow`. The L2 `calls.log` files are the exact order |
| Reuse | `GitRef` (`commit_url`, `commit_headers`, `commit_of`, `archive_url`, `offline_failure`, `name_text`), `Github.ask_gh!`, `Net.token`, `Download.choose`, `Download.command`, `Download.outcome`, `Toolchain.tar_command`, `Toolchain.download_failed`, `Toolchain.tar_failed`, `RocInstall.spawn_one!`, `RocInstall.offer!`, `RocInstall.install_offer!`, `RocInstall.fetch_optional!`, `Consent.required_want`, `Consent.auto_install`, `Mode.from_env`, `Mode.with_tty`, `Prompt.ask!`, `Launch.toolchains!`, `ToolBuild.entry_verdict!`, `ToolBuild.finish!`, `SetupIo.have_of!`, `Lookup.find`, `Release.read`, `Locked.read`, `Ident.of_url` |
| Pure first | `ToolGit.read` runs before `ToolInstall.read`. A failure of `read` makes no `Fx` call |
| Size | Keep each module at or under 490 lines (section 2). `ToolUpdateFlow` may need a cut, for example the consent steps in a new module |
| Tests | Do not edit tests (TW18). A wrong row: write it in the report |

## 11. Red run, revert check

Red run with the stubs in `cli/lib` (log: `research/slice-048-revert/red-all.log`):

| Step | Result |
| --- | --- |
| `roc check cli/lib/main.roc`, `roc fmt --check` of the new and changed Roc files | pass, 0 warnings |
| `scripts/test.sh check fmt l0 l2 l3` | check pass, fmt pass, l0 FAIL, l2 FAIL, l3 FAIL |
| L0 | `l0-3`: 85 tests, 75 passed, 10 failed (the 10 `expect`s of `ToolManageTest`, `todo: slice 048`). `l0-4`: 72 tests, 60 passed, 12 failed (the 12 `expect`s of `ToolSourceTest`). The other 6 drivers pass |
| L2 | 123 passed, 6 failed: `tm1-manage`, `tr1-rebuild`, `tr2-rebuildstops`, `tu1-update` (`todo: slice 048`), `tg1-git` and `tg2-gitstops` (wrong value: `tool install --git` still says `is not built yet`, exit 2) |
| L3 | 70 passed, 1 failed (`tools/ti3-tool-git`, wrong value for the same reason), 1 skipped |

Old tests: all pass in the stub state (no old L0 row, L2 case or L3 case failed). `scripts/test.sh selftest` and `l1` were not run (nothing of this slice touches them).

Green run with the reference: `scripts/test.sh check fmt l0 l2 l3` all pass (L0 85 and 72 tests, L2 129 cases, L3 71 cases).

Revert check (`research/slice-048-revert/mutants.py`, 10 mutations (11 after the review) of the reference on the most tricky behaviors, the result in `mutants.log`). The reference was put back after each run, then `restore.sh` put the stubs back.

| # | Mutation | Caught by |
| --- | --- | --- |
| 1 | `rebuild` builds with the header pin | L2 `tr1-rebuild` run 1 |
| 2 | `update` of a commit asks for the head | L2 `tu1-update` run 6 (`calls.log`) |
| 3 | `update` builds a branch tool when the head is the installed commit | L2 `tu1-update` run 3 |
| 4 | `rm` deletes an entry that is not Talon's | L2 `tm1-manage` run 8 |
| 5 | `rm` writes `tools.json` before it deletes the files | L2 `tm1-manage` run 7 |
| 6 | `rm` takes no lock | L2 `tm1-manage` run 7 |
| 7 | the same compiler is counted twice for the downloads | L0 `ToolSourceTest` 10 |
| 8 | `--path` is not checked | L0 `ToolSourceTest` 1 (the L2 build also stops: the reference has unused variables then) |
| 9 | `tools.json` records the commit as the ref | L2 `tg1-git` run 1 |
| 10 | the scratch dir of a git install is not deleted | L2 `tg1-git` run 1 (`calls.log`) |

| 11 | (review) `update` and `rebuild` name `--as` for a foreign entry | L2 `tr2-rebuildstops` runs 1, 4 |

11 mutations, 11 caught, 0 not caught. No full sweep was run. `mutants.py` needs the reference, which was deleted after the review.

## 12. Proposed split (TW19)

The reference is about 1580 lines (about 950 lines without doc comments), against 350 in the plan row. The tests exist for all parts already. The proposed order, each part with its own stubs and its own green run:

| Part | Content | Why this order |
| --- | --- | --- |
| 048a | `tool install --git` (`ToolGit`, `ToolGitFlow`, the changes of `ToolBuild`, `ToolFlow`, `ToolsJson.put`). Tests: `ToolSourceTest` 1 to 6, `tg1-git`, `tg2-gitstops`, L3 steps 1, 3, 7 | Rebuild and update of a git tool need the git source |
| 048b | `tool ls`, `tool rm`, `tool rebuild` (`ToolManage`, `ToolManageFlow`, `ToolsJson.manifest`, `drop`, the rebuild half of `ToolUpdate`, `ToolUpdateFlow`). Tests: `ToolManageTest`, `ToolSourceTest` 9 to 12, `tm1-manage`, `tr1-rebuild`, `tr2-rebuildstops` | Uses `ToolBuild.finish!` and `ToolGitFlow.source!` |
| 048c | `tool update` (the way, the lines, `ToolUpdateFlow.update!`). Tests: `ToolSourceTest` 7, 8, `tu1-update` | Uses the plan and the consent of 048b |

If the manager keeps one slice, the code agent should write the modules in this order and run the cases of each part when it is done.

## Review (manager, 2026-10-25)

Accepted with the split of section 12 (048a, 048b, 048c). The tests stay as written. The code agents do 048a, then 048b, then 048c, one after another. D1 to D13 and the TW24 texts are accepted.

| Item | Answer |
| --- | --- |
| Q-U1 | Accepted as D9 (one Required prompt, default Yes, the no-person text names `--yes`) |
| Q-U2 | Accepted: the plan stops at the first failure. Tools that were done before stay done (each tool is its own write). No new test |
| Q-U3 | Changed: `update` and `rebuild` do not name `--as` for a foreign bin entry. Done in the tests and the stubs: `ToolUpdate.foreign_failure`, L0 `ToolSourceTest` 12, L2 `tr2-rebuildstops` runs 1 and 4 (new `expect/stderr`, old copy in `research/slice-048-revert/expect-before2/`). The reference was changed, green, and one mutation (11) was caught |
| Q-U4, Q-G1, Q-G2, Q-T2 | Accepted |
| Q-U5 | Accepted. It is a design gap (a branch named like a sha) |
| Q-T1 | Accepted for now. Slices 050 and 051 must make `ToolsJson.read` accept the `talon` entry (the manager records it in the 050 row) |

Parts for the code agents. Each part has its own stubs, tests and green run. A later part uses the code of the earlier ones. A stub of a later part stays a stub (`todo`) until its part.

| Part | Stub modules (`cli/lib/`) and changes | L0 tests | L2 cases | L3 |
| --- | --- | --- | --- | --- |
| 048a `--git` install | `ToolGit`, `ToolGitFlow`. `ToolsJson.put` (and the `Tool` type). `ToolBuild` (`Bundle` fields, `install!` uses `put`, `probe_timeout`), `ToolFlow` (the wrappers, `read_bundle!`). `Run.roc`: `tool install` calls `ToolGitFlow.run!` | `ToolSourceTest` 1 to 6 (read, key, reuse, layout, failures, data). `ToolManageTest` 9 (`put`) | `tool/tg1-git`, `tool/tg2-gitstops` | `tools/ti3-tool-git` steps 1, 3, 7 |
| 048b `ls`, `rm`, `rebuild` | `ToolManage`, `ToolManageFlow`. `ToolsJson.manifest`, `drop`. `ToolUpdate`: `origin`, `downloads`, `want`, `refused`, `consent_stop`, `prompt`, `declined`, `foreign_failure`, `rebuilt_text`, `Outcome`, `data`. `ToolUpdateFlow.rebuild!` (and the shared plan, consent and build steps) | `ToolManageTest` 1 to 8 and 10. `ToolSourceTest` 8 (the rebuilt line, `data`), 9 to 12 | `tool/tm1-manage`, `tool/tr1-rebuild`, `tool/tr2-rebuildstops` | `tools/ti3-tool-git` steps 2, 6, 7, 8 |
| 048c `update` | `ToolUpdate`: `way`, `moved`, `pinned_text`, `up_to_date_text`, `updated_text`. `ToolUpdateFlow.update!` | `ToolSourceTest` 7, 8 (the update lines) | `tool/tu1-update` | `tools/ti3-tool-git` steps 4, 5, 7 |

The L3 case and `ToolSourceTest` 8 run completely only when all three parts are done. The code agent of a part runs the cases of that part (and the old tests) and names the cases of later parts as still red.

## Verify results (048a)

Code agent, part 048a (`tool install --git`). The stubs of 048b and 048c are unchanged (`crash "todo: slice 048"`). The slice status stays `code` (the manager sets it after 048c).

Run of `scripts/test.sh` (all steps, one run):

| Step | Result | Detail |
| --- | --- | --- |
| check, fmt | pass | 0 errors, 0 warnings |
| l0 | FAIL | `l0-4` (`ToolSourceTest`): 72 tests, 66 passed. `ToolSourceTest` 1 to 6 pass. The 6 failures are 7 to 12 (`todo`). `l0-3` (`ToolManageTest`): 85 tests, 76 passed. Test 9 (`put`) passes. The 9 failures are 1 to 8 and 10 (`todo`). The 6 other drivers pass |
| l2 | FAIL | 125 passed, 4 failed. `tg1-git` and `tg2-gitstops` pass. The 4 failures are `tm1-manage`, `tr1-rebuild`, `tr2-rebuildstops` (048b) and `tu1-update` (048c): all `ROC CRASHED todo: slice 048` |
| l3 | FAIL | 70 passed, 1 failed, 1 skipped. `ti3-tool-git` fails: steps 1, 3 and the `--path` install of step 7 show no diff. The diff is in `tool ls` (step 2), `tool update` (steps 4, 5, 7), `tool rebuild` (step 6) and `tool rm` (steps 7, 8): exit 1 on `todo`, then the files and the http log that follow from it |
| selftest, l1 | pass | |

Files (line count): `ToolGit` 251, `ToolGitFlow` 184, `ToolsJson` 248, `ToolBuild` 244, `ToolFlow` 307, `ToolInstall` 448, `Run` 174. All under 490.

Changes outside the 2 stub modules:

| File | Change |
| --- | --- |
| `ToolsJson` | `put` written. `add` now calls `put` (`release_tool` makes the `Tool` of a `Built`), so the Release text of 046 is the same. `manifest` and `drop` stay `todo` (048b) |
| `ToolBuild` | `Bundle` has the fields of section 3. `attempt!` uses `{ ..layout, dir: bundle.dir }`. `install!` makes a `ToolsJson.Tool` and calls `put`. New: `probe_timeout` (moved from `ToolFlow`) and `app_header` (the pure read of an app header, used by `ToolFlow.read_bundle!` and `ToolGitFlow.source!`) |
| `ToolFlow` | `read_app!` calls the new `read_bundle!`. The 8 public wrappers of section 3 are there (`gather_for!`, `release_list_for!`, `notes_for!`, `first_app_for!`, `platform_for!`, `compile_for!`, `bundle_for!`, `package_text_for!`). 048a uses 3 of them |
| `ToolInstall` | New public `read_flags` (the `--roc` and `--as` checks of `read`, cut out so that `ToolGit.read` gives the same texts). `read` calls it. No text changed |
| `Run` | `["tool", "install"]` calls `ToolGitFlow.run!` |

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `Bundle` of a git source: `version` is `ToolGit.source_text`, `url` is the archive URL (not written to `tools.json`), `hash` is the commit (D15), `dir` is `<src>/<path>` | An empty `url` |
| C2 | `ToolGitFlow` calls `ToolGit.reuse`, not `ToolGit.key`: `gather_for!` already has the key (`ToolInstall.installed_key`, then the repo name), which is the rule of `ToolGit.key` | A second key step in the flow (it would change the `calls.log`: no) |
| C3 | The `--resolve` check (row 1) also runs for the sha form with no `--git`. `--path` with a line that is no git source is a failure also with no operand (row 8 read literally) | `--resolve` of a sha line goes to `ToolInstall.read` |
| C4 | `head!` gets `facts.now` for the reset time of a rate limit (with `TALON_NOW` it is that time) | A second `clock!` call (the `calls.log` has one) |

Revert check (`research/slice-048-revert/agent-mutate-a.py`, results in `agent-results-a.md`): 9 mutations, 9 caught, 0 not caught. The code is the same as before (`sha256sum -c research/slice-048-revert/code-final-a.sha256` passes; the copy is in `research/slice-048-revert/code-final-a/`).

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | a sha selector with no `--git` is not a git source | L0 `ToolSourceTest` 1 |
| M2 | the same commit is not needed for `Keep` | L0 `ToolSourceTest` 3 |
| M3 | a git install keeps a release tool (no replace) | L0 `ToolSourceTest` 3 |
| M4 | the source is fetched before the check of the bin dir entry | L2 `tg2-gitstops` run 8 |
| M5 | wget is accepted for the source archive | L2 `tg2-gitstops` run 4 |
| M6 | `--offline` is checked after the commit request | L2 `tg2-gitstops` run 3 |
| M7 | the temp dir of the source is not deleted after a failure | L2 `tg2-gitstops` run 1 |
| M8 | `--path` may have a `..` part | L0 `ToolSourceTest` 1 |
| M9 | `tools.json` has no `path` of a git tool | L0 `ToolManageTest` 9 |

The release replaced by a git tool is M3. A release install that replaces a git tool is old code of 046 (`ToolInstall.reuse`, `Git(_) => Build`) and 048a did not change it.

## Verify results (048b)

Code agent, part 048b (`tool ls`, `tool rm`, `tool rebuild`). The status stays `code`. `ToolUpdate.way` and `ToolUpdate.moved` and `ToolUpdateFlow.update!` stay `crash "todo: slice 048"` (048c).

Run of `scripts/test.sh` (one run, all steps):

| Step | Result | Detail |
| --- | --- | --- |
| check, fmt | pass | 0 errors, 0 warnings |
| l0 | FAIL | `l0-3` (`ToolManageTest`): 85 of 85 pass (tests 1 to 10). `l0-4` (`ToolSourceTest`): 72 tests, 71 passed, 1 failed: test 7 (`way`, `moved`, line 192), `todo`. The 6 other drivers pass |
| l2 | FAIL | 128 passed, 1 failed: `tool/tu1-update` (`ROC CRASHED todo: slice 048`). `tm1-manage`, `tr1-rebuild`, `tr2-rebuildstops`, `tg1-git`, `tg2-gitstops` pass |
| l3 | FAIL | 70 passed, 1 failed, 1 skipped: `tools/ti3-tool-git`. The case does not stop at the first failing step (all steps run). The diff has only `tool update` (steps 4, 5, 7: exit 1 on `todo`) and what follows from it (step 5 did not move the head, so the output of steps 6 and 7 `rm` shows `aaaaaaaa`, the build counts and the commit requests differ). Steps 1, 2 (`ls`, `ls --json`), 3, 7 (`--path` install) and 8 (`rm` of both tools, the empty `tools.json`) show no diff |
| selftest, l1 | pass | |

Steps 6 and 7 (`rebuild`, `rm`) checked with a temporary local run: a copy of the case in the scratchpad (`SCENARIOS=<dir> tests/run.sh`), with steps 4 and 5 replaced by `tln tool install --git acme/gtool@main` (same `tools.json` state as the update). Result: the `rebuilt` lines, the `ran:` lines, `builds: 5`, the `rm` line of step 7, `stderr` and the tree all equal the expected files. The count of `/commits/` requests is 3 (the 3 installs), so `rebuild` made no commit request (the expected 4 includes the one of `update`). The copy is deleted.

Files (line count): `ToolManage` 260, `ToolManageFlow` 199, `ToolUpdate` 180, `ToolUpdateFlow` 210, `ToolsJson` 319, `ToolBuild` 247. All under 490.

Changes:

| File | Change |
| --- | --- |
| `ToolManage` | all bodies. Imports `ToolGit` (`source_text` of a git tool) |
| `ToolManageFlow` | `list!`, `remove!`, `machine!`, `facts_of`, `find!` |
| `ToolsJson` | `manifest`, `drop` (new private `tool_of`, `texts_field`) |
| `ToolUpdate` | 048b: `origin`, `downloads`, `want`, `refused`, `consent_stop`, `prompt`, `declined`, `foreign_failure`, `rebuilt_text`, `data`. Also `pinned_text`, `up_to_date_text`, `updated_text` (pure texts of 048c): `ToolSourceTest` 8 names them, and the manager asked that test 8 passes in 048b. `way` and `moved` stay `todo` |
| `ToolUpdateFlow` | `rebuild!`, with the shared steps (plan, consent, builds, clean). `update!` is a stub. 048c can reuse `plan_one!`, `consent!`, `asked!`, `build_all!`, `clean!` (private functions of the module) |
| `ToolBuild` | new public `entry_state!` (the calls of `entry_verdict!`, result `Make` or `Foreign`). `entry_verdict!` calls it, same calls, same text. `rebuild` needs its own text for `Foreign` (no `--as`, Q-U3) |

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C5 | A release bundle of the manifest that is no app any more: kind `Input` (exit 19), `<key>: the bundle at <url> is not an app, so tln cannot build it again` (no test) | `Usage` (exit 2): the manifest is the thing that is wrong |
| C6 | `rebuild` or `update` with no tool: the `ToolManage.ls_report([])` line goes to stdout (`--quiet` hides it, `--json` moves it to stderr), exit 0. With `--json` the envelope has `tools: []`. No test | The line on stdout with `--json` (stdout must be the envelope, R-J1) |
| C7 | `want` judges `Refuse` for each id first, then the first id for the other results (`Consent.required_want` gives the same result for all nightly ids) | A fold over all ids |
| C8 | `remove!` under the lock reads `tools.json` again and takes the tool by its key. A tool that is gone gives `pick` with `New(name)` (`is not an installed tool`) | A new failure text |
| C9 | The prompt of `Ask` is skipped when all offers are `Present` (another process installed the compilers) | Ask anyway |

Revert check (`research/slice-048-revert/agent-mutate-b.py`, results in `agent-results-b.md`): 11 mutations, 11 caught, 0 not caught. The first run of M10 (the body of `clean!` removed) made a warning (unused variable) and so a build stop, not a test failure; M10 was changed to an inverted condition and then caught. The code is the same as before (`sha256sum -c research/slice-048-revert/code-final-b.sha256` passes; the copy is in `research/slice-048-revert/code-final-b/`).

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | `rm` writes `tools.json` before it deletes the files | L2 `tm1-manage` |
| M2 | `rm` deletes a bin dir entry that is not Talon's | L0 `ToolManageTest` 6 |
| M3 | `rm` takes no lock | L2 `tm1-manage` |
| M4 | `rebuild` builds with the header pin | L2 `tr1-rebuild` |
| M5 | `rebuild` with no name does not take all tools | L2 `tr1-rebuild` |
| M6 | the plan does not stop at the first failure | L2 `tr2-rebuildstops` |
| M7 | the foreign text of `rebuild` names `--as` | L0 `ToolSourceTest` 12 |
| M8 | the manifest source is read after the check of the bin dir entry | L2 `tr2-rebuildstops` |
| M9 | the downloads count a compiler twice | L0 `ToolSourceTest` 10 |
| M10 | the scratch dirs of the git sources are not deleted | L2 `tr1-rebuild` |
| M11 | `drop` removes the other tools | L0 `ToolManageTest` 10 |

Still red for 048c: `ToolSourceTest` 7 (`way`, `moved`), L2 `tu1-update`, L3 `ti3-tool-git` steps 4, 5 and the `update` of step 7 (all `todo`).

## Verify results (048c)

Code agent, part 048c (`tool update`). No `crash "todo` is left in `cli/` or `packages/`. The status is `verify`.

`scripts/test.sh`, one run, exit 0: check pass, fmt pass, l0 pass (`ToolSourceTest` 72 of 72, `ToolManageTest` 85 of 85, all drivers), l2 pass (129 cases, `tu1-update` included), l3 pass (71 cases, `ti3-tool-git` all steps), selftest pass, l1 pass. No test was changed.

Files: `ToolUpdate` 193 lines (`way`, `moved`, private `is_commit`), `ToolUpdateFlow` 343 lines (`update!`; `rebuild!` and `update!` share `ended!`, `run!`, `plan!`, `consent!`, `asked!`, `build_all!`, `clean!`). `rebuild` has the same calls as in 048b.

How `update` works: the plan walks the tools in order. `Commit`: no call, `Skip` with the pinned line. `Release`: `release_list_for!`, `ToolInstall.pick` and `reuse` with `Selector.Latest`: `Keep` is up to date, else notes, entry check, `first_app_for!`, the pin of the new header, `platform_for!`. `Branch`: `head!`, `moved`: `Same` is up to date, else entry check, `check_curl!`, `source!`, pin, `platform_for!`. A tool with nothing to build is a `Skip` item with its line; the lines are printed in the order of the file while the builds run. `consent!` makes no call when no tool is built (run 4 of `tu1-update`).

Decisions that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| C10 | `update` of a branch tool with `--offline`: `GitRef.offline_failure` before the commit request (as `tool install --git`, R-DI12). No test | A request that fails with a network text |
| C11 | A new header with no `roc:` pin: `ToolInstall.no_pin` (exit 2, D11), checked before the platform. No test | The recorded compiler |
| C12 | `update` of a tag or a branch named like a tag: `Branch` (D7). `way` reads a ref of 7 or more hex digits, in any case, as `Commit` (no upper limit) | A limit of 40 digits |

Revert check (`research/slice-048-revert/agent-mutate-c.py`, results in `agent-results-c.md`): 7 mutations, 7 caught, 0 not caught. The code is the same as before (`sha256sum -c research/slice-048-revert/code-final.sha256` passes from the repo root; the copy of all 11 files changed in 048a, 048b and 048c, `Run`, `ToolBuild`, `ToolFlow`, `ToolGit`, `ToolGitFlow`, `ToolInstall`, `ToolsJson`, `ToolManage`, `ToolManageFlow`, `ToolUpdate`, `ToolUpdateFlow`, is in `research/slice-048-revert/code-final/`).

| # | Mutation | Caught by |
| --- | --- | --- |
| M1 | a branch whose head moved is up to date | L0 `ToolSourceTest` 7 |
| M2 | a sha-pinned ref is a branch (the head is requested) | L0 `ToolSourceTest` 7 |
| M3 | a release tool is compared with no selector | L2 `tu1-update` |
| M4 | a release tool is always built | L2 `tu1-update` |
| M5 | the pinned text has no key prefix | L0 `ToolSourceTest` 8 |
| M6 | the consent stop does not stop (builds start) | L2 `tu1-update` |
| M7 | `update` builds with the recorded compiler, not the new pin | L2 `tu1-update` |

## Gap tests (test agent, 2026-10-25)

Gap step (TESTING.md 7.1 step 5) after the code of 048a, 048b and 048c. No code was changed (`sha256sum -c research/slice-048-revert/code-final.sha256`: all OK after each mutation). New rows come from `research/slice-048-revert/gen-manage.py` (tm1 runs 12 to 15) and `gen-gaps.py` (new case `tool/tu2-updatestops`). TW21: the old `expect/` of `tm1-manage` is in `research/slice-048-revert/expect-before3/`; the diff has only the added runs. No other `expect/` changed.

| Decision | Test | What it checks | One hand mutation (caught) |
| --- | --- | --- | --- |
| C6 | L2 `tm1-manage` runs 12 to 15 (`tool update`, `tool rebuild`, with and without `--json`, `tools.json` is `{"tools":{}}`) | the line `no tool is installed. ...` on stdout (stderr with `--json`), exit 0, `data.tools` is `[]`, only the start calls (no request, no lock) | the empty list is not special-cased: no line, so `tm1-manage` fails |
| C9 | L2 `tu2-updatestops` run 3 (`tool update mo`, a person, the new header pins `nightly-2026-October-14-38a3029`, the other tag form of the installed compiler) | the download is counted and the nightly list is read, the offer is `Present`: no `ask` call, no download, the tool is updated | the prompt is also asked when no offer is a download: `tu2-updatestops` fails |
| C10 | L2 `tu2-updatestops` run 2 (`tool update gm --offline`) | exit 15 and no `http_get` for the commit | the offline check is removed: `tu2-updatestops` fails |
| C11 | L2 `tu2-updatestops` run 1 (`tool update np`, the new header has no pin) | exit 2, the calls stop after reading `main.roc` (no platform fetch, no build) | a missing pin gives the recorded compiler: `tu2-updatestops` fails |

Files: `tests/commands/cases/tool/tu2-updatestops/` (22 files, 3 runs). L2 now has 130 cases. No code bug found.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-048-revert/code-final.sha256` | OK, 11 files |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.5, fmt 0.2, l0 6.9, l2 8.7, l3 9.9, selftest 3.0, l1 37.6 s |
| Code passes | 048a, 048b, 048c: 27 mutations caught, no test changed |
| Gap tests | C6 (4 runs in tm1-manage), C9, C10, C11 (new case tu2-updatestops), 4 hand mutations caught; no code bug |
