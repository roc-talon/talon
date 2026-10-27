## The picker of `tln update -i` (R-SP4, R-SP14, R-NI2, R-NM7). Part A (pure): the list that the person sees, and the read of the reply. The ask is command code (`Update.run!`).
## The names that the person picks follow the row `tln update X Y` (R-SP4): `Update.run!` calls the flow with them as operands.
##
## The text and the reply form are a proposal (TW24, question Q2 of slice 009):
##
## | Item | Text |
## | --- | --- |
## | List, on stderr, before the question | A first line `update can move these packages:`, then one line for each item in the order of `items` (the order of `priority`, R-SP14): 2 spaces, the number, `) `, the alias padded with spaces to the longest alias plus 2, then `<name> <version>`. Each line ends with a line end. |
## | Question (`Picker.question`), the text of `Fx.ask!` | `Pick packages to update (numbers or names, empty for none): ` |
##
## The reply is read by `reply`. The command asks again for an `Invalid` reply.
Picker :: [].{

	## One free package: the first alias of its variable (`Vars.picker`), its full name (`Var.name`, or the URL form), and the version of its first use.
	Item : { alias : Str, name : Str, version : Str }

	## The text of the list (the table above). For the items `json acme/json 2.0.0` and `parser acme/parser 1.0.0`:
	## `update can move these packages:`, `  1) json    acme/json 2.0.0`, `  2) parser  acme/parser 1.0.0`.
	text : List(Item) -> Str
	text = |items| {
		width = items.fold(0, |most, item| if item.alias.count_utf8_bytes() > most item.alias.count_utf8_bytes() else most) + 2
		lines = items.map_with_index(
			|item, i| {
				pad = " ".repeat(width - item.alias.count_utf8_bytes())
				"  ${(i + 1).to_str()}) ${item.alias}${pad}${item.name} ${item.version}\n"
			},
		)
		"update can move these packages:\n${Str.join_with(lines, "")}"
	}

	## The text of the question.
	question : Str
	question = "Pick packages to update (numbers or names, empty for none): "

	## The aliases that a reply picks, in the order of `items`, each once. A reply is words split by spaces and commas. A word is a number from 1 to the count of items, or the alias of an item.
	## An empty reply (after trim) picks nothing: `Ok([])`. A word that is neither (`0`, a number above the count, an unknown name) makes the whole reply `Err(Invalid)`.
	reply : { items : List(Item), line : Str } -> Try(List(Str), [Invalid])
	reply = |facts| {
		words = facts.line.replace_each(",", " ").replace_each("\t", " ").split_on(" ").keep_if(|w| w != "")
		picked = words.map_try(|word| alias_of(facts.items, word))?
		Ok(facts.items.keep_if(|item| picked.contains(item.alias)).map(|item| item.alias))
	}
}

# A word is a number from 1 to the count of items, or the alias of an item.
alias_of : List(Picker.Item), Str -> Try(Str, [Invalid])
alias_of = |items, word| match U64.from_str(word) {
	Ok(n) => match items.get(n.minus_wrap(1)) {
		Ok(item) if n >= 1 => Ok(item.alias)
		_ => Err(Invalid)
	}
	Err(_) => match items.find_first(|item| item.alias == word) {
		Ok(item) => Ok(item.alias)
		Err(_) => Err(Invalid)
	}
}
