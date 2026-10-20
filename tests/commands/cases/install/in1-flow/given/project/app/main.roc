app [main!] {
	pf: platform "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst",   # keep
	json: "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst",
	local: "../lib/main.roc",
	inner: "./inner/main.roc",
	roc: "nightly-2026-10-14-38a3029",
}

main! = |_args| Ok({})
