import lib.Args
import lib.Fail
import lib.Intent
import lib.JsonDoc
import lib.RunCmd
import lib.RunFind
import lib.RunPlan
import lib.RunTools
import lib.ScriptsToml

RunscriptTest :: [].{}

# Slice 057, `tln run` and `[scripts]` (CLI 1: R-CM24, R-RUN1 to R-RUN12, R-RUN14 to R-RUN17). Part A: the pure decisions of `ScriptsToml`, `RunCmd`, `RunPlan`, `RunFind`, `RunTools.table` and the read of `Intent`.

lines = |list| "${Str.join_with(list, "\n")}\n"

h_foo10 = "GTD8yh6ExWViorE8u3JMyK9mC5b6FRuCgpd5xNhd7xtW"

foo10 = "https://github.com/acme/foo/releases/download/1.0.0/${h_foo10}.tar.zst"

# What `ScriptsToml.read` gives: one text for each script (`<name>@<line>: <steps>`), or the failure as `<code> <message>`.
read_view = |text| match ScriptsToml.read({ path: "talon.toml", text }) {
	Ok(scripts) => Ok(scripts.map(|s| "${s.name}@${s.line.to_str()}: ${Str.join_with(s.steps.map(|st| ScriptsToml.step_text(st)), " | ")}"))
	Err(e) => Err("${e.kind.code().to_str()} ${e.message}")
}

bad_name = "the key is not a script name (lower case letters, digits, ':', '_' and '-', the first one a letter or a digit, at most 64 characters)"

# R-RUN1, R-RUN14: the forms of `[scripts]`. A string is one step, an array has steps, a step is a string or the table `{ in, run }`. The scripts are in the order of their lines, a name can be quoted (`"check:wasm"`), and no table gives no script.
expect {
	text = lines([
		"[scripts]", # 1
		"build = [\"roc build main.roc\", \"roc-cfw sync\"]", # 2
		"\"check:wasm\" = \"@build\"", # 3
		"one = \"tool x\"  # a comment", # 4
		"all = [{ in = \"workers/ledger\", run = \"@build\" }, \"tool y\"]", # 5
		"solo = { in = \"d\", run = \"tool z\" }", # 6
	])
	good_names = ["a", "0x", "build:wasm", "a_b-c", "r2d2", "a:", "z"].all(|n| ScriptsToml.is_name(n))
	other_names = ["", "-a", "_a", ":a", "A", "a b", "a.b", "a/b", "é", "a".repeat(65)].any(|n| ScriptsToml.is_name(n))
	read_view(text) == Ok([
		"build@2: roc build main.roc | roc-cfw sync",
		"check:wasm@3: @build",
		"one@4: tool x",
		"all@5: in workers/ledger: @build | tool y",
		"solo@6: in d: tool z",
	])
		and read_view("[dependencies]\njson = \"^1\"\n") == Ok([])
			and good_names
				and !other_names
					and ScriptsToml.is_name("a".repeat(64))
}

# R-RUN1 (exit code 19): a form that is not valid, by line. Each failure names the script. A table step needs the strings `in` and `run` and no other key. The first failure by line is the one that is shown.
expect {
	step = "a table step needs the strings in and run, and no other key"
	read_view("scripts = 1\n") == Err("19 talon.toml:1: scripts: must be a table")
		and read_view("[scripts]\n\"Bad Name\" = \"x\"\n") == Err("19 talon.toml:2: scripts.Bad Name: ${bad_name}")
			and read_view("[scripts]\nn = 5\n") == Err("19 talon.toml:2: scripts.n: must be a step (a string, or a table with in and run) or an array of steps")
				and read_view("[scripts]\nn = [\"a\", 5]\n") == Err("19 talon.toml:2: scripts.n[2]: must be a string or a table with in and run")
					and read_view("[scripts]\nn = { in = \"x\" }\n") == Err("19 talon.toml:2: scripts.n: ${step}")
						and read_view("[scripts]\nn = { in = 1, run = \"y\" }\n") == Err("19 talon.toml:2: scripts.n: ${step}")
							and read_view("[scripts]\nn = [\"a\", { in = \"x\", run = \"y\", more = \"z\" }]\n") == Err("19 talon.toml:2: scripts.n[2]: ${step}")
								and read_view("[scripts]\nok = \"x\"\na = 1\nb = 2\n") == Err("19 talon.toml:3: scripts.a: must be a step (a string, or a table with in and run) or an array of steps")
}

