platform "acme"
	requires {} { main! : () => {} }
	exposes [Std]
	packages {}
	provides [main_for_host!]
	targets: {
		inputs_dir: "targets/",
		x64musl: { inputs: ["host.o", app] },
	}
