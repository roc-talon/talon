platform ""
	requires {
		## The entry point gets the arguments { and gives the result: a comment, with : and , in it
		main! : List([Utf8(Str), UnixBytes(List(U8))]) => Try({}, [Exit(I32), ..])
	}
	exposes [Std]
	packages {}
	provides [main_for_host!]
	targets: {
		inputs_dir: "targets/",
		wasm32: { inputs: ["host.o", app] },
	}
