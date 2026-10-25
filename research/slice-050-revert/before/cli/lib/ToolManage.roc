import Args
import Fail
import JsonDoc
import Lookup
import Ref
import Scope
import ToolGit
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
	read = |args| {
		verb = match args.command {
			["tool", "update"] => Update
			["tool", "rebuild"] => Rebuild
			["tool", "remove"] => Remove
			_ => Ls
		}
		name = verb_name(verb)
		count = args.operands.len()
		count_check(verb, name, count)?
		ref = match args.operands {
			[one] => Ok(operand_ref(name, one)?)
			_ => Err(None)
		}
		flag_check(args, name)?
		Ok({ verb, ref })
	}

	## R-SC3: the installed tool that a lookup (`Lookup.find` with the scope `Tool` and `ToolsJson.entities`) found. `Existing`: the tool with that key. `New(name)`: the name is a full name that no tool has: kind `Usage`,
	## `'<name>' is not an installed tool. tln tool list shows the installed tools.` (A short name that no tool has is a failure of the lookup itself.)
	pick : { tools : List(ToolsJson.Tool), found : Lookup } -> Try(ToolsJson.Tool, Fail)
	pick = |facts| match facts.found {
		Existing(found) => match facts.tools.find_first(|t| t.key == found.alias) {
			Ok(tool) => Ok(tool)
			Err(_) => Err(not_installed(found.name))
		}
		New(name) => Err(not_installed(name))
	}

	## R-T4, R-T10, R-T23: how a tool says where it came from: the version of a release (`1.1.0`), `git <ref>@<first 8 of the commit>` of a git tool (`git main@dd03c09e`). The text of the lists, the reports and `data.previous`.
	source_text : ToolsJson.Tool -> Str
	source_text = |tool| match tool.source {
		Release(rel) => rel.version
		Git(git) => ToolGit.source_text({ ref: git.ref, sha: git.commit })
	}

	## R-T4, R-T8, R-OUT2 (proposal): the answer of `tool list`. The streams:
	##
	## | Case | stdout | stderr |
	## | --- | --- | --- |
	## | No tool | `no tool is installed. Run: tln tool install owner/app` | |
	## | Tools | The header and one line for each tool, in the order of the file. The columns are `TOOL` (the key), `NAME`, `SOURCE` (`source_text`, then ` <path>` for a git tool with `--path`), `COMPILER` (the compiler of the build, R-T5), `TARGET`, `INSTALLED` (the date `YYYY-MM-DD` of `installed_at`), and `LIBS` only when a tool has run-time libraries (R-T8: the names joined by `,`, `-` for no library). Each column is padded to its widest cell, the columns are separated by 2 spaces, and a line has no trailing space. | |
	##
	## Each element is one line with its `\n`.
	ls_report : List(ToolsJson.Tool) -> { stdout : List(Str), stderr : List(Str) }
	ls_report = |tools| if tools.is_empty() {
		{ stdout: ["no tool is installed. Run: tln tool install owner/app\n"], stderr: [] }
	} else {
		with_libs = tools.any(|t| !t.libs.is_empty())
		head = if with_libs ["TOOL", "NAME", "SOURCE", "COMPILER", "TARGET", "INSTALLED", "LIBS"] else ["TOOL", "NAME", "SOURCE", "COMPILER", "TARGET", "INSTALLED"]
		cells = tools.map(|t| row_of(t, with_libs))
		widths = head.map_with_index(|h, i| widest(cells, i, h.count_utf8_bytes()))
		{ stdout: [head].concat(cells).map(|row| "${line_of(row, widths)}\n"), stderr: [] }
	}

	## R-J3, R-J4, R-OUT4 (proposal): the `data` of `tool list --json`: `tools`, an array with one object for each tool in the order of the file. The keys of a tool, in this order: `tool` (the key), `name`, `source` (an object: `kind` `release` with `version` and `url`, or `kind` `git` with `commit`, `ref` and, with `--path`, `path`),
	## `nightly`, `target`, `sha256`, `libs` (an array of texts), `installed_at`.
	ls_data : List(ToolsJson.Tool) -> JsonDoc
	ls_data = |tools| JsonDoc.Obj([("tools", JsonDoc.Arr(tools.map(tool_doc)))])

	## R-ST6, R-ST11, R-B6: what `tool remove` does with the bin dir entry. `old` is the sha256 of the binary in the data bin dir (`Err(NotFound)`: it is gone). `have` is the entry as `SetupIo.have_of!` gives it.
	##
	## | `have` | `old` | Result |
	## | --- | --- | --- |
	## | `Absent` | any | `Gone`: nothing to delete |
	## | `Sha(s)` | `Ok(s)` (the same file) | `Remove`: the entry is the one that Talon wrote (R-ST11) |
	## | `Sha(s)` | another sha256, or `Err(NotFound)` | `Keep`: not Talon's (R-ST6) |
	## | `Dir` or `Unreadable` | any | `Keep` |
	entry_fate : { old : Try(Str, [NotFound]), have : [Absent, Dir, Unreadable, Sha(Str)] } -> [Remove, Gone, Keep]
	entry_fate = |facts| match facts.have {
		Absent => Gone
		Sha(sha) => match facts.old {
			Ok(old) if old == sha => Remove
			_ => Keep
		}
		Dir | Unreadable => Keep
	}

	## R-ST6, R-OUT2 (proposal): the warning on stderr for a bin dir entry that `remove` keeps: `warning: <path> is not a file that tln wrote, so tln keeps it`.
	kept_warning : Str -> Str
	kept_warning = |path| "warning: ${path} is not a file that tln wrote, so tln keeps it"

	## R-B6, R-OUT2 (proposal): the answer of `tool remove`: `removed <key> <source_text> (<name>)` and a line end.
	remove_report : ToolsJson.Tool -> Str
	remove_report = |tool| "removed ${tool.key} ${ToolManage.source_text(tool)} (${tool.name})\n"

	## R-J3, R-J4, R-OUT4 (proposal): the `data` of `tool remove --json`, the keys in this order: `tool`, `name`, `source` (`release` or `git`), `version` (the version of a release, else null), `removed` (an array of the paths that were deleted: the bin dir entry when it was Talon's, then the binary of the data bin dir),
	## `kept` (an array: the bin dir entry when it was kept).
	remove_data : { tool : ToolsJson.Tool, removed : List(Str), kept : List(Str) } -> JsonDoc
	remove_data = |facts| {
		(kind, version) = match facts.tool.source {
			Release(rel) => ("release", JsonDoc.Text(rel.version))
			Git(_) => ("git", JsonDoc.Null)
		}
		JsonDoc.Obj([
			("tool", JsonDoc.Text(facts.tool.key)),
			("name", JsonDoc.Text(facts.tool.name)),
			("source", JsonDoc.Text(kind)),
			("version", version),
			("removed", JsonDoc.Arr(facts.removed.map(|p| JsonDoc.Text(p)))),
			("kept", JsonDoc.Arr(facts.kept.map(|p| JsonDoc.Text(p)))),
		])
	}
}

