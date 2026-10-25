app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Clock
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
	bad_admits = admits.keep_if(|(req, id, want)| Pin.admits({ req, id, times: [] }) != want).map(|(req, id, want)| (req, id, want))
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
	decide = |members, compiler, req, nightly, no_check| Pin.decide({ members, compiler, compiler_from: Path, toolchain: Err(Unset), role: Lock, req, nightly, no_check })
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
	hold = |members, compiler, toolchain, role, req, no_check| Pin.decide({ members, compiler, compiler_from: Path, toolchain, role, req, nightly: Bool.True, no_check })
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
		# R-R4 R-LK3 R-SO11 R-H6 (slice 024b): a local build is held and probed, and never written as the pin. The header stays as it was.
		("R-R4: no pin, ROC_TOOLCHAIN is a link build: held, no write", hold(free, Ok(n3), Ok("link-dev"), Lock, Err(Unset), Bool.False), Ok((Ok("link-dev"), Env, Err(None), [], Err(None)))),
		("R-LK3: the same for a copy build", hold(free, Ok(n3), Ok("copy-fix-1"), Lock, Err(Unset), Bool.False), Ok((Ok("copy-fix-1"), Env, Err(None), [], Err(None)))),
		("R-R4: the same for a git build", hold(free, Ok(n3), Ok("git-dd03c09e"), Lock, Err(Unset), Bool.False), Ok((Ok("git-dd03c09e"), Env, Err(None), [], Err(None)))),
		("R-R4: rank 6 gives a link build (the default): held, no write", Pin.decide({ members: free, compiler: Ok("link-dev"), compiler_from: Default, toolchain: Err(Unset), role: Lock, req: Err(Unset), nightly: Bool.True, no_check: Bool.False }), Ok((Ok("link-dev"), Default, Err(None), [], Err(None)))),
		("R-R4: 2 members, one changes, a link build is held: no write", Pin.decide({ members: [member(a, Err(NoPin), Bool.True), member("/w/b/main.roc", Err(NoPin), Bool.True)], compiler: Ok(n3), compiler_from: Path, toolchain: Ok("link-dev"), role: Lock, req: Err(Unset), nightly: Bool.True, no_check: Bool.False }), Ok((Ok("link-dev"), Env, Err(None), [], Err(None)))),
		("a nightly is still written after a link build was held in another row (R-RP3)", hold(free, Ok(n3), Ok(n1), Lock, Err(Unset), Bool.False), Ok((Ok(n1), Env, Err(None), [(a, n1)], Err(None)))),
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
	all_ok = |results| results.keep_if(|r| shown(r) != Ok({})).is_empty()
	rows = [
		("Env, a nightly, the switch is off: exit 10, names the variable and the switch", gate(n1, Env, Err(Unset), Err(Unset), Bool.False, Config), Err((10, "the compiler ${n1} from ROC_TOOLCHAIN is a nightly, and nightly is false (set by nightly in config.toml). Change ROC_TOOLCHAIN or the nightly switch."))),
		("Env, outside the range: exit 10, names the variable and the range", gate(n1, Env, late, late_text, Bool.True, Default), Err((10, "the compiler ${n1} from ROC_TOOLCHAIN is outside [toolchain] roc (>=${n3}). Change ROC_TOOLCHAIN or [toolchain] roc."))),
		("Env, the switch is off and the range does not admit it: the switch first", gate(n1, Env, late, late_text, Bool.False, Env), Err((10, "the compiler ${n1} from ROC_TOOLCHAIN is a nightly, and nightly is false (set by TALON_NIGHTLY). Change ROC_TOOLCHAIN or the nightly switch."))),
		("Env, inside the range", gate(n3, Env, late, late_text, Bool.True, Default), Ok({})),
		("Env, a release with the switch off: no nightly, no stop", gate("0.1.0", Env, Err(Unset), Err(Unset), Bool.False, Toml), Ok({})),
		("Path, outside the range: exit 13 as in slice 012 (R-SO13, R-PH7)", gate(n1, Path, late, late_text, Bool.True, Default), Err((13, "the roc on PATH, ${n1}, is outside [toolchain] roc (>=${n3}). This version of tln runs only the roc on PATH, so it cannot select another compiler."))),
		# Slice 022 (R-SO19, R-NS2, R-NS6): the ranks 4, 5 and 6. Exit 10 for the switch and for the range, the text names the rank and the fix. The switch is first. A local build is never checked.
		("VersionFile, a nightly, the switch is off: exit 10, names .roc-version", gate(n1, VersionFile, Err(Unset), Err(Unset), Bool.False, Env), Err((10, "the compiler ${n1} from .roc-version is a nightly, and nightly is false (set by TALON_NIGHTLY). Change .roc-version or the nightly switch."))),
		("VersionFile, outside the range", gate(n1, VersionFile, late, late_text, Bool.True, Default), Err((10, "the compiler ${n1} from .roc-version is outside [toolchain] roc (>=${n3}). Change .roc-version or [toolchain] roc."))),
		("Default, a nightly, the switch is off: exit 10, names the global default", gate(n1, Default, Err(Unset), Err(Unset), Bool.False, Toml), Err((10, "the compiler ${n1} from the global default is a nightly, and nightly is false (set by [toolchain] nightly in talon.toml). Change the default (tln roc default) or the nightly switch."))),
		("Default, outside the range", gate(n1, Default, late, late_text, Bool.True, Default), Err((10, "the compiler ${n1} from the global default is outside [toolchain] roc (>=${n3}). Change the default (tln roc default) or [toolchain] roc."))),
		("Range is never checked: rank 4 chose inside the range and the switch", gate(n1, Range, late, late_text, Bool.False, Config), Ok({})),
		("Default, inside the range, a release with the switch off", gate("0.1.0", Default, Ok(Semver("0.1.*")), Ok("0.1.*"), Bool.False, Env), Ok({})),
		("a git build is never checked, for each rank (R-NS6)", if all_ok([Env, Range, VersionFile, Default, Path].map(|from| gate("git-0123abcd", from, Ok(Exactly(n3)), Ok("=${n3}"), Bool.False, Env))) Ok({}) else Err(Fail.new(Internal, "a git build was checked")), Ok({})),
		("a link build and a copy build are never checked", if all_ok([gate("link-dev", Default, late, late_text, Bool.False, Env), gate("copy-dev", VersionFile, late, late_text, Bool.False, Env)]) Ok({}) else Err(Fail.new(Internal, "a local build was checked")), Ok({})),
		("Path, a nightly, the switch is off: exit 10 as in slice 012 (R-NS2)", gate(n1, Path, Err(Unset), Err(Unset), Bool.False, Env), Err((10, "the roc on PATH, ${n1}, is a nightly, and nightly is false (set by TALON_NIGHTLY). No roc release is known, so no compiler can be selected."))),
	]
	bad = rows.keep_if(|(_, got, want)| shown(got) != want).map(|(label, got, want)| (label, want, shown(got)))
	dbg bad
	bad == []
}

