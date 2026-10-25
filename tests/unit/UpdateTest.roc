import lib.Args
import lib.Fail
import lib.Update
import lib.Verify

UpdateTest :: [].{}

# The options as a tuple (the `Opts` type has no record with a `Bool` in an `Err`: the compiler of this nightly crashes on it, so the failure is a text).
update_view = |words| match Args.parse(words) {
	Err(stop) => Err(Fail.line(stop.fail))
	Ok(args) => match Update.read(args) {
		Ok({ opts, pick }) => Ok((opts.names, [opts.frozen, opts.dry_run, opts.no_check, opts.no_probe, opts.no_pin, pick], opts.strategy, opts.snapshot, opts.allow_moves))
		Err(f) => Err(Fail.line(f))
	}
}

verify_view = |words| match Args.parse(words) {
	Err(stop) => Err(Fail.line(stop.fail))
	Ok(args) => match Verify.read(args) {
		Ok(opts) => Ok((opts.names, [opts.frozen, opts.dry_run, opts.no_check, opts.no_probe], opts.strategy, opts.snapshot))
		Err(f) => Err(Fail.line(f))
	}
}

# [frozen, dry_run, no_check, no_probe, no_pin, pick]
flags = |on| [on.contains(0), on.contains(1), on.contains(2), on.contains(3), on.contains(4), on.contains(5)]

# R-CM4 R-CM19 R-FL5 R-FL8 R-FL9 R-FL10 R-FL12 R-FL13 R-EC2 R-E4 R-SP4 R-AD28 R-AD22 (question Q1 of slice 009): the options of `update` and `up`, and the 3 failures with the order of their checks (the registry and the strategy, then `--frozen`, then `-i` with a name).
expect {
	frozen = "tln: error[usage]: flag '--frozen' works only for tln install with no names"
	pick_names = "tln: error[usage]: update -i picks the packages: do not name packages"
	rows = [
		(["update"], Ok(([], flags([]), Err(Unset), Err(Unset), Err(NoFlag)))),
		(["up", "json", "parser@^1.1"], Ok((["json", "parser@^1.1"], flags([]), Err(Unset), Err(Unset), Err(NoFlag)))),
		(["update", "-i"], Ok(([], flags([5]), Err(Unset), Err(Unset), Err(NoFlag)))),
		(["update", "json@2.2.0", "--no-pin"], Ok((["json@2.2.0"], flags([4]), Err(Unset), Err(Unset), Err(NoFlag)))),
		(
			["update", "--dry-run", "--no-check", "--no-probe", "--strategy", "lowest", "--snapshot", "2026-10-10T00:00:00Z", "--allow-moves", "--slots", "4"],
			Ok(([], flags([1, 2, 3]), Ok(Lowest), Ok("2026-10-10T00:00:00Z"), Ok(Yes))),
		),
		(["up", "--json", "--yes", "--quiet", "--offline", "--registry", "direct", "--strategy=highest"], Ok(([], flags([]), Ok(Highest), Err(Unset), Err(NoFlag)))),
		(["update", "--frozen"], Err(frozen)),
		(["up", "--frozen", "json"], Err(frozen)),
		(["update", "-i", "json"], Err(pick_names)),
		(["update", "--frozen", "-i", "json"], Err(frozen)),
		(["update", "--strategy", "middle", "--frozen"], Err("tln: error[usage]: --strategy must be highest or lowest, not 'middle'")),
		(["update", "--registry", "https://r.example", "--strategy", "middle", "--frozen"], Err("tln: error[usage]: --registry 'https://r.example': no registry exists in this version of tln. Use --registry direct.")),
	]
	bad = rows.keep_if(|(words, want)| update_view(words) != want).map(|(words, _)| (words, update_view(words)))
	dbg bad
	bad == []
}

# R-CM11 R-FL14 R-FL5 R-FL8 R-FL9 R-FL10 R-FL7 R-EC2 R-E4 R-LB2 (question Q6 of slice 009): the options of `verify`. `--frozen` and `--dry-run` are rejected (it writes nothing), a name is rejected, and the order of the checks is: the registry and the strategy, `--frozen`, `--dry-run`, a name. `--no-check` and `--strategy` are read.
expect {
	rows = [
		(["verify"], Ok(([], [Bool.False, Bool.False, Bool.False, Bool.False], Err(Unset), Err(Unset)))),
		(["verify", "--strategy", "highest", "--json", "--quiet"], Ok(([], [Bool.False, Bool.False, Bool.False, Bool.False], Ok(Highest), Err(Unset)))),
		(["verify", "--no-check", "--no-probe", "--strategy=lowest", "--snapshot", "2026-10-10T00:00:00Z", "--slots", "2"], Ok(([], [Bool.False, Bool.False, Bool.True, Bool.True], Ok(Lowest), Ok("2026-10-10T00:00:00Z")))),
		(["verify", "--frozen"], Err("tln: error[usage]: tln verify writes nothing, so it rejects --frozen")),
		(["verify", "--dry-run"], Err("tln: error[usage]: tln verify writes nothing, so it rejects --dry-run")),
		(["verify", "--dry-run", "--frozen"], Err("tln: error[usage]: tln verify writes nothing, so it rejects --frozen")),
		(["verify", "--frozen", "json"], Err("tln: error[usage]: tln verify writes nothing, so it rejects --frozen")),
		(["verify", "json"], Err("tln: error[usage]: tln verify takes no name")),
		(["verify", "--dry-run", "json"], Err("tln: error[usage]: tln verify writes nothing, so it rejects --dry-run")),
		(["verify", "--strategy", "middle", "--frozen"], Err("tln: error[usage]: --strategy must be highest or lowest, not 'middle'")),
		(["verify", "--registry", "https://r.example", "--frozen"], Err("tln: error[usage]: --registry 'https://r.example': no registry exists in this version of tln. Use --registry direct.")),
	]
	bad = rows.keep_if(|(words, want)| verify_view(words) != want).map(|(words, _)| (words, verify_view(words)))
	dbg bad
	bad == []
}
