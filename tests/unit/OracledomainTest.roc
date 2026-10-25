import lib.Db
import lib.Epochs
import lib.Ident
import lib.Nightlies
import lib.Oracle
import lib.Pick

OracledomainTest :: [].{}

now = 1792065600

day = 86400

# The domain D (R-EP11, oldest first): 5 nightlies. n3 is the held compiler H.
n1 = "nightly-2026-10-01-1111111"

n2 = "nightly-2026-10-02-2222222"

n3 = "nightly-2026-10-03-3333333"

n4 = "nightly-2026-10-04-4444444"

n5 = "nightly-2026-10-05-5555555"

d5 = [n1, n2, n3, n4, n5]

held = n3

# A release URL of the fixture host (as in `oracleprobe.roc`).
u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

hash = |url| match Ident.of_url(url) {
	Ok(ident) => ident.hash
	Err(_) => crash "bad test URL"
}

cand = |url, days| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - days * day, size: 1 }
	Err(_) => crash "bad test URL"
}

fact = |url, deps| { url, release: { kind: Package, pf: Err(None), deps } }

slot = |id, ranges, current, hold, candidates| { id, is_platform: Bool.False, ranges, current: Ok(current), hold, named: Err(None), candidates, files: [] }

input = |slots, facts| { slots, strategy: Highest, now, min_age: 2 * day, snapshot: Err(None), facts, unmanaged: [], paths: [], second: Bool.False }

row = |url, id, outcome, modules| { hash: hash(url), nightly: id, target: "any", outcome, modules, closure: "" }

key = |url, id| { hash: hash(url), nightly: id, target: "any" }

release = |id| { id, published_at: 0, asset: Err(NoAsset) }

# The inferred facts of the real `Epochs.epochs` over D and the rows: the command gives them to the step (R-EP10).
inferred_of = |rows| Epochs.epochs(d5.map(release), rows).inferred

compat = |checks, probes, domain| { compiler: Ok(held), checks, looked: [], probes, conflicts: [], used: [], domain, inferred: [] }

view = |r| match r {
	Need(urls) => "need ${Str.join_with(urls.map(|url| url.drop_prefix("https://github.com/acme/")), " ")}"
	Pairs(pairs) => "pairs ${Str.join_with(pairs.map(|p| "${p.id.drop_prefix("https://github.com/acme/")}@${p.nightly}${if p.is_platform "!" else ""}"), " ")}"
	Scan(s) => "scan ${Str.join_with(s.ids.map(|url| url.drop_prefix("https://github.com/acme/")), " ")}"
	Wide => "wide"
	Done(chosen) => "done ${Str.join_with(chosen.map(|c| "${c.id}=${c.version}"), " ")}"
	Fail(fail) => fail.line()
}

json = |v| u("json", v)

p = |ver| "json/releases/download/${ver}/jsonx${ver.replace_each(".", "x")}.tar.zst"

# json has 3 releases, 1.0.0 is the header value. `exact` has the one value 3.0.0 (an exact range, R-OV2): its fail is a failure with a probe cause.
json_slot = slot("json", [], json("1.0.0"), Free, [cand(json("1.0.0"), 30), cand(json("2.0.0"), 30), cand(json("3.0.0"), 30)])

exact = slot("json", ["=3.0.0"], json("1.0.0"), Free, [cand(json("1.0.0"), 30), cand(json("3.0.0"), 30)])

json_facts = [fact(json("1.0.0"), []), fact(json("2.0.0"), []), fact(json("3.0.0"), [])]

hard = |ver, at| row(json(ver), at, Fail, [])

pass = |ver, at| row(json(ver), at, Pass, [])

first_line = "tln: error[no_tuple]: no tuple works: the unit check on ${held} fails for acme/json 3.0.0 (no module is named)"

fix = "  fix: tln roc use <id>\n       or tln upgrade roc"