# What `ScriptsToml.words` gives: the words, or the marker of a refusal.
words_view = |text| match ScriptsToml.words(text) {
	Ok(words) => words
	Err(Shell(word)) => ["SHELL", word]
	Err(Unclosed) => ["UNCLOSED"]
}

# R-RUN2: the words of a step. A space or a tab separates words. `"..."` and `'...'` quote a word. In `"..."` the escapes are `\"` and `\\` only. There is no expansion (`$HOME`, `~`, a glob). An unquoted word that is shell syntax is refused, a quoted one is a word.
expect {
	words_view("roc build  main.roc\tx") == ["roc", "build", "main.roc", "x"]
		and words_view("  a  ") == ["a"]
			and words_view("") == []
				and words_view("tool \"two words\" 'three four' end") == ["tool", "two words", "three four", "end"]
					and words_view("a \"q \\\" b \\\\ c \\n\" 'x\\y'") == ["a", "q \" b \\ c \\n", "x\\y"]
						and words_view("echo $HOME ~ *.txt $") == ["echo", "$HOME", "~", "*.txt", "$"]
							and words_view("C:\\dir\\x.exe --a=b") == ["C:\\dir\\x.exe", "--a=b"]
								and words_view("x \"\" y") == ["x", "", "y"]
									and words_view("a \"|\" \"&&\" '>' b") == ["a", "|", "&&", ">", "b"]
										and words_view("a|b c;d e>f") == ["a|b", "c;d", "e>f"]
											and words_view("a | b") == ["SHELL", "|"]
												and words_view("a && b") == ["SHELL", "&&"]
													and words_view("a || b") == ["SHELL", "||"]
														and words_view("a ; b") == ["SHELL", ";"]
															and words_view("a > out") == ["SHELL", ">"]
																and words_view("a >> out") == ["SHELL", ">>"]
																	and words_view("a < in") == ["SHELL", "<"]
																		and words_view("a &") == ["SHELL", "&"]
																			and words_view("a $(b) c") == ["SHELL", "$(b)"]
																				and words_view("a `b` c") == ["SHELL", "`b`"]
																					and words_view("a \"b") == ["UNCLOSED"]
																						and words_view("a 'b c") == ["UNCLOSED"]
																							and words_view("a \"b\\\" c") == ["UNCLOSED"]
																								and words_view("a\"b c\"d e") == ["ab cd", "e"]
																									and words_view("x 'a\"b' \"c'd\"") == ["x", "a\"b", "c'd"]
}

sc = |name, steps| { name, steps, line: 1 }

p_scripts = [
	sc("hi", [Line("tool-a one"), Line("tool-b")]),
	sc("chain", [Line("@hi"), Line("tool-c")]),
	sc("tail", [Line("tool-d"), Line("@chain")]),
	sc("lasthi", [Line("tool-c"), Line("@hi")]),
	sc("all", [In({ dir: "sub", run: "tool-e x" }), In({ dir: "sub", run: "@inner" }), Line("tool-f")]),
	sc("entry", [Line("@loop-a")]),
	sc("loop-a", [Line("x"), Line("@loop-b")]),
	sc("loop-b", [Line("@loop-a")]),
	sc("self", [Line("@self")]),
	sc("gone", [Line("@nothere")]),
	sc("sh", [Line("a"), Line("b && c")]),
	sc("out", [In({ dir: "../..", run: "z" })]),
	sc("up", [In({ dir: "..", run: "q" })]),
	sc("nofile", [In({ dir: "nodir", run: "@x" })]),
	sc("empty", []),
	sc("blank", [Line("  ")]),
	sc("unc", [Line("tool-a"), Line("tool-b \"x")]),
	sc("cx", [In({ dir: "sub", run: "@cy" })]),
]

