import Fail
import header.Header

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
	app_text = |x| match Header.parse(x.text) {
		Ok(header) => match header.kind() {
			Platform(_) => {
				span = header.span()
				toks = tokens(x.text.to_utf8().sublist({ start: span.start, len: span.end - span.start }))
				match clause_values(toks) {
					Ok(values) => entries_app(x, split_entries(values, Bool.True))
					Err(NoClause) => Err(no_clause(x.name))
				}
			}
			_ => Err(no_clause(x.name))
		}
		Err(_) => Err(no_clause(x.name))
	}
}

# The scan of a platform header (the pattern of `BuildTarget`). A token has its kind, its text and its byte span. Comments give no token. A string is one token of the kind `Other`.
Tok : { kind : [Word, Open, Close, Colon, Comma, Arrow, Other], text : Str, start : U64, end : U64 }

Entry : { aliases : List(Str), name : Str, type : List(Tok) }

no_toks : List(Tok)
no_toks = []

no_parts : List(List(Tok))
no_parts = []

no_hits : List(U64)
no_hits = []

no_lines : List(Str)
no_lines = []

blank : Tok
blank = { kind: Other, text: "", start: 0, end: 0 }

crash_text : Str
crash_text = "crash \"write the app\""

at : List(U8), U64 -> U8
at = |bytes, i| bytes.get(i) ?? 0

tok_at : List(Tok), U64 -> Tok
tok_at = |toks, i| toks.get(i) ?? blank

