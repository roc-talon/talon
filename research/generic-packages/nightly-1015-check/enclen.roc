app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	pkg: "../layout-probe/package/main.roc",
}

import fuzz.Fuzz
import pkg.Hex

target = Fuzz.target_with({
	name: "enclen",
	generator: Fuzz.bytes,
	test: |bytes| if Hex.encode(bytes).to_utf8().len() == 2 * bytes.len() Fuzz.keep else crash "enclen failed",
	show: Str.inspect,
})
