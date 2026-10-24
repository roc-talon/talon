app [main!] {
	pf: platform "https://github.com/acme/pfx/releases/download/0.1.0/6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL.tar.zst",
	json: "https://github.com/acme/json/releases/download/2.1.0/4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq.tar.zst",
	parser: "https://github.com/acme/parser/releases/download/1.0.0/EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc.tar.zst",
}

import pf.Std
import json.Parser

main! = |_args| Ok({})
