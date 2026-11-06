## A stand-in for packages/records: the RFC 9457 error form (R-AP21).
Problem :: { type : Str, title : Str, status : U16, detail : Str }.{
	new : Str, Str, U16, Str -> Problem
	new = |type, title, status, detail| { type, title, status, detail }

	to_json : Problem -> Str
	to_json = |p| "{\"type\":\"${p.type}\",\"title\":\"${p.title}\",\"status\":${p.status.to_str()},\"detail\":\"${p.detail}\"}"

	status : Problem -> U16
	status = |p| p.status
}

expect Problem.new("/errors/not-found", "Not found", 404, "x").status() == 404
