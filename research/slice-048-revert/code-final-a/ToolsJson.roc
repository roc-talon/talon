import Fail
import Ident
import JsonDoc
import Lookup
import TalonFile

## `tools.json`, the manifest of the global tools (slice 046, CLI 6.4 R-T4, R-T27, R-T28, CLI 6.1 R-LY2, R-LY3, R-TF1 to R-TF3, R-CC6). Part A (TESTING.md 2.2): pure decisions. The command code is `ToolFlow`.
## Slice 027 fixed a provisional form (question Q1 of `docs/slices/027-setup.md`) and `Setup.tool_names` reads it. Slice 046 confirms it and gives the fields of each tool. The text is one line (`TalonFile.render`):
##
## ```json
## {"format":1,"tools":{"foo":{"name":"acme/foo","source":{"kind":"release","version":"1.1.0","url":"https://github.com/acme/foo/releases/download/1.1.0/<hash>.tar.zst"},"build":{"hashes":["<hash>"],"nightly":"nightly-2026-10-14-38a3029","target":"x64musl"},"sha256":"<64 hex digits>","libs":[],"installed_at":"2026-10-15T12:00:00Z"}}}
## ```
##
## | Field | Content | Rule |
## | --- | --- | --- |
## | key of `tools` | The name of the bin dir entry (R-ST15), the binary name (R-T28). `Setup.tool_names` reads the keys. | R-ST1, R-T28 |
## | `name` | The full name `owner/repo` (or `host/path`), Design 4.1 | R-T4, R-T27 |
## | `source` | `{"kind":"release","version","url"}`: the release and the URL of its app bundle (the hash of the bundle is in the URL). `{"kind":"git","commit","ref"}`: written by slice 048, read here only as a kind (R-T23, R-T27: a release install replaces it). | R-T4, R-T10 |
## | `build` | The build id (Design 4.1, R-ID6): `hashes` (the hash of each release URL entry of the app header, in header order, the platform is one of them), `nightly` (the compiler id of the build, R-T5: the compiler can be removed later), `target` (`BuildSkip.target` of the machine, R-T8: no `--target`) | R-T4, R-T1, R-T5, R-T8 |
## | `sha256` | The sha256 of the installed file in the data bin dir. It identifies this file only, Talon never compares it with the sha256 of another build (R-T4). | R-T4 |
## | `libs` | The run-time libraries of a glibc build (R-T8). Slice 046 writes `[]` (question Q4: no Fx call reads the bytes of a file). | R-T8 |
## | `installed_at` | `Clock.format_utc` of the time of Talon (`TALON_NOW`) | R-T4 |
##
## A field that Talon does not know stays when Talon writes the file (R-TF2). A newer `format` is exit 19 (R-TF3). A missing file is no tool.
ToolsJson :: [].{

	## What a tool was built from. `Git` is the form of slice 048 (R-T23).
	Source : [Release({ version : Str, url : Str }), Git({ commit : Str, ref : Str })]

	## One tool as `read` gives it: the key (the binary name), the full name and the source.
	Entry : { key : Str, name : Str, source : Source }

	## One tool that a build made: the fields of the table above. `key` is the key of `tools`.
	Built : { key : Str, name : Str, version : Str, url : Str, hashes : List(Str), nightly : Str, target : Str, sha256 : Str, libs : List(Str), installed_at : Str }

	## What a binary name and a full name mean for the tools that are installed (R-T26, R-T27, R-T28, R-CC6):
	##
	## | Case | Result |
	## | --- | --- |
	## | No tool has the key and no tool has the full name | `Free` |
	## | A tool has the key and the same full name | `Same(entry)`: the same tool, a build replaces it (R-T26, R-T27) |
	## | A tool has the key and another full name | `Taken(entry)`: the binary name clash (R-T28) |
	## | No tool has the key, and a tool with the same full name has another key | `Elsewhere(entry)`: the same app under another binary name (question Q2) |
	##
	## The key is looked at first.
	Clash : [Free, Same(Entry), Taken(Entry), Elsewhere(Entry)]

	## The tools of the file. `text` is `Err(NotFound)` for a missing file (no tool). `path` is for the messages.
	##
	## | Text | Result |
	## | --- | --- |
	## | A missing file, or no `tools` field | `Ok([])` |
	## | `{"format":1,"tools":{...}}` | One `Entry` for each key of `tools`, in the order of the text |
	## | Not JSON, no integer `format` | Kind `Input` (exit 19): `<path>: the content does not parse` |
	## | A `format` above 1 | Kind `Input`: `<path>: format <n> is newer than this tln (format 1). Run: tln tool update talon` (`TalonFile.open`) |
	## | `tools` is not an object | Kind `Input`: `<path>: tools is not an object` |
	## | A tool that is not an object, or has no text `name`, or has no `source` with a known `kind` and its fields | Kind `Input`: `<path>: tool <key>: <what>` with `<what>` `is not an object`, `has no name` or `has no source that tln knows` |
	read : { path : Str, text : Try(Str, [NotFound]) } -> Try(List(Entry), Fail)
	read = |facts| match facts.text {
		Err(NotFound) => Ok([])
		Ok(text) => {
			file = open_file(facts.path, text)?
			match tools_of(facts.path, file.fields)? {
				Ok(tools) => tools.fold_try([], |kept, (key, doc)| Ok(kept.append(entry_of(facts.path, key, doc)?)))
				Err(NoTools) => Ok([])
			}
		}
	}

	## The text of the file after the tool `built` is added, or replaces the tool with the same key (R-T26, R-T27). `text` is the file as it is now. The other tools and the other top-level fields stay as they are (R-TF2), in their
	## place; a new tool is the last of `tools`. A replaced tool keeps the fields that Talon does not know, in their place (R-TF2); the fields of the table are the new ones. A file with no `tools` field gets the field at the end. A failure is the one of `read` for the parts that it reads (`TalonFile.open`).
	add : { path : Str, text : Try(Str, [NotFound]), built : Built } -> Try(Str, Fail)
	add = |facts| ToolsJson.put({ path: facts.path, text: facts.text, tool: release_tool(facts.built) })

	## The decision of the table of `Clash`. `entries` are the tools of the file, `key` is the binary name that the install wants, `name` is the full name of the app.
	clash : { entries : List(Entry), key : Str, name : Str } -> Clash
	clash = |facts| match facts.entries.find_first(|e| e.key == facts.key) {
		Ok(e) => if e.name == facts.name Same(e) else Taken(e)
		Err(_) => match facts.entries.find_first(|e| e.name == facts.name) {
			Ok(e) => Elsewhere(e)
			Err(_) => Free
		}
	}

	## R-SC3: the tools as the entities of a name lookup (`Lookup.find` with the scope `Tool`). `alias` is the key (the binary name), `name` the full name. A release tool has its version and its series (`Ident.series_of`). A git tool has no version
	## (`Err(None)`) and no series. `note` is the empty text.
	entities : List(Entry) -> List(Lookup.Entity)
	entities = |entries| entries.map(
		|e| match e.source {
			Release(rel) => { alias: e.key, name: e.name, series: Ident.series_of(rel.version) ?? "", version: Ok(rel.version), note: "" }
			Git(_) => { alias: e.key, name: e.name, series: "", version: Err(None), note: "" }
		},
	)

	## Slice 048 (R-T4, R-T7, R-T23): one tool with all the fields of the manifest. `source` is the form of the table at the top of this file. `path` is the `--path` of a git tool (R-T23): the field `path` of the object `source`. It is not there for no `--path` and for a release.
	## `hashes`, `nightly` and `target` are the build id (the object `build`). A field that is missing from the file gives the empty text (`nightly`, `target`, `sha256`, `installed_at`) or the empty list (`hashes`, `libs`).
	Tool : { key : Str, name : Str, source : Source, path : Try(Str, [None]), hashes : List(Str), nightly : Str, target : Str, sha256 : Str, libs : List(Str), installed_at : Str }

	## R-T4, R-T7: the tools of the file with all their fields, in the order of the text. The reading rules of `read` hold (a missing file is no tool, the `format`, a tool with no name or no known source: kind `Input`). The `source` of a git tool has the optional text `path`.
	manifest : { path : Str, text : Try(Str, [NotFound]) } -> Try(List(Tool), Fail)
	manifest = |_facts| crash "todo: slice 048"

	## R-T4, R-T23, R-T26, R-T27, R-TF2: the text of the file after `tool` is put in `tools`. It replaces the tool with the same key in its place, else it is the last tool. The rules of `add` hold: the other tools and the other top-level fields stay, a replaced tool keeps the fields that Talon does not
	## know, a file with no `tools` field gets the field at the end, a missing file gives a new file. The object `source` is written whole from `tool.source` and `tool.path`: a git source is `{"kind":"git","commit","ref"}` and `"path"` when `tool.path` is `Ok`.
	put : { path : Str, text : Try(Str, [NotFound]), tool : Tool } -> Try(Str, Fail)
	put = |facts| match facts.text {
		Err(NotFound) => Ok(render_fields([("tools", Obj([(facts.tool.key, tool_doc(facts.tool))]))]))
		Ok(text) => {
			file = open_file(facts.path, text)?
			tools = tools_of(facts.path, file.fields)?
			Ok(render_fields(with_tools(file.fields, tools, facts.tool)))
		}
	}

	## R-B6 (`tln tool rm`): the text of the file after the tool with `key` is removed from `tools`. The other tools and the other top-level fields stay as they are (R-TF2). The last tool gives `"tools":{}`. A key that is not there, and a file with no `tools` field, give the text
	## as it is. A missing file gives the empty text. A text that does not parse, and a newer `format`, are the failures of `read`.
	drop : { path : Str, text : Try(Str, [NotFound]), key : Str } -> Try(Str, Fail)
	drop = |_facts| crash "todo: slice 048"
}

