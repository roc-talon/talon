import Pin
import toml.Value

## The age test of `min-release-age` and the list `min-release-age-exclude` (R-C7, R-C11 to R-C16). Pure functions only.
Age :: [].{

	## R-C12: `owner/repo` or `owner/*`. Each part is not empty, has only ASCII letters, digits, `-`, `_` and `.`, and is not `.` or `..`. `*` is allowed only as the whole repo part.
	check : Str -> Try({}, [BadPattern])
	check = |pattern| parse(pattern).map_ok(|_| {})

	## R-C12: true when the pattern is valid, the name is `Ok`, and the owner (and the repo, for `owner/repo`) are equal in an ASCII case-insensitive compare.
	matches : { pattern : Str, name : Try(Str, [NoName]) } -> Bool
	matches = |input| match (parse(input.pattern), input.name) {
		(Ok(pattern), Ok(name)) => match name.split_on("/") {
			[owner, repo] => owner.caseless_ascii_equals(pattern.owner) and (pattern.repo == "*" or repo.caseless_ascii_equals(pattern.repo))
			_ => Bool.False
		}
		_ => Bool.False
	}

	## R-C12, R-C16: the first pattern of the list that matches the name, as written.
	first_match : { patterns : List(Str), name : Try(Str, [NoName]) } -> Try(Str, [None])
	first_match = |input| input.patterns.find_first(|pattern| Age.matches({ pattern, name: input.name })).map_err(|_| None)

	## R-C14: the union of the two lists. The `talon.toml` list first, then the `config.toml` list. A text that is in the list already is not added again.
	join : { project : List(Str), user : List(Str) } -> List(Str)
	join = |lists| lists.project.concat(lists.user).fold([], |acc, pattern| if acc.contains(pattern) acc else acc.append(pattern))

	## R-C7, R-C15: the one age test. `min_age` 0 hides nothing. A release at exactly `min_age` seconds is visible.
	hides : { now : U64, min_age : U64, published_at : U64, exclude : List(Str), name : Try(Str, [NoName]) } -> Bool
	hides = |input| young(input) and Age.first_match({ patterns: input.exclude, name: input.name }).is_err()

	## R-C15, R-DT4: the time of a candidate that the solver sees (slice 082). 0 when a pattern matches the name and the release is not after the snapshot. Else the real time, so that the snapshot still hides a later release.
	seen : { published_at : U64, snapshot : Try(U64, [None]), exclude : List(Str), name : Try(Str, [NoName]) } -> U64
	seen = |input| {
		after_snapshot = match input.snapshot {
			Ok(snapshot) => input.published_at > snapshot
			Err(None) => Bool.False
		}
		if !after_snapshot and Age.first_match({ patterns: input.exclude, name: input.name }).is_ok() 0 else input.published_at
	}

	## R-C16: the note when a release is younger than `min_age` and only a pattern keeps it visible. The text has no `note: ` prefix. An empty `version` (a compiler) is left out with its space.
	note : { id : Str, version : Str, now : U64, min_age : U64, published_at : U64, exclude : List(Str), name : Try(Str, [NoName]) } -> Try(Str, [None])
	note = |input| match Age.first_match({ patterns: input.exclude, name: input.name }) {
		Ok(pattern) if young(input) => {
			days = input.now.minus_saturated(input.published_at) // day
			who = if input.version.is_empty() input.id else "${input.id} ${input.version}"
			Ok("${who} is ${days.to_str()}d old (min-release-age ${(input.min_age // day).to_str()}d), not hidden by min-release-age-exclude: ${pattern}")
		}
		_ => Err(None)
	}

	## R-C15: the name that a pattern compares for a compiler: `roc-lang/nightlies` for a nightly, `roc-lang/roc` for a release.
	compiler_name : Str -> Str
	compiler_name = |id| if Pin.is_nightly(id) "roc-lang/nightlies" else "roc-lang/roc"

	## R-C11, R-C13: the value of the key `min-release-age-exclude`, or the reason that it is wrong. The caller adds the path, the line and the key.
	read_list : Value -> Try(List(Str), Str)
	read_list = |value| match value {
		Value.Array(items) => items.map_try(read_pattern)
		_ => Err(not_a_list)
	}
}

day : U64
day = 86400

not_a_list : Str
not_a_list = "must be a list of owner/repo or owner/* patterns"

young : { now : U64, min_age : U64, published_at : U64, .. } -> Bool
young = |input| input.min_age > 0 and input.published_at + input.min_age > input.now

read_pattern : Value -> Try(Str, Str)
read_pattern = |item| match item {
	Value.String(pattern) => match Age.check(pattern) {
		Ok({}) => Ok(pattern)
		Err(BadPattern) => Err("'${pattern}' must be owner/repo or owner/*")
	}
	_ => Err(not_a_list)
}

# The one parser of a pattern, for `check` and `matches`.
parse : Str -> Try({ owner : Str, repo : Str }, [BadPattern])
parse = |pattern| match pattern.split_on("/") {
	[owner, repo] if good_part(owner) and (repo == "*" or good_part(repo)) => Ok({ owner, repo })
	_ => Err(BadPattern)
}

good_part : Str -> Bool
good_part = |part| !part.is_empty() and part != "." and part != ".." and part.to_utf8().all(good_byte)

good_byte : U8 -> Bool
good_byte = |b| (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9') or b == '-' or b == '_' or b == '.'
