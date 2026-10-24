## Slice 022b, R-SO9, R-TF1, R-TF3, R-TF6: the `roc` on `PATH` (rank 7 of Resolution 13). All decisions are pure. Command code (`Install.on_path!`) calls `Fx.path_roc!`,
## reads `talon/path-roc.json` (`Item.PathRocJson`), and then loops on `step`:
##
## | `step` gives | Command code does | Then |
## | --- | --- | --- |
## | `Hash(file)` | `Fx.sha256_file!(file.path)`, then `add_sha` | `step` again |
## | `Version(file)` | `Fx.spawn_all!` of one job (limit 1): `<file.path> version`, then `finish` with the stdout | The result is final |
## | `Done(result)` | Nothing | The result is final |
##
## After the result, `save` says whether the cache is written (`Fx.write_atomic!`, R-CC1, no lock: R-CC6 does not name this file).
##
## The launcher test (R-SO9): a file of `found` is the launcher when its size is the size of `exe` and its sha256 is the sha256 of `exe`. The first file that is not the launcher is
## the compiler of rank 7. A file with another size than `exe` is not hashed (it cannot be equal). Each file is hashed once: a row of the cache is valid when `path`, `size` and `mtime`
## are all equal to the file. `roc version` runs once for each binary, on the first file that is not the launcher, and the id stays in the row.
import Compiler
import JsonDoc

