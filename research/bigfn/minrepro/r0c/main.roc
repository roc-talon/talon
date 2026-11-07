app [event!] {
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.7/H2XzG4R2kci1kL4iVzvjx4CF1ohs1XYv1CMHjZzJ5TTi.tar.zst",
	roc: "nightly-2026-10-31-f7bef6b",
}

## The shape of worker/main.roc (fetch!, run!, read_answer, handle!) with 17 stub handlers. Each stub refuses with a problem whose kind is known only at run time.
import pf.Worker
import pf.Request
import pf.Response
import Problem

fetch! : Request => Try(Response, _)
fetch! = |req| handle!(id_of(req.method().to_str()), req)

Id : [I0, I1]

id_of : Str -> Id
id_of = |t| match t {
	"m0" => I0
	_ => I1
}

problem_response : Problem -> Response
problem_response = |problem| Response.from_bytes(problem.http_status(), "application/problem+json", problem.to_json().to_utf8())

handle! : Id, Request => Try(Response, _)
handle! = |id, req| match run!(id, req) {
	Ok(res) => Ok(res)
	Err(_) => Ok(problem_response(Problem.new(Internal, "the Worker failed to handle the request")))
}

run! : Id, Request => Try(Response, [Fault(Str)])
run! = |id, req| match id {
	I0 => read_answer(h0!(req))
	I1 => read_answer(h3!(req))
}

read_answer : Try(Response, [Refuse(Problem), Fault(Str)]) -> Try(Response, [Fault(Str)])
read_answer = |result| match result {
	Ok(res) => Ok(res)
	Err(Refuse(problem)) => Ok(problem_response(problem))
	Err(Fault(text)) => Err(Fault(text))
}

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



h3! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h3! = |req| match req.header("x-3") {
	Ok(t) => if t == "f" Err(Fault("h3")) else Err(Refuse(Problem.new(kind_of(t), "handler 3 refused")))
	Err(_) => Ok(Response.from_text(200, "h3"))
}














## As mini2bp, but the fetch path is reached through a 6-alternative or-pattern, as in Worker.event! of the platform.
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
