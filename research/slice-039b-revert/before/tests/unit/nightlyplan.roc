app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Nightlies
import lib.NightlyPlan

main! = |_args| Ok({})

now = 1792065600

day = 86400

# The list of the host (slice 039): 6 nightlies. n3 is the held compiler H. n6 is too new for min-release-age (2 days). The list is newest first, as `Nightlies.list!` gives it.
n1 = "nightly-2026-10-01-1111111"

n2 = "nightly-2026-10-02-2222222"

n3 = "nightly-2026-10-03-3333333"

n4 = "nightly-2026-10-04-4444444"

n5 = "nightly-2026-10-05-5555555"

n6 = "nightly-2026-10-06-6666666"

asset = |id| { name: "roc_nightly-linux_x86_64-${id}.tar.gz", url: "http://127.0.0.1:1/dl/${id}", size: 100, sha256: Err(None) }

rel = |id, days| { id, published_at: now - days * day, asset: Ok(asset(id)) }

releases = [rel(n6, 1), rel(n5, 2), rel(n4, 3), rel(n3, 5), rel(n2, 6), rel(n1, 7)]

names = [(n1, "n1"), (n2, "n2"), (n3, "n3"), (n4, "n4"), (n5, "n5"), (n6, "n6"), ("nightly-2026-10-09-9999999", "n9")]

nm = |id| names.find_first(|(i, _)| i == id).map_ok(|(_, n)| n) ?? id

base = { releases, req: Any, now, min_age: 2 * day, snapshot: Err(None), nightly: Bool.True, held: n3, installed: [] }

view = |f| {
	got = NightlyPlan.pick(f)
	(
		match got.newest {
			Ok(id) => nm(id)
			Err(NoneKnown) => "none"
		},
		got.askable.map(nm),
		got.domain.len(),
	)
}

