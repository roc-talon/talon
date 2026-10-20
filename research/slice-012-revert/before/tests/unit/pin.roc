app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Fail
import lib.Pin

main! = |_args| Ok({})

n1 = "nightly-2026-10-09-258ab27"

n2 = "nightly-2026-10-13-91fa0c2"

n3 = "nightly-2026-10-14-38a3029"

# R-NS7 R-NS5: the compiler range of `[toolchain] roc`. `*` is any compiler. A lower bound `>=<id>` and an exact `=<id>` name a compiler id. A semver range
# (`0.1.*`, `^1`) is for releases only, so it never admits a nightly. The order of two nightlies is the date, then the text of the tag (R-NS1).
# A release has no date in P0, so a lower bound that is a nightly admits no release, and a lower bound that is a release admits no nightly (question Q9).
# Q9: a pre-release id (`0.1.0-rc1`) is not a release. `>=0.1.0-rc1` is read as a semver range (it admits `0.1.0`). A bound or an id with a pre-release part gives no order in `AtLeast`, so it admits nothing.
expect {
	parsed = [
		("*", Ok(Any)),
		(">=${n1}", Ok(AtLeast(n1))),
		("=${n1}", Ok(Exactly(n1))),
		("0.1.*", Ok(Semver("0.1.*"))),
		("^1", Ok(Semver("^1"))),
		(">=0.1.0", Ok(AtLeast("0.1.0"))),
		(">=0.1.0-rc1", Ok(Semver(">=0.1.0-rc1"))),
		(">=1.2", Ok(Semver(">=1.2"))),
		("", Err(BadReq)),
		("latest", Err(BadReq)),
		(">=nightly-2026-10-09", Err(BadReq)),
		(n1, Err(BadReq)),
	]
	bad_parsed = parsed.keep_if(|(text, want)| Pin.parse_req(text) != want).map(|(text, want)| (text, want, Pin.parse_req(text)))
	dbg bad_parsed

	same_day_low = "nightly-2026-10-09-0000000"
	same_day_high = "nightly-2026-10-09-fffffff"
	admits = [
		(Any, n1, Bool.True),
		(Any, "0.1.0", Bool.True),
		(Exactly(n1), n1, Bool.True),
		(Exactly(n1), n2, Bool.False),
		(AtLeast(n1), n1, Bool.True),
		(AtLeast(n1), n2, Bool.True),
		(AtLeast(n2), n1, Bool.False),
		(AtLeast("nightly-2025-12-31-aaaaaaa"), "nightly-2026-01-01-0000000", Bool.True),
		(AtLeast(n1), same_day_high, Bool.True),
		(AtLeast(n1), same_day_low, Bool.False),
		(AtLeast(n1), "0.1.0", Bool.False),
		(AtLeast("0.1.0"), "0.2.0", Bool.True),
		(AtLeast("0.1.0"), "0.0.9", Bool.False),
		(AtLeast("0.1.0"), n3, Bool.False),
		(AtLeast("0.1.0-rc1"), "0.1.0", Bool.False),
		(AtLeast("0.1.0-rc1"), "0.1.0-rc2", Bool.False),
		(AtLeast("0.1.0"), "0.2.0-rc1", Bool.False),
		(Semver(">=0.1.0-rc1"), "0.1.0", Bool.True),
		(Semver("0.1.*"), "0.1.5", Bool.True),
		(Semver("0.1.*"), "0.2.0", Bool.False),
		(Semver("0.1.*"), n1, Bool.False),
	]
	bad_admits = admits.keep_if(|(req, id, want)| Pin.admits({ req, id }) != want).map(|(req, id, want)| (req, id, want))
	dbg bad_admits
	kinds = [(n1, Bool.True), ("0.1.0", Bool.False), ("debug-3f9a1c2", Bool.False), ("nightly-2026-10-09", Bool.False)]
	bad_kinds = kinds.keep_if(|(id, want)| Pin.is_nightly(id) != want)
	dbg bad_kinds
	bad_parsed == [] and bad_admits == [] and bad_kinds == []
}

