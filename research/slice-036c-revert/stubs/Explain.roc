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
## | Options 3 | For each cause in the order given, for each of its modules in its order, but not `main.roc`: `stop using <alias>.<Module>` (`<Module>` is the module without `.roc`). A cause with an empty alias gives none. No repeat (the first stays). Here the app can avoid the fail (R-UM1), as the second `fix:` of the example of Resolution 5 | R-UM1, Resolution 5 |
##
## `details` is the `error.details` of the failure (R-J5, R-OUT2: a proposal): `{"compiler": <held>, "causes": [{"release": <label>, "kind": "fail" or "hang" or "crash", "modules": [<module>, ...], "from": <id>, "to": <id>, "inferred": [<id>, ...]}], "hint": <id> or null}`, the keys in this order, one object for each cause (also those that `lines` leaves out).
Explain :: [].{

	## A release that the proof blames (the table above).
	Cause : { label : Str, alias : Str, kind : [Fail, Hang, Crash], modules : List(Str), from : Str, to : Str, inferred : List(Str) }

	## The lines that follow the first line of the message (the table above).
	lines : { causes : List(Explain.Cause), hint : Try(Str, [None]) } -> List(Str)
	lines = |_x| crash "todo"

	## The `error.details` of the failure (the table above). `held` is the id of H.
	details : { held : Str, causes : List(Explain.Cause), hint : Try(Str, [None]) } -> JsonDoc
	details = |_x| crash "todo"
}
