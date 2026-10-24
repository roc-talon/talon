app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Db
import lib.Ident
import lib.Index
import lib.Oracle
import lib.Pick

main! = |_args| Ok({})

now = 1792065600

day = 86400

nightly = "nightly-2026-10-14-38a3029"

# A release URL of the fixture host (as in `oracle.roc`).
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

pf_fact = |url| { url, release: { kind: Platform, pf: Err(None), deps: [] } }

slot = |id, ranges, current, hold, candidates| { id, is_platform: Bool.False, ranges, current: Ok(current), hold, named: Err(None), candidates, files: [] }

input = |slots, facts| { slots, strategy: Highest, now, min_age: 2 * day, snapshot: Err(None), facts, unmanaged: [], paths: [], second: Bool.False }

# A row of compat.db for a release on a compiler (the target `any` is a check).
row = |url, id, outcome, modules| { hash: hash(url), nightly: id, target: "any", outcome, modules, closure: "" }

key = |url, id| { hash: hash(url), nightly: id, target: "any" }

compat = |checks, looked, probes| { compiler: Ok(nightly), checks, looked, probes, conflicts: [], used: [], domain: Ok([nightly]), inferred: [] }

view = |r| match r {
	Need(urls) => "need ${Str.join_with(urls.map(|url| url.drop_prefix("https://github.com/acme/")), " ")}"
	Pairs(pairs) => "pairs ${Str.join_with(pairs.map(|p| "${p.id.drop_prefix("https://github.com/acme/")}@${p.nightly}${if p.is_platform "!" else ""}"), " ")}"
	Scan(s) => "scan ${Str.join_with(s.ids.map(|url| url.drop_prefix("https://github.com/acme/")), " ")}"
	Wide => "wide"
	Done(chosen) => "done ${Str.join_with(chosen.map(|c| "${c.id}=${c.version}"), " ")}"
	Fail(fail) => fail.line()
}

# json has 3 releases, 1.0.0 is the header value (it is a value of the variable: R-C9). The facts of the headers are known.
json = |v| u("json", v)

json_slot = slot("json", [], json("1.0.0"), Free, [cand(json("1.0.0"), 30), cand(json("2.0.0"), 30), cand(json("3.0.0"), 30)])

json_facts = [fact(json("1.0.0"), []), fact(json("2.0.0"), []), fact(json("3.0.0"), [])]

p = |ver| "json/releases/download/${ver}/jsonx${ver.replace_each(".", "x")}.tar.zst"

