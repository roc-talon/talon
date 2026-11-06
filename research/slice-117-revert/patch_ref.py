# Applies the routes of the reference to a copy of worker/ (reference only): Route.decide gets the 4 lines, Client.is_write the 3 write routes.
import sys
w = sys.argv[1]
p = w + '/lib/Route.roc'
s = open(p).read()
s = s.replace('''			_ => Refuse(Problem.new(NotFound, "no route for ${input.method} ${path}"))
		}
	}
''', '''			["v1", "tokens"] => decide_tokens(input, path)
			["v1", "contributors", "me"] => decide_me(input, path)
			_ => Refuse(Problem.new(NotFound, "no route for ${input.method} ${path}"))
		}
	}

	decide_tokens : Route.Input, Str -> Route.Decision
	decide_tokens = |input, path| match input.method {
		"POST" => decide_post(input, path, PostTokens)
		"DELETE" => Handle(DeleteTokens)
		_ => NotAllowed(Problem.new(MethodNotAllowed, "${input.method} is not allowed on ${path}"), ["DELETE", "POST"])
	}

	decide_me : Route.Input, Str -> Route.Decision
	decide_me = |input, path| match input.method {
		"GET" => Handle(GetMe)
		"DELETE" => Handle(DeleteMe)
		_ => NotAllowed(Problem.new(MethodNotAllowed, "${input.method} is not allowed on ${path}"), ["DELETE", "GET"])
	}
''', 1)
open(p, 'w').write(s)
p = w + '/lib/Client.roc'
s = open(p).read()
s = s.replace('PostCompat | PostRelease | PutToolchain(_) => Bool.True', 'PostCompat | PostRelease | PutToolchain(_) | PostTokens | DeleteTokens | DeleteMe => Bool.True', 1)
open(p, 'w').write(s)
