import Problem

Request : Str
Response : { status : U16, ctype : Str, body : List(U8) }
Event : [Fetch(Request), Scheduled(Str), Queue(Str), Email(Str), Tail(Str), Other(Str), Rpc(Str), Manifest]
Outcome : [Respond(Response), Failed(Str), Unhandled, Reply(Str)]

from_text : U16, Str -> Response
from_text = |status, text| { status, ctype: "text/plain", body: text.to_utf8() }

header! : Request, Str => Try(Str, [NotFound])
header! = |req, name| {
	echo!("header ${name}")
	if req.starts_with(name) Ok(req.drop_prefix(name)) else Err(NotFound)
}

fetch! : Request => Try(Response, _)
fetch! = |req| handle!(id_of(req), req)

Id : [I0, I1]

id_of : Str -> Id
id_of = |t| match t {
	"m0" => I0
	_ => I1
}

problem_response : Problem -> Response
problem_response = |problem| { status: problem.http_status(), ctype: "application/problem+json", body: problem.to_json().to_utf8() }

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
h0! = |req| match header!(req, "x-0") {
	Ok(t) => if t == "f" Err(Fault("h0")) else Err(Refuse(Problem.new(kind_of(t), "handler 0 refused")))
	Err(_) => Ok(from_text(200, "h0"))
}

h3! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
h3! = |req| match header!(req, "x-3") {
	Ok(t) => if t == "f" Err(Fault("h3")) else Err(Refuse(Problem.new(kind_of(t), "handler 3 refused")))
	Err(_) => Ok(from_text(200, "h3"))
}

other! : Event => Outcome
other! = |e| match e {
	Rpc(s) => Reply(s)
	_ => Unhandled
}

event! : Event => Outcome
event! = |e| match e {
	Fetch(_) | Scheduled(_) | Queue(_) | Email(_) | Tail(_) | Other(_) => own!(e) #OR
	_ => other!(e)
}

own! : Event => Outcome
own! = |e| match e {
	Fetch(req) => match fetch!(req) {
		Ok(res) => Respond(res)
		Err(x) => Failed(Str.inspect(x))
	}
	_ => Unhandled
}

event_of : Str -> Event
event_of = |t| match t {
	"f" => Fetch(t)
	"s" => Scheduled(t)
	"q" => Queue(t)
	"e" => Email(t)
	"t" => Tail(t)
	"o" => Other(t)
	"r" => Rpc(t)
	_ => Manifest
}

main! = |args| {
	t = args.first() ?? "f"
	echo!(Str.inspect(event!(event_of(t.to_str()))))
	Ok({})
}
