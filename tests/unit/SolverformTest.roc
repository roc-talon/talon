import resolve.SolverBase
import lib.Ident
import lib.OracleRequest

SolverformTest :: [].{}

# Slice 248 (W1 of research/slice-248-revert/RESULT.md): the form of an incompatibility (`SolverBase.norm`) and the same-group conflicts of the request (`OracleRequest.request_of`), with no search.
# This module is in the driver `l0-3`, which runs no solver search: a wrong `norm` or a missing `same_group` makes the searches of other drivers loop, but these expects fail at once.

report : List((Str, Str, Str)) -> Bool
report = |rows| {
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

now = 1792065600

day = 86400

u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

ocand = |url| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - 30 * day, size: 1 }
	Err(_) => crash "bad test URL"
}

pkg_fact = |url| { url, release: { kind: Package, pf: Err(None), deps: [] } }

input = |slots, facts| { slots, strategy: Highest, now, min_age: 2 * day, exclude: [], snapshot: Err(None), facts, unmanaged: [], paths: [], second: Bool.False }

compat = |checks, used| { compiler: Ok("nightly-2026-10-03-3333333"), checks, looked: [], probes: Allowed, conflicts: [], used, domain: Err(NotRead), inferred: [], failed: Other }

# R-AL16 R-AL17 (slice 248, W1 of research/slice-248-revert/RESULT.md): `SolverBase.norm`, the one form of an incompatibility. A term that holds all places of its variable is left out (it is always true).
# Two terms of one variable are joined (the places that both hold). A term with no place: `Never` (the incompatibility never holds). No search runs here, so a wrong `norm` fails this expect at once (in a search it makes a loop).
expect {
	sizes = [2, 3]
	show_norm = |lits| match SolverBase.norm(sizes, lits) {
		Ok(ls) => "ok ${Str.join_with(ls.map(|l| "${l.v.to_str()}:${Str.join_with(l.set.map(|x| x.to_str()), ",")}"), " ")}"
		Err(Never) => "never"
	}
	report([
		("a term with all places of its variable is left out", show_norm([{ v: 0, set: [0, 1] }]), "ok "),
		("all places of variable 1, and one place of variable 0: only variable 0 stays", show_norm([{ v: 1, set: [0, 1, 2] }, { v: 0, set: [1] }]), "ok 0:1"),
		("2 terms of one variable are joined; then all places are left out only when the join has them all", show_norm([{ v: 1, set: [0, 1] }, { v: 1, set: [1, 2] }]), "ok 1:1"),
		("a term with no place: never", show_norm([{ v: 0, set: [0] }, { v: 0, set: [1] }]), "never"),
	])
}

# R-AL14 R-WS2 (slice 248, W1 of research/slice-248-revert/RESULT.md): the request that `OracleRequest.request_of` builds has the conflicts of the caller for 2 slots of one group (`same_group`), before the conflicts of the ladder.
# s0 has acme/json 1.0.0 and 1.1.0, s1 has 1.0.0 (one group: acme/json series 1). The conflict: s0 = 1.1.0 and s1 = 1.0.0 cannot both hold. No search runs here.
expect {
	g1 = u("json", "1.0.0")
	g2 = u("json", "1.1.0")
	free_slot = |id, urls| { id, is_platform: Bool.False, ranges: [], current: Err(None), hold: Free, named: Err(None), candidates: urls.map(ocand), files: [] }
	inp = input([free_slot("a", [g1, g2]), free_slot("b", [g1])], [pkg_fact(g1), pkg_fact(g2)])
	no_roc = { ..compat([], []), compiler: Err(None), conflicts: [[{ at: 0, id: g1 }]] }
	got = OracleRequest.request_of(inp, no_roc, Bool.True, Err(Held)).conflicts
	text = |conflicts| Str.join_with(conflicts.map(|terms| Str.join_with(terms.map(|t| "${t.name}:${Str.join_with(t.ids.map(|id| id.drop_prefix("https://github.com/acme/json/releases/download/").split_on("/").first() ?? id), ",")}"), " & ")), " | ")
	report([
		("the same-group conflict of s0 and s1, then the conflict of the ladder", text(got), "s0:1.1.0 & s1:1.0.0 | s0:1.0.0"),
	])
}
