app [event!] {
	base58: "https://github.com/Karakatiza666/roc-base58/releases/download/0.1.0/BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS.tar.zst",
	header: "https://github.com/Karakatiza666/roc-app-header/releases/download/0.1.0/HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU.tar.zst",
	lib: "lib/main.roc",
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.2/f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd.tar.zst",
	records: "../packages/records/main.roc",
	roc: "nightly-2026-10-31-f7bef6b",
	semver: "https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst",
	tar: "https://github.com/Karakatiza666/roc-tar/releases/download/0.0.1/FGAUE1Pds7Fvd48GkrAYd9rRUpztew8bgUZjUrKPGyo7.tar.zst",
}

## The registry Worker (Registry 4 to 8). Slice 101 is the skeleton: the entry, the router, the problem form.
## Slice 101: `fetch!` is the router. `scheduled!` and `queue!` are stubs until slices 118 to 120 (docs/slices/101-worker-skeleton.md section 3.3).
import pf.Worker
import pf.Request
import pf.Response
import pf.D1
import pf.Queue
import lib.Problem
import lib.Route
import Auth
import ReadRoutes
import ClosureRoute
import ShortRoutes
import ToolchainRoutes

db = D1.binding("DB")

fetch! : Request => Try(Response, _)
fetch! = |req| {
	input = {
		method: req.method().to_str(),
		segments: req.segments(),
		content_type: req.header("content-type"),
		has_body: body_present!(req),
	}
	match Route.decide(input) {
		Refuse(problem) => Ok(problem_response(problem))
		NotAllowed(problem, allow) => Ok(problem_response(problem).with_header("allow", Str.join_with(allow, ", ")))
		Handle(id) => handle!(id, req)
	}
}

## The most bytes that the Worker reads from a request body (R-AP46: 256 KB).
body_limit : U64
body_limit = 262144

## Is there a request body (R-AP23: a request with no body gets no media check)? The platform gives a body that is not `Empty` also for a request with
## no body, so the answer comes from the header `content-length` (0 is no body), and when the header is absent or not a number, from a read of
## at most `body_limit` bytes: 0 bytes is no body. A read that fails or is too large is a body (the route answers 413 or 400 later).
body_present! : Request => Bool
body_present! = |req| match req.header("content-length") {
	Ok(text) => match U64.from_str(text.trim()) {
		Ok(n) => n > 0
		Err(_) => read_present!(req)
	}
	Err(NotFound) => read_present!(req)
}

read_present! : Request => Bool
read_present! = |req| match req.body() {
	Empty => Bool.False
	_ => match req.bytes_with!({ max_bytes: body_limit }) {
		Ok(bytes) => !bytes.is_empty()
		Err(_) => Bool.True
	}
}

## The answer of a problem (R-AP21, R-AP23): the media type is exactly `application/problem+json`.
problem_response : Problem -> Response
problem_response = |problem| Response.from_bytes(problem.http_status(), "application/problem+json", problem.to_json().to_utf8())

## Run the handler of a route. Each `Err` of a handler is the problem `Internal` with a fixed `detail`: the answer shows no inner state (R-AP48).
handle! : Route.Id, Request => Try(Response, _)
handle! = |id, req| {
	match run!(id, req) {
		Ok(res) => Ok(res)
		Err(_) => Ok(problem_response(Problem.new(Internal, "the Worker failed to handle the request")))
	}
}

## Slice 110: the closure route. `ClosureRoute` gives `Refuse(problem)` for a 400 and `Fault` for a fault of the Worker, as `ReadRoutes`.
## Slice 108: the toolchain route does the bot check (R-TP7). A failed check is its own problem. Slice 109: `ToolchainRoutes` does the rest (`GET` and `PUT`).
## Slice 106: the three read routes. `ReadRoutes` gives `Refuse(problem)` for a 400 or a 404 and `Fault` for a fault of the Worker (500 `internal`).
run! : Route.Id, Request => Try(Response, [Fault(Str)])
run! = |id, req| match id {
	GetRepoReleases(owner, repo) => read_answer(ReadRoutes.repo_releases!(req, owner, repo))
	GetArtifact(hash) => read_answer(ReadRoutes.artifact!(req, hash))
	GetReleases => read_answer(ReadRoutes.releases!(req))
	GetPackages => read_answer(ShortRoutes.list!(req))
	PostClosure => read_answer(ClosureRoute.post!(req))
	GetToolchains => read_answer(ToolchainRoutes.list!(req))
	PutToolchain(tag) => match Auth.bot!(req) {
		Err(problem) => Ok(problem_response(problem))
		Ok(_) => read_answer(ToolchainRoutes.put!(req, tag))
	}
}

read_answer : Try(Response, ReadRoutes.Error) -> Try(Response, [Fault(Str)])
read_answer = |result| match result {
	Ok(res) => Ok(res)
	Err(Refuse(problem)) => Ok(problem_response(problem))
	Err(Fault(text)) => Err(Fault(text))
}

scheduled! : Worker.Scheduled => Try({}, _)
scheduled! = |_s| crash "todo"

queue! : Queue.Batch => Try({}, _)
queue! = |_b| crash "todo"

worker = Worker.new({ fetch!: fetch!, scheduled!: scheduled!, queue!: queue!, bindings: [db.declare()] })

event! = |e| worker.event!(e)
