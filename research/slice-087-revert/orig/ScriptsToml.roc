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

	## One step. `Line(text)` is a command line or `@<name>` (R-RUN4), as written, also the table `{ run = "<text>" }`. `In({ dir, run })` is the table `{ in = "<dir>", run = "<step string>" }` (R-RUN8), as written.
	## `Run({ dir, run, ok_exit })` is a table with `ok-exit` (slice 087, R-RUN18): `dir` is `Err(Here)` when the table has no `in`.
	Step : [Line(Str), In({ dir : Str, run : Str }), Run({ dir : Try(Str, [Here]), run : Str, ok_exit : List(U8) })]

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
	## | The value is not a string, a table or an array | `scripts.<key>: must be a step (a string, or a table with run) or an array of steps` |
	## | An item of the array is not a string or a table | `scripts.<key>[<n>]: must be a string or a table with run` (`<n>` is 1-based) |
	## | A table has no string `run`, an `in` that is not a string, or another key (a table that is the whole value too, `<key>` with no `[<n>]`) | `scripts.<key>[<n>]: a table step needs the string run, and can have the string in and ok-exit, no other key` |
	## | `ok-exit` is not an array of 1 or more integers from 0 to 255 (R-RUN18) | `scripts.<key>[<n>]: ok-exit must be an array of 1 or more integers from 0 to 255` |
	## | `ok-exit` with `run = "@<name>"` (R-RUN18) | `scripts.<key>[<n>]: ok-exit is not allowed with run = "@<name>": put it on a step of the script <name>` |
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

	## The step as it is shown (the list of `tln run`, the messages): a `Line` is its text, an `In` is `in <dir>: <run>`. A `Run` is the same with no `ok-exit`.
	step_text : ScriptsToml.Step -> Str
	step_text = |step| match step {
		Line(text) => text
		In({ dir, run }) => "in ${dir}: ${run}"
		Run(r) => match r.dir {
			Ok(dir) => "in ${dir}: ${r.run}"
			Err(Here) => r.run
		}
	}

	## R-RUN18: the codes of the `ok-exit` of a step (`[]`: none).
	ok_exit : ScriptsToml.Step -> List(U8)
	ok_exit = |step| match step {
		Run(r) => r.ok_exit
		_ => []
	}
}

# The `read_table` of one key and its value: the script, and the issues.
One : { line : U64, script : Try(ScriptsToml.Script, [Bad]), issues : List(TomlKeys.Note) }

# `a-z` and `0-9`.
name_head : U8 -> Bool
name_head = |b| (b >= 'a' and b <= 'z') or (b >= '0' and b <= '9')

step_rule : Str
step_rule = "a table step needs the string run, and can have the string in and ok-exit, no other key"

# Why a table is not a step: the message.
table_why : [Table, OkExit, At(Str)] -> Str
table_why = |why| match why {
	Table => step_rule
	OkExit => "ok-exit must be an array of 1 or more integers from 0 to 255"
	At(name) => "ok-exit is not allowed with run = \"@${name}\": put it on a step of the script ${name}"
}

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
			Err(why) => refused(table_why(why))
		}
		Value.Array(items) => match read_items(items) {
			Ok(steps) => good(steps)
			Err(Item(n, Plain)) => { line, script: Err(Bad), issues: [{ line, message: "scripts.${key}[${n.to_str()}]: must be a string or a table with run" }] }
			Err(Item(n, Bad(why))) => { line, script: Err(Bad), issues: [{ line, message: "scripts.${key}[${n.to_str()}]: ${table_why(why)}" }] }
		}
		_ => refused("must be a step (a string, or a table with run) or an array of steps")
	}
}

# R-RUN1, R-RUN18: the table `{ run = "<step>" }` with the optional keys `in` (a string) and `ok-exit`, and no other key. `in` is a reserved word of Roc, so the key is the string "in".
table_step : Dict(Str, Value) -> Try(ScriptsToml.Step, [Table, OkExit, At(Str)])
table_step = |t| {
	known = t.keys().all(|k| k == "run" or k == "in" or k == "ok-exit")
	run = match t.get("run") {
		Ok(Value.String(text)) if known => text
		_ => return Err(Table)
	}
	dir = match t.get("in") {
		Ok(Value.String(text)) => Ok(text)
		Ok(_) => return Err(Table)
		Err(_) => Err(Here)
	}
	match t.get("ok-exit") {
		Err(_) => Ok(
			match dir {
				Ok(d) => In({ dir: d, run })
				Err(Here) => Line(run)
			},
		)
		Ok(value) => {
			codes = ok_codes(value) ? |_| OkExit
			line = run.trim()
			if line.starts_with("@") Err(At(line.drop_prefix("@"))) else Ok(Run({ dir, run, ok_exit: codes }))
		}
	}
}

# R-RUN18: an array of 1 or more integers from 0 to 255.
ok_codes : Value -> Try(List(U8), [Bad])
ok_codes = |value| match value {
	Value.Array([_, ..] as items) => items.map_try(
		|item| match item {
			Value.Integer(n) if n >= 0 and n <= 255 => Ok(n.to_u8_wrap())
			_ => Err(Bad)
		},
	)
	_ => Err(Bad)
}

# The items of an array: the steps, or the 1-based place of the first item that is not a step, and why.
read_items : List(Value) -> Try(List(ScriptsToml.Step), [Item(U64, [Plain, Bad([Table, OkExit, At(Str)])])])
read_items = |items| items.fold_try(
	[],
	|steps, item| {
		n = steps.len() + 1
		match item {
			Value.String(text) => Ok(steps.append(Line(text)))
			Value.Table(t) => match table_step(t) {
				Ok(step) => Ok(steps.append(step))
				Err(why) => Err(Item(n, Bad(why)))
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
