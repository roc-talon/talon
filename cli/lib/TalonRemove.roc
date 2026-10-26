import Answer
import Args
import Fail
import JsonDoc
import Prompt
import Roots
import Setup
import Text
import Toolchain
import ToolManage

## The pure decisions of `tln tool remove talon` (slice 051, CLI 6.5 "Remove Talon": R-S5, R-RM1 to R-RM10, R-NI10, R-NR3, R-ST4, R-ST10, R-ST11). Part A (TESTING.md 2.2). The command code is `TalonRemoveFlow`. The texts and the `data` fields are proposals (R-OUT2, TW24):
## the human accepts or changes them at the review.
##
## ```mermaid
## flowchart TD
##     A["read: --dry-run, --remove-tools (option 2), --keep-all (option 3)"] --> B["asks, parts: the 4 groups with their sizes (R-RM7 to R-RM10)"]
##     B --> C["prompt: 4 options, default 1 (R-NI10). Non-interactive: option 1 (R-RM3)"]
##     C --> D["choice_of, removes: what each option removes"]
##     D --> E["order: compilers, tools and tools.json, the PATH line, Talon data, then Talon (roc.old back, tln last)"]
## ```
TalonRemove :: [].{

	## The option that the person chose: `Default` is option 1 (remove Talon, the compilers and the data, keep the tools), `WithTools` is option 2 (`--remove-tools`), `TalonOnly` is option 3 (`--keep-all`). Option 4 is the cancel.
	Choice : [Default, WithTools, TalonOnly]

	## The 4 groups of the table of R-RM7 to R-RM10.
	Group : [Talon, Tools, Compilers, Data]

	## The flags of one line: `--dry-run`, and the answer flag (`--remove-tools` is `Ok(Option(2))`, `--keep-all` is `Ok(Option(3))`, none is `Err(NoFlag)`). `--yes` is in `Args`.
	Plan : { dry_run : Bool, flag : Try(Answer, [NoFlag]) }

	## One group as the screen shows it: the group, the text of its content, and its size in bytes (the sum of `tree_info!` for its paths).
	Part : { group : Group, detail : Str, size : U64 }

	## A path that the screen measures, and the group that it is in.
	Ask : { group : Group, path : Str }

	## What a run did, or would do (`DryRun`), or did not do (`Cancelled`). `back` is the move of `roc.old` to `roc` (R-RM6). `path` is each place where the `PATH` entry was removed (R-ST4). `kept` is each bin dir entry that Talon kept because it did not write it (R-ST6). `stuck` is
	## each renamed file of Windows that stays because the detached cleanup did not start (R-RM5). `stays` is each compiler that stays with its path (option 3, R-RM6).
	Done : {
		outcome : [Removed, DryRun, Cancelled],
		version : Str,
		choice : Choice,
		parts : List(Part),
		stays : List({ id : Str, path : Str }),
		back : Try({ from : Str, to : Str }, [None]),
		path : List([Profile(Str), UserPath(Str)]),
		kept : List(Str),
		stuck : List(Str),
	}

	## Is this the operand of `tool remove talon`: exactly one operand, `talon` or `roc-talon/talon` (`ToolManage.read` has checked the form)?
	is_target : Args -> Bool
	is_target = |args| match args.operands {
		[one] => one == "talon" or one == "roc-talon/talon"
		_ => Bool.False
	}

	## R-RM3, R-NI10, R-FL12: the flags of `tool remove talon`. `--remove-tools` is the answer option 2, `--keep-all` is option 3, both are a failure of kind `Usage` (exit 2): `tln tool remove talon takes --remove-tools or --keep-all, not both`.
	read : Args -> Try(Plan, Fail)
	read = |args| {
		dry_run = has_flag(args, "--dry-run")
		match (has_flag(args, "--remove-tools"), has_flag(args, "--keep-all")) {
			(Bool.True, Bool.True) => Err(Fail.new(Usage, "tln tool remove talon takes --remove-tools or --keep-all, not both"))
			(Bool.True, _) => Ok({ dry_run, flag: Ok(Option(2)) })
			(_, Bool.True) => Ok({ dry_run, flag: Ok(Option(3)) })
			_ => Ok({ dry_run, flag: Err(NoFlag) })
		}
	}

	## R-NI10: the answer of the prompt as a choice. `Option(1)`, `Option(2)`, `Option(3)` are the 3 choices. `Option(4)` (and any other answer) is `Err(Cancel)`.
	choice_of : Answer -> Try(Choice, [Cancel])
	choice_of = |answer| match answer {
		Option(1) => Ok(Default)
		Option(2) => Ok(WithTools)
		Option(3) => Ok(TalonOnly)
		_ => Err(Cancel)
	}

	## R-RM7 to R-RM10, R-RM3: the table of the groups. Talon goes in each option. The tools go only with option 2. The compilers and the Talon data go with options 1 and 2, and stay with option 3.
	removes : { choice : Choice, group : Group } -> Bool
	removes = |facts| match facts.group {
		Talon => Bool.True
		Tools => facts.choice == WithTools
		Compilers | Data => facts.choice != TalonOnly
	}

	## R-RM9: the versions of the Zig dirs of the listing of `<cache>/toolchains`: a dir `zig-<X.Y.Z>` (3 numbers). A file, a lock dir `zig-0.17.0.lock`, a temp dir and a compiler dir are no Zig. In byte order.
	zig_versions : List({ name : Str, is_dir : Bool, mtime : U64 }) -> List(Str)
	zig_versions = |entries| Text.sorted(entries.keep_if(|entry| entry.is_dir and is_zig_name(entry.name)).map(|entry| entry.name.drop_prefix("zig-")))

	## The text of the tools of a screen: `none`, or the count and the keys in the order of the file: `3 (foo, bar, baz)`.
	describe_tools : List(Str) -> Str
	describe_tools = |keys| if keys.is_empty() "none" else "${keys.len().to_str()} (${Str.join_with(keys, ", ")})"

	## The text of the compilers of a screen: the count of each kind in this order, `<n> nightly` or `nightlies`, `release(s)`, `git build(s)`, `link(s)`, `copy` or `copies`, then `zig <version>` for each Zig. `none` for nothing. Example: `4 nightlies, 1 git build, zig 0.17.0`.
	describe_compilers : { ids : List(Str), zigs : List(Str) } -> Str
	describe_compilers = |facts| {
		counts = [
			count_text(facts.ids, "nightly-", "nightly", "nightlies"),
			count_text(facts.ids.keep_if(|id| kind_of(id) == Release), "", "release", "releases"),
			count_text(facts.ids, "git-", "git build", "git builds"),
			count_text(facts.ids, "link-", "link", "links"),
			count_text(facts.ids, "copy-", "copy", "copies"),
		].keep_if(|text| !text.is_empty())
		words = counts.concat(facts.zigs.map(|version| "zig ${version}"))
		if words.is_empty() "none" else Str.join_with(words, ", ")
	}

	## R-RM7 to R-RM10, R-RM4: the paths that one `tree_info!` call measures, in this order. `file` is `tln` (`tln.exe` on Windows). `tools` are the file names in the data bin dir. `compats` are the `compat-<id>` dirs of the compilers.
	##
	## | Group | Paths |
	## | --- | --- |
	## | Talon | `<data bin>/<file>` |
	## | Tools | `<data bin>/<tool file>` for each tool, in the order of `tools` |
	## | Compilers | `Roots.item(Toolchain(id))` for each id, then `Roots.item(Compat(c))` for each of `compats`, then `Roots.item(Zig(v))` for each of `zigs` |
	## | Data | `<cache>/talon`, `config.toml`, `share.json` |
	asks : { roots : Roots, file : Str, tools : List(Str), ids : List(Str), compats : List(Str), zigs : List(Str) } -> List(Ask)
	asks = |facts| {
		roots = facts.roots
		in_bin = |name| Text.join(Roots.item(roots, Bin), name)
		of_group = |group, paths| paths.map(|path| { group, path })
		[
			of_group(Talon, [in_bin(facts.file)]),
			of_group(Tools, facts.tools.map(in_bin)),
			of_group(Compilers, facts.ids.map(|id| Roots.item(roots, Toolchain(id)))),
			of_group(Compilers, facts.compats.map(|compat| Roots.item(roots, Compat(compat)))),
			of_group(Compilers, facts.zigs.map(|version| Roots.item(roots, Zig(version)))),
			of_group(Data, [Text.join(roots.cache, "talon"), Roots.item(roots, Config), Roots.item(roots, ShareJson)]),
		].join()
	}

	## R-RM4, R-NR2: the 4 groups with the text and the size, in the order Talon, Tools, Compilers, Data. `infos` are the answers of `tree_info!` for `asks`, in the same order (a path that is missing or cannot be read counts 0 bytes).
	## The detail of Talon is `tln, roc, the talon entry of tools.json`, of the Talon data `index, x cache, compat.db, config` (the text of the design).
	parts : { asks : List(Ask), infos : List(Try({ newest : U64, size : U64 }, [NotFound, Denied, Other(Str)])), tools : List(Str), ids : List(Str), zigs : List(Str) } -> List(Part)
	parts = |facts| {
		sized = facts.asks.map_with_index(
			|ask, i| match facts.infos.get(i) {
				Ok(Ok(info)) => { group: ask.group, size: info.size }
				_ => { group: ask.group, size: 0 }
			},
		)
		total = |group| sized.keep_if(|one| one.group == group).fold(0, |sum, one| sum + one.size)
		[
			{ group: Talon, detail: "tln, roc, the talon entry of tools.json", size: total(Talon) },
			{ group: Tools, detail: describe_tools(facts.tools), size: total(Tools) },
			{ group: Compilers, detail: describe_compilers({ ids: facts.ids, zigs: facts.zigs }), size: total(Compilers) },
			{ group: Data, detail: "index, x cache, compat.db, config", size: total(Data) },
		]
	}

	## R-NI10, R-NR2, R-NR3, R-NM4: the prompt. Kind `Default` (R-NR3), the shape `Options(4)`, the default option 1. The answer flags are `--remove-tools` and `--keep-all` (`Plan.flag`). With no person (CI, `--json`, no terminal) and with `--yes` the answer is option 1 (R-RM3).
	## The question is the screen of the design: the version, the 3 groups with their size, the note on `roc`, the 4 options, and the word `Choose`. `Prompt.text` adds ` [1-4, default 1] `.
	##
	## | Field | Text (a proposal, TW24) |
	## | --- | --- |
	## | `id` | `talon-remove` |
	## | `subject` | `the removal of Talon` |
	## | `answer_line` | Option 1: `removing Talon, the compilers and the data, keeping the tools`. Option 2: `removing Talon, the compilers, the data and the tools`. Option 3: `removing Talon only`. Option 4: `cancelled` |
	prompt : { version : Str, parts : List(Part) } -> Prompt
	prompt = |facts| Prompt.{
		id: "talon-remove",
		kind: Default,
		shape: Options(4),
		default: Option(1),
		question: screen(facts),
		subject: "the removal of Talon",
		answer_line: |answer| match answer {
			Option(1) => "removing Talon, the compilers and the data, keeping the tools"
			Option(2) => "removing Talon, the compilers, the data and the tools"
			Option(3) => "removing Talon only"
			_ => "cancelled"
		},
	}

	## R-NI10, R-RM3: the screen of the prompt (the text of the design, CLI 6.5 "Remove Talon"). The 3 groups after Talon are a table: the label, the content, the size, and for the tools the note `they run without Talon`. The columns are padded to their widest cell and are 3 spaces apart. The size column is right aligned.
	## The text has no line end at its end.
	##
	## ```text
	## Remove Talon 0.3.1 (tln and the roc proxy)?
	##
	## Talon also manages:
	##   tools        3 (foo, bar, baz)                       42.0 MB   they run without Talon
	##   compilers    4 nightlies, 1 git build, zig 0.17.0     1.2 GB
	##   Talon data   index, x cache, compat.db, config      310.0 MB
	##
	## The roc command goes with Talon. A kept compiler stays in toolchains/<id>/roc.
	##
	##   1) Remove Talon, the compilers and the data. Keep the tools.   [default]
	##   2) Remove Talon and all of the above
	##   3) Remove Talon only
	##   4) Cancel
	## Choose
	## ```
	screen : { version : Str, parts : List(Part) } -> Str
	screen = |facts| {
		shown = facts.parts.keep_if(|part| part.group != Talon)
		rows = shown.map(|part| row_of(part, if part.group == Tools "they run without Talon" else ""))
		options = [
			"  1) Remove Talon, the compilers and the data. Keep the tools.   [default]",
			"  2) Remove Talon and all of the above",
			"  3) Remove Talon only",
			"  4) Cancel",
		]
		head = ["Remove Talon ${facts.version} (tln and the roc proxy)?", "", "Talon also manages:"]
		note = ["", "The roc command goes with Talon. A kept compiler stays in toolchains/<id>/roc.", ""]
		Str.join_with(head.concat(table(rows).map(|line| "  ${line}")).concat(note).concat(options).append("Choose"), "\n")
	}

	## The name of a group in the lines: `Talon`, `tools`, `compilers`, `Talon data`.
	label : Group -> Str
	label = |group| match group {
		Talon => "Talon"
		Tools => "tools"
		Compilers => "compilers"
		Data => "Talon data"
	}

	## R-RM4, R-OUT2 (proposal): the lines of stdout, each with its line end. The first lines are the same for a dry run and a real run, one for each group in the table order, with the same columns as the screen: label, content, size, and the verb. The verb is `remove` or `keep` for a
	## dry run (`removes` of the choice), `removed` or `kept` for a real run.
	##
	## | Outcome | Lines |
	## | --- | --- |
	## | `Cancelled` | `cancelled: nothing was removed` |
	## | `DryRun` | The 4 rows (table), then `dry run: nothing was removed` |
	## | `Removed` | The 4 rows, then one line `kept <id>: <path>` for each of `stays`, then `moved <from> back to <to>` for `back`, then for each of `path`: `removed the PATH line from <file>` (`Profile`) or `removed <dir> from the user Path` (`UserPath`) |
	report : Done -> List(Str)
	report = |done| match done.outcome {
		Cancelled => ["cancelled: nothing was removed\n"]
		DryRun => table(done.parts.map(|part| row_of(part, verb(done, part.group)))).map(with_end).append("dry run: nothing was removed\n")
		Removed => {
			rows = table(done.parts.map(|part| row_of(part, verb(done, part.group)))).map(with_end)
			stays = done.stays.map(|one| "kept ${one.id}: ${one.path}\n")
			back = match done.back {
				Ok(move) => ["moved ${move.from} back to ${move.to}\n"]
				Err(None) => []
			}
			path = done.path.map(
				|place| match place {
					Profile(file) => "removed the PATH line from ${file}\n"
					UserPath(dir) => "removed ${dir} from the user Path\n"
				},
			)
			rows.concat(stays).concat(back).concat(path)
		}
	}

	## R-ST6, R-RM5, R-OUT2 (proposal): the lines of stderr, each with its line end. A bin dir entry that Talon kept: `warning: <path> is not a file that tln wrote, so tln keeps it` (`ToolManage.kept_warning`, as `tool remove`). Renamed files of Windows that stay:
	## `warning: tln could not start the cleanup of <n> renamed files, so they stay: <path>, <path>. A later install of Talon deletes them`.
	warnings : Done -> List(Str)
	warnings = |done| {
		kept = done.kept.map(|path| "${ToolManage.kept_warning(path)}\n")
		if done.stuck.is_empty() {
			kept
		} else {
			kept.append("warning: tln could not start the cleanup of ${done.stuck.len().to_str()} renamed files, so they stay: ${Str.join_with(done.stuck, ", ")}. A later install of Talon deletes them\n")
		}
	}

	## R-J3, R-J4, R-OUT4 (proposal): the `data` of `--json`, the keys in this order: `outcome` (`removed`, `dry_run`, `cancelled`), `version`, `option` (1, 2, 3, or null for a cancel), `groups` (an array: `group` (`talon`, `tools`, `compilers`, `data`), `action` (`remove` or `keep`), `detail`, `bytes`),
	## `compilers_kept` (an array of `id` and `path`), `roc_restored` (the path of `roc` when `roc.old` moved back, else null), `path` (an array of the places, a file or `the user Path`), `kept_entries` (an array of paths), `stuck` (an array of paths). A cancel has an empty `groups`.
	data : Done -> JsonDoc
	data = |done| {
		groups = match done.outcome {
			Cancelled => []
			_ => done.parts.map(
				|part| JsonDoc.Obj([
					("group", JsonDoc.Text(group_key(part.group))),
					("action", JsonDoc.Text(if removes({ choice: done.choice, group: part.group }) "remove" else "keep")),
					("detail", JsonDoc.Text(part.detail)),
					("bytes", JsonDoc.Num(part.size.to_i64_wrap())),
				]),
			)
		}
		option = match done.outcome {
			Cancelled => JsonDoc.Null
			_ => JsonDoc.Num(option_of(done.choice))
		}
		restored = match done.back {
			Ok(move) => JsonDoc.Text(move.to)
			Err(None) => JsonDoc.Null
		}
		JsonDoc.Obj([
			("outcome", JsonDoc.Text(outcome_key(done.outcome))),
			("version", JsonDoc.Text(done.version)),
			("option", option),
			("groups", JsonDoc.Arr(groups)),
			("compilers_kept", JsonDoc.Arr(done.stays.map(|one| JsonDoc.Obj([("id", JsonDoc.Text(one.id)), ("path", JsonDoc.Text(one.path))])))),
			("roc_restored", restored),
			(
				"path",
				JsonDoc.Arr(
					done.path.map(
						|place| match place {
							Profile(file) => JsonDoc.Text(file)
							UserPath(_) => JsonDoc.Text("the user Path")
						},
					),
				),
			),
			("kept_entries", JsonDoc.Arr(done.kept.map(|path| JsonDoc.Text(path)))),
			("stuck", JsonDoc.Arr(done.stuck.map(|path| JsonDoc.Text(path)))),
		])
	}

	## R-RM6: the path that is printed for a compiler that stays (option 3), so that the user can put it on `PATH`. `roc` is `<cache>/toolchains/<id>/roc`. A `link-` compiler has no `roc` in its dir: its path is the target that its `.talon.json` records (`link`, `Link.target`), when that is readable.
	## `moved` is the move of `roc.old` back to `roc`. When the target of a link is the old path of that move (`link-system`, R-ST2), the compiler is at the new path after the removal, so that path is printed.
	kept_path : { id : Str, roc : Str, link : Try(Str, [None]), moved : Try({ from : Str, to : Str }, [None]) } -> Str
	kept_path = |facts| match facts.link {
		Ok(target) if facts.id.starts_with("link-") => match facts.moved {
			Ok(move) if move.from == target => move.to
			_ => target
		}
		_ => facts.roc
	}

	## R-RM6, R-RM5: whether `roc.old` goes back. `old` is true when `roc.old` (`roc.old.exe`) is in the bin dir. `roc` is the fate of the `roc` entry (`ToolManage.entry_fate`): `Remove` and `Gone` leave the place free, `Keep` is a file that Talon did not write (R-ST6), so the old one stays where it is.
	restores : { old : Bool, roc : [Remove, Gone, Keep] } -> Bool
	restores = |facts| facts.old and facts.roc != Keep

	## R-RM5, R-HF11 (proposal): the detached child of Windows that waits until Talon ends, then deletes the renamed files. `argv` is `cmd.exe /d /c <script>`. The files are in the variables `TALON_DEL_1`, `TALON_DEL_2`, ... of `env`, never in the script. The script tries 30 times, one second apart (`ping -n 2`): it deletes the files and ends
	## when none is left.
	cleanup_command : List(Str) -> { argv : List(Str), env : List((Str, Str)) }
	cleanup_command = |files| {
		vars = files.map_with_index(|_, i| "%TALON_DEL_${(i + 1).to_str()}%")
		quoted = Str.join_with(vars.map(|name| "\"${name}\""), " ")
		gone = Str.join_with(vars.map(|name| "if not exist \"${name}\""), " ")
		script = "for /l %i in (1,1,30) do (ping -n 2 127.0.0.1 >nul & del /f /q ${quoted} >nul 2>&1 & ${gone} exit /b 0)"
		{
			argv: ["cmd.exe", "/d", "/c", script],
			env: files.map_with_index(|file, i| ("TALON_DEL_${(i + 1).to_str()}", file)),
		}
	}

	## The file name of Talon in the data bin dir and in the bin dir: `tln` (`tln.exe` on Windows).
	file : Setup.Os -> Str
	file = |os| if os == Windows "tln.exe" else "tln"
}

