import bot.Bot
import lib.Fail
import records.Work

BotTest :: [].{}

# Slice 223 (Registry R-MX1, R-MX4, R-MX10, R-MX13, R-MX15, R-MX17, R-AP2, R-AP6, R-AP10, R-AP39, R-AP40): the pure part of the compat bot. The flow is the L2 cases `bot/b1` to `bot/b21`. The work-list and audit decoders are in the records tests (slice 104k, Design Q575).
# Texts of the bot (stdout, stderr, the job words) are proposals for the review (R-OUT2, TW24); the readings are the questions Q1 to Q8 of docs/slices/223-compat-bot.md.
# ' stands for " in a JSON text.

ha = "3JF3sEqM796hk5WFqA6EtmEwJQ9quALszsfJyvXNQKy3"

hb = "4Ss5JMkXAD9Z7cktFEdrqeMuT6jGMF1pVozTyPHZ6zT4"

hc = "7tj9biW3KRJ7EEWmVUGigHiouCTXhV2dzcyvwma7Cyu7"

hd = "29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2"

tag = "nightly-2026-10-29-aaaaaaa"

origin = "http://127.0.0.1:9"

js = |text| text.replace_each("'", "\"")

# The stdout of `tln probe --json` for a unit check (the form of ProbeCmd `data`, kind unit).
unit_doc = |hash, compiler, outcome| js("{'schema':1,'command':'probe','ok':true,'data':{'kind':'unit','hash':'${hash}','label':'acme/json 2.1.0','compiler':'${compiler}','outcome':'${outcome}','modules':[],'probes':1},'error':null}")

# "none" or the result of a row, to compare in one `expect`.
row_text : Try(_, Str) -> Str
row_text = |r| match r {
	Ok(row) => "${row.hash} ${row.nightly} ${row.target} ${row.result} ${if row.error_digest.is_err() "null" else "digest"}"
	Err(_) => "none"
}

# R-AP6, R-AP39, R-AP40, R-AP2, R-AP10: the URL of each route.
expect {
	u = |route| Bot.url({ origin, route })
	u(Put(tag)) == "http://127.0.0.1:9/v1/toolchains/${tag}" and u(Sweeps(tag)) == "http://127.0.0.1:9/v1/sweeps/${tag}" and u(Audit(200)) == "http://127.0.0.1:9/v1/compat_hints?audit=200" and u(Artifact(ha)) == "http://127.0.0.1:9/v1/artifacts/${ha}" and u(Compat) == "http://127.0.0.1:9/v1/compat"
}

