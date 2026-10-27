import lib.Ident
import lib.Oracle
import lib.Pick

PickmovesTest :: [].{}

now = 1792065600

day = 86400

# A release URL of the fixture host (as in `pickclosure.roc`).
u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

cand = |url, days| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - days * day, size: 1 }
	Err(_) => crash "bad test URL"
}

# A slot with a header value. A new entry (`add`, a key of `talon.toml`) has no header value: `fresh` makes it.
slot = |id, is_platform, ranges, current, hold, candidates| { id, is_platform, ranges, current: Ok(current), hold, named: Err(None), candidates, files: [] }

fresh = |s| { ..s, current: Err(None), hold: Free }

pkg = |url, deps| { url, release: { kind: Package, pf: Err(None), deps } }

names_pf = |url, pf| { url, release: { kind: Package, pf: Ok(pf), deps: [] } }

plat = |url| { url, release: { kind: Platform, pf: Err(None), deps: [] } }

view = |r| match r {
	Need(urls) => Err(Ok(urls))
	Done(chosen) => Ok(chosen.map(|c| (c.id, c.version, c.change)))
	Fail(fail) => Err(Err(fail.line()))
}

input = |slots, facts, strategy, second| { slots, strategy, now, min_age: 2 * day, snapshot: Err(None), facts, unmanaged: [], paths: [], second }

run = |slots, facts, strategy, second| view(Oracle.step(input(slots, facts, strategy, second)))

# The rows that `Pick.moves` gives for the tuple of the second search.
moved = |slots, facts, strategy| match Oracle.step(input(slots, facts, strategy, Bool.True)) {
	Done(chosen) => Pick.moves({ slots, chosen, facts }).map(|m| (m.id, m.from, m.to, m.why))
	_ => [("step", "gave no tuple", "", "")]
}

no_fit = |ids| Err(Err("tln: error[no_tuple]: no tuple works: the releases of ${ids} do not fit together (R-C2, R-C3)"))

pf_url = |ver| u("pf", ver)

# `json` is the free variable of `tln update json@2.3.0` (the range of the selector is `=2.3.0`). `json 2.3.0` names the platform `pf 0.26.0`. The platform `pf` is held at 0.25.0, and the index has 0.25.1, 0.26.0 and 0.27.1.
json_slot = slot("json", Bool.False, ["=2.3.0"], u("json", "2.1.0"), Free, [cand(u("json", "2.1.0"), 30), cand(u("json", "2.3.0"), 30)])

pf_cands = [cand(pf_url("0.25.0"), 30), cand(pf_url("0.25.1"), 30), cand(pf_url("0.26.0"), 30), cand(pf_url("0.27.1"), 30)]

pf_slot = |hold| slot("pf", Bool.True, [">=0.25.0"], pf_url("0.25.0"), hold, pf_cands)

pf_facts = [plat(pf_url("0.25.0")), plat(pf_url("0.25.1")), plat(pf_url("0.26.0")), plat(pf_url("0.27.1"))]

json_facts = [pkg(u("json", "2.1.0"), []), names_pf(u("json", "2.3.0"), pf_url("0.26.0"))]

