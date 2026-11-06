J : { kty : Try(Str, [Missing]), kid : Try(Str, [Missing]) }

p : Str -> Try({ keys : List(J) }, _)
p = |t| Json.parse(t)

expect p("{\"keys\":[{\"kty\":\"RSA\",\"x5c\":[\"MII\",{\"a\":[1,2]}],\"kid\":\"k\"}],\"other\":{\"z\":null}}") == Ok({ keys: [{ kty: Ok("RSA"), kid: Ok("k") }] })
expect p("{}").is_err()
expect p("[]").is_err()
expect p("{\"keys\":1}").is_err()

main! = |_args| Ok({})
