# Slice 106 code step: replace the `crash "todo"` stubs of worker/lib/Reads.roc by the bodies below.
import re, sys
path = sys.argv[1]
src = open(path).read()
bodies = {}
def b(name, text): bodies[name] = text

b("artifact_id", '''artifact_id = |hash| match Base58.decode(hash) {
		Ok(bytes) => if (bytes.len() == 32) Ok(Id.name_id(1, bytes)) else Err(BadHash)
		Err(_) => Err(BadHash)
	}''')
b("form_id", 'form_id = |form| Id.name_id(2, form.to_utf8())')
b("repo_id", 'repo_id = |owner, repo| Id.name_id(3, "${owner}/${repo}".with_ascii_lowercased().to_utf8())')
b("parse_query", '''parse_query = |q| match q.group {
		Err(NotFound) => match q.after {
			Err(NotFound) => Err(bad_request("GET /v1/releases needs the query parameter group or after"))
			Ok(text) => after_value(text).map_ok(|n| ByAfter(n))
		}
		Ok(group) => if (group == "") {
			Err(bad_request("the query parameter group must not be empty"))
		} else {
			after : Try(U64, [None])
			after = match q.after {
				Err(NotFound) => Err(None)
				Ok(text) => Ok(after_value(text)?)
			}
			series = match q.series {
				Err(NotFound) => Ok(Err(None))
				Ok(text) => match Version.series_bounds(text) {
					Ok(_) => Ok(Ok(text))
					Err(BadSeries) => Err(bad_request("the query parameter series must be a series (M or 0.m), got ${text}"))
				}
			}?
			Ok(ByGroup({ group, series, after }))
		}
	}''')
b("etag_of", '''etag_of = |body| {
		hex = Crypto.SHA256.hash(body).to_hex()
		"\\"${Str.from_utf8_lossy(hex.to_utf8().take_first(32))}\\""
	}''')
b("etag_matches", '''etag_matches = |if_none_match, etag| {
		value = if_none_match.trim()
		if value == "*" {
			Bool.True
		} else {
			value.split_on(",").any(|item| strong_part(item.trim()) == etag)
		}
	}''')
b("bypass_cache", '''bypass_cache = |h| has_no_cache(h.cache_control) or has_no_cache(h.pragma)''')
b("session_of", '''session_of = |bookmark| match bookmark {
		Ok(text) => if (text.trim() == "") Any else After(text.trim())
		Err(NotFound) => Any
	}''')
b("interval_ms", 'interval_ms = |app_installed| if (app_installed) 86_400_000 else 3_600_000')
b("stale", '''stale = |c| match c.checked_at {
		Err(None) => Bool.True
		Ok(at) => c.now_ms > at and c.now_ms - at > 2 * interval_ms(c.app_installed)
	}''')
b("checked_of_row", '''checked_of_row = |row, now_ms| {
		checked_at = row.checked_at.map_err(|_| None)
		{ name: row.name, checked_at, stale: stale({ checked_at, app_installed: row.app_installed, now_ms }) }
	}''')
b("repo_item_of_row", '''repo_item_of_row = |row| {
		state = match row.state {
			0 => Ok(Active)
			1 => Ok(Missing)
			2 => Ok(Moved)
			other => Err(BadRow("repo ${row.name}: the state code ${I64.to_str(other)} is not known"))
		}?
		Ok({ name: row.name, state, successor: row.successor.map_err(|_| None), state_at: row.state_at })
	}''')
b("release_of_row", '''release_of_row = |row| {
		hash = base58_of_hex(row.hash)?
		version = Version.read({ version: row.version, version_text: row.version_text }).map_err(|_| BadRow("release ${U64.to_str(row.log_index)}: the version column is not valid"))?
		Ok({
			log_index: row.log_index,
			hash,
			group: row.form,
			series: Version.series_of(version),
			version: version.to_str(),
			url: row.url,
			tag: row.tag.map_err(|_| None),
			roc_version: row.roc_version.map_err(|_| None),
			repo: row.repo.map_err(|_| None),
			published_at: row.published_at,
			yanked: row.yanked,
			yank_reason: Err(None),
			withdrawn: row.withdrawn.map_err(|_| None),
		})
	}''')
b("artifact_of_rows", '''artifact_of_rows = |rows| {
		row = rows.artifact
		hash = base58_of_hex(row.hash)?
		kind = match row.kind {
			0 => Ok(App)
			1 => Ok(Package)
			2 => Ok(Platform)
			other => Err(BadRow("artifact ${hash}: the kind code ${I64.to_str(other)} is not known"))
		}?
		exposed : Try(List(Str), _)
		exposed = Json.parse(row.exposed_json)
		platform_hash = match row.platform_hash {
			Ok(text) => Ok(base58_of_hex(text)?)
			Err(Missing) => Err(None)
		}
		deps = rows.deps.map_try(dep_of_row)?
		Ok({
			hash,
			kind,
			exposed: exposed.map_err(|_| BadRow("artifact ${hash}: exposes is not a JSON array of text"))?,
			platform_hash,
			roc_pin: row.roc_pin.map_err(|_| None),
			size: row.size,
			deps,
			target_names: rows.target_names,
		})
	}''')
