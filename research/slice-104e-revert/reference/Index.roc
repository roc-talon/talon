import Artifact
import Closure
import Nullable
import Release

## Private reference of slice 104e (not for the code agent).
Index :: [].{

	Releases : { releases : List(Release.Row), checked : Try(Closure.Checked, [None]), repos : List(Closure.Repo) }
	Page : { releases : List(Release.Row), repos : List(Closure.Repo) }
	Detail : { artifact : Artifact.Row, releases : List(Release.Row), repos : List(Closure.Repo) }

	ReleasesWire : { releases : List(Release.Wire), checked : Nullable(Closure.CheckedWire), repos : List(Closure.RepoWire) }
	PageWire : { releases : List(Release.Wire), repos : List(Closure.RepoWire) }
	DetailWire : { artifact : Artifact.Wire, releases : List(Release.Wire), repos : List(Closure.RepoWire) }

	list_of : List(Str) -> Str
	list_of = |items| "[${Str.join_with(items, ",")}]"

	releases_text : List(Release.Row) -> Str
	releases_text = |rs| list_of(rs.map(Release.encode))

	repos_text : List(Closure.Repo) -> Str
	repos_text = |rs| list_of(rs.map(Closure.encode_repo))

	repos_of : List(Closure.RepoWire) -> Try(List(Closure.Repo), [BadJson(Str)])
	repos_of = |ws| ws.map_try(|w| Closure.decode_repo(Json.to_str(w)))

	encode_releases : Index.Releases -> Str
	encode_releases = |a| {
		checked = match a.checked {
			Ok(c) => Closure.encode_checked(c)
			Err(None) => "null"
		}
		"{\"releases\":${releases_text(a.releases)},\"checked\":${checked},\"repos\":${repos_text(a.repos)}}"
	}

	decode_releases : Str -> Try(Index.Releases, [BadJson(Str)])
	decode_releases = |text| {
		parsed : Try(Index.ReleasesWire, _)
		parsed = Json.parse(text)
		match parsed {
			Err(e) => Err(BadJson(Str.inspect(e)))
			Ok(w) => {
				repos = repos_of(w.repos)?
				checked = match Nullable.read(w.checked) {
					Ok(c) => Closure.decode_checked(Json.to_str(c)).map_ok(|x| Ok(x))?
					Err(None) => Err(None)
				}
				Ok({ releases: w.releases.map(Release.from_wire), checked, repos })
			}
		}
	}

	encode_page : Index.Page -> Str
	encode_page = |a| "{\"releases\":${releases_text(a.releases)},\"repos\":${repos_text(a.repos)}}"

	decode_page : Str -> Try(Index.Page, [BadJson(Str)])
	decode_page = |text| {
		parsed : Try(Index.PageWire, _)
		parsed = Json.parse(text)
		match parsed {
			Err(e) => Err(BadJson(Str.inspect(e)))
			Ok(w) => Ok({ releases: w.releases.map(Release.from_wire), repos: repos_of(w.repos)? })
		}
	}

	encode_detail : Index.Detail -> Str
	encode_detail = |a| "{\"artifact\":${Artifact.encode(a.artifact)},\"releases\":${releases_text(a.releases)},\"repos\":${repos_text(a.repos)}}"

	decode_detail : Str -> Try(Index.Detail, [BadJson(Str)])
	decode_detail = |text| {
		parsed : Try(Index.DetailWire, _)
		parsed = Json.parse(text)
		match parsed {
			Err(e) => Err(BadJson(Str.inspect(e)))
			Ok(w) => Ok({ artifact: Artifact.from_wire(w.artifact)?, releases: w.releases.map(Release.from_wire), repos: repos_of(w.repos)? })
		}
	}
}
