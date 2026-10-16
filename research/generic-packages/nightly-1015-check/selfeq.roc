app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	pkg: "../layout-probe/package/main.roc",
}

import fuzz.Fuzz
import pkg.Hex

target = Fuzz.target_with({
	name: "selfeq",
	generator: Fuzz.bytes,
	test: |bytes| if bytes == bytes Fuzz.keep else crash "selfeq failed",
	show: Str.inspect,
})
