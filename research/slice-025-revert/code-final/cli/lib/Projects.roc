import Fail
import JsonDoc
import TalonFile
import Text

## The known projects: the text of `talon/projects.json` (CLI 1 R-PD9 to R-PD13, CLI 6.1). The list is for GC (6.3)
## and R-RR2. The file has `format` 1 (R-TF1). The form is a proposal:
##
## ```text
## {"format":1,"projects":[{"path":"/home/me/app/main.roc","last_use":1792065600}]}
## ```
##
## | Rule | Text |
## | --- | --- |
## | Entry | Only `path` (canonical, absolute) and `last_use` (seconds since the epoch, `TALON_NOW` when set) (R-PD12). A field that Talon does not know stays (R-TF2). |
## | Order | The entries are sorted by path |
## | Content that does not parse | A JSON that is not an object with an array `projects` of objects that have a text `path` and an integer `last_use` is content that does not parse (R-TF6). `projects.json` cannot be made again (R-TF3): `TalonFile.open` with `can_recreate` false. |
Projects :: [].{

	## The new text of the file after a command read the project files `files` (R-PD9, R-PD10, R-PD11).
	## `path` is the path of `projects.json` (for the messages). `text` is its content, or `Missing`. `cache` is the
	## cache root. A file under `<cache>/talon/tmp/` or `<cache>/packages/` is never recorded (R-PD11).
	##
	## | `refresh` | An entry that is already there |
	## | --- | --- |
	## | `Always` | `last_use` becomes `now` (the commands, R-PD9) |
	## | `After(n)` | `last_use` becomes `now` only when `now - last_use` is more than `n` seconds (the proxy: `After(86400)`, R-PD10) |
	##
	## A new path is always added. The result is `Unchanged` when no entry is new and none changed. Else it is
	## `Write(text)`. A failure of `TalonFile.open` or a structure error is `Err` (kind `Input`).
	record : { path : Str, text : Try(Str, [Missing]), cache : Str, files : List(Str), now : U64, refresh : [Always, After(U64)] } -> Try([Write(Str), Unchanged], Fail)
	record = |facts| {
		loaded = match facts.text {
			Ok(text) => read_file({ path: facts.path, text })?
			Err(Missing) => { format: newest, fields: [("projects", JsonDoc.Arr([]))], items: [] }
		}
		wanted = Text.sorted_unique(facts.files.keep_if(|f| !is_skipped(facts.cache, f)))
		start = { items: loaded.items, changed: Bool.False }
		done = wanted.fold(start, |state, file| touch(state, file, facts.now, facts.refresh))
		if done.changed {
			Ok(Write(write_text(loaded, done.items.sort_with(|a, b| Text.compare(a.path, b.path)))))
		} else {
			Ok(Unchanged)
		}
	}

	## The entries of the text (for GC), sorted by path.
	entries : { path : Str, text : Str } -> Try(List({ path : Str, last_use : U64 }), Fail)
	entries = |facts| {
		loaded = read_file(facts)?
		Ok(loaded.items.sort_with(|a, b| Text.compare(a.path, b.path)).map(|item| { path: item.path, last_use: item.last_use }))
	}

	## R-PD13: the text without the entries that protect nothing. An entry leaves when its path is not in `valid` (GC and
	## R-RR2 found that the file is missing or has no app, package or platform header), or when `max_age` is `Ok(n)`
	## and `now - last_use` is more than `n` (the GC age). `removed` is the paths that left, sorted. When `removed` is
	## `[]` the text is the same as the entry text (the caller writes nothing).
	prune : { path : Str, text : Str, now : U64, max_age : Try(U64, [NoLimit]), valid : List(Str) } -> Try({ text : Str, removed : List(Str) }, Fail)
	prune = |facts| {
		loaded = read_file({ path: facts.path, text: facts.text })?
		keeps = |item| facts.valid.contains(item.path) and !too_old(item.last_use, facts.now, facts.max_age)
		kept = loaded.items.keep_if(keeps)
		removed = Text.sorted(loaded.items.keep_if(|item| !keeps(item)).map(|item| item.path))
		if removed.is_empty() {
			Ok({ text: facts.text, removed })
		} else {
			Ok({ text: write_text(loaded, kept), removed })
		}
	}
}

