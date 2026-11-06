import Problem

Toolchains :: [].{

	page_limit : U64
	page_limit = 1000

	cache_control : Str
	cache_control = "max-age=300"

	host_targets : List(Str)
	host_targets = ["linux_arm64", "linux_x86_64", "macos_apple_silicon", "macos_x86_64", "windows_arm64", "windows_x86_64"]

	archive_suffix : Str -> Str
	archive_suffix = |target| if (target.starts_with("windows_")) ".zip" else ".tar.gz"

	release_url : Str -> Str
	release_url = |tag| "https://api.github.com/repos/roc-lang/nightlies/releases/tags/${tag}"

	Asset : { name : Str, digest : Try(Str, [Missing]) }

	Release : { draft : Bool, prerelease : Bool, published_at : U64, assets : List(Toolchains.Asset) }

	all_digits : Str, U64 -> Try(U64, [BadTime])
	all_digits = |text, len| {
		bytes = text.to_utf8()
		if bytes.len() == len and bytes.all(|b| b >= 48 and b <= 57) {
			U64.from_str(text).map_err(|_| BadTime)
		} else {
			Err(BadTime)
		}
	}

	is_leap : U64 -> Bool
	is_leap = |y| (y % 4 == 0 and y % 100 != 0) or y % 400 == 0

	days_in_month : U64, U64 -> U64
	days_in_month = |y, m| match m {
		2 => if (is_leap(y)) 29 else 28
		4 | 6 | 9 | 11 => 30
		_ => 31
	}

	## Days from 1970-01-01 (Hinnant), for y >= 1970.
	days_from_civil : U64, U64, U64 -> U64
	days_from_civil = |y0, m, d| {
		y = if (m <= 2) y0 - 1 else y0
		era = y // 400
		yoe = y - era * 400
		mp = if (m > 2) m - 3 else m + 9
		doy = (153 * mp + 2) // 5 + d - 1
		doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
		era * 146097 + doe - 719468
	}

	parse_time : Str -> Try(U64, [BadTime])
	parse_time = |text| match text.split_on("T") {
		[date, time] => {
			if !time.ends_with("Z") {
				Err(BadTime)
			} else {
				clock = time.drop_suffix("Z")
				match (date.split_on("-"), clock.split_on(":")) {
					([ys, ms, ds], [hs, mis, ss]) => {
						y = all_digits(ys, 4)?
						m = all_digits(ms, 2)?
						d = all_digits(ds, 2)?
						h = all_digits(hs, 2)?
						mi = all_digits(mis, 2)?
						s = all_digits(ss, 2)?
						if y < 1970 or m < 1 or m > 12 or d < 1 or d > days_in_month(y, m) or h > 23 or mi > 59 or s > 59 {
							Err(BadTime)
						} else {
							days = days_from_civil(y, m, d)
							Ok(((days * 86400 + h * 3600 + mi * 60 + s) * 1000))
						}
					}
					_ => Err(BadTime)
				}
			}
		}
		_ => Err(BadTime)
	}

	RawAsset : { name : Try(Str, [Missing]), digest : Try(Str, [Missing]) }

	RawRelease : { draft : Try(Bool, [Missing]), prerelease : Try(Bool, [Missing]), published_at : Try(Str, [Missing]), assets : Try(List(Toolchains.RawAsset), [Missing]) }

	parse_release : Str -> Try(Toolchains.Release, [BadRelease])
	parse_release = |text| {
		cleaned = text.replace_each("\"digest\":null", "\"digest_null\":0").replace_each("\"digest\": null", "\"digest_null\":0")
		raw : Try(Toolchains.RawRelease, _)
		raw = Json.parse(cleaned)
		match raw {
			Err(_) => Err(BadRelease)
			Ok(r) => match (r.published_at, r.assets) {
				(Ok(when), Ok(assets)) => match parse_time(when) {
					Err(_) => Err(BadRelease)
					Ok(ms) => {
						named = assets.map_try(|a| match a.name {
							Ok(name) => Ok({ name, digest: a.digest })
							Err(Missing) => Err(BadRelease)
						})?
						Ok({ draft: r.draft ?? Bool.False, prerelease: r.prerelease ?? Bool.False, published_at: ms, assets: named })
					}
				}
				_ => Err(BadRelease)
			}
		}
	}

	Picked : { target : Str, asset_name : Str, sha256 : Str }

	safe_part : Str -> Bool
	safe_part = |name| name != "" and name != "." and name != ".." and !name.contains("/") and !name.contains("\\") and !name.to_utf8().contains(0)

	counts : Toolchains.Asset, Str -> Bool
	counts = |asset, target| asset.name.starts_with("roc_nightly-${target}-") and asset.name.ends_with(archive_suffix(target)) and safe_part(asset.name)

	valid_digest : Try(Str, [Missing]) -> Try(Str, [Bad])
	valid_digest = |dg| match dg {
		Ok(d) if d.starts_with("sha256:") => {
			hex = d.drop_prefix("sha256:")
			if hex.to_utf8().len() == 64 and hex.to_utf8().all(|b| (b >= 48 and b <= 57) or (b >= 97 and b <= 102)) Ok(hex) else Err(Bad)
		}
		_ => Err(Bad)
	}

	select_assets : List(Toolchains.Asset) -> List(Toolchains.Picked)
	select_assets = |assets| host_targets.keep_oks(|target| match assets.keep_if(|a| counts(a, target) and valid_digest(a.digest) != Err(Bad)) {
		[one] => match valid_digest(one.digest) {
			Ok(hex) => Ok({ target, asset_name: one.name, sha256: hex })
			Err(_) => Err(NoDigest)
		}
		_ => Err(NotOne)
	})

	Leaf : { grp : Str, version : Str, hash : Str, time : U64 }

	leaf_of : { target : Str, tag : Str, sha256 : Str, now_ms : U64 } -> Toolchains.Leaf
	leaf_of = |a| { grp: "roc-lang/nightlies:${a.target}", version: a.tag, hash: "sha256:${a.sha256}", time: a.now_ms }

	Write : { nightly : I64, tag : Str, target : Str, asset_name : Str, sha256 : Str, published_at : U64, leaf : Toolchains.Leaf }

	writes_of : { tag : Str, nightly : I64, published_at : U64, now_ms : U64, picked : List(Toolchains.Picked) } -> List(Toolchains.Write)
	writes_of = |a| a.picked.map(|p| {
		nightly: a.nightly,
		tag: a.tag,
		target: p.target,
		asset_name: p.asset_name,
		sha256: p.sha256,
		published_at: a.published_at,
		leaf: leaf_of({ target: p.target, tag: a.tag, sha256: p.sha256, now_ms: a.now_ms }),
	})

	Row : { tag : Str, target : Str, asset_name : Str, sha256 : Str, published_at : U64, log_index : U64 }

	start : Str, Try(I64, [NotANightly]) -> [Refuse(Problem), ReadRows(I64)]
	start = |tag, id| match id {
		Ok(n) => ReadRows(n)
		Err(NotANightly) => Refuse(not_nightly(tag))
	}

	after_rows : Str, List(Toolchains.Row) -> [Answer(List(Toolchains.Row)), Refuse(Problem), ReadGithub]
	after_rows = |tag, rows| if (rows.is_empty()) {
		ReadGithub
	} else {
		match rows.find_first(|r| r.tag != tag) {
			Ok(r) => Refuse(id_taken(tag, r.tag))
			Err(_) => Answer(rows)
		}
	}

	candidates : Str, Toolchains.Release -> Try(List(Toolchains.Picked), Problem)
	candidates = |tag, release| if (release.draft or release.prerelease) {
		Err(not_final(tag))
	} else {
		picked = select_assets(release.assets)
		if picked.is_empty() Err(no_candidate(tag)) else Ok(picked)
	}

	put_status : List(U64) -> U16
	put_status = |changes| if (changes.any(|c| c > 0)) 201 else 200

	QueryInput : { after : Try(Str, [NotFound]), target : Try(Str, [NotFound]) }

	Query : { after : U64, target : Try(Str, [None]) }

	parse_query : Toolchains.QueryInput -> Try(Toolchains.Query, Problem)
	parse_query = |q| {
		after = match q.after {
			Err(NotFound) => Ok(0)
			Ok(text) => {
				bytes = text.to_utf8()
				if !bytes.is_empty() and bytes.all(|b| b >= 48 and b <= 57) and (bytes.len() == 1 or bytes.first() != Ok(48)) {
					match U64.from_str(text) {
						Ok(n) if n <= 9223372036854775807 => Ok(n)
						_ => Err(bad_after(text))
					}
				} else {
					Err(bad_after(text))
				}
			}
		}?
		target = match q.target {
			Ok(t) => Ok(t)
			Err(NotFound) => Err(None)
		}
		Ok({ after, target })
	}

	bad_after : Str -> Problem
	bad_after = |text| Problem.new(BadRequest, "the query parameter after must be a log index (decimal digits), got ${text}")

	page_of : List(Toolchains.Row) -> { rows : List(Toolchains.Row), more : Bool }
	page_of = |rows| if (rows.len() > page_limit) { rows: rows.take_first(page_limit), more: Bool.True } else { rows, more: Bool.False }

	row_text : Toolchains.Row -> Str
	row_text = |r| "{\"tag\":${Json.to_str(r.tag)},\"target\":${Json.to_str(r.target)},\"asset_name\":${Json.to_str(r.asset_name)},\"sha256\":${Json.to_str(r.sha256)},\"published_at\":${r.published_at.to_str()},\"log_index\":${r.log_index.to_str()}}"

	rows_text : List(Toolchains.Row) -> Str
	rows_text = |rows| "[${Str.join_with(rows.map(row_text), ",")}]"

	put_body : List(Toolchains.Row) -> Str
	put_body = |rows| "{\"toolchains\":${rows_text(rows)}}"

	page_body : { rows : List(Toolchains.Row), more : Bool } -> Str
	page_body = |page| "{\"toolchains\":${rows_text(page.rows)},\"more\":${if (page.more) "true" else "false"}}"

	not_nightly : Str -> Problem
	not_nightly = |tag| Problem.new(NotACandidate, "the tag ${tag} is not a nightly tag")

	not_final : Str -> Problem
	not_final = |tag| Problem.new(NotACandidate, "the release ${tag} is a draft or a prerelease")

	no_release : Str -> Problem
	no_release = |tag| Problem.new(NotFound, "roc-lang/nightlies has no release with the tag ${tag}")

	no_candidate : Str -> Problem
	no_candidate = |tag| Problem.new(NotACandidate, "the release ${tag} has no compiler asset (roc_nightly-<target>-*.tar.gz, or .zip for Windows)")

	id_taken : Str, Str -> Problem
	id_taken = |tag, other| Problem.new(NotACandidate, "the tag ${tag} has the same nightly id as the recorded tag ${other}")

	github_status : U16 -> Problem
	github_status = |status| Problem.new(Upstream, "the GitHub release read failed with status ${status.to_str()}")

	github_no_answer : Problem
	github_no_answer = Problem.new(Upstream, "the GitHub release read failed: no answer")

	github_bad : Problem
	github_bad = Problem.new(Upstream, "the GitHub release answer is not a valid release")
}
