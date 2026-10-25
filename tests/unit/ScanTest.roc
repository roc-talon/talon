import lib.Scan

ScanTest :: [].{}

# R-RV2 R-LD7 (slice 008, Q5 of the manager): the file of a local import, and the files where the scan starts.
# `import Foo` and `import A/B` are relative to the project dir. `./X` and `../X` are relative to the importing file. The path has no `..`, also when it leaves the project dir.
# An app starts at its project file. A package or a platform starts at each module that its header exposes (the entry points `main!` of an app are no module).
expect {
	at = |file, name| Scan.local_file({ project_dir: "/p/app", file, name })
	files = [
		("a bare name", at("/p/app/main.roc", "Foo"), "/p/app/Foo.roc"),
		("a bare name, imported from a subdir: still the project dir", at("/p/app/sub/X.roc", "Foo"), "/p/app/Foo.roc"),
		("a subdirectory", at("/p/app/sub/X.roc", "A/B"), "/p/app/A/B.roc"),
		("./ from the project file", at("/p/app/main.roc", "./A/B"), "/p/app/A/B.roc"),
		("./ from a file in a subdir", at("/p/app/sub/Y.roc", "./X"), "/p/app/sub/X.roc"),
		("../ from a subdir", at("/p/app/sub/Y.roc", "../X"), "/p/app/X.roc"),
		("../../ from 2 levels down", at("/p/app/sub/deep/Z.roc", "../../X"), "/p/app/X.roc"),
		("../ out of the project dir", at("/p/app/main.roc", "../Shared/Codec"), "/p/Shared/Codec.roc"),
	]
	bad_files = files.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_files

	roots = |kind, exposed| Scan.roots({ kind, file: "/p/lib/main.roc", exposed })
	starts = [
		("an app starts at its file", roots(App, ["main!"]), ["/p/lib/main.roc"]),
		("a package starts at each exposed module", roots(Package, ["Parser", "Yaml"]), ["/p/lib/Parser.roc", "/p/lib/Yaml.roc"]),
		("a platform starts at each exposed module", roots(Platform, ["Stdout"]), ["/p/lib/Stdout.roc"]),
		("a package that exposes nothing", roots(Package, []), []),
	]
	bad_starts = starts.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_starts
	bad_files == [] and bad_starts == []
}

main_text = "app [main!] { pf: platform \"https://example.com/pf.tar.zst\", json: \"https://example.com/json.tar.zst\" }\n\nimport pf.Stdout\nimport json.Json\nimport json.Json.ParseErr as PE\nimport jsonx.Other\nimport Helpers\nimport ./Util/Strs\nimport Helpers\nimport \"data.json\" as data : Str\n# import json.Commented\n\nmain! = |_| Ok({})\n"

# R-RV2 (slice 008): one level of the scan. A hit is an import line of the alias, an exact match: `jsonx` and `pf` are other aliases, a comment and a file import are no import.
# A hit has the file, the line number and the text of the line (with no line end, also for a CRLF text). The next files are the local imports that are not seen yet, with no repeat, in
# the order of the first import. A file of this level, or one that the scan has read, is not next again.
expect {
	run = |alias, sources, seen| Scan.level({ alias, project_dir: "/p/app", sources, seen })
	main = { path: "/p/app/main.roc", text: main_text }
	helpers = { path: "/p/app/Helpers.roc", text: "import json.Json as J\r\nimport ../Shared/Codec\r\nimport Util/Strs\r\n" }
	first = run("json", [main], ["/p/app/main.roc"])
	first_want = {
		hits: [
			{ file: "/p/app/main.roc", line: 4, text: "import json.Json" },
			{ file: "/p/app/main.roc", line: 5, text: "import json.Json.ParseErr as PE" },
		],
		next: ["/p/app/Helpers.roc", "/p/app/Util/Strs.roc"],
	}
	seen_one = run("json", [main], ["/p/app/main.roc", "/p/app/Helpers.roc"])
	seen_one_want = { hits: first_want.hits, next: ["/p/app/Util/Strs.roc"] }
	two = run("json", [main, helpers], ["/p/app/main.roc", "/p/app/Helpers.roc"])
	two_want = {
		hits: [
			{ file: "/p/app/main.roc", line: 4, text: "import json.Json" },
			{ file: "/p/app/main.roc", line: 5, text: "import json.Json.ParseErr as PE" },
			{ file: "/p/app/Helpers.roc", line: 1, text: "import json.Json as J" },
		],
		next: ["/p/app/Util/Strs.roc", "/p/Shared/Codec.roc"],
	}
	not_in_seen = run("json", [main, helpers], ["/p/app/main.roc"])
	not_in_seen_want = { hits: two_want.hits, next: ["/p/app/Util/Strs.roc", "/p/Shared/Codec.roc"] }
	other = run("pf", [main], ["/p/app/main.roc"])
	other_want = { hits: [{ file: "/p/app/main.roc", line: 3, text: "import pf.Stdout" }], next: first_want.next }
	none = run("http", [main], ["/p/app/main.roc"])
	none_want = { hits: [], next: first_want.next }
	done = run("json", [{ path: "/p/app/Util/Strs.roc", text: "main = 1\n" }], ["/p/app/main.roc", "/p/app/Util/Strs.roc"])
	done_want = { hits: [], next: [] }
	rows = [
		("the project file: 2 hits, 2 next files, a repeat once", first, first_want),
		("a seen file is not next", seen_one, seen_one_want),
		("2 files of one level: the order, a CRLF line, a file out of the project dir", two, two_want),
		("a file of this level is not next, also when `seen` lacks it", not_in_seen, not_in_seen_want),
		("another alias gives its own line", other, other_want),
		("an alias that no line names", none, none_want),
		("a file with no import ends the scan", done, done_want),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
