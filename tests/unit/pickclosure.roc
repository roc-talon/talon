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

step = |slots, facts, strategy| view(Pick.step({ slots, strategy, now, min_age: 2 * day, snapshot: Err(None), facts, unmanaged: [], paths: [] }))

# Slice 016: the same with the path entries of the members (`unmanaged`, the header entries that no slot owns) and the path files that are read (`paths`).
step_paths = |facts| view(Pick.step({ slots: facts.slots, strategy: facts.strategy, now, min_age: 2 * day, snapshot: Err(None), facts: facts.facts, unmanaged: facts.unmanaged, paths: facts.paths }))

dep = |alias, value| { alias, value, is_platform: Bool.False }

node = |id, entries| { id, entries }

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

# R-C2 R-C8 R-OV1 R-H7 R-DT2 R-AL9 (Design 2: highest wins, winners only; the series is part of the group): which edges count. `mid` names `text 1.0.0`, which names `core 1.1.0`. `other` names `text 1.1.0`, which has no dependency. The highest
# version wins, so `text 1.0.0` is not built: its header is not asked for, and its `core 1.1.0` does not conflict with a held `core 1.0.0`. Without `other` the winner is `text 1.0.0`, and the tuple has no fit. A cycle between
# packages (`mid` names `text`, `text` names `mid`) is a problem of the closure (R-AL9, slice 016): the tuple is a conflict, and with no other tuple the step has no fit. A dependency on `core 2.0.0` is another group than the slot `core` (series 1): no conflict, but it is a package of the closure, so its header is needed.
# Slice 012, gap P8: an edge to a LOWER version of a slot group is no winner: `mid` names `core 1.0.0` and the tuple has `core 1.1.0`, so the header of `core 1.0.0` is not asked for (rule 3 of `Pick.step`: a lower version is not followed).
# Slice 012, gap P9: the winners that a release names are asked for in the order of its `deps` (R-DT2: the order is the order of the followed edges, not a sort): `text` then `util`, and `util` then `text` for the reverse list.
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
	core_hi = slot("core", ["^1"], u("core", "1.0.0"), Bool.True, [cand(u("core", "1.1.0"), 30), cand(u("core", "1.0.0"), 30)])
	low_edge = fact(u("mid", "1.0.0"), [u("core", "1.0.0")])
	core11 = fact(u("core", "1.1.0"), [])
	two = fact(u("mid", "1.0.0"), [u("text", "1.0.0"), u("util", "1.0.0")])
	two_rev = fact(u("mid", "1.0.0"), [u("util", "1.0.0"), u("text", "1.0.0")])
	rows = [
		("the highest text wins: text 1.0.0 is not asked for", step([mid_slot, other_slot, held], [mid_f, other_f, core_f], Highest), Err(Ok([u("text", "1.1.0")]))),
		("its dependency on core 1.1.0 does not count", step([mid_slot, other_slot, held], [mid_f, other_f, core_f, text10, text11], Highest), kept),
		("without other, text 1.0.0 wins and core 1.1.0 is a conflict", step([mid_slot, held], [mid_f, core_f, text10], Highest), no_fit("mid, core")),
		("slice 016, R-AL9: a cycle between packages is a problem of the closure, so the tuple is a conflict (it was Done: the walk failed after it)", step([mid_slot], [cycle_mid, cycle_text], Highest), no_fit("mid")),
		("core 2.0.0 is another group: its header is needed", step([mid_slot, core_slot1], [series_mid, series_text, core_f], Highest), Err(Ok([u("core", "2.0.0")]))),
		("core 2.0.0 is another group: no conflict", step([mid_slot, core_slot1], [series_mid, series_text, core_f, core20], Highest), Ok([("mid", "1.0.0", Keep, Err(None)), ("core", "1.0.0", Keep, Err(None))])),
		("P8: an edge to a lower version of a slot group needs no header", step([mid_slot, core_hi], [low_edge, core11], Highest), Ok([("mid", "1.0.0", Keep, Err(None)), ("core", "1.1.0", Move("1.0.0"), Err(None))])),
		("P9: the winners are asked for in the order of the deps", step([mid_slot], [two], Highest), Err(Ok([u("text", "1.0.0"), u("util", "1.0.0")]))),
		("P9: the reverse list gives the reverse order", step([mid_slot], [two_rev], Highest), Err(Ok([u("util", "1.0.0"), u("text", "1.0.0")]))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-AL9 R-AL8 R-H7 R-C2 R-DT2 R-FE1 (slice 016: one closure rule, path entries are nodes of the closure): the app has the entry `util: ../util/main.roc` (the file is `/p/util/main.roc`) and a foreign URL, and no slot owns them (`unmanaged`). The slot `json` has the header
# value 2.1.0 and the releases 2.1.0 and 2.2.0. `Need` has the ids of the nodes that the closure follows and that the step lacks: first the URLs of the chosen slots, then the other nodes in the order of the followed edges (a path file is an absolute path, a foreign URL is never needed).
# The file of `util` names `json 2.2.0`, so with `Lowest` the tuple json 2.1.0 is a conflict (roc: the header pin is lower than a dependency needs). The step moves on to json 2.2.0, as it does for the dependency of a release (the old code did not see the edge: it gave json 2.1.0, and the walk failed with exit 10).
# A path file that names a LOWER version is no conflict, and the header of that version is not asked for. A path file under a path file (`./inner/main.roc`, relative to the dir of its file) and a package that a path file names are nodes too, and the edges of the nested file count. A held `json` has no other tuple: no fit.
# The result does not depend on the order of the facts or of the paths (R-DT2).
expect {
	file = "/p/app/main.roc"
	json_slot = slot("json", [], u("json", "2.1.0"), Bool.True, [cand(u("json", "2.1.0"), 30), cand(u("json", "2.2.0"), 30)])
	held = { ..json_slot, free: Bool.False }
	unmanaged = [{ file, entries: [dep("util", "../util/main.roc"), dep("ext", "https://example.org/x.tar.zst")] }]
	json21 = fact(u("json", "2.1.0"), [])
	json22 = fact(u("json", "2.2.0"), [])
	text10 = fact(u("text", "1.0.0"), [])
	n_util = node("/p/util/main.roc", [dep("j", u("json", "2.2.0"))])
	n_low = node("/p/util/main.roc", [dep("j", u("json", "2.0.0"))])
	n_nest = node("/p/util/main.roc", [dep("inner", "./inner/main.roc"), dep("txt", u("text", "1.0.0"))])
	n_inner = node("/p/util/inner/main.roc", [dep("j", u("json", "2.2.0"))])
	run = |slots, strategy, facts, paths| step_paths({ slots, strategy, facts, unmanaged, paths })
	moved = Ok([("json", "2.2.0", Move("2.1.0"), Err(None))])
	kept = Ok([("json", "2.1.0", Keep, Err(None))])
	rows = [
		("round 1: the slot URL first, then the path file (the foreign URL never)", run([json_slot], Lowest, [], []), Err(Ok([u("json", "2.1.0"), "/p/util/main.roc"]))),
		("round 2: only the path file is missing", run([json_slot], Lowest, [json21], []), Err(Ok(["/p/util/main.roc"]))),
		("round 3: the file names json 2.2.0, so json 2.1.0 is a conflict and the header of 2.2.0 is needed", run([json_slot], Lowest, [json21], [n_util]), Err(Ok([u("json", "2.2.0")]))),
		("round 4: done with json 2.2.0", run([json_slot], Lowest, [json21, json22], [n_util]), moved),
		("the order of the facts does not matter", run([json_slot], Lowest, [json22, json21], [n_util]), moved),
		("Highest: the same tuple, and no read of json 2.1.0", run([json_slot], Highest, [json22], [n_util]), moved),
		("a lower version in the file is a raise: no conflict, and its header is not needed", run([json_slot], Lowest, [json21], [n_low]), kept),
		("a path file under a path file, and a package of the file: both are needed, in the order of the edges", run([json_slot], Lowest, [json21], [n_nest]), Err(Ok(["/p/util/inner/main.roc", u("text", "1.0.0")]))),
		("the nested file names json 2.2.0: json 2.1.0 is a conflict", run([json_slot], Lowest, [json21, text10], [n_nest, n_inner]), Err(Ok([u("json", "2.2.0")]))),
		("a held json: no other tuple", run([held], Lowest, [json21], [n_util]), no_fit("json")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-AL9 R-C2 R-PH10 R-EC10 R-DT2 (slice 016: a problem of the closure rule inside the pick is a conflict of that tuple, the step tries the next tuple, and the failure (exit 10) is only for "nothing is free"): the app holds `mid` 1.0.0, which names
# `core 1.0.0` with the hash `otherhash`. The slot `web` has the releases 2.0.0 and 1.0.0 (the header value is 1.0.0). `web 2.0.0` names `core 1.0.0` with another hash (`corex1x0x0`). So with `Highest` the first tuple (web 2.0.0) has one
# release (one label) with 2 hashes: a content conflict of roc. The old step gave that tuple (it takes the first hash of a group) and the walk failed with exit 10. Now the step moves on to web 1.0.0. A held `web` 2.0.0 has no other tuple: no fit. The result does
# not depend on the order of the facts (R-DT2).
expect {
	other_hash = "https://github.com/acme/core/releases/download/1.0.0/otherhash.tar.zst"
	web_slot = slot("web", [], u("web", "1.0.0"), Bool.True, [cand(u("web", "2.0.0"), 30), cand(u("web", "1.0.0"), 30)])
	held = { ..web_slot, current: Ok(u("web", "2.0.0")), free: Bool.False }
	mid_f = fact(u("mid", "1.0.0"), [other_hash])
	web2 = fact(u("web", "2.0.0"), [u("core", "1.0.0")])
	web1 = fact(u("web", "1.0.0"), [])
	core_a = fact(u("core", "1.0.0"), [])
	core_o = fact(other_hash, [])
	facts = [mid_f, web2, web1, core_a, core_o]
	kept = Ok([("mid", "1.0.0", Keep, Err(None)), ("web", "1.0.0", Keep, Err(None))])
	rows = [
		("Highest: web 2.0.0 has a content conflict, so the next tuple is web 1.0.0", step([mid_slot, web_slot], facts, Highest), kept),
		("the order of the facts does not matter", step([mid_slot, web_slot], facts.rev(), Highest), kept),
		("Lowest: web 1.0.0 is the first tuple, and it has no conflict", step([mid_slot, web_slot], facts, Lowest), kept),
		("a held web 2.0.0: nothing is free, no tuple", step([mid_slot, held], facts, Highest), no_fit("mid, web")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
