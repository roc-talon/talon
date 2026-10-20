app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Picker

main! = |_args| Ok({})

items = [
	{ alias: "json", name: "acme/json", version: "2.0.0" },
	{ alias: "parser", name: "acme/parser", version: "1.0.0" },
	{ alias: "pf", name: "acme/pf", version: "0.1.0" },
]

# R-SP14 R-NI2 R-NR2 R-OUT2 (question Q2 of slice 009): the text of the list. One line for each free package in the order of `items` (the order of `priority`), with its number. The aliases are padded to the longest alias plus 2. The question text is a constant.
expect {
	two = [{ alias: "json", name: "acme/json", version: "2.0.0" }, { alias: "pf", name: "acme/pf", version: "0.1.0" }]
	text = Picker.text(items)
	want = "update can move these packages:\n  1) json    acme/json 2.0.0\n  2) parser  acme/parser 1.0.0\n  3) pf      acme/pf 0.1.0\n"
	dbg text
	text == want and Picker.text(two) == "update can move these packages:\n  1) json  acme/json 2.0.0\n  2) pf    acme/pf 0.1.0\n" and Picker.question == "Pick packages to update (numbers or names, empty for none): "
}

# R-SP4 R-SP14 R-SP11 R-NM7 (question Q2 of slice 009): the reply of the picker. Numbers and aliases, split by spaces and commas. The result is in the order of the list, with no repeat. An empty reply picks nothing. A word that is not a number from 1 to the count, and is not an alias, makes the whole reply invalid (the command asks again).
expect {
	rows = [
		("1", Ok(["json"])),
		("2 1", Ok(["json", "parser"])),
		("pf,json", Ok(["json", "pf"])),
		("  3 ,  parser  ", Ok(["parser", "pf"])),
		("1 json 1", Ok(["json"])),
		("", Ok([])),
		("   ", Ok([])),
		("0", Err(Invalid)),
		("4", Err(Invalid)),
		("json nosuch", Err(Invalid)),
		("1.5", Err(Invalid)),
		("PF", Err(Invalid)),
		("js", Err(Invalid)),
		("-1", Err(Invalid)),
	]
	got = |line| Picker.reply({ items, line })
	bad = rows.keep_if(|(line, want)| got(line) != want).map(|(line, _)| (line, got(line)))
	dbg bad
	bad == [] and Picker.reply({ items: [], line: "" }) == Ok([]) and Picker.reply({ items: [], line: "1" }) == Err(Invalid)
}