# The format that this Talon writes.
newest : U64
newest = 1

Item : { path : Str, last_use : U64, pairs : List((Str, JsonDoc)) }

Loaded : { format : U64, fields : List((Str, JsonDoc)), items : List(Item) }

# The file as data. `pairs` of an item keep the fields that Talon does not know (R-TF2).
read_file : { path : Str, text : Str } -> Try(Loaded, Fail)
read_file = |facts| {
	bad = Fail.new(Input, "${facts.path}: the content does not parse")
	read = TalonFile.open({ path: facts.path, text: facts.text, newest, can_recreate: Bool.False })?
	match read {
		Use(file) => match file.fields.find_first(|(key, _)| key == "projects") {
			Ok((_, JsonDoc.Arr(docs))) => match docs.map_try(item_of) {
				Ok(items) => Ok({ format: file.format, fields: file.fields, items })
				Err(NotAnItem) => Err(bad)
			}
			_ => Err(bad)
		}
		_ => Err(bad)
	}
}

item_of : JsonDoc -> Try(Item, [NotAnItem])
item_of = |doc| match doc {
	JsonDoc.Obj(pairs) => match (pairs.find_first(|(key, _)| key == "path"), pairs.find_first(|(key, _)| key == "last_use")) {
		(Ok((_, JsonDoc.Text(path))), Ok((_, JsonDoc.Num(n)))) => if n >= 0 Ok({ path, last_use: n.to_u64_wrap(), pairs }) else Err(NotAnItem)
		_ => Err(NotAnItem)
	}
	_ => Err(NotAnItem)
}

# The text of the file with the new list of entries, in the place of the old `projects` field.
write_text : Loaded, List(Item) -> Str
write_text = |loaded, items| {
	docs = items.map(|item| JsonDoc.Obj(item.pairs))
	fields = loaded.fields.map(|(key, value)| if key == "projects" (key, JsonDoc.Arr(docs)) else (key, value))
	TalonFile.render({ format: loaded.format, fields })
}

# R-PD11: a file in a temp copy of an app or in the package cache is not a project.
is_skipped : Str, Str -> Bool
is_skipped = |cache, file| file.starts_with("${cache}/talon/tmp/") or file.starts_with("${cache}/packages/")

# One file of a command: a new entry, or a new time for an old entry (R-PD9, R-PD10, R-PD12).
touch : { items : List(Item), changed : Bool }, Str, U64, [Always, After(U64)] -> { items : List(Item), changed : Bool }
touch = |state, file, now, refresh| match state.items.find_first(|item| item.path == file) {
	Err(_) => {
		pairs = [("path", JsonDoc.Text(file)), ("last_use", JsonDoc.Num(now.to_i64_wrap()))]
		{ items: state.items.append({ path: file, last_use: now, pairs }), changed: Bool.True }
	}
	Ok(old) => if due(old.last_use, now, refresh) {
		same = |item| item.path == file
		renew = |item| if same(item) { path: item.path, last_use: now, pairs: with_time(item.pairs, now) } else item
		{ items: state.items.map(renew), changed: Bool.True }
	} else {
		state
	}
}

due : U64, U64, [Always, After(U64)] -> Bool
due = |last_use, now, refresh| match refresh {
	Always => last_use != now
	After(seconds) => too_old(last_use, now, Ok(seconds))
}

# More than `max_age` seconds old. A time in the future is not old.
too_old : U64, U64, Try(U64, [NoLimit]) -> Bool
too_old = |last_use, now, max_age| match max_age {
	Ok(seconds) => now > last_use and now - last_use > seconds
	Err(NoLimit) => Bool.False
}

with_time : List((Str, JsonDoc)), U64 -> List((Str, JsonDoc))
with_time = |pairs, now| pairs.map(|(key, value)| if key == "last_use" (key, JsonDoc.Num(now.to_i64_wrap())) else (key, value))
