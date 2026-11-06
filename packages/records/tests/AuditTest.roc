import records.Audit

AuditTest :: [].{}

# W0 tests of packages/records/Audit.roc (slice 104k, Design Q575, Registry R-AP40, R-AP73, R-AP51). ' stands for " in the JSON text.
# The bodies are the bodies of the W2 case worker/tests/cases/compat/ap40-audit and the W0 test of CompatReads.pairs_body: the encoder gives the bytes that the Worker gives today.

js : Str -> Str
js = |text| text.replace_each("'", "\"")

ha = "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2"

hb = "4Ss5JMkXAD9Z7cktFEdrqeMuT6jGMF1pVozTyPHZ6zT4"

hc = "7tj9biW3KRJ7EEWmVUGigHiouCTXhV2dzcyvwma7Cyu7"

tag = "nightly-2026-10-29-aaaaaaa"

p1 : Audit.Pair
p1 = { hash: ha, nightly: tag, target: "any", pass_count: 5, fail_count: 1, crash_count: 0 }

p2 : Audit.Pair
p2 = { hash: hb, nightly: tag, target: "x64glibc", pass_count: 2, fail_count: 2, crash_count: 1 }

p3 : Audit.Pair
p3 = { hash: hb, nightly: tag, target: "any", pass_count: 0, fail_count: 3, crash_count: 0 }

p4 : Audit.Pair
p4 = { hash: hc, nightly: tag, target: "any", pass_count: 1, fail_count: 1, crash_count: 1 }

pair_json : Str -> Str
pair_json = |rest| "{'crash_count':0,'fail_count':1,'hash':'${ha}','nightly':'${tag}','pass_count':5,'target':'any'${rest}}"

bad : Str -> Bool
bad = |t| match Audit.decode(t) {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}

# R-AP40, R-AP73: the body of the W2 case ap40-audit (4 pairs, the order of the answer, one target that is not `any`) decodes to the value and encodes again to the same bytes. The empty answer too.
expect {
	body = js("{'pairs':[${pair_json("")},{'crash_count':1,'fail_count':2,'hash':'${hb}','nightly':'${tag}','pass_count':2,'target':'x64glibc'},{'crash_count':0,'fail_count':3,'hash':'${hb}','nightly':'${tag}','pass_count':0,'target':'any'},{'crash_count':1,'fail_count':1,'hash':'${hc}','nightly':'${tag}','pass_count':1,'target':'any'}]}")
	value : Audit.Answer
	value = { pairs: [p1, p2, p3, p4] }
	two = js("{'pairs':[${pair_json("")},{'crash_count':1,'fail_count':2,'hash':'${hb}','nightly':'${tag}','pass_count':2,'target':'x64glibc'}]}")
	Audit.decode(body) == Ok(value) and Audit.encode(value) == body and Audit.encode({ pairs: [p1, p2] }) == two and Audit.decode(two) == Ok({ pairs: [p1, p2] }) and Audit.encode({ pairs: [] }) == "{\"pairs\":[]}" and Audit.decode("{\"pairs\":[]}") == Ok({ pairs: [] })
}

# R-AP40, R-AP73: the bytes of the encoder (the W0 test of CompatReads.pairs_body). Members of a pair in alphabetical order, no white space, the pairs in the order given (it is not sorted), a count of 7 stays 7.
expect {
	row : Audit.Pair
	row = { hash: ha, nightly: tag, target: "wasm32", pass_count: 0, fail_count: 0, crash_count: 7 }
	text = Audit.encode({ pairs: [row, p3] })
	text == js("{'pairs':[{'crash_count':7,'fail_count':0,'hash':'${ha}','nightly':'${tag}','pass_count':0,'target':'wasm32'},{'crash_count':0,'fail_count':3,'hash':'${hb}','nightly':'${tag}','pass_count':0,'target':'any'}]}") and Audit.decode(text).map_ok(|a| a.pairs.map(|p| p.target)) == Ok(["wasm32", "any"])
}

# R-AP51, R-AP44: the order of the members is free, an unknown member is ignored (in the answer and in a pair), white space is allowed.
expect {
	reordered = Audit.decode(js("{'pairs':[{'target':'any','pass_count':5,'nightly':'${tag}','hash':'${ha}','fail_count':1,'crash_count':0}]}"))
	extra = Audit.decode(js("{'x':null,'pairs':[${pair_json(",'x':[1]")}]}"))
	spaced = Audit.decode(js(" { 'pairs' : [ ${pair_json("")} ] } "))
	reordered == Ok({ pairs: [p1] }) and extra == Ok({ pairs: [p1] }) and spaced == Ok({ pairs: [p1] })
}

# R-AP51, R-AP73: `pairs` missing, `null` or not a list is BadJson. An item that is not an object too.
expect {
	cases = [
		"{}",
		"{'pair':[]}",
		"{'pairs':null}",
		"{'pairs':{}}",
		"{'pairs':'x'}",
		"{'pairs':1}",
		"{'pairs':[null]}",
		"{'pairs':[1]}",
		"{'pairs':['${ha}']}",
		"{'pairs':[[]]}",
		"[]",
		"[${pair_json("")}]",
	]
	cases.all(|c| bad(js(c)))
}

# R-AP51, R-AP73: each of the 6 members of a pair is required, none can be `null` and none can have a wrong type.
expect {
	whole = ["'crash_count':0", "'fail_count':1", "'hash':'${ha}'", "'nightly':'${tag}'", "'pass_count':5", "'target':'any'"]
	one = |item| js("{'pairs':[{${item}}]}")
	without = |i| one(Str.join_with(whole.map_with_index(|m, j| if (j == i) "" else m).keep_if(|m| m != ""), ","))
	changed = |i, m| one(Str.join_with(whole.map_with_index(|x, j| if (j == i) m else x), ","))
	wrongs = [
		(0, "'crash_count':null"),
		(0, "'crash_count':'0'"),
		(0, "'crash_count':-1"),
		(0, "'crash_count':0.5"),
		(1, "'fail_count':null"),
		(1, "'fail_count':'1'"),
		(1, "'fail_count':true"),
		(2, "'hash':null"),
		(2, "'hash':1"),
		(2, "'hash':['${ha}']"),
		(3, "'nightly':null"),
		(3, "'nightly':20261029"),
		(4, "'pass_count':null"),
		(4, "'pass_count':'5'"),
		(4, "'pass_count':-5"),
		(5, "'target':null"),
		(5, "'target':{}"),
	]
	ok = Audit.decode(one(Str.join_with(whole, ",")))
	missing_all = [0, 1, 2, 3, 4, 5].all(|i| bad(without(i)))
	wrong_all = wrongs.all(|(i, m)| bad(changed(i, m)))
	ok == Ok({ pairs: [p1] }) and missing_all and wrong_all
}

# R-AP51: a text that is not an object of the form is BadJson, and it does not crash.
expect {
	["", "not json", "null", "8", "\"x\"", "{", "{'pairs':[", "{'pairs':[]}x"].all(|c| bad(js(c)))
}

# R-AP40, R-AP73: round trip of values. The order is kept, a text is kept as it is (the decoder does not check the base58 form), the largest U64 is kept, a quote and a backslash in a text are escaped and read back.
expect {
	big = 18446744073709551615
	odd : Audit.Pair
	odd = { hash: "a\"b", nightly: "\\", target: "", pass_count: big, fail_count: big, crash_count: big }
	a : Audit.Answer
	a = { pairs: [p4, odd, p1, p3, p2] }
	Audit.decode(Audit.encode(a)) == Ok(a) and Audit.decode(Audit.encode({ pairs: [] })) == Ok({ pairs: [] })
}
