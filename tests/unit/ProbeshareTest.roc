import lib.Db
import lib.Fail
import lib.JsonDoc
import lib.ProbeShare

ProbeshareTest :: [].{}

# Slice 217 (Resolution 4 R-PB6; CLI 1 R-SH2, R-SH3, R-RG4; CLI 3 R-E6; Registry R-AP10, R-AP51): the pure part of `tln probe --share`. The flow is the L2 cases `probe/ps1` to `probe/ps9`.
# The texts and the `data` members are proposals for the review (R-OUT2, TW24). The facts in them are from R-PB6 and R-SH3.
# `rows` is `ShareQueue.admit` with the flag as the consent: the tests change one thing at a time from one good fact, so each row of a table fails for one reason.

# D: the nightlies, oldest first (R-NS1), as in `SharequeueTest`.
c1 = "nightly-2026-10-01-aaaaaaa"

c2 = "nightly-2026-10-03-ccccccc"

c3 = "nightly-2026-10-05-eeeeeee"

c4 = "nightly-2026-10-07-0a0a0a0"

c5 = "nightly-2026-10-09-0b0b0b0"

day_s = 86400

rel = |id, day| { id, published_at: 1790812800 + day * day_s, asset: Err(NoAsset) }

domain = [rel(c1, 0), rel(c2, 2), rel(c3, 4), rel(c4, 6), rel(c5, 8)]

version = "0.9.0"

at = "2026-11-03T10:00:00Z"

art = |hash| { hash, kind: Package, exposed: [], platform_hash: Err(None), roc_pin: Err(None), size: 10, deps: [], target_names: [] }

plat = { ..art("HP"), kind: Platform, target_names: ["x64musl", "arm64mac"] }

answer = |artifacts, runs, nearest| { artifacts, releases: [], epochs: [], runs, nearest, hints: [], log_size: 40, unknown: [], checked: [], repos: [] }

plain = answer([art("H1"), art("H2"), plat], [], [])

run = |hash, target, source, result, from, to| { hash, target, source, result, error_digest: Err(None), from, to }

fact : Str, Str, Str, Db.Outcome, Str -> Db.Fact
fact = |hash, nightly, target, outcome, closure| { hash, nightly, target, outcome, modules: [], closure }

queued = |hash, nightly, target, result| { hash, nightly, target, result, talon_version: version, queued_at: at }

input = |hash, facts| { hash, facts, recorded: [c1, c2, c3, c4, c5], answers: [plain], headers: [], domain, talon_version: version, queued_at: at }

# "ok", or the name of the kind of the failure.
kind_of : Try(a, Fail) -> Str
kind_of = |result| match result {
	Ok(_) => "ok"
	Err(fail) => fail.kind.name()
}

# R-PB6, R-SH3 (filter 1 is the one that does not apply): the stored facts of the hash go out. Old facts of `compat.db` are sent: they are no probe of this command. A pass, a fail and a crash are sent.
# The rows are sorted by nightly, then target, then closure (a proposal), also when the facts are not. Nothing stays back.
expect {
	got = ProbeShare.rows(input("H1", [fact("H1", c3, "any", Crash, ""), fact("H1", c1, "any", Pass, ""), fact("H1", c2, "any", Fail, "")]))
	got
		== {
			rows: [queued("H1", c1, "any", Pass), queued("H1", c2, "any", Fail), queued("H1", c3, "any", Crash)],
			kept_back: [],
		}
}

# R-PB6, R-SH3 filter 6: a hang is no fact (a slow machine can cause it). It stays back with the reason `Result`, and the other facts go. Both lists are in the order of the nightlies.
expect {
	got = ProbeShare.rows(input("H1", [fact("H1", c2, "any", Hang, ""), fact("H1", c1, "any", Pass, "")]))
	got == { rows: [queued("H1", c1, "any", Pass)], kept_back: [{ nightly: c2, target: "any", why: Result }] }
}

# R-PB6, R-SH3 filter 2: only a unit check goes. A row with a `closure` digest is the build of an app or of a platform: it stays back (`Kind`). A unit check and a build of one nightly are 2 rows: sorted by closure.
expect {
	got = ProbeShare.rows(input("H1", [fact("H1", c1, "linux_x86_64", Pass, "abc"), fact("H1", c1, "any", Pass, "")]))
	got == { rows: [queued("H1", c1, "any", Pass)], kept_back: [{ nightly: c1, target: "linux_x86_64", why: Kind }] }
}

