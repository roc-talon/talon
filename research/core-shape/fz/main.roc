app [target] { fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst" }

import fuzz.Fuzz
import Inject

Input := { text : Str, path : Str }.{
	generator_for : Fuzz.FuzzEncoding -> Fuzz.Generator(Input)
	generator_for = |_| { text: Fuzz.str, path: Fuzz.str }.Fuzz
}

## Direct-style effectful code, driven by a fuzz target with a fake effect record
test! : Input => Fuzz.Outcome
test! = |input| {
	fake = { read!: |_| Ok(input.text) }
	n = Inject.count_lines!(fake, input.path)
	if n == input.text.split_on("\n").len() Fuzz.keep else crash "line count differs"
}

target = Fuzz.target_with!({
	name: "inject",
	generator: Input.generator_for(Default),
	test!,
	show: |input| Str.inspect(input),
})
