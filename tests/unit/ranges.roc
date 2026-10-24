app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Ranges

main! = |_args| Ok({})

# R-I4 R-I7: the range that a header version implies when `talon.toml` has no key for it: the same series (R-ID1), never lower than the header
# version. Below 1.0 the series is `0.<minor>`. R-TF4: a text that is not a range is `BadRange`. R-I7 R-C1: a caret range matches the version and
# each newer version of its series; the ranges of a list are an intersection; a pre-release version is never admitted.
expect {
	implied = [
		("0.25.0", Ok(">=0.25.0, <0.26.0")),
		("2.1.0", Ok(">=2.1.0, <3.0.0")),
		("0.0.3", Ok(">=0.0.3, <0.1.0")),
		("1.0.0", Ok(">=1.0.0, <2.0.0")),
		("10.9.8", Ok(">=10.9.8, <11.0.0")),
		("2.1", Err(BadVersion)),
		("latest", Err(BadVersion)),
		("", Err(BadVersion)),
	]
	bad_implied = implied.keep_if(|(v, want)| Ranges.implied(v) != want).map(|(v, want)| (v, want, Ranges.implied(v)))
	dbg bad_implied

	checks = [
		("^2.1", Bool.True),
		("=2.0.0", Bool.True),
		("0.25.*", Bool.True),
		("*", Bool.True),
		(">=1.2, <1.5", Bool.True),
		("2", Bool.True),
		("~1.2", Bool.True),
		("latest", Bool.False),
		("", Bool.False),
		("^", Bool.False),
		("1.2.3.4", Bool.False),
		("=nightly-2026-10-09-258ab27", Bool.False),
		(">=nightly-2026-10-09-258ab27", Bool.False),
	]
	bad_checks = checks.keep_if(|(t, want)| (Ranges.check(t) == Ok({})) != want).map(|(t, want)| (t, want))
	dbg bad_checks

	admits = [
		(["^2.1"], "2.1.0", Bool.True),
		(["^2.1"], "2.9.9", Bool.True),
		(["^2.1"], "2.0.9", Bool.False),
		(["^2.1"], "3.0.0", Bool.False),
		(["^0.25.1"], "0.25.1", Bool.True),
		(["^0.25.1"], "0.25.9", Bool.True),
		(["^0.25.1"], "0.26.0", Bool.False),
		(["0.25.*"], "0.25.3", Bool.True),
		(["=2.0.0"], "2.0.0", Bool.True),
		(["=2.0.0"], "2.0.1", Bool.False),
		([">=2.1.0, <3.0.0", "^2.3"], "2.2.0", Bool.False),
		([">=2.1.0, <3.0.0", "^2.3"], "2.3.0", Bool.True),
		([], "9.9.9", Bool.True),
		(["^2.1"], "2.2.0-rc1", Bool.False),
		(["^2.1"], "x", Bool.False),
		(["latest"], "2.2.0", Bool.False),
	]
	bad_admits = admits.keep_if(|(rs, v, want)| Ranges.admits({ ranges: rs, version: v }) != want).map(|(rs, v, want)| (rs, v, want))
	dbg bad_admits
	bad_implied == [] and bad_checks == [] and bad_admits == []
}

# R-UP5 (slice 038): the range that a header version gets when `tln upgrade` moves a variable. A range that admits the new version stays. Else the prefix, the number of parts
# and the wildcard end stay, and the parts come from the new version. An anchor (`=`) is `=<new>`. A form with no design rule (a comparator, a list) is `Err(NoForm)` (question Q1).
expect {
	rows = [
		("^2.1", "3.0.2", Ok("^3.0")),
		("^0.25", "0.26.1", Ok("^0.26")),
		("0.25.*", "0.26.1", Ok("0.26.*")),
		("2", "3.0.2", Ok("3")),
		("^2.1.3", "3.0.2", Ok("^3.0.2")),
		("~1.4", "2.0.0", Ok("~2.0")),
		("1.0.*", "1.2.0", Ok("1.2.*")),
		("=2.0.0", "3.0.2", Ok("=3.0.2")),
		("^2.1", "2.5.0", Ok("^2.1")),
		("2", "2.5.0", Ok("2")),
		("=2.0.0", "2.0.0", Ok("=2.0.0")),
		("*", "3.0.2", Ok("*")),
		(">=1.2, <1.5", "3.0.2", Err(NoForm)),
		("^2.1", "x", Err(NoForm)),
	]
	bad = rows.keep_if(|(r, v, want)| Ranges.rewrite({ range: r, version: v }) != want).map(|(r, v, want)| (r, v, want, Ranges.rewrite({ range: r, version: v })))
	dbg bad
	bad == []
}