# R-AP2, R-MX18 item 1 (Q566): the URL of the first release that is not withdrawn (a yanked one counts).
expect {
	rel = |url, withdrawn, yanked| "{'url':'${url}','withdrawn':${withdrawn},'yanked':${yanked}}"
	good = "https://github.com/acme/json/releases/download/2.1.0/${ha}.tar.zst"
	body = js("{'artifact':{},'releases':[${rel("https://x/gone", "1792065600000", "false")},${rel(good, "null", "true")},${rel("https://x/y", "null", "false")}],'repos':[]}")
	only_withdrawn = js("{'artifact':{},'releases':[${rel("https://x/gone", "1792065600000", "false")}],'repos':[]}")
	Bot.release_url(body) == Ok(good) and Bot.release_url(only_withdrawn) == Err(NoRelease) and Bot.release_url(js("{'artifact':{},'releases':[],'repos':[]}")) == Err(NoRelease) and Bot.release_url("x").is_err()
}

# R-MX15, R-PB1, R-PB7 (Q1): the 2 jobs of one unit probe.
expect {
	Bot.fetch_job({ dir: "/t", hash: ha, url: "https://h/a.tar.zst" }) == ["curl", "-fsSL", "--output", "/t/${ha}.tar.zst", "https://h/a.tar.zst"] and Bot.probe_job({ dir: "/t", tag, hash: ha }) == ["env", "ROC_TOOLCHAIN=${tag}", "tln", "probe", "--json", "--yes", "/t/${ha}.tar.zst"]
}

# R-MX17, R-AP10: the row of a probe: the 4 results, the target any, no digest.
expect {
	r = |outcome| row_text(Bot.row({ tag, hash: ha, stdout: unit_doc(ha, tag, outcome) }))
	r("pass") == "${ha} ${tag} any pass null" and r("fail") == "${ha} ${tag} any fail null" and r("hang") == "${ha} ${tag} any hang null" and r("crash") == "${ha} ${tag} any crash null"
}

# R-MX17, R-MX18 item 5 (Q570): the compiler is compared by the nightly id, so the 2 forms of a tag are equal; another date is no row.
expect {
	july = "nightly-2026-07-31-123c5d7"
	got = |compiler| row_text(Bot.row({ tag: july, hash: ha, stdout: unit_doc(ha, compiler, "pass") }))
	got("nightly-2026-July-31-123c5d7") == "${ha} ${july} any pass null" and got(july) == "${ha} ${july} any pass null" and got("nightly-2026-08-01-123c5d7") == "none"
}

# R-MX17 (Q570): no row for an answer that is not a unit check of this hash on this nightly.
expect {
	none = |stdout| row_text(Bot.row({ tag, hash: ha, stdout })) == "none"
	failed = js("{'schema':1,'command':'probe','ok':false,'data':null,'error':{'kind':'internal','code':1,'message':'no fact','details':null}}")
	range = js("{'schema':1,'command':'probe','ok':true,'data':{'kind':'range','hash':'${ha}','label':'x','range':null,'probes':3,'downloads':0},'error':null}")
	none(failed) and none(range) and none(unit_doc(hb, tag, "pass")) and none(unit_doc(ha, "nightly-2026-10-28-bbbbbbb", "pass")) and none("") and none("not json")
}

# R-MX4: the sweep of the run: the bound is the log size of the read, and it goes only when each missing hash has a row.
expect {
	work : Work.Answer
	work = { log_size: 8, members: 3, missing: [ha, hb], sweep: Err(None) }
	full = Bot.sweep({ tag, work, rowed: [hb, hc, ha] })
	open = Bot.sweep({ tag, work, rowed: [ha] })
	none_missing = Bot.sweep({ tag, work: { ..work, missing: [] }, rowed: [] })
	full == Ok({ nightly: tag, target: "any", upto_log_index: 8 }) and open == Err(None) and none_missing == Ok({ nightly: tag, target: "any", upto_log_index: 8 })
}

# R-MX13, R-MX10: the audit groups: one group for each nightly, the unit pairs only (a smoke pair is Q3).
expect {
	n2 = "nightly-2026-10-20-bbbbbbb"
	pair = |hash, nightly, target| { hash, nightly, target, pass_count: 1, fail_count: 1, crash_count: 0 }
	Bot.audit_groups([pair(ha, tag, "any"), pair(hb, tag, "x64glibc"), pair(hc, n2, "any"), pair(hd, tag, "any")]) == [{ nightly: tag, hashes: [ha, hd] }, { nightly: n2, hashes: [hc] }] and Bot.audit_groups([pair(hb, tag, "x64glibc")]) == [] and Bot.audit_groups([]) == []
}

# R-MX18 item 2 (Q567): the tags of the GitHub list: the nightly tags only, oldest first.
expect {
	item = |t| "{'tag_name':'${t}','draft':false}"
	body = js("[${item("nightly-2026-10-29-aaaaaaa")},${item("latest")},${item("nightly-2026-10-28-bbbbbbb")},${item("nightly-2026-10-27-ccccccc")}]")
	Bot.tags(body) == Ok(["nightly-2026-10-27-ccccccc", "nightly-2026-10-28-bbbbbbb", "nightly-2026-10-29-aaaaaaa"]) and Bot.tags("[]") == Ok([]) and Bot.tags(js("[{'tag_name':'latest'}]")) == Ok([]) and Bot.tags("{}").is_err() and Bot.tags("x").is_err()
}

# R-MX18 item 7 (Q572): a work list with nothing to do: no `missing` and a sweep bound that is at least the log size.
expect {
	row = |bound| Ok({ nightly: tag, target: "any", time: 1767225609000, upto_log_index: bound })
	work : Work.Answer
	work = { log_size: 8, members: 3, missing: [], sweep: row(8) }
	Bot.done(work) and Bot.done({ ..work, sweep: row(9) }) and !Bot.done({ ..work, sweep: row(7) }) and !Bot.done({ ..work, sweep: Err(None) }) and !Bot.done({ ..work, missing: [ha] })
}

# R-MX18 item 7 (Q572, R-AP46): the chunks of 500 rows, the sweep only in the last one.
expect {
	one = { hash: ha, nightly: tag, target: "any", result: "pass", error_digest: Err(None) }
	sweep = { nightly: tag, target: "any", upto_log_index: 8 }
	sizes = |posts| posts.map(|p| p.rows.len())
	sweeps = |posts| posts.map(|p| p.sweep.is_ok())
	p501 = Bot.chunks({ rows: List.repeat(one, 501), sweep: Ok(sweep) })
	p500 = Bot.chunks({ rows: List.repeat(one, 500), sweep: Ok(sweep) })
	p1000 = Bot.chunks({ rows: List.repeat(one, 1000), sweep: Err(None) })
	p0 = Bot.chunks({ rows: [], sweep: Ok(sweep) })
	sizes(p501) == [500, 1] and sweeps(p501) == [Bool.False, Bool.True] and sizes(p500) == [500] and sweeps(p500) == [Bool.True] and sizes(p1000) == [500, 500] and sweeps(p1000) == [Bool.False, Bool.False] and sizes(p0) == [0] and sweeps(p0) == [Bool.True] and Bot.chunks({ rows: [], sweep: Err(None) }) == []
}

# R-MX18 item 13 (Q585): the failure texts, the kinds and the exit codes. A real problem body (R-AP21). No text has a token.
expect {
	origin_ = "http://127.0.0.1:9"
	problem : Str, U16 -> Str
	problem = |type, status| js("{'type':'/errors/${type}','title':'T','status':${status.to_str()},'detail':'D'}")
	got : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)], Try({ status : U16, body : Str }, [NoAnswer(Str)]) -> (Str, I32, Str)
	got = |step, reply| {
		f = Bot.failure({ origin: origin_, step, reply })
		(f.kind.name(), f.kind.code(), f.message)
	}
	token_text = |type, detail| "the registry ${origin_} refused the OIDC token of this run (/errors/${type}): ${detail}. Check that the run is the workflow of BOT_WORKFLOW_REF on the default branch of BOT_REPOSITORY_ID (R-TP7) and that the job has permissions: id-token: write."
	fault_text = |step, type| "the registry ${origin_} refused the ${step} (/errors/${type}): D. The bot stops. This is a fault of the bot or of the registry data, not of the run."
	gave_up = |step, what| "the registry ${origin_} did not take the ${step} after 4 requests (${what}). The bot stops, and the next run starts again."
	r401 = got(Post(tag), Ok({ status: 401, body: problem("unauthenticated", 401) }))
	r403 = got(Put(tag), Ok({ status: 403, body: problem("forbidden", 403) }))
	r422 = got(Put(tag), Ok({ status: 422, body: problem("not-a-candidate", 422) }))
	r404 = got(PostAudit(tag), Ok({ status: 404, body: problem("not-found", 404) }))
	r400 = got(Post(tag), Ok({ status: 400, body: problem("bad-request", 400) }))
	r409 = got(Post(tag), Ok({ status: 409, body: problem("label-conflict", 409) }))
	n503 = got(Post(tag), Ok({ status: 503, body: problem("busy", 503) }))
	n429 = got(Put(tag), Ok({ status: 429, body: problem("rate-limited", 429) }))
	n502 = got(PostAudit(tag), Ok({ status: 502, body: problem("upstream", 502) }))
	none = got(Put(tag), Err(NoAnswer("no answer in 20 s")))
	list503 = got(List, Ok({ status: 503, body: "{}" }))
	list_none = got(List, Err(NoAnswer("connection refused")))
	all = [r401, r403, r422, r404, r400, r409, n503, n429, n502, none, list503, list_none]
	no_token = all.all(|(_, _, m)| !m.contains("Bearer") and !m.contains("jwt") and !m.contains("eyJ"))
	r401 == ("rejected", 20, token_text("unauthenticated", "D")) and r403 == ("rejected", 20, token_text("forbidden", "D")) and r422 == ("rejected", 20, fault_text("put ${tag}", "not-a-candidate")) and r404 == ("rejected", 20, fault_text("post audit ${tag}", "not-found")) and r400 == ("rejected", 20, fault_text("post ${tag}", "bad-request")) and r409 == ("rejected", 20, fault_text("post ${tag}", "label-conflict")) and n503 == ("network", 15, gave_up("post ${tag}", "503")) and n429 == ("network", 15, gave_up("put ${tag}", "429")) and n502 == ("network", 15, gave_up("post audit ${tag}", "502")) and none == ("network", 15, gave_up("put ${tag}", "no answer")) and list503 == ("network", 15, "the list of nightlies at api.github.com did not answer (503). The bot stops, and the next run starts again.") and list_none == ("network", 15, "the list of nightlies at api.github.com did not answer (no answer). The bot stops, and the next run starts again.") and no_token
}

