app [target] { fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst" }

import fuzz.Fuzz
import Semver

Input := { major : U64, minor : U64, patch : U64 }.{
	generator_for : Fuzz.FuzzEncoding -> Fuzz.Generator(Input)
	generator_for = |_| { major: Fuzz.u64, minor: Fuzz.u64, patch: Fuzz.u64 }.Fuzz
}

## parse(to_str(v)) gives v back
test! : Input => Fuzz.Outcome
test! = |input| {
	text = Semver.to_str({ major: input.major, minor: input.minor, patch: input.patch })
	match Semver.parse(text) {
		Ok(back) if Semver.to_str(back) == text => Fuzz.keep
		_ => crash "round trip failed for ${text}"
	}
}

target = Fuzz.target_with!({
	name: "semver-round-trip",
	generator: Input.generator_for(Default),
	test!,
	show: |input| Str.inspect(input),
})