usage : Str -> Fail
usage = |message| Fail.new(Usage, message)

verb_name : [Ls, Update, Rebuild, Remove] -> Str
verb_name = |verb| match verb {
	Ls => "list"
	Update => "update"
	Rebuild => "rebuild"
	Remove => "remove"
}

# Rows 1 to 4: how many operands the verb takes.
count_check : [Ls, Update, Rebuild, Remove], Str, U64 -> Try({}, Fail)
count_check = |verb, name, count| match verb {
	Ls => if count > 0 Err(usage("tln tool list takes no tool name, got ${count.to_str()}")) else Ok({})
	Remove => if count == 0 {
		Err(usage("tln tool remove needs one tool: tln tool remove <tool>"))
	} else if count > 1 {
		Err(usage("tln tool remove takes one tool, got ${count.to_str()}"))
	} else {
		Ok({})
	}
	_ => if count > 1 Err(usage("tln tool ${name} takes one tool, or none for all tools, got ${count.to_str()}")) else Ok({})
}

# Rows 5 to 7: the operand is a tool name with no selector, and not `talon`.
operand_ref : Str, Str -> Try(Ref, Fail)
operand_ref = |name, operand| {
	ref = Ref.parse(operand, Scope.Tool, Bool.False)?
	match ref.selector {
		Ok(_) => return Err(usage("tln tool ${name} takes a tool name, not a version: '${operand}'"))
		Err(None) => {}
	}
	if ref.name == "talon" or ref.name == "roc-talon/talon" {
		Err(usage("tln tool ${name} talon is not built yet"))
	} else {
		Ok(ref)
	}
}

