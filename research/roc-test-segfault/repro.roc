# Repro (slice 001, 2026-10-18): `roc test` of this file crashes the compiler with
#   Segmentation fault (SIGSEGV) in the Roc compiler. Work in progress: post-check monotype
# on nightly-2026-10-14-38a3029. `roc check` passes. Change `{ json : Bool }` to `{ kind : Str }` and it passes.
# Run: ROC=<pinned roc> $ROC test research/roc-test-segfault/repro.roc --no-cache
app [main!] {}

main! = |_args| Ok({})

Thing := { n : U64, text : Str }.{
	is_eq : _
}

parse : Str -> Try(Thing, { json : Bool })
parse = |s| if s == "" Err({ json: Bool.True }) else Ok(Thing.{ n: 1, text: s })

view = |s| match parse(s) {
	Ok(a) => Ok(a)
	Err(e) => Err({ json: e.json })
}

shape = |s| match view(s) {
	Ok(a) => Ok((a.n, a.text))
	Err(e) => Err(e)
}

expect {
	rows = [("x", Ok((1, "x")))]
	bad = rows.keep_if(|(s, want)| shape(s) != want)
	bad == []
}
