import lib.Args
import lib.Fail
import lib.Opts

OptsTest :: [].{}

# The options as a tuple (the `Opts` type has no record with a `Bool` in an `Err`: the compiler of this nightly crashes on it, so the failure is a text).
view = |words| match Args.parse(words) {
	Err(stop) => Err(Fail.line(stop.fail))
	Ok(args) => match Opts.read(args) {
		Ok(o) => Ok((o.names, [o.frozen, o.dry_run, o.no_check, o.no_probe, o.no_pin, o.as_platform], o.as_alias, o.strategy, o.snapshot, [o.rename_keys, o.allow_moves]))
		Err(f) => Err(Fail.line(f))
	}
}

none = [Bool.False, Bool.False, Bool.False, Bool.False, Bool.False, Bool.False]

# R-FL8 R-FL9 R-FL10 R-FL11 R-FL12 R-FL13 R-CM2 R-CM19 R-CM20 R-AD25 R-AD27: the options of `install`, `add` and `i`, which are the same command. The values of the flags with a value, and the global flags that are not options.
expect {
	rows = [
		(["install"], Ok(([], none, Err(Unset), Err(Unset), Err(Unset), [Err(NoFlag), Err(NoFlag)]))),
		(["add", "acme/parser@1.2.3", "--no-pin", "--as", "p"], Ok((["acme/parser@1.2.3"], [Bool.False, Bool.False, Bool.False, Bool.False, Bool.True, Bool.False], Ok("p"), Err(Unset), Err(Unset), [Err(NoFlag), Err(NoFlag)]))),
		(["i", "a/b", "c/d"], Ok((["a/b", "c/d"], none, Err(Unset), Err(Unset), Err(Unset), [Err(NoFlag), Err(NoFlag)]))),
		(
			["install", "--dry-run", "--no-check", "--no-probe", "--strategy", "lowest", "--snapshot", "2026-10-10T00:00:00Z", "--slots", "4"],
			Ok(([], [Bool.False, Bool.True, Bool.True, Bool.True, Bool.False, Bool.False], Err(Unset), Ok(Lowest), Ok("2026-10-10T00:00:00Z"), [Err(NoFlag), Err(NoFlag)])),
		),
		(["install", "--strategy=highest"], Ok(([], none, Err(Unset), Ok(Highest), Err(Unset), [Err(NoFlag), Err(NoFlag)]))),
		(["install", "--rename-keys", "--allow-moves"], Ok(([], none, Err(Unset), Err(Unset), Err(Unset), [Ok(Yes), Ok(Yes)]))),
		(["install", "--json", "--yes", "--quiet", "--offline", "--registry", "direct"], Ok(([], none, Err(Unset), Err(Unset), Err(Unset), [Err(NoFlag), Err(NoFlag)]))),
		(["add", "--platform", "acme/pf@0.2.0"], Ok((["acme/pf@0.2.0"], [Bool.False, Bool.False, Bool.False, Bool.False, Bool.False, Bool.True], Err(Unset), Err(Unset), Err(Unset), [Err(NoFlag), Err(NoFlag)]))),
		# Q8: --frozen writes nothing, so --dry-run adds nothing, and it is no failure.
		(["install", "--frozen", "--dry-run"], Ok(([], [Bool.True, Bool.True, Bool.False, Bool.False, Bool.False, Bool.False], Err(Unset), Err(Unset), Err(Unset), [Err(NoFlag), Err(NoFlag)]))),
		(["install", "--frozen"], Ok(([], [Bool.True, Bool.False, Bool.False, Bool.False, Bool.False, Bool.False], Err(Unset), Err(Unset), Err(Unset), [Err(NoFlag), Err(NoFlag)]))),
	]
	bad = rows.keep_if(|(words, want)| view(words) != want).map(|(words, _)| (words, view(words)))
	dbg bad
	bad == []
}

# R-FL13 R-FL5 R-FL10 R-AD29 R-EC2 R-E4 (questions Q3, Q6): the failures of the options, all usage (exit 2). The order of the checks: the registry, the strategy, `--frozen` with names, `--platform` with the wrong count of names.
expect {
	frozen = "tln: error[usage]: flag '--frozen' works only for tln install with no names"
	rows = [
		(["install", "--frozen", "acme/json"], Err(frozen)),
		(["add", "--frozen", "a/b", "c/d"], Err(frozen)),
		(["add", "--platform"], Err("tln: error[usage]: flag '--platform' names one entry: got 0 names")),
		(["add", "--platform", "a/b", "c/d"], Err("tln: error[usage]: flag '--platform' names one entry: got 2 names")),
		(["install", "--strategy", "middle"], Err("tln: error[usage]: --strategy must be highest or lowest, not 'middle'")),
		(["install", "--registry", "https://registry.example"], Err("tln: error[usage]: --registry 'https://registry.example': no registry exists in this version of tln. Use --registry direct.")),
		(["install", "--registry", "https://r.example", "--strategy", "middle", "--frozen", "a/b"], Err("tln: error[usage]: --registry 'https://r.example': no registry exists in this version of tln. Use --registry direct.")),
		(["install", "--strategy", "middle", "--frozen", "a/b"], Err("tln: error[usage]: --strategy must be highest or lowest, not 'middle'")),
		(["install", "--frozen", "--platform"], Err("tln: error[usage]: flag '--platform' names one entry: got 0 names")),
	]
	bad = rows.keep_if(|(words, want)| view(words) != want).map(|(words, _)| (words, view(words)))
	dbg bad
	bad == []
}

