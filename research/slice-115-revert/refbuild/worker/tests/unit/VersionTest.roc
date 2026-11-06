import lib.Version
import semver.Semver
import semver.VersionReq

VersionTest :: [].{}

# W0 tests of worker/lib/Version.roc (slice 105). The numbers come from research/semver-key/key.mjs (`stored`), run in Node on these texts.

ver = |text| match Semver.parse(text) {
	Ok(v) => v
	Err(_) => crash "bad test version ${text}"
}

req = |text| match VersionReq.parse(text) {
	Ok(r) => r
	Err(_) => crash "bad test requirement ${text}"
}

texts = |vs| vs.map(|v| v.to_str())

# R-IK5 column: the XOR of the top bit as a signed INTEGER. The key 0 is the smallest value (`unknown`), U64 max is the largest.
# The 4 ends: 0, 0xFFFF (0.0.0), 2^63 (the sign edge), U64 max.
stored_rows : List((U64, I64))
stored_rows = [
	(0, -9223372036854775808),
	(0xFFFF, -9223372036854710273),
	(0x100020003FFFF, -9223090553287868417),
	(0x7FFFFFFFFFFFFFFF, -1),
	(0x8000000000000000, 0),
	(0xFFFEFFFEFFFEFFFF, 9223090557583032319),
	(0xFFFFFFFFFFFFFFFF, 9223372036854775807),
]

expect stored_rows.map(|(k, _)| Version.to_stored(k)) == stored_rows.map(|(_, s)| s)
expect stored_rows.map(|(_, s)| Version.from_stored(s)) == stored_rows.map(|(k, _)| k)

# R-IK5 column, R-IK2: the columns of a version. `version` is decimal text, `version_text` is empty only for an exact key.
# Rows: text, version, version_text. A pre-release, build metadata and a saturated part keep their text.
column_rows : List((Str, Str, Str))
column_rows = [
	("0.0.0", "-9223372036854710273", ""),
	("1.2.3", "-9223090553287868417", ""),
	("65534.65534.65534", "9223090557583032319", ""),
	("1.2.3-alpha4", "-9223090553287927337", "1.2.3-alpha4"),
	("1.2.3-alpha10", "-9223090553287927337", "1.2.3-alpha10"),
	("1.2.3-beta1", "-9223090553287927279", "1.2.3-beta1"),
	("1.2.3+build.5", "-9223090553287868417", "1.2.3+build.5"),
	("65535.0.0", "9223372036854775807", "65535.0.0"),
	("0.65535.0", "-9223090561878065153", "0.65535.0"),
	("18446744073709551615.0.0", "9223372036854775807", "18446744073709551615.0.0"),
]

expect column_rows.map(|(t, _, _)| Version.column(ver(t))) == column_rows.map(|(_, v, x)| { version: v, version_text: x })

# R-IK5 property 2 and 3: the row gives the version back, with its build metadata and its large parts. A column that fits no version is an error.
expect column_rows.map(|(t, _, _)| Version.read(Version.column(ver(t)))) == column_rows.map(|(t, _, _)| Ok(ver(t)))
expect Version.read({ version: "-9223090553287868417", version_text: "" }) == Ok(ver("1.2.3"))
expect Version.read({ version: "x", version_text: "" }) == Err(BadColumn)
expect Version.read({ version: "9223372036854775808", version_text: "" }) == Err(BadColumn)
expect Version.read({ version: "-9223090553287927337", version_text: "" }) == Err(BadColumn)
expect Version.read({ version: "-9223372036854775808", version_text: "" }) == Err(BadColumn)
expect Version.read({ version: "-9223090553287927337", version_text: "1.2" }) == Err(BadColumn)

# R-IK5 property 1, case S4 on the pure side: the stored value follows the semver order. The chain has the edges: the sign edge, a pre-release before its release,
# a numeric identifier before a letter one, and the saturated parts at the end. The stored values never fall, and the same value means a tie for `sort_precedence`.
chain = [
	"0.0.0",
	"0.0.1",
	"0.1.0",
	"1.0.0-0",
	"1.0.0-1",
	"1.0.0-4094",
	"1.0.0-A",
	"1.0.0-alpha",
	"1.0.0-beta",
	"1.0.0-rc",
	"1.0.0",
	"1.2.3-alpha4",
	"1.2.3-beta1",
	"1.2.3",
	"1.2.4",
	"1.10.0",
	"2.0.0",
	"65534.65534.65534",
	"65535.0.0",
]

