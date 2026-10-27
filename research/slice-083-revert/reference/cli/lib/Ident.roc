import header.PackageUrl
import semver.Semver

## The identity of a package release, from its URL (Design 4.1, R-ID1 to R-ID5).
## The URL rules (version, group, hash) are in the generic package `roc-app-header` (`PackageUrl`).
## Talon adds the name, the label and the series of a version text.
##
## | Field | Holds | Rule |
## | --- | --- | --- |
## | `url` | The URL text, as given | |
## | `name` | `owner/repo` for `https://github.com/<owner>/<repo>/releases/download/<tag>/<hash>.tar.zst`. Other URLs: `Err(NoName)` until question Q6 of the slice file is answered. | R-ID3 |
## | `version` | The `X.Y.Z` run of the URL, as `X.Y.Z` | R-ID4 |
## | `series` | The major, or `0.minor` below 1.0 | R-ID1 |
## | `group` | The URL form (the URL with no scheme, `{v}` in place of the version, no hash) and the series | R-ID2 |
## | `label` | `<name>@<version>`: `roc-lang/unicode@4.2.0`. `Err(NoName)` when `name` is. | R-ID4 |
## | `hash` | The hash of the URL: the content id | R-ID5 |
Ident := {
	url : Str,
	name : Try(Str, [NoName]),
	version : Str,
	series : Str,
	group : { form : Str, series : Str },
	label : Try(Str, [NoName]),
	hash : Str,
}.{
	is_eq : _

	## Reads a release URL. A path entry, or a URL with no version, with two versions, or with `0.0.0`,
	## is `Err(Foreign)`: Talon cannot identify it and never changes it (Design 4.2, R-H4).
	of_url : Str -> Try(Ident, [Foreign])
	of_url = |url| match PackageUrl.parse(url) {
		Err(_) => Err(Foreign)
		Ok(parsed) => if !Ident.safe_part(parsed.hash()) Err(Foreign) else {
			v = parsed.version()
			version = "${v.major.to_str()}.${v.minor.to_str()}.${v.patch.to_str()}"
			name = github_name(parsed.url_form())
			Ok({
				url,
				name,
				version,
				series: parsed.series(),
				group: parsed.group(),
				label: name.map_ok(|n| "${n}@${version}"),
				hash: parsed.hash(),
			})
		}
	}

	## Slice 076 (R-ID3, R-H4, R-DI1): the one guard for a part of a path that comes from outside (a part of a URL, a header, a typed name). True when the text is a safe path part: not empty, not `.` or `..`, and with no `/`, no backslash
	## and no NUL byte. So `v1..2`, `a.b` and `.hidden` are safe, and `a/b`, `..` and `a<backslash>b` are not. Every module that joins a text from outside into a path calls this function first (the audit table of the slice file).
	## `of_url` uses it for the hash (an unsafe hash makes the URL foreign, R-H4) and for `owner` and `repo` (an unsafe one gives no name, R-ID3).
	safe_part : Str -> Bool
	safe_part = |part| !part.is_empty() and part != "." and part != ".." and !part.contains("/") and !part.contains("\\") and !part.contains("\u(0)")

	## The series of a version text (R-ID1): `4.2.0` gives `4`, `0.25.1` gives `0.25`.
	## A text that is not `X.Y.Z` is `Err(BadVersion)`. A pre-release part is not tested (question Q10).
	series_of : Str -> Try(Str, [BadVersion])
	series_of = |version| match Semver.parse(version) {
		Ok(v) => Ok(if v.major() >= 1 v.major().to_str() else "0.${v.minor().to_str()}")
		Err(_) => Err(BadVersion)
	}
}

# R-ID3: `owner/repo` of the URL form `github.com/<owner>/<repo>/releases/download/<tag>/`.
github_name : Str -> Try(Str, [NoName])
github_name = |form| match form.split_on("/") {
	["github.com", owner, repo, "releases", "download", tag, ""] if Ident.safe_part(owner) and Ident.safe_part(repo) and !tag.is_empty() => Ok("${owner}/${repo}")
	_ => Err(NoName)
}
