import Args
import Fail
import Fx
import Install
import Known
import Mode
import Opts
import Out
import Report
import Resolve

## The command `tln verify` (R-CM11, R-LB2): resolve in memory, run the probe ladder on the tuple, print the result. It writes no header and no `talon.toml`. Part C (direct style over `Fx`): the wiring of
## `Install.run!`, with `Resolve.verify!` as the flow. `Run.run!` calls it for the command `verify`.
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Verify.read(args)`. A failure is printed with `Out.fail` (no `Fx` call). | R-FL5, R-FL10, R-FL14, Q6 |
## | 2 to 4 | `Install.begin!` | R-EV1, R-EV13, R-EV22, R-PD1 to R-PD8 |
## | 5 | No R-WS12 check: `verify` checks all members of a workspace (the one current member when `--file` names it) | R-PD14 |
## | 6 | `canonical!` and `Known.record!` (R-PD14: `verify` uses a project, R-PD9 records it) | R-PD9 |
## | 7 | `Install.on_path!` (the compiler) | R-SO7, R-PH8 |
## | 8 | `Resolve.verify!` with a `Resolve.Request` (the fields of `Install.run!`: `command` is `Update`, `names` is `[]`, `dry_run` and `frozen` are false) | R-CM11, R-LB2 |
## | 9 | The output (below) | R-J1 to R-J6, R-FL4 |
##
## The output (a proposal, TW24): `Resolve.verify!` prints the ladder lines and the plan (the header path, then `  ~ <alias>: <name> <old> -> <new>` for each entry of the tuple that differs from the header). Then the
## command prints `verified: the tuple passes. Nothing was written.` (the last line, not with `--quiet`). It prints no R-DT5 line. With `--json` the envelope is `Out.json_ok({ command: args.typed, data: Report.data(outcome) })`
## (the `data` of `install`: `written` is `[]`, `dry_run` is false, `added`, `kept`, `toml`, `renamed` and `pinned` are empty). A failure is printed with `Out.fail` and the code is `Exit.choose`.
Verify :: [].{

	## The flags of a `verify` line (R-FL5, R-FL10, R-FL14). The result is `Opts.read` of the line. The checks, in this order (kind `Usage`, exit 2; the texts are a proposal, TW24):
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | The failures of `Opts.read` | the texts of `Opts.read` | R-FL5, R-FL10 |
	## | 2 | `--frozen` | `tln verify writes nothing, so it rejects --frozen` | R-FL14 |
	## | 3 | `--dry-run` | `tln verify writes nothing, so it rejects --dry-run` | R-FL14 |
	## | 4 | One name or more (question Q6) | `tln verify takes no name` | R-CM11 |
	##
	## `--no-check` is read: the ladder is skipped and the run prints `check: skipped` (R-LF3). `--strategy`, `--snapshot`, `--no-probe` and `--slots` are read as `Opts.read` reads them.
	## `Opts.read` runs on the line with `--frozen` taken out (else its own check of `--frozen` with names comes first, and the order of the checks above changes).
	read : Args -> Try(Opts, Fail)
	read = |args| {
		given = |flag| args.options.any(|(name, _)| name == flag)
		opts = Opts.read({ ..args, options: args.options.keep_if(|(name, _)| name != "--frozen") })?
		if given("--frozen") {
			return Err(Fail.new(Usage, "tln verify writes nothing, so it rejects --frozen"))
		}
		if given("--dry-run") {
			return Err(Fail.new(Usage, "tln verify writes nothing, so it rejects --dry-run"))
		}
		if !opts.names.is_empty() {
			return Err(Fail.new(Usage, "tln verify takes no name"))
		}
		Ok(opts)
	}

	run! : Fx, Args => I32
	run! = |fx, args| match Verify.read(args) {
		Err(fail) => Install.failed!(fx, args, fail)
		Ok(opts) => {
			shown = Install.shown_fx(fx, args)
			match flow!(shown, args, opts) {
				Ok(outcome) => {
					shown.out!("verified: the tuple passes. Nothing was written.\n")
					if args.json {
						fx.out!(Out.json_ok({ command: args.typed, data: Report.data(outcome) }))
					}
					0
				}
				Err(fail) => Install.failed!(fx, args, fail)
			}
		}
	}
}

# Steps 2 to 8: the environment, the project, the record, the compiler, and `Resolve.verify!`.
flow! : Fx, Args, Opts => Try(Report.Outcome, Fail)
flow! = |fx, args, opts| {
	start = Install.begin!(fx, args)?
	Install.check_member(Bool.False, start.project)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	compiler = Install.compiler!(fx, start.env, Bool.False)?
	Resolve.verify!(
		fx,
		{
			command: Update,
			names: [],
			frozen: Bool.False,
			no_check: opts.no_check,
			project: start.project,
			roots: start.roots,
			net: start.net,
			now: start.now,
			offline: args.offline,
			strategy: opts.strategy,
			nightly: Install.nightly_of(start.env),
			compiler,
			snapshot: opts.snapshot,
			dry_run: Bool.False,
			add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
			prompt: { mode: Mode.from_env({ env: Dict.from_list(start.env), json: args.json }), yes: args.yes, quiet: args.quiet, rename_keys: Err(NoFlag) },
		},
	)
}