files_sub = [
	{ dir: "/r/p", scripts: Ok(p_scripts) },
	{ dir: "/r/p/sub", scripts: Ok([sc("inner", [Line("tool-g")]), sc("cy", [In({ dir: "..", run: "@cx" })])]) },
]

# What `RunPlan.plan` gives for the script `name` of `/r/p` (the stop directory is `/r`): the steps as `<directory>: <words>`, or `need <dir>`, or the failure as `<code> <message>`.
plan_view = |files, name, args| match RunPlan.plan({ start: { dir: "/r/p", name }, args, stop: "/r", files }) {
	Ok(flat) => Str.join_with(flat.map(|f| "${f.dir}: ${Str.join_with(f.words, " ")}"), "; ")
	Err(Need(dir)) => "need ${dir}"
	Err(Stop(f)) => "${f.kind.code().to_str()} ${f.message}"
}

# R-RUN4, R-RUN8, R-RUN10, R-RUN2: the flat list of steps. `@name` is the script of the same file, with all its steps. The args of `--` go to the last step, and when it is `@name` to the last step of that script. An `in` step has its own directory, and `@name` there is the script of the file of that
# directory (the caller reads the file when the plan asks). A cycle, a missing name, a missing file, a word of shell syntax and a directory outside the repository are exit 19, and the plan is made before any step runs.
expect {
	dir_miss = [{ dir: "/r/p", scripts: Ok(p_scripts) }, { dir: "/r/p/nodir", scripts: Err(NoFile) }]
	plan_view(files_sub, "hi", []) == "/r/p: tool-a one; /r/p: tool-b"
		and plan_view(files_sub, "chain", ["x", "y"]) == "/r/p: tool-a one; /r/p: tool-b; /r/p: tool-c x y"
			and plan_view(files_sub, "tail", ["z"]) == "/r/p: tool-d; /r/p: tool-a one; /r/p: tool-b; /r/p: tool-c z"
				and plan_view(files_sub, "lasthi", ["q"]) == "/r/p: tool-c; /r/p: tool-a one; /r/p: tool-b q"
					and plan_view(files_sub, "all", []) == "/r/p/sub: tool-e x; /r/p/sub: tool-g; /r/p: tool-f"
						and plan_view(files_sub, "all", ["z"]) == "/r/p/sub: tool-e x; /r/p/sub: tool-g; /r/p: tool-f z"
							and plan_view([{ dir: "/r/p", scripts: Ok(p_scripts) }], "all", []) == "need /r/p/sub"
								and plan_view(files_sub, "up", []) == "/r: q"
									and plan_view(files_sub, "empty", ["z"]) == ""
										and plan_view(files_sub, "loop-a", []) == "19 scripts call themselves: loop-a -> loop-b -> loop-a"
											and plan_view(files_sub, "entry", []) == "19 scripts call themselves: loop-a -> loop-b -> loop-a"
												and plan_view(files_sub, "cx", []) == "19 scripts call themselves: cx -> cy (/r/p/sub) -> cx"
													and plan_view(files_sub, "nothere", []) == "19 /r/p/talon.toml: has no script 'nothere'"
														and plan_view(files_sub, "self", []) == "19 scripts call themselves: self -> self"
															and plan_view(files_sub, "gone", []) == "19 /r/p/talon.toml: script gone: the step '@nothere' names the script 'nothere', and /r/p/talon.toml has no such script"
																and plan_view(files_sub, "sh", []) == "19 /r/p/talon.toml: script sh: the step 'b && c' has the word '&&': a step is one command; use 2 steps, or a .roc script"
																	and plan_view(files_sub, "unc", []) == "19 /r/p/talon.toml: script unc: the step 'tool-b \"x' has a quote that is not closed"
																		and plan_view(files_sub, "blank", []) == "19 /r/p/talon.toml: script blank: the step '  ' has no command"
																			and plan_view(files_sub, "out", []) == "19 /r/p/talon.toml: script out: the step 'in ../..: z' has the directory '../..', which is outside the repository (/r)"
																				and plan_view(dir_miss, "nofile", []) == "19 /r/p/talon.toml: script nofile: the step 'in nodir: @x' names the script 'x', and /r/p/nodir has no talon.toml"
																					and plan_view(files_sub, "nofile", []) == "need /r/p/nodir"
}

