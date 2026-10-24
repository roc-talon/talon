app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Common

main! = |_args| Ok({})

# R-EV4 (gap N01 of the code review, `nightly_of` moved from `Install` to `Common` in slice 025): `TALON_NIGHTLY` is `0` or `false` (off), `1` or `true` (on). Any other text, the empty text and no variable are not set.
expect {
	nightly = |text| Common.nightly_of([("HOME", "/h"), ("TALON_NIGHTLY", text), ("PATH", "/bin")])
	rows = [
		("0", nightly("0"), Ok(Bool.False)),
		("false", nightly("false"), Ok(Bool.False)),
		("1", nightly("1"), Ok(Bool.True)),
		("true", nightly("true"), Ok(Bool.True)),
		("TRUE is not set", nightly("TRUE"), Err(Unset)),
		("yes is not set", nightly("yes"), Err(Unset)),
		("the empty text is not set", nightly(""), Err(Unset)),
		("no variable", Common.nightly_of([("HOME", "/h")]), Err(Unset)),
		("no environment", Common.nightly_of([]), Err(Unset)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, _, _)| label)
	dbg bad
	bad == []
}
