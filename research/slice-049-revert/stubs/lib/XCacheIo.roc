import Fail
import Fx
import Roots
import Setup
import XCache

## The files of the `x` cache (slice 049, CLI 6.4: R-X2, R-B9, R-CC1, R-CC11, R-TF3, R-TF6). Command code over `Fx`. `XCache` decides. `XFlow` (`tln x`) and `XTake` (`tln tool install`) call these steps.
## The calls, in order (the L2 cases `x/x1-run`, `x/x2-offline`, `tool/tk1-takeover` and `gc/gc4-x` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | `entries!` 1 | One `list_dirs!` of `<cache>/talon/x` (a missing dir is empty): `Gc.entries`, `XCache.dirs_of`. | R-X2, R-LY1 |
## | `entries!` 2 | With one entry dir or more: one `read_files!` of `XCache.manifest_of(dir)` for each, in the order of the dirs, then `XCache.entries_of`. No call for no dir. | R-B9 |
## | `entries!` 3 | A warning on stderr (`warning: <text>`) for each manifest that gave `Delete`, then one `delete!` of those entry dirs (R-TF6). The entries that `Use` and `Ignore` give no message. | R-TF3, R-TF6 |
## | `entries!` 4 | With one entry or more (after the deletes of step 3): one `list_dirs!` of the entry dirs, in order. An entry whose dir has no file but `manifest.json` gets `has_bin` false (Q-X3). No call for no entry. | R-B1 |
## | `write!` | `copy_file!` of the build output to `layout.temp_bin` (it makes the temp dir), `sha256_file!` of `temp_bin`, one `write_atomic!` of `layout.temp_manifest`, then, when `layout.dir` is in `stale` (an entry with no binary, Q-X3), `delete!` of it, then `rename!` of `layout.temp` to `layout.dir`. `Exists` (another run made the entry first, R-CC11): `delete!` of the temp dir, the entry that is there stays. Any other error: `SetupIo.dropped!` (`delete!` of the temp dir, a failure of kind `Environment`). | R-X2, R-CC1, R-CC11 |
## | `touch!` | One `write_atomic!` of the manifest with the new `last_run` (R-X2: the time of each run). A failed write is a failure of kind `Environment`. | R-X2, R-GC9 |
XCacheIo :: [].{

	## What `write!` made: the entry and its binary.
	Written : { found : XCache.Found, bin : Str }

	## `entries!` 1 to 3: the entries of `talon/x`.
	entries! : Fx, Roots => Try(List(XCache.Found), Fail)
	entries! = |_fx, _roots| crash "todo: slice 049"

	## `write!`: the new entry of a build that passed. `built` is the attempt (`ToolBuild.built!`): its `layout.output` is the binary. `entry` is the manifest. `hex` is `Temp.hex(Fx.random!())`.
	write! : Fx, Roots, { entry : XCache.Entry, output : Str, os : Setup.Os, hex : Str, stale : List(Str) } => Try(XCacheIo.Written, Fail)
	write! = |_fx, _roots, _facts| crash "todo: slice 049"

	## `touch!`: the manifest of `found` with `last_run` set to `last_run` (the time of Talon as `Clock.format_utc`).
	touch! : Fx, XCache.Found, Str => Try({}, Fail)
	touch! = |_fx, _found, _last_run| crash "todo: slice 049"

	## The binary of an entry: `<dir>/<file>` (`XCache.layout`).
	bin_of : { found : XCache.Found, os : Setup.Os } -> Str
	bin_of = |_facts| crash "todo: slice 049"
}