# What `RunPlan.program` gives, as text.
program_view = |words| match RunPlan.program({ words, keys: ["roc-cfw", "fmt", "x.roc"] }) {
	Ok(Roc(args)) => "roc ${Str.join_with(args, " ")}"
	Ok(Tln(args)) => "tln ${Str.join_with(args, " ")}"
	Ok(Tool(t)) => "tool ${t.key} ${Str.join_with(t.args, " ")}"
	Ok(Path(p)) => "path ${p.program} ${Str.join_with(p.args, " ")}"
	Err(NoWords) => "none"
}

# R-RUN3, R-RUN6: the first word. `roc` and `tln` come first (the proxy and this `tln`), then a key of `[tools]`, then a word that ends with `.roc` (`roc <file> -- <other words>`, the `--` always), else a program of `PATH`.
expect {
	program_view(["roc", "build", "x.roc"]) == "roc build x.roc"
		and program_view(["tln", "install", "--frozen"]) == "tln install --frozen"
			and program_view(["roc-cfw", "sync", "--check"]) == "tool roc-cfw sync --check"
				and program_view(["fmt"]) == "tool fmt "
					and program_view(["scripts/notes.roc", "--since", "v1"]) == "roc scripts/notes.roc -- --since v1"
						and program_view(["notes.roc"]) == "roc notes.roc --"
							and program_view(["x.roc", "a"]) == "tool x.roc a"
								and program_view(["wrangler", "dev", "--local"]) == "path wrangler dev --local"
									and program_view(["./run.sh"]) == "path ./run.sh "
										and program_view([]) == "none"
											and RunPlan.program({ words: ["roc", "a"], keys: ["roc", "tln"] }) == Ok(Roc(["a"]))
												and RunPlan.program({ words: ["tln"], keys: ["roc", "tln"] }) == Ok(Tln([]))
}

# R-RUN9, R-RUN7, R-RUN11: the 2 variables of a step, the failure of a step that cannot start (exit 18), the list with no name (text and `data`) and the note for a key that is also on `PATH`.
expect {
	scripts = [sc("a", [Line("x"), In({ dir: "d", run: "@y" })]), sc("b", [])]
	failure = RunPlan.start_failed({ owner: "build", text: "tool-x --a", program: "tool-x", why: "NotFound" })
	RunPlan.env({ script: "build", dir: "/r/p/sub" }) == [("TALON_SCRIPT", "build"), ("TALON_SCRIPT_DIR", "/r/p/sub")]
		and Fail.line(failure) == "tln: error[environment]: script build: the step 'tool-x --a' cannot start 'tool-x': NotFound"
			and failure.kind.code() == 18
				and RunPlan.list_text({ file: "/r/p/talon.toml", scripts }) == "scripts of /r/p/talon.toml\na:\n  x\n  in d: @y\nb:\n"
					and JsonDoc.render(RunPlan.list_data({ file: "/r/p/talon.toml", scripts })) == "{\"file\":\"/r/p/talon.toml\",\"scripts\":[{\"name\":\"a\",\"steps\":[\"x\",\"in d: @y\"]},{\"name\":\"b\",\"steps\":[]}]}"
						and RunPlan.path_note("fmt") == "the tool key 'fmt' is also a program on PATH: inside tln run the key wins (R-RUN3)"
}

# What `Args.parse` and `RunCmd.read` give for the words after `tln`: the script and the args, or the failure as `<code> <message>`.
cmd_view = |words| match Args.parse(words) {
	Err(stop) => "${stop.fail.kind.code().to_str()} ${stop.fail.message}"
	Ok(args) => match RunCmd.read(args) {
		Ok(cmd) => {
			what = match cmd.name {
				Ok(name) => "script ${name}"
				Err(None) => "list"
			}
			"${what} args=${Str.join_with(cmd.args, ",")}"
		}
		Err(f) => "${f.kind.code().to_str()} ${f.message}"
	}
}

