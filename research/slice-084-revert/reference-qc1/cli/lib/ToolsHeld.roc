import Fail
import Fx
import Known
import Roots
import ToolsPlan

## The bundle hashes that the `[tools]` of known projects name (slice 056, CLI 6.4: R-PT13, R-PT14, R-B4, R-GC4, R-GC7). Command code over `Fx`. `ToolsPlan.held_paths` and `ToolsPlan.held_hashes` decide. `CacheGc` (GC keeps the entry and the package) and `XTake` (the take-over copies and keeps the entry) call it.
##
## | Function | Does | Rule |
## | --- | --- | --- |
## | `of!` | One `read_files!` of `ToolsPlan.held_paths` for the project files (no call for no file). A file that is not there or cannot be read gives no hash: GC never fails for it. | R-PD13, R-PT14 |
## | `all!` | `Known.entries!` (one `read_files!` of `projects.json`, a failure is exit 19), then `of!` for each entry, whatever its age | R-B4, R-PD9 |
ToolsHeld :: [].{

	## The hashes for the project files `files` (the paths of `projects.json`: a header file, or a `talon.toml` that `tln run` recorded). The result is sorted, each hash once.
	of! : Fx, List(Str) => List(Str)
	of! = |fx, files| {
		paths = ToolsPlan.held_paths({ files: files })
		if paths.is_empty() return []
		reads = paths.map2(fx.read_files!(paths), |path, got| (path, got)).keep_oks(
			|(path, got)| match got {
				Ok(text) => Ok({ path, text })
				Err(_) => Err(NoText)
			},
		)
		ToolsPlan.held_hashes({ files, reads })
	}

	## R-B4, R-PT13: the hashes of all known projects.
	all! : Fx, Roots => Try(List(Str), Fail)
	all! = |fx, roots| {
		entries = Known.entries!(fx, roots)?
		Ok(ToolsHeld.of!(fx, entries.map(|entry| entry.path)))
	}
}
