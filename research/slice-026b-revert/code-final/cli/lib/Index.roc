import base58.Base58
import Clock
import Ident
import JsonDoc
import Text

## The candidates of a repository in `direct` mode (CLI 7.3, R-DI3 to R-DI6, R-DI9 to R-DI11, R-DI14, R-DI15). The index is the
## list of the releases of a GitHub repository. These are pure decisions over the text of the pages that `Github.releases!` gives.
Index :: [].{

	## One candidate: a published release with one package asset (the same facts as a registry record, R-DI14, that the archive
	## does not give). `url` is the asset URL of the answer (question Q1), `ident` is its identity (`Ident.of_url`), `tag` the tag of the
	## release, `published_at` the time of R-DI10 in seconds since the epoch (UTC), `size` the size of the asset in bytes (R-DA6).
	Candidate : { url : Str, ident : Ident, tag : Str, published_at : U64, size : U64 }

	## The candidates of the pages of the release list (R-DI3 to R-DI5, R-DI10, R-DI15). `pages` are the texts of the pages, in
	## order. `owner` and `repo` name the repository in the warnings. `known` are the URLs that Talon already knows (the header entries
	## and the deps of the package headers that it has read, R-DI15). The list keeps the order of the pages and of each page.
	##
	## A release of a page (a JSON object):
	##
	## | Field | Use |
	## | --- | --- |
	## | `tag_name` | The tag (a text) |
	## | `draft`, `prerelease` | `true` skips the release (R-DI3) |
	## | `published_at` | `YYYY-MM-DDTHH:MM:SSZ`: the release time (R-DI10). Not read for a skipped release. |
	## | `assets` | The list of `{ name, size, browser_download_url }`. The other fields of an object are not read. |
	##
	## A release is a candidate when:
	##
	## | # | Test | Rule |
	## | --- | --- | --- |
	## | 1 | It is not a draft and not a prerelease | R-DI3 |
	## | 2 | Exactly one asset is named `<hash>.tar.zst` where `<hash>` is base58 text of 32 bytes. Other names do not count (`docs.tar.gz`, `<hash>.tar.zst.intoto.jsonl`, a name with a bad hash). With 2 or more such assets: no candidate, and a warning (below). With none: no candidate and no warning. | R-DI4 |
	## | 3 | `Ident.of_url(<the asset URL>)` is `Ok`: one `X.Y.Z` run, not `0.0.0`. The tag text around the run is part of the group. | R-DI5 |
	## | 4 | It is not a re-release (R-DI15): no URL of `known` has the same group and the same version with another hash | R-DI15 |
	##
	## A page that is not a JSON array of objects, or a release with no text `tag_name`, or a release that passes the test 1 to 3 and has no
	## `published_at` that `Clock.parse_utc` reads, is `Err(BadPage(n))`, with `n` the 1-based number of the page.
	##
	## Warnings, in the order of the releases (the texts are proposals, R-OUT2):
	##
	## | Case | Text |
	## | --- | --- |
	## | 2 or more package assets | `<owner>/<repo> <tag>: the release has 2 package assets (<hash>, <hash>). It is not a candidate.` The count and the hashes are in the order of the assets. |
	## | Re-release | `<owner>/<repo> <tag>: the release has the hash <new>, but Talon knows <known URL> with the hash <old>. It is not a candidate.` |
	candidates : { owner : Str, repo : Str, pages : List(Str), known : List(Str) } -> Try({ list : List(Candidate), warnings : List(Str) }, [BadPage(U64)])
	candidates = |facts| {
		ctx = { owner: facts.owner, repo: facts.repo, known: facts.known }
		facts.pages
			.map_with_index(|text, i| (i + 1, text))
			.fold_try(
				{ list: [], warnings: [] },
				|found, (n, text)| match JsonDoc.parse(text) {
					Ok(Arr(releases)) => releases.fold_try(found, |acc, release| read_release(ctx, acc, release).map_err(|_| BadPage(n)))
					_ => Err(BadPage(n))
				},
			)
	}

	## The candidates of one group (R-DI6): those whose `ident.group` equals `group`. The order stays.
	in_group : { list : List(Candidate), group : { form : Str, series : Str } } -> List(Candidate)
	in_group = |facts| facts.list.keep_if(|c| c.ident.group == facts.group)

	## The candidates for a new entry (`tln add`, R-DI6): the URL form of the newest candidate by `published_at` (the first one wins a tie),
	## and all candidates in that URL form, of every series, in the order of `list`. `note` is a note when the repository has candidates in
	## other URL forms: `<name> also has releases in other URL forms: <form>, <form>` (the forms in byte order, `name` is `<owner>/<repo>`). With no
	## candidate: `Err(NoCandidate)`.
	new_entry : { name : Str, list : List(Candidate) } -> Try({ form : Str, list : List(Candidate), note : Try(Str, [None]) }, [NoCandidate])
	new_entry = |facts| match facts.list {
		[] => Err(NoCandidate)
		[first, .. as rest] => {
			newest = rest.fold(first, |best, c| if c.published_at > best.published_at c else best)
			form = newest.ident.group.form
			others = Text.sorted_unique(facts.list.map(|c| c.ident.group.form).keep_if(|f| f != form))
			Ok({
				form,
				list: facts.list.keep_if(|c| c.ident.group.form == form),
				note: if others.is_empty() {
					Err(None)
				} else {
					Ok("${facts.name} also has releases in other URL forms: ${Str.join_with(others, ", ")}")
				},
			})
		}
	}

	## The order in which the solver asks for candidates (R-DI9, the strategy): `Highest` is the newest version first, `Lowest` the oldest
	## version first. The version is the `X.Y.Z` of the URL, compared as numbers (`1.10.0` is above `1.9.0`), not the release time. Candidates
	## of one version keep their order. The list is for one group.
	order : List(Candidate), [Highest, Lowest] -> List(Candidate)
	order = |list, strategy| list
		.map_with_index(|c, i| (i, c))
		.sort_with(
			|(i, a), (j, b)| {
				by_version = compare_versions(version_numbers(a.ident.version), version_numbers(b.ident.version))
				match (by_version, strategy) {
					(Same, _) => compare_index(i, j)
					(Before, Lowest) | (After, Highest) => Before
					_ => After
				}
			},
		)
		.map(|(_, c)| c)

	## Whether a URL has an index in `direct` mode (R-DI11): `Indexed` for the host `github.com`, else `Fixed(host)`, with `host` the text between
	## `://` and the next `/`. The entry is an anchor at its header value.
	host_kind : Str -> [Indexed, Fixed(Str)]
	host_kind = |url| {
		after_scheme = match url.split_first("://") {
			Ok(parts) => parts.after
			Err(NotFound) => url
		}
		host = match after_scheme.split_on("/").first() {
			Ok(h) => h
			Err(_) => after_scheme
		}
		if host == "github.com" Indexed else Fixed(host)
	}

	## The text that `tln update`, `tln upgrade` and `tln outdated` print for a `Fixed` host (R-DI11, the text of the design):
	## `fixed: <host> has no index without a registry`.
	fixed_line : Str -> Str
	fixed_line = |host| "fixed: ${host} has no index without a registry"
}

