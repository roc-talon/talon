app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	parser: "https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst",
	json: "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst",
}



import pf.Stdout
import parser.Parser
import json.Wire

main! = |_args| {
	Stdout.line!(Wire.encode(Parser.parse("x")))
}