# R-RUN10, R-RUN11, R-FL1, R-FL6, R-FL7, R-RUN16, R-RUN17, R-CM24: the line. One name, or none (the list). The words after `--` are the args, as they are. A word after the name with no `--` is exit 2. `--json` with a name is exit 2, with no name it is the list. `--file` and the resolve flags are not flags of
# `run`. A name of a Talon command is no script name: `tln build` is an unknown command.
expect {
	cmd_view(["run"]) == "list args="
		and cmd_view(["run", "--json"]) == "list args="
			and cmd_view(["run", "build"]) == "script build args="
				and cmd_view(["run", "build", "--", "--verbose", "x y"]) == "script build args=--verbose,x y"
					and cmd_view(["run", "check:wasm", "--offline", "--yes", "--quiet"]) == "script check:wasm args="
						and cmd_view(["run", "a", "b"]) == "2 tln run takes one script name, got 2 words. Pass arguments for the script after --."
							and cmd_view(["run", "a", "--json"]) == "2 tln run a does not take --json: the steps write to stdout. Only tln run with no name does."
								and cmd_view(["run", "a", "--file", "x"]) == "2 flag '--file' is not for 'run'"
									and cmd_view(["run", "a", "--frozen"]) == "2 flag '--frozen' is not for 'run'"
										and cmd_view(["run", "--dry-run"]) == "2 flag '--dry-run' is not for 'run'"
											and cmd_view(["run", "a", "--allow-downloads"]) == "2 flag '--allow-downloads' is not for 'run'"
												and cmd_view(["run", "--", "x"]) == "2 tln run -- <words> needs a script name: the words after -- are the arguments of a script. Use tln run <name> -- <words>."
													and cmd_view(["build"]) == "2 unknown command 'build'"
														and cmd_view(["check"]) == "2 unknown command 'check'"
}

d = |dir, names| { dir, toml: Ok({ names, bad: Err(None) }) }

nod = |dir| { dir, toml: Err(None) }

# What `RunFind.find` gives: the file as `found <dir> <kind> tools=<dir> members=<files> stop=<dir>`, or `need <paths>`, or the failure as `<code> <message>`.
find_view = |name, walk, root, members, probes| match RunFind.find({ name, walk, root, members, probes }) {
	Ok(f) => {
		kind = match f.kind {
			Root => "Root"
			Member => "Member"
			Standalone => "Standalone"
		}
		"found ${f.dir} ${kind} tools=${f.tools_dir} members=${Str.join_with(f.members, ",")} stop=${f.stop}"
	}
	Err(Need(paths)) => "need ${Str.join_with(paths, ",")}"
	Err(Stop(f)) => "${f.kind.code().to_str()} ${f.message}"
}

m1 = "/r/w/m1/main.roc"

inner = "/r/w/deep/inner/main.roc"

