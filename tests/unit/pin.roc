app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Fail
import lib.Pin

main! = |_args| Ok({})

n1 = "nightly-2026-10-09-258ab27"

n2 = "nightly-2026-10-13-91fa0c2"

n3 = "nightly-2026-10-14-38a3029"

# R-NS7 R-NS5 R-SC12: the compiler range of `[toolchain] roc`. R-SC12: a bound that is a prefix of a nightly id (`>=nightly-2026-10-09`, no hash part) is `BadReq`: only a full id is allowed. `*` is any compiler. A lower bound `>=<id>` and an exact `=<id>` name a compiler id. A semver range
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

# R-WS4 R-RP1 R-RP2 R-RP3 R-H6 R-PH8 R-SP1 R-NS5 R-SO11 R-SO3 R-SO4: the `roc:` pin of the members. R-SO3: the header pin (rank 3) is the held value, also when the `roc` on `PATH` is another id.
# R-SO4: `[toolchain] roc` (rank 4) is read as a range, and a pin that it does not admit is `outside` (P0 reports it, R-RP2). P0 holds the nightly: the held value is the pin, or the selected compiler (the `roc`
# on `PATH`) when no member has a pin. A member with no pin gets the held value when its header is written for another change, after the check (R-RP3).
# A pin is never written over a pin (R-RP1). `--no-check` writes none (R-H6). A pin that `[toolchain] roc` does not admit, or a nightly pin with the switch off, is `outside`.
expect {
	member = |file, pin, changes| { file, pin, changes }
	none = Err(NoPin)
	decide = |members, compiler, req, nightly, no_check| Pin.decide({ members, compiler, toolchain: Err(Unset), role: Lock, req, nightly, no_check })
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

	failure = |pin, req_text, nightly, source| Pin.outside_failure({ pin, req_text, nightly, source })
	range_text = failure(n1, Ok(">=${n2}"), Bool.True, Env)
	switch_text = failure(n1, Err(Unset), Bool.False, Config)
	both = failure(n1, Ok("*"), Bool.False, Toml)
	dbg [range_text.line(), switch_text.line(), both.line()]
	texts_ok = range_text.line() == "tln: error[no_tuple]: the roc pin ${n1} is outside [toolchain] roc (>=${n2}). Run tln upgrade roc or tln roc use <id>." and switch_text.line() == "tln: error[no_tuple]: the roc pin ${n1} is a nightly, and nightly is false (set by nightly in config.toml). Run tln upgrade roc or tln roc use <id>." and both.kind.code() == 10
	bad == [] and texts_ok
}

# R-SO19 R-SO20 R-SO21 R-SO22 R-RP3 R-RP2 R-H6 (slice 013, G-pin-gate section 3): the held nightly and the run compiler. `ROC_TOOLCHAIN` (`toolchain`, rank 2) never moves a header pin: a `Lock` command (install, add, update, remove)
# holds the pin and prints one note. `Verify` writes nothing, so it holds `toolchain` (R-SO21), and still reports a pin that the header does not admit (`outside`, R-RP2). With no pin, rank 2 selects the held nightly, and it
# needs no `roc` on `PATH` (R-SO22). `held_from` is the rank that selected `held`: the `gate` of a no-pin run reads it.
expect {
	member = |file, pin, changes| { file, pin, changes }
	a = "/w/a/main.roc"
	note = |pin, toolchain| "ROC_TOOLCHAIN is ${toolchain}, but the header pin is ${pin}. This command keeps the pin. To change the pin, run tln roc use ${toolchain}."
	hold = |members, compiler, toolchain, role, req, no_check| Pin.decide({ members, compiler, toolchain, role, req, nightly: Bool.True, no_check })
	shown = |r| match r {
		Ok(d) => Ok((d.held, d.held_from, d.note, d.writes.map(|w| (w.file, w.id)), d.outside))
		Err(fail) => Err((fail.kind.code(), fail.message))
	}
	pinned = [member(a, Ok(n3), Bool.True)]
	free = [member(a, Err(NoPin), Bool.True)]
	quiet = [member(a, Err(NoPin), Bool.False)]
	rows = [
		("a pin, ROC_TOOLCHAIN names another id, Lock: the pin stays and one note (R-SO20)", hold(pinned, Ok(n3), Ok(n1), Lock, Err(Unset), Bool.False), Ok((Ok(n3), Pin, Ok(note(n3, n1)), [], Err(None)))),
		("the same, Verify: the probes run on ROC_TOOLCHAIN, no note (R-SO21)", hold(pinned, Ok(n3), Ok(n1), Verify, Err(Unset), Bool.False), Ok((Ok(n1), Env, Err(None), [], Err(None)))),
		("ROC_TOOLCHAIN names the pin, Lock: no note", hold(pinned, Ok(n3), Ok(n3), Lock, Err(Unset), Bool.False), Ok((Ok(n3), Pin, Err(None), [], Err(None)))),
		("a pin, ROC_TOOLCHAIN is not set: the pin, no note (R-SO3)", hold(pinned, Ok(n2), Err(Unset), Lock, Err(Unset), Bool.False), Ok((Ok(n3), Pin, Err(None), [], Err(None)))),
		("a pin outside the range, Verify with ROC_TOOLCHAIN: outside is still the pin (R-SO21, R-RP2)", hold(pinned, Ok(n3), Ok(n1), Verify, Ok(Exactly(n2)), Bool.False), Ok((Ok(n1), Env, Err(None), [], Ok(n3)))),
		("no pin, ROC_TOOLCHAIN, header changes: rank 2 is held and written as the pin (R-SO19, R-RP3)", hold(free, Ok(n3), Ok(n1), Lock, Err(Unset), Bool.False), Ok((Ok(n1), Env, Err(None), [(a, n1)], Err(None)))),
		("the same with --no-check: no write (R-H6)", hold(free, Ok(n3), Ok(n1), Lock, Err(Unset), Bool.True), Ok((Ok(n1), Env, Err(None), [], Err(None)))),
		("no pin, ROC_TOOLCHAIN, Verify: rank 2 is held", hold(quiet, Ok(n3), Ok(n1), Verify, Err(Unset), Bool.False), Ok((Ok(n1), Env, Err(None), [], Err(None)))),
		("no pin, no roc on PATH, ROC_TOOLCHAIN: it is held, no compiler on PATH is needed (R-SO22)", hold(quiet, Err(NoCompiler), Ok(n1), Lock, Err(Unset), Bool.False), Ok((Ok(n1), Env, Err(None), [], Err(None)))),
		("no pin, ROC_TOOLCHAIN is not set: the roc on PATH, rank 7 (R-SO19)", hold(free, Ok(n3), Err(Unset), Lock, Err(Unset), Bool.False), Ok((Ok(n3), Path, Err(None), [(a, n3)], Err(None)))),
	]
	bad = rows.keep_if(|(_, got, want)| shown(got) != want).map(|(label, got, want)| (label, want, shown(got)))
	dbg bad
	text = Pin.toolchain_note({ pin: n3, toolchain: n1 })
	bad == [] and text == note(n3, n1)
}

