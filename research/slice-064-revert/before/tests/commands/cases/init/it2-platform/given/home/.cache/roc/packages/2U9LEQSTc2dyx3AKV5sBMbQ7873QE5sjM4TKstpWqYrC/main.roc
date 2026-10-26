platform "acme-mpf"
	requires {} { main! : () => {} }
	exposes [Std]
	packages {}
	provides [main_for_host!]
	targets: {
		inputs_dir: "targets/",
		wasm32: { inputs: ["host.o", app] },
		x64musl: { inputs: ["host.o", app] },
	}
