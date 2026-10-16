app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	pkg: "../package/main.roc",
}

import fuzz.Fuzz
import pkg.Pair

Input := { text : Str, n : U64 }.{
	generator_for : Fuzz.FuzzEncoding -> Fuzz.Generator(Input)
	generator_for = |_| { text: Fuzz.str, n: Fuzz.u64 }.Fuzz
}

## Parse never crashes on any text, and "x=<n>" gives n back
test : Input -> Fuzz.Outcome
test = |input| {
	_ = Pair.parse(input.text)
	match Pair.parse("x=${input.n.to_str()}") {
		Ok(p) if p.value() == input.n => Fuzz.keep
		_ => crash "x=${input.n.to_str()} did not give ${input.n.to_str()}"
	}
}

target = Fuzz.target_with({
	name: "pair-props",
	generator: Input.generator_for(Default),
	test,
	show: |input| Str.inspect(input),
})
