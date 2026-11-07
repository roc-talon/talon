import Fail
import Fx
import Item
import Registry
import Roots
import Text

## The read cache of the registry client (slice 202, Registry R-AP24, R-AP43, R-AP54, R-AP55; CLI 6.1, R-IX1 to R-IX3, R-IX6). The copies of the `GET` answers are in
## `<index>/registry/<origin dir>/get/` (`index` is `Item.Index`). The decisions are pure. `get!` is command code over `Fx`: it is the one way that a command reads a `GET` route of the registry.
## `origin` in each function is the base URL form of R-RG7 (`Registry.base`). `path` is the path and the query of the request as sent (`/v1/packages/acme/lib/releases`), made with the builders of `Registry`.
## A registry request never has a token (R-RG3): the headers are `read_headers`.
RegistryCache :: [].{

	## What the cache knows about one copy: its ETag and its `max-age` (seconds, from the answer that made it), each one absent when the answer had none (Design Q218), and its age start (the modification time of its meta file, seconds).
	Cached : { etag : Try(Str, [None]), max_age : Try(U64, [None]), mtime : U64 }

	## What to do for one read: `Use` the copy with no request, `Revalidate(etag)` (the request has `If-None-Match`), `Fetch` (the request has no `If-None-Match`), `Missing` (offline and no copy).
	Step : [Use, Revalidate(Str), Fetch, Missing]

	## R-IX1: the dir of one registry: `<index>/registry/<name>`. `<name>` is `origin` with `://` changed to `_` and each other `:` changed to `_`:
	## `https://registry.example.org` gives `https_registry.example.org`, `http://127.0.0.1:8787` gives `http_127.0.0.1_8787`, `http://[::1]:8787` gives `http_[__1]_8787`.
	origin_dir : { roots : Roots, origin : Str } -> Str
	origin_dir = |facts| {
		name = facts.origin.replace_each("://", "_").replace_each(":", "_")
		Text.join(Roots.item(facts.roots, Item.Index), "registry/${name}")
	}

	## R-IX2: the key of a copy: the first 16 bytes of SHA-256 of the path and the query of the request as sent, as 32 lower-case hex digits. `url` is the whole URL (`origin` and then the path and the query): the key is of the text after `origin`.
	## The key of `/v1/releases?group=github.com%2Froc-lang%2Funicode%2Freleases%2Fdownload%2F%7Bv%7D%2F` is `98479255038c5453bde9313928301713` (R-IX2 gives this URL as the example).
	key : { origin : Str, url : Str } -> Str
	key = |facts| {
		path = facts.url.drop_prefix(facts.origin)
		hex = Crypto.SHA256.hash(path.to_utf8()).to_hex()
		Str.from_utf8(hex.to_utf8().take_first(32)) ?? ""
	}

	## R-IX1, R-IX2: the 3 paths of a copy. `dir` is `<origin_dir>/get`, `body` is `<dir>/<key>.json` and `meta` is `<dir>/<key>.meta`.
	files : { roots : Roots, origin : Str, url : Str } -> { dir : Str, body : Str, meta : Str }
	files = |facts| {
		dir = Text.join(RegistryCache.origin_dir({ roots: facts.roots, origin: facts.origin }), "get")
		id = RegistryCache.key({ origin: facts.origin, url: facts.url })
		{ dir, body: Text.join(dir, "${id}.json"), meta: Text.join(dir, "${id}.meta") }
	}

	## R-IX2: the text of a meta file (a proposal for the form, TW24): the line `url <path>`, the line `etag <ETag>` only when `etag` is `Ok`, and the line `max-age <seconds>` only when `max_age` is `Ok`, each with a newline at the end.
	## `path` is the path and the query. The ETag is the text of the header, with its quotes.
	meta_text : { path : Str, etag : Try(Str, [None]), max_age : Try(U64, [None]) } -> Str
	meta_text = |facts| {
		etag_line = match facts.etag {
			Ok(e) => "etag ${e}\n"
			Err(None) => ""
		}
		age_line = match facts.max_age {
			Ok(n) => "max-age ${n.to_str()}\n"
			Err(None) => ""
		}
		"url ${facts.path}\n${etag_line}${age_line}"
	}

	## The reverse of `meta_text`, for the ETag and the `max-age`. A line that is not one of the 3 forms is ignored. No `etag` line gives `etag: Err(None)`, no `max-age` line gives `max_age: Err(None)`.
	## `Err(BadMeta)` (the copy is as if it is missing): no `url` line, or a `max-age` that is not a number.
	parse_meta : Str -> Try({ etag : Try(Str, [None]), max_age : Try(U64, [None]) }, [BadMeta])
	parse_meta = |text| {
		lines = text.split_on("\n")
		has_url = lines.any(|line| line.starts_with("url "))
		etag = match lines.find_first(|line| line.starts_with("etag ")) {
			Ok(e) => Ok(e.drop_prefix("etag "))
			Err(_) => Err(None)
		}
		age = match lines.find_first(|line| line.starts_with("max-age ")) {
			Ok(a) => U64.from_str(a.drop_prefix("max-age ")).map_err(|_| BadMeta).map_ok(|n| Ok(n))
			Err(_) => Ok(Err(None))
		}
		match (has_url, age) {
			(True, Ok(max_age)) => Ok({ etag, max_age })
			_ => Err(BadMeta)
		}
	}

	## R-IX3, R-AP54: the `Cache-Control` of an answer. The header name is read in any case (the Worker sends lower case). The value is a comma-separated list of directives, white space around a directive ignored, the directive names in any case.
	## `no-store` gives `NoStore` (also when `max-age` is in the list). Else `max-age=<digits>` gives `MaxAge(n)`. Else (no header, no `max-age`, a `max-age` that is not digits): `NoMaxAge`.
	max_age_of : List((Str, Str)) -> [MaxAge(U64), NoStore, NoMaxAge]
	max_age_of = |headers| match header_value(headers, "cache-control") {
		Err(_) => NoMaxAge
		Ok(value) => {
			directives = value.split_on(",").map(|d| d.trim().with_ascii_lowercased())
			if directives.contains("no-store") {
				NoStore
			} else {
				match directives.find_first(|d| d.starts_with("max-age=")) {
					Ok(d) => match U64.from_str(d.drop_prefix("max-age=")) {
						Ok(n) => MaxAge(n)
						Err(_) => NoMaxAge
					}
					Err(_) => NoMaxAge
				}
			}
		}
	}

	## R-IX2, R-IX3, R-IX7: does an answer go in the cache? Only a 200 (a 404, a problem answer, a 304 and a 3xx are not kept as a new copy). A 200 is kept with or with no `ETag` and with or with no `max-age` (Design Q218). A `NoStore` answer: `Err(NotKept)`.
	keep : { status : U16, headers : List((Str, Str)) } -> Try({ etag : Try(Str, [None]), max_age : Try(U64, [None]) }, [NotKept])
	keep = |facts| {
		if facts.status != 200 {
			Err(NotKept)
		} else {
			match RegistryCache.max_age_of(facts.headers) {
				NoStore => Err(NotKept)
				MaxAge(n) => Ok({ etag: etag_of(facts.headers), max_age: Ok(n) })
				NoMaxAge => Ok({ etag: etag_of(facts.headers), max_age: Err(None) })
			}
		}
	}

	## R-AP24, R-AP43, R-IX2, R-IX3, R-IX6. `now` is the real clock (seconds). A copy that is in the future counts as age 0.
	##
	## | Case | Result |
	## | --- | --- |
	## | `offline`, a copy of any age (`newest` is not read) | `Use` |
	## | `offline`, no copy | `Missing` |
	## | `newest` (R-AP43 `no-cache`: no local copy is read), not offline | `Fetch`, also with a fresh copy |
	## | A copy with a `max_age` and `now - mtime < max_age` | `Use` |
	## | An older copy (`now - mtime >= max_age`, so `max-age=0` always), or a copy with no `max_age` (never fresh), with an ETag | `Revalidate(etag)` |
	## | The same, with no ETag (no `If-None-Match`) | `Fetch` |
	## | No copy | `Fetch` |
	plan : { cached : Try(Cached, [Missing]), now : U64, offline : Bool, newest : Bool } -> Step
	plan = |facts| match facts.cached {
		Err(Missing) => if facts.offline Missing else Fetch
		Ok(copy) => {
			age = if copy.mtime >= facts.now 0 else facts.now - copy.mtime
			fresh = match copy.max_age {
				Ok(limit) => age < limit
				Err(None) => Bool.False
			}
			if facts.offline {
				Use
			} else if facts.newest {
				Fetch
			} else if fresh {
				Use
			} else {
				match copy.etag {
					Ok(etag) => Revalidate(etag)
					Err(None) => Fetch
				}
			}
		}
	}

	## R-IX7, R-E6 (an answer that cannot be a copy): the failure for a 3xx answer (Talon follows no redirect of the registry) and for a 304 answer to a request with no `If-None-Match`. Kind `Network` (15). The text is a proposal (TW24).
	unusable : { origin : Str, path : Str, status : U16 } -> Fail
	unusable = |facts| Fail.new(Network, "the registry ${facts.origin} gave the answer ${facts.status.to_str()} for ${facts.path}, and Talon cannot use it. Try again later.")

	## R-AP45, R-AP24, R-AP43, R-AP55: the headers of a read, in this order: `User-Agent: tln/<version>` (`Registry.headers` with no body), then `If-None-Match: <etag>` when `etag` is set, then `Cache-Control: no-cache` when `newest` is set or `bookmark` is set, then `Talon-Bookmark: <bookmark>` when it is set.
	## A request with `no-cache` has no local copy (R-AP43), so it has no `If-None-Match` (the caller gives `etag`: `read_headers` drops it when `newest` or `bookmark` is set). A bookmark always comes with `no-cache` (R-AP43 case 2).
	read_headers : { version : Str, etag : Try(Str, [None]), newest : Bool, bookmark : Try(Str, [None]) } -> List((Str, Str))
	read_headers = |facts| {
		no_cache = facts.newest or facts.bookmark != Err(None)
		agent = Registry.headers({ version: facts.version, body: None })
		with_etag = match facts.etag {
			Ok(e) if !no_cache => agent.append(("If-None-Match", e))
			_ => agent
		}
		with_cache = if no_cache with_etag.append(("Cache-Control", "no-cache")) else with_etag
		match facts.bookmark {
			Ok(b) => with_cache.append(("Talon-Bookmark", b))
			Err(None) => with_cache
		}
	}

	## One read of a `GET` route with the cache (R-AP24, R-AP43, R-AP54, R-IX2, R-IX3, R-IX6). `now` is the real clock (`Fx.clock!`). `offline` is `--offline`. `newest` is the case 1 of R-AP43 (the read after an ingest). `bookmark` is the largest `Talon-Bookmark` of the ingest answers (R-AP41 row 5).
	## The result is `Answer`: the HTTP `status` and the `body` of the answer, and where it came from (`Live`: a request was made, `Copy(t)`: the copy, with the time of its meta). `NoCopy`: offline and no copy of the route.
	## A 304 after `Revalidate` gives `status` 200 and the body of the copy, source `Live`.
	##
	## The calls, in order (the L2 case `registry/ap24-read-cache` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | Not `newest` and no `bookmark` (or `offline`): one `list_dirs!` of `files.dir` (`NotFound` is an empty list), and when the listing has `<key>.meta`: one `read_files!` of `[meta, body]`. A copy is missing when an entry or a file is missing or `parse_meta` is `Err`. With `newest` or `bookmark` and not offline: no call. |
	## | 2 | `plan`. `Use`: the result is `Copy(mtime)` with the body, and there is no more call. `Missing`: `NoCopy`. |
	## | 3 | `Fetch` or `Revalidate`: one `http_get!` of `<origin><path>` with `read_headers`. There is never an `Authorization` header (R-RG3). No answer (`Timeout`, `Failed`): `Err(Registry.no_answer)` with `no answer in 20 s` for `Timeout` and the text for `Failed`. |
	## | 3b | Status 3xx (also 304 when the request has no `If-None-Match`: it had no copy, or the copy has no ETag, or `newest`, or `bookmark`): `Err(RegistryCache.unusable)` (R-IX7, exit 15), and no write. |
	## | 4 | Status 200 and `keep` is `Ok` (a 200 with no ETag, or no max-age, is kept: Design Q218): one `write_atomic!` of `[body file, meta file]` in this order (the meta is last: R-IX2). A `NoStore` answer, a 404, any other status: no write. The answer is given as it is (status, body), source `Live`. |
	## | 5 | Status 304 after `Revalidate` (the request had `If-None-Match`): one `write_atomic!` of `[meta file]` with the same ETag and `max-age` (the age starts again: R-IX2), the result is the copy as `status` 200. |
	## A failed write is `Err` of kind `Environment`, `cannot write <path>`.
	## Slice 225 (R-RG9): `get!` with the source of the registry setting (`""` for none). The source goes to the text of a failure with no answer.
	get! : Fx, { roots : Roots, origin : Str, version : Str, path : Str, now : U64, offline : Bool, newest : Bool, bookmark : Try(Str, [None]) } => Try([Answer({ status : U16, headers : List((Str, Str)), body : Str, source : [Live, Copy(U64)] }), NoCopy], Fail)
	get! = |fx, facts| get_via!(fx, { roots: facts.roots, origin: facts.origin, version: facts.version, path: facts.path, now: facts.now, offline: facts.offline, newest: facts.newest, bookmark: facts.bookmark, source: "" })

	get_via! : Fx, { roots : Roots, origin : Str, version : Str, path : Str, now : U64, offline : Bool, newest : Bool, bookmark : Try(Str, [None]), source : Str } => Try([Answer({ status : U16, headers : List((Str, Str)), body : Str, source : [Live, Copy(U64)] }), NoCopy], Fail)
	get_via! = |fx, facts| {
		url = "${facts.origin}${facts.path}"
		paths = RegistryCache.files({ roots: facts.roots, origin: facts.origin, url })
		no_cache = facts.newest or facts.bookmark != Err(None)
		copy = if no_cache and !facts.offline Err(Missing) else load_copy!(fx, paths, RegistryCache.key({ origin: facts.origin, url }))
		step = RegistryCache.plan({ cached: copy.map_ok(|c| c.cached), now: facts.now, offline: facts.offline, newest: no_cache })
		match (step, copy) {
			(Use, Ok(c)) => Ok(Answer({ status: 200, headers: [], body: c.body, source: Copy(c.cached.mtime) }))
			(Missing, _) => Ok(NoCopy)
			(Use, Err(_)) => Ok(NoCopy)
			(Revalidate(etag), _) => fetch!(fx, facts, paths, Ok(etag), copy)
			(Fetch, _) => fetch!(fx, facts, paths, Err(None), copy)
		}
	}
}

