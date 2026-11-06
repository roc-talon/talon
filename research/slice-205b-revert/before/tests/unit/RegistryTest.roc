import lib.Fail
import lib.JsonDoc
import lib.Registry

RegistryTest :: [].{}

# Slice 201 (docs/slices/201-registry-client-core.md). Pure: the URLs, the headers and the failures of the registry client.

origin = "http://127.0.0.1:9"

version = "0.4.1"

group_url = "github.com/roc-lang/unicode/releases/download/{v}/"

# The problem answers of the Worker (worker/tests/cases/*/expect/responses.jsonl, with `title` and `detail` as R-AP21 says).
prob = |type, status, extra| "{\"type\":\"${type}\",\"title\":\"T\",\"status\":${status},\"detail\":\"D\"${extra}}"

reply = |status, body| { status, body }

# The kind code, the message and the details of a refusal.
shape = |method, status, body| {
	f = Registry.refuse({ origin, version, method, reply: reply(status, body) })
	(f.kind.code(), f.message, f.details)
}

code_of = |method, status, body| shape(method, status, body).0

# R-AP1, R-AP2, R-AP13, R-AP69, R-PK7: the URLs. The query values of R-AP13 are the bytes of the Worker case `reads/ap13-group-series-after`.
# The same `encode` builds each one: each byte outside A-Z a-z 0-9 - . _ ~ is % and 2 UPPER-case hex digits, in UTF-8 bytes, and the member order is group, then series.
expect {
	enc_ok = Registry.encode("a b+c~\u(E9)_-.:/%{}") == "a%20b%2Bc~%C3%A9_-.%3A%2F%25%7B%7D"
	group_ok = Registry.releases_url({ origin, group: group_url, series: Err(None) }) == "${origin}/v1/releases?group=github.com%2Froc-lang%2Funicode%2Freleases%2Fdownload%2F%7Bv%7D%2F"
	series_ok = Registry.releases_url({ origin, group: group_url, series: Ok("0.25") }) == "${origin}/v1/releases?group=github.com%2Froc-lang%2Funicode%2Freleases%2Fdownload%2F%7Bv%7D%2F&series=0.25"
	series_enc_ok = Registry.releases_url({ origin, group: "example.com/pkg/{v}/", series: Ok("1 2") }) == "${origin}/v1/releases?group=example.com%2Fpkg%2F%7Bv%7D%2F&series=1%202"
	# R-AP69 row 3: the lower-case name (R-AP56: the registry reads a name with no case).
	repo_ok = Registry.releases_of_repo_url({ origin, owner: "Roc-Lang", repo: "Unicode" }) == "${origin}/v1/packages/roc-lang/unicode/releases"
	# R-AP69 row 4: the hash keeps its case.
	hash = "6k78AbasGMFFrhG95Pj6jQbqkVt7FQMhVgemxJovWKR6"
	art_ok = Registry.artifact_url({ origin, hash }) == "${origin}/v1/artifacts/${hash}"
	closure_ok = Registry.closure_url(origin) == "http://127.0.0.1:9/v1/closure"
	enc_ok and group_ok and series_ok and series_enc_ok and repo_ok and art_ok and closure_ok
}

# R-RG7 rows 1 to 3 and 6, R-RG8 (Design Q207, Q210): the base URL form of a registry setting. The exit code of a bad setting (2 from the flag or the variable, 19 from config.toml) is the flow that reads the setting.
expect {
	ok : List((Str, Str))
	ok = [
		("https://registry.example.org", "https://registry.example.org"),
		("HTTPS://Registry.Example.org:443/", "https://registry.example.org"),
		("https://registry.example.org:8443", "https://registry.example.org:8443"),
		# A port that is the default of the other scheme stays.
		("https://registry.example.org:80", "https://registry.example.org:80"),
		("http://127.0.0.1:8787", "http://127.0.0.1:8787"),
		("http://127.0.0.1:80/", "http://127.0.0.1"),
		("HTTP://LocalHost:9", "http://localhost:9"),
		("http://[::1]:8787", "http://[::1]:8787"),
		("https://[2001:DB8::1]", "https://[2001:db8::1]"),
		("https://192.0.2.7:9000", "https://192.0.2.7:9000"),
	]
	bad = [
		# R-RG7 row 1: http only to a loopback host.
		"http://registry.example.org",
		"http://127.0.0.2",
		"http://192.168.0.1:8787",
		"ftp://registry.example.org",
		# Row 2: no path except one `/`, no query, no fragment, no user info.
		"https://registry.example.org/talon",
		"https://registry.example.org/talon/",
		"https://registry.example.org//",
		"https://registry.example.org?x=1",
		"https://registry.example.org/?x=1",
		"https://registry.example.org#f",
		"https://user@registry.example.org",
		"https://registry.example.org:",
		"https://registry.example.org:80x",
		"https://regi stry.example.org",
		# Row 6: not a URL.
		"direct",
		"",
		"registry.example.org",
		"https://",
	]
	ok.all(|(text, form)| Registry.base(text) == Ok(form)) and bad.all(|text| Registry.base(text) == Err(BadRegistry))
}

