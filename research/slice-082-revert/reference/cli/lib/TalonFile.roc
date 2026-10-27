import Fail
import JsonDoc

## The format of the JSON files that Talon writes (CLI 6.1, R-TF1 to R-TF3, R-TF6). `format` is a top-level integer.
## The other top-level fields are `fields`, in the order of the text. A field that Talon does not know stays in
## `fields` and is written again (R-TF2).
TalonFile :: [].{

	## Reads the text of a Talon file. `newest` is the `format` that this Talon writes. `can_recreate` is true for a
	## file that Talon can make again (`path-roc.json`, a manifest in `talon/x/`: R-TF3).
	##
	## | Text | `can_recreate` false | `can_recreate` true | Rule |
	## | --- | --- | --- | --- |
	## | A JSON object with an integer `format` of `newest` or less | `Use({ format, fields })` | The same | R-TF1, R-TF2 |
	## | A `format` above `newest` | `Err`, kind `Input` (exit 19): `<path>: format <n> is newer than this tln (format <newest>). Run: tln tool update talon` | `Ignore`: no read, no write | R-TF3 |
	## | Other text (not JSON, not an object, no integer `format`) | `Err`, kind `Input`: `<path>: the content does not parse` | `Recreate(<warning>)`: delete the file, print the warning, make it again. The warning is `<path>: the content does not parse. Talon deletes it and makes it again.` | R-TF6 |
	##
	## `fields` has no `format`. A file with a `format` below `newest` is `Use` with that `format`: the caller migrates
	## it when it writes it (R-TF3). No file in P0 has an older format.
	open : { path : Str, text : Str, newest : U64, can_recreate : Bool } -> Try([Use({ format : U64, fields : List((Str, JsonDoc)) }), Ignore, Recreate(Str)], Fail)
	open = |facts| {
		garbage = if facts.can_recreate {
			Ok(Recreate("${facts.path}: the content does not parse. Talon deletes it and makes it again."))
		} else {
			Err(Fail.new(Input, "${facts.path}: the content does not parse"))
		}
		match JsonDoc.parse(facts.text) {
			Ok(Obj(pairs)) => match pairs.find_first(|(key, _)| key == "format") {
				Ok((_, Num(n))) if n >= 0 => {
					format = n.to_u64_wrap()
					if format > facts.newest {
						if facts.can_recreate {
							Ok(Ignore)
						} else {
							Err(Fail.new(Input, "${facts.path}: format ${format.to_str()} is newer than this tln (format ${facts.newest.to_str()}). Run: tln tool update talon"))
						}
					} else {
						Ok(Use({ format, fields: pairs.keep_if(|(key, _)| key != "format") }))
					}
				}
				_ => garbage
			}
			_ => garbage
		}
	}

	## The text to write: the JSON object with `format` first, then `fields`, as `JsonDoc.render`, and one `\n` at the end.
	## The form is a proposal (one line).
	render : { format : U64, fields : List((Str, JsonDoc)) } -> Str
	render = |facts| "${JsonDoc.Obj([("format", JsonDoc.Num(facts.format.to_i64_wrap()))].concat(facts.fields)).render()}\n"
}
