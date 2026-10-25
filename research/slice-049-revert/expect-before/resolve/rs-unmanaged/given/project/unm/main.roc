app [main!] {
	pf: platform "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst",
	json: "./json/main.roc",   # my json
	other: "https://example.com/pkg/latest.tar.gz",
	parser: "https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst",
	roc: "nightly-2026-10-14-38a3029",
}

main! = |_args| Ok({})
