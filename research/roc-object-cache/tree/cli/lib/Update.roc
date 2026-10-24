import Args
import Common
import Compiler
import Consent
import Fail
import Fx
import Install
import Known
import Mode
import Net
import Opts
import Out
import Picker
import Project
import Report
import Resolve
import Roots

## The command `tln update` (also `up`, R-CM4, R-CM19): the wiring of a run, in direct style over `Fx` (TESTING.md 2.2, part C). It owns no decision: `Update.read` reads the flags,
## `Resolve.install!` with `command: Update` is the flow of slices 005 to 007, `Picker` and `Consent.picker` decide the picker of `-i`. `Run.run!` calls it for the command `update`, after `Run.check_refs`.
## It is the wiring of `Install.run!` with these differences:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Update.read(args)`. A failure is printed with `Out.fail` (no `Fx` call). | R-FL5, R-FL8 to R-FL10, R-FL13 |
## | 2 to 4 | `Install.begin!`: `env_all!`, `clock!`, the project | R-EV1, R-EV13, R-EV22, R-PD1 to R-PD8 |
## | 5 | No R-WS12 check: `update` works for all members of a workspace (R-SP2). `Install.check_member(false, project)`. | R-WS12 |
## | 6 | `canonical!` and `Known.record!` (as `install`). A run that stops in step 7 has recorded the project. | R-PD9 |
## | 7 | Only with `-i` (R-SP4, R-NI2, R-NM7): `Mode.from_env({ env, json })`. `Consent.picker(mode)`: `Stop(fail)` is the failure (exit 2): no other `Fx` call is made after step 6 (no `path_roc!`, no `roc version`). `NeedTty`: `tty!`, `Mode.with_tty`, then again. `Run`: `Resolve.picks!` (one `read_files!` call), then the ask loop below. | R-SP4, R-SP14, R-NI2, R-NM7 |
## | 8 | Not `--frozen` (it is always false: R-FL13): `Install.on_path!` (the compiler, as `install`) | R-SO7, R-SO9, R-PH8 |
## | 9 | `Resolve.install!` with a `Resolve.Request` (the fields of `Install.run!`: `command` is `Update`, `names` are the operands, or the aliases that the picker gave, `add.no_pin` is `--no-pin`, `add.as_platform` is false, `add.as_alias` is `Err(Unset)`, `prompt.rename_keys` is `Err(NoFlag)`) | R-CM4, R-SP2, R-SP3, R-SP5 |
## | 10 | The output (below) | R-DT5, R-LF4, R-J1 to R-J6, R-FL4 |
##
## The ask loop of step 7 (a proposal, TW24, question Q2): `Picker.text(items)` on stderr (`fx.err!`), then `fx.ask!(Picker.question)`, then `Picker.reply`. An `Invalid` reply asks again (a new `ask`). `EndOfInput` is the failure of
## `Consent.picker(NonInteractive)` (exit 2). An empty pick prints `nothing picked` on stdout (`fx.out!`), calls neither the compiler nor the flow, and the exit code is 0.
## A pick of names is the flow `tln update X Y` (R-SP4: the picked aliases are the operands of step 9).
##
## The output is the one of `Install.run!`: `shown_fx`, the line of `Report.resolved_line` (R-DT5, when something was resolved and planned), the line `dry run: nothing was written` for `--dry-run`, the envelope
## `Out.json_ok({ command: args.typed, data: Report.data(outcome) })` with `--json` (`command` is the word as typed: `update`, `up`). A failure is printed with `Out.fail` and the code is `Exit.choose`.
Update :: [].{

	## The flags of an `update` line (R-FL5, R-FL8 to R-FL10, R-FL12, R-FL13): `opts` is the `Opts.read` of the line (the fields that `update` does not have are false or `Unset`), `pick` is `-i`. The checks, in this order
	## (each failure has kind `Usage`, exit 2, R-EC2; the texts are a proposal, TW24):
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | The failures of `Opts.read` (`--registry`, `--strategy`) | the texts of `Opts.read` | R-FL5, R-FL10 |
	## | 2 | `--frozen` (R-FL13: `update` changes the header) | `flag '--frozen' works only for tln install with no names` | R-FL13 |
	## | 3 | `-i` with one name or more (question Q1) | `update -i picks the packages: do not name packages` | R-NR4 |
	##
	## `--no-pin`, `--no-check`, `--dry-run`, `--snapshot`, `--no-probe` and `--allow-moves` are read as `Opts.read` reads them. `--allow-moves` changes nothing in P0 (design gap G1 of slice 007).
	## `Opts.read` runs on the line with `--frozen` taken out (else its own check of `--frozen` with names comes first, and the order of the checks above changes).
	read : Args -> Try({ opts : Opts, pick : Bool }, Fail)
	read = |args| {
		given = |flag| args.options.any(|(name, _)| name == flag)
		opts = Opts.read({ ..args, options: args.options.keep_if(|(name, _)| name != "--frozen") })?
		if given("--frozen") {
			return Err(Fail.new(Usage, "flag '--frozen' works only for tln install with no names"))
		}
		if given("-i") and !opts.names.is_empty() {
			return Err(Fail.new(Usage, "update -i picks the packages: do not name packages"))
		}
		Ok({ opts, pick: given("-i") })
	}

	run! : Fx, Args => I32
	run! = |fx, args| match Update.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok({ opts, pick }) => {
			shown = Common.shown_fx(fx, args)
			match flow!(shown, args, opts, pick) {
				Ok(Moved(outcome)) => {
					print!(fx, shown, args, opts, outcome)
					0
				}
				Ok(NothingPicked) => {
					shown.out!("nothing picked\n")
					0
				}
				Err(fail) => Common.failed!(fx, args, fail)
			}
		}
	}
}

