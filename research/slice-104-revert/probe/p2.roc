P : { group : Str, series ?: Str }
N : { name : Str, state_at : Try(U64, [Missing]), id : I64 }
Q : { name : Str, state_at : [Null, Some(U64)] }

main! = |_args| Ok({})

expect {
	p : P
	p = { group: "g" }
	dbg Json.to_str(p)
	q : P
	q = { group: "g", series: "4" }
	dbg Json.to_str(q)
	n : N
	n = { name: "a", state_at: Err(Missing), id: -2687166099708853831 }
	dbg Json.to_str(n)
	qq : Q
	qq = { name: "a", state_at: Null }
	dbg Json.to_str(qq)
	qs : Q
	qs = { name: "a", state_at: Some(5) }
	dbg Json.to_str(qs)
	r : Try(P, _)
	r = Json.parse("{\"group\":\"g\",\"zzz\":1}")
	dbg r
	r2 : Try(N, _)
	r2 = Json.parse("{\"name\":\"a\",\"state_at\":null,\"id\":-2687166099708853831}")
	dbg r2
	r3 : Try(N, _)
	r3 = Json.parse("{\"name\":\"a\",\"id\":-2687166099708853831}")
	dbg r3
	d = Crypto.SHA256.hash([2].concat("github.com/roc-lang/unicode/releases/download/{v}/".to_utf8()))
	dbg d.to_hex()
	Bool.True
}
