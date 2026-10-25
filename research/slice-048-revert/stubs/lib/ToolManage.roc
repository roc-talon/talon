import Args
import Fail
import JsonDoc
import Lookup
import Ref
import ToolsJson

## The pure decisions of `tln tool list`, `tool remove` and the operand of `tool update` and `tool rebuild` (slice 048, CLI 6.4: R-CM16, R-CM19, R-T4, R-T8, R-B6, R-ST6, R-ST11, R-SC3). Part A (TESTING.md 2.2). The command code is `ToolManageFlow` (`list!`, `remove!`), `ToolUpdateFlow`
## (`update!`, `rebuild!`). The texts and the `data` fields are proposals (R-OUT2, TW24): the human accepts or changes them at the review.
##
## ```mermaid
## flowchart TD
##     A["read: the verb and the operand (R-CM19)"] --> B["Lookup (scope Tool, R-SC3): the key, the full name or the short name"]
##     B --> C["pick: the tool of tools.json (ToolsJson.manifest)"]
##     C --> D["list: ls_report, ls_data"]
##     C --> E["remove: fate of the bin dir entry (R-ST11), the lock of tools.json (R-CC6), delete, drop"]
##     C --> F["update, rebuild: ToolUpdate"]
## ```
ToolManage :: [].{

	## The command: `Ls` is `tool list` (`tool ls`), `Remove` is `tool remove` (`tool rm`). `ref` is the operand (`Ref.parse` in the scope `Tool`): `Err(None)` for no operand (`list`, and `update` and `rebuild` for all tools).
	Cmd : { verb : [Ls, Update, Rebuild, Remove], ref : Try(Ref, [None]) }

	## The line of `tool list`, `tool update`, `tool rebuild` and `tool remove` (R-CM16, R-CM19, R-FL12). All failures have the kind `Usage` (exit 2). The texts use the long form of the command (R-CM19). The proposals (TW24) are in the table. The first row that holds wins:
	##
	## | # | Case | Failure |
	## | --- | --- | --- |
	## | 1 | `list` with an operand | `tln tool list takes no tool name, got <n>` |
	## | 2 | `remove` with no operand | `tln tool remove needs one tool: tln tool remove <tool>` |
	## | 3 | `remove` with 2 operands or more | `tln tool remove takes one tool, got <n>` |
	## | 4 | `update` or `rebuild` with 2 operands or more | `tln tool <verb> takes one tool, or none for all tools, got <n>` |
	## | 5 | The operand is not a ref (`Ref.parse(operand, Scope.Tool, false)`) | Its failure |
	## | 6 | The operand has a selector (`foo@1`, `foo@latest`) | `tln tool <verb> takes a tool name, not a version: '<operand>'` |
	## | 7 | The operand is `talon` or `roc-talon/talon` (slices 050 and 051) | `tln tool <verb> talon is not built yet` |
	## | 8 | `--dry-run`, `--remove-tools` or `--keep-all` with `remove` (R-FL12: they are for `tool rm talon`) | `tln tool remove <flag> works only for tln tool remove talon` |
	## | 9 | `--from-source` with `update` (R-FL12: it is for `tool update talon`) | `tln tool update --from-source works only for tln tool update talon` |
	read : Args -> Try(Cmd, Fail)
	read = |_args| crash "todo: slice 048"

	## R-SC3: the installed tool that a lookup (`Lookup.find` with the scope `Tool` and `ToolsJson.entities`) found. `Existing`: the tool with that key. `New(name)`: the name is a full name that no tool has: kind `Usage`,
	## `'<name>' is not an installed tool. tln tool list shows the installed tools.` (A short name that no tool has is a failure of the lookup itself.)
	pick : { tools : List(ToolsJson.Tool), found : Lookup } -> Try(ToolsJson.Tool, Fail)
	pick = |_facts| crash "todo: slice 048"

	## R-T4, R-T10, R-T23: how a tool says where it came from: the version of a release (`1.1.0`), `git <ref>@<first 8 of the commit>` of a git tool (`git main@dd03c09e`). The text of the lists, the reports and `data.previous`.
	source_text : ToolsJson.Tool -> Str
	source_text = |_tool| crash "todo: slice 048"

	## R-T4, R-T8, R-OUT2 (proposal): the answer of `tool list`. The streams:
	##
	## | Case | stdout | stderr |
	## | --- | --- | --- |
	## | No tool | `no tool is installed. Run: tln tool install owner/app` | |
	## | Tools | The header and one line for each tool, in the order of the file. The columns are `TOOL` (the key), `NAME`, `SOURCE` (`source_text`, then ` <path>` for a git tool with `--path`), `COMPILER` (the compiler of the build, R-T5), `TARGET`, `INSTALLED` (the date `YYYY-MM-DD` of `installed_at`), and `LIBS` only when a tool has run-time libraries (R-T8: the names joined by `,`, `-` for no library). Each column is padded to its widest cell, the columns are separated by 2 spaces, and a line has no trailing space. | |
	##
	## Each element is one line with its `\n`.
	ls_report : List(ToolsJson.Tool) -> { stdout : List(Str), stderr : List(Str) }
	ls_report = |_tools| crash "todo: slice 048"

	## R-J3, R-J4, R-OUT4 (proposal): the `data` of `tool list --json`: `tools`, an array with one object for each tool in the order of the file. The keys of a tool, in this order: `tool` (the key), `name`, `source` (an object: `kind` `release` with `version` and `url`, or `kind` `git` with `commit`, `ref` and, with `--path`, `path`),
	## `nightly`, `target`, `sha256`, `libs` (an array of texts), `installed_at`.
	ls_data : List(ToolsJson.Tool) -> JsonDoc
	ls_data = |_tools| crash "todo: slice 048"

	## R-ST6, R-ST11, R-B6: what `tool remove` does with the bin dir entry. `old` is the sha256 of the binary in the data bin dir (`Err(NotFound)`: it is gone). `have` is the entry as `SetupIo.have_of!` gives it.
	##
	## | `have` | `old` | Result |
	## | --- | --- | --- |
	## | `Absent` | any | `Gone`: nothing to delete |
	## | `Sha(s)` | `Ok(s)` (the same file) | `Remove`: the entry is the one that Talon wrote (R-ST11) |
	## | `Sha(s)` | another sha256, or `Err(NotFound)` | `Keep`: not Talon's (R-ST6) |
	## | `Dir` or `Unreadable` | any | `Keep` |
	entry_fate : { old : Try(Str, [NotFound]), have : [Absent, Dir, Unreadable, Sha(Str)] } -> [Remove, Gone, Keep]
	entry_fate = |_facts| crash "todo: slice 048"

	## R-ST6, R-OUT2 (proposal): the warning on stderr for a bin dir entry that `remove` keeps: `warning: <path> is not a file that tln wrote, so tln keeps it`.
	kept_warning : Str -> Str
	kept_warning = |_path| crash "todo: slice 048"

	## R-B6, R-OUT2 (proposal): the answer of `tool remove`: `removed <key> <source_text> (<name>)` and a line end.
	remove_report : ToolsJson.Tool -> Str
	remove_report = |_tool| crash "todo: slice 048"

	## R-J3, R-J4, R-OUT4 (proposal): the `data` of `tool remove --json`, the keys in this order: `tool`, `name`, `source` (`release` or `git`), `version` (the version of a release, else null), `removed` (an array of the paths that were deleted: the bin dir entry when it was Talon's, then the binary of the data bin dir),
	## `kept` (an array: the bin dir entry when it was kept).
	remove_data : { tool : ToolsJson.Tool, removed : List(Str), kept : List(Str) } -> JsonDoc
	remove_data = |_facts| crash "todo: slice 048"
}
