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
	is_name = |text| match text.to_utf8() {
		[first, .. as rest] => rest.len() < 64 and name_head(first) and rest.all(|b| name_head(b) or b == ':' or b == '_' or b == '-')
		[] => Bool.False
	}

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
	read_table = |doc| match Toml.get(doc, ["scripts"]) {
		Err(NotFound) => { value: [], issues: [], warnings: [] }
		Ok(Value.Table(t)) => {
			rows = t.to_list().map(|(key, value)| read_script(doc, key, value)).sort_with(|a, b| TomlKeys.compare_lines(a.line, b.line))
			{ value: rows.keep_oks(|r| r.script), issues: rows.join_map(|r| r.issues), warnings: [] }
		}
		Ok(_) => { value: [], issues: [{ line: TomlKeys.key_line(doc, ["scripts"]), message: "scripts: must be a table" }], warnings: [] }
	}

	## R-RUN1: `read_table` of a text, as `tln run` uses it. The first issue by line is a failure of kind `Input` (exit 19): `<path>:<line>: <message>` (the messages of `read_table`). Text that is not TOML: `<path>:<line>: not valid TOML`. A text with no `[scripts]` table gives no script.
	read : { path : Str, text : Str } -> Try(List(ScriptsToml.Script), Fail)
	read = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(doc) => {
			found = read_table(doc)
			match found.issues.first() {
				Ok(issue) => Err(Fail.new(Input, "${facts.path}:${issue.line.to_str()}: ${issue.message}"))
				Err(_) => Ok(found.value)
			}
		}
	}

	## R-RUN2: the words of a command line. A space or a tab separates two words. `"..."` and `'...'` quote (the quotes are not in the word). In `"..."` the escapes are `\"` and `\\`; any other backslash stays. In `'...'` and outside quotes a backslash stays.
	## There is no expansion: `$HOME`, `~` and `*.txt` are words as they are. An unquoted word `|`, `&&`, `||`, `;`, `>`, `>>`, `<` or `&`, and an unquoted word that starts with `$(` or a backquote, is `Err(Shell(<the word>))`. A quoted word is never refused.
	## `Err(Unclosed)`: a quote that is not closed (`RunPlan.plan` makes it exit 19 with the script named, before the first step, Q3 of the review). A quote inside a word joins: `a"b c"d` is the one word `ab cd`. The empty text has no word.
	words : Str -> Try(List(Str), [Shell(Str), Unclosed])
	words = |text| read_words(text.to_utf8(), { done: [], cur: [], begun: Bool.False, quoted: Bool.False, mode: Plain })

	## The step as it is shown (the list of `tln run`, the messages): a `Line` is its text, an `In` is `in <dir>: <run>`.
	step_text : ScriptsToml.Step -> Str
	step_text = |step| match step {
		Line(text) => text
		In({ dir, run }) => "in ${dir}: ${run}"
	}
}

# The `read_table` of one key and its value: the script, and the issues.
One : { line : U64, script : Try(ScriptsToml.Script, [Bad]), issues : List(TomlKeys.Note) }

# `a-z` and `0-9`.
name_head : U8 -> Bool
name_head = |b| (b >= 'a' and b <= 'z') or (b >= '0' and b <= '9')

step_rule : Str
step_rule = "a table step needs the strings in and run, and no other key"

# R-RUN1: one key of `[scripts]`. The first problem is its one issue (all issues are at the line of the key).
read_script : Toml, Str, Value -> One
read_script = |doc, key, value| {
	line = TomlKeys.key_line(doc, ["scripts", key])
	refused = |why| { line, script: Err(Bad), issues: [{ line, message: "scripts.${key}: ${why}" }] }
	if !ScriptsToml.is_name(key) {
		return refused("the key is not a script name (lower case letters, digits, ':', '_' and '-', the first one a letter or a digit, at most 64 characters)")
	}
	good = |steps| { line, script: Ok({ name: key, steps, line }), issues: [] }
	match value {
		Value.String(text) => good([Line(text)])
		Value.Table(t) => match table_step(t) {
			Ok(step) => good([step])
			Err(Bad) => refused(step_rule)
		}
		Value.Array(items) => match read_items(items) {
			Ok(steps) => good(steps)
			Err(Item(n, Plain)) => { line, script: Err(Bad), issues: [{ line, message: "scripts.${key}[${n.to_str()}]: must be a string or a table with in and run" }] }
			Err(Item(n, Table)) => { line, script: Err(Bad), issues: [{ line, message: "scripts.${key}[${n.to_str()}]: ${step_rule}" }] }
		}
		_ => refused("must be a step (a string, or a table with in and run) or an array of steps")
	}
}

