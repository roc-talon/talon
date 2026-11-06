import lib.Reconcile
import lib.Webhook

ReconcileTest :: [].{}

# W0 tests of worker/lib/Reconcile.roc (slice 119b, docs/slices/119-reconcile.md). The claim SQL is pinned by key words; what it does on local D1 is W2 (worker/tests/cases/reconcile/).

holds : Str, List(Str) -> Bool
holds = |text, words| words.all(|w| text.contains(w))

h1 = "4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi"

h2 = "8qbHbw2BbbTHBW1sbeqakYXVKRQM8Ne7pLK7m6CVfeR"

h3 = "CktRuQ2mttgRGkXJtyksdKHjUdc2C4TgDzyB98oEzy8"

h4 = "GgBaCs3NCBuZN12kCJgAW63ydqohFkHEdfdEXBPzLHq"

h5 = "LbUiWL3xVV8hTFYBVdbTNrpDo41NKS6o3LHHuDzjfcY"

h6 = "QWmroo4YnnMqYW3cnxWkFdaTxGD3P7vMSzwMHGbUzwF"

h7 = "US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx"

h8 = "YMN9Qj5jPNp7j14VPcML1B6xGgcPWVZUGLFU3Mnyfaf"

h9 = "cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN"

zst : Str -> Str
zst = |h| "${h}.tar.zst"

row : U64, Str, Str, Try(Str, [None]) -> Reconcile.Indexed
row = |log_index, tag, hash, withdrawn| { log_index, tag, hash, withdrawn }

final : U64, Str, List(Str) -> Reconcile.ListItem
final = |id, tag, assets| { id, tag, release: { draft: Bool.False, prerelease: Bool.False, published_at: Ok(1792497600000), assets } }

pre : U64, Str, List(Str) -> Reconcile.ListItem
pre = |id, tag, assets| { id, tag, release: { draft: Bool.False, prerelease: Bool.True, published_at: Ok(1792497600000), assets } }

draft : U64, Str, List(Str) -> Reconcile.ListItem
draft = |id, tag, assets| { id, tag, release: { draft: Bool.True, prerelease: Bool.False, published_at: Err(None), assets } }

set : U64, Str -> Webhook.Change
set = |log_index, value| { log_index, to: Ok(value) }

clear : U64 -> Webhook.Change
clear = |log_index| { log_index, to: Err(Clear) }

minute = 60_000

hour = 3_600_000

day = 86_400_000

t0 = 1_767_225_600_000

# R-PU23, R-PU35, R-PU37 row 1, R-PU36: the constants, and the claim as ONE UPDATE with RETURNING: the due rows (at or before now), the oldest first, at most ?2, the 15 min claim from ?1.
# R-RE14: the columns of repo_checks that the run needs come back. R-IK2: the 64-bit ids travel as text. The releases of the repository come in the same statement (1 + R D1 calls, R-PU23).
expect {
	c = Reconcile.claim_sql()
	consts = Reconcile.cron == "*/5 * * * *" and Reconcile.max_rows == 500 and Reconcile.claim_ms == 900_000 and Reconcile.backoff_ms == 300_000
	one = c.split_on(";").len() == 1 and !c.contains("DELETE") and !c.contains("INSERT")
	claim = holds(c, ["UPDATE repo_checks", "next_check_at = ?1 + 900000", "next_check_at <= ?1", "ORDER BY next_check_at", "LIMIT ?2", "RETURNING"])
	columns = holds(c, ["CAST(repo AS TEXT)", "repository_id", "etag", "fail_count", "app_installed", "json_group_array", "log_index", "tag", "hash", "withdrawn"])
	consts and one and claim and columns
}

