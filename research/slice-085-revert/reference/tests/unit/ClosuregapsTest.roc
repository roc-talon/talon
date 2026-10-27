import lib.Closure

ClosuregapsTest :: [].{}

file = "/p/app/main.roc"

# A release URL of the fixture host (as in `closure.roc`).
u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

dep = |alias, value| { alias, value, is_platform: Bool.False }

plat = |alias, value| { alias, value, is_platform: Bool.True }

node = |id, entries| { id, entries }

form_of = |repo| "github.com/acme/${repo}/releases/download/{v}/"

rel = |repo, ver, alias, facts| {
	id: u(repo, ver),
	kind: Release,
	alias,
	name: "acme/${repo}",
	form: form_of(repo),
	version: ver,
	series: facts.series,
	direct: facts.via == Err(None),
	via: facts.via,
	raised: facts.raised,
	is_platform: facts.is_pf,
}

# R-C2 R-OV1 R-EC10 (gap X4 of slice 010): `Closure.step` after a failure of `Mvs`. The header pins `json 1.0.0` and `mid` names `json 1.1.0`, so `Mvs.select` fails with a version conflict. 2 packages name `x` at 2 versions
# (`a` names 1.0.0, `b` names 1.1.0), and no node of `x` is read. A problem that comes from an incomplete selection is never returned (rule 4): the step asks for the node that `roc` would build, the winner `x 1.1.0` (the highest
# named version), and not for `x 1.0.0` (the first edge) and not for `json 1.1.0` (it does not win: the header pins 1.0.0). With the node of `x 1.1.0` the failure is the version conflict.
expect {
	entries = [dep("json", u("json", "1.0.0")), dep("mid", u("mid", "1.0.0")), dep("a", u("a", "1.0.0")), dep("b", u("b", "1.0.0"))]
	n_json = node(u("json", "1.0.0"), [])
	n_mid = node(u("mid", "1.0.0"), [dep("json", u("json", "1.1.0"))])
	n_a = node(u("a", "1.0.0"), [dep("x", u("x", "1.0.0"))])
	n_b = node(u("b", "1.0.0"), [dep("x", u("x", "1.1.0"))])
	n_x = node(u("x", "1.1.0"), [])
	step = |nodes| Closure.step({ file, entries, nodes })
	unread = step([n_json, n_mid, n_a, n_b])
	read = step([n_json, n_mid, n_a, n_b, n_x])
	want_fail = Fail(VersionConflict([{ pinned: u("json", "1.0.0"), needed: u("json", "1.1.0"), by: u("mid", "1.0.0") }]))
	dbg unread
	dbg read
	unread == Need([u("x", "1.1.0")]) and read == want_fail
}

# R-C3 R-CM9 (gap X19 of slice 010): a later edge sets `is_platform` of a row. The header names the platform release as a package entry (`base`), and `web` names the same release with a platform entry (`pf: platform "..."`). The row
# has the alias of the first edge, and it is a platform row because a followed edge names it as a platform.
expect {
	entries = [dep("base", u("pfx", "0.1.1")), dep("web", u("web", "1.0.0"))]
	n_pfx = node(u("pfx", "0.1.1"), [])
	n_web = node(u("web", "1.0.0"), [plat("pf", u("pfx", "0.1.1"))])
	got = Closure.step({ file, entries, nodes: [n_pfx, n_web] })
	want = Done({
		rows: [
			rel("pfx", "0.1.1", "base", { series: "0.1", via: Err(None), raised: Err(None), is_pf: Bool.True }),
			rel("web", "1.0.0", "web", { series: "1", via: Err(None), raised: Err(None), is_pf: Bool.False }),
		],
		links: [
			{ from: Err(Header), alias: "base", to: u("pfx", "0.1.1") },
			{ from: Err(Header), alias: "web", to: u("web", "1.0.0") },
			{ from: Ok(u("web", "1.0.0")), alias: "pf", to: u("pfx", "0.1.1") },
		],
	})
	dbg got
	got == want
}
