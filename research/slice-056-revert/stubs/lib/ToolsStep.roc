import Args
import Fail
import Fx
import Index
import JsonDoc
import Net
import ResolveBase
import Roots
import Selector
import Setup
import ToolBuild
import ToolInstall
import ToolsPlan
import ToolsToml
import XCache

## The steps of the project tools that `install`, `update`, `upgrade` and the commands with `--tool` share (slice 056, CLI 6.4: R-PT3 to R-PT7, R-PT12, R-PT15, R-PT16, R-DL7, Resolution R-LF1, R-SO14, R-SO22). Command code over `Fx` (TESTING.md 2.2 part C).
## `ToolsPlan` and `ToolsToml` decide. A tool builds with the path of `tln x` (R-PT6: `ToolFlow` steps, `ToolBuild.built!`, `XCacheIo.write!`) and never touches `tools.json`, the bin dir or the lock of `tools.json` (R-PT12).
##
## The calls of `run!`, in order. Nothing is called when no entry is chosen (so a project with no `[tools]` has the same calls as before this slice):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `platform!` (one call), `BuildSkip.target` | R-X2 |
## | 2 | `XCacheIo.entries!` (its doc table), once | R-B9, R-PT9 |
## | 3 | For each chosen entry, in the order of the file (a failure stops the run, nothing is written): `Frozen`, and `Install` for an entry with a `url`: `ensure!` for the `url`. `Install` for an entry with no `url`, `Update`, `Upgrade`: `pick!`, then (a release that is not the `url` already) `chosen!` and `ensure!` | R-PT4 to R-PT6 |
## | 4 | With a change of `talon.toml` and no `--dry-run`: one `read_files!` of the file, `Guard.check_all`, one `write_atomic!` (`ResolveBase.write_checked!`). One write for all entries | R-CC7, R-CC1, R-PT5 |
## | 5 | The lines on stdout (`lines`) | R-OUT2 |
##
## `pick!` (R-PT4): `ToolFlow.release_list_for!`, `ToolsPlan.visible`, `ToolInstall.pick`, `ToolFlow.notes_for!`. `chosen!`: when the first candidate has an `x` entry (`ToolsPlan.cached`) no more call, else `ToolFlow.first_app_for!` (the fetch of the bundles).
## `ensure!` (R-PT6): a hit of `ToolsPlan.cached` ends it (no fetch, no build). Else `ToolFlow.bundle_for!` (when the bundle was not read), `ToolFlow.platform_for!` (R-PT16), `ToolFlow.choose_for!` (R-X1, R-DL7), `ToolBuild.built!`, `random!`, `XCacheIo.write!`, `delete!` of the temp dir (also after a failure, R-CC2).
ToolsStep :: [].{

	## What a run needs. `home` is the `talon.toml` that holds `[tools]` (`ToolsPlan.home`), `home_text` its text as the command read it (`""` for no file), `tools` the entries of that text.
	Ctx : { args : Args, env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, min_age : U64, probe_timeout : U64, snapshot : Try(U64, [None]), dry_run : Bool, allow : Bool, home : Str, home_text : Str, tools : List(ToolsToml.Entry) }

	## One result. `action` is `Added`, `Locked`, `Moved`, `Built`, `Kept` or `Removed`. A `Kept` row has no line. `would_build` is set by `--dry-run` for a release that has no `x` entry: the real run would build it (D8 of the review).
	Row : { key : Str, name : Str, action : [Added, Locked, Moved, Built, Kept, Removed], ref : Try(Str, [None]), url : Try(Str, [None]), version : Try(Str, [None]), previous : Try(Str, [None]), built : Bool, would_build : Bool }

	## One change of `talon.toml`: the entry `key` gets `ref` and `url`, or the entry `key` goes.
	Change : [Put({ key : Str, ref : Str, url : Str }), Drop(Str)]

	## What a run did: the rows, the changes (written, or planned for `--dry-run`).
	Done : { rows : List(ToolsStep.Row), changes : List(ToolsStep.Change) }

	## R-LF1, R-PT7: the check of `--frozen` for the file of the run. No `Fx` call.
	frozen_check : ResolveBase.Request, ResolveBase.Loaded -> Try({}, Fail)
	frozen_check = |_request, _loaded| crash "todo: slice 056"

	## The `Ctx` of a run of `install`, `update` or `upgrade`: the facts that the flow has already (no `Fx` call).
	ctx_of : Args, ResolveBase.Request, ResolveBase.Loaded -> Try(ToolsStep.Ctx, Fail)
	ctx_of = |_args, _request, _loaded| crash "todo: slice 056"

	## The tools step of `install`, `update` and `upgrade` (R-PT5, R-PT6): `phase` and the `keys` (`[]` is each entry). Prints the lines. `changed` is true when a line was printed (D16 of the review: `InstallFlow` prints `nothing to change` only when the header and the tools both stay as they are).
	after! : Fx, Args, { request : ResolveBase.Request, loaded : ResolveBase.Loaded, phase : ToolsPlan.Phase, keys : List(Str) } => Try({ changed : Bool }, Fail)
	after! = |_fx, _args, _run| crash "todo: slice 056"

	## Steps 1 to 4: the entries `keys` of `ctx.tools` (`[]` is all) in the phase. Nothing is written for `--dry-run`.
	run! : Fx, ToolsStep.Ctx, { phase : ToolsPlan.Phase, keys : List(Str) } => Try(ToolsStep.Done, Fail)
	run! = |_fx, _ctx, _run| crash "todo: slice 056"

	## Step 4 (R-CC7, R-CC1, R-PT5): the changes in one write. The file is read again, the spans of the changed keys are compared with the first read, the new text is made from the text that was read again. No change, or `--dry-run`: no call.
	write! : Fx, ToolsStep.Ctx, List(ToolsStep.Change) => Try({}, Fail)
	write! = |_fx, _ctx, _changes| crash "todo: slice 056"

	## Step 5 (R-OUT2, proposals): the line of each row that changed, then the line of each key that `talon.toml` got (also for `--dry-run`).
	print! : Fx, ToolsStep.Ctx, ToolsStep.Done => {}
	print! = |_fx, _ctx, _done| crash "todo: slice 056"

	## The line of a row (`ToolsPlan.line`). A `Kept` row has none.
	line : ToolsStep.Row -> Try(Str, [None])
	line = |_row| crash "todo: slice 056"

	## The line of the file for a change (`ToolsPlan.file_line`).
	file_line : Str, ToolsStep.Change, List(ToolsStep.Row) -> Str
	file_line = |_path, _change, _rows| crash "todo: slice 056"

	## The `data` rows of `--json` (`ToolsPlan.data`).
	data : Str, List(ToolsStep.Row) -> JsonDoc
	data = |_path, _rows| crash "todo: slice 056"

	## Step 1: the machine facts that the build needs.
	machine! : Fx => Try({ os : Setup.Os, target : Str }, Fail)
	machine! = |_fx| crash "todo: slice 056"

	## The `ToolBuild.Facts` of a tool: no bin dir, no `tools.json` entries (R-PT12). `name` is the full name of the app.
	facts_of : ToolsStep.Ctx, { os : Setup.Os, target : Str }, Str -> ToolBuild.Facts
	facts_of = |_ctx, _machine, _name| crash "todo: slice 056"

	## R-PT4: the list of the releases, the snapshot, the pick and the notes (`ToolFlow.release_list_for!`, `ToolsPlan.visible`, `ToolInstall.pick`, `ToolFlow.notes_for!`). `selector` is `ToolsPlan.selector_for`. No build and no fetch of a bundle.
	pick! : Fx, ToolsStep.Ctx, { machine : { os : Setup.Os, target : Str }, name : Str, selector : Try(Selector, [None]) } => Try({ facts : ToolBuild.Facts, picked : ToolInstall.Picked, newest : Index.Candidate }, Fail)
	pick! = |_fx, _ctx, _run| crash "todo: slice 056"

	## R-PT10 (as `tln tool install`), R-PT9: the release that a pick gives: the newest candidate when its build is in the `x` cache (no fetch) or with `--dry-run` (no fetch), else the first candidate whose bundle is an app (`ToolFlow.first_app_for!`: the fetch of the bundles). `bundle` is `Err(Read)` for the first case.
	chosen! : Fx, ToolsStep.Ctx, { pick : { facts : ToolBuild.Facts, picked : ToolInstall.Picked, newest : Index.Candidate }, found : List(XCache.Found) } => Try({ rel : Release, bundle : Try(ToolBuild.Bundle, [Read]) }, Fail)
	chosen! = |_fx, _ctx, _run| crash "todo: slice 056"

	## R-PT6, R-PT15, R-PT16: the `x` entry of a release. A hit of `ToolsPlan.cached` is done (no fetch, no build). Else the bundle (read when `bundle` is `Err`), the platform, the compiler, the build and the entry. A build that does not pass is the failure of `ToolInstall.build_failed` (nothing is written).
	ensure! : Fx, ToolsStep.Ctx, { facts : ToolBuild.Facts, rel : Release, bundle : Try(ToolBuild.Bundle, [Read]), found : List(XCache.Found) } => Try({ built : Bool, would : Bool, added : List(XCache.Found) }, Fail)
	ensure! = |_fx, _ctx, _run| crash "todo: slice 056"
}

Release : { version : Str, url : Str, hash : Str }