has_flag : Args, Str -> Bool
has_flag = |args, flag| args.options.any(|(name, _)| name == flag)

# A Zig dir name: `zig-` and 3 numbers with dots.
is_zig_name : Str -> Bool
is_zig_name = |name| name.starts_with("zig-") and match name.drop_prefix("zig-").split_on(".") {
	[a, b, c] => [a, b, c].all(is_number)
	_ => Bool.False
}

is_number : Str -> Bool
is_number = |text| !text.is_empty() and text.to_utf8().all(|byte| byte >= 48 and byte <= 57)

Kind : [Nightly, Release, Git, Link, Copy]

kind_of : Str -> Kind
kind_of = |id| if id.starts_with("nightly-") {
	Nightly
} else if id.starts_with("git-") {
	Git
} else if id.starts_with("link-") {
	Link
} else if id.starts_with("copy-") {
	Copy
} else {
	Release
}

# `<n> <word>` for the ids that start with `prefix`, or the empty text for none.
count_text : List(Str), Str, Str, Str -> Str
count_text = |ids, prefix, one, many| {
	n = if prefix == "" ids.len() else ids.keep_if(|id| id.starts_with(prefix)).len()
	if n == 0 "" else "${n.to_str()} ${if n == 1 one else many}"
}

Row : { label : Str, detail : Str, size : Str, tail : Str }

