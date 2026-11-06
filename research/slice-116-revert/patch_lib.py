# Applies the reference to a copy of worker/ (reference only): lib/main.roc exposes Nullable; main.roc gets the client check and the binding RL_HINTS (slice 116b).
import sys
w = sys.argv[1]
p = w + '/lib/main.roc'
s = open(p).read()
if 'Nullable' not in s:
    s = s.replace('Hints,', 'Hints, Nullable,', 1)
open(p, 'w').write(s)
p = w + '/main.roc'
s = open(p).read()
s = s.replace('import pf.Queue\n', 'import pf.Queue\nimport pf.Env\nimport lib.Client\nimport HintRoutes\n', 1)
s = s.replace('fetch! : Request => Try(Response, _)\nfetch! = |req| {\n', '''fetch! : Request => Try(Response, _)
fetch! = |req| {
	probe = Route.decide({ method: req.method().to_str(), segments: req.segments(), content_type: Err(NotFound), has_body: Bool.False })
	refusal = match probe {
		Handle(id) => {
			min = Env.var!("MIN_TLN") ?? ""
			min_write = Env.var!("MIN_TLN_WRITE") ?? ""
			Client.check({ user_agent: req.header("user-agent"), write: Client.is_write(id), min, min_write })
		}
		_ => Ok({})
	}
	match refusal {
		Err(r) => Ok(Response.from_bytes(400, "application/problem+json", Client.refusal_json(r).to_utf8()))
		Ok({}) => fetch_routed!(req)
	}
}

fetch_routed! : Request => Try(Response, _)
fetch_routed! = |req| {
''', 1)
s = s.replace('bindings: [db.declare()]', 'bindings: [db.declare(), HintRoutes.limiter.declare()]', 1)
open(p, 'w').write(s)