# Rows 8 and 9, R-FL12: the flags of `tool remove talon` and `tool update talon`.
flag_check : Args, Str -> Try({}, Fail)
flag_check = |args, name| {
	only = match name {
		"remove" => ["--dry-run", "--remove-tools", "--keep-all"]
		"update" => ["--from-source"]
		_ => []
	}
	match args.options.find_first(|(flag, _)| only.contains(flag)) {
		Ok((flag, _)) => Err(usage("tln tool ${name} ${flag} works only for tln tool ${name} talon"))
		Err(_) => Ok({})
	}
}

not_installed : Str -> Fail
not_installed = |name| usage("'${name}' is not an installed tool. tln tool list shows the installed tools.")

# One row of the table: the cells in the order of the columns.
row_of : ToolsJson.Tool, Bool -> List(Str)
row_of = |tool, with_libs| {
	source = match tool.path {
		Ok(path) => "${ToolManage.source_text(tool)} ${path}"
		Err(None) => ToolManage.source_text(tool)
	}
	date = Str.from_utf8_lossy(tool.installed_at.to_utf8().take_first(10))
	base = [tool.key, tool.name, source, tool.nightly, tool.target, date]
	if with_libs base.append(if tool.libs.is_empty() "-" else Str.join_with(tool.libs, ",")) else base
}

# The width of column `i`: the widest cell, at least `least`.
widest : List(List(Str)), U64, U64 -> U64
widest = |rows, i, least| rows.fold(
	least,
	|best, row| match row.get(i) {
		Ok(cell) => if cell.count_utf8_bytes() > best cell.count_utf8_bytes() else best
		Err(_) => best
	},
)

# The cells padded to their column, 2 spaces apart. The last cell has no padding, so the line has no space at its end.
line_of : List(Str), List(U64) -> Str
line_of = |row, widths| {
	last = row.len() - 1
	padded = row.map_with_index(
		|cell, i| {
			width = widths.get(i) ?? 0
			if i == last or cell.count_utf8_bytes() >= width cell else "${cell}${Str.repeat(" ", width - cell.count_utf8_bytes())}"
		},
	)
	Str.join_with(padded, "  ")
}

# The tool as `ls_data` shows it.
tool_doc : ToolsJson.Tool -> JsonDoc
tool_doc = |tool| {
	source = match tool.source {
		Release(rel) => JsonDoc.Obj([("kind", JsonDoc.Text("release")), ("version", JsonDoc.Text(rel.version)), ("url", JsonDoc.Text(rel.url))])
		Git(git) => {
			head = [("kind", JsonDoc.Text("git")), ("commit", JsonDoc.Text(git.commit)), ("ref", JsonDoc.Text(git.ref))]
			match tool.path {
				Ok(path) => JsonDoc.Obj(head.append(("path", JsonDoc.Text(path))))
				Err(None) => JsonDoc.Obj(head)
			}
		}
	}
	JsonDoc.Obj([
		("tool", JsonDoc.Text(tool.key)),
		("name", JsonDoc.Text(tool.name)),
		("source", source),
		("nightly", JsonDoc.Text(tool.nightly)),
		("target", JsonDoc.Text(tool.target)),
		("sha256", JsonDoc.Text(tool.sha256)),
		("libs", JsonDoc.Arr(tool.libs.map(|l| JsonDoc.Text(l)))),
		("installed_at", JsonDoc.Text(tool.installed_at)),
	])
}
