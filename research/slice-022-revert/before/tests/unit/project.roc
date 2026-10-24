app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Fail
import lib.Project

main! = |_args| Ok({})

ws = "[workspace]\nmembers = [\"apps/*/main.roc\", \"examples/*.roc\"]\n"

dep = "[dependencies]\njson = \"^2\"\n"

# One directory of a walk: the path, the entry names and the text of its `talon.toml`.
d = |dir, names, toml| { dir, names, toml }

root_d = d("/r", [".git", "main.roc", "talon.toml"], Ok(ws))

members4 = ["/r/apps/a/main.roc", "/r/apps/b/main.roc", "/r/examples/hello.roc", "/r/examples/other.roc"]

workspace = Ok({ root: "/r", members: members4 })

# The failure is one text (the stderr line): see the compiler limit in slice 001.
shown = |r| match r {
	Ok(p) => Ok((p.file, p.workspace, p.toml))
	Err(f) => Err(Fail.line(f))
}

# R-PD1 R-PD2: the path helpers of the walk. `parent` ends at `/`. `absolute` joins a relative path to the current
# directory (`--file` is relative to it) and cleans `.` and `..`. The walk stops after a directory with `.git` (a
# directory or a file) or at the home directory.
expect {
	parents = [
		(Project.parent("/a/b"), Ok("/a")),
		(Project.parent("/a"), Ok("/")),
		(Project.parent("/"), Err(AtRoot)),
	]
	abs = [
		(Project.absolute({ base: "/p/q", path: "main.roc" }), "/p/q/main.roc"),
		(Project.absolute({ base: "/p/q", path: "../x/y.roc" }), "/p/x/y.roc"),
		(Project.absolute({ base: "/p/q", path: "./a//b/../c.roc" }), "/p/q/a/c.roc"),
		(Project.absolute({ base: "/p/q", path: "/abs/z.roc" }), "/abs/z.roc"),
		(Project.absolute({ base: "/p/q", path: "../../../../r" }), "/r"),
		(Project.absolute({ base: "/", path: "a" }), "/a"),
		(Project.absolute({ base: "/p/q/", path: "a/" }), "/p/q/a"),
	]
	stops = [
		(Project.stops({ dir: "/r", names: [".git", "main.roc"], home: "/h" }), Bool.True),
		(Project.stops({ dir: "/r", names: ["main.roc"], home: "/r" }), Bool.True),
		(Project.stops({ dir: "/r", names: ["main.roc", ".gitignore", ".github"], home: "/h" }), Bool.False),
		(Project.stops({ dir: "/r/sub", names: [], home: "/r" }), Bool.False),
	]
	bad_parents = parents.keep_if(|(got, want)| got != want)
	bad_abs = abs.keep_if(|(got, want)| got != want)
	bad_stops = stops.keep_if(|(got, want)| got != want)
	dbg (bad_parents, bad_abs, bad_stops)
	bad_parents == [] and bad_abs == [] and bad_stops == []
}

# R-PD3 R-TF4: the `[workspace]` table of a `talon.toml`. No table: `NoWorkspace`. Text that is not TOML, or a `members`
# that is not a list of strings: an error with the 1-based line and a fixed message. Question Q4: `[workspace]`
# with no `members` key is not tested.
expect {
	view = |r| match r {
		Ok(table) => Ok(table)
		Err(e) => Err((e.line, e.message))
	}
	rows = [
		("", Ok(Err(NoWorkspace))),
		("[dependencies]\njson = \"^2\"\n", Ok(Err(NoWorkspace))),
		(ws, Ok(Ok(["apps/*/main.roc", "examples/*.roc"]))),
		("# a comment\n[resolution]\nstrategy = \"highest\"\n\n[workspace]\nmembers = []\n", Ok(Ok([]))),
		("[workspace\nmembers = []\n", Err((1, "not valid TOML"))),
		("[workspace]\nmembers = 5\n", Err((2, "the key workspace.members must be a list of strings"))),
		("[dependencies]\n[workspace]\nmembers = [\"a\", 1]\n", Err((3, "the key workspace.members must be a list of strings"))),
	]
	bad = rows.keep_if(|(text, want)| view(Project.workspace_of(text)) != want).map(|(text, want)| (text, want, view(Project.workspace_of(text))))
	dbg bad
	bad == []
}

