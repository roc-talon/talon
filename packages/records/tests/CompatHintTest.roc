import records.Compat

CompatHintTest :: [].{}

# W0 tests of the publish and hint types in packages/records/Compat.roc (slice 104f). ' stands for " in the JSON text.
# The member order of the hint answer and `row` from 0 are the proposals of slice 116a section 6; the encoder follows them.

js : Str -> Str
js = |text| text.replace_each("'", "\"")

fact : Compat.Fact
fact = { nightly: "nightly-2026-10-09-258ab27", target: "any", result: "pass", error_digest: Err(None) }

fact_json : Str
fact_json = "{'error_digest':null,'nightly':'nightly-2026-10-09-258ab27','result':'pass','target':'any'}"

bad_publish : Str -> Bool
bad_publish = |t| match Compat.decode_publish(t) {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}

bad_hint : Str -> Bool
bad_hint = |t| match Compat.decode_hint_post(t) {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}

bad_answer : Str -> Bool
bad_answer = |t| match Compat.decode_hint_answer(t) {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}

# R-AP71, R-AP8, R-AP58, R-AP51: the publish body. Exact text and round trip. `compat` is left out for none. A fact always writes `error_digest` (null, text, empty text).
expect {
	url = "https://github.com/a/b/releases/download/1.0.0/H1.tar.zst"
	none_text = Compat.encode_publish({ url, compat: Err(None) })
	facts = [fact, { ..fact, error_digest: Ok("e1") }, { ..fact, result: "fail", error_digest: Ok("") }]
	text = Compat.encode_publish({ url, compat: Ok(facts) })
	empty = Compat.encode_publish({ url, compat: Ok([]) })
	none_text == js("{'url':'${url}'}") and text == js("{'compat':[${fact_json},{'error_digest':'e1','nightly':'nightly-2026-10-09-258ab27','result':'pass','target':'any'},{'error_digest':'','nightly':'nightly-2026-10-09-258ab27','result':'fail','target':'any'}],'url':'${url}'}") and empty == js("{'compat':[],'url':'${url}'}") and Compat.decode_publish(none_text) == Ok({ url, compat: Err(None) }) and Compat.decode_publish(text) == Ok({ url, compat: Ok(facts) }) and Compat.decode_publish(empty) == Ok({ url, compat: Ok([]) })
}

# R-AP71, R-AP51: `compat` missing or `null` is none. A missing `url`, a `compat` that is not a list, a missing member of a fact are BadJson. A fact value `hash` or `source` as a text is only a value.
expect {
	null_compat = Compat.decode_publish(js("{'url':'u','compat':null}"))
	cases = [
		"{'compat':[]}",
		"{'url':null}",
		"{'url':'u','compat':'x'}",
		"{'url':'u','compat':{}}",
		"{'url':'u','compat':[{'nightly':'n','target':'any','result':'pass'}]}",
		"{'url':'u','compat':[{'error_digest':null,'target':'any','result':'pass'}]}",
		"{'url':'u','compat':[{'error_digest':null,'nightly':'n','result':'pass'}]}",
		"{'url':'u','compat':[{'error_digest':null,'nightly':'n','target':'any'}]}",
		"not json",
	]
	value = Compat.decode_publish(js("{'url':'u','compat':[{'error_digest':'hash','nightly':'source','target':'any','result':'pass'}]}"))
	null_compat == Ok({ url: "u", compat: Err(None) }) and cases.all(|c| bad_publish(js(c))) and value == Ok({ url: "u", compat: Ok([{ nightly: "source", target: "any", result: "pass", error_digest: Ok("hash") }]) })
}

