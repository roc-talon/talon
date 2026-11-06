import lib.RegistryCache
import lib.Roots

RegcacheTest :: [].{}

# Slice 202 (docs/slices/202-read-cache.md). Pure: the dir and the key of a copy, the meta, the freshness plan, the headers of a read.
# The flow `RegistryCache.get!` is the L2 case `tests/commands/cases/registry/ap24-read-cache`.

roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/c/cfg/talon", data: "/c/data/talon" }

origin = "http://127.0.0.1:9"

example_path = "/v1/releases?group=github.com%2Froc-lang%2Funicode%2Freleases%2Fdownload%2F%7Bv%7D%2F"

# R-IX1, R-IX2, R-IX5, R-LY1: the dir of a registry (the 3 forms of R-IX1, `://` and each other `:` become `_`), the key of the example URL of R-IX2 (the first 16 bytes of SHA-256 of the path and the query, as hex),
# a key that does not depend on the origin text, a key that changes with the query, and the 3 paths of a copy.
expect {
	dirs = [
		RegistryCache.origin_dir({ roots, origin: "https://registry.example.org" }),
		RegistryCache.origin_dir({ roots, origin: "http://127.0.0.1:8787" }),
		RegistryCache.origin_dir({ roots, origin: "http://[::1]:8787" }),
	]
	key = RegistryCache.key({ origin: "https://registry.example.org", url: "https://registry.example.org${example_path}" })
	same = RegistryCache.key({ origin, url: "${origin}${example_path}" })
	other = RegistryCache.key({ origin, url: "${origin}${example_path}&series=4" })
	files = RegistryCache.files({ roots, origin, url: "${origin}/v1/packages/acme/lib/releases" })
	dirs
		== [
			"/c/roc/talon/index/registry/https_registry.example.org",
			"/c/roc/talon/index/registry/http_127.0.0.1_8787",
			"/c/roc/talon/index/registry/http_[__1]_8787",
		]
		and key == "98479255038c5453bde9313928301713"
			and same == key
				and other != key
					and files
						== {
							dir: "/c/roc/talon/index/registry/http_127.0.0.1_9/get",
							body: "/c/roc/talon/index/registry/http_127.0.0.1_9/get/5729006e59ab0441482f6a7a40166c7a.json",
							meta: "/c/roc/talon/index/registry/http_127.0.0.1_9/get/5729006e59ab0441482f6a7a40166c7a.meta",
						}
}

# R-IX2, G-C38 (Design Q218): the meta text (the lines url, etag, max-age: the form is a proposal) and its reverse. The etag line is there only when the answer had an ETag, the max-age line only when it had a max-age: a copy with no ETag is kept (and read again with no
# If-None-Match), a copy with no max-age is kept (and never fresh). A text with no url line, or a max-age that is not a number, is a bad meta. An unknown line is ignored.
expect {
	text = RegistryCache.meta_text({ path: "/v1/packages/acme/lib/releases", etag: Ok("\"e1\""), max_age: Ok(60) })
	no_etag = RegistryCache.meta_text({ path: "/x", etag: Err(None), max_age: Ok(60) })
	no_age = RegistryCache.meta_text({ path: "/x", etag: Ok("\"e\""), max_age: Err(None) })
	neither = RegistryCache.meta_text({ path: "/x", etag: Err(None), max_age: Err(None) })
	text
		== "url /v1/packages/acme/lib/releases\netag \"e1\"\nmax-age 60\n"
		and no_etag
			== "url /x\nmax-age 60\n"
			and no_age
				== "url /x\netag \"e\"\n"
				and neither
					== "url /x\n"
					and RegistryCache.parse_meta(text)
						== Ok({ etag: Ok("\"e1\""), max_age: Ok(60) })
						and RegistryCache.parse_meta(no_etag)
							== Ok({ etag: Err(None), max_age: Ok(60) })
							and RegistryCache.parse_meta(no_age)
								== Ok({ etag: Ok("\"e\""), max_age: Err(None) })
								and RegistryCache.parse_meta(neither)
									== Ok({ etag: Err(None), max_age: Err(None) })
									and RegistryCache.parse_meta("url /x\nnote a\netag \"e2\"\nmax-age 300\n")
										== Ok({ etag: Ok("\"e2\""), max_age: Ok(300) })
										and RegistryCache.parse_meta("etag \"e\"\nmax-age 60\n")
											== Err(BadMeta)
											and RegistryCache.parse_meta("url /x\netag \"e\"\nmax-age soon\n")
												== Err(BadMeta)
												and RegistryCache.parse_meta("")
													== Err(BadMeta)
}

