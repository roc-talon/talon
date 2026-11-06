import records.Work

WorkTest :: [].{}

# W0 tests of packages/records/Work.roc (slice 104k, Design Q575, Registry R-AP39, R-AP73, R-AP51). ' stands for " in the JSON text.
# The bodies are the bodies of the W2 case worker/tests/cases/compat/ap39-sweeps and the W0 test of CompatReads.sweep_body: the encoder gives the bytes that the Worker gives today.

js : Str -> Str
js = |text| text.replace_each("'", "\"")

ha = "3JF3sEqM796hk5WFqA6EtmEwJQ9quALszsfJyvXNQKy3"

hb = "4Ss5JMkXAD9Z7cktFEdrqeMuT6jGMF1pVozTyPHZ6zT4"

hc = "7tj9biW3KRJ7EEWmVUGigHiouCTXhV2dzcyvwma7Cyu7"

tag = "nightly-2026-10-29-aaaaaaa"

sweep : Work.Sweep
sweep = { nightly: tag, target: "any", time: 1767225609000, upto_log_index: 8 }

sweep_json : Str
sweep_json = "{'nightly':'${tag}','target':'any','time':1767225609000,'upto_log_index':8}"

bad : Str -> Bool
bad = |t| match Work.decode(t) {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}

# R-AP39, R-AP73: the 4 bodies of the W2 case ap39-sweeps. Each one decodes to the value and encodes again to the same bytes (so the ETag-free body of the Worker does not change).
expect {
	bodies = [
		js("{'log_size':8,'members':3,'missing':['${ha}','${hb}','${hc}'],'sweep':null}"),
		js("{'log_size':8,'members':3,'missing':['${hb}'],'sweep':null}"),
		js("{'log_size':8,'members':3,'missing':[],'sweep':${sweep_json}}"),
		js("{'log_size':8,'members':3,'missing':['29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2'],'sweep':${sweep_json}}"),
	]
	values : List(Work.Answer)
	values = [
		{ log_size: 8, members: 3, missing: [ha, hb, hc], sweep: Err(None) },
		{ log_size: 8, members: 3, missing: [hb], sweep: Err(None) },
		{ log_size: 8, members: 3, missing: [], sweep: Ok(sweep) },
		{ log_size: 8, members: 3, missing: ["29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2"], sweep: Ok(sweep) },
	]
	bodies.map(Work.decode) == values.map(|v| Ok(v)) and values.map(Work.encode) == bodies and bodies.all(|b| Work.decode(b).map_ok(Work.encode) == Ok(b))
}

# R-AP39, R-AP73: the bytes of the encoder (the W0 test of CompatReads.sweep_body). Members in alphabetical order, `sweep` always written, `null` for none, no white space, `missing` in the order given, a quote in the tag is escaped.
expect {
	row : Work.Sweep
	row = { nightly: "nightly-2026-10-20-7a8a800", target: "any", time: 1767225600000, upto_log_index: 24 }
	full = Work.encode({ log_size: 24, members: 5, missing: [hb, ha], sweep: Ok(row) })
	none = Work.encode({ log_size: 0, members: 0, missing: [], sweep: Err(None) })
	many = Work.encode({ log_size: 3, members: 120, missing: List.repeat(ha, 120), sweep: Err(None) })
	quote = Work.encode({ log_size: 1, members: 1, missing: [], sweep: Ok({ ..row, nightly: "a\"b" }) })
	full == js("{'log_size':24,'members':5,'missing':['${hb}','${ha}'],'sweep':{'nightly':'nightly-2026-10-20-7a8a800','target':'any','time':1767225600000,'upto_log_index':24}}") and none == js("{'log_size':0,'members':0,'missing':[],'sweep':null}") and many.split_on("\"${ha}\"").len() == 121 and quote.contains("\"nightly\":\"a\\\"b\"")
}

# R-AP39, R-AP51, R-AP44: the order of the members is free, an unknown member is ignored (in the answer and in the sweep row), white space is allowed. `sweep` null and `sweep` an object are two different values.
expect {
	reordered = Work.decode(js("{'sweep':null,'missing':['${ha}'],'members':2,'log_size':9}"))
	extra = Work.decode(js("{'log_size':8,'members':3,'missing':[],'sweep':{'upto_log_index':8,'time':1767225609000,'target':'any','nightly':'${tag}','x':1},'x':[1]}"))
	spaced = Work.decode(js(" { 'log_size' : 8 , 'members' : 3 , 'missing' : [ ] , 'sweep' : null } "))
	reordered == Ok({ log_size: 9, members: 2, missing: [ha], sweep: Err(None) }) and extra == Ok({ log_size: 8, members: 3, missing: [], sweep: Ok(sweep) }) and spaced == Ok({ log_size: 8, members: 3, missing: [], sweep: Err(None) })
}