# R-AP45, R-AP23: the headers.
expect {
	get = Registry.headers({ version, body: None }) == [("User-Agent", "tln/0.4.1")]
	post = Registry.headers({ version, body: Json }) == [("User-Agent", "tln/0.4.1"), ("Content-Type", "application/json")]
	get and post
}

# R-AP21, R-AP52, R-AP22: the problem read. An unknown type is kept as read. A body that is not problem details is `NotProblem`.
expect {
	known = Registry.problem(reply(400, prob("/errors/unsupported-client", "400", ",\"minimum\":\"0.5.0\""))) == Ok({ type_text: "/errors/unsupported-client", title: "T", status: 400, detail: "D", extra: Minimum("0.5.0") })
	large = Registry.problem(reply(413, prob("/errors/too-large", "413", ",\"field\":\"groups\",\"limit\":300"))) == Ok({ type_text: "/errors/too-large", title: "T", status: 413, detail: "D", extra: Limit({ field: "groups", limit: 300 }) })
	unknown = Registry.problem(reply(422, prob("/errors/later-type", "422", ""))) == Ok({ type_text: "/errors/later-type", title: "T", status: 422, detail: "D", extra: None })
	html = Registry.problem(reply(404, "<html>not found</html>")) == Err(NotProblem)
	no_status = Registry.problem(reply(404, "{\"type\":\"/errors/not-found\"}")) == Err(NotProblem)
	known and large and unknown and html and no_status
}

# R-E6, R-EC15, R-EC20, R-AP22, R-AP52: the table. (method, status, type) to the exit code. The code comes from the HTTP status.
expect {
	p : Str, U16 -> Str
	p = |type, status| prob(type, status.to_str(), "")
	rows : List((Registry.Method, U16, Str, I32))
	rows = [
		# 400, 405, 415: a fault of tln or a version skew (1).
		(Get, 400, p("/errors/bad-request", 400), 1),
		(Post, 405, p("/errors/method-not-allowed", 405), 1),
		(Put, 415, p("/errors/unsupported-media-type", 415), 1),
		(Get, 400, p("/errors/unsupported-client", 400), 1),
		(Post, 413, p("/errors/too-large", 413), 1),
		# 400 with a type that the table does not have: by the HTTP status (R-AP52).
		(Get, 400, p("/errors/later-type", 400), 1),
		# A refused write: 20.
		(Post, 401, p("/errors/unauthenticated", 401), 20),
		(Put, 403, p("/errors/forbidden", 403), 20),
		(Delete, 404, p("/errors/not-found", 404), 20),
		(Post, 409, p("/errors/label-conflict", 409), 20),
		(Post, 422, p("/errors/not-a-candidate", 422), 20),
		(Post, 422, p("/errors/later-type", 422), 20),
		# The same statuses to a read: 15 (the last row).
		(Get, 401, p("/errors/unauthenticated", 401), 15),
		(Get, 403, p("/errors/forbidden", 403), 15),
		(Get, 404, p("/errors/not-found", 404), 15),
		(Get, 409, p("/errors/label-conflict", 409), 15),
		(Get, 422, p("/errors/not-a-candidate", 422), 15),
		# 429, 5xx, other statuses, also to a write: 15.
		(Get, 429, p("/errors/rate-limited", 429), 15),
		(Post, 429, p("/errors/rate-limited", 429), 15),
		(Post, 500, p("/errors/internal", 500), 15),
		(Put, 502, p("/errors/upstream", 502), 15),
		(Get, 302, p("/errors/later-type", 302), 15),
		(Post, 418, p("/errors/later-type", 418), 15),
		# An error answer that is not problem details: 15, for each status and method.
		(Post, 422, "<html>no</html>", 15),
		(Get, 400, "", 15),
		(Delete, 403, "{\"message\":\"x\"}", 15),
	]
	rows.all(|(method, status, body, code)| code_of(method, status, body) == code)
}