stored_of = |t| Version.to_stored(ver(t).to_key().key)

expect chain.map(stored_of) == chain.map(stored_of).sort_with(|a, b| a.order_relative_to(b))
expect List.map2(chain, chain.drop_first(1), |a, b| stored_of(a) <= stored_of(b)).all(|ok| ok)

# R-IK5 property 3: `alpha10` is before `alpha4` (semver 11.4.2) and both have one stored value. `sort_precedence` puts them right, and drops no row.
expect stored_of("1.2.3-alpha10") == stored_of("1.2.3-alpha4")
expect texts(Version.sort_precedence([ver("1.2.3"), ver("1.2.3-alpha4"), ver("1.2.3-alpha10"), ver("1.2.3-beta1"), ver("1.2.2")])) == ["1.2.2", "1.2.3-alpha10", "1.2.3-alpha4", "1.2.3-beta1", "1.2.3"]
expect texts(Version.sort_precedence([ver("1.2.3-alpha.10"), ver("1.2.3-alpha.4")])) == ["1.2.3-alpha.4", "1.2.3-alpha.10"]

# R-IK5 `?series=` (R-ID1): the series of a version, and the bounds as column values (case S4 of research/semver-key/).
expect ["1.2.3", "4.0.0", "1.0.0-rc", "0.25.1", "0.0.3", "65535.1.1", "0.65535.7"].map(|t| Version.series_of(ver(t))) == ["1", "4", "1", "0.25", "0.0", "65535", "0.65535"]

series_rows : List((Str, Str, Str))
series_rows = [
	("1", "-9223090561878065152", "-9222809086901354497"),
	("0.25", "-9223371929480593408", "-9223371925185626113"),
	("0.0", "-9223372036854775808", "-9223372032559808513"),
	("65535", "9223090561878065152", "9223372036854775807"),
	("0.65535", "-9223090566173032448", "-9223090561878065153"),
]

expect series_rows.map(|(s, _, _)| Version.series_bounds(s)) == series_rows.map(|(_, lo, hi)| Ok({ lo, hi }))
expect ["", "0", "-1", "1.2", "0.", "0.x", "01", "0.01", "x", "1.0.0", "18446744073709551616", "0.18446744073709551616", " 1"].map(|s| Version.series_bounds(s)) == List.repeat(Err(BadSeries), 13)

# R-IK5 `range`, R-AP16: the bounds of a requirement as column values, `^1.2.3` from case S5. A range that has no upper limit ends at the largest value.
expect Version.range_bounds(req("^1.2.3")) == { lo: "-9223090553287868417", hi: "-9222809086901288961" }
expect Version.range_bounds(req(">=1.2.3")) == { lo: "-9223090553287868417", hi: "9223372036854775807" }
expect Version.range_bounds(req("*")) == { lo: "-9223372036854710273", hi: "9223372036854775807" }

# R-IK5 `range`: a key in the bounds does not always match, so the filter step checks each row (case S5). Rows 1 to 3 are the superset that `BETWEEN` gives for `^1.2.3`
# (2.0.0 is the upper bound itself, 2.0.0-alpha4 is above it in a key but a pre-release never matches: roc-semver Q6, Q12). The build metadata does not change a match.
# `filter_range` keeps the order of its input. `^0.2.3` has the bounds 0.2.3 to 0.3.0: 0.3.0 is in the bounds and out of the range.
superset = ["1.2.3", "1.2.4", "1.2.3+build.5", "1.9.0", "1.99.99", "2.0.0", "2.0.0-alpha4"]
expect texts(Version.filter_range(req("^1.2.3"), superset.map(ver))) == ["1.2.3", "1.2.4", "1.2.3+build.5", "1.9.0", "1.99.99"]
expect texts(Version.filter_range(req(">=1.2.3, <1.10.0"), ["1.2.3", "1.9.9", "1.10.0", "1.2.3-beta1", "1.65535.0"].map(ver))) == ["1.2.3", "1.9.9"]
expect texts(Version.filter_range(req("^0.2.3"), ["0.2.3", "0.2.9", "0.3.0", "0.2.3-rc"].map(ver))) == ["0.2.3", "0.2.9"]