# R-PU37 row 3, R-PU22: next_check. 0 after a pass: the interval. A failed row: 5 min times 2^(n - 1), capped at the interval (1 h with no App, 24 h with the App). A large count does not overflow.
expect {
	no_app = [
		(0, t0 + hour),
		(1, t0 + 5 * minute),
		(2, t0 + 10 * minute),
		(3, t0 + 20 * minute),
		(4, t0 + 40 * minute),
		(5, t0 + hour),
		(6, t0 + hour),
		(64, t0 + hour),
		(4_000_000_000, t0 + hour),
	]
	with_app = [
		(0, t0 + day),
		(1, t0 + 5 * minute),
		(9, t0 + 1280 * minute),
		(10, t0 + day),
		(200, t0 + day),
	]
	no_app.all(|(n, want)| Reconcile.next_check(t0, hour, n) == want) and with_app.all(|(n, want)| Reconcile.next_check(t0, day, n) == want)
}

# R-PU23, CLI R-DI2, R-TP10, R-PU27: the list call of the full name that GitHub gave (the case is kept), on api.github.com only.
expect {
	Reconcile.list_url("Acme/Lib") == "https://api.github.com/repos/Acme/Lib/releases?per_page=100"
		and Reconcile.list_url("acme/roc-json") == "https://api.github.com/repos/acme/roc-json/releases?per_page=100"
}

# R-PU23, R-AP44, R-PU37 row 2: parse_list keeps the order, reads null values, nested objects and members that it does not use. One bad item, or a text that is not an array, is BadList (an item that is skipped would look deleted).
expect {
	text =
		\\[
		\\  {"url": "https://api.github.com/repos/Acme/Lib/releases/9002", "id": 9002, "tag_name": "2.0.0", "name": null, "body": null, "draft": false, "prerelease": true,
		\\   "created_at": "2026-10-20T12:00:00Z", "published_at": "2026-10-20T12:00:00Z", "author": {"login": "café", "id": 5},
		\\   "assets": [{"id": 1, "name": "8qbHbw2BbbTHBW1sbeqakYXVKRQM8Ne7pLK7m6CVfeR.tar.zst", "label": null, "size": 10, "digest": null}]},
		\\  {"id": 9003, "tag_name": "3.0.0", "draft": true, "prerelease": false, "published_at": null, "assets": []},
		\\  {"id": 9001, "tag_name": "1.0.0", "draft": false, "prerelease": false, "published_at": "2026-10-20T12:00:00Z", "assets": [{"name": "notes.txt"}, {"name": "4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi.tar.zst"}]}
		\\]
	want = [
		pre(9002, "2.0.0", [zst(h2)]),
		draft(9003, "3.0.0", []),
		final(9001, "1.0.0", ["notes.txt", zst(h1)]),
	]
	good = Reconcile.parse_list(text) == Ok(want) and Reconcile.parse_list("[]") == Ok([]) and Reconcile.parse_list(" [ ] ") == Ok([])
	bad = [
		"",
		"not json",
		"{\"id\": 1, \"tag_name\": \"1.0.0\", \"draft\": false, \"prerelease\": false, \"published_at\": null, \"assets\": []}",
		"[{\"tag_name\": \"1.0.0\", \"draft\": false, \"prerelease\": false, \"published_at\": null, \"assets\": []}]",
		"[{\"id\": 0, \"tag_name\": \"1.0.0\", \"draft\": false, \"prerelease\": false, \"published_at\": null, \"assets\": []}]",
		"[{\"id\": 5, \"tag_name\": \"\", \"draft\": false, \"prerelease\": false, \"published_at\": null, \"assets\": []}]",
		"[{\"id\": 5, \"tag_name\": \"1.0.0\", \"prerelease\": false, \"published_at\": null, \"assets\": []}]",
		"[{\"id\": 5, \"tag_name\": \"1.0.0\", \"draft\": false, \"prerelease\": false, \"published_at\": null}]",
		"[{\"id\": 5, \"tag_name\": \"1.0.0\", \"draft\": false, \"prerelease\": false, \"published_at\": null, \"assets\": []}, {\"id\": 6}]",
	]
	good and bad.all(|b| Reconcile.parse_list(b) == Err(BadList))
}