# R-MX18 items 13, 14 (Q594): `Bot.failure` for the 3 read steps `get sweeps <tag>`, `get audit` and `get artifact <hash>`: no answer, 429, 5xx and busy after the retries are 15; a 4xx is 20. No text has a token.
expect {
	problem : Str, U16 -> Str
	problem = |type, status| js("{'type':'/errors/${type}','title':'T','status':${status.to_str()},'detail':'D'}")
	got : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)], Try({ status : U16, body : Str }, [NoAnswer(Str)]) -> (Str, I32, Str)
	got = |step, reply| {
		f = Bot.failure({ origin, step, reply })
		(f.kind.name(), f.kind.code(), f.message)
	}
	gave_up = |step, what| "the registry ${origin} did not take the ${step} after 4 requests (${what}). The bot stops, and the next run starts again."
	fault = |step, type| "the registry ${origin} refused the ${step} (/errors/${type}): D. The bot stops. This is a fault of the bot or of the registry data, not of the run."
	a = got(GetSweeps(tag), Err(NoAnswer("no answer in 20 s")))
	b = got(GetAudit, Ok({ status: 429, body: problem("rate-limited", 429) }))
	c = got(GetArtifact(ha), Ok({ status: 503, body: problem("busy", 503) }))
	d = got(GetSweeps(tag), Ok({ status: 502, body: problem("upstream", 502) }))
	e = got(GetSweeps(tag), Ok({ status: 404, body: problem("not-found", 404) }))
	f = got(GetAudit, Ok({ status: 400, body: problem("bad-request", 400) }))
	g = got(GetArtifact(ha), Ok({ status: 404, body: problem("not-found", 404) }))
	no_token = [a, b, c, d, e, f, g].all(|(_, _, m)| !m.contains("Bearer") and !m.contains("jwt") and !m.contains("eyJ"))
	a == ("network", 15, gave_up("get sweeps ${tag}", "no answer")) and b == ("network", 15, gave_up("get audit", "429")) and c == ("network", 15, gave_up("get artifact ${ha}", "503")) and d == ("network", 15, gave_up("get sweeps ${tag}", "502")) and e == ("rejected", 20, fault("get sweeps ${tag}", "not-found")) and f == ("rejected", 20, fault("get audit", "bad-request")) and g == ("rejected", 20, fault("get artifact ${ha}", "not-found")) and no_token
}
