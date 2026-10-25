import lib.Closure
import lib.Db
import lib.Evidence
import lib.JsonDoc
import lib.Why

EvidenceTest :: [].{}

nt = "nightly-2026-10-14-38a3029"

other = "nightly-2026-10-09-258ab27"

# The other tag form of `nt` (R-CV1: the same date and the same sha).
nt_long = "nightly-2026-October-14-38a3029"

# A row of `facts`: the target `any` is a check, a host target is a build.
fact = |hash, nightly, target, outcome, modules| { hash, nightly, target, outcome, modules, closure: if target == "any" "" else "d1" }

no_pin = Err(NoPin)

no_hint = Err(None)

pair = |facts, pin, hint| Evidence.of_pair({ hash: "H1", compiler: nt, facts, pin, hint })

line = |rank, source, result, modules| { rank, source, result, modules }

unit_err = |hash, path| { file: Package({ hash, path }), title: "REDUNDANT EXPOSE", message: "x" }

# R-EF1 R-EF3 R-PH12 (slice 032b): the lines of one pair (hash, compiler). Rank 1 is the row of `compat.db` for (hash, compiler, `any`) with its outcome and modules. Rank 3 is the `roc:` pin of the release header, rank 4 is the cached
# `.roc-version`: each only when it is the compiler (`Pin.same_id`, R-CV1), and each is a `pass` hint. The lines are in rank order, so the first line is the fact that wins (R-EF3). A source with no value has no line. A build row is no evidence of a check.
expect {
	local = |outcome, modules| fact("H1", nt, "any", outcome, modules)
	rows = [
		("no source", pair([], no_pin, no_hint), []),
		("rank 1 pass", pair([local(Pass, [])], no_pin, no_hint), [line(1, Local, Pass, [])]),
		("rank 1 fail has its modules", pair([local(Fail, ["A.roc", "Yaml.roc"])], no_pin, no_hint), [line(1, Local, Fail, ["A.roc", "Yaml.roc"])]),
		("rank 1 hang", pair([local(Hang, [])], no_pin, no_hint), [line(1, Local, Hang, [])]),
		("rank 1 crash", pair([local(Crash, [])], no_pin, no_hint), [line(1, Local, Crash, [])]),
		("a row of another compiler is no value", pair([fact("H1", other, "any", Pass, [])], no_pin, no_hint), []),
		("a row of another hash is no value", pair([fact("H2", nt, "any", Pass, [])], no_pin, no_hint), []),
		("a row of the other tag form is no value (the key is the text of the id)", pair([fact("H1", nt_long, "any", Pass, [])], no_pin, no_hint), []),
		("a build row is no evidence of a check", pair([fact("H1", nt, "x64musl", Fail, [])], no_pin, no_hint), []),
		("a build row and a check row: the check row", pair([fact("H1", nt, "x64musl", Fail, []), local(Pass, [])], no_pin, no_hint), [line(1, Local, Pass, [])]),
		("rank 3: the pin is the compiler", pair([], Ok(nt), no_hint), [line(3, Pin, Pass, [])]),
		("rank 3: a pin for another compiler is no value", pair([], Ok(other), no_hint), []),
		("rank 3: the other tag form of the compiler is the compiler", pair([], Ok(nt_long), no_hint), [line(3, Pin, Pass, [])]),
		("rank 4: the hint is the compiler", pair([], no_pin, Ok(nt)), [line(4, Hint, Pass, [])]),
		("rank 4: the other tag form of the compiler is the compiler", pair([], no_pin, Ok(nt_long)), [line(4, Hint, Pass, [])]),
		("rank 4: a hint for another compiler is no value", pair([], no_pin, Ok(other)), []),
		("all 3 sources: rank order, the fact wins over the hints", pair([local(Fail, ["Yaml.roc"])], Ok(nt), Ok(nt)), [line(1, Local, Fail, ["Yaml.roc"]), line(3, Pin, Pass, []), line(4, Hint, Pass, [])]),
		("rank 1 and rank 4", pair([local(Pass, [])], no_pin, Ok(nt)), [line(1, Local, Pass, []), line(4, Hint, Pass, [])]),
		("rank 3 and rank 4: the pin first", pair([], Ok(nt), Ok(nt)), [line(3, Pin, Pass, []), line(4, Hint, Pass, [])]),
		("the pin is for another compiler, the hint is not", pair([], Ok(other), Ok(nt)), [line(4, Hint, Pass, [])]),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

pkg_header = |pin| "package [Lib] {\n\tcore: \"https://github.com/acme/core/releases/download/1.0.0/8bp2yxDtY2ayou722hzyv51Ts1yBaFshmVGtLXpkDy8r.tar.zst\",\n${pin}}\n\nmain = 1\n"

# R-EF1 (rank 3) R-SC12: the pin of the header text of a release. A package header is read as an app header is (R-H8). No pin, no header, and a pin that is not a full compiler id are no pin (no failure: `why` shows evidence, it does not refuse a header).
expect {
	pin = |text| Evidence.pin_of({ path: "/c/packages/H1/main.roc", text })
	app_text = "app [main!] {\n\tpf: platform \"https://github.com/acme/pfx/releases/download/0.1.0/6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL.tar.zst\",\n\troc: \"${nt}\",\n}\n\nmain! = |_args| Ok({})\n"
	rows = [
		("a package header with a pin", pin(pkg_header("\troc: \"${nt}\",\n")), Ok(nt)),
		("a package header with no pin", pin(pkg_header("")), Err(NoPin)),
		("an app header with a pin", pin(app_text), Ok(nt)),
		("a pin in the other tag form is returned as written", pin(pkg_header("\troc: \"${nt_long}\",\n")), Ok(nt_long)),
		("a pin that is a prefix is no pin (R-SC12)", pin(pkg_header("\troc: \"nightly-2026-10\",\n")), Err(NoPin)),
		("a text with no header", pin("main = 1\n"), Err(NoPin)),
		("an empty text", pin(""), Err(NoPin)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CM7 R-PH12 R-EF3 R-OUT2 (proposal, TW24): the text of the block of one package. Empty with no compiler and with no line. Else a header line (4 spaces), one line for each source (6 spaces, `*` for the winner, the rank, the source word,
# the result: `fail (<modules>)` for a fail with modules), and one `note:` line (4 spaces) for each note.
expect {
	block = |compiler, lines, notes| Evidence.text({ compiler, lines, notes })
	head = "    evidence on ${nt}:\n"
	rows = [
		("no compiler", block(Err(None), [line(1, Local, Pass, [])], []), ""),
		("a compiler and no line", block(Ok(nt), [], []), ""),
		("one line: the winner", block(Ok(nt), [line(1, Local, Pass, [])], []), "${head}      * 1 local: pass\n"),
		("a hint only: the winner is the pin", block(Ok(nt), [line(3, Pin, Pass, [])], []), "${head}      * 3 pin: pass\n"),
		("3 lines: only the first has the mark", block(Ok(nt), [line(1, Local, Hang, []), line(3, Pin, Pass, []), line(4, Hint, Pass, [])], []), "${head}      * 1 local: hang\n        3 pin: pass\n        4 roc-version: pass\n"),
		("a fail with no module", block(Ok(nt), [line(1, Local, Fail, [])], []), "${head}      * 1 local: fail\n"),
		("a fail with 2 modules", block(Ok(nt), [line(1, Local, Fail, ["A.roc", "Yaml.roc"])], []), "${head}      * 1 local: fail (A.roc, Yaml.roc)\n"),
		("a crash", block(Ok(nt), [line(1, Local, Crash, [])], []), "${head}      * 1 local: crash\n"),
		("2 notes after the lines", block(Ok(nt), [line(1, Local, Fail, ["A.roc", "B.roc"]), line(3, Pin, Pass, [])], ["module A fails on ${nt}. Your app does not import it.", "module B fails on ${nt}. Your app does not import it."]), "${head}      * 1 local: fail (A.roc, B.roc)\n        3 pin: pass\n    note: module A fails on ${nt}. Your app does not import it.\n    note: module B fails on ${nt}. Your app does not import it.\n"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-OUT4 R-OUT5 R-J3 R-J4 (proposal, TW24): the 3 keys that the evidence adds to a member of `why --json`, in this order: `compiler` (null or the id), `evidence` (a list in rank order, `winner` true for the first only), `notes`.
expect {
	json = |block| JsonDoc.Obj(Evidence.fields(block)).render()
	rows = [
		("no compiler", json({ compiler: Err(None), lines: [], notes: [] }), "{\"compiler\":null,\"evidence\":[],\"notes\":[]}"),
		("a compiler and no line", json({ compiler: Ok(nt), lines: [], notes: [] }), "{\"compiler\":\"${nt}\",\"evidence\":[],\"notes\":[]}"),
		(
			"3 lines and a note",
			json({ compiler: Ok(nt), lines: [line(1, Local, Fail, ["Yaml.roc"]), line(3, Pin, Pass, []), line(4, Hint, Pass, [])], notes: ["n1"] }),
			"{\"compiler\":\"${nt}\",\"evidence\":[{\"rank\":1,\"source\":\"local\",\"result\":\"fail\",\"modules\":[\"Yaml.roc\"],\"winner\":true},{\"rank\":3,\"source\":\"pin\",\"result\":\"pass\",\"modules\":[],\"winner\":false},{\"rank\":4,\"source\":\"roc-version\",\"result\":\"pass\",\"modules\":[],\"winner\":false}],\"notes\":[\"n1\"]}",
		),
		("hang and crash words", json({ compiler: Ok(nt), lines: [line(1, Local, Hang, []), line(1, Local, Crash, [])], notes: [] }).drop_prefix("{\"compiler\":\"${nt}\",\"evidence\":[{\"rank\":1,\"source\":\"local\",\"result\":\"hang\""), ",\"modules\":[],\"winner\":true},{\"rank\":1,\"source\":\"local\",\"result\":\"crash\",\"modules\":[],\"winner\":false}],\"notes\":[]}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-UM1 R-P6 R-EF1 (slice 032b, E5): the unit fails that the scan ignored. A node with a `Fail` row for the compiler and the target `any` gives one entry for each module that the baseline does not explain, that is not `main.roc` and
# that the app does not use. A module that is used, a module of the baseline, and a row of another outcome, compiler or target give none.
expect {
	local = |hash, outcome, modules| fact(hash, nt, "any", outcome, modules)
	ign = |hashes, facts, baseline, used| Evidence.ignored({ hashes, facts, nightly: nt, baseline, used })
	used = |hash, path| { hash, path }
	entry = |hash, path| { hash, path }
	rows = [
		("a fail of a module that the app does not use", ign(["H1"], [local("H1", Fail, ["Yaml.roc"])], [], []), [entry("H1", "Yaml.roc")]),
		("a used module is no note (it is a blame)", ign(["H1"], [local("H1", Fail, ["Yaml.roc"])], [], [used("H1", "Yaml.roc")]), []),
		("2 modules, one is used", ign(["H1"], [local("H1", Fail, ["Wire.roc", "Yaml.roc"])], [], [used("H1", "Wire.roc")]), [entry("H1", "Yaml.roc")]),
		("2 modules, none is used: the order of the row", ign(["H1"], [local("H1", Fail, ["Wire.roc", "Yaml.roc"])], [], []), [entry("H1", "Wire.roc"), entry("H1", "Yaml.roc")]),
		("a used module of another package does not count", ign(["H1"], [local("H1", Fail, ["Yaml.roc"])], [], [used("H2", "Yaml.roc")]), [entry("H1", "Yaml.roc")]),
		("main.roc is used by every package", ign(["H1"], [local("H1", Fail, ["main.roc"])], [], []), []),
		("a module of the baseline is no note (R-P6)", ign(["H1"], [local("H1", Fail, ["Yaml.roc"])], [unit_err("H1", "Yaml.roc")], []), []),
		("an error of the baseline in another package does not explain it", ign(["H1"], [local("H1", Fail, ["Yaml.roc"])], [unit_err("H2", "Yaml.roc")], []), [entry("H1", "Yaml.roc")]),
		("an error of the baseline in another module does not explain it", ign(["H1"], [local("H1", Fail, ["Yaml.roc"])], [unit_err("H1", "Wire.roc")], []), [entry("H1", "Yaml.roc")]),
		("a fail with no module", ign(["H1"], [local("H1", Fail, [])], [], []), []),
		("a pass", ign(["H1"], [local("H1", Pass, [])], [], []), []),
		("a hang is no note, whatever the modules of the row", ign(["H1"], [local("H1", Hang, ["Yaml.roc"])], [], []), []),
		("a crash is no note, whatever the modules of the row", ign(["H1"], [local("H1", Crash, ["Yaml.roc"])], [], []), []),
		("no row", ign(["H1"], [], [], []), []),
		("a row of another compiler", ign(["H1"], [fact("H1", other, "any", Fail, ["Yaml.roc"])], [], []), []),
		("a build row", ign(["H1"], [fact("H1", nt, "x64musl", Fail, ["Yaml.roc"])], [], []), []),
		("2 hashes: the order of the hashes", ign(["H2", "H1"], [local("H1", Fail, ["A.roc"]), local("H2", Fail, ["B.roc"])], [], []), [entry("H2", "B.roc"), entry("H1", "A.roc")]),
		("a row of a hash that is not in the list", ign(["H1"], [local("H2", Fail, ["B.roc"])], [], []), []),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-UM1 R-OUT2 (proposal, TW24, E4): the note has no error title and no package. The module is the path without `.roc`. The caller adds `note: `.
expect {
	text = |path| Evidence.note({ path, compiler: nt })
	rows = [
		("a top module", text("Yaml.roc"), "module Yaml fails on ${nt}. Your app does not import it."),
		("a module in a directory", text("sub/Yaml.roc"), "module sub/Yaml fails on ${nt}. Your app does not import it."),
		("the name of a module", Evidence.module_name("Yaml.roc"), "Yaml"),
		("a path with no suffix", Evidence.module_name("Yaml"), "Yaml"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

json_url = "https://github.com/acme/json/releases/download/2.1.0/jsonhash.tar.zst"

walked : Closure.Walked
walked = {
	rows: [target],
	links: [{ from: Err(Header), alias: "json", to: json_url }],
}

target = { id: json_url, kind: Release, alias: "json", name: "acme/json", form: "form", version: "2.1.0", series: "2", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False }

found = { file: "/p/main.roc", walked, target }

# R-CM7 R-PH12 R-EF3 (slice 032b): `Why.show` is the text of `Why.text` and then the text of the block. With no compiler and with no line it is `Why.text` as it is (so a `why` with no evidence prints what it printed before).
# `Why.shown_data` is `Why.data` of the same members with the 3 keys of `Evidence.fields` added at the end of each member.
expect {
	block = { compiler: Ok(nt), lines: [line(1, Local, Pass, []), line(3, Pin, Pass, [])], notes: [] }
	none = { compiler: Err(None), lines: [], notes: [] }
	plain = Why.text(found)
	first_old = Why.data([found]).render()
	first_new = Why.shown_data([{ found, evidence: block }]).render()
	bare_new = Why.shown_data([{ found, evidence: none }]).render()
	head = first_old.drop_suffix("}]}")
	tail = ",\"compiler\":\"${nt}\",\"evidence\":[{\"rank\":1,\"source\":\"local\",\"result\":\"pass\",\"modules\":[],\"winner\":true},{\"rank\":3,\"source\":\"pin\",\"result\":\"pass\",\"modules\":[],\"winner\":false}],\"notes\":[]}]}"
	rows = [
		("no compiler: the text of Why.text", Why.show({ found, evidence: none }), plain),
		("a compiler and no line: the text of Why.text", Why.show({ found, evidence: { compiler: Ok(nt), lines: [], notes: [] } }), plain),
		("lines after the paths", Why.show({ found, evidence: block }), "${plain}    evidence on ${nt}:\n      * 1 local: pass\n        3 pin: pass\n"),
		("data: the keys are added to one member", first_new, "${head}${tail}"),
		("data: no compiler is null, the lists are empty", bare_new, "${head},\"compiler\":null,\"evidence\":[],\"notes\":[]}]}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
