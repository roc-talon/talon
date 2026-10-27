app [main!] {
	# the platform
	pf: platform "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst",   # keep this comment
	json:    "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst",
	local: "../lib/main.roc",
	other: "https://example.com/other/1.0.0/FciD4i2WPEYinnKaCzFZAPTUsRxTCpJM6FyQmezmkkoj.tar.br",
	parser: "https://github.com/acme/parser/releases/download/1.2.0/EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt.tar.zst",
	roc: "nightly-2026-10-14-38a3029",
}

main! = |_args| Ok({})