# R-PU23: the outcome of the list call. 304: not modified (the body is not read). 200: the list and the ETag as it came. A bad body, another status: a failure of the row (R-PU37 row 2). The texts are proposals (TW24).
expect {
	body = "[{\"id\": 9001, \"tag_name\": \"1.0.0\", \"draft\": false, \"prerelease\": false, \"published_at\": \"2026-10-20T12:00:00Z\", \"assets\": []}]"
	list = [final(9001, "1.0.0", [])]
	ok304 = Reconcile.list_outcome({ status: 304, etag: Ok("W/\"e1\""), link: Err(None), body: "" }) == Ok(NotModified)
	ok200 = Reconcile.list_outcome({ status: 200, etag: Ok("W/\"e2\""), link: Err(None), body }) == Ok(Changed({ etag: Ok("W/\"e2\""), list }))
	no_etag = Reconcile.list_outcome({ status: 200, etag: Err(None), link: Err(None), body: "[]" }) == Ok(Changed({ etag: Err(None), list: [] }))
	bad = Reconcile.list_outcome({ status: 200, etag: Ok("W/\"e3\""), link: Err(None), body: "{}" }) == Err(Failed("the release list is not valid"))
	s500 = Reconcile.list_outcome({ status: 500, etag: Err(None), link: Err(None), body: "" }) == Err(Failed("the release list read answered status 500"))
	s404 = Reconcile.list_outcome({ status: 404, etag: Err(None), link: Err(None), body: "" }) == Err(Failed("the release list read answered status 404"))
	s403 = Reconcile.list_outcome({ status: 403, etag: Err(None), link: Err(None), body: "" }) == Err(Failed("the release list read answered status 403"))
	ok304 and ok200 and no_etag and bad and s500 and s404 and s403
}

# R-PU23, R-PU17, R-PU19, R-PU20, R-PU21, R-PU6, Design Q339, Q360: list_work over the releases of every name of the repository.
# A release not in the list, or a draft again: deleted. A prerelease: prereleased. A final release: the asset check (asset-replaced) and the clear of a candidate, never repo-missing.
# Slice 119c (R-PU24, Design Q379): repo-missing of a candidate with the recorded asset is cleared too (row 7). A row with a value keeps it. The candidates: final, exactly one package asset, a version tag, a tag that no row has; in the order of the list.
expect {
	rows = [
		row(1, "1.0.0", h1, Err(None)),
		row(2, "2.0.0", h2, Err(None)),
		row(3, "3.0.0", h3, Err(None)),
		row(4, "4.0.0", h4, Err(None)),
		row(5, "5.0.0", h5, Err(None)),
		row(6, "6.0.0", h6, Ok("unpublished")),
		row(7, "7.0.0", h7, Ok("repo-missing")),
		row(8, "11.0.0", h8, Ok("deleted")),
		row(9, "12.0.0", h1, Ok("asset-replaced")),
		row(10, "0.9.0", h9, Err(None)),
		row(11, "13.0.0", h3, Ok("prereleased")),
	]
	list = [
		final(9101, "1.0.0", [zst(h1), "notes.txt"]),
		pre(9102, "2.0.0", [zst(h2)]),
		draft(9104, "4.0.0", [zst(h4)]),
		final(9105, "5.0.0", [zst(h9)]),
		final(9106, "6.0.0", [zst(h6)]),
		final(9107, "7.0.0", [zst(h7)]),
		final(9109, "12.0.0", [zst(h1), zst(h3)]),
		final(9108, "8.0.0", [zst(h8), "${zst(h8)}.intoto.jsonl"]),
		pre(9110, "9.0.0", [zst(h5)]),
		final(9111, "nightly", [zst(h5)]),
		final(9112, "10.0.0", [zst(h5), zst(h6)]),
		final(9113, "14.0.0", []),
		draft(9114, "15.0.0", [zst(h5)]),
		final(9115, "16.0.0", ["docs.tar.gz", zst(h4)]),
		pre(9116, "13.0.0", [zst(h3)]),
	]
	work = Reconcile.list_work({ full_name: "Acme/Lib", rows, list })
	want_changes = [set(2, "prereleased"), set(3, "deleted"), set(4, "deleted"), set(5, "asset-replaced"), clear(6), clear(7), set(10, "deleted")]
	work.changes == want_changes and work.candidates == [9108, 9115]
}

