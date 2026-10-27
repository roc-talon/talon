import lib.Uses

UsesTest :: [].{}

pkgs = "/h/.cache/roc/packages"

# A release URL of the fixture host. The hash is letters and digits only.
hash_of = |repo, ver| "${repo}x${ver.replace_each(".", "x")}"

u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${hash_of(repo, ver)}.tar.zst"

pf = hash_of("pf", "0.1.0")

json = hash_of("json", "2.1.0")

parser = hash_of("parser", "1.0.0")

util = hash_of("util", "1.0.0")

link = |from, alias, to| { from, alias, to }

# R-UM1 R-LD7 (slice 031): the entries of the headers, as the alias that each header gives to a package. A link from the project header is from the app. A link from the header of a release is from that package. A link to a path file or
# to a foreign URL has no hash and is left out. A link from a path file is left out too (its files count as app files).
expect {
	walked = {
		rows: [],
		links: [
			link(Err(Header), "pf", u("pf", "0.1.0")),
			link(Err(Header), "json", u("json", "2.1.0")),
			link(Err(Header), "parser", u("parser", "1.0.0")),
			link(Err(Header), "lib", "/p/lib/main.roc"),
			link(Err(Header), "ext", "https://example.org/x.tar.zst"),
			link(Ok(u("json", "2.1.0")), "util", u("util", "1.0.0")),
			link(Ok(u("parser", "1.0.0")), "j", u("json", "2.1.0")),
			link(Ok("/p/lib/main.roc"), "util2", u("util", "1.0.0")),
			link(Ok(u("json", "2.1.0")), "ext2", "https://example.org/y.tar.zst"),
		],
	}
	want = [
		{ from: App, alias: "pf", hash: pf },
		{ from: App, alias: "json", hash: json },
		{ from: App, alias: "parser", hash: parser },
		{ from: Package(json), alias: "util", hash: util },
		{ from: Package(parser), alias: "j", hash: json },
	]
	got = Uses.edges(walked)
	dbg got
	got == want and Uses.edges({ rows: [], links: [] }) == []
}

edges = [
	{ from: App, alias: "pf", hash: pf },
	{ from: App, alias: "json", hash: json },
	{ from: App, alias: "parser", hash: parser },
	{ from: Package(json), alias: "util", hash: util },
	{ from: Package(parser), alias: "j", hash: json },
]

main_text = "app [main!] { pf: platform \"https://example.com/pf.tar.zst\", json: \"https://example.com/json.tar.zst\" }\n\nimport pf.Stdout\nimport json.Json\nimport json.Json.ParseErr as PE\nimport ext.Foo\nimport Helpers\nimport \"data.json\" as data : Str\n# import json.Commented\n\nmain! = |_| Ok({})\n"

# R-UM1 R-LD7 (slice 031): the scan of the used modules, level by level. The first level is the app file. The alias of `import json.Json` is read in the header of the file's owner. A module that an alias names is used and is the next file
# (owner: that package). A local import of a package file is used and next, with the same owner. A local import of an app file is next only. A file import, a comment, and an alias with no entry (`ext`, or `util` in the app header) give nothing.
# `used` has no repeat and keeps the order of the first use. `next` has no repeat, is in the order of the first import, and has no file that was read (`seen`: a cycle ends).
expect {
	level = |sources, seen| Uses.level({ project_dir: "/p/app", pkgs, edges, sources, seen })
	first = level([{ owner: App, path: "/p/app/main.roc", text: main_text }], ["/p/app/main.roc"])
	first_want = {
		used: [{ hash: pf, path: "Stdout.roc" }, { hash: json, path: "Json.roc" }],
		next: [{ owner: Package(pf), path: "${pkgs}/${pf}/Stdout.roc" }, { owner: Package(json), path: "${pkgs}/${json}/Json.roc" }, { owner: App, path: "/p/app/Helpers.roc" }],
	}
	read_one = [
		{ owner: Package(json), path: "${pkgs}/${json}/Json.roc", text: "import Wire\nimport util.Strs\nimport ./Internal/Nibble\nimport \"x.json\" as x : Str\n" },
		{ owner: App, path: "/p/app/Helpers.roc", text: "import json.Wire\nimport Util/Strs\nimport util.Strs\n" },
		{ owner: Package(pf), path: "${pkgs}/${pf}/Stdout.roc", text: "import Host\n" },
	]
	seen_one = ["/p/app/main.roc", "${pkgs}/${pf}/Stdout.roc", "${pkgs}/${json}/Json.roc", "/p/app/Helpers.roc"]
	second = level(read_one, seen_one)
	second_want = {
		used: [{ hash: json, path: "Wire.roc" }, { hash: util, path: "Strs.roc" }, { hash: json, path: "Internal/Nibble.roc" }, { hash: pf, path: "Host.roc" }],
		next: [
			{ owner: Package(json), path: "${pkgs}/${json}/Wire.roc" },
			{ owner: Package(util), path: "${pkgs}/${util}/Strs.roc" },
			{ owner: Package(json), path: "${pkgs}/${json}/Internal/Nibble.roc" },
			{ owner: App, path: "/p/app/Util/Strs.roc" },
			{ owner: Package(pf), path: "${pkgs}/${pf}/Host.roc" },
		],
	}
	cycle = level(
		[{ owner: Package(json), path: "${pkgs}/${json}/Wire.roc", text: "import Json\nimport parser.Parser\n" }],
		["/p/app/main.roc", "${pkgs}/${json}/Wire.roc", "${pkgs}/${json}/Json.roc"],
	)
	cycle_want = { used: [{ hash: json, path: "Json.roc" }], next: [] }
	in_parser = level(
		[{ owner: Package(parser), path: "${pkgs}/${parser}/Parser.roc", text: "import j.Wire\nimport Yaml\n" }],
		["${pkgs}/${parser}/Parser.roc"],
	)
	in_parser_want = { used: [{ hash: json, path: "Wire.roc" }, { hash: parser, path: "Yaml.roc" }], next: [{ owner: Package(json), path: "${pkgs}/${json}/Wire.roc" }, { owner: Package(parser), path: "${pkgs}/${parser}/Yaml.roc" }] }
	none = level([], [])
	rows = [
		("the app file: 2 modules used, 3 files next", Str.inspect(first), Str.inspect(first_want)),
		("the next level: package locals, an alias of the package header, the app local", Str.inspect(second), Str.inspect(second_want)),
		("a cycle: a file that was read is not next, the use is still reported", Str.inspect(cycle), Str.inspect(cycle_want)),
		("an alias of the header of a package (not the app header)", Str.inspect(in_parser), Str.inspect(in_parser_want)),
		("no source", Str.inspect(none), Str.inspect({ used: [], next: [] })),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