# R-EP9 R-RP2 Q1 (b) of slice 036: when does the step ask for D (`Wide`)? Only when `domain` is `Err(NotRead)` and (a) the verdict would be a `Fail` that has a probe cause (the explanation and the hint need the other compilers), or (b) `probes` is `Off` and the verdict would
# be a `Pairs` (a lookup round: with `--no-probe` the db and the inferred facts are the only evidence). Never for a `Done`, a `Need`, a `Pairs` of `Allowed`, a `Fail` that has no probe cause, and never with no compiler (`--no-check`, `verify`). With `Ok(D)` the step never gives `Wide`.
# A D that does not have the held compiler (a path compiler, an id of the other tag form) or is empty is used as `[H]`: the answer is the answer of `Ok([H])`, never a failure of the compiler slot.
expect {
	run = |slots, checks, probes, domain| view(Oracle.step_probed(input(slots, json_facts), compat(checks, probes, domain)))
	run_off = |slots, checks, looked, domain| view(Oracle.step_probed(input(slots, json_facts), { ..compat(checks, Off, domain), looked }))
	a_slot = slot("a", [], u("a", "1.0.0"), Free, [cand(u("a", "1.0.0"), 30)])
	b_slot = slot("b", [], u("b", "1.0.0"), Held, [])
	dep = view(Oracle.step_probed(input([a_slot, b_slot], [fact(u("a", "1.0.0"), [u("b", "1.5.0")]), fact(u("b", "1.0.0"), [])]), compat([], Allowed, Err(NotRead))))
	none = { ..compat([hard("3.0.0", held)], Allowed, Err(NotRead)), compiler: Err(None) }
	failed = run([exact], [hard("3.0.0", held)], Allowed, Err(NotRead))
	plain = run([exact], [hard("3.0.0", held)], Allowed, Ok([held]))
	rows = [
		("Allowed, a unit fail of the only value, D not read: the step asks for D", failed, "wide"),
		("the same with D read: the failure", run([exact], [hard("3.0.0", held)], Allowed, Ok(d5)).starts_with(first_line) |> Str.inspect, Str.inspect(Bool.True)),
		("a hang is a probe cause too: wide", run([exact], [row(json("3.0.0"), held, Hang, [])], Allowed, Err(NotRead)), "wide"),
		("a crash: wide", run([exact], [row(json("3.0.0"), held, Crash, [])], Allowed, Err(NotRead)), "wide"),
		("Allowed, a pass: done, D is not read", run([json_slot], [pass("3.0.0", held)], Allowed, Err(NotRead)), "done json=3.0.0"),
		("Allowed, a pair with no fact: the pair, D is not read", run([json_slot], [], Allowed, Err(NotRead)), "pairs ${p("3.0.0")}@${held}"),
		("Allowed, a fail that has no probe cause (a release needs a higher version of a held group): the failure of the step, D is not read", dep, "tln: error[no_tuple]: no tuple works: the releases of a, b do not fit together (R-C2, R-C3)"),
		("Off, the best release is not looked up: a lookup round, so D is asked for", run_off([json_slot], [], [], Err(NotRead)), "wide"),
		("Off, with D read: the lookup round is a `Pairs`", run_off([json_slot], [], [], Ok(d5)), "pairs ${p("3.0.0")}@${held}"),
		("Off, nothing changes (the header value is the best release): no lookup, so D is not read", view(Oracle.step_probed(input([slot("json", [], json("3.0.0"), Free, [cand(json("3.0.0"), 30)])], json_facts), compat([], Off, Err(NotRead)))), "done json=3.0.0"),
		("Off, a looked-up release with no row: it is fit, D is not read", run_off([json_slot], [], [key(json("3.0.0"), held)], Err(NotRead)), "done json=3.0.0"),
		("Off, a looked-up release with a hard fail row and no other value: a failure with a probe cause, D is asked for", run_off([exact], [hard("3.0.0", held)], [key(json("3.0.0"), held)], Err(NotRead)), "wide"),
		("no compiler (`--no-check`, `verify`): never wide, the row is not read", view(Oracle.step_probed(input([exact], json_facts), none)), "done json=3.0.0"),
		("D without the held compiler: the answer of [H], and no failure of the compiler slot", run([exact], [hard("3.0.0", held)], Allowed, Ok([n1, n2, n4, n5])), plain),
		("an empty D: the same", run([exact], [hard("3.0.0", held)], Allowed, Ok([])), plain),
		("D with the held compiler alone: the failure has the text of slice 036b and the fix block of R-RP2", plain, "${first_line}\n${fix}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-EP10 R-EP9 R-EP14 R-EP7 R-EP8 R-RP2 D2 (slice 036c): the checks of D and the failure with D read. The step gets the rows of the db (any compiler of D) and `Epochs.epochs` of D and the rows (here the real function). The compiler slot keeps one value, H.
# The text of a failure is the first line (slice 036b) and the lines of `Explain.lines`: a cause line when the fail goes past H or is inferred, then the fix block; the oldest nightly that works is in option 1 when the facts show one.
# R-EP8: an inferred fact never decides with `Allowed`: the step asks for the real fact (a `Pairs`). R-EP9: with `Off` it decides, and the failure says which compilers are inferred. An inferred fact never replaces a real row or the assumed pass of the header value on H (D2 of slice 036b).
expect {
	exact_run = |checks, probes, looked, inferred| view(Oracle.step_probed(input([exact], json_facts), { ..compat(checks, probes, Ok(d5)), looked, inferred }))
	slots2 = [json_slot]
	free_run = |checks, probes, looked, inferred| view(Oracle.step_probed(input(slots2, json_facts), { ..compat(checks, probes, Ok(d5)), looked, inferred }))
	all3 = [key(json("1.0.0"), held), key(json("2.0.0"), held), key(json("3.0.0"), held)]
	# real fails of 3.0.0 on n2 and n4, nothing on n3: case (b) of R-EP6 infers a fail on n3
	between = [hard("3.0.0", n2), hard("3.0.0", n4)]
	inf = inferred_of(between)
	# the header value 1.0.0 fails on n2 and n4 too, so its fail on n3 is inferred
	cur_between = [hard("1.0.0", n2), hard("1.0.0", n4), hard("3.0.0", held)]
	# the header value 1.0.0 fixed (`=1.0.0`): a real fail on H and on n5, so n4 is an inferred fail. Only H has the assumed pass (D2 revisit), so on n4 the inferred fail counts and the interval goes on.
	cur_exact = slot("json", ["=1.0.0"], json("1.0.0"), Free, [cand(json("1.0.0"), 30)])
	cur_rows = [hard("1.0.0", held), hard("1.0.0", n5)]
	cur_run = view(Oracle.step_probed(input([cur_exact], json_facts), { ..compat(cur_rows, Off, Ok(d5)), looked: [key(json("1.0.0"), held)], inferred: inferred_of(cur_rows) }))
	rows = [
		("D2 revisit: the header value has no assumed pass on n4 (not H): its inferred fail on n4 is in the interval, with the mark", cur_run, "tln: error[no_tuple]: no tuple works: the unit check on ${held} fails for acme/json 1.0.0 (no module is named)\n  acme/json 1.0.0 fails on ${held} .. ${n5} (inferred on ${n4})\n${fix}"),
		("a fail interval on D: the cause line names its ends, and the hint is the oldest nightly with a real pass", exact_run([pass("3.0.0", n1), hard("3.0.0", n2), hard("3.0.0", held), hard("3.0.0", n4), pass("3.0.0", n5)], Allowed, [], []), "${first_line}\n  acme/json 3.0.0 fails on ${n2} .. ${n4}\n  fix: tln roc use ${n1} (the oldest nightly that works)\n       or tln upgrade roc"),
		("a fail on H alone, a pass on the other compilers: no cause line, the hint names the oldest", exact_run([pass("3.0.0", n1), pass("3.0.0", n2), hard("3.0.0", held), pass("3.0.0", n4)], Allowed, [], []), "${first_line}\n  fix: tln roc use ${n1} (the oldest nightly that works)\n       or tln upgrade roc"),
		("the hint can be newer than H: the facts show a pass on n4 only", exact_run([hard("3.0.0", held), pass("3.0.0", n4)], Allowed, [], []), "${first_line}\n  fix: tln roc use ${n4} (the oldest nightly that works)\n       or tln upgrade roc"),
		("a fail on H and no other fact: no hint", exact_run([hard("3.0.0", held)], Allowed, [], []), "${first_line}\n${fix}"),
		("Allowed: the inferred fact on n3 does not decide, the step asks for the real fact of the pair (R-EP8)", exact_run(between, Allowed, [], inf), "pairs ${p("3.0.0")}@${held}"),
		("Off: the inferred fail on n3 decides: no tuple, and the failure marks n3 as inferred (R-EP9, R-EP14)", exact_run(between, Off, [key(json("3.0.0"), held)], inf), "${first_line}\n  acme/json 3.0.0 fails on ${n2} .. ${n4} (inferred on ${held})\n${fix}"),
		("Off, an inferred fail of 3.0.0 on n3: the release is out and the next release is the result", free_run(between, Off, all3, inf), "done json=2.0.0"),
		("Allowed, a fault is real only: a hang on n2 and n4 gives no inferred fact (R-EP5), so no change", exact_run([row(json("3.0.0"), n2, Hang, []), row(json("3.0.0"), n4, Hang, [])], Allowed, [], inferred_of([row(json("3.0.0"), n2, Hang, []), row(json("3.0.0"), n4, Hang, [])])), "pairs ${p("3.0.0")}@${held}"),
		("D2: the header value on H is assumed to pass, also when its fail on H is inferred: it stays the result (Off)", free_run(cur_between.concat([hard("2.0.0", held)]), Off, all3, inferred_of(cur_between)), "done json=1.0.0"),
		("a real fail row of the header value on H beats the assumed pass and the fact of the other compilers", free_run([hard("1.0.0", held), hard("3.0.0", held), hard("2.0.0", held)], Allowed, [], []).starts_with("tln: error[no_tuple]") |> Str.inspect, Str.inspect(Bool.True)),
		("a stale row of a compiler that is not in D is not read", exact_run([hard("3.0.0", held), pass("3.0.0", "nightly-2026-09-01-9999999")], Allowed, [], []), "${first_line}\n${fix}"),
		("the same rows in another order (R-DT2)", exact_run([pass("3.0.0", n5), hard("3.0.0", n4), hard("3.0.0", held), hard("3.0.0", n2), pass("3.0.0", n1)], Allowed, [], []), "${first_line}\n  acme/json 3.0.0 fails on ${n2} .. ${n4}\n  fix: tln roc use ${n1} (the oldest nightly that works)\n       or tln upgrade roc"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-J5 R-OUT2 R-EP14 (slice 036c): `fail.details` of a failure with a probe cause is `Explain.details`: the held compiler, each cause, the hint. A failure with no probe cause has no details.
expect {
	rows3 = [pass("3.0.0", n1), hard("3.0.0", n2), hard("3.0.0", held), hard("3.0.0", n4)]
	detail = |r| match r {
		Fail(f) => match f.details {
			Ok(d) => d.render()
			Err(_) => "no details"
		}
		_ => "no failure"
	}
	run = |slots, checks| detail(Oracle.step_probed(input(slots, json_facts), compat(checks, Allowed, Ok(d5))))
	a_slot = slot("a", [], u("a", "1.0.0"), Free, [cand(u("a", "1.0.0"), 30)])
	b_slot = slot("b", [], u("b", "1.0.0"), Held, [])
	dep = detail(Oracle.step_probed(input([a_slot, b_slot], [fact(u("a", "1.0.0"), [u("b", "1.5.0")]), fact(u("b", "1.0.0"), [])]), compat([], Allowed, Ok(d5))))
	rows = [
		("the cause, its interval and the hint", run([exact], rows3), "{\"compiler\":\"${held}\",\"causes\":[{\"release\":\"acme/json 3.0.0\",\"kind\":\"fail\",\"modules\":[],\"from\":\"${n2}\",\"to\":\"${n4}\",\"inferred\":[]}],\"hint\":\"${n1}\"}"),
		("no hint", run([exact], [hard("3.0.0", held)]), "{\"compiler\":\"${held}\",\"causes\":[{\"release\":\"acme/json 3.0.0\",\"kind\":\"fail\",\"modules\":[],\"from\":\"${held}\",\"to\":\"${held}\",\"inferred\":[]}],\"hint\":null}"),
		("no probe cause: no details", dep, "no details"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-RP2 R-EP8 R-EP11 D2 (slice 036c): `Oracle.hint` is the oldest compiler of D, other than H, on which the same step is `Done` with real facts only. A compiler of D is older or newer than H. An inferred fact never decides (R-EP8). The header value has the assumed pass on H only (D2 of slice 036b):
# on another compiler its pair needs a real row, so a tuple of the header value alone is not known to work there. `Scan` and `Pairs` are not `Done`. The dropped tuples (`conflicts`) of H are not read on another compiler. The header of a release that the command has not read is no fact about `n`: it is taken as fit (D3), the step runs again with an empty fact.
expect {
	a_slot = slot("a", [], u("a", "1.0.0"), Free, [cand(u("a", "1.0.0"), 30)])
	facts = json_facts.concat([fact(u("a", "1.0.0"), [])])
	pa = |at| row(u("a", "1.0.0"), at, Pass, [])
	both = |at| [pass("3.0.0", at), pa(at)]
	hint = |checks| Str.inspect(Oracle.hint(input([json_slot, a_slot], facts), compat(checks, Allowed, Ok(d5))))
	hint_with = |checks, c| Str.inspect(Oracle.hint(input([json_slot, a_slot], facts), c(compat(checks, Allowed, Ok(d5)))))
	some = |id| Str.inspect(Ok(id))
	nope = Str.inspect(Err(None))
	cur_only_n1 = [hard("3.0.0", n1), hard("2.0.0", n1)]
	rows = [
		("no fact of another compiler: none", hint([]), nope),
		("a pass of each pair on n2: n2", hint(both(n2)), some(n2)),
		("n1 has the pass of json only (the pair of a has no real fact): n2 is the oldest", hint(both(n2).concat([pass("3.0.0", n1)])), some(n2)),
		("both pairs on n1 and on n2: the oldest, n1", hint(both(n2).concat(both(n1))), some(n1)),
		("the pass on n4 only: a compiler newer than H is the answer", hint(both(n4)), some(n4)),
		("the pass on H is no answer: H is not a candidate", hint(both(held)), nope),
		("the passes of n5 and n4: the oldest, n4", hint(both(n5).concat(both(n4))), some(n4)),
		("a fail of 3.0.0 on n1 and a pass of 2.0.0 and a on n1: the tuple of 2.0.0 works there, so n1", hint([hard("3.0.0", n1), pass("2.0.0", n1), pa(n1)]), some(n1)),
		("D2: 3.0.0 and 2.0.0 fail on n1, so the tuple is the header value 1.0.0, which has no real row on n1: not n1", hint(cur_only_n1.concat([pa(n1)])), nope),
		("D2: the same with the real pass of the header value on n1: n1", hint(cur_only_n1.concat([pass("1.0.0", n1), pa(n1)])), some(n1)),
		("an inferred pass does not decide (R-EP8): the facts of n1 are inferred only", hint_with([], |c| { ..c, inferred: [{ hash: hash(json("3.0.0")), nightly: n1, outcome: Pass, modules: [], from: [n2] }, { hash: hash(u("a", "1.0.0")), nightly: n1, outcome: Pass, modules: [], from: [n2] }] }), nope),
		("a fail with a module and no scan result: the tuple needs a scan, so it is not known to work there", hint([row(json("3.0.0"), n2, Fail, ["Yaml.roc"]), pa(n2)]), nope),
		("a tuple that the ladder dropped on H is not dropped on another compiler", hint_with(both(n2), |c| { ..c, conflicts: [[{ at: 0, id: json("3.0.0") }]] }), some(n2)),
		("the header of the release of a was not read by the command: it is no fact about n2, the header is taken as fit", Str.inspect(Oracle.hint(input([json_slot, a_slot], json_facts), compat(both(n2), Allowed, Ok(d5)))), some(n2)),
		("the same, and a has no real fact on n2: the pair needs a probe, so none", Str.inspect(Oracle.hint(input([json_slot, a_slot], json_facts), compat([pass("3.0.0", n2)], Allowed, Ok(d5)))), nope),
		("D not read: none", Str.inspect(Oracle.hint(input([json_slot, a_slot], facts), compat(both(n2), Allowed, Err(NotRead)))), nope),
		("no compiler: none", Str.inspect(Oracle.hint(input([json_slot, a_slot], facts), { ..compat(both(n2), Allowed, Ok(d5)), compiler: Err(None) })), nope),
		("H is not in D: none", Str.inspect(Oracle.hint(input([json_slot, a_slot], facts), compat(both(n2), Allowed, Ok([n1, n2, n4, n5])))), nope),
		("the same rows in another order (R-DT2)", hint(both(n1).concat(both(n2)).rev()), some(n1)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
