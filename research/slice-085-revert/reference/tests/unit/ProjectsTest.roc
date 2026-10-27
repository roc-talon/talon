import lib.Fail
import lib.Projects

ProjectsTest :: [].{}

path = "/c/roc/talon/projects.json"

cache = "/c/roc"

# The text of a `projects.json` with the entries (path, last use), in the proposed form (R-PD12, R-TF1).
file : List((Str, U64)) -> Str
file = |entries| {
	items = Str.join_with(entries.map(|(p, t)| "{\"path\":\"${p}\",\"last_use\":${t.to_str()}}"), ",")
	"{\"format\":1,\"projects\":[${items}]}\n"
}

view = |r| match r {
	Ok(Write(text)) => Ok(Write(text))
	Ok(Unchanged) => Ok(Unchanged)
	Err(f) => Err(Fail.line(f))
}

# R-PD9 R-PD10 R-PD11 R-PD12 R-TF1 R-TF2: the new text of `projects.json` after a command read project files. An entry has
# only the path and the last use. The entries are sorted by path. A file in a temp copy (`talon/tmp/`) or in `packages/` is
# never recorded. `Always` sets the last use of an old entry. `After(86400)` (the proxy) sets it only when it is more than
# 1 day old. An unknown field stays, in its place.
expect {
	rec = |text, files, now, refresh| view(Projects.record({ path, text, cache, files, now, refresh }))
	old = file([("/w/a/main.roc", 100), ("/w/c/main.roc", 300)])
	two = file([("/w/a/main.roc", 100), ("/w/b/main.roc", 100)])
	rows = [
		("a new file", rec(Err(Missing), ["/w/a/main.roc", "/w/b/main.roc"], 100, Always), Ok(Write(two))),
		("a list that is not sorted", rec(Err(Missing), ["/w/b/main.roc", "/w/a/main.roc"], 100, Always), Ok(Write(two))),
		("the same file twice", rec(Err(Missing), ["/w/a/main.roc", "/w/a/main.roc"], 100, Always), Ok(Write(file([("/w/a/main.roc", 100)])))),
		(
			"an old entry gets the new time, a new one is added, the others stay",
			rec(Ok(old), ["/w/a/main.roc", "/w/b/main.roc"], 200, Always),
			Ok(Write(file([("/w/a/main.roc", 200), ("/w/b/main.roc", 200), ("/w/c/main.roc", 300)]))),
		),
		(
			"a temp copy and a package are not recorded",
			rec(Err(Missing), ["/c/roc/talon/tmp/0123456789abcdef/main.roc", "/c/roc/packages/h1/main.roc", "/w/a/main.roc"], 100, Always),
			Ok(Write(file([("/w/a/main.roc", 100)]))),
		),
		("only skipped files and no file: nothing to write", rec(Err(Missing), ["/c/roc/talon/tmp/0123456789abcdef/main.roc"], 100, Always), Ok(Unchanged)),
		(
			"a name that only starts like a skipped dir is recorded",
			rec(Err(Missing), ["/c/roc/talon/tmpx/a.roc", "/c/roc/packagesx/y.roc"], 100, Always),
			Ok(Write(file([("/c/roc/packagesx/y.roc", 100), ("/c/roc/talon/tmpx/a.roc", 100)]))),
		),
		("proxy: 1 day old exactly, no write", rec(Ok(old), ["/w/a/main.roc"], 100 + 86400, After(86400)), Ok(Unchanged)),
		(
			"proxy: more than 1 day old, write",
			rec(Ok(old), ["/w/a/main.roc"], 100 + 86401, After(86400)),
			Ok(Write(file([("/w/a/main.roc", 86501), ("/w/c/main.roc", 300)]))),
		),
		(
			"proxy: a new file is always written",
			rec(Ok(old), ["/w/b/main.roc"], 150, After(86400)),
			Ok(Write(file([("/w/a/main.roc", 100), ("/w/b/main.roc", 150), ("/w/c/main.roc", 300)]))),
		),
		(
			"unknown fields stay (R-TF2)",
			rec(Ok("{\"format\":1,\"projects\":[{\"path\":\"/w/a/main.roc\",\"last_use\":1,\"note\":\"x\"}],\"extra\":5}\n"), ["/w/a/main.roc"], 7, Always),
			Ok(Write("{\"format\":1,\"projects\":[{\"path\":\"/w/a/main.roc\",\"last_use\":7,\"note\":\"x\"}],\"extra\":5}\n")),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-TF3 R-TF6 R-PD12: `projects.json` cannot be made again, so a newer format and content that does not parse are failures
# (exit 19, kind input). Content that is JSON but has no array `projects` of objects with a text `path` and an integer
# `last_use` does not parse.
expect {
	rec = |text| view(Projects.record({ path, text: Ok(text), cache, files: ["/w/a/main.roc"], now: 1, refresh: Always }))
	garbage = Err("tln: error[input]: /c/roc/talon/projects.json: the content does not parse")
	rows = [
		("not JSON", rec("garbage"), garbage),
		("empty", rec(""), garbage),
		("newer format", rec("{\"format\":2,\"projects\":[]}"), Err("tln: error[input]: /c/roc/talon/projects.json: format 2 is newer than this tln (format 1). Run: tln tool update talon")),
		("no projects", rec("{\"format\":1}"), garbage),
		("projects is not a list", rec("{\"format\":1,\"projects\":{}}"), garbage),
		("an entry with no text path", rec("{\"format\":1,\"projects\":[{\"path\":1,\"last_use\":1}]}"), garbage),
		("an entry with no last use", rec("{\"format\":1,\"projects\":[{\"path\":\"/w/x\"}]}"), garbage),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PD12 R-PD13: the entries for GC, and the prune of entries that protect nothing: a path that is not in `valid` (the file
# is missing or has no header, found by GC or R-RR2), and, for GC, an entry whose last use is older than the GC age.
# `tln cache clean` keeps the list: it does not call `prune`.
expect {
	text = file([("/w/a", 100), ("/w/b", 5000), ("/w/c", 200)])
	prune = |max_age, valid| Projects.prune({ path, text, now: 10000, max_age, valid }).map_err(|f| Fail.line(f))
	rows = [
		(
			"a path that is not valid leaves",
			prune(Err(NoLimit), ["/w/a", "/w/c"]),
			Ok({ text: file([("/w/a", 100), ("/w/c", 200)]), removed: ["/w/b"] }),
		),
		(
			"GC age: older than the age leaves",
			prune(Ok(9000), ["/w/a", "/w/b", "/w/c"]),
			Ok({ text: file([("/w/b", 5000)]), removed: ["/w/a", "/w/c"] }),
		),
		(
			"exactly the GC age stays",
			prune(Ok(9900), ["/w/a", "/w/b", "/w/c"]),
			Ok({ text: file([("/w/a", 100), ("/w/b", 5000), ("/w/c", 200)]), removed: [] }),
		),
		(
			"nothing leaves: the same text",
			prune(Err(NoLimit), ["/w/a", "/w/b", "/w/c"]),
			Ok({ text, removed: [] }),
		),
		("an invalid path and an old entry: the paths are sorted", prune(Ok(9000), ["/w/c"]), Ok({ text: file([]), removed: ["/w/a", "/w/b", "/w/c"] })),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	listed = Projects.entries({ path, text }).map_err(|f| Fail.line(f))
	dbg (bad, listed)
	bad == [] and listed == Ok([{ path: "/w/a", last_use: 100 }, { path: "/w/b", last_use: 5000 }, { path: "/w/c", last_use: 200 }])
}