# The `tools` object of the fields of the file, or `NoTools` for a file with no such field.
tools_of : Str, List((Str, JsonDoc)) -> Try(Try(List((Str, JsonDoc)), [NoTools]), Fail)
tools_of = |path, fields| match fields.find_first(|(name, _)| name == "tools") {
	Ok((_, Obj(pairs))) => Ok(Ok(pairs))
	Ok(_) => Err(Fail.new(Input, "${path}: tools is not an object"))
	Err(_) => Ok(Err(NoTools))
}

# A file that Talon reads and writes: `format` 1 at most, and it can not be made again from nothing (R-TF3).
open_file : Str, Str -> Try({ format : U64, fields : List((Str, JsonDoc)) }, Fail)
open_file = |path, text| match TalonFile.open({ path, text, newest: 1, can_recreate: Bool.False })? {
	Use(file) => Ok(file)
	_ => Ok({ format: 1, fields: [] })
}

# One tool of the `tools` object. A check fails with the first thing that is wrong: no object, no name, no known source.
entry_of : Str, Str, JsonDoc -> Try(ToolsJson.Entry, Fail)
entry_of = |path, key, doc| {
	bad = |what| Fail.new(Input, "${path}: tool ${key}: ${what}")
	pairs = match doc {
		Obj(found) => found
		_ => return Err(bad("is not an object"))
	}
	name = match text_field(pairs, "name") {
		Ok(text) => text
		Err(_) => return Err(bad("has no name"))
	}
	match pairs.find_first(|(field, _)| field == "source") {
		Ok((_, Obj(source))) => match source_of(source) {
			Ok(known) => Ok({ key, name, source: known })
			Err(_) => Err(bad("has no source that tln knows"))
		}
		_ => Err(bad("has no source that tln knows"))
	}
}