# R-AP51, R-AP73: a required member that is missing, in the answer. `sweep` too: a missing `sweep` is not `null`.
expect {
	cases = [
		"{'members':3,'missing':[],'sweep':null}",
		"{'log_size':8,'missing':[],'sweep':null}",
		"{'log_size':8,'members':3,'sweep':null}",
		"{'log_size':8,'members':3,'missing':[]}",
		"{}",
	]
	cases.all(|c| bad(js(c)))
}

# R-AP51, R-AP73: `null` or a wrong JSON type for a member of the answer. `sweep` is an object or `null`, nothing else.
expect {
	cases = [
		"{'log_size':null,'members':3,'missing':[],'sweep':null}",
		"{'log_size':'8','members':3,'missing':[],'sweep':null}",
		"{'log_size':-1,'members':3,'missing':[],'sweep':null}",
		"{'log_size':8.5,'members':3,'missing':[],'sweep':null}",
		"{'log_size':8,'members':null,'missing':[],'sweep':null}",
		"{'log_size':8,'members':'3','missing':[],'sweep':null}",
		"{'log_size':8,'members':true,'missing':[],'sweep':null}",
		"{'log_size':8,'members':3,'missing':null,'sweep':null}",
		"{'log_size':8,'members':3,'missing':'${ha}','sweep':null}",
		"{'log_size':8,'members':3,'missing':[1],'sweep':null}",
		"{'log_size':8,'members':3,'missing':['${ha}',null],'sweep':null}",
		"{'log_size':8,'members':3,'missing':{},'sweep':null}",
		"{'log_size':8,'members':3,'missing':[],'sweep':'${tag}'}",
		"{'log_size':8,'members':3,'missing':[],'sweep':[]}",
		"{'log_size':8,'members':3,'missing':[],'sweep':1}",
		"{'log_size':8,'members':3,'missing':[],'sweep':false}",
	]
	cases.all(|c| bad(js(c)))
}

# R-AP51, R-AP73: the sweep row has 4 required members, none can be `null`, none of a wrong type.
expect {
	row = |m| js("{'log_size':8,'members':3,'missing':[],'sweep':{${m}}}")
	cases = [
		"'target':'any','time':1,'upto_log_index':8",
		"'nightly':'${tag}','time':1,'upto_log_index':8",
		"'nightly':'${tag}','target':'any','upto_log_index':8",
		"'nightly':'${tag}','target':'any','time':1",
		"'nightly':null,'target':'any','time':1,'upto_log_index':8",
		"'nightly':'${tag}','target':null,'time':1,'upto_log_index':8",
		"'nightly':'${tag}','target':'any','time':null,'upto_log_index':8",
		"'nightly':'${tag}','target':'any','time':1,'upto_log_index':null",
		"'nightly':1,'target':'any','time':1,'upto_log_index':8",
		"'nightly':'${tag}','target':'any','time':'1','upto_log_index':8",
		"'nightly':'${tag}','target':'any','time':1,'upto_log_index':-8",
		"'nightly':'${tag}','target':'any','time':1,'upto_log_index':'8'",
	]
	ok = Work.decode(row("'nightly':'${tag}','target':'any','time':1,'upto_log_index':8"))
	cases.all(|c| bad(row(c))) and ok.map_ok(|a| a.sweep) == Ok(Ok({ nightly: tag, target: "any", time: 1, upto_log_index: 8 }))
}

# R-AP51: a text that is not an object of the form is BadJson, and it does not crash.
expect {
	["", "not json", "[]", "null", "8", "\"x\"", "{", "{'log_size':8", "{'log_size':8,'members':3,'missing':[],'sweep':null}x"].all(|c| bad(js(c)))
}

# R-AP39, R-AP73: round trip of values. The `missing` order is kept, a text is kept as it is (the decoder does not check the base58 form: the Worker wrote the hash), the largest U64 is kept.
expect {
	big = 18446744073709551615
	a : Work.Answer
	a = { log_size: big, members: 0, missing: ["", "a\"b", "\\", ha], sweep: Ok({ nightly: "n", target: "any", time: big, upto_log_index: 0 }) }
	b : Work.Answer
	b = { log_size: 0, members: big, missing: [hc, hb, ha], sweep: Err(None) }
	Work.decode(Work.encode(a)) == Ok(a) and Work.decode(Work.encode(b)) == Ok(b)
}