Ctx : { owner : Str, repo : Str, known : List(Str) }

Found : { list : List(Index.Candidate), warnings : List(Str) }

# One release of a page: the new state, or `Bad` for the cases of `BadPage`.
read_release : Ctx, Found, JsonDoc -> Try(Found, [Bad])
read_release = |ctx, found, doc| match doc {
	Obj(pairs) => {
		tag = match field(pairs, "tag_name") {
			Ok(Text(t)) => t
			_ => return Err(Bad)
		}
		if is_true(pairs, "draft") or is_true(pairs, "prerelease") {
			Ok(found)
		} else {
			read_assets(ctx, found, pairs, tag)
		}
	}
	_ => Err(Bad)
}

read_assets : Ctx, Found, List((Str, JsonDoc)), Str -> Try(Found, [Bad])
read_assets = |ctx, found, pairs, tag| {
	name = "${ctx.owner}/${ctx.repo} ${tag}"
	base = "https://github.com/${ctx.owner}/${ctx.repo}/releases/download/${tag}"
	assets = package_assets(pairs)
	match assets {
		[] => Ok(found)
		[one] => {
			url = "${base}/${one.name}"
			match Ident.of_url(url) {
				Err(Foreign) => Ok(found)
				Ok(ident) => {
					published_at = match field(pairs, "published_at") {
						Ok(Text(t)) => Clock.parse_utc(t).map_err(|BadTime| Bad)?
						_ => return Err(Bad)
					}
					match re_release(ctx.known, ident) {
						Ok(old) => Ok({ ..found, warnings: found.warnings.append("${name}: the release has the hash ${ident.hash}, but Talon knows ${old.url} with the hash ${old.hash}. It is not a candidate.") })
						Err(NotFound) => Ok({ ..found, list: found.list.append({ url, ident, tag, published_at, size: one.size }) })
					}
				}
			}
		}
		_ => {
			hashes = Str.join_with(assets.map(|a| a.hash), ", ")
			Ok({ ..found, warnings: found.warnings.append("${name}: the release has ${assets.len().to_str()} package assets (${hashes}). It is not a candidate.") })
		}
	}
}

