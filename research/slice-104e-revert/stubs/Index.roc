import Artifact
import Closure
import Release

## The answers of the release reads (Registry R-AP1, R-AP2, R-AP13, R-AP14, R-AP53, R-AP73; slice 104e). Pure.
## The encoders write the bytes of `worker/lib/Reads.roc` (`releases_body`, `page_body`, `artifact_body`): no white space, the members in the order below, the lists in the order given (the caller sorts, R-AP53), a release by `Release.encode`, a `repos` item by `Closure.encode_repo`, a `checked` item by `Closure.encode_checked`.
## The decoders follow R-AP51: a required member that is missing or `null` is `BadJson`, an unknown member is ignored. `checked` is required and may be `null`.
Index :: [].{

	## R-AP1, R-AP13, R-AP14 with `group`. Members in this order: `releases`, `checked` (one item or `null`), `repos`.
	Releases : { releases : List(Release.Row), checked : Try(Closure.Checked, [None]), repos : List(Closure.Repo) }

	## R-AP14 with no `group`. Members: `releases`, `repos`.
	Page : { releases : List(Release.Row), repos : List(Closure.Repo) }

	## R-AP2. Members: `artifact`, `releases`, `repos`.
	Detail : { artifact : Artifact.Row, releases : List(Release.Row), repos : List(Closure.Repo) }

	encode_releases : Index.Releases -> Str
	encode_releases = |_a| crash "todo"

	decode_releases : Str -> Try(Index.Releases, [BadJson(Str)])
	decode_releases = |_text| crash "todo"

	encode_page : Index.Page -> Str
	encode_page = |_a| crash "todo"

	decode_page : Str -> Try(Index.Page, [BadJson(Str)])
	decode_page = |_text| crash "todo"

	encode_detail : Index.Detail -> Str
	encode_detail = |_a| crash "todo"

	decode_detail : Str -> Try(Index.Detail, [BadJson(Str)])
	decode_detail = |_text| crash "todo"
}