# R-NS1 R-NS7 R-CV1 (slice 022, G1 of slice 020): the order of 2 compiler ids, and `admits` and `same_id` that use it. The day comes first (a nightly: the date of its tag in both tag forms; a release: the UTC day of its
# `published_at`). A release is newer than a nightly of the same day, and 2 releases of one day are in the order of the versions. Two nightlies of one day are in the order of `published_at` when `times` has both (a row of `times` is found with `same_id`, so the other tag form finds it),
# else of the tag text. A release with no time has no day: it is older than each id that has a day. The real pair of 2026-07-23 (`fdd77c3` at 06:04, `306abd6` at 11:30) has the order of the times, which is the reverse of the tag text.
expect {
	t = |text| Clock.parse_utc(text) ?? 0
	f = "nightly-2026-July-23-fdd77c3"
	e = "nightly-2026-July-23-306abd6"
	f7 = "nightly-2026-07-23-fdd77c3"
	e7 = "nightly-2026-07-23-306abd6"
	times = [{ id: f, published_at: t("2026-07-23T06:04:47Z") }, { id: e, published_at: t("2026-07-23T11:30:53Z") }]
	with_releases = times.concat([{ id: "0.1.0", published_at: t("2026-07-23T20:00:00Z") }, { id: "0.2.0", published_at: t("2026-07-22T08:00:00Z") }, { id: "0.10.0", published_at: t("2026-07-01T08:00:00Z") }])
	one_day = [{ id: "0.1.0", published_at: t("2026-07-23T08:00:00Z") }, { id: "0.2.0", published_at: t("2026-07-23T09:00:00Z") }, { id: "0.10.0", published_at: t("2026-07-23T10:00:00Z") }]
	order_rows = [
		("the date first, no times", Pin.order({ a: n1, b: n2, times: [] }), Before),
		("the reverse", Pin.order({ a: n2, b: n1, times: [] }), After),
		("the same id", Pin.order({ a: n1, b: n1, times: [] }), Same),
		("one day, no times: the tag text (fdd77c3 is after 306abd6)", Pin.order({ a: f7, b: e7, times: [] }), After),
		("one day, both times: the times (the reverse of the tag text)", Pin.order({ a: f7, b: e7, times }), Before),
		("the other tag form of a row of times finds it", Pin.order({ a: e, b: f7, times }), After),
		("one day, a time for one id only: the tag text", Pin.order({ a: f7, b: e7, times: [{ id: f, published_at: 1 }] }), After),
		("a release is newer than a nightly of its day", Pin.order({ a: "0.1.0", b: e7, times: with_releases }), After),
		("a nightly is older than a release of its day (the other order)", Pin.order({ a: e7, b: "0.1.0", times: with_releases }), Before),
		("2 releases of one day with times: by version (0.1.0 before 0.2.0)", Pin.order({ a: "0.1.0", b: "0.2.0", times: one_day }), Before),
		("2 releases of one day with times, the reverse", Pin.order({ a: "0.2.0", b: "0.1.0", times: one_day }), After),
		("2 releases of one day with times: by version, not by text (0.10.0 after 0.2.0)", Pin.order({ a: "0.10.0", b: "0.2.0", times: one_day }), After),
		("a release of an earlier day is older", Pin.order({ a: "0.2.0", b: e7, times: with_releases }), Before),
		("a release with no time is older than a nightly", Pin.order({ a: "0.3.0", b: n1, times: with_releases }), Before),
		("2 releases with no day: by version, not by text (0.10.0 is after 0.2.0)", Pin.order({ a: "0.2.0", b: "0.10.0", times: [] }), Before),
	]
	bad_order = order_rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_order

	admits_rows = [
		("AtLeast e: f is before it by the times", Pin.admits({ req: AtLeast(e7), id: f7, times }), Bool.False),
		("AtLeast e: f is after it by the tag text, with no times", Pin.admits({ req: AtLeast(e7), id: f7, times: [] }), Bool.True),
		("AtLeast f: e is after it by the times", Pin.admits({ req: AtLeast(f7), id: e7, times }), Bool.True),
		("AtLeast f: e is before it by the tag text, with no times", Pin.admits({ req: AtLeast(f7), id: e7, times: [] }), Bool.False),
		("AtLeast: the bound itself", Pin.admits({ req: AtLeast(f7), id: f, times }), Bool.True),
		("Exactly in the other tag form (R-CV1)", Pin.admits({ req: Exactly(f), id: f7, times: [] }), Bool.True),
		("Exactly the other nightly of the day", Pin.admits({ req: Exactly(f), id: e7, times: [] }), Bool.False),
		("Exactly a release", Pin.admits({ req: Exactly("0.1.0"), id: "0.1.0", times: [] }), Bool.True),
		("Exactly another sha of the date", Pin.admits({ req: Exactly(f), id: "nightly-2026-07-23-fdd77c4", times: [] }), Bool.False),
	]
	bad_admits = admits_rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_admits

	same_rows = [
		(f, f7, Bool.True),
		(f7, f, Bool.True),
		(f, f, Bool.True),
		(f, e, Bool.False),
		("0.1.0", "0.1.0", Bool.True),
		("0.1.0", "0.1.1", Bool.False),
		("git-0123abcd", "git-0123abcd", Bool.True),
		("git-0123abcd", n1, Bool.False),
	]
	bad_same = same_rows.keep_if(|(a, b, want)| Pin.same_id(a, b) != want).map(|(a, b, want)| (a, b, want))
	dbg bad_same
	bad_order == [] and bad_admits == [] and bad_same == []
}