# R-SO19 R-SO13 R-NS2 R-NS3 R-PH7 R-EC13 (slice 013): `gate` checks the compiler that a rank selected when the header has no pin. `Path` (rank 7) is as in slice 012: a nightly with the switch off is exit 10,
# a range that does not admit it is exit 13 (a required download that P0 refuses). `Env` (`ROC_TOOLCHAIN`, rank 2) is exit 10 in both cases (R-SO19), and the text names the variable. The switch is checked first.
# The call is not made when the header has a pin (G5): that is an L2 run (`ladder/ld-no-check-refuse`).
expect {
	gate = |compiler, held_from, req, req_text, nightly, source| Pin.gate({ compiler, held_from, req, req_text, nightly, source })
	shown = |r| match r {
		Ok(_) => Ok({})
		Err(fail) => Err((fail.kind.code(), fail.message))
	}
	late = Ok(AtLeast(n3))
	late_text = Ok(">=${n3}")
	rows = [
		("Env, a nightly, the switch is off: exit 10, names the variable and the switch", gate(n1, Env, Err(Unset), Err(Unset), Bool.False, Config), Err((10, "the compiler ${n1} from ROC_TOOLCHAIN is a nightly, and nightly is false (set by nightly in config.toml). Change ROC_TOOLCHAIN or the nightly switch."))),
		("Env, outside the range: exit 10, names the variable and the range", gate(n1, Env, late, late_text, Bool.True, Default), Err((10, "the compiler ${n1} from ROC_TOOLCHAIN is outside [toolchain] roc (>=${n3}). Change ROC_TOOLCHAIN or [toolchain] roc."))),
		("Env, the switch is off and the range does not admit it: the switch first", gate(n1, Env, late, late_text, Bool.False, Env), Err((10, "the compiler ${n1} from ROC_TOOLCHAIN is a nightly, and nightly is false (set by TALON_NIGHTLY). Change ROC_TOOLCHAIN or the nightly switch."))),
		("Env, inside the range", gate(n3, Env, late, late_text, Bool.True, Default), Ok({})),
		("Env, a release with the switch off: no nightly, no stop", gate("0.1.0", Env, Err(Unset), Err(Unset), Bool.False, Toml), Ok({})),
		("Path, outside the range: exit 13 as in slice 012 (R-SO13, R-PH7)", gate(n1, Path, late, late_text, Bool.True, Default), Err((13, "the roc on PATH, ${n1}, is outside [toolchain] roc (>=${n3}). This version of tln runs only the roc on PATH, so it cannot select another compiler."))),
		("Path, a nightly, the switch is off: exit 10 as in slice 012 (R-NS2)", gate(n1, Path, Err(Unset), Err(Unset), Bool.False, Env), Err((10, "the roc on PATH, ${n1}, is a nightly, and nightly is false (set by TALON_NIGHTLY). No roc release is known, so no compiler can be selected."))),
	]
	bad = rows.keep_if(|(_, got, want)| shown(got) != want).map(|(label, got, want)| (label, want, shown(got)))
	dbg bad
	bad == []
}
