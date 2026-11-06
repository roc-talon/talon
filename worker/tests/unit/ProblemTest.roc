import lib.Problem

ProblemTest :: [].{}

# W0 tests of worker/lib/Problem.roc (slice 101).

# R-AP21: each of the 18 problem types has its relative URI, its status and its title (the titles are a TW24 proposal, slice 101 section 4).
types : List((Problem.Kind, Str, U16, Str))
types = [
	(BadRequest, "/errors/bad-request", 400, "Bad request"),
	(Unauthenticated, "/errors/unauthenticated", 401, "Unauthenticated"),
	(Forbidden, "/errors/forbidden", 403, "Forbidden"),
	(RepositoryChanged, "/errors/repository-changed", 403, "Repository changed"),
	(NotFound, "/errors/not-found", 404, "Not found"),
	(MethodNotAllowed, "/errors/method-not-allowed", 405, "Method not allowed"),
	(LabelConflict, "/errors/label-conflict", 409, "Label conflict"),
	(IdCollision, "/errors/id-collision", 409, "Id collision"),
	(UnsupportedClient, "/errors/unsupported-client", 400, "Unsupported client"),
	(TooLarge, "/errors/too-large", 413, "Too large"),
	(UnsupportedMediaType, "/errors/unsupported-media-type", 415, "Unsupported media type"),
	(NotACandidate, "/errors/not-a-candidate", 422, "Not a candidate"),
	(SuccessorMismatch, "/errors/successor-mismatch", 422, "Successor mismatch"),
	(SweepIncomplete, "/errors/sweep-incomplete", 422, "Sweep incomplete"),
	(RateLimited, "/errors/rate-limited", 429, "Rate limited"),
	(Internal, "/errors/internal", 500, "Internal error"),
	(Upstream, "/errors/upstream", 502, "Upstream error"),
	(Busy, "/errors/busy", 503, "Busy"),
]

# R-AP21: the type, the status and the title of each kind.
expect types.map(|(k, _, _, _)| (Problem.type_uri(k), Problem.status(k), Problem.title(k))) == types.map(|(_, uri, st, title)| (uri, st, title))

Wire : { type : Str, title : Str, status : U16, detail : Str }

parse : Str -> Try(Wire, _)
parse = |text| Json.parse(text)

# R-AP21: the body has the 4 members, and `detail` stays the same text after JSON escaping (quote, backslash, newline, tab, a control character, non-ASCII text, empty text).
details : List(Str)
details = ["", "plain text", "a \"quoted\" word", "back\\slash", "two\nlines", "a\ttab", "control \u(1) char", "caf\u(e9) \u(20ac) \u(1f600)"]

expect types.map(|(k, uri, st, title)| details.map(|d| parse(Problem.to_json(Problem.new(k, d))) == Ok({ type: uri, title, status: st, detail: d }))).join().all(|ok| ok)

# R-AP21: the HTTP status of a problem is the status of its type.
expect types.map(|(k, _, _, _)| Problem.http_status(Problem.new(k, "any"))) == types.map(|(_, _, st, _)| st)