row_of : { group : Group, detail : Str, size : U64 }, Str -> Row
row_of = |part, tail| { label: TalonRemove.label(part.group), detail: part.detail, size: Toolchain.size_text(part.size), tail }

# The rows as lines: the cells padded to their widest cell, 3 spaces apart, the size right aligned. The tail has no padding.
table : List(Row) -> List(Str)
table = |rows| {
	label_width = widest(rows.map(|row| row.label))
	detail_width = widest(rows.map(|row| row.detail))
	size_width = widest(rows.map(|row| row.size))
	rows.map(
		|row| {
			size = "${Str.repeat(" ", size_width - row.size.count_utf8_bytes())}${row.size}"
			tail = if row.tail.is_empty() "" else "   ${row.tail}"
			"${padded(row.label, label_width)}   ${padded(row.detail, detail_width)}   ${size}${tail}"
		},
	)
}

widest : List(Str) -> U64
widest = |texts| texts.fold(0, |best, text| if text.count_utf8_bytes() > best text.count_utf8_bytes() else best)

padded : Str, U64 -> Str
padded = |text, width| "${text}${Str.repeat(" ", width - text.count_utf8_bytes())}"

with_end : Str -> Str
with_end = |line| "${line}\n"

# The last cell of a row of the report: the verb of the group.
verb : Done, Group -> Str
verb = |done, group| {
	goes = TalonRemove.removes({ choice: done.choice, group })
	match done.outcome {
		DryRun => if goes "remove" else "keep"
		_ => if goes "removed" else "kept"
	}
}

group_key : Group -> Str
group_key = |group| match group {
	Talon => "talon"
	Tools => "tools"
	Compilers => "compilers"
	Data => "data"
}

outcome_key : [Removed, DryRun, Cancelled] -> Str
outcome_key = |outcome| match outcome {
	Removed => "removed"
	DryRun => "dry_run"
	Cancelled => "cancelled"
}

option_of : Choice -> I64
option_of = |choice| match choice {
	Default => 1
	WithTools => 2
	TalonOnly => 3
}