# R-UP6 R-SP12 R-C7 R-C9 R-NS3 R-NS7 (slice 039): the compilers of a free nightly. N is the newest allowed compiler (`Toolchain.range_pick`): the one download that the command names. The askable compilers are the allowed ones that are
# not older than H and are installed or are N, and H itself (R-C9: H stays in the search, as the baseline, even when it is outside the range or the age window). The order is the one of the list (newest first), H last when it is added.
# An installed compiler that is not allowed (too new, outside the range, the switch is off) is not askable. U5 (reading (c)): a compiler that is not installed and is not N is not askable.
expect {
	rows = [
		("nothing installed: N and H", view(base), ("n5", ["n5", "n3"], 6)),
		("n4 installed: N, n4 and H", view({ ..base, installed: [n4] }), ("n5", ["n5", "n4", "n3"], 6)),
		("n5 and n4 installed, and H: all three, no repeat", view({ ..base, installed: [n5, n4, n3] }), ("n5", ["n5", "n4", "n3"], 6)),
		("n1 and n2 installed (older than H): not askable", view({ ..base, installed: [n1, n2] }), ("n5", ["n5", "n3"], 6)),
		("n6 installed but too new (min-release-age): not askable, N is n5", view({ ..base, installed: [n6] }), ("n5", ["n5", "n3"], 6)),
		("min-release-age of 0: n6 is N", view({ ..base, min_age: 0 }), ("n6", ["n6", "n3"], 6)),
		("a snapshot at the time of n4: n5 is hidden, N is n4", view({ ..base, snapshot: Ok(now - 3 * day) }), ("n4", ["n4", "n3"], 6)),
		("the range `>=n4`: H is outside, N is n5, and H stays askable (R-C9)", view({ ..base, req: AtLeast(n4) }), ("n5", ["n5", "n3"], 6)),
		("the range `>=n4` and n4 installed: n4 is askable", view({ ..base, req: AtLeast(n4), installed: [n4] }), ("n5", ["n5", "n4", "n3"], 6)),
		("the range `=n4`: N is n4, H stays askable", view({ ..base, req: Exactly(n4) }), ("n4", ["n4", "n3"], 6)),
		("H is the newest allowed compiler: N is H, H alone is askable", view({ ..base, held: n5 }), ("n5", ["n5"], 6)),
		("H is newer than every allowed compiler (n6 is hidden): N is older than H, and H alone is askable", view({ ..base, held: n6, installed: [n4] }), ("n5", ["n6"], 6)),
		("the switch is off (`nightly = false`): no compiler is allowed, H alone is askable", view({ ..base, nightly: Bool.False }), ("none", ["n3"], 6)),
		("H is not in the list and is newer than every compiler of it (the id of a path compiler): H alone is askable", view({ ..base, held: "nightly-2026-10-09-9999999" }), ("n5", ["n9"], 6)),
		("H is not in the list and is older (an old path compiler): it is added, last", view({ ..base, held: "nightly-2026-09-30-0000000" }), ("n5", ["n5", "nightly-2026-09-30-0000000"], 6)),
		("an empty list: no N, H alone", view({ ..base, releases: [] }), ("none", ["n3"], 0)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SP6 R-SP7 R-SP8 R-SP9 R-UP12 R-UP13 (slice 039): what the names of `tln upgrade` free. The names keep their order. `roc` twice is `roc` once.
expect {
	rows = [
		("no names: all packages and the nightly (R-SP6, R-UP12)", NightlyPlan.scope([]), { who: All, nightly: Free }),
		("only roc: no package is free, the nightly is (R-SP8, R-UP13)", NightlyPlan.scope(["roc"]), { who: None, nightly: Free }),
		("roc twice: the same", NightlyPlan.scope(["roc", "roc"]), { who: None, nightly: Free }),
		("a package: the nightly is held (R-SP7)", NightlyPlan.scope(["json"]), { who: Named(["json"]), nightly: Held }),
		("2 packages, in order", NightlyPlan.scope(["parser", "json"]), { who: Named(["parser", "json"]), nightly: Held }),
		("a package and roc: both are free (R-SP9)", NightlyPlan.scope(["json", "roc"]), { who: Named(["json"]), nightly: Free }),
		("roc first: the same, without roc in the names", NightlyPlan.scope(["roc", "json", "parser"]), { who: Named(["json", "parser"]), nightly: Free }),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-RP1 R-SP12 (slice 039): the new pin. A free nightly and a tuple on a compiler other than H: the pin moves to it. Same compiler (also the other tag form of H, R-CV1), a held nightly, a run with no compiler: no move.
expect {
	rows = [
		("free, the tuple is on n5: the pin moves to n5", NightlyPlan.moved_to({ unify: Bool.False, free: Bool.True, held: Ok(n3), nightly: Ok(n5) }), Ok(n5)),
		("free, the tuple is on H: no move", NightlyPlan.moved_to({ unify: Bool.False, free: Bool.True, held: Ok(n3), nightly: Ok(n3) }), Err(Same)),
		("free, the tuple is on H in the other tag form of it: no move (R-CV1)", NightlyPlan.moved_to({ unify: Bool.False, free: Bool.True, held: Ok(n3), nightly: Ok("nightly-2026-October-03-3333333") }), Err(Same)),
		("held nightly, the tuple is on n5: no move", NightlyPlan.moved_to({ unify: Bool.False, free: Bool.False, held: Ok(n3), nightly: Ok(n5) }), Err(Same)),
		("free, no compiler (`--no-check`): no move", NightlyPlan.moved_to({ unify: Bool.False, free: Bool.True, held: Err(NoCompiler), nightly: Err(None) }), Err(Same)),
		("free, no compiler for H but a tuple: no move", NightlyPlan.moved_to({ unify: Bool.False, free: Bool.True, held: Err(NoCompiler), nightly: Ok(n5) }), Err(Same)),
		("free, the tuple is on H, the members have different pins (unify): the pin is written (Q3)", NightlyPlan.moved_to({ unify: Bool.True, free: Bool.True, held: Ok(n3), nightly: Ok(n3) }), Ok(n3)),
		("free, the tuple is on n5, unify: n5", NightlyPlan.moved_to({ unify: Bool.True, free: Bool.True, held: Ok(n3), nightly: Ok(n5) }), Ok(n5)),
		("a held nightly with unify (cannot be: the rows are the same): no move", NightlyPlan.moved_to({ unify: Bool.True, free: Bool.False, held: Ok(n3), nightly: Ok(n3) }), Err(Same)),
		("free, H and no tuple compiler: no move", NightlyPlan.moved_to({ unify: Bool.False, free: Bool.True, held: Ok(n3), nightly: Err(None) }), Err(Same)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-RP1 R-RP3 R-OUT2 (slice 039, TW24 proposal): the line of the pin edit of one member. A member with a pin: `~ roc: <old> -> <id>`. A member with no pin: `+ roc: <id>` (the line of slice 013). The same id (also the other tag form): no edit.
expect {
	rows = [
		("a member with a pin", NightlyPlan.pin_line({ old: Ok(n3), id: n5 }), Ok("~ roc: ${n3} -> ${n5}")),
		("a member with no pin", NightlyPlan.pin_line({ old: Err(NoPin), id: n5 }), Ok("+ roc: ${n5}")),
		("a member that has the pin already", NightlyPlan.pin_line({ old: Ok(n5), id: n5 }), Err(Same)),
		("a member that has the other tag form of the pin", NightlyPlan.pin_line({ old: Ok("nightly-2026-October-05-5555555"), id: n5 }), Err(Same)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-WS4 R-RP1 (slice 039, Q3 answer): members with different `roc:` pins. A free nightly accepts them: each member that has a pin gets the newest pin in the rows for `Pin.decide` (H is the newest pin). A member with no pin keeps none. With
# the same pin in all members, with one member, with no pins, or with a held nightly (`free` false) the rows do not change and `differ` is false.
expect {
	row = |file, pin| { file, pin, changes: Bool.False }
	shown = |f| {
		got = NightlyPlan.unify(f)
		(got.members.map(|m| (m.file, m.pin.map_err(|_| "none"))), got.differ)
	}
	a = row("/w/a/main.roc", Ok(n3))
	b = row("/w/b/main.roc", Ok(n5))
	c = row("/w/c/main.roc", Err(NoPin))
	d = row("/w/d/main.roc", Ok(n4))
	rows = [
		("2 pins: both are the newest", shown({ members: [a, b], free: Bool.True }), ([("/w/a/main.roc", Ok(n5)), ("/w/b/main.roc", Ok(n5))], Bool.True)),
		("3 pins: the newest, in any order", shown({ members: [b, a, d], free: Bool.True }), ([("/w/b/main.roc", Ok(n5)), ("/w/a/main.roc", Ok(n5)), ("/w/d/main.roc", Ok(n5))], Bool.True)),
		("a member with no pin keeps none", shown({ members: [a, c, b], free: Bool.True }), ([("/w/a/main.roc", Ok(n5)), ("/w/c/main.roc", Err("none")), ("/w/b/main.roc", Ok(n5))], Bool.True)),
		("one pin text in all members: no change", shown({ members: [a, a], free: Bool.True }), ([("/w/a/main.roc", Ok(n3)), ("/w/a/main.roc", Ok(n3))], Bool.False)),
		("one member with a pin and one with none: no change", shown({ members: [a, c], free: Bool.True }), ([("/w/a/main.roc", Ok(n3)), ("/w/c/main.roc", Err("none"))], Bool.False)),
		("no pin: no change", shown({ members: [c], free: Bool.True }), ([("/w/c/main.roc", Err("none"))], Bool.False)),
		("a held nightly: the pins stay different (Pin.decide fails, R-WS4)", shown({ members: [a, b], free: Bool.False }), ([("/w/a/main.roc", Ok(n3)), ("/w/b/main.roc", Ok(n5))], Bool.False)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
