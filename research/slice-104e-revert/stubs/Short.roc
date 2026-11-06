## The answers of `GET /v1/packages` (Registry R-AP7, R-SN1, R-SN6, R-AP33, R-AP73; slice 104e). Pure.
## The encoders write the bytes of `worker/lib/Shorts.roc` (`matches_body`, `search_body`): no white space, the members in alphabetical order. An item of `matches`: `first_log_index`, `moved_from` (left out for `Err(None)`), `name`, `state`. An entry: `matches`, `short`. An item of `packages`: `first_log_index`, `name`, `state`. The lists are in the order given.
## The decoders follow R-AP51: `moved_from` is optional (missing or `null` is `Err(None)`), all other members are required, a `state` outside `active`, `missing`, `moved` is `BadJson`, an unknown member is ignored.
Short :: [].{

	State : [Active, Missing, Moved]

	## An item of a match list (R-SN1, R-AP33). `moved_from` is the old name of a replaced name.
	Item : { name : Str, first_log_index : U64, state : Short.State, moved_from : Try(Str, [None]) }

	## An entry: the `short` value as sent and its matches (R-SN6).
	Entry : { short : Str, matches : List(Short.Item) }

	## `?short=` answer: `{"matches":[..]}`.
	Matches : { matches : List(Short.Entry) }

	## An item of the search answer (R-SN6): no `moved_from`.
	Hit : { name : Str, first_log_index : U64, state : Short.State }

	## `?q=` answer: `{"packages":[..]}`. `packages` is a reserved word in Roc, so the field is `found`; the wire member is `packages`. The codec does the rename (for example by a parse into a `Dict(Str, List(..))`, which reads an unknown member only when its value is a list of hits).
	Packages : { found : List(Short.Hit) }

	encode_matches : Short.Matches -> Str
	encode_matches = |_m| crash "todo"

	decode_matches : Str -> Try(Short.Matches, [BadJson(Str)])
	decode_matches = |_text| crash "todo"

	encode_packages : Short.Packages -> Str
	encode_packages = |_p| crash "todo"

	decode_packages : Str -> Try(Short.Packages, [BadJson(Str)])
	decode_packages = |_text| crash "todo"
}
