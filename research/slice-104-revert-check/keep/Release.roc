import Nullable

## One release on the wire (Registry R-RE2, R-AP1, R-AP2, R-AP13, R-AP14, R-AP17). Pure.
## The wire members are the table of R-AP49. Every member is always written, with null for none (R-AP51). A missing required member is `BadJson` (R-AP51).
Release :: [].{

	## `group` and `series` are the two fields of R-AP15. `version` is `Semver.to_str` of the version (R-IK5). `hash` is the base58 hash of the artifact (R-IK1). `repo` is the lower-case GitHub name, `Err(None)` on another host (null). `tag` is null on another host. `published_at` is a time in milliseconds (R-AP50). `yank_reason` is the reason of the last yank. `withdrawn` is the text of R-PU17, R-PU20 or R-PU24, or null; a reader keeps a value that it does not know.
	Row : {
		log_index : U64,
		hash : Str,
		group : Str,
		series : Str,
		version : Str,
		url : Str,
		tag : Try(Str, [None]),
		roc_version : Try(Str, [None]),
		repo : Try(Str, [None]),
		published_at : U64,
		yanked : Bool,
		yank_reason : Try(Str, [None]),
		withdrawn : Try(Str, [None]),
	}

	## The wire form of a row: a nullable member is `Try(Nullable(Str), [Missing])`. It is always written, `null` for none. A missing member reads as none.
	Wire : {
		log_index : U64,
		hash : Str,
		group : Str,
		series : Str,
		version : Str,
		url : Str,
		tag : Try(Nullable(Str), [Missing]),
		roc_version : Try(Nullable(Str), [Missing]),
		repo : Try(Nullable(Str), [Missing]),
		published_at : U64,
		yanked : Bool,
		yank_reason : Try(Nullable(Str), [Missing]),
		withdrawn : Try(Nullable(Str), [Missing]),
	}

	to_wire : Release.Row -> Release.Wire
	to_wire = |r| {
		log_index: r.log_index,
		hash: r.hash,
		group: r.group,
		series: r.series,
		version: r.version,
		url: r.url,
		tag: Nullable.write(r.tag),
		roc_version: Nullable.write(r.roc_version),
		repo: Nullable.write(r.repo),
		published_at: r.published_at,
		yanked: r.yanked,
		yank_reason: Nullable.write(r.yank_reason),
		withdrawn: Nullable.write(r.withdrawn),
	}

	from_wire : Release.Wire -> Release.Row
	from_wire = |w| {
		log_index: w.log_index,
		hash: w.hash,
		group: w.group,
		series: w.series,
		version: w.version,
		url: w.url,
		tag: Nullable.read(w.tag),
		roc_version: Nullable.read(w.roc_version),
		repo: Nullable.read(w.repo),
		published_at: w.published_at,
		yanked: w.yanked,
		yank_reason: Nullable.read(w.yank_reason),
		withdrawn: Nullable.read(w.withdrawn),
	}

	decode : Str -> Try(Release.Row, [BadJson(Str)])
	decode = |text| {
		parsed : Try(Release.Wire, _)
		parsed = Json.parse(text)
		parsed.map_ok(from_wire).map_err(|e| BadJson(Str.inspect(e)))
	}

	encode : Release.Row -> Str
	encode = |row| Json.to_str(to_wire(row))
}
