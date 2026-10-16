app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	pkg: "../package/main.roc",
}

import fuzz.Fuzz
import pkg.P

target = Fuzz.target_with({
	name: "t",
	generator: Fuzz.str,
	test: |text| if P.check(text) Fuzz.keep else Fuzz.keep,
	show: Str.inspect,
})
