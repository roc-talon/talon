app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Ident
import lib.Index
import lib.Oracle
import lib.Pick
import lib.Release

main! = |_args| Ok({})

now = 1792065600

day = 86400

h_a = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h_b = "J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr"

h_c = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

json_url = |version| "https://github.com/someone/roc-json/releases/download/${version}/${h_a}.tar.zst"

pf_url = |version| "https://github.com/roc-lang/basic-cli/releases/download/${version}/${h_c}.tar.zst"

http_url = |version| "https://github.com/roc-lang/http/releases/download/${version}/${h_b}.tar.zst"

## A candidate of the index that was published `days` days before `now`.
cand = |url, days| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - days * day, size: 1 }
	Err(_) => crash "bad test URL"
}

slot = |id, is_platform, ranges, current, free, candidates| { id, is_platform, ranges, current, hold: if free Free else Held, named: Err(None), candidates, files: [] }

package_fact = |url| { url, release: { kind: Package, pf: Err(None), deps: [] } }

step = |slots, facts, strategy, min_age, snapshot| Oracle.step({ slots, strategy, now, min_age, snapshot, facts, unmanaged: [], paths: [], second: Bool.False })

view = |r| match r {
	Need(urls) => Err(Ok(urls))
	Done(chosen) => Ok(chosen.map(|c| (c.id, c.version, c.change, c.note)))
	Fail(fail) => Err(Err(fail.line()))
}

facts_of = |slots| slots.join_map(|s| s.candidates.map(|c| c.url).concat(s.current.map_ok(|u| [u]) ?? []).map(package_fact))

