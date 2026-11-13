import records.Closure as Wire
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
	ran : Try(Fail.Ran, [None]) ?? Err(None),

	## Slice 222 (Design Q542): `Ok(range)` for the refusal of `Consent.range_refused` (no installed compiler in the range of `[toolchain] roc`), so a command can read the range as data. Never in `--json`.
	refused_range : Try(Str, [None]) ?? Err(None),

	## Slice 225 (R-RG9, Design Q601): `Ok(cause)` for a read that gave no answer (or a 5xx) from the built-in default registry: the command can go on in `direct`. Never in `--json`.
	fallback : Try(Str, [None]) ?? Err(None),

	## Slice 225 (R-RG9, Design Q601 item 3): `Ok` for a failure of a run that fell back to `direct`. `Out` puts the note `registry-direct` in `error.details.notes` (`--json`), so each command has it from this one field.
	fell : Try({ registry : Str, cause : Str }, [None]) ?? Err(None),

	## Slice 209b (R-SM6, R-EP7, Design Q557): `Ok` for the drop of a tuple for a `bot` smoke fail of the build key (the release URL `id` of the platform, its `hash`, the compiler `nightly` and the build `target`). The command gives the smoke checks of that platform to the next search (`Matrix.smoke_checks`). Never in `--json`.
	smoke : Try({ id : Str, hash : Str, nightly : Str, target : Str }, [None]) ?? Err(None),

	## Slice 226: true for the one failure of the project search that found nothing (no `--file`, no member file, no workspace: `Project.find`). A bundle operand then takes the no-project path. Never in `--json`.
	no_project : Bool ?? Bool.False,
}.{
	is_eq : _

	## Slice 206e4 (R-SH4, R-AP30, Design Q533, Q541): what a run that sent a registry request (a closure query) gives to the end of the command, also when it fails: the share hooks (the index notes, the send of the queue) run after the output and after the failure text.
	## `origin` is the registry, `share` the key of `config.toml`, `offline`, `env` and `now` the facts of the run, `answers` the closure answers of the run (the held move has 2). `headers` are the kind and the target names of the hashes with no `artifacts` row (Design Q450, Q535; `ShareHook.headers_of`, `[]` from `ran_of`). `notes` is true for a command that prints the index notes, `noted` is true when it has printed them already.
	## It is never in `--json` and never changes the exit code. `Err(None)` is a run that sent no request.
	Ran : { origin : Str, share : Try(Bool, [Unset]), offline : Bool, env : List((Str, Str)), now : U64, answers : List(Wire.Answer), notes : Bool, noted : Bool, headers : List({ hash : Str, kind : [Package, Platform, App], names : List(Str) }), built : List(Fail.Built), audit : List(JsonDoc) }

	## Slice 218 (R-SM1, R-SM2, R-SM3, Design Q549): a build of ladder step 3 that the command ran or skipped (R-BS1), for the smoke build after the work. `key` is (platform hash, compiler id, build target). `url` is the URL of the platform of the built tuple (Q549), `text` the header text of the platform that the build read (Q535: no second read). `program` (an installed toolchain, or the `roc` on `PATH`, so the compiler of the key has a program), `env`, `slots` and `timeout` are those of the ladder run.
	Built : { key : { hash : Str, nightly : Str, target : Str }, url : Str, text : Str, program : Str, env : List((Str, Str)), slots : U64, timeout : U64 }

	new : Kind, Str -> Fail
	new = |kind, message| Fail.{ kind, message, details: Err(NoDetails), again: Err(None) }

	## A failure of the ladder that is about the tuple (slice 036b): `Fail.new` of kind `NoTuple`, and `again` with the hashes that the ladder blames.
	of_tuple : Str, List(Str) -> Fail
	of_tuple = |message, blamed| { ..Fail.new(NoTuple, message), again: Ok({ blamed, probes: 0 }) }

	## The ladder tells the command how many probes had started (slice 036b, R-P5): `probes` of `again`. A failure with no `again` stays as it is.
	with_probes : Fail, U64 -> Fail
	with_probes = |fail, probes| match fail.again {
		Ok(again) => { ..fail, again: Ok({ ..again, probes }) }
		Err(None) => fail
	}

	## Slice 209b: the failure of a tuple that carries the key of its smoke fail (`smoke`).
	with_smoke : Fail, { id : Str, hash : Str, nightly : Str, target : Str } -> Fail
	with_smoke = |fail, key| { ..fail, smoke: Ok(key) }

	## Slice 225: the failure of a run that fell back (`fell` `Ok`), else the failure as it is.
	with_fell : Fail, Try({ registry : Str, cause : Str }, [None]) -> Fail
	with_fell = |fail, fell| match fell {
		Ok(f) => { ..fail, fell: Ok(f) }
		Err(None) => fail
	}

	## Slice 231 (R-TF8, Design Q607, Q609): the hint for a value of a known key that a newer tln may know.
	newer_hint : Str
	newer_hint = "A newer tln may know this value. Update tln: tln tool update talon"

	## Slice 231 (R-TF8): the failure with the hint as a second line of the message. The kind stays.
	with_hint : Fail -> Fail
	with_hint = |fail| { ..fail, message: "${fail.message}\n${Fail.newer_hint}" }

	## The last stderr line of a failure: `tln: error[<kind>]: <message>` (R-E4).
	line : Fail -> Str
	line = |fail| "tln: error[${fail.kind.name()}]: ${fail.message}"
}