# R-NS8 R-NS9 R-NS10 R-NS11 (slice 022): the value of the `nightly` switch and its source. The environment wins over `talon.toml`, which wins over `config.toml`, which wins over the default (on). `tln roc install`
# has no project (R-PD16), so it passes `toml: Err(Unset)`.
expect {
	sw = |env, toml, config| Pin.switch({ env, toml, config })
	un = Err(Unset)
	rows = [
		(sw(Ok(Bool.False), Ok(Bool.True), Ok(Bool.True)), { nightly: Bool.False, source: Env }),
		(sw(Ok(Bool.True), Ok(Bool.False), Ok(Bool.False)), { nightly: Bool.True, source: Env }),
		(sw(un, Ok(Bool.False), Ok(Bool.True)), { nightly: Bool.False, source: Toml }),
		(sw(un, un, Ok(Bool.False)), { nightly: Bool.False, source: Config }),
		(sw(un, un, Ok(Bool.True)), { nightly: Bool.True, source: Config }),
		(sw(un, un, un), { nightly: Bool.True, source: Default }),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (want, got))
	dbg bad
	bad == []
}

# R-SO4 R-SO5 R-SO6 R-SO7 R-SO19 (slice 022): `held_from` of a run with no pin and no `ROC_TOOLCHAIN` is the rank that `Compiler.select` gave (`compiler_from`). A header pin, or `ROC_TOOLCHAIN`, still wins over it.
expect {
	member = |pin| { file: "/w/a/main.roc", pin, changes: Bool.True }
	decide = |pin, toolchain, from| Pin.decide({ members: [member(pin)], compiler: Ok(n2), compiler_from: from, toolchain, role: Lock, req: Err(Unset), nightly: Bool.True, no_check: Bool.False })
	shown = |r| match r {
		Ok(d) => Ok((d.held, d.held_from, d.writes.map(|w| w.id)))
		Err(fail) => Err(fail.kind.code())
	}
	none = Err(NoPin)
	rows = [
		("rank 4", decide(none, Err(Unset), Range), Ok((Ok(n2), Range, [n2]))),
		("rank 5", decide(none, Err(Unset), VersionFile), Ok((Ok(n2), VersionFile, [n2]))),
		("rank 6", decide(none, Err(Unset), Default), Ok((Ok(n2), Default, [n2]))),
		("rank 7", decide(none, Err(Unset), Path), Ok((Ok(n2), Path, [n2]))),
		("a pin wins over rank 6", decide(Ok(n3), Err(Unset), Default), Ok((Ok(n3), Pin, []))),
		("ROC_TOOLCHAIN wins over rank 6", decide(none, Ok(n1), Default), Ok((Ok(n1), Env, [n1]))),
	]
	bad = rows.keep_if(|(_, got, want)| shown(got) != want).map(|(label, got, want)| (label, want, shown(got)))
	dbg bad
	bad == []
}

