import Fail

## The text of `main.roc` for `tln init --platform <name>` (slice 055, R-IN8, Resolution 4 R-SM2, answer OP8). Part A (pure). The app is the smoke app of R-SM2 for the platform header, with one change: each stub body is `crash "write the app"`.
## The texts (the layout of the app, the failure messages) are a proposal (TW24).
InitStub :: [].{

	## The tested reading of the `requires` clause of the platform header `text` (the text of the `main.roc` of the release):
	##
	## | Item | Reading |
	## | --- | --- |
	## | The clause | The group after the word `requires` at depth 0. The old form `requires {} { ... }` has two groups: the values are in the second. Comments (`#`, `##`) and strings are no tokens. |
	## | An entry | `name : <type>` or `[Alias : var, ...] for name : <type>`. R-SM2 gives the stub of one value. A clause with 2 or more entries (a comma at depth 0 that is followed by `name :` or by `[`) is a form that R-SM2 does not give: exit 2, like a type with no stub (answer Q6). A last comma is allowed. |
	## | A function type (a `=>` or `->` at depth 0 of the type) | A lambda: `\|_, _\| crash "write the app"`, one `_` for each argument (the commas of the part before the arrow at depth 0, plus one). The argument part `()` has no argument: `\|\| crash "write the app"`. |
	## | A record type `{ f : T, ... }` | A record with one field for each `f`, with the stub of `T`: one field and one tab more for each level. `{}` is `{}`. |
	## | Any other type (`Str`, `U16`, `List(Str)`, a tag union, ...) | No stub (R-SM2 "any other type"). The first one, in source order, also in a record field: the text of the type. |
	##
	## The app:
	##
	## ```text
	## app [<each alias of each entry, then each name>] {
	## <tab>pf: platform "<url>",
	## }
	##
	## <Alias> : {}                (one block for each alias)
	##
	## <name> = <stub>             (one block for each entry)
	## ```
	##
	## Blocks are separated by one empty line. The `roc:` pin is added by the resolve (R-IN4). The failures have kind `Usage` (exit 2, R-EC2):
	##
	## | Case | Message |
	## | --- | --- |
	## | A clause with 2 or more entries | `cannot make the stub app for <name>: its requires clause has <n> values (<text>), and R-SM2 gives a stub for one value only (R-IN8). Nothing was written.` `<text>` is the clause as in `<type>` below, without a last comma |
	## | A type that has no stub | `cannot make the stub app for <name>: the value <value> of its requires clause has the type <type>, and R-SM2 has no stub for that type (R-IN8). Nothing was written.` |
	## | The header is no platform, or has no `requires` clause (question Q2, not tested) | `<name> has no requires clause: it is not a platform (R-IN8)` |
	app_text : { name : Str, url : Str, text : Str } -> Try(Str, Fail)
	app_text = |_x| crash "todo: slice 055"
}
