import JsonDoc

## The facts of one `install` run for `--json` and for the line of R-DT5 (CLI 3 "Output catalog", R-OUT4, Resolution 11). Part A (pure).
##
## `Outcome` holds each fact that the human text prints (R-OUT4):
##
## | Field | Holds | Human text |
## | --- | --- | --- |
## | `at` | The time that the resolve is at, `YYYY-MM-DDTHH:MM:SSZ` (R-DT5: `TALON_NOW`, or the time of `--snapshot`) | the line `resolved at <time>, <n> probes` |
## | `probes` | The number of `roc` runs of the ladder: 3 for an app that changes (baseline, check, build), 2 for a package or a platform, 0 with `--no-check` | the same line |
## | `dry_run` | `--dry-run` | the line `dry run: nothing was written` |
## | `check`, `build` | The state of the ladder steps: `Passed`, `Skipped` (`--no-check`), `NotRun` (nothing changed, or a package for the build) | `check: passed`, `build: passed`, `check: skipped` |
## | `added` | The new header entries (`+ <alias>: <name> <version>`) | the `+` lines |
## | `moved` | The entries that moved or were replaced (`~ <alias>: ...`): `from` and `to` are the name and the version | the `~` lines |
## | `kept` | The entries that `add` found in the header and left as they are (R-AD21) | `<alias>: <name> <version> is in the header` |
## | `pinned` | The `roc:` id that the command wrote (R-RP3), or `Err(None)` | the line `+ roc: <id>` |
## | `toml` | The `talon.toml` keys that were written or planned: file, key, value | `<path>: <key> = "<value>"` |
## | `renamed` | The stale keys of `talon.toml` that were renamed (R-NI1): file, old key, new key | `<path>: key <from> -> <to>` |
## | `notes` | Each `note:` line without the prefix (young release, unchanged and removed errors) | the `note:` lines |
## | `written` | The files that were written, in the order of the write. `[]` for `--dry-run`, for a no-change run and for a failure. | the file lines |
Report :: [].{

	Entry : { alias : Str, name : Str, version : Str }

	Outcome : {
		at : Str,
		probes : U64,
		downloads : U64,
		dry_run : Bool,
		check : [Passed, Skipped, NotRun],
		build : [Passed, Skipped, NotRun],
		added : List(Entry),
		moved : List({ alias : Str, from : { name : Str, version : Str }, to : { name : Str, version : Str } }),
		kept : List(Entry),
		pinned : Try(Str, [None]),
		toml : List({ path : Str, key : Str, value : Str }),
		renamed : List({ path : Str, from : Str, to : Str }),
		notes : List(Str),
		written : List(Str),
	}

	## R-DT5 (proposal, TW24, question Q4): `resolved at 2026-10-15T12:00:00Z, 3 probes`. One probe is `1 probe`, none is `0 probes`.
	resolved_line : { at : Str, probes : U64 } -> Str
	resolved_line = |facts| {
		count = if facts.probes == 1 "1 probe" else "${facts.probes.to_str()} probes"
		"resolved at ${facts.at}, ${count}"
	}

	## The `data` of the envelope of `install` and `add` (R-J3, R-J4, R-OUT4, R-OUT5). Keys in this order (proposal, TW24):
	##
	## | Key | Value |
	## | --- | --- |
	## | `snapshot` | `at` |
	## | `probes` | `probes` (number) |
	## | `downloads` | `downloads` (number): the compilers that this command downloaded, 1 after one download and 0 with none (slice 025, answer Q7 of the review) |
	## | `dry_run` | `dry_run` (true or false) |
	## | `check` | `"passed"`, `"skipped"` or null for `NotRun` |
	## | `build` | the same |
	## | `added` | a list of `{ "alias", "name", "version" }` |
	## | `moved` | a list of `{ "alias", "from": { "name", "version" }, "to": { "name", "version" } }` |
	## | `kept` | a list of `{ "alias", "name", "version" }` |
	## | `pinned` | the id, or null |
	## | `toml` | a list of `{ "path", "key", "value" }` |
	## | `renamed` | a list of `{ "path", "from", "to" }` |
	## | `notes` | a list of texts |
	## | `written` | a list of paths |
	data : Outcome -> JsonDoc
	data = |o| JsonDoc.Obj([
		("snapshot", Text(o.at)),
		("probes", Num(o.probes.to_i64_wrap())),
		("downloads", Num(0)),
		("dry_run", Flag(o.dry_run)),
		("check", step_doc(o.check)),
		("build", step_doc(o.build)),
		("added", Arr(o.added.map(entry_doc))),
		(
			"moved",
			Arr(
				o.moved.map(
					|m| Obj([
						("alias", Text(m.alias)),
						("from", Obj([("name", Text(m.from.name)), ("version", Text(m.from.version))])),
						("to", Obj([("name", Text(m.to.name)), ("version", Text(m.to.version))])),
					]),
				),
			),
		),
		("kept", Arr(o.kept.map(entry_doc))),
		(
			"pinned",
			match o.pinned {
				Ok(id) => Text(id)
				Err(None) => Null
			},
		),
		("toml", Arr(o.toml.map(|t| Obj([("path", Text(t.path)), ("key", Text(t.key)), ("value", Text(t.value))])))),
		("renamed", Arr(o.renamed.map(|r| Obj([("path", Text(r.path)), ("from", Text(r.from)), ("to", Text(r.to))])))),
		("notes", Arr(o.notes.map(|n| Text(n)))),
		("written", Arr(o.written.map(|w| Text(w)))),
	])

	## One entry that `tln remove` took out of a header (slice 008). `kind` is `Release` (`name` is the full name, `version` is `Ok(<version>)`), `Path` or
	## `Foreign` (`name` is the value of the entry, `version` is `Err(None)`).
	Removed : { alias : Str, kind : [Release, Path, Foreign], name : Str, version : Try(Str, [None]) }

	## The facts of one `remove` run for `--json` and the human lines (slice 008, R-OUT4). A remove resolves nothing, so there is no `at` and no R-DT5 line (question Q8).
	##
	## | Field | Holds | Human text |
	## | --- | --- | --- |
	## | `probes` | The number of `roc` runs of the ladder: 3 for an app, 2 for a package or a platform, 0 with `--no-check` and with `--force` that skipped the check | |
	## | `dry_run` | `--dry-run` | the line `dry run: nothing was written` |
	## | `check`, `build` | As in `Outcome` (`Skipped` for `--no-check` and for the check that `--force` skipped) | `check: passed`, `build: passed`, `check: skipped` |
	## | `removed` | The entries that were taken out of the header | `- <alias>: ...` |
	## | `toml` | The keys of `talon.toml` that were removed: file, table (`dependencies`, `overrides`, `patch`), key | `<path>: - [<table>] <key>` |
	## | `patches` | The patch dirs that stay (R-RV4): the alias and the dir with `/` at the end | `kept: <dir> (the patch files of <alias>)` |
	## | `pinned` | The `roc:` id that the command wrote (R-RP3), or `Err(None)` | `+ roc: <id>` |
	## | `notes` | Each `note:` line without the prefix: the unchanged and removed errors of the check, and the note of `--force` | the `note:` lines |
	## | `written` | The files that were written, in the order of the write. `[]` for `--dry-run` and for a failure. | the file lines |
	RemoveOutcome : {
		probes : U64,
		dry_run : Bool,
		check : [Passed, Skipped, NotRun],
		build : [Passed, Skipped, NotRun],
		removed : List(Removed),
		toml : List({ path : Str, table : Str, key : Str }),
		patches : List({ alias : Str, dir : Str }),
		pinned : Try(Str, [None]),
		notes : List(Str),
		written : List(Str),
	}

	## The `data` of the envelope of `remove` and `rm` (R-J3, R-J4, R-OUT4, R-OUT5). Keys in this order (proposal, TW24):
	##
	## | Key | Value |
	## | --- | --- |
	## | `probes` | `probes` (number) |
	## | `dry_run` | `dry_run` (true or false) |
	## | `check` | `"passed"`, `"skipped"` or null for `NotRun` |
	## | `build` | the same |
	## | `removed` | a list of `{ "alias", "kind": "release" or "path" or "foreign", "name", "version" }` (`version` is null when `Err(None)`) |
	## | `toml` | a list of `{ "path", "table", "key" }` |
	## | `patches` | a list of `{ "alias", "dir" }` |
	## | `pinned` | the id, or null |
	## | `notes` | a list of texts |
	## | `written` | a list of paths |
	remove_data : RemoveOutcome -> JsonDoc
	remove_data = |o| JsonDoc.Obj([
		("probes", Num(o.probes.to_i64_wrap())),
		("dry_run", Flag(o.dry_run)),
		("check", step_doc(o.check)),
		("build", step_doc(o.build)),
		("removed", Arr(o.removed.map(removed_doc))),
		("toml", Arr(o.toml.map(|t| Obj([("path", Text(t.path)), ("table", Text(t.table)), ("key", Text(t.key))])))),
		("patches", Arr(o.patches.map(|p| Obj([("alias", Text(p.alias)), ("dir", Text(p.dir))])))),
		(
			"pinned",
			match o.pinned {
				Ok(id) => Text(id)
				Err(None) => Null
			},
		),
		("notes", Arr(o.notes.map(|n| Text(n)))),
		("written", Arr(o.written.map(|w| Text(w)))),
	])
}

# `NotRun` is null: the step did not run.
step_doc : [Passed, Skipped, NotRun] -> JsonDoc
step_doc = |step| match step {
	Passed => Text("passed")
	Skipped => Text("skipped")
	NotRun => Null
}

entry_doc : Report.Entry -> JsonDoc
entry_doc = |e| Obj([("alias", Text(e.alias)), ("name", Text(e.name)), ("version", Text(e.version))])

removed_doc : Report.Removed -> JsonDoc
removed_doc = |r| {
	kind = match r.kind {
		Release => "release"
		Path => "path"
		Foreign => "foreign"
	}
	version = match r.version {
		Ok(v) => Text(v)
		Err(None) => Null
	}
	Obj([("alias", Text(r.alias)), ("kind", Text(kind)), ("name", Text(r.name)), ("version", version)])
}