# The table `{ in = "<dir>", run = "<step>" }`: the 2 strings and no other key. `in` is a reserved word of Roc, so the key is the string "in".
table_step : Dict(Str, Value) -> Try(ScriptsToml.Step, [Bad])
table_step = |t| match (t.get("in"), t.get("run")) {
	(Ok(Value.String(dir)), Ok(Value.String(run))) => if t.len() == 2 Ok(In({ dir, run })) else Err(Bad)
	_ => Err(Bad)
}

# The items of an array: the steps, or the 1-based place of the first item that is not a step, and why.
read_items : List(Value) -> Try(List(ScriptsToml.Step), [Item(U64, [Plain, Table])])
read_items = |items| items.fold_try(
	[],
	|steps, item| {
		n = steps.len() + 1
		match item {
			Value.String(text) => Ok(steps.append(Line(text)))
			Value.Table(t) => match table_step(t) {
				Ok(step) => Ok(steps.append(step))
				Err(Bad) => Err(Item(n, Table))
			}
			_ => Err(Item(n, Plain))
		}
	},
)

# R-RUN2: the state of the scan of a command line. `begun` is true when a word has started (an empty quoted word is a word), `quoted` when a quote was in the word.
Reading : { done : List(Str), cur : List(U8), begun : Bool, quoted : Bool, mode : [Plain, Dq, Sq] }

read_words : List(U8), Reading -> Try(List(Str), [Shell(Str), Unclosed])
read_words = |bytes, st| match st.mode {
	Plain => match bytes {
		[] => Ok(flush(st)?.done)
		[b, .. as rest] => if b == ' ' or b == '\t' {
			read_words(rest, flush(st)?)
		} else if b == '"' {
			read_words(rest, { ..st, mode: Dq, begun: Bool.True, quoted: Bool.True })
		} else if b == '\'' {
			read_words(rest, { ..st, mode: Sq, begun: Bool.True, quoted: Bool.True })
		} else {
			read_words(rest, { ..st, cur: st.cur.append(b), begun: Bool.True })
		}
	}
	Dq => match bytes {
		[] => Err(Unclosed)
		['\\', next, .. as rest] if next == '"' or next == '\\' => read_words(rest, { ..st, cur: st.cur.append(next) })
		['"', .. as rest] => read_words(rest, { ..st, mode: Plain })
		[b, .. as rest] => read_words(rest, { ..st, cur: st.cur.append(b) })
	}
	Sq => match bytes {
		[] => Err(Unclosed)
		['\'', .. as rest] => read_words(rest, { ..st, mode: Plain })
		[b, .. as rest] => read_words(rest, { ..st, cur: st.cur.append(b) })
	}
}

# The end of a word: it joins the list. An unquoted word that is shell syntax is refused.
flush : Reading -> Try(Reading, [Shell(Str)])
flush = |st| if st.begun {
	word = Str.from_utf8_lossy(st.cur)
	if !st.quoted and is_shell(word) {
		Err(Shell(word))
	} else {
		Ok({ done: st.done.append(word), cur: [], begun: Bool.False, quoted: Bool.False, mode: Plain })
	}
} else {
	Ok(st)
}

is_shell : Str -> Bool
is_shell = |word| ["|", "&&", "||", ";", ">", ">>", "<", "&"].contains(word) or word.starts_with("$(") or word.starts_with("`")
