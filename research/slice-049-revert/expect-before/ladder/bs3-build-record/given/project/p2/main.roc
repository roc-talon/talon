app [main!] {
	pf: platform "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst",
	json: "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst",
	parser: "https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst",
	roc: "nightly-2026-10-14-38a3029",
}


main! = |_args| Ok({})
import pf.Std
