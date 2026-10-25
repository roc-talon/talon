import lib.Args
import lib.Fail
import lib.JsonDoc
import lib.Locked
import lib.PathCmd
import lib.Roots

PathcmdTest :: [].{}

h_cli = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

h_json = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h_http = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"

cli_url = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${h_cli}.tar.zst"

json_url = "https://github.com/someone/roc-json/releases/download/2.1.0/${h_json}.tar.zst"

http_url = "https://github.com/roc-lang/http/releases/download/1.9.0/${h_http}.tar.zst"

odd_url = "https://example.com/pkg/latest.tar.gz"

file = "/w/proj/app/main.roc"

# An app header: a platform, a package, 4 path entries (relative, with `..` and `.`, deeper, absolute), a foreign URL, a comment, and the `roc:` pin.
header = "# my app\napp [main!] {\n\t# the platform\n\tpf: platform \"${cli_url}\", # trailing\n\tjson: \"${json_url}\",\n\tlib: \"../shared/lib/main.roc\",\n\tdeep: \"vendor/a/b/main.roc\",\n\tdot: \"./x/../y/main.roc\",\n\tabs: \"/opt/pf/main.roc\",\n\todd: \"${odd_url}\",\n\troc: \"nightly-2026-10-09-258ab27\",\n}\n\nmain! = |_| Ok({})\n"

roots : Roots
roots = Roots.{ cache: "/h/.cache/roc", pkgs: "/h/.cache/roc/packages", build: "/h/.cache/roc", config: "/h/.config/talon", data: "/h/.local/share/talon" }

# The header rows of the project file, as `Locked.read` gives them (a function: a top-level constant with a `crash` branch is a warning of `roc test`).
hdr_rows = |text| match Locked.read({ path: file, text }) {
	Ok(l) => l.rows
	Err(_) => crash "bad test header"
}

# The result of `pick` as text: the failure line, or the kind of the source, the url, and the directory.
pick_view = |alias| match PathCmd.pick({ alias, rows: hdr_rows(header), file, roots }) {
	Ok(e) => match e.source {
		Release(url) => "release ${url} ${e.dir}"
		Dir => "dir ${e.dir}"
	}
	Err(f) => Fail.line(f)
}

read_view = |words| match Args.parse(words) {
	Err(stop) => Fail.line(stop.fail)
	Ok(args) => match PathCmd.read(args) {
		Ok(want) => "alias ${want.alias}"
		Err(f) => Fail.line(f)
	}
}

# R-PTH1 R-EC2: the operands of `tln path`. One alias. No alias, and 2 or more, are usage failures (exit 2). The texts are a proposal (TW24).
expect {
	rows = [
		(["path", "pf"], "alias pf"),
		(["path", "pf", "--file", "p/main.roc", "--json"], "alias pf"),
		(["path"], "tln: error[usage]: tln path needs an alias: a name in the header of the project file"),
		(["path", "pf", "json"], "tln: error[usage]: tln path takes one alias, got 2 names"),
		(["path", "a", "b", "c"], "tln: error[usage]: tln path takes one alias, got 3 names"),
	]
	bad = rows.keep_if(|(words, want)| read_view(words) != want).map(|(words, want)| (words, want, read_view(words)))
	dbg bad
	bad == []
}

# R-PTH1 R-PTH3 R-CR1 R-H4 R-H7: the directory of an entry. A release URL (also the platform entry): `<pkgs>/<hash>` (the packages root, R-CR1). A path entry: the directory of the file that it names, seen from
# the directory of the project file, with no `.` and no `..`; an absolute value stays. A foreign URL and an alias that is not in the header (also a different case) are usage failures (the `roc:` pin: question Q2, not tested).
# Both are usage failures (exit 2, R-PTH3). Texts: a proposal (TW24).
expect {
	pkgs = "/h/.cache/roc/packages"
	rows = [
		("pf", "release ${cli_url} ${pkgs}/${h_cli}"),
		("json", "release ${json_url} ${pkgs}/${h_json}"),
		("lib", "dir /w/proj/shared/lib"),
		("deep", "dir /w/proj/app/vendor/a/b"),
		("dot", "dir /w/proj/app/y"),
		("abs", "dir /opt/pf"),
		("odd", "tln: error[usage]: 'odd' is a foreign URL (${odd_url}): roc keeps it under another cache rule, so it has no directory in packages/ (R-PTH3)"),
		("nope", "tln: error[usage]: no entry 'nope' in the header of /w/proj/app/main.roc. Entries: pf, json, lib, deep, dot, abs, odd."),
		("PF", "tln: error[usage]: no entry 'PF' in the header of /w/proj/app/main.roc. Entries: pf, json, lib, deep, dot, abs, odd."),
	]
	bad = rows.keep_if(|(alias, want)| pick_view(alias) != want).map(|(alias, want)| (alias, want, pick_view(alias)))
	dbg bad
	bad == []
}

# R-PTH1: the output. stdout is the directory and a line end, nothing else. `--json` `data` is `{ alias, kind, dir }` with the kind `url` or `path` (a proposal, R-OUT2).
expect {
	entry = |alias| match PathCmd.pick({ alias, rows: hdr_rows(header), file, roots }) {
		Ok(e) => e
		Err(_) => crash "bad test alias"
	}
	shown = |alias| "${PathCmd.text(entry(alias))}|${JsonDoc.render(PathCmd.data(entry(alias)))}"
	checks = [
		(shown("pf"), "/h/.cache/roc/packages/${h_cli}\n|{\"alias\":\"pf\",\"kind\":\"url\",\"dir\":\"/h/.cache/roc/packages/${h_cli}\"}"),
		(shown("lib"), "/w/proj/shared/lib\n|{\"alias\":\"lib\",\"kind\":\"path\",\"dir\":\"/w/proj/shared/lib\"}"),
	]
	bad = checks.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