# R-IX3, R-AP54, R-AP55: the Cache-Control of an answer. The header name in any case (the Worker sends lower case). A directive list with white space, names in any case. `no-store` wins over `max-age`. `max-age=0` is a value.
# No header, no max-age and a max-age that is not digits are `NoMaxAge`. G-C38: only `max-age` and `no-store` are read, so `s-maxage` and `stale-while-revalidate` give no max-age, and they do not change a `max-age` next to them.
expect {
	of = |value| RegistryCache.max_age_of([("content-type", "application/json"), ("Cache-Control", value)])
	lower = RegistryCache.max_age_of([("cache-control", "max-age=60"), ("etag", "\"x\"")])
	upper = RegistryCache.max_age_of([("CACHE-CONTROL", "max-age=300")])
	lower
		== MaxAge(60)
		and upper
			== MaxAge(300)
			and of("max-age=60")
				== MaxAge(60)
				and of("public ,  Max-Age=300 , immutable")
					== MaxAge(300)
					and of("max-age=0")
						== MaxAge(0)
						and of("no-store")
							== NoStore
							and of("max-age=60, NO-STORE")
								== NoStore
								and of("no-cache")
									== NoMaxAge
									and of("max-age=abc")
										== NoMaxAge
										and of("s-maxage=60")
											== NoMaxAge
											and of("s-maxage=600, max-age=30")
												== MaxAge(30)
												and of("max-age=60, stale-while-revalidate=30, s-maxage=600")
													== MaxAge(60)
													and of("stale-while-revalidate=30")
														== NoMaxAge
														and of("s-maxage=10, no-store")
															== NoStore
															and RegistryCache.max_age_of([("etag", "\"x\"")])
																== NoMaxAge
}

# R-IX2, R-IX3, R-IX7, R-AP43, G-C38: what is kept. A 200 is kept, with the header names in any case (the Worker sends lower case): with an ETag and a max-age, with no ETag (etag is `Err(None)`), with no max-age (also when only `s-maxage` is there),
# and with neither. A `no-store` 200, a 404, a problem answer (400), a 304, a 3xx and a 500 are not kept.
expect {
	ok = [("cache-control", "max-age=60"), ("etag", "\"e1\"")]
	keep = |status, headers| RegistryCache.keep({ status, headers })
	keep(200, ok)
		== Ok({ etag: Ok("\"e1\""), max_age: Ok(60) })
		and keep(200, [("Cache-Control", "max-age=300"), ("ETag", "\"t\"")])
			== Ok({ etag: Ok("\"t\""), max_age: Ok(300) })
			and keep(200, [("cache-control", "max-age=60")])
				== Ok({ etag: Err(None), max_age: Ok(60) })
				and keep(200, [("etag", "\"e1\"")])
					== Ok({ etag: Ok("\"e1\""), max_age: Err(None) })
					and keep(200, [("cache-control", "s-maxage=60"), ("etag", "\"e1\"")])
						== Ok({ etag: Ok("\"e1\""), max_age: Err(None) })
						and keep(200, [])
							== Ok({ etag: Err(None), max_age: Err(None) })
							and keep(200, [("cache-control", "no-store"), ("etag", "\"e1\"")])
								== Err(NotKept)
								and keep(404, ok)
									== Err(NotKept)
									and keep(400, ok)
										== Err(NotKept)
										and keep(304, ok)
											== Err(NotKept)
											and keep(301, ok)
												== Err(NotKept)
												and keep(500, ok)
													== Err(NotKept)
}

