import records.Yank

YankTest :: [].{}

# W0 tests of packages/records/Yank.roc (slice 246, docs/slices/246-yank.md). The rules are R-YK1 (the bodies), R-YK6 (the reason), R-AP51 (optional and null members), R-AP44 (an unknown member), R-AP49 (the release record).
# The answer fixture is the release record of the W2 case yank/yk1-yank-unyank after a yank, in the byte form of Release.encode (the same bytes as the answer of a publish: the members in the order of the other codecs of this package).

answer_text : Str
answer_text = "{\"release\":{\"group\":\"github.com/acme/lib/releases/download/{v}/\",\"hash\":\"3g6pdQ6Y66osX1c5BJXrWnGNJWpqTrXCLT3cSfANdbdg\",\"log_index\":1,\"provenance\":[\"oidc\",\"ingest\"],\"published_at\":1792497600000,\"repo\":\"acme/lib\",\"roc_version\":null,\"series\":\"1\",\"tag\":\"1.0.0\",\"url\":\"https://github.com/acme/lib/releases/download/1.0.0/3g6pdQ6Y66osX1c5BJXrWnGNJWpqTrXCLT3cSfANdbdg.tar.zst\",\"version\":\"1.0.0\",\"withdrawn\":null,\"yank_reason\":\"broken build\",\"yanked\":true}}"

# R-YK1: the body of the answer is the release record in `{"release": ...}`. A decode and an encode give the same bytes.
# R-AP49: the members `yanked` and `yank_reason` are the yank state.
expect {
	match Yank.decode_answer(answer_text) {
		Ok(row) => [row.yanked, row.yank_reason == Ok("broken build"), row.log_index == 1, Yank.encode_answer(row) == answer_text].all(|b| b)
		Err(_) => Bool.False
	}
}

# R-YK1, R-AP51: a missing `release` is `BadJson`. A text that is not JSON is `BadJson`. A release with `yanked` missing is `BadJson`.
expect {
	is_bad = |text| match Yank.decode_answer(text) {
		Err(BadJson(_)) => Bool.True
		Ok(_) => Bool.False
	}
	[
		is_bad("{}"),
		is_bad(""),
		is_bad("not json"),
		is_bad("{\"release\":{\"log_index\":1}}"),
		is_bad("{\"release\":null}"),
	].all(|b| b)
}

# R-YK1, R-YK6, R-AP51: the request. A reason is a text. A missing `reason` and `null` are no reason. An unknown member is ignored (R-AP44).
expect {
	reason_of = |text| match Yank.decode_request(text) {
		Ok(request) => Ok(request.reason)
		Err(BadJson(_)) => Err(Bad)
	}
	[
		reason_of("{\"reason\":\"broken build\"}") == Ok(Ok("broken build")),
		reason_of("{\"reason\":\"\"}") == Ok(Ok("")),
		reason_of("{}") == Ok(Err(None)),
		reason_of("{\"reason\":null}") == Ok(Err(None)),
		reason_of("{\"reason\":\"x\",\"later\":[1,2]}") == Ok(Ok("x")),
		reason_of("{\"later\":true}") == Ok(Err(None)),
		reason_of("{\"reason\":\"caf\\u00e9 \\\"q\\\"\"}") == Ok(Ok("café \"q\"")),
	].all(|b| b)
}

# R-AP51: a `reason` of another JSON type, and a body that is not an object, are `BadJson` (the Worker maps it to 400).
expect {
	is_bad = |text| match Yank.decode_request(text) {
		Err(BadJson(_)) => Bool.True
		Ok(_) => Bool.False
	}
	[
		is_bad("{\"reason\":5}"),
		is_bad("{\"reason\":true}"),
		is_bad("{\"reason\":[\"x\"]}"),
		is_bad("{\"reason\":{}}"),
		is_bad("[]"),
		is_bad("\"x\""),
		is_bad(""),
		is_bad("not json"),
	].all(|b| b)
}

# R-AP51: the writer leaves out an optional member that has no value. The text of a request that has a reason has the member. A decode of what the writer wrote gives the request again.
expect {
	none = { reason: Err(None) }
	some = { reason: Ok("a \"b\"\\ c é") }
	[
		Yank.encode_request(none) == "{}",
		Yank.encode_request({ reason: Ok("broken build") }) == "{\"reason\":\"broken build\"}",
		Yank.decode_request(Yank.encode_request(none)) == Ok(none),
		Yank.decode_request(Yank.encode_request(some)) == Ok(some),
	].all(|b| b)
}

# R-YK6: the limit is 500 bytes of UTF-8, not 500 characters. 500 bytes are good, 501 are too long. A 2-byte character counts 2, a 3-byte character 3, a 4-byte character 4.
expect {
	a = |n| "a".repeat(n)
	check = |text| Yank.check_reason(text)
	[
		Yank.reason_limit == 500,
		check("") == Ok({}),
		check(a(500)) == Ok({}),
		check(a(501)) == Err(TooLong),
		check("é".repeat(250)) == Ok({}),
		check("é".repeat(251)) == Err(TooLong),
		check("${a(498)}é") == Ok({}),
		check("${a(499)}é") == Err(TooLong),
		check("€".repeat(166)) == Ok({}),
		check("€".repeat(167)) == Err(TooLong),
		check("😀".repeat(125)) == Ok({}),
		check("😀".repeat(126)) == Err(TooLong),
	].all(|b| b)
}

# R-YK6: no control character: U+0000 to U+001F (the tab and the new line too) and U+007F. A space, other punctuation, and text in other scripts are good. The length is checked first.
expect {
	check = |text| Yank.check_reason(text)
	[
		check("a\tb") == Err(ControlChar),
		check("a\nb") == Err(ControlChar),
		check("a\rb") == Err(ControlChar),
		check("a\u(00)b") == Err(ControlChar),
		check("a\u(1B)[31mb") == Err(ControlChar),
		check("a\u(7F)b") == Err(ControlChar),
		check("\u(1F)") == Err(ControlChar),
		check("a b  c, d; e: f! g? (h) [i] {j} \"k\" 'l' <m> /n\\o") == Ok({}),
		check("日本語 текст ελληνικά 😀") == Ok({}),
		check("${"a".repeat(501)}\n") == Err(TooLong),
	].all(|b| b)
}