# R-WS4 R-RP1 R-RP2 R-RP3 R-H6 R-PH8 R-SP1 R-NS5 R-SO11: the `roc:` pin of the members. P0 holds the nightly: the held value is the pin, or the selected compiler (the `roc`
# on `PATH`) when no member has a pin. A member with no pin gets the held value when its header is written for another change, after the check (R-RP3).
# A pin is never written over a pin (R-RP1). `--no-check` writes none (R-H6). A pin that `[toolchain] roc` does not admit, or a nightly pin with the switch off, is `outside`.
expect {
	member = |file, pin, changes| { file, pin, changes }
	none = Err(NoPin)
	decide = |members, compiler, req, nightly, no_check| Pin.decide({ members, compiler, req, nightly, no_check })
	shown = |r| match r {
		Ok(d) => Ok((d.held, d.writes.map(|w| (w.file, w.id)), d.outside))
		Err(fail) => Err((fail.kind.code(), fail.message))
	}
	a = "/w/a/main.roc"
	b = "/w/b/main.roc"
	rows = [
		("no pin, header changes: write the compiler", decide([member(a, none, Bool.True)], Ok(n1), Err(Unset), Bool.True, Bool.False), Ok((Ok(n1), [(a, n1)], Err(None)))),
		("--no-check: no write (R-H6)", decide([member(a, none, Bool.True)], Ok(n1), Err(Unset), Bool.True, Bool.True), Ok((Ok(n1), [], Err(None)))),
		("a missing pin alone is not a change (R-RP3)", decide([member(a, none, Bool.False)], Ok(n1), Err(Unset), Bool.True, Bool.False), Ok((Ok(n1), [], Err(None)))),
		("a pin stays, also when it is not the compiler (R-RP1, R-RP2)", decide([member(a, Ok(n2), Bool.True)], Ok(n1), Err(Unset), Bool.True, Bool.False), Ok((Ok(n2), [], Err(None)))),
		("no compiler, or a local build: nothing to write (R-SO11)", decide([member(a, none, Bool.True)], Err(NoCompiler), Err(Unset), Bool.True, Bool.False), Ok((Err(NoCompiler), [], Err(None)))),
		("a member with no pin gets the workspace pin (R-WS4)", decide([member(a, Ok(n2), Bool.True), member(b, none, Bool.True)], Ok(n1), Err(Unset), Bool.True, Bool.False), Ok((Ok(n2), [(b, n2)], Err(None)))),
		("the same pin in 2 members", decide([member(a, Ok(n2), Bool.True), member(b, Ok(n2), Bool.True)], Ok(n1), Err(Unset), Bool.True, Bool.False), Ok((Ok(n2), [], Err(None)))),
		("2 members, no pin, only b changes", decide([member(a, none, Bool.False), member(b, none, Bool.True)], Ok(n1), Err(Unset), Bool.True, Bool.False), Ok((Ok(n1), [(b, n1)], Err(None)))),
		("pins that differ: exit 2, the members and the commands (R-WS4)", decide([member(a, Ok(n1), Bool.True), member(b, none, Bool.True), member("/w/c/main.roc", Ok(n2), Bool.True)], Ok(n1), Err(Unset), Bool.True, Bool.False), Err((2, "members have different roc pins: ${a} ${n1}, /w/c/main.roc ${n2}. Run tln roc use <id> or tln upgrade roc."))),
		("a pin below the lower bound (R-RP2, R-NS7)", decide([member(a, Ok(n1), Bool.True)], Ok(n1), Ok(AtLeast(n2)), Bool.True, Bool.False), Ok((Ok(n1), [], Ok(n1)))),
		("a pin inside the range", decide([member(a, Ok(n2), Bool.True)], Ok(n1), Ok(AtLeast(n1)), Bool.True, Bool.False), Ok((Ok(n2), [], Err(None)))),
		("a nightly pin, the switch is off (R-NS5)", decide([member(a, Ok(n1), Bool.True)], Ok(n1), Err(Unset), Bool.False, Bool.False), Ok((Ok(n1), [], Ok(n1)))),
		("a release pin, the switch is off", decide([member(a, Ok("0.1.0"), Bool.True)], Ok(n1), Err(Unset), Bool.False, Bool.False), Ok((Ok("0.1.0"), [], Err(None)))),
		("a nightly pin and a semver range (R-NS7)", decide([member(a, Ok(n1), Bool.True)], Ok(n1), Ok(Semver("0.1.*")), Bool.True, Bool.False), Ok((Ok(n1), [], Ok(n1)))),
	]
	bad = rows.keep_if(|(_, got, want)| shown(got) != want).map(|(label, got, want)| (label, want, shown(got)))
	dbg bad

	failure = |pin, req_text, nightly| Pin.outside_failure({ pin, req_text, nightly })
	range_text = failure(n1, Ok(">=${n2}"), Bool.True)
	switch_text = failure(n1, Err(Unset), Bool.False)
	both = failure(n1, Ok("*"), Bool.False)
	dbg [range_text.line(), switch_text.line(), both.line()]
	texts_ok = range_text.line() == "tln: error[no_tuple]: the roc pin ${n1} is outside [toolchain] roc (>=${n2}). Run tln upgrade roc or tln roc use <id>." and switch_text.line() == "tln: error[no_tuple]: the roc pin ${n1} is a nightly, and nightly is false (TALON_NIGHTLY or [toolchain] nightly). Run tln upgrade roc or tln roc use <id>." and both.kind.code() == 10
	bad == [] and texts_ok
}
