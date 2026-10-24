import Args
import Fx

## The command code of `tln outdated` (slice 040, R-CM6, TESTING.md 2.2 part C). The pure part is `Outdated`. It resolves nothing, runs no probe, downloads no archive and no compiler, and writes no header and no `talon.toml`.
##
## The steps of `run!`, in order (the L2 cases `outdated/od1-table` and `outdated/od2-edges` fix the calls):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Outdated.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call) | R-FL5, R-FL7, R-CM6 |
## | 2 | `Install.begin!`, then `Known.record!` of the canonical member files (the only write of the run besides the index cache and the compiler list pins) | R-PD1 to R-PD9, R-PD14 |
## | 3 | `ResolveLoad.load!`: the member files and the `talon.toml` files (one `read_files!`). The members are the current member, else all members (as `tln list`) | R-PD5, R-PD6 |
## | 4 | `Vars.build` for each member: the groups, the ranges, the host | R-ID2, R-I2 to R-I4, R-WS1 |
## | 5 | `PickIndex.index!` for the groups of the `Indexed` hosts, one call for all of them (R-DI1: the rows of `tln outdated` are listed). No call when there is no such group. `--offline` uses the cache pages (R-DI12). | R-DI1, R-DI2, R-DI12 |
## | 6 | `Outdated.versions` for each group | R-C1, R-C6, R-C7, R-UP1 |
## | 7 | Only when a row is behind: the compiler list (`PickLoop.releases!`, at most once), then one `Facts.load!` for the keys (hash, release of D, `any`) of the rows. An empty or unread list gives `Unread` and no query | R-EP11, R-EF1 |
## | 8 | The output (below) | R-J1 to R-J6, R-FL4, R-OUT4 |
##
## Output. The notes of the index (the offline line, the warnings of `Index.candidates`) go to stderr as in the other commands. stdout is `Outdated.text` of each member, or with `--json` only the envelope
## `Out.json_ok({ command: args.typed, data: Outdated.data(members) })`. The answer is not hidden by `--quiet` (R-FL4). The exit code is 0 when the report was made (question Q3). A failure is printed with `Common.failed!`.
OutdatedFlow :: [].{

	## The exit code of the command (the steps above).
	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo"
}