PathRoc :: [].{

	## One file, as `Fx.path_roc!` gives it. `mtime` is in seconds.
	File : { path : Str, size : U64, mtime : U64 }

	## One row of the cache. `sha256` is set after the file was hashed (only a file with the size of `exe`). `id` tells 3 cases apart (R-SO9: `roc version` runs once for each binary):
	##
	## | `id` | Meaning | In the file |
	## | --- | --- | --- |
	## | `NotRun` | `roc version` did not run on this file | no key `id` |
	## | `NoId` | It ran, and gave no id (a non-zero exit, no output, or a text that is not `Roc compiler version <id>`) | `"id":null` |
	## | `Id(id)` | It ran and gave `id` (also a local build such as `debug-<sha>`) | `"id":"<id>"` |
	##
	## `extra` is the fields of the row that Talon does not know (R-TF2), in the order of the file, as `JsonDoc` values. They stay when the row stays.
	Entry : { path : Str, size : U64, mtime : U64, sha256 : Try(Str, [None]), id : [NotRun, NoId, Id(Str)], extra : List((Str, JsonDoc)) }

	## What `read` found:
	##
	## | State | Meaning | `save` |
	## | --- | --- | --- |
	## | `Absent` | No file | Writes when a row was added |
	## | `Good` | `format` is 1 | Writes when a row was added or changed |
	## | `Newer` | `format` is more than 1 (R-TF3): the rows are ignored | Never writes |
	## | `Corrupt` | Not JSON, not an object, no integer `format`, a row with a missing or wrong field (R-TF6) | Writes (the file is made again) |
	State : [Absent, Good, Newer, Corrupt]

	## R-TF1, R-TF3, R-TF6: the cache from the result of `Fx.read_files!`. `Err(NotFound)` is `Absent`. Another error is `Absent` too (question Q3: not tested).
	## The rows are `[]` for `Absent`, `Newer` and `Corrupt`. The text of the file is a JSON object with the integer `format` and the list `files`. Each row is an object with
	## `path` (text), `size` and `mtime` (integers that are not negative), the optional text `sha256`, and the optional `id` (a text, or `null`: `NoId`). A field that Talon does not know is kept in `extra`, in the
	## top object (the result `extra`) and in each row (`Entry.extra`), in the order of the file (R-TF2). `Newer` and `Corrupt` have no `extra`.
	read : Try(Str, [NotFound, Denied, Other(Str)]) -> { entries : List(PathRoc.Entry), extra : List((Str, JsonDoc)), state : PathRoc.State }
	read = |result| match result {
		Err(_) => { entries: [], extra: [], state: Absent }
		Ok(text) => match JsonDoc.parse(text) {
			Ok(Obj(pairs)) => read_object(pairs)
			_ => corrupt
		}
	}

	## R-TF1, R-TF2: the text of the file, one line with no spaces and a line end at the end, as `JsonDoc.render` makes it (proposal, TW24):
	## `{"format":1,"files":[{"path":"/usr/bin/roc","size":123,"mtime":1792065600,"sha256":"<hex>","id":"<id>"}]}`. The keys of a row are in this order, and `sha256` is left out when it is `Err(None)`,
	## `id` is left out for `NotRun` and is `null` for `NoId`. After the keys that Talon knows come the unknown keys: the top object has `format`, `files`, then `extra`, and a row has its known keys, then `Entry.extra`.
	## The rows keep the order of the list.
	write : { entries : List(PathRoc.Entry), extra : List((Str, JsonDoc)) } -> Str
	write = |facts| {
		top = [("format", Num(1)), ("files", Arr(facts.entries.map(row_doc)))].concat(facts.extra)
		"${JsonDoc.render(Obj(top))}\n"
	}

	## R-SO9: the next step of the walk over `found`, in the order of `found`. For each file:
	##
	## | Case | Step |
	## | --- | --- |
	## | The size is not the size of `exe` | It is not the launcher. It is the compiler: `Version(file)` when its row is `NotRun` or missing. `Done(result)` when the row has `Id(id)` (mapped as `finish` does) or `NoId` (`Done(Err(NoCompiler))`: `roc version` already ran for this (path, size, mtime) and gave no id, it does not run again). |
	## | The size is the size of `exe`, and the file has no `sha256` in its row | `Hash(file)` |
	## | The size is the size of `exe`, the file has a `sha256`, and `exe` has none | `Hash(exe)` |
	## | Both have a `sha256`, and they are equal | The file is the launcher: go on to the next file |
	## | Both have a `sha256`, and they differ | It is not the launcher: the compiler, as the first case |
	## | The walk ends with no compiler (`found` is `[]`, or each file is the launcher) | `Done(Err(NoCompiler))` |
	##
	## A row is valid for a file when `path`, `size` and `mtime` are equal. Another row of the same path is not valid (the file changed). The order of the hashes: the file first, then `exe`.
	## `exe` is `Err(Unknown)`: question Q2, not tested.
	step : { exe : Try(PathRoc.File, [Unknown]), found : List(PathRoc.File), entries : List(PathRoc.Entry) } -> [Hash(PathRoc.File), Version(PathRoc.File), Done(Try(Str, [NoCompiler]))]
	step = |facts| match facts.exe {
		Err(Unknown) => Done(Err(NoCompiler))
		Ok(exe) => walk(exe, facts.found, facts.entries)
	}

	## The rows after `Fx.sha256_file!` gave `sha256` for `file`: the row of the path gets the `sha256`, the `size` and the `mtime` of `file`. A row of the same path with other `size` or
	## `mtime` is replaced (it is a row of an older file: its `id` is gone too). There is one row for each path.
	add_sha : List(PathRoc.Entry), PathRoc.File, Str -> List(PathRoc.Entry)
	add_sha = |entries, file, sha256| upsert(entries, file, |e| { ..e, sha256: Ok(sha256) })

	## R-SO9, R-SO10, R-SO11: `text` is the stdout of `<file.path> version`. The id is the one of `Compiler.version_id` (`Roc compiler version <id>`). The row of `file` gets `Id(id)` (as `add_sha` does for a
	## `sha256`). A text that is not a version (a non-zero exit of the job gives the text of its stdout, maybe empty): the row gets `NoId` and the result is `Err(NoCompiler)`: the run is not repeated. The result is the id when `Compiler.kind` is `Nightly` or `Release`, else `Err(NoCompiler)`: a local build (`debug-<sha>`) is no compiler (R-SO11, as `Compiler.on_path`). The row
	## keeps the id of a local build, so `roc version` does not run again.
	finish : { entries : List(PathRoc.Entry), file : PathRoc.File, text : Str } -> { entries : List(PathRoc.Entry), id : Try(Str, [NoCompiler]) }
	finish = |facts| {
		parsed = Compiler.version_id(facts.text)
		id = match parsed {
			Ok(found) => Id(found)
			Err(BadVersion) => NoId
		}
		{ entries: upsert(facts.entries, facts.file, |e| { ..e, id: id }), id: usable(id) }
	}

	## R-TF3, R-TF6: whether to write the cache. `before` is the rows that `read` gave, `after` is the rows at the end of the walk (the same rows: no write), `extra` is the unknown top fields that `read` gave.
	##
	## | `state` | `before` equals `after` as sets | Result |
	## | --- | --- | --- |
	## | `Newer` | any | `Skip` (R-TF3: Talon never writes a file with a newer `format`) |
	## | `Corrupt` | any | `Write(write({ entries: after, extra }))` (R-TF6: the file is made again) |
	## | `Absent`, `Good` | yes | `Skip` |
	## | `Absent`, `Good` | no | `Write(write({ entries: after, extra }))` |
	save : { state : PathRoc.State, before : List(PathRoc.Entry), after : List(PathRoc.Entry), extra : List((Str, JsonDoc)) } -> [Skip, Write(Str)]
	save = |facts| {
		write_now = Write(PathRoc.write({ entries: facts.after, extra: facts.extra }))
		match facts.state {
			Newer => Skip
			Corrupt => write_now
			_ => if same_rows(facts.before, facts.after) Skip else write_now
		}
	}

	## R-TF6: the warning (no `warning: ` and no line end, the command adds them) for a `Corrupt` cache, proposal (TW24): `<path>: path-roc.json is not valid. Talon made it again.` Other states: `Err(None)`.
	warning : { path : Str, state : PathRoc.State } -> Try(Str, [None])
	warning = |facts| match facts.state {
		Corrupt => Ok("${facts.path}: path-roc.json is not valid. Talon made it again.")
		_ => Err(None)
	}
}