# R-PB6, R-SH3 filter 3: the compiler is a nightly with a recorded sha256. A nightly that is not in `recorded`, and a release `X.Y.Z` (also when recorded), stay back (`Compiler`). A tag in the other form (R-CV1) is the same compiler.
expect {
	local = { ..input("H1", [fact("H1", c1, "any", Pass, ""), fact("H1", c2, "any", Pass, ""), fact("H1", "0.4.1", "any", Pass, "")]), recorded: [c1, "0.4.1"] }
	got = ProbeShare.rows(local)
	got.rows == [queued("H1", c1, "any", Pass)] and got.kept_back == [{ nightly: "0.4.1", target: "any", why: Compiler }, { nightly: c2, target: "any", why: Compiler }]
}

# R-PB6, R-SH3 filter 4: the hash must be in an answer of the registry (an artifact record or a release row). With no answer, or an answer that names other hashes, nothing goes: each fact stays back with `NotInAnswer`.
# A hash that is only in a release row of the answer is enough (filter 7 then needs the header kind: `headers`).
expect {
	facts = [fact("H9", c1, "any", Pass, "")]
	no_answer = ProbeShare.rows({ ..input("H9", facts), answers: [] })
	other = ProbeShare.rows(input("H9", facts))
	rel_only = { ..plain, releases: [{ log_index: 1, hash: "H9", group: "github.com/x/y/releases/download/{v}/", series: "1", version: "1.0.0", url: "https://github.com/x/y/releases/download/1.0.0/H9.tar.zst", tag: Ok("1.0.0"), roc_version: Err(None), repo: Ok("x/y"), published_at: 1790848800000, yanked: Bool.False, yank_reason: Err(None), withdrawn: Err(None), provenance: ["webhook"] }] }
	found = ProbeShare.rows({ ..input("H9", facts), answers: [rel_only], headers: [{ hash: "H9", kind: Package, names: [] }] })
	no_header = ProbeShare.rows({ ..input("H9", facts), answers: [rel_only] })
	no_answer.rows == []
		and no_answer.kept_back == [{ nightly: c1, target: "any", why: NotInAnswer }]
			and other.kept_back == [{ nightly: c1, target: "any", why: NotInAnswer }]
				and found.rows == [queued("H9", c1, "any", Pass)]
					and no_header.kept_back == [{ nightly: c1, target: "any", why: Target }]
}

# R-PB6, R-SH3 filter 5 (R-EF3): a `bot` row of an answer for the pair (hash, nightly, target) stops the fact (`BotRow`). A bot run holds each release of D in its interval. A bot row of another hash and an `author` row stop nothing.
expect {
	with_runs = |runs| { ..input("H1", [fact("H1", c1, "any", Pass, ""), fact("H1", c2, "any", Pass, ""), fact("H1", c4, "any", Pass, "")]), answers: [answer([art("H1")], runs, [])] }
	bot = ProbeShare.rows(with_runs([run("H1", "any", Bot, Pass, c2, c3)]))
	other = ProbeShare.rows(with_runs([run("H2", "any", Bot, Pass, c1, c5), run("H1", "any", Author, Pass, c1, c5)]))
	bot.rows == [queued("H1", c1, "any", Pass), queued("H1", c4, "any", Pass)]
		and bot.kept_back == [{ nightly: c2, target: "any", why: BotRow }]
			and other.rows.len() == 3
}

# R-PB6, R-SH3 filter 7 (Registry R-CT2, Design Q432): the target must be one that the Worker takes for the kind of the hash. A package takes `any` only. A platform takes `any` or a name of its `target_names`. A fact of another target stays back (`Target`).
expect {
	pkg_plan = ProbeShare.rows(input("H1", [fact("H1", c1, "any", Pass, ""), fact("H1", c2, "x64musl", Pass, "")]))
	plat_plan = ProbeShare.rows(input("HP", [fact("HP", c1, "any", Pass, ""), fact("HP", c2, "x64musl", Pass, ""), fact("HP", c3, "linux_x86_64", Pass, "")]))
	pkg_plan.rows == [queued("H1", c1, "any", Pass)]
		and pkg_plan.kept_back == [{ nightly: c2, target: "x64musl", why: Target }]
			and plat_plan.rows == [queued("HP", c1, "any", Pass), queued("HP", c2, "x64musl", Pass)]
				and plat_plan.kept_back == [{ nightly: c3, target: "linux_x86_64", why: Target }]
}