# R-PU23, R-PU14, R-PU19: no rows: every candidate of the list (an empty list gives none). An empty list: every row with no value is deleted. A candidate whose tag is indexed with another hash: no candidate, asset-replaced.
expect {
	only_new = Reconcile.list_work({ full_name: "acme/lib", rows: [], list: [final(7, "1.0.0", [zst(h1)]), final(8, "v2.0.0", [zst(h2)])] })
	empty = Reconcile.list_work({ full_name: "acme/lib", rows: [row(1, "1.0.0", h1, Err(None)), row(2, "2.0.0", h2, Ok("edited"))], list: [] })
	again = Reconcile.list_work({ full_name: "acme/lib", rows: [row(1, "1.0.0", h1, Err(None))], list: [final(7, "1.0.0", [zst(h2)])] })
	only_new == { changes: [], candidates: [7, 8] }
		and empty == { changes: [set(1, "deleted")], candidates: [] }
		and again == { changes: [set(1, "asset-replaced")], candidates: [] }
		and Reconcile.list_work({ full_name: "acme/lib", rows: [], list: [] }) == { changes: [], candidates: [] }
}

# R-PU25: the reserve. Under 10 % of the limit (strict): the reset time in ms. Exactly 10 %, more, a missing header or one that is not a whole number: go on.
expect {
	h = |remaining, limit, reset| Reconcile.reserve({ remaining, limit, reset })
	under = h(Ok("499"), Ok("5000"), Ok("1767229200")) == Ok(1_767_229_200_000) and h(Ok("0"), Ok("5000"), Ok("1767229200")) == Ok(1_767_229_200_000) and h(Ok("9"), Ok("100"), Ok("7")) == Ok(7000)
	edge = h(Ok("500"), Ok("5000"), Ok("1767229200")) == Err(Go) and h(Ok("10"), Ok("100"), Ok("7")) == Err(Go)
	above = h(Ok("4999"), Ok("5000"), Ok("1767229200")) == Err(Go)
	missing = h(Err(None), Ok("5000"), Ok("1767229200")) == Err(Go) and h(Ok("1"), Err(None), Ok("1767229200")) == Err(Go) and h(Ok("1"), Ok("5000"), Err(None)) == Err(Go)
	bad = h(Ok("x"), Ok("5000"), Ok("1767229200")) == Err(Go) and h(Ok("1"), Ok("-5"), Ok("1767229200")) == Err(Go) and h(Ok("1"), Ok("5000"), Ok("soon")) == Err(Go) and h(Ok(""), Ok("5000"), Ok("1")) == Err(Go)
	under and edge and above and missing and bad
}

# R-PU23, R-PU13, R-PU15, R-PU21: the message of a candidate (the form is a proposal, TW24), and the job that it gives: Poll (the job Release with the provenance poll). Another action of poll is not a job.
expect {
	m = Reconcile.message_of(600, 9108)
	form = m == { event: "poll", action: "published", installation_id: 0, repository_id: 600, release_id: 9108, repository_ids: [] }
	job = Webhook.job_of(m) == Ok(Poll({ repository_id: 600, release_id: 9108 }))
	other = Webhook.job_of({ ..m, action: "edited" }) == Err(Unknown) and Webhook.job_of({ ..m, event: "polls" }) == Err(Unknown)
	form and job and other
}

# ---- Slice 119c (Design Q371, Q372, Q378 to Q380; docs/slices/119-reconcile.md section 13) ----

