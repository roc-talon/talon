import Args
import Fail
import Fx
import Index

## The command `tln init` (slice 041, R-CM1, CLI 5): a new app or package in the current directory, with the nightly as the `roc:` entry of the header and a CI file.
## It is direct style over `Fx` (TESTING.md 2.2, part C). `Init.read` and `Init.start` are the decisions (part A), `InitText` has the texts.
##
## The steps, in order (the L2 case `init/it1-app` fixes the calls):
##
## | # | Step | Rule |
## | --- | --- | --- |
## | 1 | `Init.read(args)`. A failure is printed as `Common.failed!` does (no `Fx` call). | R-CM1, R-FL12, R-EC2 |
## | 2 | `env_all!`, `Roots.from_env`, `Clock.now!`, `cwd!` | R-EV1, R-EV22 |
## | 3 | `read_files!` of `<cwd>/main.roc`. A file there: failure of kind `Usage` (exit 2), nothing is written. No search up or down (R-PD15). | R-IN7, R-PD15 |
## | 4 | An app: the release list of the platform (`Github.releases!`, `Index.candidates`), `config.toml` for `min-release-age`, `Init.start`. A package has no platform. | R-IN1, R-C7 |
## | 5 | `write_atomic!` of `<cwd>/main.roc` (`InitText.app_file` or `InitText.package_file`): the header has no `roc:` entry | R-IN1, R-IN4, R-IN5 |
## | 6 | The flow of `tln upgrade` on that file: `Update.begin!` (it records the file in `projects.json`, R-PD9) and `Update.resolve!` with `command: Upgrade`, `names: []` (all packages and the nightly are free, R-UP12, R-UP6). The resolve writes the pin. | R-IN2, R-IN3, R-NI12, R-PD9 |
## | 7 | Not `--ci none`: `read_files!` of `<cwd>/.github/workflows/ci.yml`. Not there: `write_atomic!` of it (`InitText.ci_file(Help.version)`). There: it is not written, and the output has the line `note: .github/workflows/ci.yml exists, not written`, exit 0 (answer Q2). | R-IN6, R-IN7 |
## | 7b | A failure in step 6 or 7 (exit 10, 12, 13, a failed download): `delete!` of `<cwd>/main.roc`, which this run made, then the failure. A file that the run did not make is never deleted (answer Q1). | R-IN7 |
## | 8 | The output (below) | R-OUT1 |
##
## The output (a proposal, TW24): the lines of the flow of step 6 and the line R-DT5 (`Update.print!`), then `created main.roc` and, with a CI file, `created .github/workflows/ci.yml` (paths as seen from the current directory). With `--json` the envelope is
## the one of `Update.print!` with `command: "init"`: `data.written` has the files of the flow and then the CI file. The human text goes to stderr with `--json`, as in `Install`.
Init :: [].{

	## The options of an `init` line: the template, the platform name (`named` is `--platform`, a full name `owner/repo`; `Err(Unset)` is `InitText.default_platform`), and the CI file (`--ci`, default `Ci`).
	Plan : { template : [App, Package], named : Try(Str, [Unset]), ci : [Ci, NoCi] }

	## The checks of an `init` line, in this order (each failure has kind `Usage`, exit 2, R-EC2; the texts are a proposal, TW24):
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | 2 or more operands | `tln init takes one template name (app or package), got <n> names` | R-CM1 |
	## | 2 | One operand that is not `app` or `package` | `unknown template '<name>': use app or package` | R-IN1 |
	## | 3 | `--ci` with a value other than `github` or `none` | `--ci must be github or none, not '<value>'` | R-CM1 |
	## | 4 | `--platform` with the template `package` | `--platform does not work with the package template: a package has no platform` | R-IN1 (answer Q4) |
	## | 5 | `--platform` that is not `owner/repo` (a name with no `/`, 2 or more `/`, an empty part, an `@`) | `'<name>' is not a platform name: use owner/repo` | R-IN1 (answer Q6) |
	##
	## No operand is `App`.
	read : Args -> Try(Init.Plan, Fail)
	read = |_args| crash "todo: slice 041"

	## The release that the template starts at (R-IN1, R-IN2, R-C7): from the candidates of the repository, the releases that `min-release-age` does not hide (`published_at + min_age <= now`), in the URL form of the newest of them
	## (`Index.new_entry`, R-DI6), and of those the highest version (`Index.order`). The resolve of the slice then moves it as `tln upgrade` does, so this is only the start. `Err(NoRelease)` when none is left.
	start : { name : Str, list : List(Index.Candidate), now : U64, min_age : U64 } -> Try(Index.Candidate, [NoRelease])
	start = |_facts| crash "todo: slice 041"

	## The exit code of the command. Step 1 first (a failure is printed as `Common.failed!` does), then the steps above.
	##
	## The calls of steps 2 to 7 are fixed by `calls.log` of the L2 case `init/it1-app`. Notes that the log shows: the flow of step 6 calls `env_all!`, `clock!` and `cwd!` again (they are the first calls of `Update.begin!`, which is not changed); `Update.begin!` and `Update.resolve!` get
	## `{ ..args, operands: [], options: [], file: Ok(<cwd>/main.roc) }` and `Opts.read` of that record (`Opts.read` refuses `--platform` with no operand), so the project is found with `--file` and nothing above `<cwd>` is searched; the `Fx` of those two calls is the `shown` one
	## (`Common.shown_fx`), as in `Upgrade.run!`; the consent flags `--allow-downloads` and `--probe-downloads` stay in `options` of that record (answer Q3: `Args.allows` gets `init` for both flags, and `Opts.read` reads them); the min-release-age of step 4 is `config.min_release_age ?? 172800` of one `read_files!` of `config.toml`; the CI file is written after the flow, with one `write_atomic!` and `data.written` gets its absolute path at the end.
	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo: slice 041"
}
