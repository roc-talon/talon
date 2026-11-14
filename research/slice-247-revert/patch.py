# Private reference of slice 247 (test agent): the changes of the shared files that the stubs leave to the code agent. Usage: patch.py <worker dir of the copy>
import sys, re
d = sys.argv[1]
def sub(path, old, new, count=1):
    s = open(f'{d}/{path}').read()
    assert old in s, f'{path}: anchor not found: {old[:60]}'
    s = s.replace(old, new, count)
    open(f'{d}/{path}', 'w').write(s)
# Route.decide: the line and decide_successor
sub('lib/Route.roc', '\t\t\t["v1", "packages"] => decide_get(input, path, GetPackages)\n', '\t\t\t["v1", "packages"] => decide_get(input, path, GetPackages)\n\t\t\t["v1", "packages", owner, repo, "successor"] => decide_successor(input, path, owner, repo)\n')
sub('lib/Route.roc', '\t## `PUT /v1/toolchains/{tag}`: the method only.', '''	decide_successor : Route.Input, Str, Str, Str -> Route.Decision
	decide_successor = |input, path, owner, repo| match input.method {
		"PUT" => if !input.has_body {
			Handle(PutSuccessor(owner, repo))
		} else {
			match input.content_type {
				Err(NotFound) => Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, but the request has no Content-Type"))
				Ok(ct) => if (is_json_media(ct)) Handle(PutSuccessor(owner, repo)) else Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, got ${ct}"))
			}
		}
		"DELETE" => Handle(DeleteSuccessor(owner, repo))
		_ => NotAllowed(Problem.new(MethodNotAllowed, "${input.method} is not allowed on ${path}"), ["DELETE", "PUT"])
	}

	## `PUT /v1/toolchains/{tag}`: the method only.''')
sub('lib/Client.roc', 'PostCompat | PostRelease | PutToolchain(_) | PostTokens | DeleteTokens | DeleteMe => Bool.True', 'PostCompat | PostRelease | PutToolchain(_) | PostTokens | DeleteTokens | DeleteMe | PutSuccessor(_, _) | DeleteSuccessor(_, _) => Bool.True')
# Auth.move!
s = open(f'{d}/Auth.roc').read()
s = s.replace('import lib.Oidc\n', 'import lib.Move\nimport lib.Oidc\n', 1)
a = s.index('\tmove! : Request')
s = s[:a] + '''\tmove! : Request => Try([Operator, Token(Oidc.Claims)], Problem)
	move! = |req| {
		token = match Oidc.bearer(req.header("authorization")) {
			Token(text) => text
			NoToken => return Err(Oidc.missing_token)
			Refuse(problem) => return Err(problem)
		}
		is_operator = match Env.secret!("OPERATOR_KEY") {
			Ok(key) if !key.reveal().is_empty() => WebCrypto.timing_safe_equal!(key.reveal().to_utf8(), token.to_utf8())
			_ => Bool.False
		}
		if is_operator {
			Ok(Operator)
		} else {
			claims = verify!(token)?
			Move.check_token(claims)?
			Ok(Token(claims))
		}
	}
}
'''
open(f'{d}/Auth.roc', 'w').write(s)
