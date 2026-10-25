app [main!] { lib: "../../cli/lib/main.roc" }

import lib.JsonDoc
import lib.PathRoc

main! = |_args| Ok({})

# Slice 022b (R-SO9, R-TF1 to R-TF3, R-TF6). The expected value of each row is the design text or the slice file text, not the code. A wrong row prints with `dbg`.
# The file text of `path-roc.json` and the warning are proposals of docs/slices/022b-launcher-test.md (TW24).

# The running tln has size 100. A file of size 100 can be the launcher, a file of any other size cannot.
exe : PathRoc.File
exe = { path: "/t/tln", size: 100, mtime: 1 }

# `f1` and `f3` have the size of tln. `f2` has another size.
f1 : PathRoc.File
f1 = { path: "/a/roc", size: 100, mtime: 5 }

f2 : PathRoc.File
f2 = { path: "/b/roc", size: 7, mtime: 6 }

f3 : PathRoc.File
f3 = { path: "/c/roc", size: 100, mtime: 7 }

# Another size than tln, a binary that is not a compiler.
f4 : PathRoc.File
f4 = { path: "/d/roc", size: 9, mtime: 8 }

# A field that Talon does not know (R-TF2), as a row and as a top field.
row_x = JsonDoc.Arr([JsonDoc.Num(1)])

top_note = JsonDoc.Text("keep")

# The file text of a state with no unknown field.
doc : List(PathRoc.Entry) -> { entries : List(PathRoc.Entry), extra : List((Str, JsonDoc)) }
doc = |entries| { entries, extra: [] }

nightly = "nightly-2026-10-14-38a3029"

# One row of the cache for `file`.
row : PathRoc.File, Try(Str, [None]), [NotRun, NoId, Id(Str)] -> PathRoc.Entry
row = |file, sha256, id| { path: file.path, size: file.size, mtime: file.mtime, sha256, id, extra: [] }

sha_t = "tttt"

sha_a = "aaaa"

sha_b = "bbbb"

# A row of the launcher (tln itself) with its sha256.
exe_row : PathRoc.Entry
exe_row = row(exe, Ok(sha_t), NotRun)

