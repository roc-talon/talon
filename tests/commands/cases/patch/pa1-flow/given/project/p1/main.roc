app [main!] {
	pf: platform "https://github.com/acme/pf/releases/download/0.1.0/3nqZet4D6XXs8rmYGGBYJTHAiXPqhEBh6HYtHz6pggi3.tar.zst",
	json: "https://github.com/acme/json/releases/download/2.1.0/3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm.tar.zst",
	util: "../ut/main.roc",
	src: "https://example.org/archive/main.tar.gz",
	roc: "nightly-2026-10-14-38a3029",
}

main! = |_args| Ok({})