# R-RUN12, R-RUN11, R-PD2, R-PD3, R-PD5, R-PD6, R-PD9, R-WS5 (NC2, NC4, NC5): which `talon.toml` holds the script. The walk goes up from the nearest directory. It stops after the workspace root and after the `talon.toml` of a standalone project, so a script of a file above has no effect.
# A workspace file is a file with a member file in its directory, or below it up to the next `talon.toml`: a path that may exist is asked (`need`), and the answer decides. The tools of a workspace file are the root's, the tools of a standalone file are its own. Files with a bad `[scripts]` form are exit 19 when the walk reaches them.
expect {
	ws_walk = [d("/r/w/m1", ["y"]), d("/r/w", ["x"])]
	deep_walk = [d("/r/w/deep/inner", ["di"]), d("/r/w/deep", ["dp"]), d("/r/w", ["r"])]
	probe_inner = |exists| [{ path: "/r/w/deep/inner/talon.toml", exists }]
	# no workspace: the first file with the name, the walk stops at a file with no such name
	find_view(Ok("x"), [nod("/r/a/b"), d("/r/a", ["x"]), d("/r", ["x"])], Err(NoWorkspace), [], []) == "found /r/a Standalone tools=/r/a members= stop=/r"
		and find_view(Ok("x"), [d("/r/a/b", ["y"]), d("/r/a", ["x"])], Err(NoWorkspace), [], []) == "2 no script 'x' in the talon.toml files that the walk checked: /r/a/b/talon.toml."
			# a workspace: the member file has no `x`, the root has it. A member file that has the name holds it. The root ends the walk.
			and find_view(Ok("x"), ws_walk, Ok("/r/w"), [m1], []) == "found /r/w Root tools=/r/w members=${m1} stop=/r/w"
				and find_view(Ok("y"), ws_walk, Ok("/r/w"), [m1], []) == "found /r/w/m1 Member tools=/r/w members=${m1} stop=/r/w"
					and find_view(Ok("x"), [d("/r/w", ["r"]), d("/r", ["x"])], Ok("/r/w"), [m1], []) == "2 no script 'x' in the talon.toml files that the walk checked: /r/w/talon.toml."
						# a standalone project in a workspace directory (no member file in it or below it): its own file, its own tools, and the root script has no effect there
						and find_view(Ok("y"), [d("/r/w/s", ["y"]), d("/r/w", ["x"])], Ok("/r/w"), [m1], []) == "found /r/w/s Standalone tools=/r/w/s members= stop=/r/w"
							and find_view(Ok("x"), [d("/r/w/s", ["y"]), d("/r/w", ["x"])], Ok("/r/w"), [m1], []) == "2 no script 'x' in the talon.toml files that the walk checked: /r/w/s/talon.toml."
								# NC4: `deep` has the member below it, but `deep/inner/talon.toml` is between: the answer of the probe decides
								and find_view(Ok("dp"), deep_walk, Ok("/r/w"), [inner], []) == "need /r/w/deep/inner/talon.toml"
									and find_view(Ok("dp"), deep_walk, Ok("/r/w"), [inner], probe_inner(Bool.True)) == "found /r/w/deep Standalone tools=/r/w/deep members= stop=/r/w"
										and find_view(Ok("dp"), deep_walk, Ok("/r/w"), [inner], probe_inner(Bool.False)) == "found /r/w/deep Member tools=/r/w members=${inner} stop=/r/w"
											and find_view(Ok("r"), deep_walk, Ok("/r/w"), [inner], probe_inner(Bool.True)) == "2 no script 'r' in the talon.toml files that the walk checked: /r/w/deep/inner/talon.toml, /r/w/deep/talon.toml."
												and find_view(Ok("r"), deep_walk, Ok("/r/w"), [inner], probe_inner(Bool.False)) == "found /r/w Root tools=/r/w members=${inner} stop=/r/w"
													# a bad form: exit 19 for a file that the walk examines, none for a file above the stop
													and find_view(Ok("x"), [{ dir: "/r/a", toml: Ok({ names: ["x"], bad: Ok("/r/a/talon.toml:3: scripts.x: must be a table") }) }], Err(NoWorkspace), [], []) == "19 /r/a/talon.toml:3: scripts.x: must be a table"
														and find_view(Ok("x"), [d("/r/a", ["x"]), { dir: "/r", toml: Ok({ names: [], bad: Ok("/r/talon.toml:1: scripts: must be a table") }) }], Err(NoWorkspace), [], []) == "found /r/a Standalone tools=/r/a members= stop=/r"
															# no name (the list, R-RUN11): the first file with a script
															and find_view(Err(None), [d("/r/w/m1", []), d("/r/w", ["r"])], Ok("/r/w"), [m1], []) == "found /r/w Root tools=/r/w members=${m1} stop=/r/w"
																and find_view(Err(None), [d("/r/a", ["p", "q"])], Err(NoWorkspace), [], []) == "found /r/a Standalone tools=/r/a members= stop=/r/a"
																	and find_view(Err(None), [d("/r/a/b", []), d("/r/a", ["p"])], Err(NoWorkspace), [], []) == "2 no script in the talon.toml files that the walk checked: /r/a/b/talon.toml."
																		# no file
																		and find_view(Ok("x"), [nod("/r/a"), nod("/r")], Err(NoWorkspace), [], []) == "2 no talon.toml found. Checked: /r/a, /r."
}

