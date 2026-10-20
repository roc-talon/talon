app [main!] {
	pf: platform "https://github.com/acme/pfx/releases/download/0.1.1/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK.tar.zst",
	web: "https://github.com/acme/web/releases/download/1.0.0/8LoFFAesdE1jgr4tRFe77ihKB88VgTwyacjUvpMJm6S7.tar.zst",
	core: "https://github.com/acme/core/releases/download/1.1.0/GFxDoMVtm3uCVP4qTSN11k2YKtzwLWibi2UNecy1KX6a.tar.zst",
	mid: "https://github.com/acme/mid/releases/download/1.0.0/5oo1arXY7EXbrxT5DxfxyZ4WYxzoRmneT2gsChjwSgGi.tar.zst",
	util: "./util/main.roc",
	ext: "https://example.org/ext/pkg-latest.tar.zst",
	roc: "nightly-2026-10-14-38a3029",
}

main! = |_args| Ok({})
