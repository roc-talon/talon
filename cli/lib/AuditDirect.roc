import AuditTypes
import Fail
import Github
import Ident
import Index
import JsonDoc

## The decisions of `tln audit` with `direct` (slice 244b, R-AU1, R-AU2 `direct` column, R-DI2 to R-DI4, R-DI11, R-DI15). Part A: pure. `AuditCheck` re-exports these names.
## The release lists come from `Github.audit_list!` (command code in `AuditFlow`).
AuditDirect :: [].{

	## A release list of one repository: the call answered 404, or the pages (`redirected`: GitHub redirected a renamed repository, Q-244b-1).
	Fetched : [NotFound, Pages({ pages : List(Str), redirected : Bool })]

	## The repository `owner/repo` (lower case) of an entry or a URL on `github.com`. Another host: `Err(None)`.
	repo_of : Str -> Try({ owner : Str, repo : Str }, [None])
	repo_of = |url| match Github.hint_ref(url) {
		Ok(ref) => Ok({ owner: ref.owner.with_ascii_lowercased(), repo: ref.repo.with_ascii_lowercased() })
		Err(NoRef) => Err(None)
	}

	## R-AU1, R-DI2, R-DI11: the repositories to list: the `github.com` repository of each entry, lower case, each once, in the order of the entries.
	repos_of : List(AuditTypes.Entry) -> List({ owner : Str, repo : Str })
	repos_of = |entries| entries
		.keep_oks(|e| AuditDirect.repo_of(e.url))
		.fold([], |acc, r| if acc.contains(r) acc else acc.append(r))

	## R-AU2, R-AU13, R-DI3, R-DI4, R-DI15 (Q-244b-1, Q-244b-2): the finding of one entry from the list of its repository. The release is the one whose `tag_name` is the tag of the URL. Order: `asset-replaced`, `release-missing`, `prerelease`, `moved`.
	## A draft is not the release. `BadPage(n)` is a page (1-based) that is not a list of releases.
	direct_finding : { entry : AuditTypes.Entry, list : AuditDirect.Fetched } -> Try(AuditTypes.Finding, [None, BadPage(U64)])
	direct_finding = |facts| {
		e = facts.entry
		base = { entry: e, reason: RepoMissing, ignored: Err(None), since: Err(None), yank_reason: Err(None), new_hash: Err(None), successor: Err(None) }
		match facts.list {
			NotFound => Ok(base)
			Pages({ pages, redirected }) => {
				releases = read_pages(pages)?
				tag = Github.hint_ref(e.url).map_ok(|r| r.tag) ?? ""
				found = releases.find_first(|r| r.tag == tag and !r.draft)
				successor = if redirected moved_to(releases, e.name) else Err(None)
				found_as = |reason, new_hash| Ok({ ..base, reason, new_hash, successor })
				match found {
					Err(_) => found_as(ReleaseMissing, Err(None))
					Ok(r) => {
						others = r.assets.keep_if(|h| h != e.hash)
						if !r.assets.contains(e.hash) {
							found_as(AssetReplaced, if others.len() == 1 others.first().map_err(|_| None) else Err(None))
						} else if r.prerelease {
							found_as(Prerelease, Err(None))
						} else if redirected {
							found_as(Moved, Err(None))
						} else {
							Err(None)
						}
					}
				}
			}
		}
	}

	## R-AU1, R-AU2, R-DI11: the findings of `direct`, in the order of the entries. `checked` counts the entries with a list (also a 404). An entry of another host, or of a repository with no list, is in `unindexed`. A bad page stops the run (kind `Network`, exit 15).
	of_lists : { entries : List(AuditTypes.Entry), lists : List({ owner : Str, repo : Str, list : AuditDirect.Fetched }) } -> Try({ checked : U64, findings : List(AuditTypes.Finding), unindexed : List(AuditTypes.Entry) }, Fail)
	of_lists = |facts| facts.entries.fold_try(
		{ checked: 0, findings: [], unindexed: [] },
		|acc, entry| {
			got = match AuditDirect.repo_of(entry.url) {
				Ok(listed) => facts.lists.find_first(|l| l.owner == listed.owner and l.repo == listed.repo).map_err(|_| None)
				Err(None) => Err(None)
			}
			match got {
				Err(None) => Ok({ ..acc, unindexed: acc.unindexed.append(entry) })
				Ok(l) => match AuditDirect.direct_finding({ entry, list: l.list }) {
					Ok(f) => Ok({ ..acc, checked: acc.checked + 1, findings: acc.findings.append(f) })
					Err(None) => Ok({ ..acc, checked: acc.checked + 1 })
					Err(BadPage(n)) => Err(Fail.new(Network, "the release list of ${l.owner}/${l.repo} (page ${n.to_str()}) is not a list of releases"))
				}
			}
		},
	)
}

Release : { tag : Str, draft : Bool, prerelease : Bool, html_url : Str, assets : List(Str) }

# The releases of all pages, or the number of the first page that is not a list of objects with a text `tag_name`.
read_pages : List(Str) -> Try(List(Release), [BadPage(U64)])
read_pages = |pages| pages.fold_try(
	(1, []),
	|(n, acc), page| match JsonDoc.parse(page) {
		Ok(Arr(items)) => {
			read = items.map_try(read_release).map_err(|_| BadPage(n))?
			Ok((n + 1, acc.concat(read)))
		}
		_ => Err(BadPage(n))
	},
).map_ok(|(_, all)| all)

read_release : JsonDoc -> Try(Release, [Bad])
read_release = |doc| match doc {
	Obj(pairs) => {
		flag = |key| match pairs.find_first(|(k, _)| k == key) {
			Ok((_, Flag(b))) => b
			_ => Bool.False
		}
		tag = match pairs.find_first(|(k, _)| k == "tag_name") {
			Ok((_, Text(t))) => t
			_ => return Err(Bad)
		}
		html_url = match pairs.find_first(|(k, _)| k == "html_url") {
			Ok((_, Text(u))) => u
			_ => ""
		}
		Ok({ tag, draft: flag("draft"), prerelease: flag("prerelease"), html_url, assets: Index.assets_of(pairs).map(|a| a.hash) })
	}
	_ => Err(Bad)
}

# Q-244b-1: the `owner/repo` of the `html_url` of the first release, when it is not the old name (any case).
moved_to : List(Release), Str -> Try(Str, [None])
moved_to = |releases, old| match releases.first() {
	Ok(r) => match html_repo(r.html_url) {
		Ok(name) => if name.with_ascii_lowercased() == old.with_ascii_lowercased() Err(None) else Ok(name)
		Err(None) => Err(None)
	}
	Err(_) => Err(None)
}

# `owner/repo` of `https://github.com/<owner>/<repo>/...`, as written.
html_repo : Str -> Try(Str, [None])
html_repo = |url| match url.drop_prefix("https://github.com/").split_on("/") {
	[owner, repo, ..] if url.starts_with("https://github.com/") and !owner.is_empty() and !repo.is_empty() => Ok("${owner}/${repo}")
	_ => Err(None)
}