# R-PB6: a stored fact of another hash is not sent (the caller gave the facts of one hash; a wrong row never reaches the registry). No fact: no row and nothing back.
expect {
	other = ProbeShare.rows(input("H1", [fact("H2", c1, "any", Pass, "")]))
	none = ProbeShare.rows(input("H1", []))
	other == { rows: [], kept_back: [] } and none == { rows: [], kept_back: [] }
}

# R-PB6 (4), R-AP10, Design Q498: the batches. No row, no batch. 500 rows are one request, 501 rows are 500 and 1. At most 20 requests (10,000 rows): 10,000 rows are 20 batches, 10,500 rows are 20 batches and 500 rows `unsent` (the rows past the cap, in order).
expect {
	list : U64 -> List(Db.Queued)
	list = |n| U64.to(1, n).iter().map(|i| queued("H${i.to_str()}", c1, "any", Pass)).collect()
	sizes = |n| ProbeShare.batches(list(n)).send.map(|b| b.len())
	left = |n| ProbeShare.batches(list(n)).unsent.len()
	over = ProbeShare.batches(list(10500))
	ProbeShare.max_requests == 20
		and sizes(0) == []
			and sizes(1) == [1]
				and sizes(500) == [500]
					and sizes(501) == [500, 1]
						and sizes(10000).len() == 20
							and left(10000) == 0
								and over.send.len() == 20
									and over.send.map(|b| b.len()).fold(0, |a, n| a + n) == 10000
										and over.unsent == list(10500).drop_first(10000)
											and left(501) == 0
}

# R-PB6, R-AP10, R-AP51, R-E6: one answer. A 200 or a 201 with a body that decodes: the rows count (`sent`), `written`, `first` and the number of `skipped` items. A body that does not decode is exit 15.
expect {
	reply = |status, body| Ok({ status, headers: [], body })
	ask = |r| ProbeShare.answer({ origin: "http://127.0.0.1:9", version, count: 3, reply: r })
	ok_body = "{\"written\":2,\"first\":1,\"skipped\":[{\"row\":0,\"reason\":\"bot-row\"}]}"
	want = Ok({ sent: 3, counted: 2, first: 1, skipped: 1 })
	ask(reply(201, ok_body)) == want
		and ask(reply(200, ok_body)) == want
			and kind_of(ask(reply(201, "{\"written\":2}"))) == "network"
				and kind_of(ask(reply(200, "not json"))) == "network"
}

