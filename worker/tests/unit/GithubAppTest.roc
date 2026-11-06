import lib.GithubApp

GithubAppTest :: [].{}

# W0 tests of worker/lib/GithubApp.roc (slice 119a, R-PU25 token part, R-CT12, R-WH14).
# The vectors come from python (base64, calendar) and openssl, not from the Roc code. The signing input is the one of research/github-app-check/check.sh (make_jwt).

# ---- R-PU25: the signing input of the JWT of the App ----
# The header is the same for all ids. The payload is `{"iat":s-60,"exp":s+540,"iss":id}` for s = 1767225600 (2026-01-01T00:00:00Z). The ids of 1, 2, 6 and 7 digits give the 4 base64 padding
# classes of the payload (the text has no `=`). The ms of `now_ms` are cut: 1767225600999 gives the same text as 1767225600000.
head_b64 = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9"

jwt_rows : List((Str, U64, Str))
jwt_rows = [
	("1", 1767225600000, "${head_b64}.eyJpYXQiOjE3NjcyMjU1NDAsImV4cCI6MTc2NzIyNjE0MCwiaXNzIjoxfQ"),
	("12", 1767225600000, "${head_b64}.eyJpYXQiOjE3NjcyMjU1NDAsImV4cCI6MTc2NzIyNjE0MCwiaXNzIjoxMn0"),
	("123456", 1767225600000, "${head_b64}.eyJpYXQiOjE3NjcyMjU1NDAsImV4cCI6MTc2NzIyNjE0MCwiaXNzIjoxMjM0NTZ9"),
	("5572595", 1767225600000, "${head_b64}.eyJpYXQiOjE3NjcyMjU1NDAsImV4cCI6MTc2NzIyNjE0MCwiaXNzIjo1NTcyNTk1fQ"),
	("5572595", 1767225600999, "${head_b64}.eyJpYXQiOjE3NjcyMjU1NDAsImV4cCI6MTc2NzIyNjE0MCwiaXNzIjo1NTcyNTk1fQ"),
	("5572595", 1792594866000, "${head_b64}.eyJpYXQiOjE3OTI1OTQ4MDYsImV4cCI6MTc5MjU5NTQwNiwiaXNzIjo1NTcyNTk1fQ"),
]

# R-PU25: the exact signing input (iat now-60, exp now+540, iss the id as a number, this member order).
expect jwt_rows.map(|(id, now, _)| GithubApp.jwt_input({ app_id: id, now_ms: now })) == jwt_rows.map(|(_, _, want)| Ok(want))

# R-WH14, R-PU25: an id that is not digits is a setting fault, not a JWT. The empty text, a sign, a space, a letter and a client id of the form `Iv23...` are refused.
expect ["", "-1", "+1", " 1", "1 ", "12a", "Iv23li2sxWgMaAvjaUbQ", "1.5"].map(|id| GithubApp.jwt_input({ app_id: id, now_ms: 1767225600000 })) == List.repeat(Err(BadAppId), 8)

# R-PU25: the JWT text adds the signature as base64url with no padding. The bytes [251, 255, 0, 1] give `-_8AAQ` (the standard alphabet would give `+/8AAQ`); 0, 1, 2 bytes of padding.
expect GithubApp.jwt_text({ input: "a.b", signature: [251, 255, 0, 1] }) == "a.b.-_8AAQ"
expect GithubApp.jwt_text({ input: "a.b", signature: [1, 2] }) == "a.b.AQI"
expect GithubApp.jwt_text({ input: "a.b", signature: [1, 2, 3] }) == "a.b.AQID"
expect GithubApp.jwt_text({ input: "a.b", signature: [1, 2, 3, 4, 5] }) == "a.b.AQIDBAU"

# ---- R-PU25: the token request and its answer ----

# R-PU25: `POST /app/installations/<id>/access_tokens` on the REST API.
expect GithubApp.token_url("177657685") == "https://api.github.com/app/installations/177657685/access_tokens"

# R-PU25: the answer of GitHub (the members of the real answer; `expires_at` 2026-11-02T01:00:00Z is 1793581200000 ms). Members that the Worker does not read are ignored.
real_answer = "{\"token\":\"ghs_16C7e42F292c6912E7710c838347Ae178B4a\",\"expires_at\":\"2026-11-02T01:00:00Z\",\"permissions\":{\"contents\":\"read\",\"metadata\":\"read\"},\"repository_selection\":\"selected\"}"

expect GithubApp.parse_token(real_answer) == Ok({ token: "ghs_16C7e42F292c6912E7710c838347Ae178B4a", expires_ms: 1793581200000 })

# The order of the members does not matter. A member that is not in the table of the answer is ignored.
expect GithubApp.parse_token("{\"expires_at\":\"2026-11-02T01:00:00Z\",\"x\":[1,2],\"token\":\"t\"}") == Ok({ token: "t", expires_ms: 1793581200000 })

