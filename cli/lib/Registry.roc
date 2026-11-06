import records.Closure as Wire
import records.Problem
import Fail
import JsonDoc

## The registry client core (slice 201, Registry 4, 4.2; CLI 3). Pure: no `Fx`, no clock. The wire types and codecs are the package `records` (R-PK7, slice 104).
## The URLs of the read routes, the headers of a request, the read of a problem answer, the table of R-E6 and the reader of a closure answer.
## `origin` in each function is the base URL form of R-RG7 row 3 (`Registry.base` of the setting): no path, no trailing `/`. A builder adds the route path to it as it is (R-RG7 row 5).
Registry :: [].{

	## The kind of a request. R-E6 maps a refusal of `Post`, `Put` and `Delete` (a write) to exit 20. `Query` is `POST /v1/closure`: a read (Design Q194, R-AP74 row 1), so it is never exit 20.
	Method : [Get, Query, Post, Put, Delete]

	## An answer that the client got: the HTTP status and the body text. The body of an error answer is read with `problem`.
	Reply : { status : U16, body : Str }

	## R-RG7 rows 1 to 3, 6 (Design Q207, Q210): the base URL form of a registry setting that is a URL. The scheme and the host are read in lower case. The scheme is `https` (any host) or `http` (only to `127.0.0.1`, `[::1]` or `localhost`).
	## The parts are the host, an optional port, and no other part: no user info, no query, no fragment, no path except one `/` at the end. The host is letters, digits, `-` and `.`, or an IPv6 address in `[ ]`. The form is `<scheme>://<host>` and `:<port>` only when the port is not the default (443 for `https`, 80 for `http`).
	## `HTTPS://Registry.Example.org:443/` gives `https://registry.example.org`. Any other text, `direct` too, is `Err(BadRegistry)`: the caller handles `direct` first, and maps the error to exit 2 (`--registry`, `TALON_REGISTRY`) or exit 19 (`config.toml`) with its message (a flow slice).
	base : Str -> Try(Str, [BadRegistry])
	base = |setting| {
		text = setting.with_ascii_lowercased()
		trimmed = text.drop_suffix("/")
		{ scheme, rest } = Registry.split_scheme(trimmed)?
		parts = Registry.split_authority(rest)?
		if scheme == "http" and !Registry.is_loopback(parts.host) {
			Err(BadRegistry)
		} else {
			default = if scheme == "https" 443 else 80
			port = match parts.port {
				Ok(n) if n != default => ":${n.to_str()}"
				_ => ""
			}
			Ok("${scheme}://${parts.host}${port}")
		}
	}

	split_scheme : Str -> Try({ scheme : Str, rest : Str }, [BadRegistry])
	split_scheme = |text| match text.split_first("://") {
		Ok({ before: "https", after }) => Ok({ scheme: "https", rest: after })
		Ok({ before: "http", after }) => Ok({ scheme: "http", rest: after })
		_ => Err(BadRegistry)
	}

	is_loopback : Str -> Bool
	is_loopback = |host| host == "127.0.0.1" or host == "localhost" or host == "[::1]"

	## The host and the optional port of an authority with no other part.
	split_authority : Str -> Try({ host : Str, port : Try(U16, [None]) }, [BadRegistry])
	split_authority = |auth| {
		split = if auth.starts_with("[") {
			match auth.split_first("]") {
				Ok({ before, after }) => Ok({ host: "${before}]", tail: after, v6: Bool.True })
				Err(_) => Err(BadRegistry)
			}
		} else {
			match auth.split_first(":") {
				Ok({ before, after }) => Ok({ host: before, tail: ":${after}", v6: Bool.False })
				Err(_) => Ok({ host: auth, tail: "", v6: Bool.False })
			}
		}
		{ host, tail, v6 } = split?
		host_ok = if v6 Registry.all_bytes(host.drop_prefix("[").drop_suffix("]"), Registry.is_v6_byte) else Registry.all_bytes(host, Registry.is_host_byte)
		if !host_ok or host.is_empty() or host == "[]" {
			Err(BadRegistry)
		} else if tail.is_empty() {
			Ok({ host, port: Err(None) })
		} else if tail.starts_with(":") {
			digits = tail.drop_prefix(":")
			if digits.is_empty() or !Registry.all_bytes(digits, |b| b >= '0' and b <= '9') {
				Err(BadRegistry)
			} else {
				U16.from_str(digits).map_ok(|n| { host, port: Ok(n) }).map_err(|_| BadRegistry)
			}
		} else {
			Err(BadRegistry)
		}
	}

	all_bytes : Str, (U8 -> Bool) -> Bool
	all_bytes = |text, ok| text.to_utf8().all(ok)

	is_host_byte : U8 -> Bool
	is_host_byte = |b| (b >= 'a' and b <= 'z') or (b >= '0' and b <= '9') or b == '-' or b == '.'

	is_v6_byte : U8 -> Bool
	is_v6_byte = |b| (b >= 'a' and b <= 'f') or (b >= '0' and b <= '9') or b == ':' or b == '.'

	## R-AP69: the encoding of a query value and of a path part: each byte outside the unreserved set of RFC 3986 (`A-Z`, `a-z`, `0-9`, `-`, `.`, `_`, `~`) is `%` and 2 UPPER-case hex digits. A byte is a byte of the UTF-8 text.
	## ONE function: each URL builder below calls it, so the keys of the Worker cache (R-AP69) are the URLs that `tln` sends.
	encode : Str -> Str
	encode = |text| text.to_utf8().fold("", |acc, b| "${acc}${Registry.encode_byte(b)}")

	encode_byte : U8 -> Str
	encode_byte = |b| {
		plain = (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9') or b == '-' or b == '.' or b == '_' or b == '~'
		if plain {
			Str.from_utf8([b]) ?? ""
		} else {
			"%${Registry.hex(b // 16)}${Registry.hex(b % 16)}"
		}
	}

	hex : U8 -> Str
	hex = |n| Str.from_utf8([if n < 10 '0' + n else 'A' + (n - 10)]) ?? ""

	## R-AP1: `<origin>/v1/packages/<owner>/<repo>/releases`. `owner` and `repo` are written in lower case (ASCII), as the cache key of R-AP69 row 3 needs, and then encoded with `encode`.
	releases_of_repo_url : { origin : Str, owner : Str, repo : Str } -> Str
	releases_of_repo_url = |facts| {
		owner = Registry.encode(facts.owner.with_ascii_lowercased())
		repo = Registry.encode(facts.repo.with_ascii_lowercased())
		"${facts.origin}/v1/packages/${owner}/${repo}/releases"
	}

	## R-AP2: `<origin>/v1/artifacts/<hash>`. The hash is encoded with `encode`, and its case is kept (it is base58).
	artifact_url : { origin : Str, hash : Str } -> Str
	artifact_url = |facts| "${facts.origin}/v1/artifacts/${Registry.encode(facts.hash)}"

	## R-AP13 and R-AP69 rows 1 and 2: `<origin>/v1/releases?group=<group>`, with `&series=<series>` after it when `series` is set. The members are in this order. `group` and `series` are encoded with `encode`.
	releases_url : { origin : Str, group : Str, series : Try(Str, [None]) } -> Str
	releases_url = |facts| {
		base_url = "${facts.origin}/v1/releases?group=${Registry.encode(facts.group)}"
		match facts.series {
			Ok(series) => "${base_url}&series=${Registry.encode(series)}"
			Err(None) => base_url
		}
	}

	## R-AP16: `<origin>/v1/closure`.
	closure_url : Str -> Str
	closure_url = |origin| "${origin}/v1/closure"

	## R-AP45, R-AP23: the headers of each request, in this order: `User-Agent: tln/<version>`, then `Content-Type: application/json` when the request has a body. No other header (the cache headers are slice 202). `version` is the version of `tln` (`0.4.1`).
	headers : { version : Str, body : [None, Json] } -> List((Str, Str))
	headers = |facts| {
		agent = ("User-Agent", "tln/${facts.version}")
		match facts.body {
			None => [agent]
			Json => [agent, ("Content-Type", "application/json")]
		}
	}

	## R-AP21, R-AP52, R-AP22: the problem details of an error answer (`records.Problem.decode`). A body that is not JSON, or has no `type` or no `status`, is `Err(NotProblem)`. A `type` that the table of R-AP21 does not have is kept as read (`type_text`).
	problem : Registry.Reply -> Try(Problem.Body, [NotProblem])
	problem = |reply| Problem.decode(reply.body).map_err(|_| NotProblem)

	## R-E6, R-J7, R-AP22, R-AP45, R-AP46, R-AP52: the failure for an error answer (a status that is not 2xx). The kind comes from the HTTP status (the type only changes the message):
	##
	## | Answer | Kind (exit code) |
	## | --- | --- |
	## | `reply.body` is not problem details (`problem` is `NotProblem`), any status | `Network` (15) |
	## | 400, 405, 413, 415 | `Internal` (1) |
	## | `unsupported-client` with no `minimum` (R-AP74 row 2) | `Internal` (1), text `update to the newest version` |
	## | 401, 403, 404, 409, 422 and `method` is `Post`, `Put` or `Delete` (not `Query`, a read) | `Rejected` (20) |
	## | 503 with the type `/errors/busy` (slice 201b, R-AP82): `the registry is busy (503). Try again in <n> s.` or `Try again later.` as the 429 rule | `Network` (15) |
	## | Any other status (429, 5xx, a 4xx to a `Get`, 3xx, ...) | `Network` (15) |
	##
	## `details` (R-J7): `{"status": <HTTP status>, "type": <type_text as read>}`, in this order. With no problem details: `{"status": <HTTP status>}`.
	## Messages: see the "Output" section of the slice file (proposals). Two are in CLI 3 R-E6: `unsupported-client` (400, with `minimum`) and the text `too-large` names `field` and `limit`.
	## Slice 208 (Design Q424, R-AP25): `retry_after ?:` is the value of the header `Retry-After` of the answer (the name in any case), as the text of the answer. For a 429 the message gives the time: `... Try again in <n> s.` when the text, with white space cut, is a whole number
	## (`<n>` as the number); with no `retry_after`, or a value that is not a whole number (`soon`, `1.5`, `-3`, empty), the message is as before (`Try again later.`). The other statuses ignore it.
	refuse : { origin : Str, version : Str, method : Registry.Method, reply : Registry.Reply, retry_after ?: Str } -> Fail
	refuse = |facts| {
		status = facts.reply.status
		match Registry.problem(facts.reply) {
			Err(NotProblem) => {
				message = "${facts.origin} answered ${status.to_str()} and the answer is not problem details. Check the registry setting."
				{ ..Fail.new(Network, message), details: Ok(Obj([("status", Num(status.to_i64()))])) }
			}
			Ok(body) => {
				details = Obj([("status", Num(status.to_i64())), ("type", Text(body.type_text))])
				{ ..Registry.problem_fail(facts, body), details: Ok(details) }
			}
		}
	}

	problem_fail : { origin : Str, version : Str, method : Registry.Method, reply : Registry.Reply, retry_after ?: Str }, Problem.Body -> Fail
	problem_fail = |facts, body| {
		status = facts.reply.status
		what = if body.detail.is_empty() body.title else body.detail
		refused = "the registry ${facts.origin} refused the request"
		internal = Fail.new(Internal, "${refused} (${body.type_text}): ${what}. This is a fault of tln ${facts.version} or a version skew.")
		is_write = facts.method == Post or facts.method == Put or facts.method == Delete
		match (status, body.extra) {
			(400, Minimum(min)) if body.type_text == Problem.type_uri(UnsupportedClient) => Fail.new(Internal, "tln ${facts.version} is too old for ${facts.origin}: update to ${min} or later")
			(400, _) if body.type_text == Problem.type_uri(UnsupportedClient) => Fail.new(Internal, "tln ${facts.version} is too old for ${facts.origin}: update to the newest version")
			(413, Limit({ field, limit })) if body.type_text == Problem.type_uri(TooLarge) => Fail.new(Internal, "${refused}: ${field} is over the limit of ${limit.to_str()}")
			(400, _) | (405, _) | (413, _) | (415, _) => internal
			(401, _) | (403, _) | (404, _) | (409, _) | (422, _) if is_write => Fail.new(Rejected, "${what} (${body.type_text}). Fix the release or the workflow, then run the command again.")
			(429, _) => Fail.new(Network, "the registry answered 429 (${body.type_text}). ${Registry.wait_text(facts.?retry_after ?? "")}")
			(503, _) if body.type_text == Problem.type_uri(Busy) => Fail.new(Network, "the registry is busy (503). ${Registry.wait_text(facts.?retry_after ?? "")}")
			_ => Fail.new(Network, "the registry answered ${status.to_str()} (${body.type_text}). Try again later.")
		}
	}

	## R-AP25, Design Q424: the end of a 429 message. A whole number of seconds (white space cut) gives `Try again in <n> s.`, anything else `Try again later.`
	wait_text : Str -> Str
	wait_text = |text| {
		trimmed = text.trim()
		if !trimmed.is_empty() and Registry.all_bytes(trimmed, |b| b >= '0' and b <= '9') {
			match U64.from_str(trimmed) {
				Ok(n) => "Try again in ${n.to_str()} s."
				Err(_) => "Try again later."
			}
		} else {
			"Try again later."
		}
	}

	## Q424: the value of the header `Retry-After` of an answer (the name in any case), or the empty text.
	retry_after_of : List((Str, Str)) -> Str
	retry_after_of = |list| match list.find_first(|(name, _)| name.with_ascii_lowercased() == "retry-after") {
		Ok((_, value)) => value
		Err(_) => ""
	}

	## R-E6 (no answer): the failure for a request that got no answer (a refused connection, a timeout). Kind `Network` (15). No `details`.
	no_answer : { origin : Str, why : Str } -> Fail
	no_answer = |facts| Fail.new(Network, "the registry ${facts.origin} gave no answer: ${facts.why}. Try again later.")

	## R-AP51, R-E6 (a 2xx answer that does not decode): the closure answer of R-AP17 (`records.Closure.decode_answer`). A required member that is missing, `null`, or of a wrong type: `Err` with kind `Network` (15) and a message that names the registry `origin`. An unknown member is ignored (R-AP44).
	closure_answer : { origin : Str, body : Str } -> Try(Wire.Answer, Fail)
	closure_answer = |facts| match Wire.decode_answer(facts.body) {
		Ok(answer) => Ok(answer)
		Err(BadJson(text)) => Err(Fail.new(Network, "the answer of the registry ${facts.origin} is not a closure answer: ${text}"))
	}
}
