import Fail

## The check before a write of project files (CLI 7.4, R-CC7). The app header, the member files and `talon.toml` have no
## lock: people and editors write them. Talon keeps the text that it read. Just before the `rename` (R-CC1) the command
## code reads each file again and calls `check_all`. The command code cuts the spans (the header of a `.roc` file by
## `roc-app-header`, each table that Talon changes in `talon.toml` by `roc-toml`) and does the span edit (R-H1). This module
## only decides.
Guard :: [].{

	## One file of the write. `read` is the text that Talon read at the start. `now` is the text just before the write.
	## `spans_read` is the text of each span that Talon edits, cut from `read`. `spans_now` is the same spans, cut from
	## `now`, in the same order (they can be at other places in the text).
	##
	## | Case | `how` |
	## | --- | --- |
	## | `read == now` | `Same`: Talon writes |
	## | The text differs, and each span has the same text (`spans_read == spans_now`) | `Reapply`: Talon applies its span edit to `now`, then writes |
	## | Else | A conflict |
	##
	## With 1 or more conflicts, the result is `Err`: nothing is written. The failure has kind `Conflict` (exit 17). The
	## message names each file in the order of the list, and is `<path>[, <path>...] changed while tln ran. Nothing was
	## written. Run the command again.` (a proposal, TW24). With no conflict, the result is the files in the order of the
	## write: each `talon.toml` first, then the other files (`.roc`), each group in the order of the list. A file is a
	## `talon.toml` when its path ends with `/talon.toml`.
	check_all : List({ path : Str, read : Str, now : Str, spans_read : List(Str), spans_now : List(Str) }) -> Try(List({ path : Str, how : [Same, Reapply] }), Fail)
	check_all = |files| {
		conflicts = files.keep_if(|f| f.read != f.now and f.spans_read != f.spans_now).map(|f| f.path)
		if conflicts.is_empty() {
			Ok(write_order(files).map(|f| { path: f.path, how: if f.read == f.now Same else Reapply }))
		} else {
			Err(Fail.new(Conflict, "${Str.join_with(conflicts, ", ")} changed while tln ran. Nothing was written. Run the command again."))
		}
	}
}

# Each `talon.toml` first, then the other files, each group in the order of the list (R-CC1).
write_order : List({ path : Str, read : Str, now : Str, spans_read : List(Str), spans_now : List(Str) }) -> List({ path : Str, read : Str, now : Str, spans_read : List(Str), spans_now : List(Str) })
write_order = |files| files.keep_if(|f| is_toml(f.path)).concat(files.keep_if(|f| !is_toml(f.path)))

is_toml : Str -> Bool
is_toml = |path| path.ends_with("/talon.toml")
