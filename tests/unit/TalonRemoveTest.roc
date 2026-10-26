import lib.Args
import lib.Prompt
import lib.Roots
import lib.TalonRemove

TalonRemoveTest :: [].{}

# Slice 051 (docs/slices/051-tool-rm-talon.md): `tln tool remove talon`, the pure decisions. The expected value of each row is the design text (CLI 6.5 "Remove Talon", 6.7, 4) or the slice file text, not the code. A wrong row prints with `dbg`.
# Texts that the design does not give are the proposals of the slice file (TW24). The `Fx` calls, the order of the removal and the files are in the L2 cases `tests/commands/cases/tool/rm1-default` to `rm4-stops` and the L3 case `tests/scenarios/tools/rm1-remove-talon`.

part : TalonRemove.Group, Str, U64 -> TalonRemove.Part
part = |group, detail, size| { group, detail, size }

# The design example, with the sizes of its text: tools 42 MB, compilers 1.2 GB, Talon data 310 MB, and Talon itself 9 MB.
screen_parts : List(TalonRemove.Part)
screen_parts = [
	part(Talon, "tln, roc, the talon entry of tools.json", 9_000_000),
	part(Tools, "3 (foo, bar, baz)", 42_000_000),
	part(Compilers, "4 nightlies, 1 git build, zig 0.17.0", 1_200_000_000),
	part(Data, "index, x cache, compat.db, config", 310_000_000),
]

done : [Removed, DryRun, Cancelled], TalonRemove.Choice -> TalonRemove.Done
done = |outcome, choice| { outcome, version: "0.3.1", choice, parts: screen_parts, stays: [], back: Err(None), path: [], kept: [], stuck: [] }

