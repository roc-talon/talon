import Fail
import TomlKeys
import toml.Toml
import toml.Value

## The `[scripts]` table of `talon.toml` and the words of a step (slice 057, CLI 1 `tln run`: R-RUN1, R-RUN2, R-RUN14). Part A (pure, TESTING.md 2.2). `tln run` is the only reader of `[scripts]` (R-RUN15, R-HK1):
## `Intent.read` only knows the table name, so `install` and the other commands print no warning for it and never look at it.
##
## ```toml
## [scripts]
## build = ["roc build --target=wasm32 --no-cache --output=app.wasm main.roc", "roc-cfw sync"]
## check = ["@build-wasm", "roc-cfw sync --check"]
## all = [{ in = "workers/ledger", run = "@build" }, { in = "workers/web", run = "@build" }]
## ```
ScriptsToml :: [].{

	## One step. `Line(text)` is a command line or `@<name>` (R-RUN4), as written. `In({ dir, run })` is the table `{ in = "<dir>", run = "<step string>" }` (R-RUN8), as written.
	Step : [Line(Str), In({ dir : Str, run : Str })]

	## One script: the name, its steps in order (a string is one step), and the 1-based line of its key.
	Script : { name : Str, steps : List(ScriptsToml.Step), line : U64 }

	## R-RUN1: is the text a script name? `[a-z0-9][a-z0-9:_-]*`, at most 64 characters (bytes).
	is_name : Str -> Bool
	is_name = |_text| crash "todo: slice 057"

	## R-RUN1, R-RUN14: the scripts of a parsed document, in the order of their lines. No `[scripts]` table gives no script. `issues` are failures of kind `Input` (exit 19): a reader takes the first one by line and prints
	## `<path>:<line>: <message>`. The message texts are proposals (TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | `scripts` is not a table | `scripts: must be a table` |
	## | The key is not `is_name` | `scripts.<key>: the key is not a script name (lower case letters, digits, ':', '_' and '-', the first one a letter or a digit, at most 64 characters)` |
	## | The value is not a string, a table or an array | `scripts.<key>: must be a step (a string, or a table with in and run) or an array of steps` |
	## | An item of the array is not a string or a table | `scripts.<key>[<n>]: must be a string or a table with in and run` (`<n>` is 1-based) |
	## | A table has no string `in`, no string `run`, or another key (a table that is the whole value too, `<key>` with no `[<n>]`) | `scripts.<key>[<n>]: a table step needs the strings in and run, and no other key` |
	##
	## `in` is a reserved word of Roc: the key is read as the string `"in"` (a Dict key), not as a field.
	read_table : Toml -> { value : List(ScriptsToml.Script), issues : List(TomlKeys.Note), warnings : List(TomlKeys.Note) }
	read_table = |_doc| crash "todo: slice 057"

	## R-RUN1: `read_table` of a text, as `tln run` uses it. The first issue by line is a failure of kind `Input` (exit 19): `<path>:<line>: <message>` (the messages of `read_table`). Text that is not TOML: `<path>:<line>: not valid TOML`. A text with no `[scripts]` table gives no script.
	read : { path : Str, text : Str } -> Try(List(ScriptsToml.Script), Fail)
	read = |_facts| crash "todo: slice 057"

	## R-RUN2: the words of a command line. A space or a tab separates two words. `"..."` and `'...'` quote (the quotes are not in the word). In `"..."` the escapes are `\"` and `\\`; any other backslash stays. In `'...'` and outside quotes a backslash stays.
	## There is no expansion: `$HOME`, `~` and `*.txt` are words as they are. An unquoted word `|`, `&&`, `||`, `;`, `>`, `>>`, `<` or `&`, and an unquoted word that starts with `$(` or a backquote, is `Err(Shell(<the word>))`. A quoted word is never refused.
	## `Err(Unclosed)`: a quote that is not closed (`RunPlan.plan` makes it exit 19 with the script named, before the first step, Q3 of the review). A quote inside a word joins: `a"b c"d` is the one word `ab cd`. The empty text has no word.
	words : Str -> Try(List(Str), [Shell(Str), Unclosed])
	words = |_text| crash "todo: slice 057"

	## The step as it is shown (the list of `tln run`, the messages): a `Line` is its text, an `In` is `in <dir>: <run>`.
	step_text : ScriptsToml.Step -> Str
	step_text = |_step| crash "todo: slice 057"
}
