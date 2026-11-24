platform ""
	requires {
		main! : List(Str) => Try({}, [Exit(I32), ..])
	}
	exposes []
	packages {}
	provides { "roc_main": main_for_host! }
	targets: {
		x64mac: { inputs: ["libhost.a", app] },
		arm64mac: { inputs: ["libhost.a", app] },
		x64musl: { inputs: ["libhost.a", app] },
		arm64musl: { inputs: ["libhost.a", app] },
	}
