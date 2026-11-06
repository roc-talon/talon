app [event!] {
	lib: "lib/main.roc",
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.2/f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd.tar.zst",
	roc: "nightly-2026-10-31-f7bef6b",
}

import pf.Worker
import pf.Request
import pf.Response
import pf.D1
import pf.Queue
import lib.Problem
import lib.Route

db = D1.binding("DB")

problem_response : Problem -> Response
problem_response = |p| Response.from_bytes(p.http_status(), "application/problem+json", p.to_json().to_utf8())

closure! : Request => Try(Response, [NotBuilt])
closure! = |_req| Err(NotBuilt)

fetch! : Request => Try(Response, _)
fetch! = |req| {
	has_body = match req.body() {
		Empty => Bool.False
		_ => Bool.True
	}
	input = { method: req.method().to_str(), segments: req.segments(), content_type: req.header("content-type"), has_body }
	match Route.decide(input) {
		Refuse(p) => Ok(problem_response(p))
		NotAllowed(p, allow) => Ok(problem_response(p).with_header("allow", Str.join_with(allow, ", ")))
		Handle(PostClosure) => match closure!(req) {
			Ok(r) => Ok(r)
			Err(_) => Ok(problem_response(Problem.new(Internal, "the Worker failed to handle the request")))
		}
	}
}

scheduled! : Worker.Scheduled => Try({}, _)
scheduled! = |_s| crash "todo"

queue! : Queue.Batch => Try({}, _)
queue! = |_b| crash "todo"

worker = Worker.new({ fetch!: fetch!, scheduled!: scheduled!, queue!: queue!, bindings: [db.declare()] })

event! = |e| worker.event!(e)
