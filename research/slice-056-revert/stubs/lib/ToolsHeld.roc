import Fail
import Fx
import Roots

## The bundle hashes that the `[tools]` of known projects name (slice 056, CLI 6.4: R-PT13, R-PT14, R-B4, R-GC4, R-GC7). Command code over `Fx`. `ToolsPlan.held_paths` and `ToolsPlan.held_hashes` decide. `CacheGc` (GC keeps the entry and the package) and `XTake` (the take-over copies and keeps the entry) call it.
##
## | Function | Does | Rule |
## | --- | --- | --- |
## | `of!` | One `read_files!` of `ToolsPlan.held_paths` for the project files (no call for no file). A file that is not there or cannot be read gives no hash: GC never fails for it. | R-PD13, R-PT14 |
## | `all!` | `Known.entries!` (one `read_files!` of `projects.json`, a failure is exit 19), then `of!` for each entry, whatever its age | R-B4, R-PD9 |
ToolsHeld :: [].{

	## The hashes for the project files `files` (the paths of `projects.json`: a header file, or a `talon.toml` that `tln run` recorded). The result is sorted, each hash once.
	of! : Fx, List(Str) => List(Str)
	of! = |_fx, _files| crash "todo: slice 056"

	## R-B4, R-PT13: the hashes of all known projects.
	all! : Fx, Roots => Try(List(Str), Fail)
	all! = |_fx, _roots| crash "todo: slice 056"
}