Read : { entries : List(PathRoc.Entry), extra : List((Str, JsonDoc)), state : PathRoc.State }

Next : [Hash(PathRoc.File), Version(PathRoc.File), Done(Try(Str, [NoCompiler]))]

corrupt : Read
corrupt = { entries: [], extra: [], state: Corrupt }

field : List((Str, JsonDoc)), Str -> Try(JsonDoc, [NotFound])
field = |pairs, key| pairs.find_first(|(name, _)| name == key).map_ok(|(_, value)| value)

# R-TF3: the `format` is read first, so a newer file of any shape is `Newer`.
read_object : List((Str, JsonDoc)) -> Read
read_object = |pairs| match field(pairs, "format") {
	Ok(Num(n)) => if n > 1 {
		{ entries: [], extra: [], state: Newer }
	} else if n == 1 {
		read_files(pairs)
	} else {
		corrupt
	}
	_ => corrupt
}

read_files : List((Str, JsonDoc)) -> Read
read_files = |pairs| match field(pairs, "files") {
	Ok(Arr(items)) => match items.map_try(read_row) {
		Ok(entries) => { entries, extra: pairs.keep_if(|(name, _)| name != "format" and name != "files"), state: Good }
		Err(BadRow) => corrupt
	}
	_ => corrupt
}

read_row : JsonDoc -> Try(PathRoc.Entry, [BadRow])
read_row = |doc| match doc {
	Obj(fields) => {
		path = text_field(fields, "path")?
		size = count_field(fields, "size")?
		mtime = count_field(fields, "mtime")?
		sha256 = match field(fields, "sha256") {
			Err(NotFound) => Ok(Err(None))
			Ok(Text(hex)) => Ok(Ok(hex))
			_ => Err(BadRow)
		}?
		id = match field(fields, "id") {
			Err(NotFound) => Ok(NotRun)
			Ok(Null) => Ok(NoId)
			Ok(Text(text)) if !text.is_empty() => Ok(Id(text))
			_ => Err(BadRow)
		}?
		known = ["path", "size", "mtime", "sha256", "id"]
		Ok({ path, size, mtime, sha256, id, extra: fields.keep_if(|(name, _)| !known.contains(name)) })
	}
	_ => Err(BadRow)
}