# R-E6, R-J7: the other answers. 400 and 413 are `internal` (1), 401 403 404 409 422 to a write are `rejected` (20), 429 and 5xx are `network` (15), a body that is not problem details is `network`, an unlisted 2xx or a 3xx is `network`, no answer is `network`.
expect {
	problem = |ptype, status| "{\"type\":\"${ptype}\",\"title\":\"T\",\"status\":${status}}"
	ask = |r| ProbeShare.answer({ origin: "http://127.0.0.1:9", version, count: 3, reply: r })
	status_kind = |status, ptype| kind_of(ask(Ok({ status, headers: [], body: problem(ptype, status.to_str()) })))
	cases = [
		("400", status_kind(400, "/errors/bad-request"), "internal"),
		("413", status_kind(413, "/errors/too-large"), "internal"),
		("404", status_kind(404, "/errors/not-found"), "rejected"),
		("422", status_kind(422, "/errors/unprocessable"), "rejected"),
		("403", status_kind(403, "/errors/forbidden"), "rejected"),
		("429", status_kind(429, "/errors/rate-limited"), "network"),
		("503 busy", status_kind(503, "/errors/busy"), "network"),
		("500", status_kind(500, "/errors/internal"), "network"),
		("204", status_kind(204, "/errors/x"), "network"),
		("302", status_kind(302, "/errors/x"), "network"),
		("a 502 that is not problem details", kind_of(ask(Ok({ status: 502, headers: [], body: "<html>" }))), "network"),
		("no answer", kind_of(ask(Err(Timeout))), "network"),
		("failed", kind_of(ask(Err(Failed("refused")))), "network"),
	]
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-PB6, R-SH10, R-EC2, R-OUT2: the 3 usage failures (exit 2). The first has the words of `ShareAccount.direct_text`.
expect {
	ProbeShare.direct({}).kind.name() == "usage"
		and Fail.line(ProbeShare.direct({})) == "tln: error[usage]: tln probe --share needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml."
			and Fail.line(ProbeShare.no_hash({})) == "tln: error[usage]: tln probe --share needs a header alias: the project file has no hash"
				and Fail.line(ProbeShare.bundle({})) == "tln: error[usage]: tln probe --share needs a header alias: a bundle file can be a hash before its release"
					and ProbeShare.no_hash({}).kind.name() == "usage"
						and ProbeShare.bundle({}).kind.name() == "usage"
}

# R-PB6, R-OUT2 (proposal): the lines and the `data` of a share. One line for the send, one line for each fact that stayed back, in the order of `kept_back`. 1 fact is `fact`, else `facts`.
expect {
	shared = { requests: 1, sent: 3, counted: 2, first: 1, skipped: 1 }
	one = { requests: 1, sent: 1, counted: 1, first: 1, skipped: 0 }
	back = [{ nightly: c2, target: "any", why: Result }, { nightly: c3, target: "x64musl", why: Target }, { nightly: c4, target: "any", why: BotRow }]
	lines = ProbeShare.lines({ label: "acme/json 2.1.0", shared, kept_back: back, unsent: [] })
	single = ProbeShare.lines({ label: "acme/json 2.1.0", shared: one, kept_back: [], unsent: [] })
	lines
		== [
			"shared 3 facts of acme/json 2.1.0: 2 counted, 1 skipped by the registry\n",
			"  not shared: ${c2} any: a hang, or a machine error\n",
			"  not shared: ${c3} x64musl: the registry does not take this target for the kind of the hash\n",
			"  not shared: ${c4} any: the registry has a bot result for it\n",
		]
		and single == ["shared 1 fact of acme/json 2.1.0: 1 counted, 0 skipped by the registry\n"]
}

# R-PB6, R-OUT2, R-OUT4 (proposal): the reasons that the other filters give, in the lines and in the words of `data`.
expect {
	shared = { requests: 0, sent: 0, counted: 0, first: 0, skipped: 0 }
	reasons = [Kind, Compiler, NotInAnswer]
	back = reasons.map_with_index(|why, i| { nightly: c1, target: "t${i.to_str()}", why })
	lines = ProbeShare.lines({ label: "x 1.0.0", shared, kept_back: back, unsent: [] })
	lines.drop_first(1)
		== [
			"  not shared: ${c1} t0: not a unit check\n",
			"  not shared: ${c1} t1: the compiler has no recorded sha256 or is not a nightly\n",
			"  not shared: ${c1} t2: the hash is not in an answer of the registry\n",
		]
		and JsonDoc.render(ProbeShare.data({ shared, kept_back: back, unsent: [] }))
			== "{\"share\":{\"requests\":0,\"sent\":0,\"counted\":0,\"first\":0,\"skipped\":0,\"not_shared\":[{\"nightly\":\"${c1}\",\"target\":\"t0\",\"reason\":\"kind\"},{\"nightly\":\"${c1}\",\"target\":\"t1\",\"reason\":\"compiler\"},{\"nightly\":\"${c1}\",\"target\":\"t2\",\"reason\":\"not-in-answer\"}]}}"
}

# R-PB6, R-OUT2, R-OUT4 (proposal): the `data` words of the other reasons, and a share with no fact back.
expect {
	shared = { requests: 2, sent: 501, counted: 500, first: 100, skipped: 1 }
	back = [{ nightly: c1, target: "any", why: BotRow }, { nightly: c1, target: "x", why: Result }, { nightly: c1, target: "y", why: Target }]
	words = JsonDoc.render(ProbeShare.data({ shared, kept_back: back, unsent: [] }))
	JsonDoc.render(ProbeShare.data({ shared, kept_back: [], unsent: [] })) == "{\"share\":{\"requests\":2,\"sent\":501,\"counted\":500,\"first\":100,\"skipped\":1,\"not_shared\":[]}}"
		and words.contains("\"reason\":\"bot-row\"")
			and words.contains("\"reason\":\"result\"")
				and words.contains("\"reason\":\"target\"")
}

# R-PB6 (4), (5), Q495, Q498: `nothing to share` when no request went and no row is unsent (then the lines of the kept back facts). Rows that are `unsent` are listed after the kept back facts, also with no request that worked (a first request that failed): the `shared` line then.
expect {
	none = { requests: 0, sent: 0, counted: 0, first: 0, skipped: 0 }
	back = [{ nightly: c2, target: "any", why: Result }]
	left = [queued("H1", c3, "any", Pass), queued("H2", c4, "x", Fail)]
	nothing = ProbeShare.lines({ label: "x 1.0.0", shared: none, kept_back: back, unsent: [] })
	failed_first = ProbeShare.lines({ label: "x 1.0.0", shared: none, kept_back: [], unsent: left })
	data = JsonDoc.render(ProbeShare.data({ shared: none, kept_back: back, unsent: left }))
	nothing == ["nothing to share\n", "  not shared: ${c2} any: a hang, or a machine error\n"]
		and failed_first
			== [
				"shared 0 facts of x 1.0.0: 0 counted, 0 skipped by the registry\n",
				"  not shared: ${c3} any: not sent\n",
				"  not shared: ${c4} x: not sent\n",
			]
			and data.ends_with("\"not_shared\":[{\"nightly\":\"${c2}\",\"target\":\"any\",\"reason\":\"result\"},{\"nightly\":\"${c3}\",\"target\":\"any\",\"reason\":\"not-sent\"},{\"nightly\":\"${c4}\",\"target\":\"x\",\"reason\":\"not-sent\"}]}}")
}

# R-PB6 (3), Q491: the body of the one closure request. `groups` empty, `hashes` the one hash, `compilers` from the oldest to the newest nightly of the facts that can be sent without the answer: a unit check, no hang, a nightly in `recorded`.
# A build row, a hang, an unrecorded nightly, a release `X.Y.Z` and a fact of another hash do not count. No such fact: no `compilers`.
expect {
	r = |facts, recorded| ProbeShare.closure_request({ hash: "H1", facts, recorded })
	all = [fact("H1", c4, "any", Pass, ""), fact("H1", c2, "any", Fail, ""), fact("H1", c3, "any", Pass, ""), fact("H1", c1, "any", Hang, ""), fact("H1", c5, "x", Pass, "abc"), fact("H2", "nightly-2026-09-01-aaaaaaa", "any", Pass, ""), fact("H1", "0.4.1", "any", Pass, "")]
	rec = [c1, c2, c3, c4, c5, "0.4.1", "nightly-2026-09-01-aaaaaaa"]
	one = r([fact("H1", c3, "any", Pass, "")], [c3])
	r(all, rec) == { groups: [], hashes: ["H1"], compilers: Ok({ from: Ok(c2), to: Ok(c4) }) }
		and one.compilers == Ok({ from: Ok(c3), to: Ok(c3) })
}

# R-PB6 (1), (4), Q494, Q498, R-EC15: `--offline` and the cap are exit 15 (kind `network`).
expect {
	Fail.line(ProbeShare.offline({})) == "tln: error[network]: tln probe --share needs the network: --offline sends no request"
		and ProbeShare.offline({}).kind.name() == "network"
			and Fail.line(ProbeShare.unfinished({ requests: 20, count: 500 })) == "tln: error[network]: tln probe --share sent 20 requests and stopped: 500 facts are not shared. Run it again to send the rest."
				and ProbeShare.unfinished({ requests: 20, count: 500 }).kind.name() == "network"
}

# R-PB6 (3), (5), Q495, Q503: with no answer (no request was sent because no fact passes the local filters 2, 3 and 6) the reasons are still the filter reasons: a hang is `Result`, a build row `Kind`,
# an unrecorded compiler `Compiler`, in the order of the nightlies. A fact that passes the local filters has `NotInAnswer`. A hash in no `artifacts` of an answer that was read shares nothing (Q504).
expect {
	facts = [fact("H1", c1, "any", Hang, ""), fact("H1", c2, "x", Pass, "abc"), fact("H1", c3, "any", Pass, ""), fact("H1", c4, "any", Pass, "")]
	got = ProbeShare.rows({ ..input("H1", facts), recorded: [c1, c2, c4], answers: [] })
	got.rows == []
		and got.kept_back
			== [
				{ nightly: c1, target: "any", why: Result },
				{ nightly: c2, target: "x", why: Kind },
				{ nightly: c3, target: "any", why: Compiler },
				{ nightly: c4, target: "any", why: NotInAnswer },
			]
}