# The value of a header. The name is read in any case.
header_value : List((Str, Str)), Str -> Try(Str, [NotFound])
header_value = |headers, name| match headers.find_first(|(n, _)| n.with_ascii_lowercased() == name) {
	Ok((_, value)) => Ok(value)
	Err(_) => Err(NotFound)
}

# The ETag of an answer, with its quotes, or `Err(None)`.
etag_of : List((Str, Str)) -> Try(Str, [None])
etag_of = |headers| match header_value(headers, "etag") {
	Ok(e) => Ok(e)
	Err(_) => Err(None)
}

Copy : { cached : RegistryCache.Cached, body : Str }

# Step 1 of `get!`: the copy of a route. A copy is missing when an entry or a file is missing, or the meta is bad.
load_copy! : Fx, { dir : Str, body : Str, meta : Str }, Str => Try(Copy, [Missing])
load_copy! = |fx, files, key| {
	listing = match fx.list_dirs!([files.dir]) {
		[Ok(entries)] => entries
		_ => []
	}
	match listing.find_first(|e| e.name == "${key}.meta") {
		Err(_) => Err(Missing)
		Ok(entry) => match fx.read_files!([files.meta, files.body]) {
			[Ok(meta), Ok(body)] => match RegistryCache.parse_meta(meta) {
				Ok(m) => Ok({ cached: { etag: m.etag, max_age: m.max_age, mtime: entry.mtime }, body })
				Err(_) => Err(Missing)
			}
			_ => Err(Missing)
		}
	}
}

