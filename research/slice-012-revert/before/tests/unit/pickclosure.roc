app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Ident
import lib.Index
import lib.Pick

main! = |_args| Ok({})

now = 1792065600

day = 86400

# A release URL of the fixture host (as in `closure.roc`).
u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

cand = |url, days| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - days * day, size: 1 }
	Err(_) => crash "bad test URL"
}

slot = |id, ranges, current, free, candidates| { id, is_platform: Bool.False, ranges, current: Ok(current), free, named: Err(None), candidates }

fact = |url, deps| { url, release: { kind: Package, pf: Err(None), deps } }

view = |r| match r {
	Need(urls) => Err(Ok(urls))
	Done(chosen) => Ok(chosen.map(|c| (c.id, c.version, c.change, c.note)))
	Fail(fail) => Err(Err(fail.line()))
}

step = |slots, facts, strategy| view(Pick.step({ slots, strategy, now, min_age: 2 * day, snapshot: Err(None), facts }))

no_fit = |ids| Err(Err("tln: error[no_tuple]: no tuple works: the releases of ${ids} do not fit together (R-C2, R-C3)"))

mid_slot = slot("mid", [], u("mid", "1.0.0"), Bool.True, [cand(u("mid", "1.0.0"), 30)])

core_slot = slot("core", ["^1"], u("core", "1.0.0"), Bool.True, [cand(u("core", "1.1.0"), 30), cand(u("core", "1.0.0"), 30)])