# R-SP24 R-SP15 R-SP16 R-SP23 R-PH10 R-VA6 R-C1 R-C7 R-C9 R-DT2 (slice 017): the second search of a held move. The first search (the old `step`) has no tuple: `json 2.3.0` needs the platform 0.26.0, and the platform is held at 0.25.0. A `Held` slot never
# moves, so the second search has no tuple either (exit 10 as before). A `Movable` slot is the first in the search, and it tries its current value first, then the nearest: with `Highest` the higher versions from low to high (0.25.1,
# 0.26.0, not the newest 0.27.1: the move is the smallest step, Q1 of the gap file), then the lower versions from high to low. So a movable variable keeps its value when a tuple exists with it and the earlier movable variables, also when a free
# variable could get a newer release (the 3rd row: `web` 2.0.0 and `core`). A moved variable keeps the constraints of a free variable: its ranges (R-C1) and `min-release-age` (R-C7) apply. The result and the `Need` list stay in the order of the slots.
expect {
	one = |hold, second| run([json_slot, pf_slot(hold)], json_facts.concat(pf_facts), Highest, second)
	moved_both = Ok([("json", "2.3.0", Move("2.1.0")), ("pf", "0.26.0", Move("0.25.0"))])
	# A free `web` that would like 2.0.0 (it names core 1.1.0), a movable `core` at 1.0.0, and the movable platform that has to move.
	web_slot = slot("web", Bool.False, [], u("web", "1.0.0"), Free, [cand(u("web", "2.0.0"), 30), cand(u("web", "1.0.0"), 30)])
	core_slot = slot("core", Bool.False, ["^1"], u("core", "1.0.0"), Movable, [cand(u("core", "1.0.0"), 30), cand(u("core", "1.1.0"), 30)])
	web_facts = [pkg(u("web", "2.0.0"), [u("core", "1.1.0")]), pkg(u("web", "1.0.0"), []), pkg(u("core", "1.0.0"), []), pkg(u("core", "1.1.0"), [])]
	four = [web_slot, json_slot, core_slot, pf_slot(Movable)]
	# A json with 2 releases: the newest names the new platform. The first search takes 2.1.0 (R-SP15): no move. The second search keeps `pf` (it is first in the search) and the free `json` takes 2.1.0.
	json_range = { ..json_slot, ranges: ["^2"] }
	too_young = [cand(pf_url("0.25.0"), 30), cand(pf_url("0.25.1"), 30), cand(pf_url("0.26.0"), 1), cand(pf_url("0.27.1"), 30)]
	rows = [
		("the first search: no tuple with the platform held at 0.25.0 (R-SP15 is false)", one(Movable, Bool.False), no_fit("json, pf")),
		("the second search: the platform moves to 0.26.0, the nearest value that works (not 0.27.1)", one(Movable, Bool.True), moved_both),
		("a Held slot never moves: the second search has no tuple (R-SP23)", one(Held, Bool.True), no_fit("json, pf")),
		("the order of the facts does not matter (R-DT2)", run([json_slot, pf_slot(Movable)], json_facts.concat(pf_facts).rev(), Highest, Bool.True), moved_both),
		("Lowest: the same nearest value", run([json_slot, pf_slot(Movable)], json_facts.concat(pf_facts), Lowest, Bool.True), moved_both),
		("a movable slot keeps its value when a tuple exists, and the free json takes 2.1.0 (R-SP24)", run([json_range, pf_slot(Movable)], json_facts.concat(pf_facts), Highest, Bool.True), Ok([("json", "2.1.0", Keep), ("pf", "0.25.0", Keep)])),
		(
			"the movable slots come first in the search: core keeps 1.0.0, so web takes 1.0.0, and only the platform moves (R-SP24, R-VA6)",
			run(four, json_facts.concat(pf_facts).concat(web_facts), Highest, Bool.True),
			Ok([("web", "1.0.0", Keep), ("json", "2.3.0", Move("2.1.0")), ("core", "1.0.0", Keep), ("pf", "0.26.0", Move("0.25.0"))]),
		),
		("the first search of the same slots has no tuple: json and pf", run(four, json_facts.concat(pf_facts).concat(web_facts), Highest, Bool.False), no_fit("web, json, core, pf")),
		("the ranges of a movable slot apply (R-C1): 0.25.* does not admit 0.26.0", run([json_slot, { ..pf_slot(Movable), ranges: ["0.25.*"] }], json_facts.concat(pf_facts), Highest, Bool.True), no_fit("json, pf")),
		("min-release-age hides a new release for a movable slot (R-C7): 0.26.0 is 1 day old", run([json_slot, { ..pf_slot(Movable), candidates: too_young }], json_facts.concat(pf_facts), Highest, Bool.True), no_fit("json, pf")),
		("no facts: `Need` has the URLs of the tuple in the order of the slots, not of the search", run([json_slot, pf_slot(Movable)], [], Highest, Bool.True), Err(Ok([u("json", "2.3.0"), pf_url("0.25.0")]))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SP24 R-WS12 R-WS2 R-WS3 R-DI9 (slice 017): the order of the values of a movable slot, and one value for one group. `core` is held by another member at 1.2.0 (movable, the index has 1.0.0 to 1.4.0). The new entry of `add` is a free slot of the same group
# (R-WS12) that the index offers at some versions only. Two slots of one group have one value (R-WS2, R-WS3): the first search has no tuple when the new entry cannot have 1.2.0. In the second search the nearest value that the new entry has wins: `Highest` goes up
# first (1.3.0, not the newest 1.4.0), `Lowest` goes down first (1.1.0, not the oldest 1.0.0). With no selector the new entry has 1.2.0 (the first search has a tuple: the held version, R-WS12), and with a list that lacks every version no tuple exists.
expect {
	core = slot("core", Bool.False, ["^1"], u("core", "1.2.0"), Movable, [cand(u("core", "1.0.0"), 30), cand(u("core", "1.1.0"), 30), cand(u("core", "1.2.0"), 30), cand(u("core", "1.3.0"), 30), cand(u("core", "1.4.0"), 30)])
	entry = |versions| fresh(slot("core2", Bool.False, ["^1"], u("core", "1.2.0"), Free, versions.map(|v| cand(u("core", v), 30))))
	facts = ["1.0.0", "1.1.0", "1.2.0", "1.3.0", "1.4.0"].map(|v| pkg(u("core", v), []))
	pair = |version, old| Ok([("core", version, if old == "" Keep else Move(old)), ("core2", version, Move(""))])
	both = ["1.0.0", "1.1.0", "1.3.0", "1.4.0"]
	rows = [
		("the first search: the new entry has no 1.2.0, so no tuple", run([core, entry(both)], facts, Highest, Bool.False), no_fit("core, core2")),
		("Highest, second search: the nearest higher value (1.3.0, not 1.4.0)", run([core, entry(both)], facts, Highest, Bool.True), pair("1.3.0", "1.2.0")),
		("Lowest, second search: the nearest lower value (1.1.0, not 1.0.0)", run([core, entry(both)], facts, Lowest, Bool.True), pair("1.1.0", "1.2.0")),
		("Lowest: the lower values from high to low, then the higher ones from low to high", run([core, entry(["1.4.0", "1.3.0"])], facts, Lowest, Bool.True), pair("1.3.0", "1.2.0")),
		("Highest: only lower values are offered: they go from high to low", run([core, entry(["1.0.0", "1.1.0"])], facts, Highest, Bool.True), pair("1.1.0", "1.2.0")),
		("the held version is offered: no move, also in the second search (R-SP24: current first)", run([core, entry(["1.0.0", "1.2.0", "1.4.0"])], facts, Highest, Bool.True), Ok([("core", "1.2.0", Keep), ("core2", "1.2.0", Move(""))])),
		("the first search with the held version offered: a tuple, the new entry gets it (R-WS12)", run([core, entry(["1.0.0", "1.2.0", "1.4.0"])], facts, Highest, Bool.False), Ok([("core", "1.2.0", Keep), ("core2", "1.2.0", Move(""))])),
		("a Held slot of the group with a new entry that lacks its version: no tuple, also in the second search", run([{ ..core, hold: Held }, entry(both)], facts, Highest, Bool.True), no_fit("core, core2")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SP16 R-SP23 R-C1 R-C2 R-C3 R-AL9 R-WS2 (slice 017): `Pick.moves` gives one row for each `Movable` slot that the second search moved, with its old and new version and the first conflict of the old value in the final tuple (the texts are a proposal, TW24):
# R-C3 (a package names another platform: `json 2.3.0 needs pf 0.26.0`), R-C2 (a release has a dependency on a higher version: `web 2.0.0 needs core >= 1.1.0`), R-C1 (a range of the group, also of the new entry: `core 1.2.0 is outside =1.3.0`), and R-AL9
# (a problem of the closure that no release of the slots shows: a path file names `core 1.1.0`). A free slot that moves, a held slot and a movable slot that keeps its value have no row. Rows come in the order of the slots.
expect {
	core_cands = [cand(u("core", "1.0.0"), 30), cand(u("core", "1.1.0"), 30)]
	web_pin = slot("web", Bool.False, ["=2.0.0"], u("web", "1.0.0"), Free, [cand(u("web", "1.0.0"), 30), cand(u("web", "2.0.0"), 30)])
	core_low = slot("core", Bool.False, ["^1"], u("core", "1.0.0"), Movable, core_cands)
	web_facts = [pkg(u("web", "1.0.0"), []), pkg(u("web", "2.0.0"), [u("core", "1.1.0")]), pkg(u("core", "1.0.0"), []), pkg(u("core", "1.1.0"), [])]
	core_mid = slot("core", Bool.False, ["^1"], u("core", "1.2.0"), Movable, [cand(u("core", "1.2.0"), 30), cand(u("core", "1.3.0"), 30)])
	pinned_entry = fresh(slot("core2", Bool.False, ["=1.3.0"], u("core", "1.2.0"), Free, [cand(u("core", "1.2.0"), 30), cand(u("core", "1.3.0"), 30)]))
	core_facts = [pkg(u("core", "1.2.0"), []), pkg(u("core", "1.3.0"), [])]
	# A path file of the app names core 1.1.0, and no release of a slot shows it.
	file = "/p/app/main.roc"
	path_input = { ..input([core_low], [pkg(u("core", "1.0.0"), []), pkg(u("core", "1.1.0"), [])], Highest, Bool.True), unmanaged: [{ file, entries: [{ alias: "util", value: "../util/main.roc", is_platform: Bool.False }] }], paths: [{ id: "/p/util/main.roc", entries: [{ alias: "c", value: u("core", "1.1.0"), is_platform: Bool.False }] }] }
	by_path = match Oracle.step(path_input) {
		Done(chosen) => Pick.moves({ slots: [core_low], chosen, facts: path_input.facts }).map(|m| (m.id, m.from, m.to, m.why))
		_ => [("step", "gave no tuple", "", "")]
	}
	rows = [
		("R-C3: the platform moves because json 2.3.0 names pf 0.26.0", moved([json_slot, pf_slot(Movable)], json_facts.concat(pf_facts), Highest), [("pf", "0.25.0", "0.26.0", "json 2.3.0 needs pf 0.26.0")]),
		("R-C2: core moves because web 2.0.0 has a dependency on core 1.1.0 (the free web moves too and has no row)", moved([web_pin, core_low], web_facts, Highest), [("core", "1.0.0", "1.1.0", "web 2.0.0 needs core >= 1.1.0")]),
		("R-C1: the range of the new entry of the group excludes the held version (R-WS2)", moved([core_mid, pinned_entry], core_facts, Highest), [("core", "1.2.0", "1.3.0", "core 1.2.0 is outside =1.3.0")]),
		("R-AL9: a problem of the closure that the releases of the slots do not show", by_path, [("core", "1.0.0", "1.1.0", "core 1.0.0 does not fit the closure of the new tuple")]),
		("a movable slot that keeps its value has no row", moved([{ ..json_slot, ranges: ["^2"] }, pf_slot(Movable)], json_facts.concat(pf_facts), Highest), []),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