# R-PH10 R-C1 R-C6 R-C7 R-C9 R-VA6 R-DI9 R-DT2 R-C4 R-SP1 R-NS4 R-SE3: the choice for one slot, with the facts known (no `Need`). The range limits the versions (R-C1). `min-release-age` hides a release that is newer
# than the age, and a snapshot time hides a release published after it (R-C7); both never hide the header value (R-C9), also when the index no longer lists it, and never hide a version that the user named
# (R-NS4: then a note names its age). R-SE3: `min-release-age` is the defence against a new release of a maintainer that is taken over. The strategy gives the newest (`Highest`) or the oldest (`Lowest`) version in the range (R-DI9, R-VA6). A held slot has the value of the header only (R-SP1). The result does
# not depend on the order of the candidates or of the facts (R-DT2). A fact that shows the wrong kind drops the candidate (R-C4).
expect {
	json = |version| json_url(version)
	list = [cand(json("2.1.0"), 30), cand(json("2.2.0"), 10), cand(json("2.3.0"), 3), cand(json("2.4.0"), 1), cand(json("3.0.0"), 20), cand(json("2.0.5"), 40)]
	base = slot("json", Bool.False, [">=2.1.0, <3.0.0"], Ok(json("2.1.0")), Bool.True, list)
	run = |s, strategy, min_age, snapshot| view(step([s], facts_of([s]), strategy, min_age, snapshot))
	moved = |version| Ok([("json", version, Move("2.1.0"), Err(None))])
	kept = |version| Ok([("json", version, Keep, Err(None))])
	no_snap = Err(None)
	reversed = { ..base, candidates: list.rev() }
	just_old = { ..base, current: Ok(json("2.5.0")), candidates: [cand(json("2.5.0"), 1), cand(json("2.4.0"), 30)] }
	other = { ..base, current: Ok(json("2.4.0")), candidates: [cand(json("2.5.0"), 1), cand(json("2.4.0"), 30)] }
	gone = { ..base, candidates: [cand(json("2.2.0"), 1)] }
	named = { ..base, ranges: ["=2.4.0"], named: Ok("2.4.0") }
	two_ranges = { ..base, ranges: [">=2.1.0, <3.0.0", "^2.2"] }
	twin_a = json("2.3.0")
	twin_b = "https://github.com/someone/roc-json/releases/download/v2.3.0/${h_b}.tar.zst"
	twins = { ..base, candidates: [cand(twin_b, 10), cand(twin_a, 10)] }
	twins_reversed = { ..base, candidates: [cand(twin_a, 10), cand(twin_b, 10)] }
	urls = |s| match step([s], facts_of([s]), Highest, 2 * day, no_snap) {
		Done(chosen) => Ok(chosen.map(|c| c.url))
		_ => Err(None)
	}
	wrong_kind = step([base], facts_of([base]).map(|f| if f.url == json("2.3.0") { url: f.url, release: { kind: Platform, pf: Err(None), deps: [] } } else f), Highest, 2 * day, no_snap)
	rows = [
		("highest in the range, 2.4.0 is too new, 3.0.0 is outside (R-C1, R-C7)", run(base, Highest, 2 * day, no_snap), moved("2.3.0")),
		("min-release-age 0d turns the age off (R-C7)", run(base, Highest, 0, no_snap), moved("2.4.0")),
		("lowest: the header value is the lowest in the range", run(base, Lowest, 2 * day, no_snap), kept("2.1.0")),
		("a held slot has its header value only (R-SP1)", run({ ..base, hold: Held }, Highest, 2 * day, no_snap), kept("2.1.0")),
		("a snapshot time hides the releases after it (R-DT4)", run(base, Highest, 0, Ok(now - 5 * day)), moved("2.2.0")),
		("the header value is not hidden by the age (R-C9)", run(just_old, Highest, 2 * day, no_snap), Ok([("json", "2.5.0", Keep, Err(None))])),
		("a new release that is not the header value is hidden", run(other, Highest, 2 * day, no_snap), Ok([("json", "2.4.0", Keep, Err(None))])),
		("the header value stays when the index no longer lists it (R-C9)", run(gone, Highest, 2 * day, no_snap), kept("2.1.0")),
		("a named version is not hidden, and a note names its age (R-NS4, R-C7)", run(named, Highest, 2 * day, no_snap), Ok([("json", "2.4.0", Move("2.1.0"), Ok("json 2.4.0 is 1d old (min-release-age 2d)"))])),
		("2 ranges of 2 members (R-WS2), highest", run(two_ranges, Highest, 2 * day, no_snap), moved("2.3.0")),
		("2 ranges of 2 members, lowest", run(two_ranges, Lowest, 2 * day, no_snap), moved("2.2.0")),
		("the order of the candidates does not matter (R-DT2)", run(reversed, Highest, 2 * day, no_snap), moved("2.3.0")),
		("a release that is exactly min-release-age old is visible (R-C7)", run(base, Highest, 3 * day, no_snap), moved("2.3.0")),
		("a release published at the snapshot time is visible (R-DT4)", run(base, Highest, 0, Ok(now - 3 * day)), moved("2.3.0")),
		("the order of the facts does not matter (R-DT2)", view(step([base], facts_of([base]).rev(), Highest, 2 * day, no_snap)), moved("2.3.0")),
		("a fact with the wrong kind drops the candidate (R-C4)", view(wrong_kind), moved("2.2.0")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	url_rows = [
		("one version in 2 URL forms: the lower URL wins (R-DT2)", urls(twins), Ok([twin_a])),
		("the same, the candidates in reversed order (R-DT2)", urls(twins_reversed), Ok([twin_a])),
	]
	bad_urls = url_rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_urls
	bad == [] and bad_urls == []
}

# R-PH10 R-C2 R-C3 R-VA6 R-SP11 R-DT2: the tuple of 2 slots, and the protocol of the step. The first slot in the order of `priority` has the strongest rank: it gets its best release, and the next slots get the best that
# fits. R-C3: `json 2.3.0` names the platform 0.25.1, so with the platform last the tuple is (json 2.3.0, pf 0.25.1), and with the platform first it is (pf 0.25.2, json 2.2.0). R-C2 (one level): a release that has a
# dependency on a higher version of the group of another slot than the chosen one is a conflict. A candidate with no fact is taken as fit, so the step gives `Need` with the URLs of the tuple that it found, in the order
# of the slots, and the next call has more facts. `Fail` is exit 10 (`no_tuple`, R-PH10), with the first slot that has no candidate (R-PH13: a case with one release has no other tuple).
expect {
	jc = |version, days| cand(json_url(version), days)
	pc = |version, days| cand(pf_url(version), days)
	json_slot = slot("json", Bool.False, ["^2"], Ok(json_url("2.1.0")), Bool.True, [jc("2.3.0", 30), jc("2.2.0", 30)])
	pf_slot = slot("pf", Bool.True, ["0.25.*"], Ok(pf_url("0.25.0")), Bool.True, [pc("0.25.2", 30), pc("0.25.1", 30)])
	json_names_pf = { url: json_url("2.3.0"), release: { kind: Package, pf: Ok(pf_url("0.25.1")), deps: [] } }
	json_plain = { url: json_url("2.2.0"), release: { kind: Package, pf: Err(None), deps: [] } }
	json_current = package_fact(json_url("2.1.0"))
	pf_fact = |version| { url: pf_url(version), release: { kind: Platform, pf: Err(None), deps: [] } }
	all_facts = [json_names_pf, json_plain, json_current, pf_fact("0.25.0"), pf_fact("0.25.1"), pf_fact("0.25.2")]
	json_chosen = |v| ("json", v, Move("2.1.0"), Err(None))
	pf_chosen = |v| ("pf", v, Move("0.25.0"), Err(None))
	one = |slots, facts| view(step(slots, facts, Highest, 2 * day, Err(None)))

	# R-C2: http is held at 1.8.0. json 2.3.0 has a dependency on http 1.9.0, so json 2.2.0 (http 1.5.0) is the choice.
	http_slot = slot("http", Bool.False, ["^1"], Ok(http_url("1.8.0")), Bool.False, [])
	json_needs_http = { url: json_url("2.3.0"), release: { kind: Package, pf: Err(None), deps: [http_url("1.9.0"), "../util/main.roc"] } }
	json_old_http = { url: json_url("2.2.0"), release: { kind: Package, pf: Err(None), deps: [http_url("1.5.0")] } }
	http_fact = package_fact(http_url("1.8.0"))
	c2_facts = [json_needs_http, json_old_http, http_fact]

	rounds = [
		("round 1: no facts, the tuple of the first candidates", one([json_slot, pf_slot], []), Err(Ok([json_url("2.3.0"), pf_url("0.25.2")]))),
		("round 2: json names 0.25.1, so 0.25.2 is dropped, 0.25.1 is needed", one([json_slot, pf_slot], [json_names_pf, pf_fact("0.25.2")]), Err(Ok([pf_url("0.25.1")]))),
		("round 3: all facts of the tuple are known", one([json_slot, pf_slot], all_facts), Ok([json_chosen("2.3.0"), pf_chosen("0.25.1")])),
		("the platform first: the platform wins (R-VA6, R-SP11)", one([pf_slot, json_slot], all_facts), Ok([pf_chosen("0.25.2"), json_chosen("2.2.0")])),
		("the order of the facts does not matter (R-DT2)", one([json_slot, pf_slot], all_facts.rev()), Ok([json_chosen("2.3.0"), pf_chosen("0.25.1")])),
		("R-C2: a dependency on a higher version of a held slot", one([json_slot, http_slot], c2_facts), Ok([json_chosen("2.2.0"), ("http", "1.8.0", Keep, Err(None))])),
		("R-C2: the other order of the slots", one([http_slot, json_slot], c2_facts), Ok([("http", "1.8.0", Keep, Err(None)), json_chosen("2.2.0")])),
		("a held slot needs its fact too", one([http_slot], []), Err(Ok([http_url("1.8.0")]))),
	]
	bad_rounds = rounds.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_rounds

	fail_line = |slots, facts| match step(slots, facts, Highest, 2 * day, Err(None)) {
		Fail(fail) => "${fail.kind.code().to_str()} ${fail.line()}"
		_ => "no failure"
	}
	too_new = slot("json", Bool.False, ["^2"], Err(None), Bool.True, [jc("2.3.0", 1), jc("2.2.0", 1)])
	outside = slot("json", Bool.False, ["^5"], Ok(json_url("2.1.0")), Bool.True, [jc("2.3.0", 30), jc("3.0.0", 30), jc("1.0.0", 30)])
	only_platforms = [{ url: json_url("2.3.0"), release: { kind: Platform, pf: Err(None), deps: [] } }, { url: json_url("2.2.0"), release: { kind: App, pf: Err(None), deps: [] } }]
	no_fit_json = slot("json", Bool.False, ["^2"], Err(None), Bool.True, [jc("2.3.0", 30)])
	no_fit_pf = slot("pf", Bool.True, ["0.25.*"], Err(None), Bool.True, [pc("0.25.2", 30)])
	fails = [
		("no release in the ranges (R-C1)", fail_line([outside], facts_of([outside])), "10 tln: error[no_tuple]: no tuple works: json has no release that satisfies ^5 (4 releases, 4 outside the ranges, 0 too new)"),
		("all releases are too new (R-C7)", fail_line([too_new], facts_of([too_new])), "10 tln: error[no_tuple]: no tuple works: json has no release that satisfies ^2 (2 releases, 0 outside the ranges, 2 too new)"),
		("2 ranges in the text", fail_line([{ ..outside, ranges: ["^5", ">=1.0.0, <2.0.0"] }], facts_of([outside])), "10 tln: error[no_tuple]: no tuple works: json has no release that satisfies ^5 and >=1.0.0, <2.0.0 (4 releases, 4 outside the ranges, 0 too new)"),
		("a package entry and only platform releases (R-C4)", fail_line([{ ..too_new, candidates: [jc("2.3.0", 30), jc("2.2.0", 30)] }], only_platforms), "10 tln: error[no_tuple]: no tuple works: json has no release of the kind package in ^2 (R-C4)"),
		("one release each, and they do not fit (R-C3, R-PH13)", fail_line([no_fit_json, no_fit_pf], [json_names_pf, pf_fact("0.25.2")]), "10 tln: error[no_tuple]: no tuple works: the releases of json, pf do not fit together (R-C2, R-C3)"),
	]
	bad_fails = fails.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad_fails
	bad_rounds == [] and bad_fails == []
}

# R-C3 R-C4 R-C2 R-DI7 R-H7: what the step needs from the header of a package release (`main.roc` of the fetched package): the kind (the first keyword), the platform that it names (`pf: platform "<url>"`, as in the
# source), and the value of each other entry except `roc:` (a path entry too). A text with no header, or with a header that does not parse, is a failure of kind `input` with the line.
expect {
	cli = pf_url("0.25.0")
	read = |text| match Release.read({ path: "/pkgs/x/main.roc", text }) {
		Ok(r) => Ok((r.kind, r.pf, r.deps))
		Err(e) => Err(e.line())
	}
	rows = [
		("an app", "app [main!] {\n\tpf: platform \"${cli}\",\n\tjson: \"${json_url("2.1.0")}\",\n\troc: \"nightly-2026-10-09-258ab27\",\n\tutil: \"../util/main.roc\",\n}\n", Ok((App, Ok(cli), [json_url("2.1.0"), "../util/main.roc"]))),
		("a package that names a platform", "package [Lib] {\n\tpf: platform \"${cli}\",\n}\n", Ok((Package, Ok(cli), []))),
		("a package with no platform", "package [Lib] { http: \"${http_url("1.8.0")}\" }\n", Ok((Package, Err(None), [http_url("1.8.0")]))),
		("a platform", "platform \"cli\"\n\trequires {} { main! : () => {} }\n\texposes [Stdout]\n\tpackages { json: \"${json_url("2.1.0")}\" }\n\tprovides [main_for_host!]\n", Ok((Platform, Err(None), [json_url("2.1.0")]))),
		("no header", "main! = |_| Ok({})\n", Err("tln: error[input]: /pkgs/x/main.roc: the package has no app, package or platform header")),
		("a header that does not parse", "package [Lib] {\n\thttp: 5,\n}\n", Err("tln: error[input]: /pkgs/x/main.roc:2: the header is not valid")),
	]
	bad = rows.keep_if(|(_, text, want)| read(text) != want).map(|(label, text, want)| (label, want, read(text)))
	dbg bad
	bad == []
}
