platform "acme-pf"
	requires {} { main! : () => {} }
	exposes [Std]
	packages {}
	provides [main_for_host!]
