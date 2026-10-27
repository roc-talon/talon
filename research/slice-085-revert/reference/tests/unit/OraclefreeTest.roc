import lib.Ident
import lib.Oracle

OraclefreeTest :: [].{}

now = 1792065600

day = 86400

# The domain D (oldest first): 5 nightlies. n3 is the held compiler H. The compilers above H are n4 and n5 (n5 is the newest).
n1 = "nightly-2026-10-01-1111111"

n2 = "nightly-2026-10-02-2222222"

n3 = "nightly-2026-10-03-3333333"

n4 = "nightly-2026-10-04-4444444"

n5 = "nightly-2026-10-05-5555555"

d5 = [n1, n2, n3, n4, n5]

held = n3

u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

hash = |url| match Ident.of_url(url) {
	Ok(ident) => ident.hash
	Err(_) => crash "bad test URL"
}

cand = |url, days| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - days * day, size: 1 }
	Err(_) => crash "bad test URL"
}

fact = |url, deps| { url, release: { kind: Package, pf: Err(None), deps } }

slot = |id, current, hold, candidates| { id, is_platform: Bool.False, ranges: [], current: Ok(current), hold, named: Err(None), candidates, files: [] }

input = |slots, facts| { slots, strategy: Highest, now, min_age: 2 * day, snapshot: Err(None), facts, unmanaged: [], paths: [], second: Bool.False }

row = |url, id, outcome| { hash: hash(url), nightly: id, target: "any", outcome, modules: [], closure: "" }

compat = |checks| { compiler: Ok(held), checks, looked: [], probes: Allowed, conflicts: [], used: [], domain: Ok(d5), inferred: [], failed: Other }

short = |url| url.drop_prefix("https://github.com/acme/")

names = [(n1, "n1"), (n2, "n2"), (n3, "n3"), (n4, "n4"), (n5, "n5")]

nm = |id| names.find_first(|(i, _)| i == id).map_ok(|(_, n)| n) ?? id

view = |r| match r {
	Pairs(pairs) => "pairs ${Str.join_with(pairs.map(|p| "${short(p.id)}@${nm(p.nightly)}"), " ")}"
	Done(done) => "done ${Str.join_with(done.chosen.map(|c| "${c.id}=${c.version}"), " ")} on ${
		match done.nightly {
			Ok(id) => nm(id)
			Err(None) => "no compiler"
		}
	}"
	Need(_) => "need"
	Scan(_) => "scan"
	Wide => "wide"
	Fail(fail) => fail.line()
}

json = |v| u("json", v)

lib = |v| u("lib", v)

# json has 3 releases, 1.0.0 is the header value. lib has 2 releases. The pass and fail rows are real facts of the db.
json_slot = |hold| slot("json", json("1.0.0"), hold, [cand(json("1.0.0"), 30), cand(json("2.0.0"), 30), cand(json("3.0.0"), 30)])

lib_slot = |hold| slot("lib", lib("1.0.0"), hold, [cand(lib("1.0.0"), 30), cand(lib("1.1.0"), 30)])

facts = [fact(json("1.0.0"), []), fact(json("2.0.0"), []), fact(json("3.0.0"), []), fact(lib("1.0.0"), []), fact(lib("1.1.0"), [])]

pass = |url, id| row(url, id, Pass)

fail = |url, id| row(url, id, Fail)

# the compilers that the command can ask for: H, n4 (installed) and n5 (the newest, the one download)
open = Ok([n3, n4, n5])

run = |slots, checks, askable| view(Oracle.step_free(input(slots, facts), compat(checks), askable))

