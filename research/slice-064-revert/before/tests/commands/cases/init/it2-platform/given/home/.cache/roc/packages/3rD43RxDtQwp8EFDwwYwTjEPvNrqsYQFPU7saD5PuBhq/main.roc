platform "acme-mov"
	requires {
		[Model : model] for program : {
			init! : () => model,
			update! : model, Str => model,
		}
	}
	exposes [Std]
	packages {}
	provides [main_for_host!]
	targets: {
		inputs_dir: "targets/",
		x64musl: { inputs: ["host.o", app] },
	}
