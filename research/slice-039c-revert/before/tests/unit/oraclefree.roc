app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Ident
import lib.Oracle

main! = |_args| Ok({})

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

compat = |checks| { compiler: Ok(held), checks, looked: [], probes: Allowed, conflicts: [], used: [], domain: Ok(d5), inferred: [] }

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
