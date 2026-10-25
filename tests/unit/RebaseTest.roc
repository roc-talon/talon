import lib.Rebase

RebaseTest :: [].{}

# Q4 of slice 006 (user answer): the glob of the files of the probe copy that `Rebase` changes. The glob is matched against the whole path, relative to the
# root of the copy. `*` does not cross `/`, `**` does, `**/` is zero or more whole segments, `?` is one character that is not `/`.
expect {
	rows = [
		# a name
		("main.roc", "main.roc", Bool.True),
		("main.roc", "sub/main.roc", Bool.False),
		("", "main.roc", Bool.False),
		# `*`: one segment, also the empty run and a name that starts with a dot
		("*.roc", "main.roc", Bool.True),
		("*.roc", ".x.roc", Bool.True),
		("*.roc", ".roc", Bool.True),
		("*.roc", "sub/main.roc", Bool.False),
		("*.roc", "main.roc.bak", Bool.False),
		("a*b*c", "aXbYc", Bool.True),
		("a*b*c", "aXbY", Bool.False),
		("sub/*/x.roc", "sub/a/x.roc", Bool.True),
		("sub/*/x.roc", "sub/x.roc", Bool.False),
		("sub/*/x.roc", "sub/a/b/x.roc", Bool.False),
		("*", "a/b", Bool.False),
		# `?`: one character, never `/`
		("a?c.roc", "abc.roc", Bool.True),
		("a?c.roc", "ac.roc", Bool.False),
		("a?c.roc", "a/c.roc", Bool.False),
		# `**`: any depth. `**/` is whole segments.
		("**", "a/b", Bool.True),
		("**/*.roc", "main.roc", Bool.True),
		("**/*.roc", "a/b/main.roc", Bool.True),
		("**/*.roc", "a/b/main.txt", Bool.False),
		("**/main.roc", "a/main.roc", Bool.True),
		("**/main.roc", "xmain.roc", Bool.False),
		("sub/**", "sub/a/b.roc", Bool.True),
		("sub/**", "sub", Bool.False),
		("sub/**", "other/a.roc", Bool.False),
	]
	bad = rows.keep_if(|(glob, path, want)| Rebase.glob_match({ glob, path }) != want)
	dbg bad
	bad == []
}

