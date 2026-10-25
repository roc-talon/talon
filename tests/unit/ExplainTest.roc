import lib.Explain
import lib.JsonDoc

ExplainTest :: [].{}

# The expected value of each row is the text of the contract in the doc of `cli/lib/Explain.roc` (slice 036c, TW24 proposal), and the names that R-RP2 gives: `tln upgrade roc`, `tln roc use <id>`.
# The ids of the compilers are made up.

n1 = "nightly-2026-10-01-1111111"

n2 = "nightly-2026-10-02-2222222"

n3 = "nightly-2026-10-03-3333333"

n4 = "nightly-2026-10-04-4444444"

n5 = "nightly-2026-10-05-5555555"

cause = |label, alias, kind, modules, from, to, inferred| { label, alias, kind, modules, from, to, inferred }

json = |from, to| cause("acme/json 2.1.0", "json", Fail, [], from, to, [])

parser = |from, to| cause("acme/parser 1.2.0", "parser", Fail, [], from, to, [])

text = |causes, hint| Str.join_with(Explain.lines({ causes, hint }), "\n")

no_hint = Err(None)

fix = "  fix: tln roc use <id>\n       or tln upgrade roc"

# R-RP2 R-EP7 R-EP9 R-EP14 R-UM1 (slice 036c): the lines after the first line of the message. The fix block is always there (R-RP2 names `tln upgrade roc` and `tln roc use <id>`). The hint is the oldest nightly that works, when the command knows one.
# A cause line is for a fail that goes past the held compiler (`from` is not `to`) or that is inferred: a fail on the held compiler alone is in the first line already. A fault is an interval of one compiler, but the function does not know that: the words are the words of the kind.
# A module that the app uses and that fails gives an option `stop using <alias>.<Module>` (the second `fix:` of the example of Resolution 5), but `main.roc` and the platform (no alias) give none. No option is repeated.
expect {
	rows = [
		("no cause and no hint: the fix block only", text([], no_hint), fix),
		("a hint: option 1 names the nightly", text([], Ok(n1)), "  fix: tln roc use ${n1} (the oldest nightly that works)\n       or tln upgrade roc"),
		("a fail on the held compiler alone: no cause line", text([json(n3, n3)], no_hint), fix),
		("a fail interval: one cause line", text([json(n2, n5)], no_hint), "  acme/json 2.1.0 fails on ${n2} .. ${n5}\n${fix}"),
		("a hang that goes past the held compiler: the word of the kind", text([cause("acme/json 2.1.0", "json", Hang, [], n3, n4, [])], no_hint), "  acme/json 2.1.0 hangs on ${n3} .. ${n4}\n${fix}"),
		("a crash: the word of the kind", text([cause("acme/json 2.1.0", "json", Crash, [], n3, n4, [])], no_hint), "  acme/json 2.1.0 crashes on ${n3} .. ${n4}\n${fix}"),
		("an interval with inferred compilers: they are marked (R-EP9, R-EP14)", text([cause("acme/json 2.1.0", "json", Fail, [], n2, n4, [n3])], no_hint), "  acme/json 2.1.0 fails on ${n2} .. ${n4} (inferred on ${n3})\n${fix}"),
		("the inferred compilers in the order given, joined with a comma", text([cause("acme/json 2.1.0", "json", Fail, [], n1, n5, [n2, n4])], no_hint), "  acme/json 2.1.0 fails on ${n1} .. ${n5} (inferred on ${n2}, ${n4})\n${fix}"),
		("a fail on the held compiler alone that is inferred: the line is printed", text([cause("acme/json 2.1.0", "json", Fail, [], n3, n3, [n3])], no_hint), "  acme/json 2.1.0 fails on ${n3} (inferred on ${n3})\n${fix}"),
		("2 causes: the cause lines in the order given", text([json(n2, n4), parser(n3, n5)], no_hint), "  acme/json 2.1.0 fails on ${n2} .. ${n4}\n  acme/parser 1.2.0 fails on ${n3} .. ${n5}\n${fix}"),
		("the platform has its own label", text([cause("the platform acme/pf 0.1.0", "", Fail, [], n2, n4, [])], no_hint), "  the platform acme/pf 0.1.0 fails on ${n2} .. ${n4}\n${fix}"),
		("a failing module that the app uses: the option to stop using it", text([cause("acme/json 2.1.0", "json", Fail, ["Yaml.roc"], n3, n3, [])], no_hint), "${fix}\n       or stop using json.Yaml"),
		("main.roc is no option, the other module is", text([cause("acme/json 2.1.0", "json", Fail, ["main.roc", "Yaml.roc"], n3, n3, [])], no_hint), "${fix}\n       or stop using json.Yaml"),
		("only main.roc: no option", text([cause("acme/json 2.1.0", "json", Fail, ["main.roc"], n3, n3, [])], no_hint), fix),
		("the platform has no alias: no option for its module", text([cause("the platform acme/pf 0.1.0", "", Fail, ["Host.roc"], n3, n3, [])], no_hint), fix),
		("2 modules and 2 causes: the options in the order of the causes and of their modules", text([cause("acme/json 2.1.0", "json", Fail, ["Wire.roc", "Yaml.roc"], n3, n3, []), cause("acme/parser 1.2.0", "parser", Fail, ["Yaml.roc"], n3, n3, [])], no_hint), "${fix}\n       or stop using json.Wire\n       or stop using json.Yaml\n       or stop using parser.Yaml"),
		("the same alias and module twice: one option", text([cause("acme/json 2.1.0", "json", Fail, ["Yaml.roc", "Yaml.roc"], n3, n3, []), cause("acme/json 2.1.0", "json", Fail, ["Yaml.roc"], n3, n3, [])], no_hint), "${fix}\n       or stop using json.Yaml"),
		("a hint, an interval and a module: the order of the lines", text([cause("acme/json 2.1.0", "json", Fail, ["Yaml.roc"], n2, n4, [])], Ok(n1)), "  acme/json 2.1.0 fails on ${n2} .. ${n4}\n  fix: tln roc use ${n1} (the oldest nightly that works)\n       or tln upgrade roc\n       or stop using json.Yaml"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-J5 R-OUT2 R-EP9 R-EP14 (slice 036c, TW24): `error.details` of the failure: `{"compiler", "causes": [{"release", "kind", "modules", "from", "to", "inferred"}], "hint"}`, the keys in this order. Each cause is in it, also a cause that `lines` leaves out (a fail on the held compiler alone). The hint is the id or `null`.
expect {
	render = |causes, hint| JsonDoc.render(Explain.details({ held: n3, causes, hint }))
	rows = [
		("no cause, no hint", render([], no_hint), "{\"compiler\":\"${n3}\",\"causes\":[],\"hint\":null}"),
		("a cause with a module, an interval, inferred compilers, and a hint", render([cause("acme/json 2.1.0", "json", Fail, ["Yaml.roc"], n2, n4, [n3])], Ok(n1)), "{\"compiler\":\"${n3}\",\"causes\":[{\"release\":\"acme/json 2.1.0\",\"kind\":\"fail\",\"modules\":[\"Yaml.roc\"],\"from\":\"${n2}\",\"to\":\"${n4}\",\"inferred\":[\"${n3}\"]}],\"hint\":\"${n1}\"}"),
		("a fail on the held compiler alone is a cause too, and the words of the kinds", render([json(n3, n3), cause("the platform acme/pf 0.1.0", "", Hang, [], n3, n3, []), cause("acme/parser 1.2.0", "parser", Crash, [], n3, n3, [])], no_hint), "{\"compiler\":\"${n3}\",\"causes\":[{\"release\":\"acme/json 2.1.0\",\"kind\":\"fail\",\"modules\":[],\"from\":\"${n3}\",\"to\":\"${n3}\",\"inferred\":[]},{\"release\":\"the platform acme/pf 0.1.0\",\"kind\":\"hang\",\"modules\":[],\"from\":\"${n3}\",\"to\":\"${n3}\",\"inferred\":[]},{\"release\":\"acme/parser 1.2.0\",\"kind\":\"crash\",\"modules\":[],\"from\":\"${n3}\",\"to\":\"${n3}\",\"inferred\":[]}],\"hint\":null}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