# R-SO20 R-R4 R-LK3 (slice 026, gap G2 of slice 024b): `tln roc use` refuses a `git-`, `link-` or `copy-` id (R-U1), so the note of R-SO20 must not tell the user to run it for such an id.
# The note has 2 forms. A nightly or a release: `... To change the pin, run tln roc use <id>.` A local build: it says that a build is never a pin, and names `ROC_TOOLCHAIN` and `tln roc default` (the two ways of R-U1).
expect {
	n3_pin = n3
	first = |toolchain| "ROC_TOOLCHAIN is ${toolchain}, but the header pin is ${n3_pin}. This command keeps the pin. To change the pin, run tln roc use ${toolchain}."
	second = |toolchain| "ROC_TOOLCHAIN is ${toolchain}, but the header pin is ${n3_pin}. This command keeps the pin. A git, link or copy build cannot be a pin, so tln roc use does not take it. Use ROC_TOOLCHAIN or tln roc default for it."
	note = |toolchain| Pin.toolchain_note({ pin: n3_pin, toolchain })
	# The same through `decide`: a Lock command with a pin and `ROC_TOOLCHAIN` set to a local build.
	decided = |toolchain| match Pin.decide({ members: [{ file: "/w/a/main.roc", pin: Ok(n3_pin), changes: Bool.True }], compiler: Ok(n3_pin), compiler_from: Path, toolchain: Ok(toolchain), role: Lock, req: Err(Unset), nightly: Bool.True, no_check: Bool.False }) {
		Ok(d) => d.note
		Err(_) => Err(None)
	}
	notes = [
		(n1, first(n1)),
		("0.1.0", first("0.1.0")),
		("link-dev", second("link-dev")),
		("copy-fix-1", second("copy-fix-1")),
		("git-dd03c09e", second("git-dd03c09e")),
	]
	bad = notes.keep_if(|(toolchain, want)| note(toolchain) != want).map(|(toolchain, want)| (toolchain, want, note(toolchain)))
	dbg bad
	bad == [] and decided("link-dev") == Ok(second("link-dev")) and decided(n1) == Ok(first(n1))
}