source_of : List((Str, JsonDoc)) -> Try(ToolsJson.Source, [Unknown])
source_of = |pairs| match text_field(pairs, "kind") {
	Ok("release") => match (text_field(pairs, "version"), text_field(pairs, "url")) {
		(Ok(version), Ok(url)) => Ok(Release({ version, url }))
		_ => Err(Unknown)
	}
	Ok("git") => match (text_field(pairs, "commit"), text_field(pairs, "ref")) {
		(Ok(commit), Ok(ref)) => Ok(Git({ commit, ref }))
		_ => Err(Unknown)
	}
	_ => Err(Unknown)
}

text_field : List((Str, JsonDoc)), Str -> Try(Str, [Missing])
text_field = |pairs, name| match pairs.find_first(|(field, _)| field == name) {
	Ok((_, Text(text))) => Ok(text)
	_ => Err(Missing)
}

# The fields of the file with `tool` in `tools`: replaced in its place, else the last tool. No `tools` field: the field is the last (R-TF2).
with_tools : List((Str, JsonDoc)), Try(List((Str, JsonDoc)), [NoTools]), ToolsJson.Tool -> List((Str, JsonDoc))
with_tools = |fields, tools, tool| match tools {
	Err(NoTools) => fields.append(("tools", Obj([(tool.key, tool_doc(tool))])))
	Ok(pairs) => {
		merged = if pairs.any(|(key, _)| key == tool.key) {
			pairs.map(|(key, doc)| if key == tool.key (key, merge(doc, tool)) else (key, doc))
		} else {
			pairs.append((tool.key, tool_doc(tool)))
		}
		fields.map(|(name, doc)| if name == "tools" (name, Obj(merged)) else (name, doc))
	}
}

