import semver.Semver
import semver.VersionReq

## Version ranges of `talon.toml` and the implied range of a header entry (Design 4.3, R-I3, R-I4, R-I7, R-C1, R-TF4).
## The syntax of a range is `VersionReq` of the generic package `roc-semver`. This module adds the rules of Talon.
Ranges :: [].{

	## R-I4: the range that a header version implies when `talon.toml` has no key for it: the same series (R-ID1), and never lower
	## than the header version. `0.25.0` gives `>=0.25.0, <0.26.0`. `2.1.0` gives `>=2.1.0, <3.0.0`. A version below 1.0 has the series
	## `0.<minor>`, so `0.0.3` gives `>=0.0.3, <0.1.0`. The text is exactly this form: `>=<v>, <<next series>.0` with `, ` between the 2 parts.
	## The version is `X.Y.Z` (`Ident.version`). Else `Err(BadVersion)`.
	implied : Str -> Try(Str, [BadVersion])
	implied = |version| match Semver.parse(version) {
		Ok(v) => Ok(">=${version}, <${next_series(v)}")
		Err(_) => Err(BadVersion)
	}

	## R-TF4: does the text parse as a range? `^2.1`, `=2.0.0`, `0.25.*`, `*`, `>=1.2, <1.5`, `2`, `~1.2` do. `latest`, the empty text, `^`,
	## `1.2.3.4` and `=nightly-2026-10-09-258ab27` do not.
	check : Str -> Try({}, [BadRange])
	check = |text| match VersionReq.parse(text) {
		Ok(_) => Ok({})
		Err(_) => Err(BadRange)
	}

	## R-C1, R-I7: a version is admitted when each range of the list admits it (the ranges are an intersection). The empty list admits each
	## version. A range or a version that does not parse admits nothing. `^2.1` admits `2.1.0` and `2.9.9`, not `2.0.9` and not `3.0.0`.
	## `^0.25.1` admits `0.25.1` and `0.25.9`, not `0.26.0`. A pre-release version is never admitted (`VersionReq.matches`).
	admits : { ranges : List(Str), version : Str } -> Bool
	admits = |facts| match Semver.parse(facts.version) {
		Ok(version) => facts.ranges.all(
			|text| match VersionReq.parse(text) {
				Ok(req) => req.matches(version)
				Err(_) => Bool.False
			},
		)
		Err(_) => Bool.False
	}

	## R-UP5 (slice 038): the range that a header version gets when `tln upgrade` moves a variable to `version` (`X.Y.Z`). A range that admits the version does not change. Else the same form at the new version:
	## the prefix (`^`, `~` or none), the number of parts (1 to 3, each taken from the new version) and a wildcard end (`.*`) stay. A range that starts with `=` (an anchor) is `=<version>`.
	##
	## | Range | Version | Result |
	## | --- | --- | --- |
	## | `^2.1` | `3.0.2` | `^3.0` |
	## | `^0.25` | `0.26.1` | `^0.26` |
	## | `0.25.*` | `0.26.1` | `0.26.*` |
	## | `2` | `3.0.2` | `3` |
	## | `^2.1.3` | `3.0.2` | `^3.0.2` |
	## | `=2.0.0` | `3.0.2` | `=3.0.2` |
	## | `^2.1` | `2.5.0` | `^2.1` (it admits the version) |
	## | `~1.4` | `2.0.0` | `~2.0` |
	## | `1.0.*` | `1.2.0` | `1.2.*` |
	## | `>=1.2, <1.5` (a form that the design does not give: question Q1) | `3.0.2` | `Err(NoForm)` |
	rewrite : { range : Str, version : Str } -> Try(Str, [NoForm])
	rewrite = |facts| if Ranges.admits({ ranges: [facts.range], version: facts.version }) {
		Ok(facts.range)
	} else {
		match Semver.parse(facts.version) {
			Ok(v) => moved_form(facts.range.trim(), v)
			Err(_) => Err(NoForm)
		}
	}
}

# The first version of the next series: `2.1.0` gives `3.0.0`, `0.25.0` gives `0.26.0`.
next_series : Semver -> Str
next_series = |v| if v.major() >= 1 "${(v.major() + 1).to_str()}.0.0" else "0.${(v.minor() + 1).to_str()}.0"

# R-UP5: an anchor is an anchor of the new version. Else the prefix, the number of parts and the wildcard end stay, and the parts come from the version.
moved_form : Str, Semver -> Try(Str, [NoForm])
moved_form = |range, v| {
	numbers = [v.major().to_str(), v.minor().to_str(), v.patch().to_str()]
	if range.starts_with("=") {
		Ok("=${Str.join_with(numbers, ".")}")
	} else {
		prefix = if range.starts_with("^") "^" else if range.starts_with("~") "~" else ""
		body = range.drop_prefix(prefix)
		parts = body.drop_suffix(".*").split_on(".")
		if parts.len() <= 3 and parts.all(|p| U64.from_str(p).is_ok()) {
			Ok("${prefix}${Str.join_with(numbers.take_first(parts.len()), ".")}${if body.ends_with(".*") ".*" else ""}")
		} else {
			Err(NoForm)
		}
	}
}
