import Args
import Fx

## The command `tln path <alias>` (slice 055, R-CM25, R-PTH1 to R-PTH5, R-PD14, R-PD9): in direct style over `Fx` (TESTING.md 2.2, part C). `PathCmd` has the decisions. `Run.run!` calls it for the command `path`.
##
## The calls, in order (the L2 case `path/pt1-entry` fixes them):
##
## | # | Step | Rule |
## | --- | --- | --- |
## | 1 | `PathCmd.read(args)`. A failure is printed as `Common.failed!` does (no `Fx` call). | R-PTH1, R-EC2 |
## | 2 | `Install.begin!` (environment, time, project) | R-PD14, R-PD1 to R-PD8 |
## | 3 | A workspace root with no current member (answer Q1 of the review): `Install.check_member(Bool.True, project)`, as `add` and `remove`: exit 2 that lists the members. L2 `path/pt1-entry` run 9. | R-PD5, R-WS12 |
## | 4 | `canonical!` and `Known.record!` of the member files: the run records the project, also when it fails later | R-PTH4, R-PD9 |
## | 5 | One `read_files!` of the project file (`Install.begin!` read it before: the log has 2 reads, decision D1), `Locked.read`, `PathCmd.pick`. No other read: a file in the directory of the entry is never read. | R-PTH1, R-PTH3, R-PTH5 |
## | 6 | A release entry: `Fetch.packages!` for its URL (nothing is resolved, no project file is written). A failure is the failure of the run (`--offline` and a missing directory: exit 15). A path entry: no fetch. | R-PTH2, R-FE2, R-FE3, R-FE7 |
## | 7 | The output | R-PTH1, R-J1 to R-J6 |
##
## The output: stdout is the line of `PathCmd.text`, nothing else (also with `--quiet`: it is the answer, R-FL4). With `--json` stdout is the envelope `Out.json_ok({ command: args.typed, data: PathCmd.data(entry) })`. A failure is printed with `Common.failed!`.
PathFlow :: [].{

	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo: slice 055"
}
