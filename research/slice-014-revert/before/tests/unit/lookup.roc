app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Fail
import lib.Lookup
import lib.Ref
import lib.Scope

main! = |_args| Ok({})

ent = |alias, name, note| { alias, name, note }

# The reference is parsed with the code of `Ref` (tested in `ref.roc`). The failure is one text: the stderr line and the block.
find = |scope, text, entities| match Ref.parse(text, scope, Bool.False) {
	Err(f) => Err("ref: ${Fail.line(f)}")
	Ok(ref) => match Lookup.find(scope, ref, entities) {
		Ok(found) => Ok(found)
		Err(e) => Err("${Fail.line(e.fail)}|${e.block}")
	}
}

header = [
	ent("pf", "roc-lang/basic-cli", "platform (pf)"),
	ent("json", "someone/roc-json", "json"),
	ent("parser", "lukewilliamboswell/roc-parser", "parser"),
]

# R-SC6 R-SC7 R-AD1 R-AD2 R-AD6 R-SC2: `tln add X` with no registry. A header alias names that entry (form 1).
# A full name is not looked up in the project: it is `New` (no search). A short name that is not an alias is an error:
# GitHub has no index of short names.
expect {
	rows = [
		("json", Ok(Lookup.Existing({ alias: "json", name: "someone/roc-json" }))),
		("pf", Ok(Lookup.Existing({ alias: "pf", name: "roc-lang/basic-cli" }))),
		("someone/roc-json", Ok(Lookup.New("someone/roc-json"))),
		("roc-lang/unicode", Ok(Lookup.New("roc-lang/unicode"))),
		("roc-lang/unicode@4", Ok(Lookup.New("roc-lang/unicode"))),
		("example.com/pkgs/yaml", Ok(Lookup.New("example.com/pkgs/yaml"))),
		(
			"yaml",
			Err("tln: error[usage]: 'yaml' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).|"),
		),
	]
	bad = rows.keep_if(|(text, want)| find(Scope.Install, text, header) != want).map(|(text, want)| (text, want, find(Scope.Install, text, header)))
	dbg bad
	bad == []
}

# R-SC1 R-SC6 R-SC7 R-SC8 R-SC14 R-SC15 Q12: the project scope (`update`, `remove`, `why`). The forms in order: alias, full name,
# short name (the repo name, or the repo name without a leading `roc-`). An alias wins over a short name.
# A short name must match one entity: on a tie Talon stops and lists the full names (the example of the design).
expect {
	closure = [
		ent("pf", "roc-lang/basic-webserver", "platform (pf)"),
		ent("", "someone/basic-webserver", "via web-utils"),
		ent("json", "a/yaml", "json"),
		ent("", "b/roc-json", "via yaml-tools"),
		ent("", "lukewilliamboswell/roc-parser", "via x"),
		ent("", "example.com/pkgs/parser", "via y"),
		ent("", "roc-lang/unicode", "via z"),
		ent("http1", "roc-lang/http@1", "via a"),
		ent("http2", "roc-lang/http@2", "via b"),
	]
	http_tie = "tln: error[usage]: \"roc-lang/http\" matches 2 packages. Use the full name.|\"roc-lang/http\" matches 2 packages:\n  roc-lang/http@1      via a\n  roc-lang/http@2      via b\n"
	tie = "tln: error[usage]: \"basic-webserver\" matches 2 packages. Use the full name.|\"basic-webserver\" matches 2 packages:\n  roc-lang/basic-webserver      platform (pf)\n  someone/basic-webserver       via web-utils\n"
	rows = [
		("pf", Ok(Lookup.Existing({ alias: "pf", name: "roc-lang/basic-webserver" }))),
		("someone/basic-webserver", Ok(Lookup.Existing({ alias: "", name: "someone/basic-webserver" }))),
		("json", Ok(Lookup.Existing({ alias: "json", name: "a/yaml" }))),
		("unicode", Ok(Lookup.Existing({ alias: "", name: "roc-lang/unicode" }))),
		("parser", Ok(Lookup.Existing({ alias: "", name: "lukewilliamboswell/roc-parser" }))),
		("roc-parser", Ok(Lookup.Existing({ alias: "", name: "lukewilliamboswell/roc-parser" }))),
		("basic-webserver", Err(tie)),
		# Q12 R-SC15: 2 entries of one repo (the name has `@series`). The series of the selector picks the entry.
		("roc-lang/http@2", Ok(Lookup.Existing({ alias: "http2", name: "roc-lang/http@2" }))),
		("roc-lang/http@^1.2", Ok(Lookup.Existing({ alias: "http1", name: "roc-lang/http@1" }))),
		# Q12 R-SC14: no selector, or no entry of the series, is a tie.
		("roc-lang/http", Err(http_tie)),
		("roc-lang/http@3", Err(http_tie)),
	]
	bad = rows.keep_if(|(text, want)| find(Scope.Project, text, closure) != want).map(|(text, want)| (text, want, find(Scope.Project, text, closure)))
	dbg bad
	bad == []
}

# R-SC3 R-SC4 R-AD7: `tool` and `x`. A short name must match an installed tool or an `x` cache entry. It never goes to an index.
# With no local match, and no registry, Talon stops and asks for the full name. A full name with no local match is `New`.
expect {
	tools = [ent("app", "owner/app", "tool"), ent("fmt", "owner/roc-fmt", "tool")]
	rows = [
		(Scope.Tool, "app", Ok(Lookup.Existing({ alias: "app", name: "owner/app" }))),
		(Scope.Tool, "fmt", Ok(Lookup.Existing({ alias: "fmt", name: "owner/roc-fmt" }))),
		(Scope.X, "roc-fmt", Ok(Lookup.Existing({ alias: "fmt", name: "owner/roc-fmt" }))),
		(Scope.Tool, "owner/other", Ok(Lookup.New("owner/other"))),
		(Scope.X, "owner/app", Ok(Lookup.Existing({ alias: "app", name: "owner/app" }))),
		(
			Scope.Tool,
			"other",
			Err("tln: error[usage]: 'other' matches no installed tool or cached app. Use the full name (owner/repo).|"),
		),
		(
			Scope.X,
			"other",
			Err("tln: error[usage]: 'other' matches no installed tool or cached app. Use the full name (owner/repo).|"),
		),
	]
	bad = rows.keep_if(|(scope, text, want)| find(scope, text, tools) != want).map(|(scope, text, want)| (text, want, find(scope, text, tools)))
	dbg bad
	bad == []
}
