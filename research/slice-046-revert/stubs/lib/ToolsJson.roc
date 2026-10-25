import Fail
import Lookup

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
	read = |_facts| crash "todo: slice 046"

	## The text of the file after the tool `built` is added, or replaces the tool with the same key (R-T26, R-T27). `text` is the file as it is now. The other tools and the other top-level fields stay as they are (R-TF2), in their
	## place; a new tool is the last of `tools`. A replaced tool keeps the fields that Talon does not know, in their place (R-TF2); the fields of the table are the new ones. A file with no `tools` field gets the field at the end. A failure is the one of `read` for the parts that it reads (`TalonFile.open`).
	add : { path : Str, text : Try(Str, [NotFound]), built : Built } -> Try(Str, Fail)
	add = |_facts| crash "todo: slice 046"

	## The decision of the table of `Clash`. `entries` are the tools of the file, `key` is the binary name that the install wants, `name` is the full name of the app.
	clash : { entries : List(Entry), key : Str, name : Str } -> Clash
	clash = |_facts| crash "todo: slice 046"

	## R-SC3: the tools as the entities of a name lookup (`Lookup.find` with the scope `Tool`). `alias` is the key (the binary name), `name` the full name. A release tool has its version and its series (`Ident.series_of`). A git tool has no version
	## (`Err(None)`) and no series. `note` is the empty text.
	entities : List(Entry) -> List(Lookup.Entity)
	entities = |_entries| crash "todo: slice 046"
}
