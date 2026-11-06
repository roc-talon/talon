Nul(a) := Try(a, [None]).{
	parser_for : encoding -> (state -> Try({ value : Nul(a), rest : state }, err))
		where [
			encoding.parse_null : encoding, state -> Try(state, err),
			a.parser_for : encoding -> (state -> Try({ value : a, rest : state }, err)),
		]
	parser_for = |encoding| {
		Encoding : encoding
		Inner : a

		inner = Inner.parser_for(encoding)
		|state| match Encoding.parse_null(encoding, state) {
			Ok(rest) => Ok({ value: Nul.(Err(None)), rest })
			Err(_) => {
				p = inner(state)?
				Ok({ value: Nul.(Ok(p.value)), rest: p.rest })
			}
		}
	}

	encoder_for : encoding -> (Nul(a), state -> Try(state, err))
		where [
			encoding.encode_null : state -> Try(state, err),
			a.encoder_for : encoding -> (a, state -> Try(state, err)),
		]
	encoder_for = |encoding| {
		Encoding : encoding
		Inner : a

		inner = Inner.encoder_for(encoding)
		|Nul.(value), state| match value {
			Ok(x) => inner(x, state)
			Err(None) => Encoding.encode_null(state)
		}
	}
}

R : { a : Nul(Str), b : Nul({ x : U64 }), c : Nul(U64) }

main! = |_args| Ok({})

expect {
	r : Try(R, _)
	r = Json.parse("{\"a\":null,\"b\":{\"x\":3},\"c\":4,\"z\":1}")
	dbg r
	v : R
	v = { a: Nul.(Err(None)), b: Nul.(Ok({ x: 1 })), c: Nul.(Ok(7)) }
	dbg Json.to_str(v)
	Bool.True
}