# Steps 3 to 5 of `get!`: the request, and the write of the copy.
fetch! = |fx, facts, files, etag, copy| {
	url = "${facts.origin}${facts.path}"
	headers = RegistryCache.read_headers({ version: facts.version, etag, newest: facts.newest, bookmark: facts.bookmark })
	reply = match fx.http_get!({ url, headers }) {
		Ok(r) => r
		Err(why) => {
			text = match why {
				Timeout => "no answer in 20 s"
				Failed(t) => t
			}
			return Err(Registry.no_answer({ origin: facts.origin, why: text, source: facts.source }))
		}
	}
	if reply.status >= 300 and reply.status < 400 and reply.status != 304 {
		return Err(RegistryCache.unusable({ origin: facts.origin, path: facts.path, status: reply.status }))
	}
	if reply.status == 304 {
		match (etag, copy) {
			(Ok(_), Ok(c)) => {
				meta = RegistryCache.meta_text({ path: facts.path, etag: c.cached.etag, max_age: c.cached.max_age })
				write!(fx, [{ path: files.meta, content: meta }])?
				return Ok(Answer({ status: 200, headers: [], body: c.body, source: Live }))
			}
			_ => return Err(RegistryCache.unusable({ origin: facts.origin, path: facts.path, status: reply.status }))
		}
	}
	match RegistryCache.keep({ status: reply.status, headers: reply.headers }) {
		Ok(kept) => {
			meta = RegistryCache.meta_text({ path: facts.path, etag: kept.etag, max_age: kept.max_age })
			write!(fx, [{ path: files.body, content: reply.body }, { path: files.meta, content: meta }])?
		}
		Err(NotKept) => {}
	}
	Ok(Answer({ status: reply.status, headers: reply.headers, body: reply.body, source: Live }))
}

write! : Fx, List({ path : Str, content : Str }) => Try({}, Fail)
write! = |fx, writes| match fx.write_atomic!(writes) {
	Ok(_) => Ok({})
	Err(failed) => Err(Fail.new(Environment, "cannot write ${failed.path}"))
}