# Steps 2 to 9: the environment, the project, the record, the picker, the compiler, and `Resolve.install!`.
flow! : Fx, Args, Opts, Bool => Try([Moved(Report.Outcome), NothingPicked], Fail)
flow! = |fx, args, opts, pick| {
	start = Install.begin!(fx, args)?
	Install.check_member(Bool.False, start.project)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	mode = Mode.from_env({ env: Dict.from_list(start.env), json: args.json })
	request = |names, compiler, toolchain| request_of(args, opts, start, names, { compiler, toolchain })
	picked = if pick {
		items = picker_items!(fx, mode, request(opts.names, Err(NoCompiler), Err(Unset)))?
		if items.is_empty() Ok([]) else ask_names!(fx, items)
	} else {
		Ok(opts.names)
	}
	names = picked?
	if pick and names.is_empty() {
		Ok(NothingPicked)
	} else {
		toolchain = Compiler.toolchain_of(start.env)?
		compiler = Install.compiler!(fx, start.roots, Bool.False)
		Ok(Moved(Resolve.install!(fx, request(names, compiler, toolchain))?))
	}
}

# Step 9: the `Resolve.Request` (R-CM4, R-SP2, R-SP3, R-SP5).
request_of : Args, Opts, { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, project : Project }, List(Str), { compiler : Try({ id : Str, path : Str }, [NoCompiler]), toolchain : Try(Str, [Unset]) } -> Resolve.Request
request_of = |args, opts, start, names, selected| {
	command: Update,
	names,
	frozen: Bool.False,
	no_check: opts.no_check,
	project: start.project,
	roots: start.roots,
	net: start.net,
	now: start.now,
	offline: args.offline,
	strategy: opts.strategy,
	nightly: Common.nightly_of(start.env),
	compiler: selected.compiler,
	toolchain: selected.toolchain,
	snapshot: opts.snapshot,
	dry_run: opts.dry_run,
	add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: opts.no_pin },
	prompt: { mode: Mode.from_env({ env: Dict.from_list(start.env), json: args.json }), yes: args.yes, quiet: args.quiet, rename_keys: Err(NoFlag), allow_moves: opts.allow_moves },
	downloads: { auto: Consent.auto_install(start.env), allow: opts.allow_downloads, probe: opts.probe_downloads, env: start.env },
	probe: { no_probe: opts.no_probe, slots: opts.slots },
}

# Step 7, R-NI2, R-NM7: a picker needs a person. The tty is asked only when the mode needs it (R-HF1). Then the free packages (one `read_files!` call).
picker_items! : Fx, Mode, Resolve.Request => Try(List(Picker.Item), Fail)
picker_items! = |fx, mode, request| {
	match Consent.picker(mode) {
		Run => {}
		Stop(fail) => return Err(fail)
		NeedTty => match Consent.picker(Mode.with_tty(mode, fx.tty!())) {
			Run => {}
			Stop(fail) => return Err(fail)
			NeedTty => return Err(Fail.new(Internal, "the mode still needs a tty after the tty check"))
		}
	}
	Resolve.picks!(fx, request)
}

# The ask loop (a proposal, TW24): the list once on stderr, then the question until the reply is valid. The end of input is the failure of a picker with no person.
ask_names! : Fx, List(Picker.Item) => Try(List(Str), Fail)
ask_names! = |fx, items| {
	fx.err!(Picker.text(items))
	ask_again!(fx, items)
}

ask_again! : Fx, List(Picker.Item) => Try(List(Str), Fail)
ask_again! = |fx, items| match fx.ask!(Picker.question) {
	Ok(line) => match Picker.reply({ items, line }) {
		Ok(names) => Ok(names)
		Err(Invalid) => ask_again!(fx, items)
	}
	Err(EndOfInput) => Err(Consent.no_person)
}

# Step 10: the lines after the flow, or the envelope (as `Install.run!`).
print! : Fx, Fx, Args, Opts, Report.Outcome => {}
print! = |fx, shown, args, opts, outcome| {
	planned = !outcome.added.is_empty() or !outcome.moved.is_empty() or outcome.pinned.is_ok() or !outcome.toml.is_empty() or !outcome.renamed.is_empty()
	if planned {
		shown.out!("${Report.resolved_line({ at: outcome.at, probes: outcome.probes })}\n")
	}
	if opts.dry_run {
		shown.out!("dry run: nothing was written\n")
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Report.data(outcome) }))
	}
}
