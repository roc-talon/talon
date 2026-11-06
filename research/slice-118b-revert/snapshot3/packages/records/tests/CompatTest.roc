import records.Compat

CompatTest :: [].{}

# W0 tests of packages/records/Compat.roc (slice 104d). The request of `POST /v1/compat`, bot path. ' stands for " in the JSON text.
# R-PK7: the type is shared by the Worker, the bot script and the CLI.

js : Str -> Str
js = |text| text.replace_each("'", "\"")

ok_row : Compat.Row
ok_row = { hash: "H1", nightly: "nightly-2026-10-09-258ab27", target: "any", result: "pass", error_digest: Err(None) }

row_json : Str
row_json = "{'error_digest':null,'hash':'H1','nightly':'nightly-2026-10-09-258ab27','result':'pass','target':'any'}"

sweep : Compat.Sweep
sweep = { nightly: "nightly-2026-10-09-258ab27", target: "any", upto_log_index: 42 }

is_bad : Str -> Bool
is_bad = |t| match Compat.decode_post(t) {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}

# R-AP10, R-AP51, R-AP58, R-MX8: exact text and round trip. `error_digest` is always written (null, text, empty text). `sweep` is left out for none (optional). `source` is never written.
expect {
	d = { ..ok_row, error_digest: Ok("e1") }
	e = { ..ok_row, error_digest: Ok("") }
	none_text = Compat.encode_post({ rows: [ok_row, d, e], sweep: Err(None) })
	with_text = Compat.encode_post({ rows: [ok_row], sweep: Ok(sweep) })
	none_text == js("{'rows':[${row_json},{'error_digest':'e1','hash':'H1','nightly':'nightly-2026-10-09-258ab27','result':'pass','target':'any'},{'error_digest':'','hash':'H1','nightly':'nightly-2026-10-09-258ab27','result':'pass','target':'any'}]}") and with_text == js("{'rows':[${row_json}],'sweep':{'nightly':'nightly-2026-10-09-258ab27','target':'any','upto_log_index':42}}") and !none_text.contains("source") and !none_text.contains("sweep") and Compat.decode_post(none_text) == Ok({ rows: [ok_row, d, e], sweep: Err(None) }) and Compat.decode_post(with_text) == Ok({ rows: [ok_row], sweep: Ok(sweep) })
}

# R-AP10, R-AP51: the decode of a body with no sweep, `"sweep":null`, a sweep, and no rows in the list. Both sweep forms of none give `Err(None)`.
expect {
	rows = "'rows':[${row_json}]"
	Compat.decode_post(js("{${rows}}")) == Ok({ rows: [ok_row], sweep: Err(None) }) and Compat.decode_post(js("{${rows},'sweep':null}")) == Ok({ rows: [ok_row], sweep: Err(None) }) and Compat.decode_post(js("{${rows},'sweep':{'nightly':'nightly-2026-10-09-258ab27','target':'any','upto_log_index':42}}")) == Ok({ rows: [ok_row], sweep: Ok(sweep) }) and Compat.decode_post(js("{'rows':[]}")) == Ok({ rows: [], sweep: Err(None) })
}

# R-AP51, R-AP66: a missing or null `rows`, a missing `error_digest`, a missing or null `hash` (and the other text members) are BadJson. A null `error_digest` is accepted.
expect {
	cases = [
		"{}",
		"{'rows':null}",
		"{'rows':[{'hash':'H1','nightly':'n','target':'any','result':'pass'}]}",
		"{'rows':[{'error_digest':null,'nightly':'n','target':'any','result':'pass'}]}",
		"{'rows':[{'error_digest':null,'hash':null,'nightly':'n','target':'any','result':'pass'}]}",
		"{'rows':[{'error_digest':null,'hash':'H1','target':'any','result':'pass'}]}",
		"{'rows':[{'error_digest':null,'hash':'H1','nightly':'n','result':'pass'}]}",
		"{'rows':[{'error_digest':null,'hash':'H1','nightly':'n','target':'any'}]}",
		"not json",
	]
	cases.all(|c| is_bad(js(c))) and Compat.decode_post(js("{'rows':[${row_json}]}")) == Ok({ rows: [ok_row], sweep: Err(None) })
}

# R-AP66 check 4, R-MX5: a `source` member is BadJson, in the body and in a row, with any value (text, null, number, object) and with an escaped key (`source`). 12 cases.
expect {
	row = row_json
	row_with = |v| row_json.replace_first("{", "{'source':${v},")
	bodies = ["'x'", "null", "1", "{'a':1}", "'bot'"]
	in_body = bodies.map(|v| js("{'rows':[${row}],'source':${v}}"))
	in_row = bodies.map(|v| js("{'rows':[${row_with(v)}]}"))
	escaped = [js("{'rows':[${row}],'s\\u006furce':'x'}"), js("{'rows':[${row_with("'x'")}]}").replace_first("source", "s\\u006furce")]
	in_body.all(is_bad) and in_row.all(is_bad) and escaped.all(is_bad)
}

# R-AP66: the word `source` as a value is not a member. A digest that holds `"source":` is a digest.
expect {
	a = Compat.decode_post(js("{'rows':[{'error_digest':'source','hash':'H1','nightly':'n','target':'any','result':'pass'}]}"))
	d = "x \"source\": 1"
	b = Compat.decode_post(Compat.encode_post({ rows: [{ ..ok_row, error_digest: Ok(d) }], sweep: Err(None) }))
	a == Ok({ rows: [{ hash: "H1", nightly: "n", target: "any", result: "pass", error_digest: Ok("source") }], sweep: Err(None) }) and b == Ok({ rows: [{ ..ok_row, error_digest: Ok(d) }], sweep: Err(None) })
}

# R-AP66: a negative, a fractional and a text `upto_log_index` are BadJson.
expect {
	body = |v| js("{'rows':[],'sweep':{'nightly':'n','target':'any','upto_log_index':${v}}}")
	["-1", "1.5", "'7'", "null"].all(|v| is_bad(body(v))) and Compat.decode_post(body("7")) == Ok({ rows: [], sweep: Ok({ nightly: "n", target: "any", upto_log_index: 7 }) })
}

# R-AP44: an unknown member (`talon_version`) is ignored, in the body and in a row.
expect Compat.decode_post(js("{'rows':[${row_json.replace_first("{", "{'talon_version':'0.5.0',")}],'talon_version':'0.5.0','future':{'a':1}}")) == Ok({ rows: [ok_row], sweep: Err(None) })
