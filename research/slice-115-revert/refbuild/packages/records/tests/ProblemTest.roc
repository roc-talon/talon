import records.Problem

ProblemTest :: [].{}

# W0 tests of packages/records/Problem.roc (slice 104). The expected values are the table of R-AP21.
# The 17 types: URI and status.
types : List((Problem.Kind, Str, U16))
types = [
	(BadRequest, "/errors/bad-request", 400),
	(Unauthenticated, "/errors/unauthenticated", 401),
	(Forbidden, "/errors/forbidden", 403),
	(RepositoryChanged, "/errors/repository-changed", 403),
	(NotFound, "/errors/not-found", 404),
	(MethodNotAllowed, "/errors/method-not-allowed", 405),
	(LabelConflict, "/errors/label-conflict", 409),
	(IdCollision, "/errors/id-collision", 409),
	(UnsupportedClient, "/errors/unsupported-client", 400),
	(TooLarge, "/errors/too-large", 413),
	(UnsupportedMediaType, "/errors/unsupported-media-type", 415),
	(NotACandidate, "/errors/not-a-candidate", 422),
	(SuccessorMismatch, "/errors/successor-mismatch", 422),
	(SweepIncomplete, "/errors/sweep-incomplete", 422),
	(RateLimited, "/errors/rate-limited", 429),
	(Internal, "/errors/internal", 500),
	(Upstream, "/errors/upstream", 502),
]

# R-AP21: the type and the status of each kind, and the kind of each type.
expect types.map(|(k, _, _)| (Problem.type_uri(k), Problem.status(k))) == types.map(|(_, uri, st)| (uri, st))
expect types.map(|(_, uri, _)| Problem.kind_from_uri(uri)) == types.map(|(k, _, _)| Ok(k))

# R-AP21: a client does not crash on a type of a later registry.
expect Problem.kind_from_uri("/errors/teapot") == Err(UnknownType)
expect Problem.kind_from_uri("") == Err(UnknownType)

# R-AP21, R-AP44, R-AP46, R-AP45, R-TP12: the body has `type`, `title`, `status`, `detail`, and the extra members of some types. Member order is free. A member that the client does not know is ignored (R-AP44).
decoded : List((Str, Problem.Body))
decoded = [
	(
		"{\"type\":\"/errors/not-found\",\"title\":\"Not found\",\"status\":404,\"detail\":\"no such release\"}",
		{ type_text: "/errors/not-found", title: "Not found", status: 404, detail: "no such release", extra: None },
	),
	(
		"{\"detail\":\"d\",\"status\":413,\"title\":\"Too large\",\"type\":\"/errors/too-large\",\"limit\":1000,\"field\":\"hashes\"}",
		{ type_text: "/errors/too-large", title: "Too large", status: 413, detail: "d", extra: Limit({ field: "hashes", limit: 1000 }) },
	),
	(
		"{\"type\":\"/errors/unsupported-client\",\"title\":\"Unsupported client\",\"status\":400,\"detail\":\"old\",\"minimum\":\"0.5.0\"}",
		{ type_text: "/errors/unsupported-client", title: "Unsupported client", status: 400, detail: "old", extra: Minimum("0.5.0") },
	),
	(
		"{\"type\":\"/errors/repository-changed\",\"title\":\"Repository changed\",\"status\":403,\"detail\":\"d\",\"issues_url\":\"https://example.org/issues\"}",
		{ type_text: "/errors/repository-changed", title: "Repository changed", status: 403, detail: "d", extra: IssuesUrl("https://example.org/issues") },
	),
	(
		"{\"type\":\"/errors/internal\",\"title\":\"Internal error\",\"status\":500,\"detail\":\"\",\"trace\":\"ignored\"}",
		{ type_text: "/errors/internal", title: "Internal error", status: 500, detail: "", extra: None },
	),
]

expect decoded.map(|(text, _)| Problem.decode(text)) == decoded.map(|(_, body)| Ok(body))

# R-AP21: encode then decode gives the same body, also for a `detail` with escapes. The text has the relative URI of the type.
expect {
	details = ["", "a \"quoted\" word", "two\nlines", "caf\u(e9) \u(20ac)"]
	bodies = decoded.map(|(_, b)| b).map(|b| details.map(|d| { ..b, detail: d })).join()
	bodies.all(|b| Problem.decode(Problem.encode(b)) == Ok(b)) and bodies.all(|b| Problem.encode(b).contains("\"type\":\"${b.type_text}\""))
}

# R-AP52: a type that the client does not know is kept as read, with status, title, detail and the extra members that it knows.
expect Problem.decode("{\"type\":\"/errors/teapot\",\"title\":\"Teapot\",\"status\":418,\"detail\":\"short\",\"minimum\":\"1.0.0\"}") == Ok({ type_text: "/errors/teapot", title: "Teapot", status: 418, detail: "short", extra: Minimum("1.0.0") })

# R-AP52: a body that is not JSON, or has no `type`, or no `status`, is an error (BadJson).
bad_bodies : List(Str)
bad_bodies = [
	"not json",
	"[]",
	"{\"title\":\"T\",\"status\":404,\"detail\":\"d\"}",
	"{\"type\":\"/errors/not-found\",\"title\":\"T\",\"detail\":\"d\"}",
]

expect bad_bodies.all(
	|t| match Problem.decode(t) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	},
)

# R-AP21, R-AP52: only `type` and `status` are required. A body with no `title` or no `detail` decodes with the empty text.
expect Problem.decode("{\"type\":\"/errors/not-found\",\"status\":404,\"detail\":\"d\"}") == Ok({ type_text: "/errors/not-found", title: "", status: 404, detail: "d", extra: None }) and Problem.decode("{\"type\":\"/errors/not-found\",\"status\":404,\"title\":\"T\"}") == Ok({ type_text: "/errors/not-found", title: "T", status: 404, detail: "", extra: None })
