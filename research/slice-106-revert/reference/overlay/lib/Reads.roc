## PRIVATE REFERENCE of slice 106 (test agent). The code agent does not read it (TW18).
import base58.Base58
import records.Artifact
import records.Closure
import records.Code
import records.Id
import records.Release
import Problem
import Version

Reads :: [].{
	page_limit : U64
	page_limit = 1000

	cache_control : Str
	cache_control = "max-age=60"

	artifact_id : Str -> Try(I64, [BadHash])
	artifact_id = |hash| match Base58.decode(hash) {
		Ok(bytes) => if (bytes.len() == 32) Ok(Id.name_id(1, bytes)) else Err(BadHash)
		Err(_) => Err(BadHash)
	}

	form_id : Str -> I64
	form_id = |form| Id.name_id(2, form.to_utf8())

	repo_id : Str, Str -> I64
	repo_id = |owner, repo| Id.name_id(3, "${owner}/${repo}".with_ascii_lowercased().to_utf8())

	QueryInput : { group : Try(Str, [NotFound]), series : Try(Str, [NotFound]), after : Try(Str, [NotFound]) }

	Query : [ByGroup({ group : Str, series : Try(Str, [None]), after : Try(U64, [None]) }), ByAfter(U64)]

	number : Str -> Try(U64, [BadNumber])
	number = |t| {
		digits = t != "" and t.to_utf8().all(|b| b >= 48 and b <= 57) and (t == "0" or !t.starts_with("0"))
		if (digits) {
			n = U64.from_str(t).map_err(|_| BadNumber)?
			if (n <= 9223372036854775807) Ok(n) else Err(BadNumber)
		} else {
			Err(BadNumber)
		}
	}

	bad : Str -> Problem
	bad = |detail| Problem.new(BadRequest, detail)

	parse_query : Reads.QueryInput -> Try(Reads.Query, Problem)
	parse_query = |q| {
		if q.group == Err(NotFound) and q.after == Err(NotFound) {
			return Err(bad("GET /v1/releases needs the query parameter group or after"))
		}
		if q.group == Ok("") {
			return Err(bad("the query parameter group must not be empty"))
		}
		after = match q.after {
			Err(NotFound) => Err(None)
			Ok(t) => match number(t) {
				Ok(n) => Ok(n)
				Err(_) => return Err(bad("the query parameter after must be a log index (decimal digits), got ${t}"))
			}
		}
		match q.group {
			Err(NotFound) => match after {
				Ok(n) => Ok(ByAfter(n))
				Err(_) => Err(bad("GET /v1/releases needs the query parameter group or after"))
			}
			Ok(g) => {
				series = match q.series {
					Err(NotFound) => Err(None)
					Ok(s) => match Version.series_bounds(s) {
						Ok(_) => Ok(s)
						Err(_) => return Err(bad("the query parameter series must be a series (M or 0.m), got ${s}"))
					}
				}
				Ok(ByGroup({ group: g, series, after }))
			}
		}
	}

	hex_digits : List(U8)
	hex_digits = "0123456789abcdef".to_utf8()

	hex_byte : U8 -> List(U8)
	hex_byte = |b| [hex_digits.get((b // 16).to_u64()) ?? 48, hex_digits.get((b % 16).to_u64()) ?? 48]

	etag_of : List(U8) -> Str
	etag_of = |body| {
		digest = Crypto.SHA256.hash(body).to_bytes()
		hex = digest.take_first(16).join_map(hex_byte)
		"\"${Str.from_utf8_lossy(hex)}\""
	}

	etag_matches : Str, Str -> Bool
	etag_matches = |if_none_match, etag| {
		v = if_none_match.trim()
		if v == "*" {
			Bool.True
		} else {
			v.split_on(",").any(
				|piece| {
					t = piece.trim()
					tag = if (t.starts_with("W/")) t.drop_prefix("W/") else t
					tag == etag
				},
			)
		}
	}

	has_no_cache : Try(Str, [NotFound]) -> Bool
	has_no_cache = |h| match h {
		Ok(v) => v.split_on(",").any(|d| d.trim().caseless_ascii_equals("no-cache"))
		Err(_) => Bool.False
	}

	bypass_cache : { cache_control : Try(Str, [NotFound]), pragma : Try(Str, [NotFound]) } -> Bool
	bypass_cache = |h| has_no_cache(h.cache_control) or has_no_cache(h.pragma)

	session_of : Try(Str, [NotFound]) -> [Any, After(Str)]
	session_of = |bookmark| match bookmark {
		Ok(v) => if (v.trim() == "") Any else After(v.trim())
		Err(_) => Any
	}

	interval_ms : Bool -> U64
	interval_ms = |app_installed| if (app_installed) 86400000 else 3600000

	stale : { checked_at : Try(U64, [None]), app_installed : Bool, now_ms : U64 } -> Bool
	stale = |c| match c.checked_at {
		Err(_) => Bool.True
		Ok(at) => c.now_ms > at and c.now_ms - at > 2 * interval_ms(c.app_installed)
	}

	CheckRow : { name : Str, checked_at : Try(U64, [Missing]), app_installed : Bool }

	CheckedItem : Closure.Checked

	opt : Try(a, [Missing]) -> Try(a, [None])
	opt = |t| match t {
		Ok(v) => Ok(v)
		Err(_) => Err(None)
	}

	checked_of_row : Reads.CheckRow, U64 -> Reads.CheckedItem
	checked_of_row = |row, now_ms| {
		at = opt(row.checked_at)
		{ name: row.name, checked_at: at, stale: stale({ checked_at: at, app_installed: row.app_installed, now_ms }) }
	}

	RepoRow : { name : Str, state : I64, successor : Try(Str, [Missing]), state_at : U64 }

	RepoItem : Closure.Repo

	repo_item_of_row : Reads.RepoRow -> Try(Reads.RepoItem, [BadRow(Str)])
	repo_item_of_row = |row| {
		state = match row.state {
			0 => Ok(Active)
			1 => Ok(Missing)
			2 => Ok(Moved)
			n => Err(BadRow("repos.state ${n.to_str()}"))
		}?
		Ok({ name: row.name, state, successor: opt(row.successor), state_at: row.state_at })
	}

	ReleaseRow : {
		log_index : U64,
		hash : List(U8),
		form : Str,
		version : Str,
		version_text : Str,
		url : Str,
		tag : Try(Str, [Missing]),
		roc_version : Try(Str, [Missing]),
		repo : Try(Str, [Missing]),
		published_at : U64,
		yanked : Bool,
		withdrawn : Try(Str, [Missing]),
	}

	hash_text : List(U8), Str -> Try(Str, [BadRow(Str)])
	hash_text = |bytes, what| if (bytes.len() == 32) Ok(Base58.encode(bytes)) else Err(BadRow("${what}: a hash has ${bytes.len().to_str()} bytes"))

	release_of_row : Reads.ReleaseRow -> Try(Release.Row, [BadRow(Str)])
	release_of_row = |row| {
		hash = hash_text(row.hash, "release ${row.log_index.to_str()}")?
		v = Version.read({ version: row.version, version_text: row.version_text }).map_err(|_| BadRow("release ${row.log_index.to_str()}: bad version columns"))?
		Ok(
			{
				log_index: row.log_index,
				hash,
				group: row.form,
				series: Version.series_of(v),
				version: v.to_str(),
				url: row.url,
				tag: opt(row.tag),
				roc_version: opt(row.roc_version),
				repo: opt(row.repo),
				published_at: row.published_at,
				yanked: row.yanked,
				yank_reason: Err(None),
				withdrawn: opt(row.withdrawn),
			},
		)
	}

	ArtifactRow : { hash : List(U8), kind : I64, exposed_json : Str, platform_hash : Try(List(U8), [Missing]), roc_pin : Try(Str, [Missing]), size : U64 }

	DepRow : { alias : Str, hash : List(U8), form : Try(Str, [Missing]), version : Try(Str, [Missing]), version_text : Try(Str, [Missing]), url : Str }

	no_version_group : Str -> Str
	no_version_group = |url| {
		bare = if (url.starts_with("https://")) url.drop_prefix("https://") else url.drop_prefix("http://")
		"${Str.join_with(bare.split_on("/").drop_last(1), "/")}/"
	}

	dep_of_row : Reads.DepRow -> Try(Artifact.Dep, [BadRow(Str)])
	dep_of_row = |d| {
		hash = hash_text(d.hash, "dep ${d.alias}")?
		group = d.form ?? no_version_group(d.url)
		match d.version {
			Err(_) => Ok({ alias: d.alias, hash, group, series: Err(None), version: Err(None), url: d.url })
			Ok(vs) => {
				v = Version.read({ version: vs, version_text: d.version_text ?? "" }).map_err(|_| BadRow("dep ${d.alias}: bad version columns"))?
				Ok({ alias: d.alias, hash, group, series: Ok(Version.series_of(v)), version: Ok(v.to_str()), url: d.url })
			}
		}
	}

	artifact_of_rows : { artifact : Reads.ArtifactRow, deps : List(Reads.DepRow), target_names : List(Str) } -> Try(Artifact.Row, [BadRow(Str)])
	artifact_of_rows = |rows| {
		a = rows.artifact
		hash = hash_text(a.hash, "artifact")?
		kind = a.kind.to_u8_try().map_err(|_| BadRow("artifact kind")).on_err(|e| Err(e))?
		code = Code.kind_from_code(kind).map_err(|_| BadRow("artifact kind"))?
		exposed : Try(List(Str), _)
		exposed = Json.parse(a.exposed_json)
		exposed_list = exposed.map_err(|_| BadRow("artifact exposes"))?
		platform_hash = match a.platform_hash {
			Ok(b) => Ok(hash_text(b, "platform")?)
			Err(_) => Err(None)
		}
		deps = rows.deps.map_try(dep_of_row)?
		Ok({ hash, kind: code, exposed: exposed_list, platform_hash, roc_pin: opt(a.roc_pin), size: a.size, deps, target_names: rows.target_names })
	}

	repos_json : List(Reads.RepoItem) -> Str
	repos_json = |repos| Str.join_with(repos.sort_with(|a, b| Artifact.compare(a.name, b.name)).map(Closure.encode_repo), ",")

	releases_json : List(Release.Row) -> Str
	releases_json = |rs| Str.join_with(rs.map(Release.encode), ",")

	releases_body : { releases : List(Release.Row), checked : Try(Reads.CheckedItem, [None]), repos : List(Reads.RepoItem) } -> Str
	releases_body = |a| {
		checked = match a.checked {
			Ok(c) => Closure.encode_checked(c)
			Err(_) => "null"
		}
		"{\"releases\":[${releases_json(a.releases)}],\"checked\":${checked},\"repos\":[${repos_json(a.repos)}]}"
	}

	page_body : { releases : List(Release.Row), repos : List(Reads.RepoItem) } -> Str
	page_body = |a| "{\"releases\":[${releases_json(a.releases)}],\"repos\":[${repos_json(a.repos)}]}"

	artifact_body : { artifact : Artifact.Row, releases : List(Release.Row), repos : List(Reads.RepoItem) } -> Str
	artifact_body = |a| "{\"artifact\":${Artifact.encode(a.artifact)},\"releases\":[${releases_json(a.releases)}],\"repos\":[${repos_json(a.repos)}]}"

	no_repo_releases : Str, Str -> Problem
	no_repo_releases = |owner, repo| Problem.new(NotFound, "no indexed release for ${owner}/${repo}")

	no_artifact : Str -> Problem
	no_artifact = |hash| Problem.new(NotFound, "no artifact ${hash}")
}
