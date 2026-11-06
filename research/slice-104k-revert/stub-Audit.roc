## The answer of `GET /v1/compat_hints?audit=<n>` (Registry R-AP40, R-AP73; Design Q575; slice 104k). Pure.
## STUB of slice 104k: the types are real, `encode` and `decode` crash.
Audit :: [].{

	## One pair with hints and no `bot` row. `hash` is base58, `nightly` the tag, `target` the name.
	Pair : { hash : Str, nightly : Str, target : Str, pass_count : U64, fail_count : U64, crash_count : U64 }

	## R-AP40: `{"pairs":[..]}`.
	Answer : { pairs : List(Audit.Pair) }

	## Members of the answer and of a pair in alphabetical order (`crash_count`, `fail_count`, `hash`, `nightly`, `pass_count`, `target`). The pairs stay in the order given. No white space.
	encode : Audit.Answer -> Str
	encode = |_answer| crash "todo: slice 104k"

	## R-AP51, R-AP73. `pairs` and all 6 members of a pair are required. A missing member or a wrong type is `BadJson`. An unknown member is ignored.
	decode : Str -> Try(Audit.Answer, [BadJson(Str)])
	decode = |_text| crash "todo: slice 104k"
}
