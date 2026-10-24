import Kind
import JsonDoc

## A failure that Talon finds: its kind, a message for a person, and optional details for `--json` (R-J5).
Fail := {
	kind : Kind,
	message : Str,
	details : Try(JsonDoc, [NoDetails]),
}.{
	is_eq : _

	new : Kind, Str -> Fail
	new = |kind, message| { kind, message, details: Err(NoDetails) }

	## The last stderr line of a failure: `tln: error[<kind>]: <message>` (R-E4).
	line : Fail -> Str
	line = |fail| "tln: error[${fail.kind.name()}]: ${fail.message}"
}
