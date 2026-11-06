import lib.IndexNotes
import lib.JsonDoc

IndexnotesTest :: [].{}

# Slice 210 (docs/slices/210-index-notes.md). Pure: the notes about the age of the registry index (Registry R-AP29, R-AP30). The expected text is the design text.
# The age format (`3d`, `5h`, `12m`) and the keys of the JSON note are proposals (R-OUT2, TW24). `now` is in seconds, `checked_at` in milliseconds (R-AP50).

now : U64
now = 1800000000

# `checked_at` of an item that was checked `ago` seconds before `now`, as the wire has it (milliseconds).
at = |ago| Ok((now - ago) * 1000)

stale_item = |name, ago| { name, checked_at: at(ago), stale: Bool.True }

fresh_item = |name, ago| { name, checked_at: at(ago), stale: Bool.False }

never_item = |name| { name, checked_at: Err(None), stale: Bool.True }

answer_of = |checked| { artifacts: [], releases: [], epochs: [], runs: [], nearest: [], hints: [], log_size: 40, unknown: [], checked, repos: [] }

# R-AP30 (proposal): the age. Whole days from 86400 s, else whole hours from 3600 s, else whole minutes. Each unit rounds down. Under one minute is `0m`.
expect {
	rows = [(0, "0m"), (59, "0m"), (60, "1m"), (720, "12m"), (3599, "59m"), (3600, "1h"), (18000, "5h"), (86399, "23h"), (86400, "1d"), (3 * 86400 + 5, "3d"), (400 * 86400, "400d")]
	wrong = rows.keep_if(|(s, want)| IndexNotes.age_text(s) != want).map(|(s, _)| s)
	dbg wrong
	wrong == []
}

# R-AP29, R-AP30: a stale item with a time. `index: <name> checked <age> ago`. `checked_at` is milliseconds: the 999 ms of the remainder do not change the age.
expect {
	d3 = IndexNotes.note({ now, item: stale_item("someone/roc-json", 3 * 86400 + 100) })
	h5 = IndexNotes.note({ now, item: stale_item("someone/roc-json", 5 * 3600) })
	m12 = IndexNotes.note({ now, item: stale_item("acme/roc-x", 12 * 60 + 1) })
	edge = IndexNotes.note({ now, item: { name: "acme/roc-x", checked_at: Ok((now - 3600) * 1000 - 999), stale: Bool.True } })
	dbg (d3, h5, m12, edge)
	d3 == Ok("index: someone/roc-json checked 3d ago") and h5 == Ok("index: someone/roc-json checked 5h ago") and m12 == Ok("index: acme/roc-x checked 12m ago") and edge == Ok("index: acme/roc-x checked 1h ago")
}

# R-AP29, R-AP30: `checked_at` null (not checked since the first ingest) with `stale` true gives the second text.
expect IndexNotes.note({ now, item: never_item("someone/roc-json") }) == Ok("index: someone/roc-json not checked since its first ingest")

# R-AP29, R-AP30: only `stale` decides. A fresh item gives no note, also an old time or a null time (the Worker computes `stale`: it knows the interval of each repository). A stale item with a recent time still gives a note (the age is 0m).
expect {
	fresh_old = IndexNotes.note({ now, item: fresh_item("a/b", 99 * 86400) })
	fresh_null = IndexNotes.note({ now, item: { name: "a/b", checked_at: Err(None), stale: Bool.False } })
	stale_recent = IndexNotes.note({ now, item: stale_item("a/b", 10) })
	dbg (fresh_old, fresh_null, stale_recent)
	fresh_old == Err(Fresh) and fresh_null == Err(Fresh) and stale_recent == Ok("index: a/b checked 0m ago")
}

# R-AP29: a time after `now` (a clock that runs behind the Worker) is age 0, not a wrap.
expect IndexNotes.note({ now, item: { name: "a/b", checked_at: Ok((now + 500) * 1000), stale: Bool.True } }) == Ok("index: a/b checked 0m ago")

# R-AP30: one note for each stale repository of the answer, in the order of the answer (R-AP64: by name). A fresh item gives none.
expect {
	answer = answer_of([stale_item("acme/roc-a", 2 * 86400), fresh_item("acme/roc-b", 60), never_item("acme/roc-c"), stale_item("zed/roc-d", 7200)])
	IndexNotes.notes({ now, answers: [answer] }) == ["index: acme/roc-a checked 2d ago", "index: acme/roc-c not checked since its first ingest", "index: zed/roc-d checked 2h ago"]
}

# R-AP30: an answer with no item, or no stale item, gives no note (a command with a `direct` index or a group on another host has no item, R-AP64).
expect {
	none = IndexNotes.notes({ now, answers: [answer_of([])] })
	all_fresh = IndexNotes.notes({ now, answers: [answer_of([fresh_item("a/b", 5), fresh_item("c/d", 9)])] })
	none == [] and all_fresh == []
}

