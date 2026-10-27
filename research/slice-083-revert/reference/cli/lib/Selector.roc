import semver.Semver
import semver.VersionReq

## The selector of a reference: the text after `@` (CLI 2, R-SL1 to R-SL15).
## This is a syntax check only. It needs no index. A later step (the index, slice 003 and 007)
## finds the release that matches.
##
## | Tag | Text | Rule |
## | --- | --- | --- |
## | `Exact(v)` | A version with 3 parts that `Semver.parse` reads: `1.4.0` | R-SL3 |
## | `Range(text)` | A range that `VersionReq.parse` reads, or a series. `text` is what `talon.toml` gets (R-AD26): the typed text, and `^` is put before a bare version with 1 or 2 parts (`1` gives `^1`, `1.2` gives `^1.2`, `0.25` gives `^0.25`, R-SL15) | R-SL4, R-SL15 |
## | `Latest` | `latest` | R-SL5 |
## | `Nightly(tag)` | A full nightly tag in one of the two forms of Design 2: `nightly-2026-10-09-258ab27`, `nightly-2026-July-31-123c5d7` (see below) | R-SL6 |
## | `Step(n)` | `-1`, `+2`: a sign and decimal digits. `Step(-1)`, `Step(2)` | R-SL7 |
## | `GitSha(text)` | Hex digits only, 7 or more, and no rule above applies | R-SL10 |
## | `GitRef(text)` | Any text, only with `git` set (`--git`) | R-SL8, R-SL11, R-SL13 |
##
## The nightly tag form: `nightly-`, 4 digits, `-`, 2 digits or an English month name, `-`, 2 digits, `-`,
## 7 or more hex digits (proposal, slice 004, decision D5).
##
## The order of the rules (R-SL9 to R-SL13) with `git` not set:
##
## | # | Test | Result |
## | --- | --- | --- |
## | 0 | The text is empty | `Err(Empty)` |
## | 1 | `latest`, a nightly tag, a step, a version with 3 parts, a range | The tag of the table above (R-SL9) |
## | 2 | Hex only, 7 or more characters | `GitSha` (R-SL10) |
## | 3 | Anything else (a branch or tag name, a typo such as `mian`) | `Err(Unknown)`. The caller says `use --git for a branch or tag` (R-SL11, R-SL12, R-SL13). |
##
## With `git` set, a non-empty text is `GitRef(text)`: it skips rules 1 and 2 (R-SL13). So `latest` and `1.4.0` are git refs then.
## A selector of 7 or more decimal digits is both a range and a hex text: question Q4 of the slice file.
Selector := [
	Exact(Str),
	Range(Str),
	Latest,
	Nightly(Str),
	Step(I64),
	GitSha(Str),
	GitRef(Str),
].{
	is_eq : _

	## Reads the text after `@`. The second argument is `--git`.
	parse : Str, Bool -> Try(Selector, [Empty, Unknown])
	parse = |text, git|
		if text.is_empty() {
			Err(Empty)
		} else if git {
			Ok(GitRef(text))
		} else if text == "latest" {
			Ok(Latest)
		} else if is_nightly_tag(text) {
			Ok(Nightly(text))
		} else {
			match step_of(text) {
				Ok(n) => Ok(Step(n))
				Err(NotStep) => release_or_sha(text)
			}
		}
}

# A release version, a range, or a sha (R-SL9 to R-SL10). Anything else is `Unknown`.
release_or_sha : Str -> Try(Selector, [Unknown])
release_or_sha = |text| match Semver.parse(text) {
	Ok(_) => Ok(Exact(text))
	Err(_) => match VersionReq.parse(text) {
		Ok(_) => Ok(Range(with_caret(text)))
		Err(_) => if is_sha(text) Ok(GitSha(text)) else Err(Unknown)
	}
}

# R-SL15: a bare version with 1 or 2 parts is a caret range.
with_caret : Str -> Str
with_caret = |text| {
	bytes = text.to_utf8()
	bare = bytes.all(|b| is_digit(b) or b == '.') and bytes.keep_if(|b| b == '.').len() < 2
	if bare "^${text}" else text
}

# R-SL7: a sign and decimal digits.
step_of : Str -> Try(I64, [NotStep])
step_of = |text| {
	sign = if text.starts_with("-") -1 else 1
	digits = text.drop_prefix("-").drop_prefix("+")
	signed = text.starts_with("-") or text.starts_with("+")
	if signed and all_digits(digits) {
		match I64.from_str(digits) {
			Ok(n) => Ok(sign * n)
			Err(_) => Err(NotStep)
		}
	} else {
		Err(NotStep)
	}
}

# R-SL10: hex digits only, 7 or more.
is_sha : Str -> Bool
is_sha = |text| text.count_utf8_bytes() >= 7 and text.to_utf8().all(is_hex)

# D5: `nightly-YYYY-MM-DD-<sha>` or `nightly-YYYY-<Month>-DD-<sha>`, with a sha of 7 or more hex digits.
is_nightly_tag : Str -> Bool
is_nightly_tag = |text| match text.split_on("-") {
	["nightly", year, month, day, sha] => digits_of(year, 4) and (digits_of(month, 2) or months.contains(month)) and digits_of(day, 2) and is_sha(sha)
	_ => Bool.False
}

months : List(Str)
months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

digits_of : Str, U64 -> Bool
digits_of = |text, count| text.count_utf8_bytes() == count and all_digits(text)

all_digits : Str -> Bool
all_digits = |text| !text.is_empty() and text.to_utf8().all(is_digit)

is_digit : U8 -> Bool
is_digit = |b| b >= '0' and b <= '9'

is_hex : U8 -> Bool
is_hex = |b| is_digit(b) or (b >= 'a' and b <= 'f') or (b >= 'A' and b <= 'F')
