import Fail
import Fx
import ToolCompiler
import ToolInstall

## Option 2 of the prompt R-NI8: try the installed compiler releases (slice 047, CLI 6.4: R-T17 to R-T21, R-PP2, R-PP3). Command code, direct style over `Fx`. `ToolCompiler` decides, this module orders the calls. The calls, in order
## (the L2 cases `tool/ti3-compiler` and `ti4-nothing` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | For each id in order: `Launch.program!`, then `Launch.touch!` (the id is in `ids`, so it is installed). Then one `Launch.child_env!`. | R-PX6, R-CC9 |
## | 2 | One `probes!` with the pool 12 (the default of `probe.slots`) and one `ToolCompiler.check_spec` for each id, in the order of `ids`: the checks run in one round, at the same time. The result is read in the order of the list (R-PP3). | R-T18, R-PP2, R-PP3 |
## | 3 | `Probe.classify` and `Probe.errors` of each result. One `Facts.save!` with `ToolCompiler.check_row` of each result that has a row (`Replace`): one `db_write!` for the round. | R-T21, R-PP4 |
## | 4 | For each id in order whose check passed, until a build passes: the build of the caller (`build`, the attempt of `ToolFlow`: its header line, `roc build`, no `--target`). One `Facts.save!` with `ToolCompiler.build_row` (no row with no platform hash). | R-T19, R-T21 |
## | 5 | A build that does not pass: `ToolCompiler.tried_of` with the stage `Build`. A check that does not pass: the same with the stage `Check`, in the order of the ids. The result is `Passed` with the first build that passed, else `Failed` with all the failed releases. | R-T19, R-T20 |
##
## `first` of `build` is true for the first build of the command (the caller prints the platform line only then, R-SE8). Each attempt has its own temp dir (`random!`): a failed attempt deletes it, the passed one is kept for the install (`ToolFlow`).
ToolTry :: [].{

	## What option 2 gave. `Passed`: the release `id` built the app, `layout` is the attempt (the output is in `layout.output`). `Failed`: no release built it (an empty list for no release).
	Result : [Passed({ id : Str, layout : ToolInstall.Layout }), Failed(List(ToolCompiler.Tried))]

	## Steps 1 to 5. `ids` are the `ToolCompiler.candidates` (in the order of R-T17). `Err(fail)` is the failure of a call (`Launch.program!`, `Facts.save!` with `TooNew`: exit 19, or a failed build call of the caller).
	installed! : Fx, ToolCompiler.Run, { ids : List(Str), build : { id : Str, first : Bool } => Try(ToolCompiler.Attempt, Fail) } => Try(ToolTry.Result, Fail)
	installed! = |_fx, _run, _tries| crash "todo: slice 047"
}