# R-PU25: an answer that is not a token: not JSON, not an object, a missing member, a member of the wrong type, a time that is not in the `Z` form.
bad_answers : List(Str)
bad_answers = [
	"",
	"not json",
	"[]",
	"{}",
	"{\"token\":\"t\"}",
	"{\"expires_at\":\"2026-11-02T01:00:00Z\"}",
	"{\"token\":1,\"expires_at\":\"2026-11-02T01:00:00Z\"}",
	"{\"token\":null,\"expires_at\":\"2026-11-02T01:00:00Z\"}",
	"{\"token\":\"t\",\"expires_at\":1793581200}",
	"{\"token\":\"t\",\"expires_at\":\"2026-11-02T01:00:00+00:00\"}",
	"{\"token\":\"t\",\"expires_at\":\"2026-11-02 01:00:00\"}",
	"{\"token\":\"t\",\"expires_at\":\"2026-02-30T01:00:00Z\"}",
]

expect bad_answers.map(GithubApp.parse_token) == List.repeat(Err(BadAnswer), bad_answers.len())

# ---- R-PU25: the token is kept until 5 min before its end ----
# end = 1793581200000. The edge is end - 300000 = 1793580900000. A time 1 s before the edge keeps the token, 1 s after the edge drops it. The exact edge is not tested.
token_end : GithubApp.Token
token_end = { token: "t", expires_ms: 1793581200000 }

usable_rows : List((U64, Bool))
usable_rows = [
	(1793577600000, Bool.True), # just issued: 1 h left
	(1793580899000, Bool.True), # 1 s before the edge: 5 min 1 s left
	(1793580901000, Bool.False), # 1 s after the edge: 4 min 59 s left
	(1793581199999, Bool.False), # 1 ms before the end
	(1793581200000, Bool.False), # at the end
	(1793581200001, Bool.False), # after the end
	(0, Bool.True), # a clock at 0 is not a crash
]

expect usable_rows.map(|(now, _)| GithubApp.usable(token_end, now)) == usable_rows.map(|(_, want)| want)

# A token that ends less than 5 min after 0 is never usable, and the sum is not an underflow or an overflow.
expect GithubApp.usable({ token: "t", expires_ms: 100000 }, 0) == Bool.False
expect GithubApp.usable({ token: "t", expires_ms: 300001 }, 0) == Bool.True
expect GithubApp.usable({ token: "t", expires_ms: 1793581200000 }, 18446744073709551615) == Bool.False

# ---- Q3 (proposal): which reads get the token, and the headers ----
# Only the REST API host, as the exact prefix. The other GitHub hosts and the look-alike hosts do not get the token.
uses_rows : List((Str, Bool))
uses_rows = [
	("https://api.github.com/repos/roc-talon/talon/tags?per_page=100", Bool.True),
	("https://api.github.com/app/installations/1/access_tokens", Bool.True),
	("https://api.github.com/repositories/42", Bool.True),
	("https://raw.githubusercontent.com/acme/app/1.0.0/.roc-version", Bool.False),
	("https://github.com/acme/app/releases/download/1.0.0/x.tar.zst", Bool.False),
	("https://api.github.com.evil.example/repos/a/b", Bool.False),
	("https://api.github.com@evil.example/repos/a/b", Bool.False),
	("http://api.github.com/repos/a/b", Bool.False),
	("https://API.GITHUB.COM/repos/a/b", Bool.False),
	("https://evil.example/https://api.github.com/", Bool.False),
	("", Bool.False),
]

expect uses_rows.map(|(url, _)| GithubApp.uses_token(url)) == uses_rows.map(|(_, want)| want)

# R-PU25, Q3: the headers of an API read are the user agent, the accept and `Authorization: Bearer <token>`, in this order (the form that the real check used). A read of another host has
# the user agent only, and the token text is in no header (it is not sent to another host).
expect GithubApp.read_headers({ url: "https://api.github.com/repos/o/r", token: "ghs_x" }) == [("user-agent", "talon-registry"), ("accept", "application/vnd.github+json"), ("authorization", "Bearer ghs_x")]
expect GithubApp.read_headers({ url: "https://raw.githubusercontent.com/o/r/1/.roc-version", token: "ghs_x" }) == [("user-agent", "talon-registry")]
expect GithubApp.read_headers({ url: "https://api.github.com.evil.example/", token: "ghs_x" }) == [("user-agent", "talon-registry")]

# ---- Q4 (proposal): the answer of a route that has no token ----
expect GithubApp.failure_class(NoSetting("GITHUB_APP_KEY")) == Fault("the setting GITHUB_APP_KEY is not set")
expect GithubApp.failure_class(BadSetting("GITHUB_APP_ID")) == Fault("the setting GITHUB_APP_ID is not valid")
expect GithubApp.failure_class(SignFailed) == Fault("the JWT of the App cannot be signed")
expect GithubApp.failure_class(TokenStatus(401)) == Upstream("the GitHub installation token request failed with status 401")
expect GithubApp.failure_class(TokenStatus(403)) == Upstream("the GitHub installation token request failed with status 403")
expect GithubApp.failure_class(TokenNoAnswer) == Upstream("the GitHub installation token request failed: no answer")
expect GithubApp.failure_class(TokenBad) == Upstream("the GitHub installation token answer is not valid")

