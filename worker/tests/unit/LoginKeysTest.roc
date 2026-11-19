import lib.Login
import lib.Problem

LoginKeysTest :: [].{}

# W0 tests of the planned change of TOKEN_KEY (docs/slices/258-token-key-change.md, Design Q637): `Login.old_keys`, `Login.verify_key`, `Login.token_kid`, `Login.no_key`.
# The public keys are throwaway test keys made with node (crypto.generateKeyPairSync) for this file, and the key of RFC 8037 A.1. A real key is never used.
# The token texts are the ones of LoginTest.roc (made by research/slice-117-revert/gen/vectors.mjs), and one more with the `kid` key-0 (the signature is 64 zero bytes: no crypto is checked here).

aud : Str
aud = "https://registry.example"

# a JWK Set text of the entries (each entry is the text of one JWK)
set_of : List(Str) -> Str
set_of = |entries| "{\"keys\":[${Str.join_with(entries, ",")}]}"

# the public JWK text of the key with this x and kid
pub : Str, Str -> Str
pub = |kid, x| "{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"kid\":\"${kid}\",\"x\":\"${x}\"}"

x_a : Str
x_a = "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo"

x_b : Str
x_b = "JNtkIvk4__GDrlWNNKYABzLApEVm0EpEDyx_DvAwJaE"

x_c : Str
x_c = "ADGaZkqP7V5HzwzwuIao-7v0lhXj72UYFFfwF-AnGaU"

x_d : Str
x_d = "avqTM38K-RMqb8EHgmBMUs_F0y7f7NDxL1HXqla0Ifs"

x_e : Str
x_e = "L1qqUJRlgkfDFuDMJr60tmbd4f08ok7VZB7uVxhjFyo"

x_f : Str
x_f = "JmpKuXcFD87TIjVssze_5GqL9Y8zbfBYwUuePs0fXrI"