# R-AP71, R-MX5, Design Q176: a fact with a member `hash` or `source`, with any value (text, null, number, object) and with an escaped key, is BadJson.
expect {
	one = |m| js("{'url':'u','compat':[${fact_json.replace_first("{", "{${m},")}]}")
	members = ["'hash':'H1'", "'hash':null", "'hash':1", "'hash':{'a':1}", "'source':'bot'", "'source':null", "'source':2", "'source':{'a':1}", "'h\\u0061sh':'H1'", "'s\\u006furce':'x'"]
	members.all(|m| bad_publish(one(m))) and Compat.decode_publish(one("'talon_version':'0.5.0'")) == Ok({ url: "u", compat: Ok([fact]) })
}

# R-AP72, R-CT2: the hint request. Exact text (members in alphabetical order, a row has no `error_digest`) and round trip. `rows: []` is a value. `talon_version` is any text.
expect {
	row = { hash: "H1", nightly: "nightly-2026-10-09-258ab27", target: "any", result: "pass" }
	text = Compat.encode_hint_post({ talon_version: "0.5.0", rows: [row] })
	empty = Compat.encode_hint_post({ talon_version: "", rows: [] })
	text == js("{'rows':[{'hash':'H1','nightly':'nightly-2026-10-09-258ab27','result':'pass','target':'any'}],'talon_version':'0.5.0'}") and empty == js("{'rows':[],'talon_version':''}") and Compat.decode_hint_post(text) == Ok({ talon_version: "0.5.0", rows: [row] }) and Compat.decode_hint_post(empty) == Ok({ talon_version: "", rows: [] }) and !text.contains("error_digest") and !text.contains("source")
}

# R-AP72, R-AP70 row 6, R-AP51: both members are required. `error_digest` in a row (text or null), `sweep`, and `source` in the body or in a row, with any value, are BadJson. An unknown member is ignored.
expect {
	row = "{'hash':'H1','nightly':'n','result':'pass','target':'any'"
	body = |extra| js("{'rows':[${row}}],'talon_version':'v'${extra}}")
	in_row = |m| js("{'rows':[${row},${m}}],'talon_version':'v'}")
	cases = [
		"{'rows':[]}",
		"{'talon_version':'v'}",
		"{'rows':null,'talon_version':'v'}",
		"{'rows':[],'talon_version':null}",
		body(",'sweep':null"),
		body(",'sweep':{'nightly':'n'}"),
		body(",'source':'x'"),
		body(",'source':null"),
		body(",'s\\u006furce':1"),
		in_row("'error_digest':null"),
		in_row("'error_digest':'e'"),
		in_row("'source':'bot'"),
		in_row("'source':null"),
		in_row("'e\\u0072ror_digest':null"),
	]
	cases.all(bad_hint) and Compat.decode_hint_post(body(",'future':1")) == Ok({ talon_version: "v", rows: [{ hash: "H1", nightly: "n", target: "any", result: "pass" }] })
}

# R-AP72, R-CT14, R-AP10: the answer. Exact bytes: the members `written`, `first`, `skipped` in this order, an item `row`, `reason`, `skipped` always there. The text equals `Hints.answer_body` of the W0 case of slice 116a.
expect {
	two = [{ row: 0, reason: "unknown-hash" }, { row: 3, reason: "bot-row" }]
	a = { written: 2, first: 1, skipped: two }
	z = { written: 0, first: 0, skipped: [] }
	quote = { written: 1, first: 1, skipped: [{ row: 5, reason: "a \"q\" \\ b" }] }
	Compat.encode_hint_answer(a) == "{\"written\":2,\"first\":1,\"skipped\":[{\"row\":0,\"reason\":\"unknown-hash\"},{\"row\":3,\"reason\":\"bot-row\"}]}" and Compat.encode_hint_answer(z) == "{\"written\":0,\"first\":0,\"skipped\":[]}" and Compat.decode_hint_answer(Compat.encode_hint_answer(a)) == Ok(a) and Compat.decode_hint_answer(Compat.encode_hint_answer(z)) == Ok(z) and Compat.decode_hint_answer(Compat.encode_hint_answer(quote)) == Ok(quote)
}

# R-AP72, R-AP51, R-AP44: the reader ignores the order, an unknown member and an unknown reason. A missing or null member is BadJson. A negative or fractional count is BadJson.
expect {
	reordered = Compat.decode_hint_answer(js("{'skipped':[{'reason':'new-reason','row':2,'x':1}],'first':1,'written':0,'extra':true}"))
	reordered == Ok({ written: 0, first: 1, skipped: [{ row: 2, reason: "new-reason" }] }) and ["{'written':1,'first':1}", "{'written':1,'skipped':[]}", "{'first':1,'skipped':[]}", "{'written':null,'first':1,'skipped':[]}", "{'written':1,'first':1,'skipped':null}", "{'written':-1,'first':1,'skipped':[]}", "{'written':1.5,'first':1,'skipped':[]}", "{'written':1,'first':1,'skipped':[{'row':0}]}", "[]"].all(|c| bad_answer(js(c)))
}

# R-AP10, R-AP72, R-MX15: the answer of the bot path is `{"written":<n>}`.
expect {
	missing = match Compat.decode_written("{}") {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	Compat.encode_written({ written: 3 }) == "{\"written\":3}" and Compat.decode_written("{\"written\":0}") == Ok({ written: 0 }) and Compat.decode_written("{\"written\":2,\"first\":1}") == Ok({ written: 2 }) and missing
}
