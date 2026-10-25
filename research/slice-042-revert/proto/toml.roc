app [main!] {
	lib: "../../../cli/lib/main.roc",
	toml: "https://github.com/Karakatiza666/roc-toml/releases/download/0.1.0/3icmtKz6XQUyHqu5JftcoJJT6a9YTND1B8z1UAmtqJpN.tar.zst",
}

import toml.Toml
import toml.Value

main! = |_args| Ok({})

# Prototype for slice 042: what Toml.insert writes for a [patch] entry.
entry = Value.Table(Dict.from_list([("path", Value.String("./.talon/patches/json/main.roc")), ("base", Value.String("abc"))]))

show = |text| match Toml.parse(text) {
	Ok(doc) => match Toml.insert(doc, ["patch", "json"], entry) {
		Ok(done) => Ok(done.to_str())
		Err(e) => Err(Str.inspect(e))
	}
	Err(_) => Err("parse")
}

expect {
	dbg show("")
	dbg show("# top\n[dependencies]\njson = \"^2\"  # c\n")
	dbg show("[dependencies]\njson = \"^2\"\n\n[patch]\nother = { path = \"x\", base = \"y\" }\n\n[resolution]\nstrategy = \"lowest\"\n")
	dbg show("[dependencies]\njson = \"^2\"")
	Bool.True
}
