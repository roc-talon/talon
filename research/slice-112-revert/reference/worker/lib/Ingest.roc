## The pure part of the ingest route `POST /v1/releases` with no token (Registry 4: R-AP9, R-AP26, R-AP41; 5.1: R-IK3; 7: R-PU4, R-PU6, R-PU14, R-PU15,
## R-PU19, R-PU26, R-PU31, R-PU32, R-PU34 rows 3 and 4, R-TP5; slice 112). No effect, no platform import.
## The effects (the body read, the D1 session and its calls, the GitHub reads, the archive read, the clock) are in `worker/IngestRoutes.roc`.
## The tests are in `worker/tests/unit/IngestTest.roc` (W0) and `worker/tests/cases/ingest/` (W2).
## The texts of the `detail` of a problem and the body form are proposals (TW24): `docs/slices/112-ingest.md` section 5.
import records.Artifact
import records.Release
import records.Id
import records.Code
import header.PackageUrl
import base58.Base58
import Toolchains
import semver.Semver
import Problem
import Reads
import Version

Ingest :: [].{

	# ---- the request ----

	## The release that the URL names (R-DI5, R-PU6). `url` is the request URL as sent. `owner`, `repo` and `tag` are the path parts as sent.
	## `name` is `<owner>/<repo>` with the ASCII letters in lower case (R-IK2, R-RE11). `hash` is the base58 hash of the last segment.
	## `form` is `PackageUrl.url_form` (the group, R-AP15). `version` is the `X.Y.Z` run of the URL. `column` is `Version.column(version)` (R-IK5).
	Target : { url : Str, owner : Str, repo : Str, name : Str, tag : Str, hash : Str, form : Str, version : Semver, column : Version.Column }

	## R-AP26, R-AP48 row 6, R-AP51. The body is a JSON object with the member `url` (text, required). The first rule that fails gives the problem:
	## 1. Not JSON, not an object, `url` missing, `null` or not text: 400 `bad-request` (`bad_body`).
	## 2. A member `compat` with a value that is not `null` (any JSON value): 401 `unauthenticated` (`compat_needs_token`). `compat: null` is no value (R-AP51): an ingest.
	## Other members are ignored (R-AP44). The result is the text of `url`.
	parse_body : List(U8) -> Try(Str, Problem)
	parse_body = |bytes| {
		text = Str.from_utf8(bytes) ?? ""
		parsed : Try({ url : Str }, _)
		parsed = Json.parse(text)
		match parsed {
			Err(_) => Err(bad_body(if (text.trim() == "") "the body is empty" else "the body is not a JSON object with a text member url"))
			Ok(b) => if (has_compat(text)) Err(compat_needs_token) else Ok(b.url)
		}
	}

	has_compat : Str -> Bool
	has_compat = |text| text.split_on("\"compat\"").drop_first(1).any(
		|after| {
			rest = after.trim_start()
			if rest.starts_with(":") {
				!rest.drop_prefix(":").trim_start().starts_with("null")
			} else {
				Bool.False
			}
		},
	)

	## R-PU34 row 4, R-DI5, R-PU6. The URL must be `https://github.com/<owner>/<repo>/releases/download/<tag>/<hash>.tar.zst`: exactly these 7 path parts after the host,
	## each part not empty, with no query and no fragment, `<hash>` base58 of exactly 32 bytes, and `PackageUrl.parse` gives `Ok` (one `X.Y.Z` run, not `0.0.0`).
	## Else 422 `not-a-candidate` (`not_release_url`). Another host is also `not_release_url`, with no D1 call and no GitHub call (R-PU40, Design Q155; R-AP68 row 2).
	parse_url : Str -> Try(Ingest.Target, Problem)
	parse_url = |url| {
		bad = Err(not_release_url(url))
		if !url.starts_with("https://github.com/") or url.contains("?") or url.contains("#") {
			return bad
		}
		match url.drop_prefix("https://github.com/").split_on("/") {
			[owner, repo, "releases", "download", tag, last] if owner != "" and repo != "" and tag != "" and is_package_asset(last) =>
				match PackageUrl.parse(url) {
					Ok(u) => {
						v = u.version()
						version = Semver.new(v.major, v.minor, v.patch)
						Ok({ url, owner, repo, name: "${owner}/${repo}".with_ascii_lowercased(), tag, hash: last.drop_suffix(".tar.zst"), form: u.url_form(), version, column: Version.column(version) })
					}
					Err(_) => bad
				}
			_ => bad
		}
	}

	is_package_asset : Str -> Bool
	is_package_asset = |name| name.ends_with(".tar.zst") and (b58(name.drop_suffix(".tar.zst")).len() == 32)

	b58 : Str -> List(U8)
	b58 = |text| Base58.decode(text) ?? []

	## The GitHub reads, in this order (R-AP68 rows 6, 8, 10; Design Q156). The parts are put in the URL as they are in the request URL.
	repo_url : Ingest.Target -> Str
	repo_url = |t| "https://api.github.com/repos/${t.owner}/${t.repo}"

	release_url : Ingest.Target -> Str
	release_url = |t| "https://api.github.com/repos/${t.owner}/${t.repo}/releases/tags/${t.tag}"

	## R-AP49 `roc_version`, CLI R-DI8.
	roc_version_url : Ingest.Target -> Str
	roc_version_url = |t| "https://raw.githubusercontent.com/${t.owner}/${t.repo}/${t.tag}/.roc-version"

	# ---- the pre-read (D1 call 1, R-AP41 "an optional read batch") ----

	## The release row of the label (form, version, version_text) of the target, if it has one, and if it has a `provenance` row with `via` = `ingest` (code 3, R-RE9).
	LabelRow : { release : Reads.ReleaseRow, has_ingest : Bool }

	## What to do after the pre-read (R-AP68 rows 4 and 7; Design Q156, Q157):
	## - `Conflict(problem)`: the label has another hash (R-PU19): 409 `label_conflict(target, Ok(<the other hash>))`. No GitHub read, no write.
	## - `Answer(release)`: the label has this hash and an `ingest` provenance row (R-PU14): 200 with the record. No GitHub read, no write.
	## - `AddProvenance(log_index)`: the label has this hash, and no `ingest` row: the visibility read (R-PU31), then a batch with the provenance row only (R-PU15), 200.
	## - `Index`: no row for the label: the whole flow.
	## A row that `Reads.release_of_row` refuses, or a hash that is not 32 bytes, is `Err(BadRow)` (500).
	after_read : Ingest.Target, List(Ingest.LabelRow) -> Try([Conflict(Problem), Answer(Release.Row), AddProvenance(U64), Index], [BadRow(Str)])
	after_read = |target, rows| match rows {
		[] => Ok(Index)
		[row, ..] => {
			hash = Reads.base58_of_bytes(row.release.hash)?
			if hash != target.hash {
				Ok(Conflict(label_conflict(target, Ok(hash))))
			} else if row.has_ingest {
				Ok(Answer(Reads.release_of_row(row.release)?))
			} else {
				Ok(AddProvenance(row.release.log_index))
			}
		}
	}

	# ---- the GitHub answers ----

	## `GET /repos/{owner}/{repo}` (R-PU31, R-TP5): `id`, `owner.id`, and `public` when `visibility` is `public` (R-PU32: `private` and `internal` are not).
	## A text that is not JSON, or with a member missing, is `Err(BadRepo)` (502). Unknown members are ignored.
	Repo : { id : U64, owner_id : U64, public : Bool }

	parse_repo : Str -> Try(Ingest.Repo, [BadRepo])
	parse_repo = |text| {
		raw : Try({ id : U64, owner : { id : U64 }, visibility : Str }, _)
		raw = Json.parse(text)
		match raw {
			Ok(r) => Ok({ id: r.id, owner_id: r.owner.id, public: r.visibility == "public" })
			Err(_) => Err(BadRepo)
		}
	}

	## `GET /repos/{owner}/{repo}/releases/tags/{tag}` (R-PU6): `draft`, `prerelease`, `published_at` (`Toolchains.parse_time`; `null` or missing is `Err(None)`),
	## and the `name` of each asset. A text that is not JSON, a missing `draft`, `prerelease` or `assets`, or a `published_at` text that `parse_time` refuses, is `Err(BadRelease)` (502).
	GithubRelease : { draft : Bool, prerelease : Bool, published_at : Try(U64, [None]), assets : List(Str) }

	parse_release : Str -> Try(Ingest.GithubRelease, [BadRelease])
	parse_release = |text| {
		full : Try({ draft : Bool, prerelease : Bool, published_at : Str, assets : List({ name : Str }) }, _)
		full = Json.parse(text)
		match full {
			Ok(r) => match Toolchains.parse_time(r.published_at) {
				Ok(ms) => Ok({ draft: r.draft, prerelease: r.prerelease, published_at: Ok(ms), assets: r.assets.map(|a| a.name) })
				Err(_) => Err(BadRelease)
			}
			Err(_) => {
				bare : Try({ draft : Bool, prerelease : Bool, assets : List({ name : Str }) }, _)
				bare = Json.parse(text.replace_each("\"published_at\":null", "\"published_at_null\":0").replace_each("\"published_at\": null", "\"published_at_null\":0"))
				match bare {
					Ok(r) => if (text.contains("\"published_at\"")) Ok({ draft: r.draft, prerelease: r.prerelease, published_at: Err(None), assets: r.assets.map(|a| a.name) }) else Err(BadRelease)
					Err(_) => Err(BadRelease)
				}
			}
		}
	}

	## R-PU6 with CLI R-DI3 and R-DI4. The first rule that fails gives the problem:
	## 1. `draft`: 422 `not_final(tag, "a draft")`. 2. `prerelease`: 422 `not_final(tag, "a prerelease")`.
	## 3. The package assets are the assets named `<b>.tar.zst` with `<b>` base58 of exactly 32 bytes (`x.tar.zst.intoto.jsonl`, `docs.tar.gz` are not).
	##    0 of them: 422 `no_package_asset`. 2 or more: 422 `many_package_assets(tag, count)`.
	## 4. The one package asset is not `<hash>.tar.zst` of the URL: 422 `other_asset(tag, name)`.
	## 5. `published_at` is `Err(None)`: 502 `github_bad("release")`.
	## The result is `published_at` in ms.
	candidate : Ingest.Target, Ingest.GithubRelease -> Try(U64, Problem)
	candidate = |t, r| {
		if r.draft {
			return Err(not_final(t.tag, "a draft"))
		}
		if r.prerelease {
			return Err(not_final(t.tag, "a prerelease"))
		}
		pkgs = r.assets.keep_if(is_package_asset)
		match pkgs {
			[] => Err(no_package_asset(t.tag))
			[one] =>
				if one != "${t.hash}.tar.zst" {
					Err(other_asset(t.tag, one))
				} else {
					match r.published_at {
						Ok(ms) => Ok(ms)
						Err(None) => Err(github_bad("release"))
					}
				}
			_ => Err(many_package_assets(t.tag, pkgs.len()))
		}
	}

	## The text of `.roc-version` at the tag (R-AP49): no white space at the ends.
	roc_version_of : Str -> Str
	roc_version_of = |text| text.trim()

	# ---- the write batch (D1 call 2, R-SG8, R-IK3, R-PU15, R-PU26, R-TP5) ----

	## One `names` row (R-IK3, R-RE22). `value`: the 32 hash bytes for kind 1 (bound as a blob), the UTF-8 bytes of the text for kinds 2 and 3 (bound as text).
	Name : { id : I64, kind : U8, value : List(U8) }

	## The rows of one ingest. Each id is a function of its name (R-IK2: `Id.name_id`). The batch writes them in the order of the slice file section 3.2.
	## - `names`: each name that a row of the plan refers to, once, sorted by `id`: the artifact hash, the platform hash (an app), each dep hash and each dep form
	##   (a dep with a version), the form of the release, the lower-case GitHub name.
	## - `new_targets`: the target names of the artifact with no code yet (`Code.target_code` gives `Err`), in the order of `artifact.target_names` (R-IK7).
	## - `artifact` (R-RE1): `kind` is the code (R-IK7), `exposes_json` the JSON array of the module names in header order (Q106-7), `platform_id` the id of `platform_hash`.
	## - `deps` (R-RE19): in the order of `artifact.deps` sorted by `alias`. `form` and `version` are `Err(None)` for a dep URL with no version.
	## - `target_names` (R-RE20): `artifact.target_names`, sorted.
	## - `leaf` (R-SG8 rows 1 and 2): `grp` the form, `version` `Semver.to_str`, `hash` the base58 hash, `time` the clock of the request.
	## - `release` (R-RE2): `repo` the id of `name`, `url` and `tag` of the target, `published_at` of GitHub. `yanked` 0, `withdrawn` NULL.
	## - `provenance_time` (R-PU15): `via` 3 (`ingest`), no claims, this time (the clock).
	## - `repo_row` (R-TP5): a new `repos` row, state `active` (0), no successor, `state_at` and `time` the clock. Not written when the row exists (slice 113 compares the ids, R-TP9).
	## - `check_row` (R-PU26, R-PU22): a new `repo_checks` row: `etag` and `checked_at` NULL, `next_check_at` = the clock + `Reads.interval_ms(Bool.False)` (1 h),
	##   `fail_count` 0, `app_installed` 0. Not written when the row exists.
	Plan : {
		names : List(Ingest.Name),
		new_targets : List(Str),
		artifact : { id : I64, kind : U8, exposes_json : Str, platform_id : Try(I64, [None]), roc_pin : Try(Str, [None]), size : U64 },
		deps : List({ alias : Str, dep : I64, form : Try(I64, [None]), version : Try(Version.Column, [None]), url : Str }),
		target_names : List(Str),
		leaf : { grp : Str, version : Str, hash : Str, time : U64 },
		release : { form : I64, column : Version.Column, artifact : I64, repo : I64, url : Str, tag : Str, roc_version : Try(Str, [None]), published_at : U64 },
		provenance_time : U64,
		repo_row : { repo : I64, repository_id : U64, repository_owner_id : U64, time : U64 },
		check_row : { repo : I64, next_check_at : U64 },
	}

	plan : { target : Ingest.Target, repo : Ingest.Repo, artifact : Artifact.Row, published_at : U64, roc_version : Try(Str, [None]), now_ms : U64 } -> Ingest.Plan
	plan = |input| {
		t = input.target
		a = input.artifact
		hash_bytes = b58(a.hash)
		art_id = Id.name_id(1, hash_bytes)
		form_id = Id.name_id(2, t.form.to_utf8())
		repo_id = Id.name_id(3, t.name.to_utf8())
		deps = a.deps.sort_with(|x, y| Artifact.compare(x.alias, y.alias))
		dep_names = deps.join_map(
			|d| match d.version {
				Ok(_) => [name_of(1, b58(d.hash)), name_of(2, d.group.to_utf8())]
				Err(None) => [name_of(1, b58(d.hash))]
			},
		)
		plat = match a.platform_hash {
			Ok(p) => [name_of(1, b58(p))]
			Err(None) => []
		}
		all = [name_of(1, hash_bytes)].concat(plat).concat(dep_names).concat([name_of(2, t.form.to_utf8()), name_of(3, t.name.to_utf8())])
		names = all.fold([], |acc, n| if (acc.any(|m| m.kind == n.kind and m.value == n.value)) acc else acc.append(n)).sort_with(|x, y| if (x.id < y.id) Before else if (x.id > y.id) After else Same)
		{
			names,
			new_targets: a.target_names.keep_if(|n| Code.target_code(n).is_err()),
			artifact: {
				id: art_id,
				kind: Code.kind_code(a.kind),
				exposes_json: Json.to_str(a.exposed),
				platform_id: a.platform_hash.map_ok(|p| Id.name_id(1, b58(p))),
				roc_pin: a.roc_pin,
				size: a.size,
			},
			deps: deps.map(
				|d| {
					alias: d.alias,
					dep: Id.name_id(1, b58(d.hash)),
					form: d.version.map_ok(|_| Id.name_id(2, d.group.to_utf8())),
					version: match d.version {
						Ok(text) => match Semver.parse(text) {
							Ok(v) => Ok(Version.column(v))
							Err(_) => Err(None)
						}
						Err(None) => Err(None)
					},
					url: d.url,
				},
			),
			target_names: a.target_names.sort_with(Artifact.compare),
			leaf: { grp: t.form, version: t.version.to_str(), hash: t.hash, time: input.now_ms },
			release: { form: form_id, column: t.column, artifact: art_id, repo: repo_id, url: t.url, tag: t.tag, roc_version: input.roc_version, published_at: input.published_at },
			provenance_time: input.now_ms,
			repo_row: { repo: repo_id, repository_id: input.repo.id, repository_owner_id: input.repo.owner_id, time: input.now_ms },
			check_row: { repo: repo_id, next_check_at: input.now_ms + Reads.interval_ms(Bool.False) },
		}
	}

	name_of : U8, List(U8) -> Ingest.Name
	name_of = |kind, value| { id: Id.name_id(kind, value), kind, value }

	# ---- the batch result ----

	## The constraint failure of `D1.batch!` (the platform `Sql.Constraint`, the same shape: lib/ has no platform import).
	Constraint : { kind : [PrimaryKey, Unique, ForeignKey, Check, NotNull, Trigger, Datatype, Other], message : Str }

	## `Trigger` with the message `label-conflict` (R-SG8 row 4, Q27): `LabelConflict` (409, `label_conflict(target, Err(None))`, R-AP68 row 11, Design Q164).
	## `PrimaryKey` with the message `UNIQUE constraint failed: names.id` (R-IK3): `IdCollision` (D1 call 3, then `collision`).
	## Each other failure (also `leaf-missing`, R-SG8 row 7, and a `PrimaryKey` of another table): `Fault` (500).
	batch_failure : Ingest.Constraint -> [LabelConflict, IdCollision, Fault]
	batch_failure = |c| match c.kind {
		Trigger if c.message == "label-conflict" => LabelConflict
		PrimaryKey if c.message == "UNIQUE constraint failed: names.id" => IdCollision
		_ => Fault
	}

	## One row of the detail read of R-IK3: `SELECT CAST(id AS TEXT) AS id, kind, CAST(value AS BLOB) AS value FROM names WHERE id IN (...)` with the ids of `plan.names`.
	NameRow : { id : Str, kind : I64, value : List(U8) }

	## R-IK3: the first name of `names` (in its order) for which a row has the same id and another (kind, value) gives 409 `id_collision(new, other)`.
	## A name is shown as text: kind 1 as base58, kinds 2 and 3 as UTF-8. With no such row (it cannot be), 409 `id_collision_unknown`.
	collision : List(Ingest.Name), List(Ingest.NameRow) -> Problem
	collision = |names, rows| {
		found = names.fold_until(
			Err(None),
			|_, n| {
				id = n.id.to_str()
				match rows.find_first(|r| r.id == id and !(r.kind == n.kind.to_i64() and r.value == n.value)) {
					Ok(r) => Break(Ok(id_collision((n.kind, text_of(n.kind, n.value)), (r.kind.to_u8_wrap(), text_of(r.kind.to_u8_wrap(), r.value)), id)))
					Err(_) => Continue(Err(None))
				}
			},
		)
		found ?? id_collision_unknown
	}

	text_of : U8, List(U8) -> Str
	text_of = |kind, bytes| if (kind == 1) Base58.encode(bytes) else Str.from_utf8(bytes) ?? "?"

	## R-AP8: 201 when the `releases` statement of the batch has `changes` above 0, else 200 (another request wrote the label between the 2 calls, as Q109-6).
	status_of : U64 -> U16
	status_of = |changes| if (changes > 0) 201 else 200

	## The body of a 200 or 201 answer (R-AP8, TW24 proposal): `{"release":<Release.encode of the record>}`, no white space.
	answer_body : Release.Row -> Str
	answer_body = |release| "{\"release\":${Release.encode(release)}}"

	## R-AP8: the `Location` of a 201 answer.
	location : Str -> Str
	location = |hash| "/v1/artifacts/${hash}"

	## R-AP9: the `Cache-Control` of a 200 and a 201 answer.
	cache_control : Str
	cache_control = "no-store"

	# ---- the problems (R-AP21; the texts are proposals, slice file section 5) ----

	bad_body : Str -> Problem
	bad_body = |why| Problem.new(BadRequest, "the body must be a JSON object with the member url (text): ${why}")

	compat_needs_token : Problem
	compat_needs_token = Problem.new(Unauthenticated, "a body with compat needs a GitHub OIDC token (tln publish)")

	not_release_url : Str -> Problem
	not_release_url = |url| Problem.new(NotACandidate, "the url is not a GitHub release asset URL with a version and a hash (https://github.com/<owner>/<repo>/releases/download/<tag>/<hash>.tar.zst): ${url}")

	## R-PU32: the design gives this `detail`.
	not_public : Problem
	not_public = Problem.new(NotACandidate, "repository not found or not public")

	no_release : Str -> Problem
	no_release = |tag| Problem.new(NotACandidate, "the repository has no published release with the tag ${tag}")

	not_final : Str, Str -> Problem
	not_final = |tag, what| Problem.new(NotACandidate, "the release ${tag} is ${what}")

	no_package_asset : Str -> Problem
	no_package_asset = |tag| Problem.new(NotACandidate, "the release ${tag} has no package asset <hash>.tar.zst")

	many_package_assets : Str, U64 -> Problem
	many_package_assets = |tag, n| Problem.new(NotACandidate, "the release ${tag} has ${n.to_str()} package assets <hash>.tar.zst, not 1")

	other_asset : Str, Str -> Problem
	other_asset = |tag, name| Problem.new(NotACandidate, "the package asset of the release ${tag} is ${name}, not the asset of the url")

	## R-PU19: the detail says to release a new version. `other` is the hash in the index when the pre-read saw it, `Err(None)` after a race (R-AP68, Design Q164).
	label_conflict : Ingest.Target, Try(Str, [None]) -> Problem
	label_conflict = |t, other| {
		seen : Str
		seen = match other {
			Ok(h) => Str.concat("the hash ", h)
			Err(None) => "another hash"
		}
		Problem.new(LabelConflict, "the label ${t.form} ${t.version.to_str()} has ${seen} in the index, not ${t.hash}: release a new version")
	}

	## R-IK3: `new` and `other` are (kind, text). Kind words: 1 `hash`, 2 `group`, 3 `repository`.
	id_collision : (U8, Str), (U8, Str), Str -> Problem
	id_collision = |(nk, new), (ok, other), id| Problem.new(IdCollision, "the ${kind_word(nk)} ${new} has the id ${id} of the ${kind_word(ok)} ${other} in the index")

	id_collision_unknown : Problem
	id_collision_unknown = Problem.new(IdCollision, "a name of the release has the id of another name in the index")

	kind_word : U8 -> Str
	kind_word = |k| match k {
		1 => "hash"
		2 => "group"
		_ => "repository"
	}

	## 502 `upstream`: `what` is `repository`, `release` or `.roc-version`.
	github_status : Str, U16 -> Problem
	github_status = |what, status| Problem.new(Upstream, "the GitHub ${what} read failed with status ${status.to_str()}")

	github_no_answer : Str -> Problem
	github_no_answer = |what| Problem.new(Upstream, "the GitHub ${what} read failed: no answer")

	github_bad : Str -> Problem
	github_bad = |what| Problem.new(Upstream, "the GitHub ${what} answer is not valid")
}
