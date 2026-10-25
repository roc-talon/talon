import Args
import Common
import Fail
import Fx
import Known
import Out
import RunCmd
import RunEach
import RunPlan
import RunTools
import Roots
import ScriptsToml
import Text

## The command `tln run --each [<name>] [--keep-going] [-- <args>]` (slice 058, CLI 1: R-CM24, R-RUN13, R-RUN10, R-EA1 to R-EA8, R-PD9, R-RUN7, R-RUN9). Direct style over `Fx` (TESTING.md 2.2 part C): `RunEach` decides, this module orders the calls.
## `RunFlow.flow!` calls `run!` after `Project.scan!` when the line has `--each`. The command resolves nothing and writes no project file (R-RUN16). Its one write is `projects.json` (R-PD9).
##
## The calls, in order (the L2 case `run/rn4-each` fixes them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | The workspace root of the walk (R-PD3). None: failure of kind `Usage` (exit 2). | R-RUN13 |
## | 2 | One `read_files!` of `RunEach.paths` (the `talon.toml` candidates of the member files: a missing file is no file), then `RunEach.nodes`. No path: no call. | R-EA1, NC4 |
## | 3 | `RunEach.standalone`: when the nearest `talon.toml` of the walk is neither the root nor a node, the start directory is in a standalone project (NC2, NC5, R-PD5): the workspace has no effect, failure of kind `Usage` (exit 2), nothing is recorded. | R-RUN13, NC5 |
## | 4 | R-PD9: `canonical!` of all the member files of the root (one call, a path that fails stays as it is), then `Known.record!`. It runs also when a later step fails. | R-PD9, R-PT14 |
## | 5 | `RunTools.table` of the root file (the `[tools]` of the workspace, R-RUN3), the warnings of it on stderr. | R-RUN3 |
## | 5b | One `read_files!` of `RunEach.header_paths` (the member files of the nodes), then `RunEach.edges` and `RunEach.order`. A failure of them is exit 19 (a header with no or a bad header: exit 2) before the first step (R-EA5). No path: no call. | R-EA2, R-EA3, R-EA5 |
## | 6 | No name: stdout `RunEach.list_text`, or with `--json` `Out.json_ok` with `RunEach.list_data` (R-EA8). Nothing runs. | R-EA8 |
## | 7 | A name: `ScriptsToml.read` of each node (the first bad form is exit 19), the nodes that have the script (in the order of `RunEach.order`), then `RunSteps.plan!` for each of them with the args of `--` (R-RUN10) before any step runs. No node has the script: kind `Usage` (exit 2, question Q2 of the slice file). | R-RUN13, R-RUN1, R-RUN2, R-RUN4, R-RUN8, R-RUN10 |
## | 8 | For each node in order: `skipped` (with `--keep-going`: a line `skipped <node> (after <failed node>)` on stderr), else the line `running <node>` on stderr and `RunSteps.steps!`. A code that is not 0, or a failure of a step (exit 18 and the others, `Common.failed!`), fails the node. Without `--keep-going` the command stops with that code. With it, the run goes on and ends with the code of the first failure. | R-EA7, R-RUN7, R-RUN9 |
RunEachFlow :: [].{

	## What the caller has: the environment, the roots, the clock, and the walk.
	Start : { env : List((Str, Str)), roots : Roots, now : U64, scan : { walk : List({ dir : Str, names : List(Str), toml : Try(Str, [None]) }), root : Try(Str, [NoWorkspace]), members : List(Str) } }

	## Steps 1 to 8. The exit code of the run.
	run! : Fx, Args, RunCmd.Cmd, RunEachFlow.Start, (Fx => I32) => Try(I32, Fail)
	run! = |_fx, _args, _cmd, _start, _tln| crash "todo: slice 058"
}