# R-SO9: the walk over the `roc` files of `PATH`. `step` gives the next effect, or the result. The first file that is not the launcher is the compiler.
expect {
	run = |found, entries| PathRoc.step({ exe: Ok(exe), found, entries })
	rows = [
		("no roc on PATH", run([], []), Done(Err(NoCompiler))),
		# A file with another size than tln is never hashed: it is the compiler, so `roc version` runs.
		("size differs: no hash, run roc version", run([f2], []), Version(f2)),
		("size differs: the id is in the row", run([f2], [row(f2, Err(None), Id(nightly))]), Done(Ok(nightly))),
		("a release id", run([f2], [row(f2, Err(None), Id("0.1.0"))]), Done(Ok("0.1.0"))),
		# R-SO11: a local build is no compiler for rank 7, and the id is in the row so `roc version` does not run again.
		("local build id", run([f2], [row(f2, Err(None), Id("debug-1a2b3c4"))]), Done(Err(NoCompiler))),
		# R-SO9: `roc version` ran once and gave no id (`NoId`): it does not run again for this file. The mtime key still applies.
		("ran with no id: no second run", run([f2], [row(f2, Err(None), NoId)]), Done(Err(NoCompiler))),
		("ran with no id, the file changed: run again", run([f2], [row({ ..f2, mtime: 9 }, Err(None), NoId)]), Version(f2)),
		("the launcher first, then a file that ran with no id", run([f1, f2], [row(f1, Ok(sha_t), NotRun), exe_row, row(f2, Err(None), NoId)]), Done(Err(NoCompiler))),
		# The key of a row is the path, the size and the mtime: a change in one of them makes the row useless.
		("mtime differs: run again", run([f2], [row({ ..f2, mtime: 9 }, Err(None), Id(nightly))]), Version(f2)),
		("size differs from the row: run again", run([f2], [row({ ..f2, size: 8 }, Err(None), Id(nightly))]), Version(f2)),
		("the row is of another path: run", run([f2], [row({ ..f2, path: "/x/roc" }, Err(None), Id(nightly))]), Version(f2)),
		# The launcher test: same size, then the sha256 of the file first, then the sha256 of tln.
		("same size: hash the file", run([f1], []), Hash(f1)),
		("same size, the file has its sha256: hash tln", run([f1], [row(f1, Ok(sha_a), NotRun)]), Hash(exe)),
		("the row of tln is old (mtime): hash tln again", run([f1], [row(f1, Ok(sha_a), NotRun), row({ ..exe, mtime: 2 }, Ok(sha_t), NotRun)]), Hash(exe)),
		("the row of the file is old (mtime): hash the file again", run([f1], [row({ ..f1, mtime: 4 }, Ok(sha_t), NotRun), exe_row]), Hash(f1)),
		# Equal sha256: the file is the launcher. The only file: there is no compiler.
		("the only file is the launcher", run([f1], [row(f1, Ok(sha_t), NotRun), exe_row]), Done(Err(NoCompiler))),
		("the launcher first, then a compiler", run([f1, f2], [row(f1, Ok(sha_t), NotRun), exe_row]), Version(f2)),
		("the launcher first, then a compiler with its id", run([f1, f2], [row(f1, Ok(sha_t), NotRun), exe_row, row(f2, Err(None), Id(nightly))]), Done(Ok(nightly))),
		# A file of the size of tln with other bytes (an old copy of a launcher) is not the launcher: it is the compiler.
		("same size, other sha256: the compiler", run([f1, f2], [row(f1, Ok(sha_a), NotRun), exe_row]), Version(f1)),
		# The walk goes on to the next file with the size of tln, and the walk stops at the first compiler.
		("a second file of the size of tln", run([f1, f3, f2], [row(f1, Ok(sha_t), NotRun), exe_row]), Hash(f3)),
		("the first compiler wins", run([f2, f1], []), Version(f2)),
		("two launchers, then none", run([f1, f3], [row(f1, Ok(sha_t), NotRun), row(f3, Ok(sha_t), NotRun), exe_row]), Done(Err(NoCompiler))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SO9: the walk as command code runs it. Each file is hashed once and `roc version` runs once for each binary, also across 2 commands (the second one reads the rows that the first wrote).
# `hash_of` and `text_of` stand for `Fx.sha256_file!` and `Fx.spawn_all!`. The log has one word for each effect.
expect {
	hash_of = |path| if path == "/t/tln" sha_t else if path == "/a/roc" sha_t else sha_a
	text_of = |path| if path == "/b/roc" "Roc compiler version ${nightly}\n" else "not a version"
	walk = |found, entries0| {
		var $entries = entries0
		var $log = []
		var $result = Err(NoCompiler)
		var $done = Bool.False
		for _ in (0.U64).until(8) {
			if !$done {
				match PathRoc.step({ exe: Ok(exe), found, entries: $entries }) {
					Hash(file) => {
						$log = $log.append("hash ${file.path}")
						$entries = PathRoc.add_sha($entries, file, hash_of(file.path))
					}
					Version(file) => {
						$log = $log.append("version ${file.path}")
						finished = PathRoc.finish({ entries: $entries, file, text: text_of(file.path) })
						$entries = finished.entries
						$result = finished.id
						$done = Bool.True
					}
					Done(id) => {
						$result = id
						$done = Bool.True
					}
				}
			}
		}
		{ log: $log, id: $result, entries: $entries }
	}
	first = walk([f1, f2], [])
	second = walk([f1, f2], first.entries)
	bad_first = walk([f4], [])
	bad_second = walk([f4], bad_first.entries)
	# The launcher is hashed with tln (file first, then tln), and a file of another size is not hashed.
	checks = [
		("first run: the log", first.log == ["hash /a/roc", "hash /t/tln", "version /b/roc"]),
		("first run: the id", first.id == Ok(nightly)),
		("second run: no hash and no roc version", second.log == []),
		("second run: the id", second.id == Ok(nightly)),
		("second run: the rows are the same", second.entries == first.entries),
		# R-SO9: a binary that is not a compiler runs once too. The row says that it ran, so the second command does not run it.
		("not a compiler, first run: one roc version, no id", bad_first.log == ["version /d/roc"] and bad_first.id == Err(NoCompiler)),
		("not a compiler, second run: no roc version, no id", bad_second.log == [] and bad_second.id == Err(NoCompiler)),
	]
	bad = checks.keep_if(|(_, ok)| !ok).map(|(label, _)| label)
	dbg (bad, first.log, second.log, bad_first.log, bad_second.log)
	bad == []
}

# R-SO9, R-SO10, R-SO11: the rows after a hash, and after `roc version`. One row for each path. A row of an older file (other size or mtime) is replaced, and its id goes with it.
expect {
	text = "Roc compiler version ${nightly}\n"
	after_sha = PathRoc.add_sha([], f1, sha_a)
	replaced = PathRoc.add_sha([row({ ..f1, mtime: 4 }, Ok(sha_b), Id(nightly)), row(f2, Err(None), Id("0.1.0"))], f1, sha_a)
	with_id = PathRoc.finish({ entries: [row(f2, Ok(sha_b), NotRun)], file: f2, text })
	local = PathRoc.finish({ entries: [], file: f2, text: "Roc compiler version debug-1a2b3c4\n" })
	release = PathRoc.finish({ entries: [], file: f2, text: "Roc compiler version 0.1.0" })
	stale = PathRoc.finish({ entries: [row({ ..f2, mtime: 9 }, Ok(sha_b), Id("0.1.0"))], file: f2, text })
	no_id = PathRoc.finish({ entries: [], file: f4, text: "boom" })
	empty = PathRoc.finish({ entries: [], file: f4, text: "" })
	no_name = PathRoc.finish({ entries: [], file: f4, text: "Roc compiler version \n" })
	with_x = { ..row(f2, Ok(sha_b), NotRun), extra: [("x", row_x)] }
	kept_sha = PathRoc.add_sha([with_x], f2, sha_a)
	kept_id = PathRoc.finish({ entries: [with_x], file: f2, text })
	checks = [
		("add_sha on no rows", after_sha == [row(f1, Ok(sha_a), NotRun)]),
		("add_sha replaces the row of an older file", replaced.keep_if(|r| r.path == "/a/roc") == [row(f1, Ok(sha_a), NotRun)]),
		("add_sha keeps the other rows", replaced.keep_if(|r| r.path != "/a/roc") == [row(f2, Err(None), Id("0.1.0"))]),
		("finish: a nightly id, and the sha256 stays", with_id.entries == [row(f2, Ok(sha_b), Id(nightly))]),
		("finish: the result", with_id.id == Ok(nightly)),
		("finish: a row of an older file is replaced, with its sha256 and its id", stale.entries == [row(f2, Err(None), Id(nightly))]),
		("finish: a release", release.id == Ok("0.1.0")),
		("finish: the row of a release", release.entries == [row(f2, Err(None), Id("0.1.0"))]),
		("finish: a text that is not a version: no compiler", no_id.id == Err(NoCompiler)),
		("finish: a text that is not a version: the row says that it ran (NoId)", no_id.entries == [row(f4, Err(None), NoId)]),
		("finish: no output is no id", empty.entries == [row(f4, Err(None), NoId)] and empty.id == Err(NoCompiler)),
		("finish: an empty id is no id", no_name.entries == [row(f4, Err(None), NoId)] and no_name.id == Err(NoCompiler)),
		("add_sha keeps the unknown fields of the row (R-TF2)", kept_sha == [{ ..with_x, sha256: Ok(sha_a) }]),
		("finish keeps the unknown fields of the row (R-TF2)", kept_id.entries == [{ ..with_x, id: Id(nightly) }]),
		("finish: a local build is no compiler (R-SO11)", local.id == Err(NoCompiler)),
		("finish: the row of a local build keeps its id", local.entries == [row(f2, Err(None), Id("debug-1a2b3c4"))]),
	]
	bad = checks.keep_if(|(_, ok)| !ok).map(|(label, _)| label)
	dbg bad
	bad == []
}

# R-TF1, R-TF2: the text of the file. Rows keep their order, and the keys of a row are in the order path, size, mtime, sha256, id, then the unknown keys. A `sha256` that is `Err(None)` and an id that is `NotRun` are left out. `NoId` is `null`.
# The top object has format, files, then its unknown keys.
expect {
	entries = [row(f1, Ok(sha_a), NotRun), row(f2, Err(None), Id(nightly)), row(f3, Ok(sha_b), Id("0.1.0")), row(f4, Err(None), NoId)]
	want = "{\"format\":1,\"files\":[{\"path\":\"/a/roc\",\"size\":100,\"mtime\":5,\"sha256\":\"aaaa\"},{\"path\":\"/b/roc\",\"size\":7,\"mtime\":6,\"id\":\"${nightly}\"},{\"path\":\"/c/roc\",\"size\":100,\"mtime\":7,\"sha256\":\"bbbb\",\"id\":\"0.1.0\"},{\"path\":\"/d/roc\",\"size\":9,\"mtime\":8,\"id\":null}]}\n"
	got = PathRoc.write(doc(entries))
	back = PathRoc.read(Ok(got))
	with_extra = [{ ..row(f1, Ok(sha_a), Id(nightly)), extra: [("x", row_x), ("y", JsonDoc.Null)] }, row(f2, Err(None), NoId)]
	want_extra = "{\"format\":1,\"files\":[{\"path\":\"/a/roc\",\"size\":100,\"mtime\":5,\"sha256\":\"aaaa\",\"id\":\"${nightly}\",\"x\":[1],\"y\":null},{\"path\":\"/b/roc\",\"size\":7,\"mtime\":6,\"id\":null}],\"note\":\"keep\"}\n"
	got_extra = PathRoc.write({ entries: with_extra, extra: [("note", top_note)] })
	dbg (got, got_extra)
	got == want and PathRoc.write(doc([])) == "{\"format\":1,\"files\":[]}\n" and back == { entries, extra: [], state: Good } and got_extra == want_extra and PathRoc.read(Ok(got_extra)) == { entries: with_extra, extra: [("note", top_note)], state: Good }
}

# R-TF1, R-TF2, R-TF3, R-TF6: what `read` makes of the text. A newer `format` is ignored (no rows, and `save` never writes it). A file that does not parse is `Corrupt`. A field that Talon does not know is kept (R-TF2): in the top object and in each row, in the order of the file.
# `"id":null` is `NoId` (the run happened, no id), no key `id` is `NotRun`.
expect {
	read = |text| PathRoc.read(Ok(text))
	a = "{\"path\":\"/a/roc\",\"size\":100,\"mtime\":5,\"sha256\":\"aaaa\"}"
	good = |entries| { entries, extra: [], state: Good }
	none = { entries: [], extra: [], state: Corrupt }
	rows = [
		("no file", PathRoc.read(Err(NotFound)), { entries: [], extra: [], state: Absent }),
		("empty list", read("{\"format\":1,\"files\":[]}"), good([])),
		("one row", read("{\"format\":1,\"files\":[${a}]}"), good([row(f1, Ok(sha_a), NotRun)])),
		("white space", read("{ \"format\": 1,\n \"files\": [ ${a} ] }\n"), good([row(f1, Ok(sha_a), NotRun)])),
		("id null is NoId", read("{\"format\":1,\"files\":[{\"path\":\"/b/roc\",\"size\":7,\"mtime\":6,\"id\":null}]}"), good([row(f2, Err(None), NoId)])),
		("an unknown top field is kept (R-TF2)", read("{\"format\":1,\"extra\":true,\"files\":[],\"z\":[1]}"), { entries: [], extra: [("extra", JsonDoc.Flag(Bool.True)), ("z", row_x)], state: Good }),
		("an unknown field of a row is kept, in order (R-TF2)", read("{\"format\":1,\"files\":[{\"path\":\"/a/roc\",\"size\":100,\"x\":[1],\"mtime\":5,\"sha256\":\"aaaa\",\"y\":null}]}"), good([{ ..row(f1, Ok(sha_a), NotRun), extra: [("x", row_x), ("y", JsonDoc.Null)] }])),
		("a newer format (R-TF3)", read("{\"format\":2,\"files\":[${a}]}"), { entries: [], extra: [], state: Newer }),
		("a newer format with another shape (R-TF3)", read("{\"format\":3,\"rows\":{}}"), { entries: [], extra: [], state: Newer }),
		("not JSON", read("{\"format\":1,"), none),
		("empty text", read(""), none),
		("not an object", read("[]"), none),
		("no format", read("{\"files\":[]}"), none),
		("format is a text", read("{\"format\":\"1\",\"files\":[]}"), none),
		("no files", read("{\"format\":1}"), none),
		("a row with no size", read("{\"format\":1,\"files\":[{\"path\":\"/a/roc\",\"mtime\":5}]}"), none),
		("a row with a size that is a text", read("{\"format\":1,\"files\":[{\"path\":\"/a/roc\",\"size\":\"1\",\"mtime\":5}]}"), none),
		("a row with a size that is less than 0", read("{\"format\":1,\"files\":[{\"path\":\"/a/roc\",\"size\":-1,\"mtime\":5}]}"), none),
		("a row with an id that is a number", read("{\"format\":1,\"files\":[{\"path\":\"/a/roc\",\"size\":1,\"mtime\":5,\"id\":7}]}"), none),
		("a row with an id that is false", read("{\"format\":1,\"files\":[{\"path\":\"/a/roc\",\"size\":1,\"mtime\":5,\"id\":false}]}"), none),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-TF3, R-TF6: when the cache is written. The same rows: no write. A `Newer` file is never written. A `Corrupt` file is made again.
expect {
	one = [row(f1, Ok(sha_a), NotRun)]
	two = [row(f1, Ok(sha_a), NotRun), row(f2, Err(None), Id(nightly))]
	swapped = [row(f2, Err(None), Id(nightly)), row(f1, Ok(sha_a), NotRun)]
	save = |state, before, after| PathRoc.save({ state, before, after, extra: [] })
	note = [("note", top_note)]
	rows = [
		("absent, no row", save(Absent, [], []), Skip),
		("absent, a row", save(Absent, [], one), Write(PathRoc.write(doc(one)))),
		("good, the same rows", save(Good, two, two), Skip),
		("good, the same rows in another order", save(Good, two, swapped), Skip),
		("good, a new row", save(Good, one, two), Write(PathRoc.write(doc(two)))),
		("good, a changed row", save(Good, one, [row(f1, Ok(sha_b), NotRun)]), Write(PathRoc.write(doc([row(f1, Ok(sha_b), NotRun)])))),
		("newer, new rows", save(Newer, [], two), Skip),
		("corrupt, new rows", save(Corrupt, [], two), Write(PathRoc.write(doc(two)))),
		("corrupt, no rows", save(Corrupt, [], []), Write(PathRoc.write(doc([])))),
		# R-TF2: the unknown top fields that `read` gave are written back.
		("good, a new row, the top fields stay", PathRoc.save({ state: Good, before: one, after: two, extra: note }), Write(PathRoc.write({ entries: two, extra: note }))),
		("corrupt: no top fields to keep", PathRoc.save({ state: Corrupt, before: [], after: one, extra: [] }), Write(PathRoc.write(doc(one)))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-TF6: the warning of a file that is made again. Only `Corrupt` has one (R-TF3: a newer file is ignored with no warning).
expect {
	path = "/c/roc/talon/path-roc.json"
	text = "/c/roc/talon/path-roc.json: path-roc.json is not valid. Talon made it again."
	rows = [
		("corrupt", PathRoc.warning({ path, state: Corrupt }), Ok(text)),
		("good", PathRoc.warning({ path, state: Good }), Err(None)),
		("absent", PathRoc.warning({ path, state: Absent }), Err(None)),
		("newer", PathRoc.warning({ path, state: Newer }), Err(None)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
