app [event!] {
	base58: "https://github.com/Karakatiza666/roc-base58/releases/download/0.1.0/BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS.tar.zst",
	header: "https://github.com/Karakatiza666/roc-app-header/releases/download/0.1.0/HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU.tar.zst",
	lib: "lib/main.roc",
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.10/Dfyn36P4a9t8519ZVXDkHrmvXA9cbzrjkN4YHJuVfkGd.tar.zst",
	records: "../packages/records/main.roc",
	roc: "nightly-2026-11-06-34f137a",
	semver: "https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst",
	tar: "https://github.com/Karakatiza666/roc-tar/releases/download/0.0.2/ynGk61syE32Lobjgwd3ZNRURf78xPGxr8Nzi1bSuhUr.tar.zst",
}

## The W2 test app of slice 111 (a test fixture: the code agent does not change it, TW18). It is never deployed: `main.roc` is the Worker.
## It is in `worker/` so that it imports the module `Archive.roc` of the Worker as it is. `scripts/test.sh w2` builds it to `archive-test.wasm`,
## and `worker/tests/run.mjs` runs it for a case with the file `app` (text `archive`).
##
## `GET /archive?url=<asset URL>`: `Archive.read!(url, ArchiveRead.url_hash(url))`.
## | Result | Answer |
## | --- | --- |
## | `Ok(row)` | 200, `application/json`, `Artifact.encode(row)` (R-AP49) |
## | `Refused(refusal)` | The problem of `ArchiveRead.problem(refusal)` |
## | `Upstream(err)` | The problem of `ArchiveRead.upstream_problem(err)` |
## | `Fault(_)`, a URL with no hash | 500 `internal` |
import pf.Worker
import pf.Request
import pf.Response
import lib.ArchiveRead
import lib.Problem
import records.Artifact
import Archive

fetch! : Request => Try(Response, _)
fetch! = |req| match (req.method(), req.segments()) {
	(GET, ["archive"]) => {
		url = req.query("url") ?? ""
		result = match ArchiveRead.url_hash(url) {
			Ok(hash) => Archive.read!(url, hash)
			Err(NoHash) => Err(Fault("the URL has no hash"))
		}
		Ok(answer(result))
	}

	_ => Ok(problem_response(Problem.new(NotFound, "no route")))
}

answer : Try(Artifact.Row, Archive.Error) -> Response
answer = |result| match result {
	Ok(row) => Response.from_bytes(200, "application/json", Artifact.encode(row).to_utf8())
	Err(Refused(refusal)) => problem_response(ArchiveRead.problem(refusal))
	Err(Upstream(err)) => problem_response(ArchiveRead.upstream_problem(err))
	Err(Fault(text)) => problem_response(Problem.new(Internal, text))
}

problem_response : Problem -> Response
problem_response = |problem| Response.from_bytes(problem.http_status(), "application/problem+json", problem.to_json().to_utf8())

worker = Worker.new({ fetch!: fetch! })

event! = |e| worker.event!(e)
