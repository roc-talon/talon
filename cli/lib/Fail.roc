import Kind
import JsonDoc

## A failure that Talon finds: its kind, a message for a person, and optional details for `--json` (R-J5).
## Slice 036b (R-AL5, R-AL6, R-PH13): `again` is `Ok` for a failure of the ladder that is about the tuple (kind `NoTuple`): the oracle loop can try another tuple. `blamed` are the hashes of the releases that the ladder blames (`[]`: the whole tuple),
## `probes` is the number of probes that the command had started when the ladder failed (the ladder fills it). `Err(None)` is any other failure: it ends the command. It is never in `--json`.
Fail := {
	kind : Kind,
	message : Str,
	details : Try(JsonDoc, [NoDetails]),
	again : Try({ blamed : List(Str), probes : U64 }, [None]),
}.{
	is_eq : _

	new : Kind, Str -> Fail
	new = |kind, message| { kind, message, details: Err(NoDetails), again: Err(None) }

	## A failure of the ladder that is about the tuple (slice 036b): `Fail.new` of kind `NoTuple`, and `again` with the hashes that the ladder blames.
	of_tuple : Str, List(Str) -> Fail
	of_tuple = |message, blamed| { ..Fail.new(NoTuple, message), again: Ok({ blamed, probes: 0 }) }

	## The ladder tells the command how many probes had started (slice 036b, R-P5): `probes` of `again`. A failure with no `again` stays as it is.
	with_probes : Fail, U64 -> Fail
	with_probes = |fail, probes| match fail.again {
		Ok(again) => { ..fail, again: Ok({ ..again, probes }) }
		Err(None) => fail
	}

	## The last stderr line of a failure: `tln: error[<kind>]: <message>` (R-E4).
	line : Fail -> Str
	line = |fail| "tln: error[${fail.kind.name()}]: ${fail.message}"
}