b("releases_body", '''releases_body = |a| {
		checked = match a.checked {
			Ok(item) => Closure.encode_checked(item)
			Err(None) => "null"
		}
		"{\\"releases\\":[${releases_json(a.releases)}],\\"checked\\":${checked},\\"repos\\":[${repos_json(a.repos)}]}"
	}''')
b("page_body", '''page_body = |a| "{\\"releases\\":[${releases_json(a.releases)}],\\"repos\\":[${repos_json(a.repos)}]}"''')
b("artifact_body", '''artifact_body = |a| "{\\"artifact\\":${Artifact.encode(a.artifact)},\\"releases\\":[${releases_json(a.releases)}],\\"repos\\":[${repos_json(a.repos)}]}"''')
b("no_repo_releases", 'no_repo_releases = |owner, repo| Problem.new(NotFound, "no indexed release for ${owner}/${repo}")')
b("no_artifact", 'no_artifact = |hash| Problem.new(NotFound, "no artifact ${hash}")')

for name, body in bodies.items():
    pat = re.compile(r'^\t' + re.escape(name) + r' = \|[^|]*\| crash "todo"$', re.M)
    if not pat.search(src):
        sys.exit("stub not found: " + name)
    src = pat.sub(lambda m: "\t" + body.replace("\\", "\\\\") if False else "\t" + body, src, count=1)

helpers = '''
	# ---- helpers (private use) ----

	bad_request : Str -> Problem
	bad_request = |detail| Problem.new(BadRequest, detail)

	max_after : U64
	max_after = 9223372036854775807

	## R-AP56: decimal digits, no leading zero (only `0` itself), at most 2^63 - 1.
	after_value : Str -> Try(U64, Problem)
	after_value = |text| {
		bytes = text.to_utf8()
		digits = !bytes.is_empty() and bytes.all(|b| b >= '0' and b <= '9')
		plain = bytes.len() == 1 or bytes.first() != Ok('0')
		number = if (digits and plain) U64.from_str(text).map_err(|_| BadNumber) else Err(BadNumber)
		match number {
			Ok(n) if n <= max_after => Ok(n)
			_ => Err(bad_request("the query parameter after must be a log index (decimal digits), got ${text}"))
		}
	}

	## The tag of an entity tag with the weak mark `W/` cut (RFC 9110 13.1.2 weak comparison).
	strong_part : Str -> Str
	strong_part = |tag| tag.drop_prefix("W/")

	## R-AP55: the directive `no-cache` in a comma separated list, no case, white space around a directive ignored.
	has_no_cache : Try(Str, [NotFound]) -> Bool
	has_no_cache = |header| match header {
		Ok(text) => text.split_on(",").any(|item| item.trim().caseless_ascii_equals("no-cache"))
		Err(NotFound) => Bool.False
	}

	## 64 hex digits (any case) become the base58 text of 32 bytes.
	base58_of_hex : Str -> Try(Str, [BadRow(Str)])
	base58_of_hex = |hex| match Crypto.SHA256.Digest.from_hex(hex) {
		Ok(digest) => Ok(Base58.encode(digest.to_bytes()))
		Err(_) => Err(BadRow("the hash ${hex} is not 32 bytes in hex"))
	}

	## R-AP49: one dep. With a `form`, its group is `form`. Without one, the group is made from `url`.
	dep_of_row : Reads.DepRow -> Try(Artifact.Dep, [BadRow(Str)])
	dep_of_row = |dep| {
		hash = base58_of_hex(dep.hash)?
		column = match dep.version {
			Ok(version) => Ok(Version.read({ version, version_text: dep.version_text ?? "" }))
			Err(Missing) => Err(None)
		}
		version = match column {
			Ok(read) => Ok(read.map_err(|_| BadRow("dep ${dep.alias}: the version column is not valid"))?)
			Err(None) => Err(None)
		}
		Ok({
			alias: dep.alias,
			hash,
			group: match dep.form {
				Ok(form) => form
				Err(Missing) => group_of_url(dep.url)
			},
			series: version.map_ok(Version.series_of),
			version: version.map_ok(|v| v.to_str()),
			url: dep.url,
		})
	}

	## R-AP49 (Q106-8): the URL with no scheme and no last segment.
	group_of_url : Str -> Str
	group_of_url = |url| {
		rest = match url.split_on("://") {
			[_, .. as after] => Str.join_with(after, "://")
			_ => url
		}
		"${Str.join_with(rest.split_on("/").drop_last(1), "/")}/"
	}

	releases_json : List(Release.Row) -> Str
	releases_json = |releases| Str.join_with(releases.map(Release.encode), ",")

	## R-AP53: `repos` sorted by `name` (bytes).
	repos_json : List(Reads.RepoItem) -> Str
	repos_json = |repos| Str.join_with(repos.sort_with(|a, b| Artifact.compare(a.name, b.name)).map(Closure.encode_repo), ",")
'''
# put the helpers before the closing brace of the type
idx = src.rstrip().rfind("}")
src = src[:idx].rstrip("\n") + "\n" + helpers + "}\n"
src = src.replace("import records.Release\nimport Problem\n", "import base58.Base58\nimport records.Id\nimport records.Release\nimport semver.Semver\nimport Problem\nimport Version\n")
open(path, "w").write(src)