# R-NI10 R-RM3 R-FL12 R-S5: the operand and the flags of `tool remove talon`. `--remove-tools` is the answer option 2, `--keep-all` is option 3, no flag is no answer, `--dry-run` is a flag of its own. The 2 answer flags together are a usage failure (exit 2).
# `is_target` is true for exactly one operand, `talon` or `roc-talon/talon`.
expect {
	words = |list| match Args.parse(list) {
		Ok(args) => args
		Err(_) => crash "the test words do not parse"
	}
	read = |list| match TalonRemove.read(words(list)) {
		Ok(plan) => "dry=${Str.inspect(plan.dry_run)} flag=${Str.inspect(plan.flag)}"
		Err(fail) => fail.line()
	}
	target = |list| TalonRemove.is_target(words(list))
	rows = [
		("no flag", read(["tool", "rm", "talon"]), "dry=False flag=Err(NoFlag)"),
		("R-RM4: --dry-run", read(["tool", "rm", "talon", "--dry-run"]), "dry=True flag=Err(NoFlag)"),
		("R-RM3: --remove-tools is option 2", read(["tool", "remove", "talon", "--remove-tools"]), "dry=False flag=Ok(Option(2))"),
		("R-RM3: --keep-all is option 3", read(["tool", "remove", "talon", "--keep-all"]), "dry=False flag=Ok(Option(3))"),
		("--dry-run and an option", read(["tool", "rm", "roc-talon/talon", "--keep-all", "--dry-run"]), "dry=True flag=Ok(Option(3))"),
		("--yes is no part of the plan", read(["tool", "rm", "talon", "--yes"]), "dry=False flag=Err(NoFlag)"),
		("the 2 answer flags", read(["tool", "rm", "talon", "--remove-tools", "--keep-all"]), "tln: error[usage]: tln tool remove talon takes --remove-tools or --keep-all, not both"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	operands = [
		(target(["tool", "rm", "talon"]), Bool.True),
		(target(["tool", "rm", "roc-talon/talon"]), Bool.True),
		(target(["tool", "rm", "foo"]), Bool.False),
		(target(["tool", "rm", "acme/talon"]), Bool.False),
		(target(["tool", "ls"]), Bool.False),
		(target(["tool", "rm", "talon", "foo"]), Bool.False),
	]
	bad_operands = operands.keep_if(|(got, want)| got != want)
	dbg bad_operands
	bad == [] and bad_operands == []
}

# R-RM7 R-RM8 R-RM9 R-RM10 R-RM3 R-NI10: the table of the groups. Talon goes with each option. The tools go only with option 2 (`--remove-tools`). The compilers and the Talon data go with options 1 and 2, and stay with option 3 (`--keep-all`).
# The answer of the prompt: options 1 to 3 are the 3 choices, option 4 is the cancel, and so is any other answer (`Yes`, `No`, option 0, option 5).
expect {
	cell = |choice, group| if TalonRemove.removes({ choice, group }) "R" else "-"
	row = |choice| "${cell(choice, Talon)}${cell(choice, Tools)}${cell(choice, Compilers)}${cell(choice, Data)}"
	table = [
		("option 1", row(Default), "R-RR"),
		("option 2", row(WithTools), "RRRR"),
		("option 3", row(TalonOnly), "R---"),
	]
	bad_table = table.keep_if(|(_, got, want)| got != want)
	dbg bad_table
	choice = |answer| match TalonRemove.choice_of(answer) {
		Ok(Default) => "1"
		Ok(WithTools) => "2"
		Ok(TalonOnly) => "3"
		Err(Cancel) => "cancel"
	}
	answers = [
		(choice(Option(1)), "1"),
		(choice(Option(2)), "2"),
		(choice(Option(3)), "3"),
		(choice(Option(4)), "cancel"),
		(choice(Option(0)), "cancel"),
		(choice(Option(5)), "cancel"),
		(choice(Yes), "cancel"),
		(choice(No), "cancel"),
	]
	bad_answers = answers.keep_if(|(got, want)| got != want)
	dbg bad_answers
	bad_table == [] and bad_answers == []
}

# R-RM9 R-RM1 R-NR2: the words of the screen. The Zig dirs are `zig-<X.Y.Z>` dirs of the listing of `toolchains/` (a file, a lock dir, a temp dir, a compiler dir and a version with 2 or 4 numbers are no Zig), in byte order.
# The tools are `<n> (<keys>)` in the order of the file, `none` for no tool. The compilers are the count of each kind in the order nightly, release, git build, link, copy, then each Zig: the design example `4 nightlies, 1 git build, zig 0.17.0`. One is singular. No compiler is `none`.
expect {
	dir = |name| { name, is_dir: Bool.True, mtime: 0 }
	file = |name| { name, is_dir: Bool.False, mtime: 0 }
	zigs = TalonRemove.zig_versions([dir("zig-0.17.0"), dir("zig-0.16.1"), file("zig-0.15.0"), dir("zig-0.17.0.lock"), dir("zig-0.17.0.0123456789abcdef.tmp"), dir("zig-0.17"), dir("zig-x.y.z"), dir("nightly-2026-10-14-38a3029"), dir("zig-"), dir("zig-0.10.0")])
	compilers = |ids, zig| TalonRemove.describe_compilers({ ids, zigs: zig })
	rows = [
		("zig dirs, byte order", Str.join_with(zigs, " "), "0.10.0 0.16.1 0.17.0"),
		("R-RM9: the design example", compilers(["nightly-2026-10-14-38a3029", "nightly-2026-10-09-258ab27", "nightly-2026-09-01-abcdef0", "nightly-2026-08-01-abcdef1", "git-ab12cd34"], ["0.17.0"]), "4 nightlies, 1 git build, zig 0.17.0"),
		("one of each kind", compilers(["nightly-2026-10-14-38a3029", "0.4.0", "git-ab12cd34", "link-mine", "copy-fix"], ["0.17.0", "0.16.1"]), "1 nightly, 1 release, 1 git build, 1 link, 1 copy, zig 0.17.0, zig 0.16.1"),
		("2 of the kinds that are not nightlies", compilers(["0.4.0", "0.4.1", "git-a", "git-b", "link-x", "link-y", "copy-1", "copy-2"], []), "2 releases, 2 git builds, 2 links, 2 copies"),
		("only Zig", compilers([], ["0.17.0"]), "zig 0.17.0"),
		("nothing", compilers([], []), "none"),
		("no tool", TalonRemove.describe_tools([]), "none"),
		("one tool", TalonRemove.describe_tools(["foo"]), "1 (foo)"),
		("3 tools, in the order given", TalonRemove.describe_tools(["foo", "bar", "baz"]), "3 (foo, bar, baz)"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	bad == []
}

# R-RM4 R-RM7 R-RM8 R-RM9 R-RM10 R-RM1 R-NR2: the paths that one `tree_info!` measures, in the order of the groups, and the 4 parts with their sizes. The paths are: Talon, the file `tln` of the data bin dir; the tools, their files in the same dir; the compilers, each `toolchains/<id>`, each `compat-<c>` dir
# (the dirs of the compat ids that the compilers record: the compat dirs of compilers that Talon did not install are no ask: R-RM1), then each Zig dir; the Talon data: `<cache>/talon`, `config.toml`, `share.json`. `packages/` is in no ask (R-RM1). The size of a part is the sum of its paths (a path that is missing, or that `tree_info!` cannot
# read, counts 0). The detail of Talon and of the Talon data is the text of the design.
expect {
	roots = match Roots.from_env([("HOME", "/h")]) {
		Ok(found) => found
		Err(_) => crash "no roots"
	}
	asks = TalonRemove.asks({ roots, file: "tln", tools: ["foo", "bar"], ids: ["nightly-2026-10-14-38a3029", "git-ab12cd34"], compats: ["c1"], zigs: ["0.17.0"] })
	show = |list| list.map(|ask| "${Str.inspect(ask.group)} ${ask.path}")
	ok = |size| Ok({ newest: 0, size })
	infos = [ok(10), ok(11), Err(NotFound), ok(100), Err(Denied), ok(20), ok(300), ok(1000), Err(NotFound), ok(5)]
	parts = TalonRemove.parts({ asks, infos, tools: ["foo", "bar"], ids: ["nightly-2026-10-14-38a3029", "git-ab12cd34"], zigs: ["0.17.0"] })
	view = parts.map(|p| "${Str.inspect(p.group)}: ${p.detail}: ${p.size.to_str()}")
	windows_asks = TalonRemove.asks({ roots, file: "tln.exe", tools: [], ids: [], compats: [], zigs: [] })
	dbg show(asks)
	dbg view
	show(asks) == [
		"Talon /h/.local/share/talon/bin/tln",
		"Tools /h/.local/share/talon/bin/foo",
		"Tools /h/.local/share/talon/bin/bar",
		"Compilers /h/.cache/roc/toolchains/nightly-2026-10-14-38a3029",
		"Compilers /h/.cache/roc/toolchains/git-ab12cd34",
		"Compilers /h/.cache/roc/compat-c1",
		"Compilers /h/.cache/roc/toolchains/zig-0.17.0",
		"Data /h/.cache/roc/talon",
		"Data /h/.config/talon/config.toml",
		"Data /h/.local/share/talon/share.json",
	]
		and view == [
			"Talon: tln, roc, the talon entry of tools.json: 10",
			"Tools: 2 (foo, bar): 11",
			"Compilers: 1 nightly, 1 git build, zig 0.17.0: 420",
			"Data: index, x cache, compat.db, config: 1005",
		]
			and show(windows_asks).first() == Ok("Talon /h/.local/share/talon/bin/tln.exe")
}

# R-NI10 R-NR2 R-NR3 R-NM4: the screen and the prompt. The screen is the text of the design (CLI 6.5 "Remove Talon"): the question with the version, the 3 groups with their sizes (`Toolchain.size_text`: a proposal for the form of the size), the note on `roc`, the 4 options, the word `Choose`. `Prompt.text` adds the range and the default.
# The kind is Default (R-NR3): with no person, or with `--yes`, the answer is option 1 (R-RM3, R-NM8). An answer flag (`--remove-tools`, `--keep-all`) wins over `--yes` (R-NM10). A person is asked, a terminal is tested first. An empty line is option 1 (R-NM4), a number from 1 to 4 is that option, any other line asks again.
expect {
	prompt = TalonRemove.prompt({ version: "0.3.1", parts: screen_parts })
	decide = |mode, yes, flag| match Prompt.decide(prompt, { mode, yes, flag }) {
		Ask => "ask"
		NeedTty => "need-tty"
		Use(answer) => "use ${Str.inspect(answer)}"
		Stop(fail) => "stop ${fail.message}"
	}
	reply = |line| match Prompt.reply(prompt, line) {
		Ok(answer) => Str.inspect(answer)
		Err(Invalid) => "invalid"
	}
	screen = Str.join_with(
		[
			"Remove Talon 0.3.1 (tln and the roc proxy)?",
			"",
			"Talon also manages:",
			"  tools        3 (foo, bar, baz)                       42.0 MB   they run without Talon",
			"  compilers    4 nightlies, 1 git build, zig 0.17.0     1.2 GB",
			"  Talon data   index, x cache, compat.db, config      310.0 MB",
			"",
			"The roc command goes with Talon. A kept compiler stays in toolchains/<id>/roc.",
			"",
			"  1) Remove Talon, the compilers and the data. Keep the tools.   [default]",
			"  2) Remove Talon and all of the above",
			"  3) Remove Talon only",
			"  4) Cancel",
			"Choose [1-4, default 1] ",
		],
		"\n",
	)
	line_of = prompt.answer_line
	says = [
		(line_of(Option(1)), "removing Talon, the compilers and the data, keeping the tools"),
		(line_of(Option(2)), "removing Talon, the compilers, the data and the tools"),
		(line_of(Option(3)), "removing Talon only"),
		(line_of(Option(4)), "cancelled"),
	]
	rows = [
		("the screen of the design", Prompt.text(prompt), screen),
		("R-RM3: no person: option 1", decide(NonInteractive, Bool.False, Err(NoFlag)), "use Option(1)"),
		("R-RM3: --yes is option 1", decide(Interactive, Bool.True, Err(NoFlag)), "use Option(1)"),
		("--yes with no terminal", decide(NeedsTty, Bool.True, Err(NoFlag)), "use Option(1)"),
		("R-RM3: --remove-tools in CI", decide(NonInteractive, Bool.False, Ok(Option(2))), "use Option(2)"),
		("R-RM3: --keep-all in CI", decide(NonInteractive, Bool.False, Ok(Option(3))), "use Option(3)"),
		("R-NM10: the flag wins over --yes", decide(Interactive, Bool.True, Ok(Option(3))), "use Option(3)"),
		("a person is asked", decide(Interactive, Bool.False, Err(NoFlag)), "ask"),
		("the terminal is tested", decide(NeedsTty, Bool.False, Err(NoFlag)), "need-tty"),
		("the reply Enter", reply(""), "Option(1)"),
		("the reply 1", reply("1"), "Option(1)"),
		("the reply 2 with spaces", reply(" 2 "), "Option(2)"),
		("the reply 3", reply("3"), "Option(3)"),
		("the reply 4 is the cancel", reply("4"), "Option(4)"),
		("the reply 0", reply("0"), "invalid"),
		("the reply 5", reply("5"), "invalid"),
		("the reply yes", reply("yes"), "invalid"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	bad_says = says.keep_if(|(got, want)| got != want)
	dbg bad_says
	bad == [] and bad_says == []
}

# R-RM4 R-RM6 R-RM3 R-OUT2 (proposal, TW24): the lines of stdout. A table of the 4 groups with the verb, the same columns as the screen. A dry run says `remove` or `keep` for the choice and ends with `dry run: nothing was removed`. A real run says `removed` or `kept`, then one line for each compiler that
# stays (option 3: the path that the user can put on `PATH`), the move of `roc.old`, and the `PATH` entries that were removed (a profile line, or the user `Path` of Windows). A cancel is one line. The warnings on stderr: a bin dir entry that Talon kept (R-ST6), and the renamed files of Windows that stay (R-RM5).
expect {
	lines = |d| Str.join_with(TalonRemove.report(d), "")
	warns = |d| Str.join_with(TalonRemove.warnings(d), "")
	option3 = {
		..done(Removed, TalonOnly),
		stays: [{ id: "link-mine", path: "/h/src/roc/zig-out/bin/roc" }, { id: "nightly-2026-10-14-38a3029", path: "/h/.cache/roc/toolchains/nightly-2026-10-14-38a3029/roc" }],
		back: Ok({ from: "/h/.local/bin/roc.old", to: "/h/.local/bin/roc" }),
	}
	option2 = {
		..done(Removed, WithTools),
		path: [Profile("/h/.bashrc"), UserPath("C:\\Users\\a\\.local\\bin")],
		kept: ["/h/.local/bin/baz", "/h/.local/bin/roc"],
		stuck: ["/h/.local/bin/tln.0123456789abcdef.del", "/h/.local/share/talon/bin/tln.0123456789abcdef.del"],
	}
	rows = [
		("a real run, option 1", lines(done(Removed, Default)), "Talon        tln, roc, the talon entry of tools.json     9.0 MB   removed\ntools        3 (foo, bar, baz)                          42.0 MB   kept\ncompilers    4 nightlies, 1 git build, zig 0.17.0        1.2 GB   removed\nTalon data   index, x cache, compat.db, config         310.0 MB   removed\n"),
		("a dry run, option 1", lines(done(DryRun, Default)), "Talon        tln, roc, the talon entry of tools.json     9.0 MB   remove\ntools        3 (foo, bar, baz)                          42.0 MB   keep\ncompilers    4 nightlies, 1 git build, zig 0.17.0        1.2 GB   remove\nTalon data   index, x cache, compat.db, config         310.0 MB   remove\ndry run: nothing was removed\n"),
		("a dry run, option 2", lines(done(DryRun, WithTools)), "Talon        tln, roc, the talon entry of tools.json     9.0 MB   remove\ntools        3 (foo, bar, baz)                          42.0 MB   remove\ncompilers    4 nightlies, 1 git build, zig 0.17.0        1.2 GB   remove\nTalon data   index, x cache, compat.db, config         310.0 MB   remove\ndry run: nothing was removed\n"),
		("R-RM6: option 3 names each compiler that stays and moves roc.old back", lines(option3), "Talon        tln, roc, the talon entry of tools.json     9.0 MB   removed\ntools        3 (foo, bar, baz)                          42.0 MB   kept\ncompilers    4 nightlies, 1 git build, zig 0.17.0        1.2 GB   kept\nTalon data   index, x cache, compat.db, config         310.0 MB   kept\nkept link-mine: /h/src/roc/zig-out/bin/roc\nkept nightly-2026-10-14-38a3029: /h/.cache/roc/toolchains/nightly-2026-10-14-38a3029/roc\nmoved /h/.local/bin/roc.old back to /h/.local/bin/roc\n"),
		("option 2: the PATH entries", lines(option2), "Talon        tln, roc, the talon entry of tools.json     9.0 MB   removed\ntools        3 (foo, bar, baz)                          42.0 MB   removed\ncompilers    4 nightlies, 1 git build, zig 0.17.0        1.2 GB   removed\nTalon data   index, x cache, compat.db, config         310.0 MB   removed\nremoved the PATH line from /h/.bashrc\nremoved C:\\Users\\a\\.local\\bin from the user Path\n"),
		("a cancel", lines(done(Cancelled, Default)), "cancelled: nothing was removed\n"),
		("no warning", warns(done(Removed, Default)), ""),
		("R-ST6 R-RM5: the warnings", warns(option2), "warning: /h/.local/bin/baz is not a file that tln wrote, so tln keeps it\nwarning: /h/.local/bin/roc is not a file that tln wrote, so tln keeps it\nwarning: tln could not start the cleanup of 2 renamed files, so they stay: /h/.local/bin/tln.0123456789abcdef.del, /h/.local/share/talon/bin/tln.0123456789abcdef.del. A later install of Talon deletes them\n"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, _)| (label, got))
	dbg bad
	bad == []
}

# R-J3 R-J4 R-OUT4 (proposal, TW24): the `data` of `--json`. The keys in this order: `outcome`, `version`, `option` (1, 2, 3, or null for a cancel), `groups` (the 4 groups with `group`, `action` `remove` or `keep` by the table of R-RM7 to R-RM10, `detail`, `bytes`; empty for a cancel), `compilers_kept`, `roc_restored`
# (the path of `roc`, or null), `path` (the places, a profile or the text `the user Path`), `kept_entries`, `stuck`.
expect {
	render = |d| TalonRemove.data(d).render()
	small = [part(Talon, "t", 1), part(Tools, "x", 2), part(Compilers, "c", 3), part(Data, "d", 4)]
	groups = |a, b, c, d| "[{\"group\":\"talon\",\"action\":\"${a}\",\"detail\":\"t\",\"bytes\":1},{\"group\":\"tools\",\"action\":\"${b}\",\"detail\":\"x\",\"bytes\":2},{\"group\":\"compilers\",\"action\":\"${c}\",\"detail\":\"c\",\"bytes\":3},{\"group\":\"data\",\"action\":\"${d}\",\"detail\":\"d\",\"bytes\":4}]"
	option3 = {
		..done(Removed, TalonOnly),
		parts: small,
		stays: [{ id: "link-mine", path: "/h/r" }],
		back: Ok({ from: "/h/b/roc.old", to: "/h/b/roc" }),
		path: [Profile("/h/.bashrc"), UserPath("C:\\bin")],
		kept: ["/h/b/baz"],
		stuck: ["/h/b/tln.1.del"],
	}
	rows = [
		("a dry run, option 1", render({ ..done(DryRun, Default), parts: small }), "{\"outcome\":\"dry_run\",\"version\":\"0.3.1\",\"option\":1,\"groups\":${groups("remove", "keep", "remove", "remove")},\"compilers_kept\":[],\"roc_restored\":null,\"path\":[],\"kept_entries\":[],\"stuck\":[]}"),
		("a real run, option 2", render({ ..done(Removed, WithTools), parts: small }), "{\"outcome\":\"removed\",\"version\":\"0.3.1\",\"option\":2,\"groups\":${groups("remove", "remove", "remove", "remove")},\"compilers_kept\":[],\"roc_restored\":null,\"path\":[],\"kept_entries\":[],\"stuck\":[]}"),
		("option 3 with all the lists", render(option3), "{\"outcome\":\"removed\",\"version\":\"0.3.1\",\"option\":3,\"groups\":${groups("remove", "keep", "keep", "keep")},\"compilers_kept\":[{\"id\":\"link-mine\",\"path\":\"/h/r\"}],\"roc_restored\":\"/h/b/roc\",\"path\":[\"/h/.bashrc\",\"the user Path\"],\"kept_entries\":[\"/h/b/baz\"],\"stuck\":[\"/h/b/tln.1.del\"]}"),
		("a cancel", render(done(Cancelled, Default)), "{\"outcome\":\"cancelled\",\"version\":\"0.3.1\",\"option\":null,\"groups\":[],\"compilers_kept\":[],\"roc_restored\":null,\"path\":[],\"kept_entries\":[],\"stuck\":[]}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, _)| (label, got))
	dbg bad
	bad == []
}

# R-RM6 R-RM5 R-ST10 R-HF11: the small decisions of the last step. `kept_path`: the path that is printed for a compiler that stays (`toolchains/<id>/roc`), and for a link the target that its `.talon.json` records (a link has no `roc` in its dir); a link whose target cannot be read gets the dir path. When `roc.old` moved back to `roc` and the target of the link is the old path of that move (`link-system`, R-ST2), the compiler is at the new path, so that path is printed (a stale path does not help the user to put the compiler on `PATH`).
# `restores`: `roc.old` goes back when it is there and the `roc` entry is gone or was Talon's (R-RM6). A `roc` that Talon did not write stays, so `roc.old` stays where it is (R-ST6). `file`: `tln`, `tln.exe` on Windows.
# `cleanup_command`: the detached child of Windows (a proposal): `cmd.exe /d /c <script>` with the files in `TALON_DEL_<n>`, never in the script, and a loop of 30 tries one second apart.
expect {
	path = |id, link| TalonRemove.kept_path({ id, roc: "/c/toolchains/${id}/roc", link, moved: Err(None) })
	after = |id, link, from| TalonRemove.kept_path({ id, roc: "/c/toolchains/${id}/roc", link, moved: Ok({ from, to: "/h/bin/roc" }) })
	restores = |old, roc| TalonRemove.restores({ old, roc })
	three = TalonRemove.cleanup_command(["/a/roc.1.del", "/a/tln.1.del", "/d/tln.1.del"])
	one = TalonRemove.cleanup_command(["C:\\u\\tln.1.del"])
	rows = [
		("a nightly", path("nightly-2026-10-14-38a3029", Err(None)), "/c/toolchains/nightly-2026-10-14-38a3029/roc"),
		("a git build", path("git-ab12cd34", Err(None)), "/c/toolchains/git-ab12cd34/roc"),
		("a copy", path("copy-fix", Err(None)), "/c/toolchains/copy-fix/roc"),
		("a link with a target", path("link-mine", Ok("/h/src/roc")), "/h/src/roc"),
		("a link with no readable target", path("link-mine", Err(None)), "/c/toolchains/link-mine/roc"),
		("only a link has a target", path("git-ab12cd34", Ok("/h/src/roc")), "/c/toolchains/git-ab12cd34/roc"),
		("R-RM6: link-system after roc.old moved back is at roc", after("link-system", Ok("/h/bin/roc.old"), "/h/bin/roc.old"), "/h/bin/roc"),
		("a link of another target stays at its target", after("link-mine", Ok("/h/src/roc"), "/h/bin/roc.old"), "/h/src/roc"),
		("a link with no move stays at its target", path("link-system", Ok("/h/bin/roc.old")), "/h/bin/roc.old"),
		("only a link is moved with roc.old", after("git-ab12cd34", Ok("/h/bin/roc.old"), "/h/bin/roc.old"), "/c/toolchains/git-ab12cd34/roc"),
		("restores: old and roc removed", Str.inspect(restores(Bool.True, Remove)), "True"),
		("restores: old and roc gone", Str.inspect(restores(Bool.True, Gone)), "True"),
		("restores: old and a roc of the user", Str.inspect(restores(Bool.True, Keep)), "False"),
		("restores: no roc.old", Str.inspect(restores(Bool.False, Remove)), "False"),
		("restores: no roc.old, no roc", Str.inspect(restores(Bool.False, Gone)), "False"),
		("the file of Linux", TalonRemove.file(Linux), "tln"),
		("the file of macOS", TalonRemove.file(Macos), "tln"),
		("the file of Windows", TalonRemove.file(Windows), "tln.exe"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	script_three = "for /l %i in (1,1,30) do (ping -n 2 127.0.0.1 >nul & del /f /q \"%TALON_DEL_1%\" \"%TALON_DEL_2%\" \"%TALON_DEL_3%\" >nul 2>&1 & if not exist \"%TALON_DEL_1%\" if not exist \"%TALON_DEL_2%\" if not exist \"%TALON_DEL_3%\" exit /b 0)"
	script_one = "for /l %i in (1,1,30) do (ping -n 2 127.0.0.1 >nul & del /f /q \"%TALON_DEL_1%\" >nul 2>&1 & if not exist \"%TALON_DEL_1%\" exit /b 0)"
	bad == []
		and three.argv == ["cmd.exe", "/d", "/c", script_three]
			and three.env == [("TALON_DEL_1", "/a/roc.1.del"), ("TALON_DEL_2", "/a/tln.1.del"), ("TALON_DEL_3", "/d/tln.1.del")]
				and one.argv == ["cmd.exe", "/d", "/c", script_one]
					and one.env == [("TALON_DEL_1", "C:\\u\\tln.1.del")]
}
