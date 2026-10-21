app [main!] {
	pf: platform "https://github.com/acme/pfx/releases/download/0.1.1/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK.tar.zst",
	core: "https://github.com/acme/core/releases/download/1.0.0/8bp2yxDtY2ayou722hzyv51Ts1yBaFshmVGtLXpkDy8r.tar.zst",
	util: "./util/main.roc",
	roc: "nightly-2026-10-14-38a3029",
}

main! = |_args| Ok({})
