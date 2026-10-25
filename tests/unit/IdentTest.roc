import lib.Ident

IdentTest :: [].{}

# R-ID1 R-ID2 R-ID3 R-ID4 R-ID5: the identity of a release from its URL: name, version, series, group, label, content id.
# The name is `owner/repo` for a GitHub release URL. The group is the URL form plus the series, so 1.9.0 and 2.0.0 of one
# repo are two groups with one URL form. A path entry, or a URL with no version, 2 versions or 0.0.0, is foreign (R-H4).
expect {
	cli_hash = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"
	uni_hash = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"
	view = |url| match Ident.of_url(url) {
		Ok(i) => Ok((i.name, i.version, i.series, i.group, i.label, i.hash))
		Err(e) => Err(e)
	}
	rows = [
		(
			"https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${cli_hash}.tar.zst",
			Ok((Ok("roc-lang/basic-cli"), "0.25.0", "0.25", { form: "github.com/roc-lang/basic-cli/releases/download/{v}/", series: "0.25" }, Ok("roc-lang/basic-cli@0.25.0"), cli_hash)),
		),
		(
			"https://github.com/roc-lang/unicode/releases/download/4.2.0/${uni_hash}.tar.zst",
			Ok((Ok("roc-lang/unicode"), "4.2.0", "4", { form: "github.com/roc-lang/unicode/releases/download/{v}/", series: "4" }, Ok("roc-lang/unicode@4.2.0"), uni_hash)),
		),
		(
			"https://github.com/roc-lang/http/releases/download/1.9.0/Aaa.tar.zst",
			Ok((Ok("roc-lang/http"), "1.9.0", "1", { form: "github.com/roc-lang/http/releases/download/{v}/", series: "1" }, Ok("roc-lang/http@1.9.0"), "Aaa")),
		),
		(
			"https://github.com/roc-lang/http/releases/download/2.0.0/Bbb.tar.zst",
			Ok((Ok("roc-lang/http"), "2.0.0", "2", { form: "github.com/roc-lang/http/releases/download/{v}/", series: "2" }, Ok("roc-lang/http@2.0.0"), "Bbb")),
		),
		("../util/main.roc", Err(Foreign)),
		("https://example.com/pkg/Ccc.tar.zst", Err(Foreign)),
		("https://example.com/1.0.0/2.0.0/Ccc.tar.zst", Err(Foreign)),
		("https://example.com/pkg/0.0.0/Ccc.tar.zst", Err(Foreign)),
	]
	bad = rows.keep_if(|(url, want)| view(url) != want).map(|(url, want)| (url, want, view(url)))
	dbg bad
	# A URL on another host has a group, a version and a hash. Its name is question Q6, so the row has no name.
	other = match Ident.of_url("https://example.com/pkgs/json/2.1.0/Ddd.tar.zst") {
		Ok(i) => (i.version, i.series, i.group, i.hash) == ("2.1.0", "2", { form: "example.com/pkgs/json/{v}/", series: "2" }, "Ddd")
		Err(_) => Bool.False
	}
	bad == [] and other
}

# R-ID1: the series is the major, or `0.minor` below 1.0.
expect {
	rows = [
		("4.2.0", Ok("4")),
		("1.0.0", Ok("1")),
		("0.25.1", Ok("0.25")),
		("0.0.3", Ok("0.0")),
		("x", Err(BadVersion)),
		("1.2", Err(BadVersion)),
	]
	bad = rows.keep_if(|(v, want)| Ident.series_of(v) != want).map(|(v, want)| (v, want, Ident.series_of(v)))
	dbg bad
	bad == []
}