is_word_byte : U8 -> Bool
is_word_byte = |b| (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9') or b == '_'

is_space : U8 -> Bool
is_space = |b| b == ' ' or b == '\t' or b == '\n' or b == '\r'

# The index after the string that starts at `start` (the quote), with `\` escapes.
string_end : List(U8), U64 -> U64
string_end = |bytes, start| {
	n = bytes.len()
	var $j = start + 1
	while $j < n and at(bytes, $j) != '"' {
		$j = if at(bytes, $j) == '\\' $j + 2 else $j + 1
	}
	$j + 1
}

# The index after the word that starts at `start`: word bytes, and one `!` at the end.
word_end : List(U8), U64 -> U64
word_end = |bytes, start| {
	var $j = start
	while is_word_byte(at(bytes, $j)) {
		$j = $j + 1
	}
	if at(bytes, $j) == '!' $j + 1 else $j
}

tok_of : List(U8), U64, U64, [Word, Open, Close, Colon, Comma, Arrow, Other] -> Tok
tok_of = |bytes, start, end, kind| { kind, text: Str.from_utf8_lossy(bytes.sublist({ start, len: end - start })), start, end }

# The kind and the width of the token that starts with a byte that is no word, no space and no quote.
punct : List(U8), U64 -> { kind : [Word, Open, Close, Colon, Comma, Arrow, Other], width : U64 }
punct = |bytes, i| {
	b = at(bytes, i)
	if (b == '=' or b == '-') and at(bytes, i + 1) == '>' {
		{ kind: Arrow, width: 2 }
	} else if b == '{' or b == '[' or b == '(' {
		{ kind: Open, width: 1 }
	} else if b == '}' or b == ']' or b == ')' {
		{ kind: Close, width: 1 }
	} else if b == ':' {
		{ kind: Colon, width: 1 }
	} else if b == ',' {
		{ kind: Comma, width: 1 }
	} else {
		{ kind: Other, width: 1 }
	}
}

tokens : List(U8) -> List(Tok)
tokens = |bytes| {
	n = bytes.len()
	var $out = no_toks
	var $i = 0
	while $i < n {
		b = at(bytes, $i)
		if b == '#' {
			while $i < n and at(bytes, $i) != '\n' {
				$i = $i + 1
			}
		} else if b == '"' {
			end = string_end(bytes, $i)
			$out = $out.append(tok_of(bytes, $i, end, Other))
			$i = end
		} else if is_space(b) {
			$i = $i + 1
		} else if is_word_byte(b) {
			end = word_end(bytes, $i)
			$out = $out.append(tok_of(bytes, $i, end, Word))
			$i = end
		} else {
			found = punct(bytes, $i)
			$out = $out.append(tok_of(bytes, $i, $i + found.width, found.kind))
			$i = $i + found.width
		}
	}
	$out
}

is_open : Tok -> Bool
is_open = |t| t.kind == Open

is_word : Tok, Str -> Bool
is_word = |t, text| t.kind == Word and t.text == text

# The text of tokens: one space where the source had white space or a comment between two tokens.
join_text : List(Tok) -> Str
join_text = |toks| {
	var $out = ""
	var $prev = 0
	var $first = Bool.True
	for t in toks {
		gap = if !$first and t.start > $prev " " else ""
		$out = Str.concat($out, Str.concat(gap, t.text))
		$prev = t.end
		$first = Bool.False
	}
	$out
}

# The index of the bracket that closes the bracket at `from`. At the end of the list when it is not closed.
close_of : List(Tok), U64 -> U64
close_of = |toks, from| {
	var $depth = 0.I64
	var $k = from
	var $found = toks.len()
	while $k < toks.len() and $found == toks.len() {
		match tok_at(toks, $k).kind {
			Open => {
				$depth = $depth + 1
			}
			Close => {
				$depth = $depth - 1
				if $depth == 0 {
					$found = $k
				}
			}
			_ => {}
		}
		$k = $k + 1
	}
	$found
}

# The values of the `requires` clause: the group after the word `requires` at depth 0. The old form has two groups: the values are in the second.
clause_values : List(Tok) -> Try(List(Tok), [NoClause])
clause_values = |toks| {
	var $depth = 0.I64
	var $at = toks.len()
	var $k = 0
	while $k < toks.len() and $at == toks.len() {
		t = tok_at(toks, $k)
		match t.kind {
			Open => {
				$depth = $depth + 1
			}
			Close => {
				$depth = $depth - 1
			}
			Word if $depth == 0 and t.text == "requires" => {
				$at = $k
			}
			_ => {}
		}
		$k = $k + 1
	}
	first = $at + 1
	if first >= toks.len() or !is_open(tok_at(toks, first)) {
		Err(NoClause)
	} else {
		end1 = close_of(toks, first)
		if is_open(tok_at(toks, end1 + 1)) {
			end2 = close_of(toks, end1 + 1)
			Ok(toks.sublist({ start: end1 + 2, len: end2 - end1 - 2 }))
		} else {
			Ok(toks.sublist({ start: first + 1, len: end1 - first - 1 }))
		}
	}
}

# A comma at depth 0 starts the next entry when `name :` follows it (and, between the entries of a clause, `[Alias : var] for`).
starts_entry : List(Tok), U64, Bool -> Bool
starts_entry = |toks, j, with_alias| {
	t = tok_at(toks, j)
	if t.kind == Word {
		tok_at(toks, j + 1).kind == Colon
	} else if with_alias and t.kind == Open and t.text == "[" {
		is_word(tok_at(toks, close_of(toks, j) + 1), "for")
	} else {
		Bool.False
	}
}

# The entries of a clause, or the fields of a record type: the pieces between the commas that start an entry. A last comma and empty pieces are dropped.
split_entries : List(Tok), Bool -> List(List(Tok))
split_entries = |toks, with_alias| {
	var $depth = 0.I64
	var $from = 0
	var $parts = no_parts
	var $k = 0
	while $k < toks.len() {
		match tok_at(toks, $k).kind {
			Open => {
				$depth = $depth + 1
			}
			Close => {
				$depth = $depth - 1
			}
			Comma if $depth == 0 and starts_entry(toks, $k + 1, with_alias) => {
				$parts = $parts.append(toks.sublist({ start: $from, len: $k - $from }))
				$from = $k + 1
			}
			_ => {}
		}
		$k = $k + 1
	}
	$parts = $parts.append(toks.sublist({ start: $from, len: toks.len() - $from }))
	$parts.map(drop_last_comma).keep_if(|part| !part.is_empty())
}

drop_last_comma : List(Tok) -> List(Tok)
drop_last_comma = |part| if !part.is_empty() and tok_at(part, part.len() - 1).kind == Comma part.drop_last(1) else part

# The alias names of `[Alias : var, ...]`: the words that a colon follows, at depth 0 of the brackets.
alias_names : List(Tok) -> List(Str)
alias_names = |inner| {
	var $depth = 0.I64
	var $names = no_lines
	var $k = 0
	while $k < inner.len() {
		t = tok_at(inner, $k)
		match t.kind {
			Open => {
				$depth = $depth + 1
			}
			Close => {
				$depth = $depth - 1
			}
			Word if $depth == 0 and tok_at(inner, $k + 1).kind == Colon => {
				$names = $names.append(t.text)
			}
			_ => {}
		}
		$k = $k + 1
	}
	$names
}

# One entry: `name : <type>` or `[Alias : var, ...] for name : <type>`.
parse_entry : List(Tok) -> Try(Entry, [Bad])
parse_entry = |part| {
	first = tok_at(part, 0)
	if first.kind == Open and first.text == "[" {
		close = close_of(part, 0)
		rest = part.drop_first(close + 1)
		if is_word(tok_at(rest, 0), "for") and tok_at(rest, 1).kind == Word and tok_at(rest, 2).kind == Colon {
			aliases = alias_names(part.sublist({ start: 1, len: close - 1 }))
			Ok({ aliases, name: tok_at(rest, 1).text, type: rest.drop_first(3) })
		} else {
			Err(Bad)
		}
	} else if first.kind == Word and tok_at(part, 1).kind == Colon {
		Ok({ aliases: [], name: first.text, type: part.drop_first(2) })
	} else {
		Err(Bad)
	}
}

no_clause : Str -> Fail
no_clause = |name| Fail.new(Usage, "${name} has no requires clause: it is not a platform (R-IN8)")

# The app for the entries of the clause (answer Q6: one entry only).
entries_app : { name : Str, url : Str, text : Str }, List(List(Tok)) -> Try(Str, Fail)
entries_app = |x, parts| match parts {
	[part] => match parse_entry(part) {
		Ok(entry) => match stub_of(entry.type, 0) {
			Ok(stub) => Ok(app_of(x.url, entry, stub))
			Err(type_text) => Err(Fail.new(Usage, "cannot make the stub app for ${x.name}: the value ${entry.name} of its requires clause has the type ${type_text}, and R-SM2 has no stub for that type (R-IN8). Nothing was written."))
		}
		Err(Bad) => Err(no_clause(x.name))
	}
	[] => Err(no_clause(x.name))
	_ => Err(Fail.new(Usage, "cannot make the stub app for ${x.name}: its requires clause has ${parts.len().to_str()} values (${Str.join_with(parts.map(join_text), ", ")}), and R-SM2 gives a stub for one value only (R-IN8). Nothing was written."))
}

# R-IN8: the text of the app, the layout of the doc of `app_text`.
app_of : Str, Entry, Str -> Str
app_of = |url, entry, stub| {
	exposed = Str.join_with(entry.aliases.append(entry.name), ", ")
	alias_blocks = entry.aliases.map(|alias| "${alias} : {}\n\n")
	"app [${exposed}] {\n\tpf: platform \"${url}\",\n}\n\n${Str.join_with(alias_blocks, "")}${entry.name} = ${stub}\n"
}

# The index of the first arrow (`=>` or `->`) at depth 0.
arrow_at : List(Tok) -> Try(U64, [NoArrow])
arrow_at = |toks| {
	var $depth = 0.I64
	var $hits = no_hits
	var $k = 0
	while $k < toks.len() {
		match tok_at(toks, $k).kind {
			Open => {
				$depth = $depth + 1
			}
			Close => {
				$depth = $depth - 1
			}
			Arrow if $depth == 0 => {
				$hits = $hits.append($k)
			}
			_ => {}
		}
		$k = $k + 1
	}
	match $hits {
		[first, ..] => Ok(first)
		[] => Err(NoArrow)
	}
}

# The number of arguments of a function type: the commas at depth 0 of the part before the arrow, plus one. `()` has none.
arg_count : List(Tok) -> U64
arg_count = |args| {
	var $depth = 0.I64
	var $commas = 0
	for t in args {
		match t.kind {
			Open => {
				$depth = $depth + 1
			}
			Close => {
				$depth = $depth - 1
			}
			Comma if $depth == 0 => {
				$commas = $commas + 1
			}
			_ => {}
		}
	}
	if args.len() == 2 and is_open(tok_at(args, 0)) and tok_at(args, 0).text == "(" and tok_at(args, 1).kind == Close 0 else $commas + 1
}

lambda : U64 -> Str
lambda = |n| if n == 0 "|| ${crash_text}" else "|${Str.join_with(List.repeat("_", n), ", ")}| ${crash_text}"

tabs : U64 -> Str
tabs = |n| Str.join_with(List.repeat("\t", n), "")

# The stub of a type (R-SM2). `Err` has the text of the first type in source order that has no stub. `level` is the indent of the line of the value.
stub_of : List(Tok), U64 -> Try(Str, Str)
stub_of = |toks, level| match arrow_at(toks) {
	Ok(at_arrow) => Ok(lambda(arg_count(toks.take_first(at_arrow))))
	Err(NoArrow) => if is_record(toks) record_stub(split_entries(toks.sublist({ start: 1, len: toks.len() - 2 }), Bool.False), level) else Err(join_text(toks))
}

# The whole type is one record `{ ... }`.
is_record : List(Tok) -> Bool
is_record = |toks| tok_at(toks, 0).kind == Open and tok_at(toks, 0).text == "{" and close_of(toks, 0) + 1 == toks.len()

record_stub : List(List(Tok)), U64 -> Try(Str, Str)
record_stub = |fields, level| {
	if fields.is_empty() {
		return Ok("{}")
	}
	var $lines = no_lines
	for field in fields {
		if tok_at(field, 0).kind == Word and tok_at(field, 1).kind == Colon {
			match stub_of(field.drop_first(2), level + 1) {
				Ok(stub) => {
					$lines = $lines.append("${tabs(level + 1)}${tok_at(field, 0).text}: ${stub},\n")
				}
				Err(type_text) => return Err(type_text)
			}
		} else {
			return Err(join_text(field))
		}
	}
	Ok("{\n${Str.join_with($lines, "")}${tabs(level)}}")
}
