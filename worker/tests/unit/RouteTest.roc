import lib.Problem
import lib.Route

RouteTest :: [].{}

# W0 tests of worker/lib/Route.roc (slice 101). The order of the checks is R-AP48.

input = |method, segments, content_type, has_body| { method, segments, content_type, has_body }

closure = ["v1", "closure"]

json = Ok("application/json")

# R-AP48 row 1, R-AP21: a path that is no route gives the problem `not-found`, with a detail that names the method and the path. The method text does not matter.
expect Route.decide(input("GET", [], Err(NotFound), Bool.False)) == Refuse(Problem.new(NotFound, "no route for GET /"))
expect Route.decide(input("GET", ["v1", "nothing"], Err(NotFound), Bool.False)) == Refuse(Problem.new(NotFound, "no route for GET /v1/nothing"))
expect Route.decide(input("BREW", ["v1", "nothing"], Err(NotFound), Bool.False)) == Refuse(Problem.new(NotFound, "no route for BREW /v1/nothing"))
expect Route.decide(input("POST", ["v1", "closure", "extra"], json, Bool.True)) == Refuse(Problem.new(NotFound, "no route for POST /v1/closure/extra"))
expect Route.decide(input("POST", ["V1", "closure"], json, Bool.True)) == Refuse(Problem.new(NotFound, "no route for POST /V1/closure"))

# R-AP48 row 1 before row 5 (Q101-2): a body with a media type that is not JSON, on a path that is no route, gives 404, not 415.
expect Route.decide(input("POST", ["v1", "nothing"], Ok("text/plain"), Bool.True)) == Refuse(Problem.new(NotFound, "no route for POST /v1/nothing"))
expect Route.decide(input("POST", ["v1", "nothing"], Err(NotFound), Bool.True)) == Refuse(Problem.new(NotFound, "no route for POST /v1/nothing"))

# R-AP48 row 2, R-AP21 (Q101-1): the path is a route and the method is not served on it: 405 with the methods of the path.
# Row 2 comes before row 5: a body with a media type that is not JSON still gives 405.
not_allowed = |method| NotAllowed(Problem.new(MethodNotAllowed, "${method} is not allowed on /v1/closure"), ["POST"])
expect Route.decide(input("GET", closure, Err(NotFound), Bool.False)) == not_allowed("GET")
expect Route.decide(input("DELETE", closure, Err(NotFound), Bool.False)) == not_allowed("DELETE")
expect Route.decide(input("PUT", closure, Ok("text/plain"), Bool.True)) == not_allowed("PUT")
expect Route.decide(input("BREW", closure, Err(NotFound), Bool.False)) == not_allowed("BREW")

# R-AP48 row 5, R-AP21, R-AP23: a body that is not `application/json` gives `unsupported-media-type`. The media type has no case.
# A request without a body is not checked (Q101-4).
bad_media = |ct| Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, got ${ct}"))
expect Route.decide(input("POST", closure, Ok("text/plain"), Bool.True)) == bad_media("text/plain")
expect Route.decide(input("POST", closure, Ok("application/jsonx"), Bool.True)) == bad_media("application/jsonx")
expect Route.decide(input("POST", closure, Ok("application/problem+json"), Bool.True)) == bad_media("application/problem+json")
expect Route.decide(input("POST", closure, Err(NotFound), Bool.True)) == Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, but the request has no Content-Type"))
expect Route.decide(input("POST", closure, json, Bool.False)) == Handle(PostClosure)
expect Route.decide(input("POST", closure, Err(NotFound), Bool.False)) == Handle(PostClosure)
expect Route.decide(input("POST", closure, Ok("text/plain"), Bool.False)) == Handle(PostClosure)

# R-AP23 (Q101-3): accepted: `application/json` with no parameter, or with `charset=utf-8` as a token or a quoted string (RFC 9110 8.3.1), with no case in the type,
# the parameter name and the value, and spaces around `;`. Other parameters are ignored (R-AP44). Any other charset gives 415.
ok_media = [
	"application/json",
	"application/json; charset=utf-8",
	"application/json;charset=utf-8",
	"application/json; charset=UTF-8",
	"application/json; Charset=Utf-8",
	"Application/JSON",
	"APPLICATION/JSON; CHARSET=UTF-8",
	"application/json ; charset=utf-8",
	"application/json; charset=\"utf-8\"",
	"application/json; charset=\"UTF-8\"",
	"application/json; foo=bar",
	"application/json; charset=utf-8; foo=bar",
	"application/json; foo=bar; charset=utf-8",
	"application/json; charset=\"utf-8\"; foo=\"b;ar\"",
]
expect ok_media.map(|ct| Route.decide(input("POST", closure, Ok(ct), Bool.True))) == ok_media.map(|_| Handle(PostClosure))
bad_charset = [
	"application/json; charset=latin-1",
	"application/json; charset=utf-16",
	"application/json; charset=ISO-8859-1",
	"application/json; charset=",
	"application/json; charset=\"latin-1\"",
	"application/json; foo=bar; charset=latin-1",
	"application/json; charset=utf-8x",
]
expect bad_charset.map(|ct| Route.decide(input("POST", closure, Ok(ct), Bool.True))) == bad_charset.map(|ct| bad_media(ct))
