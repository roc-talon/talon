app [main!] { toml: "https://github.com/Karakatiza666/roc-toml/releases/download/0.1.0/3icmtKz6XQUyHqu5JftcoJJT6a9YTND1B8z1UAmtqJpN.tar.zst" }

import toml.Toml
import toml.Value

main! = |_args| Ok({})

text =
	\\# Settings
	\\[server]
	\\port = 8080 # the default
	\\

expect {
	doc = Toml.parse(text)?
	doc.get(["server", "port"]) == Ok(Integer(8080))
}

expect {
	doc = Toml.parse(text)?
	edited = doc.replace(["server", "port"], Integer(9090))?
	edited.to_str() == "# Settings\n[server]\nport = 9090 # the default\n"
}

expect {
	doc = Toml.parse(text)?
	edited = doc.insert(["server", "host"], String("localhost"))?
	edited.get(["server", "host"]) == Ok(String("localhost"))
}