# R-C2 R-C1 R-VA6 R-DT2 R-DI9 R-FE1 (Q14 of slice 009, slice 005 Q7): R-C2 over the full closure. The app names `mid` and `core` (header value 1.0.0). `mid` names `text 1.1.0` (a package that is no variable), and `text 1.1.0` names
# `core 1.1.0`. So the chain app, mid, text, core needs `core` at 1.1.0 or higher, and a check of one level does not see it. The step asks for the header of `text 1.1.0` (`Need`: a package of the closure, 2 levels below the app) before it
# gives a tuple. A `Foreign` URL and a path value in the dependencies of a release are not followed (R-H4, R-H7). With `Lowest` the first tuple is `core 1.0.0`, and the header of `text` shows that it does not fit, so the step moves on to `core 1.1.0`
# (and asks for its header). With `Highest` the first tuple is `core 1.1.0`, and the step still needs the header of `text 1.1.0` to know that it fits. A held `core`, or a range `=1.0.0`, has no tuple: the failure of R-C2.
# The result does not depend on the order of the facts (R-DT2).
expect {
	mid_f = fact(u("mid", "1.0.0"), [u("text", "1.1.0"), "https://example.org/x.tar.zst", "../util/main.roc"])
	core10 = fact(u("core", "1.0.0"), [])
	core11 = fact(u("core", "1.1.0"), [])
	text_f = fact(u("text", "1.1.0"), [u("core", "1.1.0")])
	moved = Ok([("mid", "1.0.0", Keep, Err(None)), ("core", "1.1.0", Move("1.0.0"), Err(None))])
	held = { ..core_slot, free: Bool.False }
	exact = { ..core_slot, ranges: ["=1.0.0"] }
	rounds = [
		("lowest, round 1: the first tuple", step([mid_slot, core_slot], [], Lowest), Err(Ok([u("mid", "1.0.0"), u("core", "1.0.0")]))),
		("lowest, round 2: mid names text, which is a level 2 package: its header is needed", step([mid_slot, core_slot], [mid_f, core10], Lowest), Err(Ok([u("text", "1.1.0")]))),
		("lowest, round 2b: the facts of the tuple first, then the deeper packages", step([mid_slot, core_slot], [mid_f], Lowest), Err(Ok([u("core", "1.0.0"), u("text", "1.1.0")]))),
		("lowest, round 3: text names core 1.1.0, so core 1.0.0 is dropped and 1.1.0 is needed", step([mid_slot, core_slot], [mid_f, core10, text_f], Lowest), Err(Ok([u("core", "1.1.0")]))),
		("lowest, round 4: done", step([mid_slot, core_slot], [mid_f, core10, text_f, core11], Lowest), moved),
		("the order of the facts does not matter", step([mid_slot, core_slot], [core11, text_f, core10, mid_f], Lowest), moved),
		("highest, round 1: the first tuple has core 1.1.0", step([mid_slot, core_slot], [mid_f, core11], Highest), Err(Ok([u("text", "1.1.0")]))),
		("highest, round 2: done", step([mid_slot, core_slot], [mid_f, core11, text_f], Highest), moved),
		("a held core: no tuple", step([mid_slot, held], [mid_f, core10, text_f], Lowest), no_fit("mid, core")),
		("a range =1.0.0: no tuple", step([mid_slot, exact], [mid_f, core10, text_f], Lowest), no_fit("mid, core")),
	]
	bad = rounds.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-C2 R-C8 R-OV1 R-H7 (Design 2: highest wins, winners only; the series is part of the group): which edges count. `mid` names `text 1.0.0`, which names `core 1.1.0`. `other` names `text 1.1.0`, which has no dependency. The highest
# version wins, so `text 1.0.0` is not built: its header is not asked for, and its `core 1.1.0` does not conflict with a held `core 1.0.0`. Without `other` the winner is `text 1.0.0`, and the tuple has no fit. A cycle between
# packages ends the step (`mid` names `text`, `text` names `mid`). A dependency on `core 2.0.0` is another group than the slot `core` (series 1): no conflict, but it is a package of the closure, so its header is needed.
expect {
	other_slot = slot("other", [], u("other", "1.0.0"), Bool.True, [cand(u("other", "1.0.0"), 30)])
	held = slot("core", ["^1"], u("core", "1.0.0"), Bool.False, [])
	mid_f = fact(u("mid", "1.0.0"), [u("text", "1.0.0")])
	other_f = fact(u("other", "1.0.0"), [u("text", "1.1.0")])
	core_f = fact(u("core", "1.0.0"), [])
	text10 = fact(u("text", "1.0.0"), [u("core", "1.1.0")])
	text11 = fact(u("text", "1.1.0"), [])
	kept = Ok([("mid", "1.0.0", Keep, Err(None)), ("other", "1.0.0", Keep, Err(None)), ("core", "1.0.0", Keep, Err(None))])
	cycle_mid = fact(u("mid", "1.0.0"), [u("text", "1.0.0")])
	cycle_text = fact(u("text", "1.0.0"), [u("mid", "1.0.0")])
	series_text = fact(u("text", "1.1.0"), [u("core", "2.0.0")])
	series_mid = fact(u("mid", "1.0.0"), [u("text", "1.1.0")])
	core20 = fact(u("core", "2.0.0"), [])
	core_slot1 = slot("core", ["^1"], u("core", "1.0.0"), Bool.True, [cand(u("core", "1.0.0"), 30)])
	rows = [
		("the highest text wins: text 1.0.0 is not asked for", step([mid_slot, other_slot, held], [mid_f, other_f, core_f], Highest), Err(Ok([u("text", "1.1.0")]))),
		("its dependency on core 1.1.0 does not count", step([mid_slot, other_slot, held], [mid_f, other_f, core_f, text10, text11], Highest), kept),
		("without other, text 1.0.0 wins and core 1.1.0 is a conflict", step([mid_slot, held], [mid_f, core_f, text10], Highest), no_fit("mid, core")),
		("a cycle between packages ends the step", step([mid_slot], [cycle_mid, cycle_text], Highest), Ok([("mid", "1.0.0", Keep, Err(None))])),
		("core 2.0.0 is another group: its header is needed", step([mid_slot, core_slot1], [series_mid, series_text, core_f], Highest), Err(Ok([u("core", "2.0.0")]))),
		("core 2.0.0 is another group: no conflict", step([mid_slot, core_slot1], [series_mid, series_text, core_f, core20], Highest), Ok([("mid", "1.0.0", Keep, Err(None)), ("core", "1.0.0", Keep, Err(None))])),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
