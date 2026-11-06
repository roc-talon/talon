Nul := Try(Str, [None]).{
	parser_for : encoding -> (state -> Try({ value : Nul, rest : state }, err))
		where [
			encoding.parse_str : encoding, state -> Try({ value : Str, rest : state }, err),
			encoding.parse_null : encoding, state -> Try(state, err),
		]
	parser_for = |encoding| {
		Encoding : encoding

		|state| match Encoding.parse_null(encoding, state) {
			Ok(rest) => Ok({ value: Nul.(Err(None)), rest })
			Err(_) => {
				p = Encoding.parse_str(encoding, state)?
				Ok({ value: Nul.(Ok(p.value)), rest: p.rest })
			}
		}
	}

	encoder_for : encoding -> (Nul, state -> Try(state, err))
		where [
			encoding.encode_str : Str, state -> Try(state, err),
			encoding.encode_null : state -> Try(state, err),
		]
	encoder_for = |encoding| {
		Encoding : encoding

		|n, state| match Nul.unwrap(n) {
			Ok(s) => Encoding.encode_str(s, state)
			Err(_) => Encoding.encode_null(state)
		}
	}

	unwrap : Nul -> Try(Str, [None])
	unwrap = |Nul.(t)| t
}

R : { a : Nul, b : Str }

main! = |_args| Ok({})

expect {
	r : Try(R, _)
	r = Json.parse("{\"a\":null,\"b\":\"x\",\"z\":1}")
	dbg r
	r2 : Try(R, _)
	r2 = Json.parse("{\"a\":\"q\",\"b\":\"x\"}")
	dbg r2
	dbg Json.to_str({ a: Nul.(Err(None)), b: "y" })
	Bool.True
}
