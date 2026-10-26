import Fail

## Slice 078 (CLI 6.4 R-T4, CLI 6.7 R-ST9, R-ST11, CLI 6.1 R-TF2): the record of the bin dir entries that Talon made. Part A (TESTING.md 2.2): pure decisions on the text of `tools.json`. The command code is in `SetupFlow`, `ToolBuild`, `XTake` and `TalonUpdateFlow`.
## The field is `bin`, an object in the entry of a tool: the name of a bin dir entry (no `.exe`) to the sha256 of the file that Talon put there. The `talon` entry has `tln` and `roc` (R-S6). `format` stays 1 (R-TF2).
##
## ```json
## {"format":1,"tools":{"foo":{"name":"acme/foo", ..., "installed_at":"2026-10-15T12:00:00Z","bin":{"foo":"<64 hex digits>"}},"talon":{"name":"roc-talon/talon", ..., "bin":{"tln":"<64 hex digits>","roc":"<64 hex digits>"}}}}
## ```
##
## | Rule | Text |
## | --- | --- |
## | Place | `bin` is the last field of a new entry. A `bin` that is there stays in its place (R-TF2). |
## | Entry | A tool `<key>` has the name `<key>`. `tln` and `roc` (with `.exe` on Windows: the name has none) are in the entry `talon`. |
## | Time | Talon writes a name each time it makes the entry (R-ST7, R-ST9), after the file is in place: the record of an older file stays until the new file is there. |
BinRecord :: [].{

	## R-ST11 (2): the record of the file. The pairs (name, sha256) of all entries, in the order of the text: the pairs of the first entry that has `bin`, then of the next. A missing file, no `tools` field, an entry with no `bin`, a `bin` that is no object and a value that is no text
	## give no pair (a bad record is no record: the entry is foreign, R-ST6 keeps it, kind of fail-safe). A text that does not parse and a newer `format` are failures of kind `Input` (exit 19) as `ToolsJson.read`: `<path>: the content does not parse`,
	## `<path>: format <n> is newer than this tln (format 1). Run: tln tool update talon`, `<path>: tools is not an object`.
	read : { path : Str, text : Try(Str, [NotFound]) } -> Try(List((Str, Str)), Fail)
	read = |_facts| crash "todo: slice 078"

	## R-T4, R-ST11, R-ST9, R-TF2: the text of the file after the names of `bin` are set in the entry `key`. A name that is there gets the new sha256 in its place, a new name is the last of `bin`, and the other names stay. `bin` is a new last field of an entry that has none.
	## The other entries, the other top-level fields and the other fields of the entry stay as they are, in their place (R-TF2). Nothing to change gives the text byte for byte: an empty `bin` list, a key that is not in `tools`, no `tools` field, and a name with the sha256 that is there.
	## A missing file gives the empty text (as `ToolsJson.drop`). A text that does not parse and a newer `format` are the failures of `read`.
	set : { path : Str, text : Try(Str, [NotFound]), key : Str, bin : List((Str, Str)) } -> Try(Str, Fail)
	set = |_facts| crash "todo: slice 078"

	## R-ST9, R-ST11: `set` for the bin dir entries that setup made, in one step. `made` has the name of each entry in the bin dir (`tln`, `roc`, `foo`; on Windows `tln.exe`) and the sha256 of its file. The name `tln` or `roc` is in the entry `talon`, any other name is in the entry of the same key
	## (`foo.exe` is `foo`; one `.exe` is cut). The pairs of one entry are set together, in the order of `made`. An entry that is not in `tools` is left out (setup records only for an entry that exists). Nothing to change gives the text as it is (the flow writes no file then).
	record_all : { path : Str, text : Try(Str, [NotFound]), made : List({ entry : Str, sha256 : Str }) } -> Try(Str, Fail)
	record_all = |_facts| crash "todo: slice 078"
}
