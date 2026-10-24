import Args
import Compiler
import Fail
import Fx
import Install
import Known
import Mode
import Out
import Removal
import Report
import Resolve

## The command `tln remove` (also `rm`, R-CM3, R-CM19): the wiring of a run, in direct style over `Fx` (TESTING.md 2.2, part C). It owns no decision: `Removal.opts` reads the flags,
## `Resolve.remove!` is the flow, `Removal.plan` and `Scan` decide, `Report.remove_data` makes the `data` of `--json`. `Run.run!` calls it for the command `remove`, after `Run.check_refs` (W1, W3).
## It is the same wiring as `Install.run!` (slice 007): steps 2 to 7 are the same calls in the same order.
##
## `run!` prints, and gives the exit code (`Exit.choose`). The calls, in order (the L2 case `remove/rm1-flow` fixes them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Removal.opts(args)`. A failure is printed with `Out.fail` (no `Fx` call). | R-FL5, R-FL10, R-FL13, Q2 |
## | 2 | `env_all!` (one call). `Roots.from_env`, `Net.from_env`, `TALON_NIGHTLY`, `TALON_NOW` (as `Install.run!`). | R-EV1, R-EV4, R-EV13, R-EV22 |
## | 3 | `clock!`, then `Clock.now({ talon_now, real })` | R-EV22 |
## | 4 | `Project.find!` with the start `cwd!`, `--file`, and the home dir | R-PD1 to R-PD8 |
## | 5 | A workspace root with no current member is a usage failure that lists the members (the text of `Install.check_member`: `no current member in the workspace at <root>. Members: <file>, <file>. Pass --file <member file>.`). No `Fx` call is made after step 4 for this failure. | R-WS12 |
## | 6 | `canonical!` of the member files that the run reads (the standalone file, or each member of a workspace), then `Known.record!` with `now`. A run that found a project records it, also a run that fails later and a `--dry-run`. | R-PD9, R-CC2, R-CC6 |
## | 7 | The compiler: `Install.on_path!` (`path_roc!`, the cache `path-roc.json`, the launcher test, and `roc version` of the first file that is not the launcher: R-SO9). Each run does it, also with `--no-check` and `--force`, and also a run that fails later (D1 of slice 007). | R-SO7, R-SO9, R-PH6, R-PH8 |
## | 8 | `Resolve.remove!` with a `Resolve.Request` (the fields of `Install.run!`: `command` is `Install`, `names` is `[]`, `frozen` is false, `no_check` and `dry_run` are the flags, the others as for `install`) and `{ names: opts.names, force: opts.force }` | R-CM3, R-RV1 to R-RV5 |
## | 9 | The output (below) | R-LF4, R-J1 to R-J6, R-FL4 |
##
## The output is the one of `Install.run!`. `shown_fx` gives each step a `Fx` with a changed `out!`: with `--json`, `out!` is `err!` (stdout has the one envelope, stderr has the human text). With `--quiet`, `out!` prints nothing, also with `--json`.
## After `Resolve.remove!` gave the `Report.RemoveOutcome`, the command prints, with the same `Fx`, the line `dry run: nothing was written` for `--dry-run` (the last line). With `--json` the envelope is
## `Out.json_ok({ command: args.typed, data: Report.remove_data(outcome) })` on stdout. `command` is the word as typed (`remove`, `rm`). A failure is printed with `Out.fail` and the code is `Exit.choose`. There is no R-DT5 line: a remove resolves nothing (question Q8).
Remove :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match Removal.opts(args) {
		Err(fail) => Install.failed!(fx, args, fail)
		Ok(opts) => {
			shown = Install.shown_fx(fx, args)
			match flow!(shown, args, opts) {
				Ok(outcome) => {
					print!(fx, shown, args, opts, outcome)
					0
				}
				Err(fail) => Install.failed!(fx, args, fail)
			}
		}
	}
}

# Steps 2 to 8: the environment, the project, the record, the compiler, and `Resolve.remove!`.
flow! : Fx, Args, Removal.Opts => Try(Report.RemoveOutcome, Fail)
flow! = |fx, args, opts| {
	start = Install.begin!(fx, args)?
	Install.check_member(Bool.True, start.project)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	toolchain = Compiler.toolchain_of(start.env)?
	compiler = Install.compiler!(fx, start.roots, Bool.False)
	Resolve.remove!(
		fx,
		{
			command: Install,
			names: [],
			frozen: Bool.False,
			no_check: opts.no_check,
			project: start.project,
			roots: start.roots,
			net: start.net,
			now: start.now,
			offline: args.offline,
			strategy: Err(Unset),
			nightly: Install.nightly_of(start.env),
			compiler,
			toolchain,
			snapshot: Err(Unset),
			dry_run: opts.dry_run,
			add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
			prompt: { mode: Mode.from_env({ env: Dict.from_list(start.env), json: args.json }), yes: args.yes, quiet: args.quiet, rename_keys: Err(NoFlag), allow_moves: Err(NoFlag) },
			downloads: { auto: Ask, allow: Err(NoFlag), probe: Err(NoFlag), env: start.env },
		},
		{ names: opts.names, force: opts.force },
	)
}

# Step 9: the last line of a dry run, or the envelope.
print! : Fx, Fx, Args, Removal.Opts, Report.RemoveOutcome => {}
print! = |fx, shown, args, opts, outcome| {
	if opts.dry_run {
		shown.out!("dry run: nothing was written\n")
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Report.remove_data(outcome) }))
	}
}
