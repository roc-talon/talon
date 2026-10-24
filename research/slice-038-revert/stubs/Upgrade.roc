import Args
import Fail
import Fx
import Opts

## The command `tln upgrade` for packages (slice 038, R-CM5, Resolution 10): the wiring of a run, in direct style over `Fx` (TESTING.md 2.2, part C). It is the wiring of `Update.run!` with these differences:
##
## | Step | Difference | Rule |
## | --- | --- | --- |
## | 1 | `Upgrade.read(args)`: `--strategy lowest` is a usage failure, `roc` as a name is not built yet (slice 039) | R-UP8, R-SP8, R-SP9 |
## | 2 | No picker (`-i` is not a flag of `upgrade`) | R-FL12 |
## | 3 | `Resolve.install!` with `command: Upgrade`. The packages are free with no range and in any series (`Vars.scope`), the nightly is held (slice 039 frees it), the ranges of `talon.toml` move with the versions (`Lags.rewrites`), the variables that did not get their newest release are notes (`Lags.of`). | R-SP6, R-SP7, R-UP1 to R-UP5, R-UP12, R-UP13 |
##
## The output is the output of `Update.run!`: the lines of the flow, the line R-DT5, `dry run: nothing was written`, and the envelope of `--json`.
Upgrade :: [].{

	## The flags of an `upgrade` line (R-FL5, R-FL8 to R-FL10, R-FL13, R-UP8). The checks, in this order (each failure has kind `Usage`, exit 2, R-EC2, except the last; the texts are a proposal, TW24):
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | The failures of `Opts.read` (`--registry`, `--strategy`) | the texts of `Opts.read` | R-FL5, R-FL10 |
	## | 2 | `--frozen` | `flag '--frozen' works only for tln install with no names` | R-FL13 |
	## | 3 | `--strategy lowest` | `--strategy lowest does not work with tln upgrade: upgrade only moves up` | R-UP8 |
	## | 4 | A name with a selector (`json@^3`) (review of Q4) | `tln upgrade does not take a selector: '<name>'. Use tln update <name>` | R-SL5 |
	## | 5 | The name `roc` (kind `Internal`, slice 039 builds it) | `tln upgrade roc is not built yet` | R-SP8, R-SP9 |
	read : Args -> Try({ opts : Opts }, Fail)
	read = |_x| crash "todo"

	## The exit code of the command. `Upgrade.read` first (a failure is printed as `Common.failed!` does). Then the steps of `Update.run!` (`Install.begin!`, `Install.check_member`, `Known.record!`, `Compiler.toolchain_of`, `Install.compiler!`)
	## and `Resolve.install!` with `command: Upgrade`, `frozen: Bool.False`, `add` with no platform and no alias. The prints are the ones of `Update.run!`.
	run! : Fx, Args => I32
	run! = |_x, _y| crash "todo"
}
