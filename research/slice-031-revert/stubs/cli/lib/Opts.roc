import Answer
import Args
import Fail

## The flags of `tln install` (and `add`, `i`) as data (CLI 1, R-FL5, R-FL8 to R-FL14, R-FL12, R-AD28). `Args.parse` has checked that each flag is
## allowed for the command (slice 001). This module reads the values and checks the facts that need the operands. All of it is part A (pure).
##
## | Field | Holds |
## | --- | --- |
## | `names` | The operands of the command: the refs to add. No name: the command keeps the header (R-SP18). |
## | `frozen`, `dry_run`, `no_check`, `no_probe`, `no_pin` | The flags of the same name |
## | `as_platform` | `--platform` (the ref is the platform, R-AD29) |
## | `as_alias` | The value of `--as` |
## | `strategy` | The value of `--strategy`: `highest` or `lowest` (R-FL10) |
## | `snapshot` | The text of `--snapshot` (R-FL9). `Resolve` checks the form (`Intent.direct_snapshot`). |
## | `rename_keys` | `--rename-keys`: `Ok(Yes)` when set (R-NI1 answer flag) |
## | `allow_moves` | `--allow-moves`: `Ok(Yes)` when set (R-NI3 answer flag) |
## | `allow_downloads` | `--allow-downloads`: `Ok(Yes)` when set (R-NI5 answer flag, slice 025) |
## | `probe_downloads` | `--probe-downloads`: `Ok(Yes)` when set (R-NI4 answer flag, slice 025) |
Opts := {
	names : List(Str),
	frozen : Bool,
	dry_run : Bool,
	no_check : Bool,
	no_probe : Bool,
	no_pin : Bool,
	as_platform : Bool,
	as_alias : Try(Str, [Unset]),
	strategy : Try([Highest, Lowest], [Unset]),
	snapshot : Try(Str, [Unset]),
	rename_keys : Try(Answer, [NoFlag]),
	allow_moves : Try(Answer, [NoFlag]),
	allow_downloads : Try(Answer, [NoFlag]),
	probe_downloads : Try(Answer, [NoFlag]),
	slots : Try(U64, [Unset]),
}.{
	is_eq : _

	## Reads the options of an `install` line. Each failure has the kind `Usage` (exit 2, R-EC2). The texts are a proposal (TW24). The checks, in this order:
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | `--registry` with a value other than `direct` (P0 has only `direct`, question Q6) | `--registry '<value>': no registry exists in this version of tln. Use --registry direct.` | R-FL5, R-RG2 |
	## | 2 | `--strategy` with a value other than `highest` or `lowest` | `--strategy must be highest or lowest, not '<value>'` | R-FL10 |
	## | 3 | `--frozen` with one name or more (`install` with names changes the header) | `flag '--frozen' works only for tln install with no names` | R-FL13 |
	## | 4 | `--platform` with no name or with 2 or more names (question Q3) | `flag '--platform' names one entry: got <n> names` | R-AD29 |
	## | 5 | Slice 031: `--slots` with a value that is not a whole number of 1 or more (question Q6) | `--slots must be a whole number of 1 or more, not '<value>'` | R-FL11 |
	##
	## Slice 031 (R-FL11, R-PP7): `slots` is the value of `--slots <n>` (or `--slots=<n>`), `Err(Unset)` when the flag is not given. It is the flag layer of `Probe.settings`.
	## `--dry-run` with `--frozen` is allowed (question Q8). `--no-pin` with no exact version is ignored (slice 004, Q8). `--slots` and `--no-probe` are read and
	## change nothing in P0 (R-LF2: no unit probe). `--yes`, `--json` and the other global flags are not options of the command: `Args` has them.
	read : Args -> Try(Opts, Fail)
	read = |args| {
		check_registry(args)?
		strategy = strategy_of(args)?
		given = |flag| args.options.any(|(name, _)| name == flag)
		count = args.operands.len()
		if given("--frozen") and count > 0 {
			return Err(Fail.new(Usage, "flag '--frozen' works only for tln install with no names"))
		}
		if given("--platform") and count != 1 {
			return Err(Fail.new(Usage, "flag '--platform' names one entry: got ${count.to_str()} names"))
		}
		Ok({
			names: args.operands,
			frozen: given("--frozen"),
			dry_run: given("--dry-run"),
			no_check: given("--no-check"),
			no_probe: given("--no-probe"),
			no_pin: given("--no-pin"),
			as_platform: given("--platform"),
			as_alias: value_of(args, "--as"),
			strategy,
			snapshot: value_of(args, "--snapshot"),
			rename_keys: if given("--rename-keys") Ok(Yes) else Err(NoFlag),
			allow_moves: if given("--allow-moves") Ok(Yes) else Err(NoFlag),
			allow_downloads: if given("--allow-downloads") Ok(Yes) else Err(NoFlag),
			probe_downloads: if given("--probe-downloads") Ok(Yes) else Err(NoFlag),
			slots: Err(Unset),
		})
	}
}

# The value of a flag that has one, or `Unset`.
value_of : Args, Str -> Try(Str, [Unset])
value_of = |args, flag| match args.options.find_first(|(name, _)| name == flag) {
	Ok((_, value)) => value
	Err(NotFound) => Err(Unset)
}

# R-FL5, R-RG2: P0 has only `direct`.
check_registry : Args -> Try({}, Fail)
check_registry = |args| match args.registry {
	Ok(value) if value != "direct" => Err(Fail.new(Usage, "--registry '${value}': no registry exists in this version of tln. Use --registry direct."))
	_ => Ok({})
}

# R-FL10
strategy_of : Args -> Try(Try([Highest, Lowest], [Unset]), Fail)
strategy_of = |args| match value_of(args, "--strategy") {
	Err(Unset) => Ok(Err(Unset))
	Ok("highest") => Ok(Ok(Highest))
	Ok("lowest") => Ok(Ok(Lowest))
	Ok(other) => Err(Fail.new(Usage, "--strategy must be highest or lowest, not '${other}'"))
}
