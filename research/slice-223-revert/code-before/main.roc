app [main!] {
	bot: "lib/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst",
}

## The compat bot app (slice 223, Registry R-MX17): `main!` builds the real `Fx` and calls `BotFlow.run!`. Stub.
main! = |_args| crash "todo: slice 223"