# R-AP24, R-AP43, R-IX2, R-IX3, R-IX6, G-C38: the plan. A copy is used when its age is less than its max-age (also at the age max-age minus 1, not at max-age), else it is revalidated with its ETag. max-age 0 always revalidates.
# A copy with no ETag is read again with a plain fetch (no If-None-Match). A copy with no max-age is never fresh (revalidated or fetched at any age, also at age 0). No copy is a fetch. `newest` (no-cache) fetches also with a fresh copy.
# Offline uses a copy of any age (also with `newest`, also with no max-age), and a missing copy is `Missing`. A copy in the future has age 0.
expect {
	copy = |max_age, mtime| Ok({ etag: Ok("\"e\""), max_age: Ok(max_age), mtime })
	no_etag = |max_age, mtime| Ok({ etag: Err(None), max_age: Ok(max_age), mtime })
	no_age = Ok({ etag: Ok("\"e\""), max_age: Err(None), mtime: 1000 })
	bare = Ok({ etag: Err(None), max_age: Err(None), mtime: 1000 })
	plan = |cached, now, offline, newest| RegistryCache.plan({ cached, now, offline, newest })
	none = Err(Missing)
	plan(copy(60, 1000), 1000, Bool.False, Bool.False)
		== Use
		and plan(copy(60, 1000), 1059, Bool.False, Bool.False)
			== Use
			and plan(copy(60, 1000), 1060, Bool.False, Bool.False)
				== Revalidate("\"e\"")
				and plan(copy(60, 1000), 90000, Bool.False, Bool.False)
					== Revalidate("\"e\"")
					and plan(copy(0, 1000), 1000, Bool.False, Bool.False)
						== Revalidate("\"e\"")
						and plan(copy(300, 1000), 1299, Bool.False, Bool.False)
							== Use
							and plan(copy(60, 2000), 1000, Bool.False, Bool.False)
								== Use
								and plan(none, 1000, Bool.False, Bool.False)
									== Fetch
									and plan(copy(60, 1000), 1010, Bool.False, Bool.True)
										== Fetch
										and plan(none, 1010, Bool.False, Bool.True)
											== Fetch
											and plan(copy(60, 1000), 99999, Bool.True, Bool.False)
												== Use
												and plan(copy(60, 1000), 99999, Bool.True, Bool.True)
													== Use
													and plan(none, 1000, Bool.True, Bool.False)
														== Missing
														and plan(none, 1000, Bool.True, Bool.True)
															== Missing
															and plan(no_etag(60, 1000), 1059, Bool.False, Bool.False)
																== Use
																and plan(no_etag(60, 1000), 1060, Bool.False, Bool.False)
																	== Fetch
																	and plan(no_etag(60, 1000), 90000, Bool.True, Bool.False)
																		== Use
																		and plan(no_age, 1000, Bool.False, Bool.False)
																			== Revalidate("\"e\"")
																			and plan(no_age, 1001, Bool.False, Bool.False)
																				== Revalidate("\"e\"")
																				and plan(no_age, 1001, Bool.False, Bool.True)
																					== Fetch
																					and plan(no_age, 99999, Bool.True, Bool.False)
																						== Use
																						and plan(bare, 1000, Bool.False, Bool.False)
																							== Fetch
																							and plan(bare, 99999, Bool.True, Bool.True)
																								== Use
}

# R-IX7, R-E6, G-C38: the failure for an answer that is not a copy (a 3xx, or a 304 to a request with no If-None-Match). Kind network (exit 15). The text is a proposal (TW24): it names the registry, the status and the path.
expect {
	fail = RegistryCache.unusable({ origin: "http://127.0.0.1:9", path: "/v1/packages/acme/lib/releases", status: 301 })
	fail.kind.code()
		== 15
		and fail.message
			== "the registry http://127.0.0.1:9 gave the answer 301 for /v1/packages/acme/lib/releases, and Talon cannot use it. Try again later."
}

# R-AP45, R-AP24, R-AP43, R-AP55, R-AP41 row 5, R-RG3: the headers of a read, in the order User-Agent, If-None-Match, Cache-Control, Talon-Bookmark. `newest` sends no-cache and no If-None-Match (no local copy). A bookmark always comes with no-cache
# and with no If-None-Match. There is never an Authorization header.
expect {
	etag = Ok("\"e1\"")
	plain = RegistryCache.read_headers({ version: "0.4.1", etag: Err(None), newest: Bool.False, bookmark: Err(None) })
	revalidate = RegistryCache.read_headers({ version: "0.4.1", etag, newest: Bool.False, bookmark: Err(None) })
	newest = RegistryCache.read_headers({ version: "0.4.1", etag, newest: Bool.True, bookmark: Err(None) })
	bookmark = RegistryCache.read_headers({ version: "0.4.1", etag, newest: Bool.False, bookmark: Ok("b123") })
	both = RegistryCache.read_headers({ version: "0.4.1", etag: Err(None), newest: Bool.True, bookmark: Ok("b123") })
	plain
		== [("User-Agent", "tln/0.4.1")]
		and revalidate
			== [("User-Agent", "tln/0.4.1"), ("If-None-Match", "\"e1\"")]
			and newest
				== [("User-Agent", "tln/0.4.1"), ("Cache-Control", "no-cache")]
				and bookmark
					== [("User-Agent", "tln/0.4.1"), ("Cache-Control", "no-cache"), ("Talon-Bookmark", "b123")]
					and both
						== bookmark
}
