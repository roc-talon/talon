platform "acme-cnst"
	requires {} { main! : { go! : () => {}, port : U16 } }
	exposes [Std]
	packages {}
	provides [main_for_host!]
