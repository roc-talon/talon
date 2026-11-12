import Args
import Channel
import Clock
import Common
import Fail
import Fx
import JsonDoc
import NightlyPlan
import ManageUse
import Opts
import Out
import Report
import RocUse
import ShareHook
import Update

## The command `tln upgrade` for packages (slice 038, R-CM5, Resolution 10): the wiring of a run, in direct style over `Fx` (TESTING.md 2.2, part C). It is the wiring of `Update.run!` with these differences:
##
## | Step | Difference | Rule |
## | --- | --- | --- |
## | 1 | `Upgrade.read(args)`: `--strategy lowest` is a usage failure, `roc` is a name (slice 039) | R-UP8, R-SP8, R-SP9 |
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
	## | 5 | `--no-check` with a free nightly (no names, or the name `roc`, slice 039). Slice 039 replaces the `Internal` failure of the name `roc` with this check | `--no-check does not work when tln upgrade moves the nightly: the roc pin moves only after the check. Name the packages to hold the nightly: tln upgrade <name> --no-check` | R-UP9, R-EC2 |
	read : Args -> Try({ opts : Opts }, Fail)
	read = |args| {
		given = |flag| args.options.any(|(name, _)| name == flag)
		opts = Opts.read({ ..args, options: args.options.keep_if(|(name, _)| name != "--frozen") })?
		if given("--frozen") {
			return Err(Fail.new(Usage, "flag '--frozen' works only for tln install with no names"))
		}
		match opts.strategy {
			Ok(Lowest) => return Err(Fail.new(Usage, "--strategy lowest does not work with tln upgrade: upgrade only moves up"))
			_ => {}
		}
		match opts.names.find_first(|name| name.contains("@")) {
			Ok(name) => return Err(Fail.new(Usage, "tln upgrade does not take a selector: '${name}'. Use tln update ${name}"))
			Err(_) => {}
		}
		if opts.no_check and NightlyPlan.scope(opts.names).nightly == Free {
			return Err(Fail.new(Usage, "--no-check does not work when tln upgrade moves the nightly: the roc pin moves only after the check. Name the packages to hold the nightly: tln upgrade <name> --no-check"))
		}
		Ok({ opts: opts })
	}

	## The exit code of the command. `Upgrade.read` first (a failure is printed as `Common.failed!` does). Then the steps of `Update.run!` (`Install.begin!`, `Install.check_member`, `Known.record!`, `Compiler.toolchain_of`, `Install.compiler!`)
	## and `Resolve.install!` with `command: Upgrade`, `frozen: Bool.False`, `add` with no platform and no alias. The prints are the ones of `Update.run!`.
	run! : Fx, Args => I32
	run! = |fx, args| match Upgrade.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok({ opts }) => {
			shown = Common.shown_fx(fx, args)
			got = Update.begin_toml!(shown, args)
			begun = got.map_ok(|g| g.start)
			# Slice 243 (R-CH15): `tln upgrade roc` on `[toolchain] roc = "=<user id>"` runs the check loop over the builds of that channel and writes talon.toml.
			held_user = match got {
				Ok(g) if opts.names == ["roc"] => match g.toml {
					Ok(text) => match Channel.pin_text(text) {
						Ok(value) => match Channel.user_range(value) {
							Ok(Exactly(id)) => Ok(id)
							_ => Err(None)
						}
						Err(_) => Err(None)
					}
					Err(NoToml) => Err(None)
				}
				_ => Err(None)
			}
			match held_user {
				Ok(held) => match begun {
					Ok(start) => return match RocUse.upgrade_user!(shown, args, start, { held, dry_run: opts.dry_run }) {
						Ok(done) => {
							print_user!(fx, shown, args, start.now, done)
							0
						}
						Err(fail) => Common.failed!(fx, args, fail)
					}
					Err(fail) => return Common.failed!(fx, args, fail)
				}
				Err(_) => {}
			}
			result = match begun {
				Ok(start) => Update.resolve!(shown, args, opts, start, { command: Upgrade, names: opts.names, fixed: [], fresh: Bool.False })
				Err(fail) => Err(fail)
			}
			match result {
				Ok(done) => {
					Update.print!(fx, shown, args, opts, done)
					ShareHook.send!(fx, done.ran, 0)
					0
				}
				Err(fail) => ShareHook.failed!(fx, args, fail)
			}
		}
	}
}

# Slice 243 (R-CH15, TW24 proposal): the lines of `tln upgrade roc` on a user pin. `Newest`: `<id> is the newest`. A move: the root `talon.toml` and `  ~ [toolchain] roc: =<old> -> =<new>`, then `resolved at <time>, <n> probes` (and `dry run: nothing was written`).
# With `--json` the human text goes to stderr and stdout is the envelope; `data` is the `data` of `roc use`.
print_user! : Fx, Fx, Args, U64, [Newest(Str), Kept({ note : Try(Str, [None]) }), Moved({ id : Str, old : Str, file : Str, written : Bool, probes : U64, downloads : U64, built : Bool, notes : List(Str), skipped : Try(Str, [None]) })] => {}
print_user! = |fx, shown, args, now, done| match done {
	Newest(id) => {
		shown.out!("${id} is the newest\n")
		if args.json {
			fx.out!(Out.json_ok({ command: args.typed, data: JsonDoc.Obj([("id", JsonDoc.Text(id)), ("changed", JsonDoc.Flag(Bool.False))]) }))
		}
	}
	Kept(_) => {
		# As `upgrade roc` when no later nightly works (ur5-optional): the note, `nothing to change`, exit 0.
		shown.out!("nothing to change\n")
		if args.json {
			fx.out!(Out.json_ok({ command: args.typed, data: JsonDoc.Obj([("changed", JsonDoc.Flag(Bool.False)), ("notes", JsonDoc.Arr([]))]) }))
		}
	}
	Moved(moved) => {
		match moved.skipped {
			Ok(text) => shown.out!("note: ${text}\n")
			Err(None) => {}
		}
		shown.out!("${moved.file}\n")
		shown.out!("  ~ [toolchain] roc: ${moved.old} -> =${moved.id}\n")
		shown.out!("${Report.resolved_line({ at: Clock.format_utc(now), log: Err(None), probes: moved.probes })}\n")
		if !moved.written {
			shown.out!("dry run: nothing was written\n")
		}
		if args.json {
			files = if moved.written [{ file: moved.file, previous: Ok(moved.old) }] else []
			fx.out!(Out.json_ok({ command: args.typed, data: ManageUse.use_data({ id: moved.id, files, probes: moved.probes, downloads: moved.downloads, built: moved.built, notes: moved.notes }) }))
		}
	}
}