# The old tool with the fields of `tool` in their place. A field of the old tool that Talon does not know stays (R-TF2). The new fields that the old tool lacks follow, in the order of the table.
merge : JsonDoc, ToolsJson.Tool -> JsonDoc
merge = |old, tool| match old {
	Obj(pairs) => {
		fresh = match tool_doc(tool) {
			Obj(fields) => fields
			_ => []
		}
		replaced = pairs.map(
			|(name, doc)| match fresh.find_first(|(key, _)| key == name) {
				Ok((_, new)) => (name, new)
				Err(_) => (name, doc)
			},
		)
		Obj(replaced.concat(fresh.keep_if(|(key, _)| !pairs.any(|(name, _)| name == key))))
	}
	_ => tool_doc(tool)
}

# The tool as the table at the top of this file gives it. A git source has its `path` only with `--path`.
tool_doc : ToolsJson.Tool -> JsonDoc
tool_doc = |tool| Obj([
	("name", Text(tool.name)),
	("source", source_doc(tool)),
	("build", Obj([("hashes", Arr(tool.hashes.map(|h| Text(h)))), ("nightly", Text(tool.nightly)), ("target", Text(tool.target))])),
	("sha256", Text(tool.sha256)),
	("libs", Arr(tool.libs.map(|l| Text(l)))),
	("installed_at", Text(tool.installed_at)),
])

source_doc : ToolsJson.Tool -> JsonDoc
source_doc = |tool| match tool.source {
	Release(rel) => Obj([("kind", Text("release")), ("version", Text(rel.version)), ("url", Text(rel.url))])
	Git(git) => {
		head = [("kind", Text("git")), ("commit", Text(git.commit)), ("ref", Text(git.ref))]
		match tool.path {
			Ok(path) => Obj(head.append(("path", Text(path))))
			Err(None) => Obj(head)
		}
	}
}

# A release build as the tool with all the fields.
release_tool : ToolsJson.Built -> ToolsJson.Tool
release_tool = |built| {
	key: built.key,
	name: built.name,
	source: Release({ version: built.version, url: built.url }),
	path: Err(None),
	hashes: built.hashes,
	nightly: built.nightly,
	target: built.target,
	sha256: built.sha256,
	libs: built.libs,
	installed_at: built.installed_at,
}

render_fields : List((Str, JsonDoc)) -> Str
render_fields = |fields| TalonFile.render({ format: 1, fields })