# R-PU31, R-RE14, Design Q371, Q378 to Q380: the claim also gives the stored repo_etag, the name of the row and the ids and state of its repos row (no other read in the run).
expect {
	c = Reconcile.claim_sql()
	holds(c, ["repo_etag", "names", "value", "repository_owner_id", "state"]) and c.split_on(";").len() == 1
}

# R-PU23, Design Q372: has_next reads rel="next" of the Link header of GitHub. The last page has prev, first and no next.
expect {
	two = "<https://api.github.com/repositories/600/releases?per_page=100&page=2>; rel=\"next\", <https://api.github.com/repositories/600/releases?per_page=100&page=5>; rel=\"last\""
	middle = "<https://api.github.com/repositories/600/releases?per_page=100&page=1>; rel=\"prev\", <https://api.github.com/repositories/600/releases?per_page=100&page=3>; rel=\"next\", <https://api.github.com/repositories/600/releases?per_page=100&page=5>; rel=\"last\", <https://api.github.com/repositories/600/releases?per_page=100&page=1>; rel=\"first\""
	last = "<https://api.github.com/repositories/600/releases?per_page=100&page=4>; rel=\"prev\", <https://api.github.com/repositories/600/releases?per_page=100&page=1>; rel=\"first\""
	yes = Reconcile.has_next(Ok(two)) and Reconcile.has_next(Ok(middle))
	no = !Reconcile.has_next(Ok(last)) and !Reconcile.has_next(Err(None)) and !Reconcile.has_next(Ok("")) and !Reconcile.has_next(Ok("<https://x/y?page=2>; rel=\"last\""))
	Reconcile.max_pages == 10 and yes and no
}

# Design Q372: the page URLs (the Worker makes them, page 1 is the list URL), the pages as one list with a repeated id kept once (the first), and a 200 with a next link is a list (no failure now).
expect {
	urls = Reconcile.page_url("Acme/Lib", 1) == "https://api.github.com/repos/Acme/Lib/releases?per_page=100"
		and Reconcile.page_url("Acme/Lib", 2) == "https://api.github.com/repos/Acme/Lib/releases?per_page=100&page=2"
		and Reconcile.page_url("acme/lib", 10) == "https://api.github.com/repos/acme/lib/releases?per_page=100&page=10"
	a = final(1, "1.0.0", [zst(h1)])
	b = final(2, "2.0.0", [zst(h2)])
	b_later = pre(2, "2.0.0", [zst(h2)])
	c = final(3, "3.0.0", [zst(h3)])
	merged = Reconcile.merge_pages([[a, b], [b_later, c], []]) == [a, b, c] and Reconcile.merge_pages([]) == [] and Reconcile.merge_pages([[a]]) == [a]
	link = "<https://api.github.com/repositories/600/releases?per_page=100&page=2>; rel=\"next\""
	paged = Reconcile.list_outcome({ status: 200, etag: Ok("W/\"p1\""), link: Ok(link), body: "[]" }) == Ok(Changed({ etag: Ok("W/\"p1\""), list: [] }))
	urls and merged and paged
}

# R-PU31, R-RE14, Design Q371: repo_etag is stored only for a public read of the name of the row (the case of the full name is ignored). A rename, a read that is not public, no ETag: NULL.
expect {
	e = |public, row_name, full_name, etag| Reconcile.repo_etag_of({ public, row_name, full_name, etag })
	stored = e(Bool.True, "acme/lib", "acme/lib", Ok("W/\"r1\"")) == Ok("W/\"r1\"") and e(Bool.True, "acme/lib", "Acme/Lib", Ok("W/\"r2\"")) == Ok("W/\"r2\"")
	null = e(Bool.True, "acme/lib", "acme/lib2", Ok("W/\"r3\"")) == Err(None)
		and e(Bool.True, "acme/lib-old", "Acme/Lib", Ok("W/\"r4\"")) == Err(None)
		and e(Bool.False, "acme/lib", "acme/lib", Ok("W/\"r5\"")) == Err(None)
		and e(Bool.True, "acme/lib", "acme/lib", Err(None)) == Err(None)
	stored and null
}