# R-NI4 R-NI5 R-FL12 R-DL5 (slice 025): the answer flags of the download prompts. `--allow-downloads` answers the required download of the first probe (R-NI5) and `--probe-downloads` answers the optional downloads (R-NI4). Each is `Ok(Yes)` when set,
# for each command that resolves (`Opts.read` is the one reader of `install`, `add`, `update` and `verify`). A flag on a command that does not name it is the failure of `Args.parse` (R-FL12, tested in `tests/unit/args.roc`).
expect {
	flags = |words| match Args.parse(words) {
		Err(stop) => Err(Fail.line(stop.fail))
		Ok(args) => match Opts.read(args) {
			Ok(o) => Ok([o.allow_downloads, o.probe_downloads])
			Err(f) => Err(Fail.line(f))
		}
	}
	rows = [
		(["install"], Ok([Err(NoFlag), Err(NoFlag)])),
		(["install", "--allow-downloads"], Ok([Ok(Yes), Err(NoFlag)])),
		(["add", "json", "--allow-downloads"], Ok([Ok(Yes), Err(NoFlag)])),
		(["update", "json", "--allow-downloads"], Ok([Ok(Yes), Err(NoFlag)])),
		(["verify", "--allow-downloads"], Ok([Ok(Yes), Err(NoFlag)])),
		(["install", "--yes"], Ok([Err(NoFlag), Err(NoFlag)])),
		# R-NI4 R-FL12 (slice 069): `--probe-downloads` is read for `upgrade`, `probe` and `init` only. The other commands stop in `Args.parse`.
		(["upgrade", "--probe-downloads"], Ok([Err(NoFlag), Ok(Yes)])),
		(["upgrade", "roc", "--allow-downloads", "--probe-downloads"], Ok([Ok(Yes), Ok(Yes)])),
		(["probe", "--probe-downloads"], Ok([Err(NoFlag), Ok(Yes)])),
		(["init", "--probe-downloads", "--allow-downloads"], Ok([Ok(Yes), Ok(Yes)])),
		(["install", "--probe-downloads"], Err("tln: error[usage]: flag '--probe-downloads' is not for 'install'")),
		(["add", "json", "--allow-downloads", "--probe-downloads"], Err("tln: error[usage]: flag '--probe-downloads' is not for 'install'")),
		(["verify", "--probe-downloads", "--allow-downloads"], Err("tln: error[usage]: flag '--probe-downloads' is not for 'verify'")),
	]
	bad = rows.keep_if(|(words, want)| flags(words) != want).map(|(words, _)| (words, flags(words)))
	dbg bad
	bad == []
}

# R-NI4 R-FL12 (slice 069): `Opts.read` does not read `--probe-downloads` for a command that the flag table does not name. `Args.parse` stops that line first (the rows above), so this row is a second guard:
# the parsed line of `upgrade` gets the command words of another command, and the flag is not read. A line of `upgrade`, `probe` or `init` with the same flag is read.
expect {
	read_as = |words, command| match Args.parse(words) {
		Err(stop) => Err(Fail.line(stop.fail))
		Ok(args) => match Opts.read({ ..args, command: command }) {
			Ok(o) => Ok(o.probe_downloads)
			Err(f) => Err(Fail.line(f))
		}
	}
	line = ["upgrade", "--probe-downloads"]
	rows = [
		(["upgrade"], Ok(Ok(Yes))),
		(["probe"], Ok(Ok(Yes))),
		(["init"], Ok(Ok(Yes))),
		(["install"], Ok(Err(NoFlag))),
		(["update"], Ok(Err(NoFlag))),
		(["verify"], Ok(Err(NoFlag))),
		(["remove"], Ok(Err(NoFlag))),
	]
	bad = rows.keep_if(|(command, want)| read_as(line, command) != want).map(|(command, _)| (command, read_as(line, command)))
	dbg bad
	bad == []
}

# R-FL11 R-PP7 R-FL7 R-EC2 (slice 031): `--slots <n>` (or `--slots=<n>`) is the flag layer of the pool size, for each command that resolves (`Opts.read` reads `install`, `add`, `update` and `verify`). Not given: `Unset`. A value that is not a whole
# number of 1 or more is a usage failure (exit 2). A flag with no value is the failure of `Args.parse` (tested in `args.roc`).
expect {
	slots = |words| match Args.parse(words) {
		Err(stop) => Err(Fail.line(stop.fail))
		Ok(args) => match Opts.read(args) {
			Ok(o) => Ok(o.slots)
			Err(f) => Err(Fail.line(f))
		}
	}
	bad = |text| Err("tln: error[usage]: --slots must be a whole number of 1 or more, not '${text}'")
	rows = [
		(["install"], Ok(Err(Unset))),
		(["install", "--slots", "4"], Ok(Ok(4))),
		(["update", "json", "--slots=3"], Ok(Ok(3))),
		(["verify", "--slots", "1", "--no-probe"], Ok(Ok(1))),
		(["add", "acme/json", "--slots", "12"], Ok(Ok(12))),
		(["install", "--slots", "0"], bad("0")),
		(["install", "--slots", "many"], bad("many")),
		(["update", "--slots", "2.5"], bad("2.5")),
	]
	wrong = rows.keep_if(|(words, want)| slots(words) != want).map(|(words, want)| (words, want, slots(words)))
	dbg wrong
	wrong == []
}
