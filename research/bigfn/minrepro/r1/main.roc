app [event!] {
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.7/H2XzG4R2kci1kL4iVzvjx4CF1ohs1XYv1CMHjZzJ5TTi.tar.zst",
}

import pf.Worker
import pf.Request
import pf.Response
import Problem

fetch! : Request => Try(Response, _)
fetch! = |req| match h0!(req) {
	Ok(res) => Ok(res)
	Err(Refuse(problem)) => Ok(problem_response(problem))
	Err(Fault(text)) => Err(Fault(text))
}

problem_response : Problem -> Response
problem_response = |problem| Response.from_bytes(problem.http_status(), "application/problem+json", problem.to_json().to_utf8())

kind_of : Str -> Problem.Kind
kind_of = |t| match t {
	"a" => BadRequest
	"b" => NotFound
	"c" => Unauthenticated
	"d" => RateLimited
	_ => Forbidden
}

h0! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h0! = |req| match req.header("x-0") {
	Ok(t) => if t == "f" Err(Fault("h0")) else Err(Refuse(Problem.new(kind_of(t), "handler 0 refused")))
	Err(_) => Ok(Response.from_text(200, "h0"))
}

worker = Worker.new({ fetch!: |_req| Ok(Response.from_text(500, "not used")) })

event! = |e| match e {
	Fetch(_) | Scheduled(_) | Queue(_) | Email(_) | Tail(_) | Other(_) => own!(e) #OR
	_ => worker.event!(e)
}

own! : Worker.Event => Worker.Outcome
own! = |e| match e {
	Fetch(req) => match fetch!(req) {
		Ok(res) => Respond(res)
		Err(x) => Failed(Str.inspect(x))
	}
	_ => Unhandled
}
