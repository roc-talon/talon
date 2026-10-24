app [main!] {
	pf: platform "https://github.com/acme/pfx/releases/download/0.1.0/EzqknpoPqsBuuzVvoGfbsVxNNPnRQAcoD6YA4hZdDEPn.tar.zst",
	json: "https://github.com/acme/json/releases/download/2.1.0/F816SmTdWDgJo2qBVGLZ7vj6Kvz5woHpovB99Jbw7fgt.tar.zst",
	parser: "https://github.com/acme/parser/releases/download/1.0.0/Bdq38a9Hys5HgjBDnFySDPcEN49bYeYXDHAaMbsMNr5t.tar.zst",
	lib: "https://github.com/acme/lib/releases/download/1.0.0/3Nj5wCJVRM6NNxtmpfBtTFvvFL21CW8iyiMqygRKga4h.tar.zst",
	util: "https://github.com/acme/util/releases/download/1.0.0/5QL3KuZ4wwgQeGjXb6Fj9mVrDdgx7LBPFWH8mrUGRvNe.tar.zst",
	ext: "https://example.org/ext/releases/download/1.0.0/Ftp3yEhxf3CqQHnMY5Yuvtf8aM7EQpNME389WjF21Sw6.tar.zst",
	loc: "./loc/main.roc",
	roc: "nightly-2026-10-09-9d9d9d9",
}

main! = |_args| Ok({})