# R-LD4, R-H7: one path string of a file. The app dir of the project is /p/app, the copy is /c. A path that stays in the app dir is not changed (the copy has the
# target at the same relative place, so the errors of the baseline and of the candidate have the same file names). A path that goes above the app dir at any
# point changes its prefix: the target is absolute in the original tree, or, for a target that is in the app dir again, it is in the copy. A prefix is a whole segment.
expect {
	at = |file_dir, path| Rebase.path({ path, file_dir, from: "/p/app", to: "/c" })
	root = "/p/app"
	sub = "/p/app/sub"
	rows = [
		# unchanged: absolute, or inside
		(at(root, "/abs/x.roc"), "/abs/x.roc"),
		(at(root, "/q/../x.roc"), "/q/../x.roc"),
		(at(root, "./inner/main.roc"), "./inner/main.roc"),
		(at(root, "inner/main.roc"), "inner/main.roc"),
		(at(root, "inner/../x.roc"), "inner/../x.roc"),
		(at(sub, "../x.roc"), "../x.roc"),
		# out of the app dir: the original place
		(at(root, "../lib/main.roc"), "/p/lib/main.roc"),
		(at(root, "../../x/y.roc"), "/x/y.roc"),
		(at(root, "inner/../../lib/x.roc"), "/p/lib/x.roc"),
		(at(sub, "../../lib/x.roc"), "/p/lib/x.roc"),
		(at(root, "../app-two/x.roc"), "/p/app-two/x.roc"),
		(at(root, "../../.."), "/"),
		# out and in again: the place in the copy
		(at(root, "../app/x.roc"), "/c/x.roc"),
		(at(sub, "../../app/sub/y.roc"), "/c/sub/y.roc"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# Q1 of slice 006b (user answer: all `.roc` files): the file of an `import "<file>" as <name> : <Type>` line follows the rule of `path`. Only a line that starts with
# `import "` counts: an indented line, a comment and `import pf.Stdout` do not. All other bytes stay.
expect {
	at = |file_dir, text| Rebase.embeds({ text, file_dir, from: "/p/app", to: "/c" })
	text = |a, b, c, d|
		Str.join_with(
			[
				"module [a]",
				"",
				"import pf.Stdout",
				"import \"${a}\" as notes : Str",
				"import \"${b}\" as local : Str",
				"import \"${c}\" as back : Str",
				"  import \"../indented.txt\" as nope : Str",
				"# import \"../comment.txt\" as nope : Str",
				"x = \"import \\\"../s.txt\\\"\"",
				"import \"${d}\" as last : Str",
				"",
			],
			"\n",
		)
	rows = [
		(at("/p/app", text("../data/notes.txt", "inner/data.json", "../app/x.txt", "/abs/y.txt")), text("/p/data/notes.txt", "inner/data.json", "/c/x.txt", "/abs/y.txt")),
		(at("/p/app/sub", text("../../data/notes.txt", "../data.json", "../../app/sub/x.txt", "../z.txt")), text("/p/data/notes.txt", "../data.json", "/c/sub/x.txt", "../z.txt")),
		(at("/p/app", "module []\n"), "module []\n"),
		(at("/p/app", "import \"../a.txt\""), "import \"/p/a.txt\""),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-LD4, R-H1, R-H7: the files of the copy. The path entries of a header (also a platform entry) and the import files of each matching file change, and only the bytes of their value.
# A URL entry, the pin, the comment, the order and the rest of the body stay. A file that the glob does not match, and a file with no change, are not in the result.
expect {
	url = "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst"
	app_text = |pf, lib, inner, back, embed| Str.join_with(
		[
			"app [main!] {",
			"\tpf: platform \"${pf}\",   # keep",
			"\tlib: \"${lib}\",",
			"\tinner: \"${inner}\",",
			"\tback: \"${back}\",",
			"\tjson: \"${url}\",",
			"\troc: \"nightly-2026-10-14-38a3029\",",
			"}",
			"",
			"import \"${embed}\" as m : Str",
			"",
			"main! = |_args| Ok({})",
			"",
		],
		"\n",
	)
	package_text = |up, same| "package [Sub] { up: \"${up}\", same: \"${same}\", json: \"${url}\" }\n"
	module_text = |embed| "module [x]\n\nimport \"${embed}\" as d : Str\n\nx = d\n"
	main_in = app_text("../pf/main.roc", "../lib/main.roc", "./inner/main.roc", "../app/inner/main.roc", "../data/main.txt")
	main_out = app_text("/p/pf/main.roc", "/p/lib/main.roc", "./inner/main.roc", "/c/inner/main.roc", "/p/data/main.txt")
	sub_in = package_text("../../lib/x.roc", "../y.roc")
	sub_out = package_text("/p/lib/x.roc", "../y.roc")
	tree = [
		{ path: "main.roc", text: main_in },
		{ path: "sub/main.roc", text: sub_in },
		{ path: "Mod.roc", text: module_text("../data.txt") },
		{ path: "Plain.roc", text: module_text("inner/data.txt") },
		{ path: "notes.txt", text: "import \"../data.txt\"\n../lib/main.roc\n" },
	]
	mod_out = { path: "Mod.roc", text: module_text("/p/data.txt") }
	top = Rebase.files({ files: tree, glob: "*.roc", from: "/p/app", to: "/c" })
	deep = Rebase.files({ files: tree, glob: "**/*.roc", from: "/p/app", to: "/c" })
	one = Rebase.files({ files: tree, glob: "main.roc", from: "/p/app", to: "/c" })
	same = Rebase.files({ files: [{ path: "main.roc", text: app_text("pf/main.roc", "lib/main.roc", "./inner/main.roc", "inner/main.roc", "data/main.txt") }], glob: "main.roc", from: "/p/app", to: "/c" })
	bad = [
		(top, [{ path: "main.roc", text: main_out }, mod_out]),
		(deep, [{ path: "main.roc", text: main_out }, { path: "sub/main.roc", text: sub_out }, mod_out]),
		(one, [{ path: "main.roc", text: main_out }]),
		(same, []),
	].keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