text_field : List((Str, JsonDoc)), Str -> Try(Str, [BadRow])
text_field = |fields, key| match field(fields, key) {
	Ok(Text(text)) => Ok(text)
	_ => Err(BadRow)
}

count_field : List((Str, JsonDoc)), Str -> Try(U64, [BadRow])
count_field = |fields, key| match field(fields, key) {
	Ok(Num(n)) => n.to_u64_try().map_err(|OutOfRange| BadRow)
	_ => Err(BadRow)
}

# The keys of a row: path, size, mtime, sha256, id, then the unknown keys.
row_doc : PathRoc.Entry -> JsonDoc
row_doc = |e| {
	sha = match e.sha256 {
		Ok(hex) => [("sha256", Text(hex))]
		Err(None) => []
	}
	id = match e.id {
		NotRun => []
		NoId => [("id", Null)]
		Id(text) => [("id", Text(text))]
	}
	known = [("path", Text(e.path)), ("size", Num(e.size.to_i64_wrap())), ("mtime", Num(e.mtime.to_i64_wrap()))]
	Obj(known.concat(sha).concat(id).concat(e.extra))
}

# A row is valid for a file when the path, the size and the mtime are equal.
valid : PathRoc.Entry, PathRoc.File -> Bool
valid = |e, file| e.path == file.path and e.size == file.size and e.mtime == file.mtime

fresh : PathRoc.File -> PathRoc.Entry
fresh = |file| { path: file.path, size: file.size, mtime: file.mtime, sha256: Err(None), id: NotRun, extra: [] }

row_of : List(PathRoc.Entry), PathRoc.File -> Try(PathRoc.Entry, [NotFound])
row_of = |entries, file| entries.find_first(|e| valid(e, file))

sha_of : List(PathRoc.Entry), PathRoc.File -> Try(Str, [None])
sha_of = |entries, file| match row_of(entries, file) {
	Ok(e) => e.sha256
	Err(NotFound) => Err(None)
}

# One row for each path: a valid row is changed, a row of an older file is replaced by a new row.
upsert : List(PathRoc.Entry), PathRoc.File, (PathRoc.Entry -> PathRoc.Entry) -> List(PathRoc.Entry)
upsert = |entries, file, change| {
	if entries.any(|e| e.path == file.path) {
		entries.map(|e| if e.path != file.path e else if valid(e, file) change(e) else change(fresh(file)))
	} else {
		entries.append(change(fresh(file)))
	}
}

# R-SO10, R-SO11: a local build is no compiler for rank 7.
usable : [NotRun, NoId, Id(Str)] -> Try(Str, [NoCompiler])
usable = |id| match id {
	Id(text) => if Compiler.kind(text) == Local Err(NoCompiler) else Ok(text)
	_ => Err(NoCompiler)
}

walk : PathRoc.File, List(PathRoc.File), List(PathRoc.Entry) -> Next
walk = |exe, found, entries| match found {
	[] => Done(Err(NoCompiler))
	[file, .. as rest] => if file.size != exe.size {
		compiler_step(file, entries)
	} else {
		match (sha_of(entries, file), sha_of(entries, exe)) {
			(Err(None), _) => Hash(file)
			(Ok(_), Err(None)) => Hash(exe)
			(Ok(a), Ok(b)) => if a == b walk(exe, rest, entries) else compiler_step(file, entries)
		}
	}
}

# The first file that is not the launcher: `roc version` runs only when no run is in its row.
compiler_step : PathRoc.File, List(PathRoc.Entry) -> Next
compiler_step = |file, entries| match row_of(entries, file) {
	Ok(e) => match e.id {
		NotRun => Version(file)
		id => Done(usable(id))
	}
	Err(NotFound) => Version(file)
}

same_rows : List(PathRoc.Entry), List(PathRoc.Entry) -> Bool
same_rows = |a, b| a.len() == b.len() and a.all(|e| b.contains(e)) and b.all(|e| a.contains(e))