field : List((Str, JsonDoc)), Str -> Try(JsonDoc, [NotFound])
field = |pairs, key| match pairs.find_first(|(k, _)| k == key) {
	Ok((_, value)) => Ok(value)
	Err(NotFound) => Err(NotFound)
}

is_true : List((Str, JsonDoc)), Str -> Bool
is_true = |pairs, key| match field(pairs, key) {
	Ok(Flag(b)) => b
	_ => Bool.False
}

# The assets named `<hash>.tar.zst` with a base58 hash of 32 bytes (R-DI4, G1).
package_assets : List((Str, JsonDoc)) -> List({ name : Str, hash : Str, size : U64 })
package_assets = |pairs| match field(pairs, "assets") {
	Ok(Arr(items)) => items.keep_oks(
		|item| match item {
			Obj(asset) => match field(asset, "name") {
				Ok(Text(name)) => if is_package_name(name) {
					Ok({
						name,
						hash: name.drop_suffix(".tar.zst"),
						size: match field(asset, "size") {
							Ok(Num(n)) => if n >= 0 n.to_u64_wrap() else 0
							_ => 0
						},
					})
				} else {
					Err(NotAPackage)
				}
				_ => Err(NotAPackage)
			}
			_ => Err(NotAPackage)
		},
	)
	_ => []
}

is_package_name : Str -> Bool
is_package_name = |name| name.ends_with(".tar.zst") and Base58.decode(name.drop_suffix(".tar.zst")).map_ok(|bytes| bytes.len()) == Ok(32)

# R-DI15: a known URL with the same group and version and another hash.
re_release : List(Str), Ident -> Try(Ident, [NotFound])
re_release = |known, ident| known
	.keep_oks(Ident.of_url)
	.find_first(|k| k.group == ident.group and k.version == ident.version and k.hash != ident.hash)

version_numbers : Str -> List(U64)
version_numbers = |version| version.split_on(".").map(|part| U64.from_str(part) ?? 0)

compare_versions : List(U64), List(U64) -> [Before, Same, After]
compare_versions = |a, b| match (a, b) {
	([x, .. as xs], [y, .. as ys]) => if x < y Before else if x > y After else compare_versions(xs, ys)
	([], []) => Same
	([], _) => Before
	(_, []) => After
}

compare_index : U64, U64 -> [Before, Same, After]
compare_index = |i, j| if i < j Before else if i > j After else Same
