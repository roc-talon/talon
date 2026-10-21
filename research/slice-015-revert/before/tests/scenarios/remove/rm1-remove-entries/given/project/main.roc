app [main!] {
	pf: platform "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst",   # the platform
	json: "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst",
	parser: "https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst",
	xml: "https://github.com/acme/xml/releases/download/1.0.0/E6PYifPFJi9TKEr1v2C6JGTpcG9ghozE74kaMeyETSao.tar.zst",
	lex: "https://github.com/acme/lex/releases/download/1.0.0/ETHqKvPfSpgiJzvkfaLumTGq3KhTvan7meq82W7wz73L.tar.zst",
	util: "../util/main.roc",
	odd: "https://example.com/pkg/latest.tar.gz",
}

import pf.Stdout
import json.Json
import Helpers

main! = |_args| Stdout.line!(Json.name)
