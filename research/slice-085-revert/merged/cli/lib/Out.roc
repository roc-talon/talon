import Fail
import JsonDoc

## What a command prints (CLI 3): the `--json` envelope, the error text, `--quiet`.
Out :: [].{

	## The `schema` number of the envelope and of all command data (R-J3, R-OUT5, R-E5).
	schema : I64
	schema = 1

	## The envelope of a run that worked, with a newline at the end. The keys come in this order:
	## schema, command, ok, data, error. `error` is null (R-J1, R-J3, R-J4, R-J5).
	json_ok : { command : Str, data : JsonDoc } -> Str
	json_ok = |run| envelope(run.command, Bool.True, run.data, Null)

	## The envelope of a failure: `ok` false, `data` null, `error` with kind, code, message
	## and, when the failure has them, details (R-J3, R-J4, R-J5).
	json_fail : { command : Str, fail : Fail } -> Str
	json_fail = |run| envelope(run.command, Bool.False, Null, error_doc(run.fail))

	## The text of a failure. Without `--json`: stderr has the error line, stdout is empty.
	## With `--json`: stdout has the envelope, stderr has the same human text (R-J1, R-J2, R-E4, R-OUT4).
	## The message of the human text and of `error.message` is the same string.
	fail : { command : Str, json : Bool, fail : Fail } -> { stdout : Str, stderr : Str }
	fail = |run| {
		stdout: if run.json json_fail({ command: run.command, fail: run.fail }) else "",
		stderr: "${run.fail.line()}\n",
	}

	## Does `--quiet` hide a line? Errors and answer lines stay, other lines go (R-FL4).
	show : Bool, [Info, Answer, Error] -> Bool
	show = |quiet, line| match line {
		Info => !quiet
		Answer | Error => Bool.True
	}
}

envelope : Str, Bool, JsonDoc, JsonDoc -> Str
envelope = |command, ok, data, error| {
	doc = JsonDoc.Obj([
		("schema", Num(Out.schema)),
		("command", Text(command)),
		("ok", Flag(ok)),
		("data", data),
		("error", error),
	])
	"${doc.render()}\n"
}

error_doc : Fail -> JsonDoc
error_doc = |fail| {
	base = [
		("kind", JsonDoc.Text(fail.kind.name())),
		("code", Num(fail.kind.code().to_i64())),
		("message", Text(fail.message)),
	]
	match fail.details {
		Ok(details) => Obj(base.append(("details", details)))
		Err(NoDetails) => Obj(base)
	}
}
