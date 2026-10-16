import Value

## A parsed TOML 1.0.0 document. It keeps the source text, so an edit
## (`replace`) changes only the bytes of one value and keeps all other bytes:
## comments, order, blank lines and the form of each value.
Toml :: { text : Str, table : Dict(Str, Value) }.{

	## Parses TOML 1.0.0 text. Invalid text gives an error with the 1-based
	## line and column (in bytes) where the parser stopped, and a message.
	parse : Str -> Try(Toml, [TomlErr({ line : U64, column : U64, message : Str })])
	parse = |_text| crash "todo"

	## The root table of the document.
	table : Toml -> Dict(Str, Value)
	table = |_doc| crash "todo"

	## The value at a key path. The path names keys only: it does not go into
	## an array, so it does not reach a table in an array of tables. The empty
	## path gives the root table.
	get : Toml, List(Str) -> Try(Value, [NotFound])
	get = |_doc, _path| crash "todo"

	## A table as a TOML document. In each table, the keys whose values are not
	## tables and not arrays of tables come first, as `key = value` lines
	## (`Value.print`), in the order of the `Dict`. Then each sub-table is a
	## `[a.b]` section, and each array of tables (a non-empty array with only
	## tables in it) is one `[[a.b]]` section for each element. A table that is
	## not empty and has only sub-tables and arrays of tables gets no header
	## line. A blank line comes before each header line, except at the start.
	## Each line ends with `\n`. The empty table gives the empty text.
	##
	## The text parses back to an equal table when each date in it exists.
	print : Dict(Str, Value) -> Str
	print = |_table| crash "todo"

	## The text of the document. After `parse`, it is the parsed text.
	to_str : Toml -> Str
	to_str = |_doc| crash "todo"

	## Replaces the value of the entry `key = value` at the key path. The new
	## text is the old text with the bytes of the old value replaced by
	## `Value.print(new)`. All other bytes stay the same, also a comment on the
	## same line. The entry can be a dotted key or a key in an inline table.
	## `NoEntry` when the path names no entry: a missing key, or a table that a
	## header or a dotted key makes.
	replace : Toml, List(Str), Value -> Try(Toml, [NoEntry])
	replace = |_doc, _path, _new| crash "todo"

	## The 1-based line of the first byte of the key of the entry at the key
	## path. `NoEntry` as for `replace`.
	line : Toml, List(Str) -> Try(U64, [NoEntry])
	line = |_doc, _path| crash "todo"
}
