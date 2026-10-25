import lib.Fail
import lib.JsonDoc
import lib.Out

OutTest :: [].{}

# R-J1: one JSON document on one line. Text is escaped. Keys keep the order of the list.
expect {
	docs : List(JsonDoc)
	docs = [
		Null,
		Num(-5),
		Arr([]),
		Obj([]),
		Text("caf\u(e9) \"q\" back\\slash\nnew\ttab"),
		Obj([("a", Num(1)), ("b", Arr([Flag(Bool.True), Flag(Bool.False), Null])), ("c", Obj([("d", Text("x"))]))]),
	]
	rendered = docs.map(JsonDoc.render)
	dbg rendered
	rendered == [
		"null",
		"-5",
		"[]",
		"{}",
		"\"caf\u(e9) \\\"q\\\" back\\\\slash\\nnew\\ttab\"",
		"{\"a\":1,\"b\":[true,false,null],\"c\":{\"d\":\"x\"}}",
	]
}

# R-J1 R-J3 R-J4 R-J5 R-J6 R-OUT5 R-E5: the envelope has schema, command, ok, data, error in this order.
# ok: data is the object and error is null. Failure: data is null and error has kind, code, message
# and, only when the failure has them, details. `schema` is 1.
expect {
	ok = Out.json_ok({ command: "list", data: Obj([("count", Num(2))]) })
	usage = Out.json_fail({ command: "frobnicate", fail: Fail.new(Usage, "unknown command 'frobnicate'") })
	net = Out.json_fail({
		command: "update",
		fail: Fail.{ kind: Network, message: "registry answered 502", details: Ok(Obj([("status", Num(502))])), again: Err(None) },
	})
	Out.schema == 1
		and ok == "{\"schema\":1,\"command\":\"list\",\"ok\":true,\"data\":{\"count\":2},\"error\":null}\n"
			and usage == "{\"schema\":1,\"command\":\"frobnicate\",\"ok\":false,\"data\":null,\"error\":{\"kind\":\"usage\",\"code\":2,\"message\":\"unknown command 'frobnicate'\"}}\n"
				and net == "{\"schema\":1,\"command\":\"update\",\"ok\":false,\"data\":null,\"error\":{\"kind\":\"network\",\"code\":15,\"message\":\"registry answered 502\",\"details\":{\"status\":502}}}\n"
}

# R-J1 R-J2 R-E4 R-OUT4: a failure without --json prints the error line on stderr and nothing on stdout.
# With --json, stdout has the envelope and stderr has the same human line. `error.message` and the
# message of the line are the same string.
expect {
	fail = Fail.new(Usage, "unknown command 'frobnicate'")
	plain = Out.fail({ command: "frobnicate", json: Bool.False, fail })
	json = Out.fail({ command: "frobnicate", json: Bool.True, fail })
	plain == { stdout: "", stderr: "tln: error[usage]: unknown command 'frobnicate'\n" }
		and json == {
			stdout: Out.json_fail({ command: "frobnicate", fail }),
			stderr: "tln: error[usage]: unknown command 'frobnicate'\n",
		}
}

# R-FL4: --quiet keeps errors and answer lines (CLI 4, R-NM6) and hides other lines.
expect {
	shown = [
		Out.show(Bool.False, Info),
		Out.show(Bool.False, Answer),
		Out.show(Bool.False, Error),
		Out.show(Bool.True, Info),
		Out.show(Bool.True, Answer),
		Out.show(Bool.True, Error),
	]
	dbg shown
	shown == [Bool.True, Bool.True, Bool.True, Bool.False, Bool.True, Bool.True]
}