# R-AL4 R-EP7 R-EP8 R-UM1 R-EF1 R-P4 R-VA6 R-DT2 (slice 036b): the step with the probe facts of one compiler (the held nightly). The pairs (release, compiler) of the best tuple that have no check are asked for, in one `Pairs` (`Allowed`); the value that the header has
# now is a pass (the baseline covers it: a run that changes nothing probes nothing). A hard fail (a fail with no module), a hang and a crash of a release take it out of the tuple, and the step asks for the pair of the next best release. A fail with modules
# is a `Scan` of the tuple when no scan result is known (new rows in expect 8). A check of another compiler and a row of a build (the target `host`) are no check of this pair. The checks in another order give the same answer (R-DT2).
expect {
	run = |checks| view(Oracle.step_probed(input([json_slot], json_facts), compat(checks, [], Allowed)))
	pair = |ver| "pairs ${p(ver)}@${nightly}"
	hard = |ver| row(json(ver), nightly, Fail, [])
	rows = [
		("no check: the best release is asked for, the header value is not", run([]), pair("3.0.0")),
		("a hard fail of 3.0.0: the next release is asked for", run([hard("3.0.0")]), pair("2.0.0")),
		("a hang of 3.0.0 (a fault, R-EP5): the same", run([row(json("3.0.0"), nightly, Hang, [])]), pair("2.0.0")),
		("a crash of 3.0.0: the same", run([row(json("3.0.0"), nightly, Crash, [])]), pair("2.0.0")),
		("hard fails of 3.0.0 and 2.0.0: the header value is a pass, so it is the result and nothing is asked for", run([hard("3.0.0"), hard("2.0.0")]), "done json=1.0.0"),
		("a pass of 3.0.0: done", run([row(json("3.0.0"), nightly, Pass, [])]), "done json=3.0.0"),
		("a fail of 3.0.0 with a module and no scan result: the step asks for the scan of the tuple (R-UM1, slice 036b2)", run([row(json("3.0.0"), nightly, Fail, ["Yaml.roc"])]), "scan ${p("3.0.0")}"),
		("a pass of another compiler: no check of this pair", run([row(json("3.0.0"), "nightly-2026-10-01-aaaaaaa", Pass, [])]), pair("3.0.0")),
		("a build row (target host): no check of this pair", run([{ ..row(json("3.0.0"), nightly, Pass, []), target: "x64musl" }]), pair("3.0.0")),
		("the same rows in another order (R-DT2)", run([hard("2.0.0"), hard("3.0.0")]), "done json=1.0.0"),
		("a real fail row of the header value beats the assumed pass: that value is out, and the pass of 3.0.0 is the result", run([row(json("1.0.0"), nightly, Fail, []), row(json("3.0.0"), nightly, Pass, [])]), "done json=3.0.0"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-AL4 R-LD3 R-WS2 R-C9 (slice 036b): which slots are asked for. A new name has no header value, so its release is asked for. A platform pair is marked (R-LD3: the platform has a text of its own). A held slot is never asked for (its value is the header value).
# 2 slots give the pairs in the order of the slots, no repeat: a slot that changes and a slot that does not.
expect {
	pf = |ver| u("pf", ver)
	pf_slot = { ..slot("pf", [], pf("0.1.0"), Free, [cand(pf("0.1.0"), 30), cand(pf("0.1.1"), 30)]), is_platform: Bool.True }
	new_slot = { ..slot("new", [], u("new", "1.0.0"), Free, [cand(u("new", "1.0.0"), 30)]), current: Err(None) }
	held = slot("json", [], json("1.0.0"), Held, [])
	facts = json_facts.concat([pf_fact(pf("0.1.0")), pf_fact(pf("0.1.1")), fact(u("new", "1.0.0"), [])])
	run = |slots, checks| view(Oracle.step_probed(input(slots, facts), compat(checks, [], Allowed)))
	rows = [
		("the platform pair is marked", run([pf_slot], []), "pairs pf/releases/download/0.1.1/pfx0x1x1.tar.zst@${nightly}!"),
		("a new name: its release is asked for", run([new_slot], []), "pairs new/releases/download/1.0.0/newx1x0x0.tar.zst@${nightly}"),
		("2 slots: the pairs are in the order of the slots", run([json_slot, pf_slot], []), "pairs ${p("3.0.0")}@${nightly} pf/releases/download/0.1.1/pfx0x1x1.tar.zst@${nightly}!"),
		("a slot that has its pair: only the other is asked for", run([json_slot, pf_slot], [row(json("3.0.0"), nightly, Pass, [])]), "pairs pf/releases/download/0.1.1/pfx0x1x1.tar.zst@${nightly}!"),
		("a held slot is never asked for", run([held], []), "done json=1.0.0"),
		("a header value that is the best release: nothing changes, nothing is asked for", run([slot("json", [], json("3.0.0"), Free, [cand(json("1.0.0"), 30), cand(json("3.0.0"), 30)])], []), "done json=3.0.0"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-LF2 R-EP9 R-AL4 (slice 036b): `Off` is `--no-probe`: the step never asks for a probe. Known evidence is used: a chosen release that changes, has no row and is not in `looked` is a pair to look up in the db (`Pairs`: the command looks up and
# does not probe). After the lookup (`looked`) the step goes on with the rows that were found: a fail takes the release out, and the next best release is looked up. A release that was looked up and has no row is fit (a pair with no fact, 035 Q4).
expect {
	run = |checks, looked| view(Oracle.step_probed(input([json_slot], json_facts), compat(checks, looked, Off)))
	asked = |ver| "pairs ${p(ver)}@${nightly}"
	hard = |ver| row(json(ver), nightly, Fail, [])
	rows = [
		("the best release is not looked up: a lookup is asked for", run([], []), asked("3.0.0")),
		("looked up, no row: it is fit", run([], [key(json("3.0.0"), nightly)]), "done json=3.0.0"),
		("a row with a hard fail: the next release is looked up", run([hard("3.0.0")], [key(json("3.0.0"), nightly)]), asked("2.0.0")),
		("both are looked up and fail: the header value", run([hard("3.0.0"), hard("2.0.0")], [key(json("3.0.0"), nightly), key(json("2.0.0"), nightly)]), "done json=1.0.0"),
		("a row of 3.0.0 without a key in `looked` is a lookup too (the key is the row's own): it is known", run([row(json("3.0.0"), nightly, Pass, [])], []), "done json=3.0.0"),
		("a lookup of another compiler is no lookup of this pair", run([], [key(json("3.0.0"), "nightly-2026-10-01-aaaaaaa")]), asked("3.0.0")),
		("nothing changes: no lookup", view(Oracle.step_probed(input([slot("json", [], json("3.0.0"), Free, [cand(json("3.0.0"), 30)])], json_facts), compat([], [], Off))), "done json=3.0.0"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SO22 R-LF3 R-PH13 (slice 036b, U3: `--no-check` runs no probe, as slice 031 tests it): with no compiler (`--no-check`, or no compiler at all) there is no compiler slot, no check is read, and the answer is the answer of `Oracle.step` (slice 036). The step with a compiler and `Off`
# with every pair looked up and no row gives it too. A row of the db is not read without a compiler.
expect {
	slots = [json_slot]
	hard3 = row(json("3.0.0"), nightly, Fail, [])
	none = { compiler: Err(None), checks: [hard3], looked: [], probes: Allowed, conflicts: [], used: [], domain: Ok([nightly]), inferred: [] }
	plain = |facts| view(Oracle.step_probed(input(slots, facts), none))
	same = |facts| match Oracle.step(input(slots, facts)) {
		Need(urls) => "need ${Str.join_with(urls.map(|url| url.drop_prefix("https://github.com/acme/")), " ")}"
		Done(chosen) => "done ${Str.join_with(chosen.map(|c| "${c.id}=${c.version}"), " ")}"
		Fail(fail) => fail.line()
	}
	looked = [key(json("1.0.0"), nightly), key(json("2.0.0"), nightly), key(json("3.0.0"), nightly)]
	rows = [
		("no compiler: the best release, the fail row is not read", plain(json_facts), "done json=3.0.0"),
		("the same as Oracle.step", same(json_facts), "done json=3.0.0"),
		("a compiler, Off, all looked up, no row: the same", view(Oracle.step_probed(input(slots, json_facts), compat([], looked, Off))), "done json=3.0.0"),
		("no compiler, a header fact is missing: the Need of the step", plain(json_facts.take_first(1)), same(json_facts.take_first(1))),
		("the Need names the best release", plain(json_facts.take_first(1)), "need ${p("3.0.0")}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-AL5 R-AL6 R-PH13 (slice 036b, Q2 of slice 036): a tuple that the ladder dropped is a conflict of the caller. It is a list of (place of a slot, release URL). The whole tuple: the step gives the next best tuple. The releases that the ladder blames: the conflict has
# those releases only, so a tuple with the other values stays out only when it has all of them. The closure walk (R-AL9) and the pairs come in this order: the pairs of the tuple first, then its closure. `json` 3.0.0 names `mid` 1.0.0, which names `core` 1.1.0, and `core` is
# held at 1.0.0 (a slot): the closure of json 3.0.0 has a problem that no fact of the slots shows (R-C2).
expect {
	core_slot = slot("core", [], u("core", "1.0.0"), Held, [])
	facts = json_facts.concat([fact(u("core", "1.0.0"), [])])
	run = |slots, conflicts, checks| view(Oracle.step_probed(input(slots, facts), { compiler: Ok(nightly), checks, looked: [], probes: Allowed, conflicts, used: [], domain: Ok([nightly]), inferred: [] }))
	pass = |ver| row(json(ver), nightly, Pass, [])
	deep = [fact(json("1.0.0"), []), fact(json("2.0.0"), []), fact(json("3.0.0"), [u("mid", "1.0.0")]), fact(u("mid", "1.0.0"), [u("core", "1.1.0")]), fact(u("core", "1.0.0"), [])]
	rows = [
		("the whole tuple is dropped: the next release is asked for", run([json_slot, core_slot], [[{ at: 0, id: json("3.0.0") }, { at: 1, id: u("core", "1.0.0") }]], []), "pairs ${p("2.0.0")}@${nightly}"),
		("the blame names only json 3.0.0: the same result", run([json_slot, core_slot], [[{ at: 0, id: json("3.0.0") }]], []), "pairs ${p("2.0.0")}@${nightly}"),
		("a conflict that names 2 releases of 2 slots: json 3.0.0 stays with a core that is not 1.0.0 only, so with the held core it is out", run([json_slot, core_slot], [[{ at: 0, id: json("3.0.0") }, { at: 1, id: u("core", "1.0.0") }]], [pass("2.0.0")]), "done json=2.0.0 core=1.0.0"),
		("a place that is no slot never applies", run([json_slot, core_slot], [[{ at: 7, id: json("3.0.0") }]], []), "pairs ${p("3.0.0")}@${nightly}"),
		("no conflict, a pass: json 3.0.0", run([json_slot, core_slot], [], [pass("3.0.0")]), "done json=3.0.0 core=1.0.0"),
		("the pairs come before the closure walk: json 3.0.0 has a closure problem, but the first answer is still its pair", view(Oracle.step_probed(input([json_slot, core_slot], deep), compat([], [], Allowed))), "pairs ${p("3.0.0")}@${nightly}"),
		("with the pass, the closure walk drops json 3.0.0 and the next best release is asked for", view(Oracle.step_probed(input([json_slot, core_slot], deep), compat([pass("3.0.0")], [], Allowed))), "pairs ${p("2.0.0")}@${nightly}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PH13 R-LD3 R-EP7 R-OV2 (slice 036b, TW24): the text of a failure that has a probe cause. `no tuple works: the unit check on <compiler> fails for <blame>; <blame>`: `<name> <version>` (`the platform <name> <version>` for the platform) and `(no module is named)`,
# `(hangs)` or `(crashes)`, in the order of the explanation, no repeat. This is the text of `Units.judge` (slice 031), so a run with one tuple gives the text that it gave before. An exact range (`=2.1.0`, an override, R-OV2) has one value: its fail is no tuple.
# A failure with no probe cause has the text of `step` (the releases of the slots do not fit together).
# Slice 036c: a failure with a probe cause has the lines of `Explain.lines` after the first line. Here D is `[H]`: no cause line, no hint, so only the `fix:` block (`tests/unit/oracledomain.roc` has D with more compilers).
expect {
	exact = slot("json", ["=3.0.0"], json("1.0.0"), Free, [cand(json("1.0.0"), 30), cand(json("3.0.0"), 30)])
	pf_slot = { ..slot("pf", ["=0.1.1"], u("pf", "0.1.0"), Free, [cand(u("pf", "0.1.0"), 30), cand(u("pf", "0.1.1"), 30)]), is_platform: Bool.True }
	facts = json_facts.concat([pf_fact(u("pf", "0.1.0")), pf_fact(u("pf", "0.1.1"))])
	a_slot = slot("a", [], u("a", "1.0.0"), Free, [cand(u("a", "1.0.0"), 30)])
	b_slot = slot("b", [], u("b", "1.0.0"), Held, [])
	run = |slots, checks| view(Oracle.step_probed(input(slots, facts), compat(checks, [], Allowed)))
	line = |text| "tln: error[no_tuple]: no tuple works: the unit check on ${nightly} fails for ${text}\n  fix: tln roc use <id>\n       or tln upgrade roc"
	rows = [
		("a hard fail of the only value", run([exact], [row(json("3.0.0"), nightly, Fail, [])]), line("acme/json 3.0.0 (no module is named)")),
		("a hang", run([exact], [row(json("3.0.0"), nightly, Hang, [])]), line("acme/json 3.0.0 (hangs)")),
		("a crash", run([exact], [row(json("3.0.0"), nightly, Crash, [])]), line("acme/json 3.0.0 (crashes)")),
		("the platform", run([pf_slot], [row(u("pf", "0.1.1"), nightly, Fail, [])]), line("the platform acme/pf 0.1.1 (no module is named)")),
		("2 slots that both fail: the explanation names the causes of its proof, here the first slot (the crash of the platform is not part of it)", run([exact, pf_slot], [row(json("3.0.0"), nightly, Fail, []), row(u("pf", "0.1.1"), nightly, Crash, [])]), line("acme/json 3.0.0 (no module is named)")),
		("the platform fails first in the order of the slots: its blame", run([pf_slot, exact], [row(json("3.0.0"), nightly, Fail, []), row(u("pf", "0.1.1"), nightly, Crash, [])]), line("the platform acme/pf 0.1.1 (crashes)")),
		("no probe cause (a release that needs a higher version of a held group): the text of `step`", view(Oracle.step_probed(input([a_slot, b_slot], [fact(u("a", "1.0.0"), [u("b", "1.5.0")]), fact(u("b", "1.0.0"), [])]), compat([], [], Allowed))), "tln: error[no_tuple]: no tuple works: the releases of a, b do not fit together (R-C2, R-C3)"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-AL8 R-AL4 (slice 036b, fix F1): a unit probe runs in the dir of the package, so the header of each release of a pair is read (the package is fetched) before the probe: `Need` comes before `Pairs`. The release with no header fact is asked for first,
# also when the header of another release is known. When the header is known, the pair is asked for.
expect {
	run = |facts| view(Oracle.step_probed(input([json_slot], facts), compat([], [], Allowed)))
	rows = [
		("no header fact: the header of the best release is read first", run([]), "need ${p("3.0.0")}"),
		("the header of another release is known: the best one is still read first", run([fact(json("2.0.0"), [])]), "need ${p("3.0.0")}"),
		("the header of the best release is known: now the pair", run([fact(json("3.0.0"), [])]), "pairs ${p("3.0.0")}@${nightly}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-UM1 R-AL5 R-AL4 R-LF2 (slice 036b2): the used-module scan. A chosen release with a real fail that has modules, and no scan result, is a `Scan` of the tuple: the tuple is good until the command knows which modules the app uses. `compat.used` has one row for each scanned
# release (also with no module). A fail whose module is used drops the release (the solver gives the next one, and its pair is asked for). A fail whose modules are not used is no blame: done. `main.roc` is used by every release (`Units.judge`), so a fail in it needs no scan.
# A hard fail, a hang, a crash and a pass need no scan. Only the chosen releases are scanned, in the order of the slots, with no repeat. The scan result of another release does not count. `Off` scans too (the row comes from the db).
expect {
	a_slot = slot("a", [], u("a", "1.0.0"), Free, [cand(u("a", "1.0.0"), 30), cand(u("a", "2.0.0"), 30)])
	facts = json_facts.concat([fact(u("a", "1.0.0"), []), fact(u("a", "2.0.0"), [])])
	yaml = |ver| row(json(ver), nightly, Fail, ["Yaml.roc"])
	use = |ver, modules| { id: json(ver), modules }
	run = |checks, used| view(Oracle.step_probed(input([json_slot], facts), { compiler: Ok(nightly), checks, looked: [], probes: Allowed, conflicts: [], used, domain: Ok([nightly]), inferred: [] }))
	run2 = |checks, used| view(Oracle.step_probed(input([json_slot, a_slot], facts), { compiler: Ok(nightly), checks, looked: [], probes: Allowed, conflicts: [], used, domain: Ok([nightly]), inferred: [] }))
	pass_a = row(u("a", "2.0.0"), nightly, Pass, [])
	tuple = match Oracle.step_probed(input([json_slot, a_slot], facts), { compiler: Ok(nightly), checks: [yaml("3.0.0"), pass_a], looked: [], probes: Allowed, conflicts: [], used: [], domain: Ok([nightly]), inferred: [] }) {
		Scan(s) => Str.join_with(s.chosen.map(|c| "${c.id}=${c.version}"), " ")
		_ => "no scan"
	}
	off = view(Oracle.step_probed(input([json_slot], facts), { compiler: Ok(nightly), checks: [yaml("3.0.0")], looked: [key(json("3.0.0"), nightly)], probes: Off, conflicts: [], used: [], domain: Ok([nightly]), inferred: [] }))
	rows = [
		("a fail with a module, no scan result: scan", run([yaml("3.0.0")], []), "scan ${p("3.0.0")}"),
		("the scan found Yaml.roc used: 3.0.0 is out, the pair of the next release is asked for", run([yaml("3.0.0")], [use("3.0.0", ["Yaml.roc"])]), "pairs ${p("2.0.0")}@${nightly}"),
		("the scan found another module used: the fail touches nothing, done", run([yaml("3.0.0")], [use("3.0.0", ["Parser.roc"])]), "done json=3.0.0"),
		("a scan with no module (a row with an empty list): done, and no second scan", run([yaml("3.0.0")], [use("3.0.0", [])]), "done json=3.0.0"),
		("the scan result of another release does not count", run([yaml("3.0.0")], [use("2.0.0", ["Yaml.roc"])]), "scan ${p("3.0.0")}"),
		("a fail in main.roc: used by every release, no scan: the next release", run([row(json("3.0.0"), nightly, Fail, ["main.roc"])], []), "pairs ${p("2.0.0")}@${nightly}"),
		("a fail in main.roc and in Yaml.roc: the same", run([row(json("3.0.0"), nightly, Fail, ["Yaml.roc", "main.roc"])], []), "pairs ${p("2.0.0")}@${nightly}"),
		("a fail of a release that is not chosen: no scan", run([yaml("2.0.0"), row(json("3.0.0"), nightly, Pass, [])], []), "done json=3.0.0"),
		("a fail with a module of another compiler: no check of this pair", run([row(json("3.0.0"), "nightly-2026-10-01-aaaaaaa", Fail, ["Yaml.roc"])], []), "pairs ${p("3.0.0")}@${nightly}"),
		("2 slots: the chosen releases with a fail are scanned in the order of the slots, once each", run2([yaml("3.0.0"), row(u("a", "2.0.0"), nightly, Fail, ["Lib.roc"])], []), "scan ${p("3.0.0")} a/releases/download/2.0.0/ax2x0x0.tar.zst"),
		("2 slots: only the release with a fail is scanned", run2([yaml("3.0.0"), pass_a], []), "scan ${p("3.0.0")}"),
		("2 slots: json has a scan result and a fail that touches nothing: only a is scanned", run2([yaml("3.0.0"), row(u("a", "2.0.0"), nightly, Fail, ["Lib.roc"])], [use("3.0.0", [])]), "scan a/releases/download/2.0.0/ax2x0x0.tar.zst"),
		("the verdict has the whole tuple, one release for each slot", tuple, "json=3.0.0 a=2.0.0"),
		("`Off`: a row from the db with a module is scanned too", off, "scan ${p("3.0.0")}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
