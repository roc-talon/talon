app [event!] {
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.7/H2XzG4R2kci1kL4iVzvjx4CF1ohs1XYv1CMHjZzJ5TTi.tar.zst",
	roc: "nightly-2026-10-31-f7bef6b",
}

## The shape of worker/main.roc (fetch!, run!, read_answer, handle!) with 17 stub handlers. Each stub refuses with a problem whose kind is known only at run time.
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
		Handle(id) => handle!(id, req)
	}
}

problem_response : Problem -> Response
problem_response = |problem| Response.from_bytes(problem.http_status(), "application/problem+json", problem.to_json().to_utf8())

handle! : Route.Id, Request => Try(Response, _)
handle! = |id, req| match run!(id, req) {
	Ok(res) => Ok(res)
	Err(_) => Ok(problem_response(Problem.new(Internal, "the Worker failed to handle the request")))
}

run! : Route.Id, Request => Try(Response, [Fault(Str)])
run! = |id, req| match id {
	PostClosure => read_answer(h0!(req))
	PutToolchain(_t) => read_answer(h1!(req))
	GetToolchains => read_answer(h2!(req))
	GetRepoReleases(_o, _r) => read_answer(h3!(req))
	GetArtifact(_h) => read_answer(h4!(req))
	GetReleases => read_answer(h5!(req))
	GetPackages => read_answer(h6!(req))
	PostCompat => read_answer(h7!(req))
	GetSweep(_t) => read_answer(h8!(req))
	GetCompatHints => read_answer(h9!(req))
	GetArtifactCompat(_h) => read_answer(h10!(req))
	PostRelease => read_answer(h11!(req))
	PostTokens => read_answer(h12!(req))
	DeleteTokens => read_answer(h13!(req))
	GetMe => read_answer(h14!(req))
	DeleteMe => read_answer(h15!(req))
	PostWebhook => read_answer(h16!(req))
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
	_ => NotFound
}

h0! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h0! = |req| match req.header("x-0") {
	Ok(t) => if t == "f" Err(Fault("h0")) else Err(Refuse(Problem.new(kind_of(t), "handler 0 refused")))
	Err(_) => Ok(Response.from_text(200, "h0"))
}

h1! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h1! = |req| match req.header("x-1") {
	Ok(t) => if t == "f" Err(Fault("h1")) else Err(Refuse(Problem.new(kind_of(t), "handler 1 refused")))
	Err(_) => Ok(Response.from_text(200, "h1"))
}

h2! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h2! = |req| match req.header("x-2") {
	Ok(t) => if t == "f" Err(Fault("h2")) else Err(Refuse(Problem.new(kind_of(t), "handler 2 refused")))
	Err(_) => Ok(Response.from_text(200, "h2"))
}

h3! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h3! = |req| match req.header("x-3") {
	Ok(t) => if t == "f" Err(Fault("h3")) else Err(Refuse(Problem.new(kind_of(t), "handler 3 refused")))
	Err(_) => Ok(Response.from_text(200, "h3"))
}

h4! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h4! = |req| match req.header("x-4") {
	Ok(t) => if t == "f" Err(Fault("h4")) else Err(Refuse(Problem.new(kind_of(t), "handler 4 refused")))
	Err(_) => Ok(Response.from_text(200, "h4"))
}

h5! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h5! = |req| match req.header("x-5") {
	Ok(t) => if t == "f" Err(Fault("h5")) else Err(Refuse(Problem.new(kind_of(t), "handler 5 refused")))
	Err(_) => Ok(Response.from_text(200, "h5"))
}

h6! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h6! = |req| match req.header("x-6") {
	Ok(t) => if t == "f" Err(Fault("h6")) else Err(Refuse(Problem.new(kind_of(t), "handler 6 refused")))
	Err(_) => Ok(Response.from_text(200, "h6"))
}

h7! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h7! = |req| match req.header("x-7") {
	Ok(t) => if t == "f" Err(Fault("h7")) else Err(Refuse(Problem.new(kind_of(t), "handler 7 refused")))
	Err(_) => Ok(Response.from_text(200, "h7"))
}

h8! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h8! = |req| match req.header("x-8") {
	Ok(t) => if t == "f" Err(Fault("h8")) else Err(Refuse(Problem.new(kind_of(t), "handler 8 refused")))
	Err(_) => Ok(Response.from_text(200, "h8"))
}

h9! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h9! = |req| match req.header("x-9") {
	Ok(t) => if t == "f" Err(Fault("h9")) else Err(Refuse(Problem.new(kind_of(t), "handler 9 refused")))
	Err(_) => Ok(Response.from_text(200, "h9"))
}

h10! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h10! = |req| match req.header("x-10") {
	Ok(t) => if t == "f" Err(Fault("h10")) else Err(Refuse(Problem.new(kind_of(t), "handler 10 refused")))
	Err(_) => Ok(Response.from_text(200, "h10"))
}

h11! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h11! = |req| match req.header("x-11") {
	Ok(t) => if t == "f" Err(Fault("h11")) else Err(Refuse(Problem.new(kind_of(t), "handler 11 refused")))
	Err(_) => Ok(Response.from_text(200, "h11"))
}

h12! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h12! = |req| match req.header("x-12") {
	Ok(t) => if t == "f" Err(Fault("h12")) else Err(Refuse(Problem.new(kind_of(t), "handler 12 refused")))
	Err(_) => Ok(Response.from_text(200, "h12"))
}

h13! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h13! = |req| match req.header("x-13") {
	Ok(t) => if t == "f" Err(Fault("h13")) else Err(Refuse(Problem.new(kind_of(t), "handler 13 refused")))
	Err(_) => Ok(Response.from_text(200, "h13"))
}

h14! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h14! = |req| match req.header("x-14") {
	Ok(t) => if t == "f" Err(Fault("h14")) else Err(Refuse(Problem.new(kind_of(t), "handler 14 refused")))
	Err(_) => Ok(Response.from_text(200, "h14"))
}

h15! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h15! = |req| match req.header("x-15") {
	Ok(t) => if t == "f" Err(Fault("h15")) else Err(Refuse(Problem.new(kind_of(t), "handler 15 refused")))
	Err(_) => Ok(Response.from_text(200, "h15"))
}

h16! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h16! = |req| match req.header("x-16") {
	Ok(t) => if t == "f" Err(Fault("h16")) else Err(Refuse(Problem.new(kind_of(t), "handler 16 refused")))
	Err(_) => Ok(Response.from_text(200, "h16"))
}

worker = Worker.new({ fetch!: fetch! })

event! = |e| worker.event!(e)
