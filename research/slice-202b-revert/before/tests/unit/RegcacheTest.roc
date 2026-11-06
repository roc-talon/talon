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

# R-IX2: the meta text (the lines url, etag, max-age: the form is a proposal) and its reverse. A text with no etag line, or no max-age line, or a max-age that is not a number, is a bad meta. An unknown line is ignored.
expect {
	text = RegistryCache.meta_text({ path: "/v1/packages/acme/lib/releases", etag: "\"e1\"", max_age: 60 })
	text
		== "url /v1/packages/acme/lib/releases\netag \"e1\"\nmax-age 60\n"
		and RegistryCache.parse_meta(text) == Ok({ etag: "\"e1\"", max_age: 60 })
			and RegistryCache.parse_meta("url /x\nnote a\netag \"e2\"\nmax-age 300\n") == Ok({ etag: "\"e2\"", max_age: 300 })
				and RegistryCache.parse_meta("url /x\nmax-age 60\n") == Err(BadMeta)
					and RegistryCache.parse_meta("url /x\netag \"e\"\n") == Err(BadMeta)
						and RegistryCache.parse_meta("url /x\netag \"e\"\nmax-age soon\n") == Err(BadMeta)
							and RegistryCache.parse_meta("") == Err(BadMeta)
}

# R-IX3, R-AP54, R-AP55: the Cache-Control of an answer. The header name in any case (the Worker sends lower case). A directive list with white space, names in any case. `no-store` wins over `max-age`. `max-age=0` is a value.
# No header, no max-age and a max-age that is not digits are `NoMaxAge`.
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
											and RegistryCache.max_age_of([("etag", "\"x\"")])
												== NoMaxAge
}

# R-IX2, R-IX3, R-AP43: what is kept. A 200 with an ETag and a max-age is kept, with the header names in any case (the Worker sends lower case). A `no-store` 200, a 404, a problem answer (400), a 304 and a 500 are not kept.
expect {
	ok = [("cache-control", "max-age=60"), ("etag", "\"e1\"")]
	keep = |status, headers| RegistryCache.keep({ status, headers })
	keep(200, ok)
		== Ok({ etag: "\"e1\"", max_age: 60 })
		and keep(200, [("Cache-Control", "max-age=300"), ("ETag", "\"t\"")])
			== Ok({ etag: "\"t\"", max_age: 300 })
			and keep(200, [("cache-control", "no-store"), ("etag", "\"e1\"")])
				== Err(NotKept)
				and keep(404, ok)
					== Err(NotKept)
					and keep(400, ok)
						== Err(NotKept)
						and keep(304, ok)
							== Err(NotKept)
							and keep(500, ok)
								== Err(NotKept)
}

# R-AP24, R-AP43, R-IX3, R-IX6: the plan. A copy is used when its age is less than its max-age (also at the age max-age minus 1, not at max-age), else it is revalidated with its ETag. max-age 0 always revalidates.
# No copy is a fetch. `newest` (no-cache) fetches also with a fresh copy. Offline uses a copy of any age (also with `newest`), and a missing copy is `Missing`. A copy in the future has age 0.
expect {
	copy = |max_age, mtime| Ok({ etag: "\"e\"", max_age, mtime })
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