# R-J7, R-AP52: `error.details` has `status` (the HTTP status) and `type` (as read, also an unknown one). With no problem details, `status` only (a proposal).
expect {
	d1 = shape(Post, 409, prob("/errors/label-conflict", "409", "")).2 == Ok(Obj([("status", Num(409)), ("type", Text("/errors/label-conflict"))]))
	d2 = shape(Get, 502, prob("/errors/later-type", "502", "")).2 == Ok(Obj([("status", Num(502)), ("type", Text("/errors/later-type"))]))
	d3 = shape(Get, 404, "<html>").2 == Ok(Obj([("status", Num(404))]))
	d4 = Registry.no_answer({ origin, why: "connection refused" }).details == Err(NoDetails)
	d1 and d2 and d3 and d4
}

# R-E6, R-AP45, R-AP46: the 2 texts that CLI 3 gives, and the proposed texts of the other rows (R-OUT2).
expect {
	min = shape(Get, 400, prob("/errors/unsupported-client", "400", ",\"minimum\":\"0.5.0\"")).1 == "tln 0.4.1 is too old for http://127.0.0.1:9: update to 0.5.0 or later"
	large = shape(Post, 413, prob("/errors/too-large", "413", ",\"field\":\"groups\",\"limit\":300")).1 == "the registry http://127.0.0.1:9 refused the request: groups is over the limit of 300"
	bad = shape(Get, 400, prob("/errors/bad-request", "400", "")).1 == "the registry http://127.0.0.1:9 refused the request (/errors/bad-request): D. This is a fault of tln 0.4.1 or a version skew."
	# No detail: the title.
	no_detail = shape(Get, 400, "{\"type\":\"/errors/bad-request\",\"title\":\"Bad request\",\"status\":400}").1 == "the registry http://127.0.0.1:9 refused the request (/errors/bad-request): Bad request. This is a fault of tln 0.4.1 or a version skew."
	rejected = shape(Post, 409, prob("/errors/label-conflict", "409", "")).1 == "D (/errors/label-conflict). Fix the release or the workflow, then run the command again."
	net = shape(Get, 502, prob("/errors/upstream", "502", "")).1 == "the registry answered 502 (/errors/upstream). Try again later."
	not_registry = shape(Get, 404, "<html>").1 == "http://127.0.0.1:9 answered 404 and the answer is not problem details. Check the registry setting."
	none = Registry.no_answer({ origin, why: "connection refused" }).message == "the registry http://127.0.0.1:9 gave no answer: connection refused. Try again later."
	min and large and bad and no_detail and rejected and net and not_registry and none
}

# R-AP51, R-E6 (a 2xx answer that does not decode), R-AP44, R-PK7: the closure answer. A missing member, a null required member and a wrong type are exit 15 and name the registry. An unknown member is ignored.
answer = |log_size, extra| "{\"artifacts\":[],\"releases\":[],\"epochs\":[],\"runs\":[],\"nearest\":[],\"hints\":[],${log_size}\"unknown\":[\"x\"],\"checked\":[],\"repos\":[]${extra}}"

expect {
	ok = match Registry.closure_answer({ origin, body: answer("\"log_size\":7,", ",\"later\":{\"a\":1}") }) {
		Ok(a) => a.log_size == 7 and a.unknown == ["x"] and a.artifacts.is_empty()
		Err(_) => Bool.False
	}
	bad = |body| match Registry.closure_answer({ origin, body }) {
		Err(f) => f.kind.code() == 15 and f.message.contains(origin)
		Ok(_) => Bool.False
	}
	missing = bad(answer("", "")) and (
		match Registry.closure_answer({ origin, body: answer("", "") }) {
			Err(f) => f.message.contains("log_size")
			Ok(_) => Bool.False
		}
	)
	null_member = bad(answer("\"log_size\":null,", ""))
	wrong_type = bad(answer("\"log_size\":\"7\",", ""))
	not_json = bad("<html></html>")
	ok and missing and null_member and wrong_type and not_json
}
