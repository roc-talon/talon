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
}

# The first version of the next series: `2.1.0` gives `3.0.0`, `0.25.0` gives `0.26.0`.
next_series : Semver -> Str
next_series = |v| if v.major() >= 1 "${(v.major() + 1).to_str()}.0.0" else "0.${(v.minor() + 1).to_str()}.0"