# ---- Q2 (proposal): the secret GITHUB_APP_KEY as a PKCS#8 PEM ----
# The key is a throwaway 1024-bit key made for this test (openssl genpkey). The DER has 634 bytes, starts with 30 82 02 76 02 01 00 30, ends with 86 b5 02 11 28 d7 6b 1d,
# and the sum of byte * index is 25327050 (python, on the base64 decode of the body of the PEM).
pem_pkcs8 = "-----BEGIN PRIVATE KEY-----\nMIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBAL0v5EG8bBjNftnU\nsWoq3X0JQrstcpJ5142azbMdf++/M6WupBeCyfWP2ign4GkdiDN6cOII2bMPzO6+\nC7Ayla00kjZotexhFqtIhNgXCe/Ht3RX6uKBoO4YdMRpsCUiTh7XN4EOEd/qRPgm\nEJn+dLC7pZNqE+hgc/yR9XcJYErTAgMBAAECgYA1yc0C55hwQNTFCBTdE4zfhOeF\nIjnF7YBckVvUhhmex2TewVWEHbpf5+NlsVi7ahsUT8aSbWO/5kkkw8G8+dTV6bAs\nH73meunrtZguR3bPRisX2EJilDhVVOXFGSdts33l2WKt5J84x3ZCiywsNOplmvkd\na+8pBYTgpFejWY6eoQJBAOWv/BWM610zonjY7IjBEMazQvuMOJeq8G0M8u5hx0n9\nXmkWj9cRLQcHWX26AYDNSMmRL9szIw34FM7LIdSkM2MCQQDS3Chh/37Fen/ByGqs\nrJtIz8q2H7ovtyCJP7NFP9isXqMe8XTKLIxho7p5JgJV23hNw6cZQ3yQhGvcRspp\nSX3RAkBcg3bYw0rl3m9Zl54mMwVr0zZulXsR8+MlOWr8A1w+/BOz5keHi76ELzyn\nfG0wkP75WUZaVw2OidbvuDfnK0AbAkEAkFVa3xnAcPSVFtRVELVl5cU2gMve6mJz\nxv7ve2tkqThud/PXebxcq0kjj2HRH2wHQVO3wbdMQLAkFLfwPXmswQJAATuI+v9r\ngQPEsNd0EBL09Lwxb6dG6Tnx9RgVqHE3MIKbvBlpHEdqZgbtgTG8tXB+ye3pOe9J\nwIiGtQIRKNdrHQ==\n-----END PRIVATE KEY-----\n"

pem_pkcs1 = "-----BEGIN RSA PRIVATE KEY-----\nMIICXAIBAAKBgQC9L+RBvGwYzX7Z1LFqKt19CUK7LXKSedeNms2zHX/vvzOlrqQX\n-----END RSA PRIVATE KEY-----\n"

# (length, first 8 bytes, last 8 bytes, the sum of byte * index) of the DER bytes.
shape = |bytes| {
	weighted = bytes.fold({ i: 0.U64, sum: 0.U64 }, |acc, b| { i: acc.i + 1, sum: acc.sum + acc.i * b.to_u64() })
	(bytes.len(), bytes.take_first(8), bytes.take_last(8), weighted.sum)
}

der_shape : (U64, List(U8), List(U8), U64)
der_shape = (634, [48, 130, 2, 118, 2, 1, 0, 48], [134, 181, 2, 17, 40, 215, 107, 29], 25327050)

expect GithubApp.pkcs8_of_pem(pem_pkcs8).map_ok(shape) == Ok(der_shape)

# The lines may end with CR LF (a secret that was typed on Windows), and the last line may have no end of line.
expect GithubApp.pkcs8_of_pem(pem_pkcs8.replace_each("\n", "\r\n")).map_ok(shape) == Ok(der_shape)
expect GithubApp.pkcs8_of_pem(pem_pkcs8.drop_suffix("\n")).map_ok(shape) == Ok(der_shape)

# The form that GitHub gives (PKCS#1) is named, so the operator sees what to do; any other text is not a PEM.
expect GithubApp.pkcs8_of_pem(pem_pkcs1) == Err(Pkcs1)
expect ["", "hello", "-----BEGIN PRIVATE KEY-----\n-----END PRIVATE KEY-----\n", "-----BEGIN PRIVATE KEY-----\n!!!!\n-----END PRIVATE KEY-----\n", "-----BEGIN PRIVATE KEY-----\nMIICdgIB"].map(GithubApp.pkcs8_of_pem) == List.repeat(Err(NotPem), 5)
