platform "acme"
	requires {} { main! : () => {} }
	exposes [Std]
	packages {}
	provides [main_for_host!]
	targets: {
		inputs_dir: "targets/",
		wasm32: { inputs: ["host.o", app] },
	}