# R-SP12 R-SP8 R-UP6 (slice 039): `Oracle.step_free` with the packages held (`tln upgrade roc`). The compiler is the best value that no fact excludes: the newest compiler of the askable ones, then the older ones, and H last (H has the assumed pass, R-BL3).
# A pair with no fact on a compiler is asked first for the newest compiler (a `Pairs` row, R-AL4), so the probes go to the compiler that could win.
expect {
	held_json = [json_slot(Held)]
	two = [json_slot(Held), lib_slot(Held)]
	rows = [
		("held json, no fact on n5: the pair on the newest compiler is asked", run(held_json, [], open), "pairs ${short(json("1.0.0"))}@n5"),
		("held json passes on n5: the nightly is n5", run(held_json, [pass(json("1.0.0"), n5)], open), "done json=1.0.0 on n5"),
		("held json fails on n5, no fact on n4: the pair on n4 is asked", run(held_json, [fail(json("1.0.0"), n5)], open), "pairs ${short(json("1.0.0"))}@n4"),
		("held json fails on n5, passes on n4: the nightly is n4 (R-SP12)", run(held_json, [fail(json("1.0.0"), n5), pass(json("1.0.0"), n4)], open), "done json=1.0.0 on n4"),
		("held json fails on n5 and n4: the nightly stays H (the assumed pass, no probe on H)", run(held_json, [fail(json("1.0.0"), n5), fail(json("1.0.0"), n4)], open), "done json=1.0.0 on n3"),
		("2 held packages: the nightly is the newest one that all hashes pass on (lib fails on n5, json fails on n4)", run(two, [pass(json("1.0.0"), n5), fail(lib("1.0.0"), n5), fail(json("1.0.0"), n4), pass(lib("1.0.0"), n4)], open), "done json=1.0.0 lib=1.0.0 on n3"),
		("2 held packages: all pass on n4, one fails on n5: n4", run(two, [fail(json("1.0.0"), n5), pass(json("1.0.0"), n4), pass(lib("1.0.0"), n4), pass(lib("1.0.0"), n5)], open), "done json=1.0.0 lib=1.0.0 on n4"),
		("only H is askable (nothing else installed): no pair on n4 or n5, the nightly is H", run(held_json, [], Ok([n3])), "done json=1.0.0 on n3"),
		("a compiler that is not askable is never chosen, even when the facts pass on it", run(held_json, [pass(json("1.0.0"), n5)], Ok([n3, n4])), "pairs ${short(json("1.0.0"))}@n4"),
		("a compiler that is not in D is never chosen (the list of askable has n5 and D has not)", view(Oracle.step_free(input(held_json, facts), { ..compat([pass(json("1.0.0"), n5), pass(json("1.0.0"), n4)]), domain: Ok([n1, n2, n3, n4]) }, open)), "done json=1.0.0 on n4"),
		("a held compiler (`Err(Held)`): the slot has H only, the nightly is H and no pair is asked on n5", run(held_json, [], Err(Held)), "done json=1.0.0 on n3"),
		("no compiler (`--no-check`): the nightly is `Err(None)`", view(Oracle.step_free(input(held_json, facts), { ..compat([]), compiler: Err(None) }, open)), "done json=1.0.0 on no compiler"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SP13 R-SP9 R-SP12 (slice 039): `upgrade X roc`: X is free and the compiler is free. The compiler is the last slot, so X gets its best release first: the newest release of X wins over the newest compiler. The search goes
# to an older compiler only when no release of X works on a newer one in any way, and then only for the best release of X that still has a compiler.
expect {
	free_json = [json_slot(Free)]
	rows = [
		("free json, 3.0.0 passes on n3 and fails on n5 and n4: json 3.0.0 on H (X first)", run(free_json, [fail(json("3.0.0"), n5), fail(json("3.0.0"), n4), pass(json("3.0.0"), n3), pass(json("2.0.0"), n5)], open), "done json=3.0.0 on n3"),
		("free json, 3.0.0 passes on n4, fails on n5: json 3.0.0 on n4", run(free_json, [fail(json("3.0.0"), n5), pass(json("3.0.0"), n4)], open), "done json=3.0.0 on n4"),
		("free json, 3.0.0 passes on n5: json 3.0.0 on n5", run(free_json, [pass(json("3.0.0"), n5)], open), "done json=3.0.0 on n5"),
		("free json, 3.0.0 fails on every compiler (H too: a real row): json 2.0.0 on n5, if it passes", run(free_json, [fail(json("3.0.0"), n5), fail(json("3.0.0"), n4), fail(json("3.0.0"), n3), pass(json("2.0.0"), n5)], open), "done json=2.0.0 on n5"),
		("free json, no fact: the pair of the newest release on the newest compiler is asked first", run(free_json, [], open), "pairs ${short(json("3.0.0"))}@n5"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-RP4 R-SP16 R-SP23 R-SP24 R-SP13 R-UP13 (slice 039c): `Oracle.step_moved`, the step of the second search of `tln upgrade X`. The nightly is held and movable: it keeps H (n3) when a tuple exists with H, and else it moves the smallest step in the order of D: the nearest compiler above H, then the
# ones above it up to the newest (`values` has no compiler below H: `NightlyPlan.movable`). The header value (json 1.0.0) has the assumed pass on H unless a real row says other. Only the compilers of `values` are asked (installed compilers and H).
# The compiler is decided after the movable packages and before the free ones, so a free package gives way before the nightly moves.
expect {
	moved_input = |slots| { ..input(slots, facts), second: Bool.True }
	run_moved = |slots, checks, values| view(Oracle.step_moved(moved_input(slots), compat(checks), values))
	held_json = [json_slot(Movable)]
	all = [n3, n4, n5]
	rows = [
		("no fact: json 1.0.0 has the assumed pass on H, so the nightly stays H and nothing is asked on n4 or n5 (the free nightly would ask n5 first)", run_moved(held_json, [], all), "done json=1.0.0 on n3"),
		("json 1.0.0 fails on H: the pair on n4 is asked first, the nearest compiler above H (not the newest n5)", run_moved(held_json, [fail(json("1.0.0"), n3)], all), "pairs ${short(json("1.0.0"))}@n4"),
		("it passes on n4: the nightly moves to n4, not to n5", run_moved(held_json, [fail(json("1.0.0"), n3), pass(json("1.0.0"), n4)], all), "done json=1.0.0 on n4"),
		("it fails on n4, no fact on n5: n5 is asked next", run_moved(held_json, [fail(json("1.0.0"), n3), fail(json("1.0.0"), n4)], all), "pairs ${short(json("1.0.0"))}@n5"),
		("it fails on H and n4 and passes on n5: n5", run_moved(held_json, [fail(json("1.0.0"), n3), fail(json("1.0.0"), n4), pass(json("1.0.0"), n5)], all), "done json=1.0.0 on n5"),
		("it fails on H, n4 and n5: no value is left for a held json, no tuple (the compilers below H are no values: `NightlyPlan.movable`)", run_moved([json_slot(Held)], [fail(json("1.0.0"), n3), fail(json("1.0.0"), n4), fail(json("1.0.0"), n5)], all), view(Oracle.step_free(moved_input([json_slot(Held)]), compat([fail(json("1.0.0"), n3), fail(json("1.0.0"), n4), fail(json("1.0.0"), n5)]), Ok(all)))),
		("a compiler that is not a value is never asked: n4 is not installed, so n5 is asked after H", run_moved(held_json, [fail(json("1.0.0"), n3)], [n3, n5]), "pairs ${short(json("1.0.0"))}@n5"),
		("H is a value also when `values` lacks it: no fact keeps H", run_moved(held_json, [], [n4, n5]), "done json=1.0.0 on n3"),
		("the free package gives way before the nightly moves: lib 1.1.0 fails on H, lib 1.0.0 passes on H (R-UP13: a free X does not move the nightly)", run_moved([json_slot(Movable), lib_slot(Free)], [pass(json("1.0.0"), n3), fail(lib("1.1.0"), n3), pass(lib("1.0.0"), n3)], all), "done json=1.0.0 lib=1.0.0 on n3"),
		("no release of the free lib works on H, and lib 1.1.0 passes on n4: the nightly moves to n4 and lib keeps its best release", run_moved([json_slot(Movable), lib_slot(Free)], [pass(json("1.0.0"), n3), pass(json("1.0.0"), n4), fail(lib("1.1.0"), n3), fail(lib("1.0.0"), n3), pass(lib("1.1.0"), n4)], all), "done json=1.0.0 lib=1.1.0 on n4"),
		("a movable json moves too when no compiler works for 1.0.0: json 2.0.0 is the nearest release, and its pair is asked on H first (the packages are decided before the compiler)", run_moved(held_json, [fail(json("1.0.0"), n3), fail(json("1.0.0"), n4), fail(json("1.0.0"), n5)], all), "pairs ${short(json("2.0.0"))}@n3"),
		("no compiler (`--no-check`): the nightly is `Err(None)`, as `step_free`", view(Oracle.step_moved(moved_input(held_json), { ..compat([]), compiler: Err(None) }, all)), "done json=1.0.0 on no compiler"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-LF2 R-EP9 R-EP8 R-SP12 R-UP6 (slice 039c, Q5 of slice 039): `--no-probe` with a free nightly (`probes: Off`). The step asks for no probe. A pair with no fact is fit (R-EP9), so the nightly is the newest compiler that no known fact excludes: a real row, and an inferred fact (it decides with `Off`).
# The facts of a release that changes are looked up in the db first (a `Pairs` round that the command answers with `Facts.load!`, not with a probe). With `Allowed` an inferred fail does not decide: the step asks for the real fact (R-EP8).
expect {
	off = |checks, inferred| { ..compat(checks), probes: Off, inferred }
	guess = |url, id, outcome| { hash: hash(url), nightly: id, outcome, modules: [], from: [] }
	run_off = |slots, checks, inferred| view(Oracle.step_free(input(slots, facts), off(checks, inferred), open))
	held_json = [json_slot(Held)]
	rows = [
		("no fact on n5: it is fit, the nightly is n5 and nothing is probed", run_off(held_json, [], []), "done json=1.0.0 on n5"),
		("a real fail on n5: n4, which has no fact and is fit", run_off(held_json, [fail(json("1.0.0"), n5)], []), "done json=1.0.0 on n4"),
		("real fails on n5 and n4: H (the assumed pass)", run_off(held_json, [fail(json("1.0.0"), n5), fail(json("1.0.0"), n4)], []), "done json=1.0.0 on n3"),
		("an inferred fail on n5 decides with `Off`: n4", run_off(held_json, [], [guess(json("1.0.0"), n5, Fail)]), "done json=1.0.0 on n4"),
		("an inferred pass on n5 does not exclude it", run_off(held_json, [], [guess(json("1.0.0"), n5, Pass)]), "done json=1.0.0 on n5"),
		("a free json 3.0.0 is a release that changes, with no row: the command looks it up (a lookup round on the newest compiler, no probe)", run_off([json_slot(Free)], [], []), "pairs ${short(json("3.0.0"))}@n5"),
		("a real pass of json 3.0.0 on n5: it is done on n5", run_off([json_slot(Free)], [pass(json("3.0.0"), n5)], []), "done json=3.0.0 on n5"),
		("an inferred fail of json 3.0.0 on n5, and a real pass on n4: json 3.0.0 on n4 (the compiler is last: X first, R-SP13)", run_off([json_slot(Free)], [pass(json("3.0.0"), n4)], [guess(json("3.0.0"), n5, Fail)]), "done json=3.0.0 on n4"),
		("with `Allowed`, an inferred fail on n5 does not decide: the pair of the best tuple (n4) has no real fact, so the step asks for it (R-EP8). With `Off` the same facts give `done` on n4", view(Oracle.step_free(input(held_json, facts), { ..compat([]), inferred: [guess(json("1.0.0"), n5, Fail)] }, open)), "pairs ${short(json("1.0.0"))}@n4"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
