import Args
import Fail
import Fx
import Index
import Selector
import ToolBuild

## The take-over of an `x` cache entry by `tln tool install` (slice 049, CLI 6.4: R-B1 to R-B4, R-B7, R-B10, R-NI9, R-CC6, R-ST6, R-ST7, R-ST9, R-T3, R-T26, R-PT13). Command code over `Fx`. `XCache` decides, `XCacheIo` reads the entries.
## `ToolFlow.flow!` calls `online!` after the answer `Build` of `ToolInstall.reuse` (step 7), and `offline!` at its start (with `--offline`) and after a release list that failed with the kind `Network` (no network). The calls, in order (the L2 case `tool/tk1-takeover` fixes them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `XCacheIo.entries!` (the calls of its doc table). | R-B9 |
## | 2 | `XCache.choose` with `installed` `Err(None)` (an installed tool of the same name was decided before: `ToolInstall.reuse`), the target of the machine, and `check`: `Online({ first: <the version of the newest candidate of pick>, listed: <the versions of all candidates> })` for `online!`, `Offline` for `offline!`. `NoMatch`: the result is `Err(NoMatch)` and the flow goes on as before. | R-B1, R-B2, R-B3, R-B10 |
## | 3 online | `Cached(hit)`: on stderr `note: <XCmd.no_data>` (R-C6), then, when `XCache.is_older` of the version of `hit` and the newest candidate, `XCmd.available` with `via` `TakeOver`. | R-B3, R-C6 |
## | 3 offline | `Cached(hit)`: `Mode.from_env`, `Prompt.ask!` with `XCmd.unchecked_prompt` (`TakeOver`): `flag` `Ok(Yes)` for `--allow-unchecked`, `yes` is `--yes`. The prompt is asked before the lock (R-CC3 point 5). `No`: `XCmd.declined`. With no person and no answer: exit 13 (`Prompt.decide`). | R-B7, R-NI9, R-NM5 |
## | 4 | `take!`: `ToolBuild.entry_verdict!` (R-ST6: the bin dir entry before the move, as before the download of a build), one `random!`, `ToolInstall.layout`, then under the lock of `tools.json` (`Fx.locked!`, `Wait`, R-CC6) the steps of the table below. | R-B4, R-ST6 |
##
## `take!` under the lock:
##
## | # | Does | Rule |
## | --- | --- | --- |
## | 1 | `read_files!` of `tools.json`, `ToolsJson.read`, `ToolsJson.clash` again (`Taken`, `Elsewhere`: the failures of `ToolInstall`; `Same(old)`: `Replaced`; `Free`: `Installed`), `ToolBuild.entry_verdict!` again. | R-CC6, R-T28, R-ST6 |
## | 2 | `sha256_file!` of the binary of the entry. It must be the `sha256` of the manifest, else a failure of kind `Integrity` (exit 16, nothing changed; question Q-T3: the design does not say what follows). The check is before the move, so a bad file never replaces an installed binary. | R-B4 |
## | 3 | `make_dirs!` of the data bin dir and the bin dir. `XCache.take_how` (`project_uses` is `Bool.False` until slice 056). `Move`: `rename!` of the binary to `layout.data_tmp`; when it fails, `copy_file!` to the same name. `Copy`: `copy_file!`. Then `rename!` of `data_tmp` to `layout.data_file`. A failed copy: `SetupIo.dropped!`. | R-B4, R-T3, R-CC1 |
## | 4 | `ToolBuild.link_entry!` (the bin dir entry, R-ST7), then `ToolsJson.put` with the tool of the manifest (`installed_at` is the time of Talon) and `write_atomic!` of `tools.json`. | R-ST7, R-ST9, R-T4 |
## | 5 | `Move`: one `delete!` of the entry dir (also after a copy that replaced a failed `rename`). `Copy`: nothing (R-PT13). | R-B4 |
XTake :: [].{

	## What a take-over gives. `Err(NoMatch)`: no entry matches.
	Taken : Try(ToolBuild.Done, [NoMatch])

	## Steps 1 to 4 online. `list` are the candidates of the release list, `newest` is the first candidate of `ToolInstall.pick`.
	online! : Fx, Args, { facts : ToolBuild.Facts, selector : Try(Selector, [None]), list : List(Index.Candidate), newest : Index.Candidate } => Try(Taken, Fail)
	online! = |_fx, _args, _run| crash "todo: slice 049"

	## Steps 1 to 4 offline (R-B7): no resolve and no check. `offline!` asks the prompt R-NI9 for a matching entry.
	offline! : Fx, Args, { facts : ToolBuild.Facts, selector : Try(Selector, [None]) } => Try(Taken, Fail)
	offline! = |_fx, _args, _run| crash "todo: slice 049"
}
