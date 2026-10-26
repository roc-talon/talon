platform "acme-web"
	requires {
		[Context : context] for program : {
			init! : () => Try(context, Str),
			respond! : Request, context => Try(Response, Str),
			shutdown! : context => {},
		}
	}
	exposes [Std]
	packages {}
	provides [main_for_host!]