# What `Intent.read` gives for the warnings of a text in a role, or the failure.
warn_view = |text, role| match Intent.read({ path: "talon.toml", text, role }) {
	Ok(r) => Ok(r.warnings)
	Err(e) => Err("${e.kind.code().to_str()} ${e.message}")
}

# R-RUN14, R-RUN15, R-HK1: `[scripts]` is a known table in each role (standalone, workspace root, workspace member): the commands that read `talon.toml` (`install` and the others) print no warning for it and never look into it, so a bad `[scripts]` form is no failure of `Intent.read`
# (only `tln run` reads it). Another table that a member may not have is still exit 19 (R-WS5).
expect {
	text = lines(["[dependencies]", "json = \"^1\"", "", "[scripts]", "build = [\"roc build main.roc\", { in = \"d\", run = \"@x\" }]"])
	bad = lines(["[scripts]", "n = 5"])
	warn_view(text, Standalone) == Ok([])
		and warn_view(text, Root) == Ok([])
			and warn_view(text, Member) == Ok([])
				and warn_view(bad, Standalone) == Ok([])
					and warn_view(bad, Member) == Ok([])
						and warn_view("[workspace]\nmembers = []\n\n[scripts]\nb = \"x\"\n", Root) == Ok([])
							and warn_view("[tools]\n", Member) == Err("19 talon.toml:1: the table [tools] is not allowed in a workspace member file (it has only dependencies, overrides, patch and build)")
}

# What `RunTools.table` gives: the keys and the warnings, or the failure.
table_view = |text| match RunTools.table({ path: "talon.toml", text }) {
	Ok(t) => Ok("${Str.join_with(t.tools.map(|e| e.key), ",")}|${Str.join_with(t.warnings, ";")}")
	Err(e) => Err("${e.kind.code().to_str()} ${e.message}")
}

# R-RUN3 (point 2), R-PT1, OP4: the `[tools]` table of the file that holds the tools (the workspace root, or the standalone file): the keys, the warnings, and the first failure by line (exit 19). Other tables are not read. No table gives no key.
expect {
	text = lines(["[tools]", "roc-cfw = { ref = \"acme/foo@^1\", url = \"${foo10}\" }", "fmt = { ref = \"acme/fmt\", note = \"x\" }"])
	table_view(text) == Ok("roc-cfw,fmt|talon.toml:3: unknown key tools.fmt.note")
		and table_view("[scripts]\nb = 5\n") == Ok("|")
			and table_view("[tools]\nx = 5\ny = 6\n") == Err("19 talon.toml:2: tools.x: must be a table with ref and url")
}

# R-RUN3 (point 2), R-PT7, R-DL7 (answers Q2 and Q6 of the review): a `[tools]` key with no `url` in a step is exit 14 (not locked) and names `tln install`. The consent stop of a build in `tln run` names `--yes` and `TALON_AUTO_INSTALL=yes`, not `--allow-downloads` (`run` refuses that flag).
# Another failure stays as it is, also a consent stop of another text.
expect {
	stop = Fail.new(Consent, "the compiler nightly-2026-10-12-2664a27 is not installed. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.")
	other = Fail.new(Consent, "no consent for the download of acme/foo")
	build = Fail.new(AppError, "the build failed. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.")
	no_url = RunTools.no_url({ path: "/p/talon.toml", key: "fmt" })
	no_url.kind.code() == 14
		and no_url.message == "the [tools] of /p/talon.toml are not locked: tools.fmt has no url. Run tln install to lock them."
			and RunTools.stop(stop).message == "the compiler nightly-2026-10-12-2664a27 is not installed. Pass --yes or set TALON_AUTO_INSTALL=yes."
				and RunTools.stop(stop).kind.code() == 13
					and RunTools.stop(other).message == other.message
						and RunTools.stop(build).message == build.message
}
