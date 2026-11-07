app [event!] {
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.7/H2XzG4R2kci1kL4iVzvjx4CF1ohs1XYv1CMHjZzJ5TTi.tar.zst",
	roc: "nightly-2026-10-31-f7bef6b",
}

## Smallest copy of the fetch path of worker/main.roc: Route.decide and the problem answer, no route handler.
import pf.Worker
import pf.Request
import pf.Response
import Problem
import Route

fetch! : Request => Try(Response, _)
fetch! = |req| {
	input = { method: req.method().to_str(), segments: req.segments(), content_type: req.header("content-type"), has_body: Bool.False }
	match Route.decide(input) {
		Refuse(problem) => Ok(problem_response(problem))
		NotAllowed(problem, allow) => Ok(problem_response(problem).with_header("allow", Str.join_with(allow, ", ")))
		Handle(_) => Ok(Response.from_text(200, "ok"))
	}
}

problem_response : Problem -> Response
problem_response = |problem| Response.from_bytes(problem.http_status(), "application/problem+json", problem.to_json().to_utf8())

worker = Worker.new({ fetch!: fetch! })

event! = |e| worker.event!(e)