# the `kid` list of a good result, or the marker of a refusal
kids : Str, Str -> Str
kids = |text, current| match Login.old_keys(text, current) {
	Ok(list) => Str.join_with(list.map(|k| k.kid), ",")
	Err(BadOldKeys(_)) => "BAD"
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT9, R-WH14 (row TOKEN_OLD_KEYS, Q258-1, Q258-3, Q258-4, Q258-6): `old_keys(text, current_kid)`: the JWK Set of the old public keys. At most 4 keys. A fault is `Err(BadOldKeys(why))`,
# and the route answers 500 `internal`. A bad entry is never left out. `current_kid` is the `kid` of `TOKEN_KEY`: no old key has it.

expect {
	# R-WH14: the good case, the public key of RFC 8037 A.1 (the `x` is in `public_json`, no `d`)
	one = match Login.old_keys(set_of([pub("key-0", x_a)]), "key-1") {
		Ok([k]) => k.kid == "key-0" and k.public_json.contains("\"x\":\"${x_a}\"") and k.public_json.contains("Ed25519") and !k.public_json.contains("\"d\"")
		_ => Bool.False
	}
	# R-WH14: 4 keys are good, in the order of the text
	four = kids(set_of([pub("key-0", x_a), pub("key-1b", x_b), pub("key-2", x_c), pub("key-3", x_d)]), "key-1") == "key-0,key-1b,key-2,key-3"
	# Q258-3: 5 keys are a fault
	five = kids(set_of([pub("key-0", x_a), pub("key-1b", x_b), pub("key-2", x_c), pub("key-3", x_d), pub("key-4", x_e)]), "key-1") == "BAD"
	# Q258-5 (a missing set): an empty list, an empty text and a missing text are an empty set
	empty_list = Login.old_keys("{\"keys\":[]}", "key-1") == Ok([])
	empty_text = Login.old_keys("", "key-1") == Ok([])
	one and four and five and empty_list and empty_text
}

expect {
	# R-WH14, Q258-4: a text that is not a JWK Set
	not_json = kids("not json", "key-1") == "BAD"
	array = kids("[]", "key-1") == "BAD"
	no_keys = kids("{}", "key-1") == "BAD"
	keys_text = kids("{\"keys\":\"x\"}", "key-1") == "BAD"
	keys_object = kids("{\"keys\":{}}", "key-1") == "BAD"
	single_jwk = kids(pub("key-0", x_a), "key-1") == "BAD"
	# R-WH14, Q258-4: an entry that is not an Ed25519 key of type OKP, with a `kid`
	rsa = kids(set_of(["{\"kty\":\"RSA\",\"kid\":\"key-0\",\"n\":\"AQAB\",\"e\":\"AQAB\"}"]), "key-1") == "BAD"
	ec = kids(set_of(["{\"kty\":\"EC\",\"crv\":\"P-256\",\"kid\":\"key-0\",\"x\":\"f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU\",\"y\":\"x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0\"}"]), "key-1") == "BAD"
	oct = kids(set_of(["{\"kty\":\"oct\",\"kid\":\"key-0\",\"k\":\"AAAA\"}"]), "key-1") == "BAD"
	ed448 = kids(set_of(["{\"kty\":\"OKP\",\"crv\":\"Ed448\",\"kid\":\"key-0\",\"x\":\"${x_a}\"}"]), "key-1") == "BAD"
	no_x = kids(set_of(["{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"kid\":\"key-0\"}"]), "key-1") == "BAD"
	no_kid = kids(set_of(["{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"x\":\"${x_a}\"}"]), "key-1") == "BAD"
	empty_kid = kids(set_of([pub("", x_a)]), "key-1") == "BAD"
	# Q258-4: a bad entry is never left out: a good key and a bad one is a fault, in each order
	mixed1 = kids(set_of([pub("key-0", x_a), "{\"kty\":\"RSA\",\"kid\":\"key-2\",\"n\":\"AQAB\",\"e\":\"AQAB\"}"]), "key-1") == "BAD"
	mixed2 = kids(set_of(["{\"kty\":\"RSA\",\"kid\":\"key-2\",\"n\":\"AQAB\",\"e\":\"AQAB\"}", pub("key-0", x_a)]), "key-1") == "BAD"
	mixed3 = kids(set_of([pub("key-0", x_a), pub("", x_b)]), "key-1") == "BAD"
	not_json and array and no_keys and keys_text and keys_object and single_jwk and rsa and ec and oct and ed448 and no_x and no_kid and empty_kid and mixed1 and mixed2 and mixed3
}

expect {
	# Q258-6: two keys with one `kid` (the same key or two keys) are a fault
	dup_same = kids(set_of([pub("key-0", x_a), pub("key-0", x_a)]), "key-1") == "BAD"
	dup_other = kids(set_of([pub("key-0", x_a), pub("key-2", x_b), pub("key-0", x_c)]), "key-1") == "BAD"
	# Q258-6: a `kid` equal to the `kid` of TOKEN_KEY is a fault, also when it is the last of 4
	same_as_current = kids(set_of([pub("key-1", x_a)]), "key-1") == "BAD"
	same_last = kids(set_of([pub("key-0", x_a), pub("key-2", x_b), pub("key-3", x_c), pub("key-1", x_d)]), "key-1") == "BAD"
	# the same set is good for another current key
	other_current = kids(set_of([pub("key-1", x_a)]), "key-9") == "key-1"
	# a `kid` is compared as text: a different case is another `kid`
	case_kids = kids(set_of([pub("key-a", x_a), pub("KEY-A", x_b)]), "Key-A") == "key-a,KEY-A"
	# Q258-1: a member `d` is ignored (not refused), and the public JWK has no `d`
	with_d = match Login.old_keys(set_of(["{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"kid\":\"key-0\",\"x\":\"${x_a}\",\"d\":\"nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A\"}"]), "key-1") {
		Ok([k]) => k.kid == "key-0" and !k.public_json.contains("nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A") and !k.public_json.contains("\"d\"")
		_ => Bool.False
	}
	# other members of a JWK (`use`, `alg`, `key_ops`) are ignored
	extra = kids(set_of(["{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"kid\":\"key-0\",\"use\":\"sig\",\"alg\":\"EdDSA\",\"x\":\"${x_a}\"}"]), "key-1") == "key-0"
	dup_same and dup_other and same_as_current and same_last and other_current and case_kids and with_d and extra
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT9 (Q258-5): `verify_key(current, old, kid)`: the key to check the signature with. The current key wins. A `kid` in no set is `Err(NoKey)`: 401.

key_of : Str -> Login.SigningKey
key_of = |kid| { kid, public_json: "{\"kty\":\"OKP\",\"crv\":\"Ed25519\",\"kid\":\"${kid}\",\"x\":\"${x_a}\"}" }

picked : Str, List(Str), Str -> Str
picked = |current, old, kid| match Login.verify_key(key_of(current), old.map(|k| { kid: k, public_json: "old ${k}" }), kid) {
	Ok(k) => if (k.public_json.starts_with("old ")) "old ${k.kid}" else "current ${k.kid}"
	Err(NoKey) => "none"
}

expect {
	current = picked("key-1", ["key-0", "key-00"], "key-1") == "current key-1"
	old_first = picked("key-1", ["key-0", "key-00"], "key-0") == "old key-0"
	old_second = picked("key-1", ["key-0", "key-00"], "key-00") == "old key-00"
	by_kid_not_position = picked("key-1", ["key-0", "key-00", "key-3"], "key-3") == "old key-3"
	none = picked("key-1", ["key-0", "key-00"], "key-9") == "none"
	no_old = picked("key-1", [], "key-0") == "none" and picked("key-1", [], "key-1") == "current key-1"
	case_differs = picked("key-1", ["key-0"], "KEY-0") == "none" and picked("key-1", ["key-0"], "Key-1") == "none"
	prefix = picked("key-1", ["key-0"], "key-") == "none" and picked("key-1", ["key-0"], "key-00") == "none"
	empty_kid = picked("key-1", ["key-0"], "") == "none"
	# the current key wins when it is also in the list (`old_keys` refuses such a set, but this function is pure)
	current_wins = picked("key-1", ["key-1", "key-0"], "key-1") == "current key-1" and picked("key-1", ["key-0", "key-1"], "key-1") == "current key-1"
	current and old_first and old_second and by_kid_not_position and none and no_old and case_differs and prefix and empty_kid and current_wins
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT9, R-CT16 row 3: `token_kid(text)`: the `kid` of the header, with the form checks of `decode` (the same 401 texts), before any set is read. `decode(text, kid)` is not changed.

unauth : Str -> Try(Str, Str)
unauth = |text| Err(Problem.new(Unauthenticated, text).to_json())

kid_of : Str -> Try(Str, Str)
kid_of = |text| match Login.token_kid(text) {
	Ok(kid) => Ok(kid)
	Err(p) => Err(p.to_json())
}

expect {
	good = kid_of("eyJhbGciOiJFZERTQSIsImtpZCI6ImtleS0xIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJhdWQiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJzdWIiOiI0MjQyIiwiaWF0IjoxNzY3MjI1NjAwLCJleHAiOjE3Njk4MTc2MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA") == Ok("key-1")
	other = kid_of("eyJhbGciOiJFZERTQSIsImtpZCI6ImtleS0yIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJhdWQiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJzdWIiOiI0MjQyIiwiaWF0IjoxNzY3MjI1NjAwLCJleHAiOjE3Njk4MTc2MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA") == Ok("key-2")
	old = kid_of("eyJhbGciOiJFZERTQSIsImtpZCI6ImtleS0wIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJhdWQiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJzdWIiOiI0MjQyIiwiaWF0IjoxNzY3MjI1NjAwLCJleHAiOjE3Njk4MTc2MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA") == Ok("key-0")
	missing = kid_of("eyJhbGciOiJFZERTQSJ9.eyJpc3MiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJhdWQiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJzdWIiOiI0MjQyIiwiaWF0IjoxNzY3MjI1NjAwLCJleHAiOjE3Njk4MTc2MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA") == unauth("the token kid is missing")
	none_alg = kid_of("eyJhbGciOiJub25lIiwia2lkIjoia2V5LTEifQ.eyJpc3MiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJhdWQiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJzdWIiOiI0MjQyIiwiaWF0IjoxNzY3MjI1NjAwLCJleHAiOjE3Njk4MTc2MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA") == unauth("the token alg is \"none\", expected \"EdDSA\"")
	rs256 = kid_of("eyJhbGciOiJSUzI1NiIsImtpZCI6ImtpZC0xIn0.eyJpc3MiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJhdWQiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJzdWIiOiI0MjQyIiwiaWF0IjoxNzY3MjI1NjAwLCJleHAiOjE3Njk4MTc2MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA") == unauth("the token alg is \"RS256\", expected \"EdDSA\"")
	no_alg = kid_of("eyJraWQiOiJrZXktMSJ9.eyJpc3MiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJhdWQiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJzdWIiOiI0MjQyIiwiaWF0IjoxNzY3MjI1NjAwLCJleHAiOjE3Njk4MTc2MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA") == unauth("the token alg is missing")
	garbage = kid_of("garbage") == unauth("the token is not a valid JWT") and kid_of("") == unauth("the token is not a valid JWT") and kid_of("a.b") == unauth("the token is not a valid JWT")
	good and other and old and missing and none_alg and rs256 and no_alg and garbage
}

# R-CT9, R-CT16 row 3: the 401 of a `kid` that is in no set. The text is the old text, the same as the one of `decode` for another `kid`.
expect {
	text = Login.no_key("key-2") == Problem.new(Unauthenticated, "the token kid \"key-2\" is not the key of this registry")
	same_as_decode = match Login.decode("eyJhbGciOiJFZERTQSIsImtpZCI6ImtleS0yIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJhdWQiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJzdWIiOiI0MjQyIiwiaWF0IjoxNzY3MjI1NjAwLCJleHAiOjE3Njk4MTc2MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "key-1") {
		Err(p) => p == Login.no_key("key-2")
		Ok(_) => Bool.False
	}
	escaped = Login.no_key("a\"b").to_json().contains("the token kid")
	text and same_as_decode and escaped
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# R-CT9, Q301, Q258-7: the last good moment of an old token. A token with iat = T has exp = T + 30 days. It is good at T + 30 days + 59.999 s and refused at T + 30 days + 60 s.
# The token has the `kid` key-0 and is decoded with that `kid` (the one that `verify_key` gave). T = 1767225600 s.

old_token : Str
old_token = "eyJhbGciOiJFZERTQSIsImtpZCI6ImtleS0wIiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJhdWQiOiJodHRwczovL3JlZ2lzdHJ5LmV4YW1wbGUiLCJzdWIiOiI0MjQyIiwiaWF0IjoxNzY3MjI1NjAwLCJleHAiOjE3Njk4MTc2MDB9.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

late : Str, U64 -> Try(Login.Verified, Problem)
late = |text, now_ms| match Login.decode(text, "key-0") {
	Ok(d) => Login.check(d, { audience: aud, now_ms })
	Err(p) => Err(p)
}

expect {
	good = late(old_token, 1_769_817_659_999) == Ok({ account: 4242, iat_ms: 1_767_225_600_000 })
	at_exp = late(old_token, 1_769_817_600_000) == Ok({ account: 4242, iat_ms: 1_767_225_600_000 })
	edge = late(old_token, 1_769_817_660_000) == Err(Problem.new(Unauthenticated, "token claim exp is 1769817600: the token expired (now is 1769817660, leeway 60 s)"))
	after = late(old_token, 1_769_817_700_000) == Err(Problem.new(Unauthenticated, "token claim exp is 1769817600: the token expired (now is 1769817700, leeway 60 s)"))
	good and at_exp and edge and after
}
