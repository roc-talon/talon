app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	pkg: "../layout-probe/package/main.roc",
}

import fuzz.Fuzz
import pkg.Hex

target = Fuzz.target_with({
	name: "copyeq",
	generator: Fuzz.bytes,
	test: |bytes| if bytes.append(1) == bytes.append(1) Fuzz.keep else crash "copyeq failed",
	show: Str.inspect,
})