# R-PD3 R-PD2 R-TF4: the workspace root of a walk is the nearest directory with a `[workspace]` table. The files are read
# nearest first, and the read stops at the root: a `talon.toml` above the root is never read. A bad `talon.toml` that is
# read first is a failure of kind `input` (exit 19) with `<dir>/talon.toml:<line>:`.
expect {
	view = |r| match r {
		Ok(Ok(root)) => Ok(Ok((root.dir, root.patterns)))
		Ok(Err(NoWorkspace)) => Ok(Err(NoWorkspace))
		Err(f) => Err(Fail.line(f))
	}
	patterns = ["apps/*/main.roc", "examples/*.roc"]
	rows = [
		(
			"the root is found above a member",
			[d("/r/apps/a", ["main.roc", "talon.toml"], Ok(dep)), d("/r/apps", ["a"], Err(None)), root_d],
			Ok(Ok(("/r", patterns))),
		),
		(
			"the nearest workspace wins",
			[d("/r/apps", ["talon.toml"], Ok("[workspace]\nmembers = [\"*/main.roc\"]\n")), root_d],
			Ok(Ok(("/r/apps", ["*/main.roc"]))),
		),
		(
			"a bad talon.toml above the root is never read",
			[root_d, d("/", ["talon.toml"], Ok("[workspace\n"))],
			Ok(Ok(("/r", patterns))),
		),
		(
			"no workspace",
			[d("/s/app", ["main.roc", "talon.toml"], Ok(dep)), d("/s", [".git"], Err(None))],
			Ok(Err(NoWorkspace)),
		),
	]
	bad = rows.keep_if(|(_, walk, want)| view(Project.root_of({ walk: walk })) != want).map(|(label, walk, want)| (label, want, view(Project.root_of({ walk: walk }))))
	dbg bad
	failure = match Project.root_of({ walk: [d("/r/x", ["talon.toml"], Ok("[workspace\n")), root_d] }) {
		Err(f) => Fail.line(f).starts_with("tln: error[input]: /r/x/talon.toml:1: not valid TOML")
		Ok(_) => Bool.False
	}
	bad == [] and failure
}

# R-PD1 R-PD4 R-PD5 R-PD6 R-TF4: the choice of the project with no `--file`. Walk is nearest first. The rows show
# (the project file, the workspace, the `talon.toml`).
expect {
	rows = [
		(
			"standalone, its own talon.toml",
			[d("/s/app", ["main.roc", "talon.toml"], Ok(dep)), d("/s", [".git"], Err(None))],
			[],
			Ok((Ok("/s/app/main.roc"), Err(Standalone), Ok("/s/app/talon.toml"))),
		),
		(
			"the main.roc of a parent directory",
			[d("/s/app/src", ["x.roc"], Err(None)), d("/s/app", ["main.roc"], Err(None)), d("/s", [".git"], Err(None))],
			[],
			Ok((Ok("/s/app/main.roc"), Err(Standalone), Err(NoToml))),
		),
		(
			"the talon.toml of a parent directory is another intent (R-PD6)",
			[d("/s/app", ["main.roc"], Err(None)), d("/s", [".git", "talon.toml"], Ok(dep))],
			[],
			Ok((Ok("/s/app/main.roc"), Err(Standalone), Err(NoToml))),
		),
		(
			"a member, from its own directory: its own talon.toml",
			[d("/r/apps/a", ["main.roc", "talon.toml"], Ok(dep)), d("/r/apps", ["a", "b"], Err(None)), root_d],
			members4,
			Ok((Ok("/r/apps/a/main.roc"), workspace, Ok("/r/apps/a/talon.toml"))),
		),
		(
			"a member with no talon.toml: the root one is the nearest",
			[d("/r/apps/b", ["main.roc"], Err(None)), d("/r/apps", ["a", "b"], Err(None)), root_d],
			members4,
			Ok((Ok("/r/apps/b/main.roc"), workspace, Ok("/r/talon.toml"))),
		),
		(
			"a member, from a directory below it",
			[d("/r/apps/b/src", ["x.roc"], Err(None)), d("/r/apps/b", ["main.roc", "src"], Err(None)), d("/r/apps", ["a", "b"], Err(None)), root_d],
			members4,
			Ok((Ok("/r/apps/b/main.roc"), workspace, Ok("/r/talon.toml"))),
		),
		(
			"no member and a workspace: the workspace with no current member",
			[d("/r/docs", ["notes.txt"], Err(None)), root_d],
			members4,
			Ok((Err(NoCurrent), workspace, Ok("/r/talon.toml"))),
		),
		(
			"at the root only member files count: its main.roc is not a member",
			[root_d],
			members4,
			Ok((Err(NoCurrent), workspace, Ok("/r/talon.toml"))),
		),
		(
			"a main.roc that is not a member is standalone, also inside a workspace directory (R-PD5)",
			[d("/r/tools", ["main.roc", "talon.toml"], Ok(dep)), root_d],
			members4,
			Ok((Ok("/r/tools/main.roc"), Err(Standalone), Ok("/r/tools/talon.toml"))),
		),
		(
			"2 member files in one directory",
			[d("/r/examples", ["hello.roc", "other.roc"], Err(None)), root_d],
			members4,
			Err("tln: error[usage]: /r/examples has 2 member files: /r/examples/hello.roc, /r/examples/other.roc. Pass --file <path>."),
		),
		(
			"one member file in the directory: it is the project file",
			[d("/r/examples", ["hello.roc", "other.roc"], Err(None)), root_d],
			["/r/apps/a/main.roc", "/r/examples/hello.roc"],
			Ok((Ok("/r/examples/hello.roc"), Ok({ root: "/r", members: ["/r/apps/a/main.roc", "/r/examples/hello.roc"] }), Ok("/r/talon.toml"))),
		),
		(
			"no project file and no workspace",
			[d("/e/sub", ["x.txt"], Err(None)), d("/e", [".git"], Err(None))],
			[],
			Err("tln: error[usage]: no project file found. Checked: /e/sub, /e. Pass --file <path>."),
		),
	]
	bad = rows.keep_if(|(_, walk, members, want)| shown(Project.find({ file: Err(Unset), walk, members })) != want).map(|(label, walk, members, want)| (label, want, shown(Project.find({ file: Err(Unset), walk, members }))))
	dbg bad
	failure = match Project.find({ file: Err(Unset), walk: [d("/b", ["main.roc", "talon.toml"], Ok("[workspace\n"))], members: [] }) {
		Err(f) => Fail.line(f).starts_with("tln: error[input]: /b/talon.toml:1: not valid TOML")
		Ok(_) => Bool.False
	}
	bad == [] and failure
}

