import JsonDoc

## The words that explain a failure of the oracle loop (slice 036c, R-RP2, R-EP9, R-EP14, 035 Q1, R-J5; TESTING.md 2.2 part A). Pure. `Oracle.step_probed` gives the first line of the message (the text of `Units.judge`, R-PH13),
## and this module gives the lines that follow it, and the `details` of the failure for `--json`. The texts are a proposal (TW24), except the names that R-RP2 gives: `tln upgrade roc`, `tln roc use <id>`.
##
## A cause is a release that the proof of the failure blames: a unit fail, a hang or a crash on the held compiler H. `label` is `<name> <version>` or `the platform <name> <version>` (the text of the first line). `alias` is the alias of its slot in the header
## (`json`), and `""` for the platform. `modules` are the failing modules that the app uses (the `modules` of the cause of the solver, `Yaml.roc`). `from` and `to` are the first and the last compiler of the fail interval of D (R-EP7: they are H alone for a fault).
## `inferred` are the compilers of that interval whose fail is inferred (R-EP9: always empty with `Allowed`).
##
## `lines` (each line has no line end):
##
## | Part | Lines | Rule |
## | --- | --- | --- |
## | Cause line | For each cause, in the order given, when `from` is not `to` or `inferred` is not empty (a fail on H alone is in the first line already): `  <label> <word> on <from> .. <to>`, or `  <label> <word> on <from>` when `from` is `to`. `<word>` is `fails`, `hangs` or `crashes`. With `inferred`: ` (inferred on <id>, <id>)` at the end, the ids in the order given | R-EP7, R-EP9, R-EP14 |
## | Fix block | Always (R-RP2). The first line is `  fix: <option>`, each other option is a line `       or <option>` (7 spaces: it lines up with the first option, as the example of Resolution 5) | R-RP2, 035 Q1 |
## | Option 1 | `tln roc use <n> (the oldest nightly that works)` when `hint` is `Ok(n)`, else `tln roc use <id>` (the text of R-RP2) | R-RP2 |
## | Option 2 | `tln upgrade roc` | R-RP2 |
## | Option 2 left out | When `failed` is `UpgradeRoc` (`failed_command` of the request: `tln upgrade roc`), option 2 is not a line of the fix block (R-AL12: that command just failed). Slice 065. The options are data (a list) before they are rendered, so the filter works on the option, not on the text. The other options keep their order, and option 1 is the `fix:` line. With `Other`, option 2 is there | R-AL12, R-SP8 |
## | Options 3 | For each cause in the order given, for each of its modules in its order, but not `main.roc`: `stop using <alias>.<Module>` (`<Module>` is the module without `.roc`). A cause with an empty alias gives none. No repeat (the first stays). Here the app can avoid the fail (R-UM1), as the second `fix:` of the example of Resolution 5 | R-UM1, Resolution 5 |
##
## `details` is the `error.details` of the failure (R-J5, R-OUT2: a proposal): `{"compiler": <held>, "causes": [{"release": <label>, "kind": "fail" or "hang" or "crash", "modules": [<module>, ...], "from": <id>, "to": <id>, "inferred": [<id>, ...]}], "hint": <id> or null}`, the keys in this order, one object for each cause (also those that `lines` leaves out).
Explain :: [].{

	## A release that the proof blames (the table above).
	Cause : { label : Str, alias : Str, kind : [Fail, Hang, Crash], modules : List(Str), from : Str, to : Str, inferred : List(Str) }

	## The lines that follow the first line of the message (the table above).
	## Slice 065: `failed` is the failed command (`failed_command`). The caller is `OracleCause.failure`, with `compat.failed`.
	lines : { causes : List(Explain.Cause), hint : Try(Str, [None]), failed : [UpgradeRoc, Other] } -> List(Str)
	lines = |x| x.causes.keep_if(|c| c.from != c.to or !c.inferred.is_empty()).map(cause_line).concat(fix_lines(x.hint, x.causes, x.failed))

	## Slice 065 (R-AL12, R-SP8): the command that failed. `UpgradeRoc` for `tln upgrade roc` (`command` is `Upgrade` and `names` is `["roc"]`), `Other` for each other command, also `tln upgrade` and `tln upgrade roc <name>` (manager answer Q1 of `docs/slices/065-fix-line.md`). Flags do not matter (they are not in the input).
	failed_command : { command : [Install, Update, Upgrade], names : List(Str) } -> [UpgradeRoc, Other]
	failed_command = |x| match x.command {
		Upgrade => if x.names == ["roc"] UpgradeRoc else Other
		Install => Other
		Update => Other
	}

	## The `error.details` of the failure (the table above). `held` is the id of H.
	details : { held : Str, causes : List(Explain.Cause), hint : Try(Str, [None]) } -> JsonDoc
	details = |x| JsonDoc.Obj([
		("compiler", JsonDoc.Text(x.held)),
		("causes", JsonDoc.Arr(x.causes.map(cause_doc))),
		(
			"hint",
			match x.hint {
				Ok(id) => JsonDoc.Text(id)
				Err(None) => JsonDoc.Null
			},
		),
	])
}

word : Explain.Cause -> Str
word = |c| match c.kind {
	Fail => "fails"
	Hang => "hangs"
	Crash => "crashes"
}

# R-EP7, R-EP9: the interval, and the compilers whose fail is inferred.
cause_line : Explain.Cause -> Str
cause_line = |c| {
	span = if c.from == c.to c.from else "${c.from} .. ${c.to}"
	mark = if c.inferred.is_empty() "" else " (inferred on ${Str.join_with(c.inferred, ", ")})"
	"  ${c.label} ${word(c)} on ${span}${mark}"
}

# R-RP2: the first option is the nightly that works, else a placeholder. Then the upgrade, then the modules that the app can stop using (R-UM1).
# R-AL12, R-SP8: the upgrade is not an option when `tln upgrade roc` is the command that failed (slice 065).
fix_lines : Try(Str, [None]), List(Explain.Cause), [UpgradeRoc, Other] -> List(Str)
fix_lines = |hint, causes, failed| {
	first = match hint {
		Ok(id) => "tln roc use ${id} (the oldest nightly that works)"
		Err(None) => "tln roc use <id>"
	}
	upgrade = match failed {
		UpgradeRoc => []
		Other => ["or tln upgrade roc"]
	}
	options = ["fix: ${first}"].concat(upgrade).concat(stops(causes).map(|s| "or ${s}"))
	options.map_with_index(|text, i| if i == 0 "  ${text}" else "       ${text}")
}

stops : List(Explain.Cause) -> List(Str)
stops = |causes| causes
	.join_map(|c| if c.alias == "" [] else c.modules.keep_if(|m| m != "main.roc").map(|m| "stop using ${c.alias}.${m.drop_suffix(".roc")}"))
	.fold([], |found, s| if found.contains(s) found else found.append(s))

kind_name : Explain.Cause -> Str
kind_name = |c| match c.kind {
	Fail => "fail"
	Hang => "hang"
	Crash => "crash"
}

cause_doc : Explain.Cause -> JsonDoc
cause_doc = |c| JsonDoc.Obj([
	("release", JsonDoc.Text(c.label)),
	("kind", JsonDoc.Text(kind_name(c))),
	("modules", JsonDoc.Arr(c.modules.map(|m| JsonDoc.Text(m)))),
	("from", JsonDoc.Text(c.from)),
	("to", JsonDoc.Text(c.to)),
	("inferred", JsonDoc.Arr(c.inferred.map(|m| JsonDoc.Text(m)))),
])