# R-AP30 (proposal, R-OUT2): the `--json` note. `kind` `index-stale`, `name`, `checked_at` (the wire integer, milliseconds, or null) and `text`.
expect {
	timed = IndexNotes.json_note({ now, item: stale_item("someone/roc-json", 3 * 86400 + 100) }).map_ok(JsonDoc.render)
	never = IndexNotes.json_note({ now, item: never_item("someone/roc-json") }).map_ok(JsonDoc.render)
	fresh = IndexNotes.json_note({ now, item: fresh_item("someone/roc-json", 100) }).map_ok(JsonDoc.render)
	dbg (timed, never, fresh)
	timed == Ok("{\"kind\":\"index-stale\",\"name\":\"someone/roc-json\",\"checked_at\":1799740700000,\"text\":\"index: someone/roc-json checked 3d ago\"}")
		and never == Ok("{\"kind\":\"index-stale\",\"name\":\"someone/roc-json\",\"checked_at\":null,\"text\":\"index: someone/roc-json not checked since its first ingest\"}")
			and fresh == Err(Fresh)
}

# R-AP30: `json_notes` are the `json_note` of the same items, in the same order, so the text of each equals the line of `notes`.
expect {
	answer = answer_of([stale_item("acme/roc-a", 2 * 86400), fresh_item("acme/roc-b", 60), never_item("acme/roc-c")])
	docs = IndexNotes.json_notes({ now, answers: [answer] }).map(JsonDoc.render)
	want = ["acme/roc-a", "acme/roc-c"].map(|n| IndexNotes.json_note({ now, item: answer.checked.find_first(|c| c.name == n) ?? never_item(n) }).map_ok(JsonDoc.render) ?? "")
	dbg docs
	docs.len() == 2 and docs == want
}

# R-AP30, Design Q408: a held move has 2 answers. The same name stale in both: one note, with the older `checked_at`.
expect {
	first = answer_of([stale_item("acme/roc-a", 2 * 86400)])
	second = answer_of([stale_item("acme/roc-a", 5 * 86400)])
	IndexNotes.notes({ now, answers: [first, second] }) == ["index: acme/roc-a checked 5d ago"]
		and IndexNotes.notes({ now, answers: [second, first] }) == ["index: acme/roc-a checked 5d ago"]
}

# R-AP30, Design Q408: null is older than any time, in either answer order.
expect {
	first = answer_of([stale_item("acme/roc-a", 5 * 86400)])
	second = answer_of([never_item("acme/roc-a")])
	want = ["index: acme/roc-a not checked since its first ingest"]
	IndexNotes.notes({ now, answers: [first, second] }) == want and IndexNotes.notes({ now, answers: [second, first] }) == want
}

# R-AP30, Design Q408: a fresh item and a stale item of one name give the stale one (the fresh item gives no note).
expect {
	fresh = answer_of([fresh_item("acme/roc-a", 5 * 86400)])
	stale = answer_of([stale_item("acme/roc-a", 3 * 3600)])
	IndexNotes.notes({ now, answers: [fresh, stale] }) == ["index: acme/roc-a checked 3h ago"]
		and IndexNotes.notes({ now, answers: [stale, fresh] }) == ["index: acme/roc-a checked 3h ago"]
}

# R-AP30, Design Q408: the notes of 2 answers are sorted by name, not by answer. Each repository once.
expect {
	first = answer_of([stale_item("zed/roc-d", 7200), stale_item("acme/roc-c", 3600)])
	second = answer_of([stale_item("acme/roc-b", 120), stale_item("zed/roc-d", 3 * 3600)])
	IndexNotes.notes({ now, answers: [first, second] }) == ["index: acme/roc-b checked 2m ago", "index: acme/roc-c checked 1h ago", "index: zed/roc-d checked 3h ago"]
}

# R-AP30, Design Q407: `index_notes` is the member `data.index_notes`: the array of `json_notes`, or none (left out) with no note. Also with 2 answers (Q408), each repository once.
expect {
	a = answer_of([stale_item("acme/roc-a", 2 * 86400), fresh_item("acme/roc-b", 60)])
	b = answer_of([never_item("acme/roc-a")])
	member = IndexNotes.index_notes({ now, answers: [a, b] }).map_ok(JsonDoc.render)
	none = IndexNotes.index_notes({ now, answers: [answer_of([fresh_item("acme/roc-b", 60)]), answer_of([])] }).map_ok(JsonDoc.render)
	nothing = IndexNotes.index_notes({ now, answers: [] }).map_ok(JsonDoc.render)
	dbg (member, none, nothing)
	member == Ok("[{\"kind\":\"index-stale\",\"name\":\"acme/roc-a\",\"checked_at\":null,\"text\":\"index: acme/roc-a not checked since its first ingest\"}]") and none == Err(None) and nothing == Err(None)
}
