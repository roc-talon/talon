import Args
import Clock
import Common
import Fail
import Fx
import Known
import Net
import Out
import Project
import Proxy
import RunCmd
import RunFind
import RunPlan
import RunTools
import Roots
import ScriptsToml
import Text
import ToolsToml

## The command `tln run [<name>] [-- <args>]` (slice 057, CLI 1: R-CM24, R-RUN1 to R-RUN12, R-RUN14 to R-RUN17, R-HK1, R-PD9, R-PD16, R-PT8 to R-PT10, R-SE17). Direct style over `Fx` (TESTING.md 2.2 part C): `RunCmd`, `ScriptsToml`, `RunFind` and `RunPlan` decide, this module orders the calls.
## `Run.tln!` calls `run!` for the command `["run"]`, with itself as the function that runs a `tln` step. The command resolves nothing, fetches nothing and writes no project file (R-RUN16). Its one write is `projects.json` (R-PD9). Its one fetch is the build of a project tool that has no binary (R-PT9, `RunTools`).
## No other command reads `[scripts]` (R-RUN15, R-HK1).
##
## The calls, in order (the L2 cases `run/rn1-scripts`, `run/rn2-words`, `run/rn3-tools` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `RunCmd.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-RUN10, R-FL1 |
## | 2 | `env_all!`, `Roots.from_env` (exit 18 for a bad `HOME`), `Clock.now!` (`clock!`, `TALON_NOW`), `cwd!`. | R-EV13, R-EV22 |
## | 3 | `Project.scan!`: `list_dirs!` of each directory of the walk, one `read_files!` of the `talon.toml` files, the `list_dirs!` of the members of the root. Then `RunFind.find` with the scripts of each file (`ScriptsToml.read_table`). On `Need(paths)`: one `read_files!` of the paths (a `NotFound` is "no file"), then `find` again. | R-RUN12, R-PD2, R-PD3 |
## | 4 | R-PD9: the files to record are, for a `Root` file all member files, for a `Member` file the member files of its node, for a `Standalone` file the `main.roc` of its directory when the directory has one, else the `talon.toml` itself (NC1). `canonical!` of them (one call, a path that fails stays as it is), then `Known.record!`. No file: no call. It runs also when a later step fails. | R-PD9, R-PD16, R-PT14 |
## | 5 | No name: the list. `RunTools.table` of the file of `[tools]` (`RunFind.Found.tools_dir`), the warnings of it on stderr, one `programs!` of the keys when there are some, the note `RunPlan.path_note` on stderr for each key that is on `PATH`. stdout: `RunPlan.list_text`, or with `--json` `Out.json_ok` with `RunPlan.list_data`. | R-RUN11 |
## | 6 | A name: `RunTools.table` (warnings on stderr). `RunPlan.plan` before any step. On `Need(dir)`: one `read_files!` of `<dir>/talon.toml`, `ScriptsToml.read_table` (an issue is exit 19, a missing file is `NoFile`), `plan` again. A failure of `plan` is its `Fail` (exit 19). | R-RUN1, R-RUN2, R-RUN4, R-RUN8, R-RUN10 |
## | 7 | Each step in order, a child at a time, until one gives a code that is not 0 (the code of the run, R-RUN7) or `NotStarted` (`RunPlan.start_failed`, exit 18). The program is `RunPlan.program`: `Path`: `exec_in!` of `[<program>] ++ <args>` in the directory of the step with `RunPlan.env`. `Tool`: `RunTools.load!` (once for the run) and `RunTools.bin!`, then `exec_in!` of `[<binary>] ++ <args>` the same way. | R-RUN3, R-RUN5, R-RUN7, R-RUN9, R-PT9 |
## | 7 `roc` | `Roc(args)`: `Proxy.run!` with a `Fx` that has `args!` = `args`, `cwd!` = the directory of the step, `env_all!` = the environment of step 2 and the variables of R-RUN9, `program_name!` = `roc`, and `exec!` = `exec_in!` in the directory of the step with the variables of R-RUN9 added. So the step gets the compiler that the proxy selects (R-RUN3, R-PX1), also when `tln setup` did not run. The derived `Fx` makes no call for these 5 fields: its calls are those of the proxy. | R-RUN3, R-RUN6, R-PX1 |
## | 7 `tln` | `Tln(args)`: the function `tln!` of `Run` with the same derived `Fx`, but `program_name!` = `tln`. | R-RUN3 |
RunFlow :: [].{

	## Steps 1 to 7. The exit code of the run.
	run! : Fx, Args, (Fx => I32) => I32
	run! = |_fx, _args, _tln| crash "todo: slice 057"
}