# R-U5, R-NS5, R-NS7, R-NS2 (slice 026b, proposal): the stop of `tln roc use` for a compiler that `[toolchain] roc` or the `nightly` switch does not admit. The switch is checked first (as R-NS2 and `Pin.gate`): a nightly with the switch off names the switch and its source. A range that does not admit the
# id names the range. A release is not a nightly, so the switch does not stop it. No range, or a range that admits it, is `Ok`. Kind `NoTuple` (exit 10, as R-NS2, review of slice 026b). The command never edits `talon.toml`, and the text says so.
expect {
	req_text_of = |req| match req {
		Ok(AtLeast(id)) => Ok(">=${id}")
		Ok(Semver(text)) => Ok(text)
		Ok(Exactly(id)) => Ok("=${id}")
		Ok(Any) => Ok("*")
		Err(Unset) => Err(Unset)
	}
	gate = |id, req, nightly, source| Pin.use_gate({ id, req, req_text: req_text_of(req), nightly, source, times: [] })
	bound = "nightly-2026-10-14-ffffff0"
	gate_t = |id, req, times| Pin.use_gate({ id, req, req_text: req_text_of(req), nightly: Bool.True, source: Default, times })
	keep = "tln roc use does not change talon.toml."
	switch_text = |id, source| Err(Fail.new(NoTuple, "tln roc use ${id}: it is a nightly, and nightly is false (set by ${source}). Use a release, or change the nightly switch. ${keep}"))
	range_text = |id, range| Err(Fail.new(NoTuple, "tln roc use ${id}: it is outside [toolchain] roc (${range}). Use a compiler in the range, or change [toolchain] roc. ${keep}"))
	at_least = Ok(AtLeast("nightly-2026-10-12-2664a27"))
	rows = [
		("no range, the switch on", gate(n1, Err(Unset), Bool.True, Default), Ok({})),
		("a nightly in the range", gate(n3, at_least, Bool.True, Toml), Ok({})),
		("the nightly at the bound", gate("nightly-2026-10-12-2664a27", at_least, Bool.True, Toml), Ok({})),
		("a nightly below the range", gate(n1, at_least, Bool.True, Toml), range_text(n1, ">=nightly-2026-10-12-2664a27")),
		("a nightly with the switch off, from the environment", gate(n3, Err(Unset), Bool.False, Env), switch_text(n3, "TALON_NIGHTLY")),
		("the switch off, from talon.toml", gate(n3, Err(Unset), Bool.False, Toml), switch_text(n3, "[toolchain] nightly in talon.toml")),
		("the switch off, from config.toml", gate(n3, Err(Unset), Bool.False, Config), switch_text(n3, "nightly in config.toml")),
		("the switch is checked before the range", gate(n1, at_least, Bool.False, Env), switch_text(n1, "TALON_NIGHTLY")),
		("a release with the switch off, no range", gate("0.1.0", Err(Unset), Bool.False, Env), Ok({})),
		("a release in a semver range", gate("0.1.3", Ok(Semver("0.1.*")), Bool.True, Default), Ok({})),
		("a release outside a semver range", gate("0.2.0", Ok(Semver("0.1.*")), Bool.True, Default), range_text("0.2.0", "0.1.*")),
		("a nightly under a semver range (releases only)", gate(n3, Ok(Semver("0.1.*")), Bool.True, Default), range_text(n3, "0.1.*")),
		("the other tag form of the exact nightly", gate("nightly-2026-October-14-38a3029", Ok(Exactly(n3)), Bool.True, Toml), Ok({})),
		("two nightlies of one day: the later time is in the range", gate_t(n3, Ok(AtLeast(bound)), [{ id: n3, published_at: 200 }, { id: bound, published_at: 100 }]), Ok({})),
		("two nightlies of one day: the earlier time is below the range", gate_t(bound, Ok(AtLeast(n3)), [{ id: n3, published_at: 200 }, { id: bound, published_at: 100 }]), range_text(bound, ">=${n3}")),
		("two nightlies of one day, no times: the tag text orders them", gate_t(n3, Ok(AtLeast(bound)), []), range_text(n3, ">=${bound}")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