# R-PD1 R-PD5 R-PD6: with `--file` that file is the project file. It is a member when the root has it in its members,
# else it is standalone (also inside a workspace). A standalone file uses the talon.toml of its own directory, when that
# file has no `[workspace]` table.
expect {
	rows = [
		(
			"a member file, also when its directory has 2 member files",
			"/r/examples/hello.roc",
			[d("/r/examples", ["hello.roc", "other.roc"], Err(None)), root_d],
			Ok((Ok("/r/examples/hello.roc"), workspace, Ok("/r/talon.toml"))),
		),
		(
			"a member with its own talon.toml",
			"/r/apps/a/main.roc",
			[d("/r/apps/a", ["main.roc", "talon.toml"], Ok(dep)), d("/r/apps", ["a", "b"], Err(None)), root_d],
			Ok((Ok("/r/apps/a/main.roc"), workspace, Ok("/r/apps/a/talon.toml"))),
		),
		(
			"a file that is not a member, deep in the workspace",
			"/r/apps/b/src/x.roc",
			[d("/r/apps/b/src", ["x.roc"], Err(None)), d("/r/apps/b", ["main.roc", "src"], Err(None)), d("/r/apps", ["a", "b"], Err(None)), root_d],
			Ok((Ok("/r/apps/b/src/x.roc"), Err(Standalone), Err(NoToml))),
		),
		(
			"the main.roc of the root directory is not a member: the root talon.toml has [workspace] so it is not its toml",
			"/r/main.roc",
			[root_d],
			Ok((Ok("/r/main.roc"), Err(Standalone), Err(NoToml))),
		),
		(
			"a standalone file with its own talon.toml, inside a workspace directory",
			"/r/tools/main.roc",
			[d("/r/tools", ["main.roc", "talon.toml"], Ok(dep)), root_d],
			Ok((Ok("/r/tools/main.roc"), Err(Standalone), Ok("/r/tools/talon.toml"))),
		),
		(
			"a file with no workspace and no talon.toml",
			"/o/x.roc",
			[d("/o", ["x.roc"], Err(None))],
			Ok((Ok("/o/x.roc"), Err(Standalone), Err(NoToml))),
		),
	]
	run = |file, walk| shown(Project.find({ file: Ok(file), walk, members: members4 }))
	bad = rows.keep_if(|(_, file, walk, want)| run(file, walk) != want).map(|(label, file, walk, want)| (label, want, run(file, walk)))
	dbg bad
	bad == []
}

# R-PD8 R-TF5: the header of the project file. An app, a package and a platform header are accepted (the platform text is
# the head of the header of basic-cli 0.25.0). A file with no header (a module, or an app with no header) is a usage
# failure (exit 2). A header that does not parse is an input failure (exit 19) with the file and the 1-based line.
expect {
	pf_header = "## A native platform.\nplatform \"\"\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])\n\t}\n\texposes [Cmd, Env, Path]\n\tpackages {\n\t\t# the shared types\n\t\thttp: \"https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst\",\n\t}\n\tprovides { \"roc_main\": main_for_host! }\n\thosted {\n\t\t\"hosted_cmd_run\": Host.cmd_run!,\n\t}\n"
	check = |text| Project.check_header({ path: "/p/main.roc", text }).map_err(|f| Fail.line(f))
	rows = [
		("app [main!] { pf: platform \"https://example.com/pf/1.0.0/HASH.tar.zst\" }\n\nmain! = |_| Ok({})\n", Ok(App)),
		("# a comment\n\napp [main!] {\n\tpf: platform \"https://example.com/pf/1.0.0/HASH.tar.zst\",\n}\n", Ok(App)),
		("package [Parser, Utf8] {}\n", Ok(Package)),
		(pf_header, Ok(Platform)),
		("module [helper]\n\nhelper = 1\n", Err("tln: error[usage]: /p/main.roc has no app, package or platform header")),
		("main! = |_| Ok({})\n", Err("tln: error[usage]: /p/main.roc has no app, package or platform header")),
		("", Err("tln: error[usage]: /p/main.roc has no app, package or platform header")),
		("# note\n\napp [main!] { pf: oops }\nmain! = |_| Ok({})\n", Err("tln: error[input]: /p/main.roc:3: the header is not valid")),
	]
	bad = rows.keep_if(|(text, want)| check(text) != want).map(|(text, want)| (text, want, check(text)))
	dbg bad
	bad == []
}
