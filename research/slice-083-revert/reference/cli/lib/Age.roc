## Private reference of slice 081 (test agent). Not the answer for the code agent: it only proves the tests are right.
## The age test of `min-release-age` and the list `min-release-age-exclude` (R-C7, R-C11 to R-C16). Pure functions only.
Age :: [].{

	## R-C12: `owner/repo` or `owner/*`. Each part: not empty, ASCII letters, digits, `-`, `_`, `.`, and not `.` or `..`. `*` only as the whole repo part.
	check : Str -> Try({}, [BadPattern])
	check = |pattern| match parts_of(pattern) {
		Ok(_) => Ok({})
		Err(BadPattern) => Err(BadPattern)
	}

	## R-C12: true when the pattern is valid, the name is `Ok`, and the owner (and the repo, for `owner/repo`) are equal, ASCII case-insensitive.
	matches : { pattern : Str, name : Try(Str, [NoName]) } -> Bool
	matches = |input| match (parts_of(input.pattern), input.name) {
		(Ok((owner, repo)), Ok(name)) => match name.split_on("/") {
			[n_owner, n_repo] => n_owner.caseless_ascii_equals(owner) and (repo == "*" or n_repo.caseless_ascii_equals(repo))
			_ => Bool.False
		}
		_ => Bool.False
	}

	## R-C12, R-C16: the first pattern of the list that matches, as written.
	first_match : { patterns : List(Str), name : Try(Str, [NoName]) } -> Try(Str, [None])
	first_match = |input| match input.patterns.find_first(|pattern| Age.matches({ pattern, name: input.name })) {
		Ok(p) => Ok(p)
		Err(_) => Err(None)
	}

	## R-C14: the project list, then the user list, each text once.
	join : { project : List(Str), user : List(Str) } -> List(Str)
	join = |lists| lists.project.concat(lists.user).fold([], |acc, p| if acc.contains(p) acc else acc.append(p))

	## R-C7, R-C15: the one age test.
	hides : { now : U64, min_age : U64, published_at : U64, exclude : List(Str), name : Try(Str, [NoName]) } -> Bool
	hides = |input| input.min_age > 0 and input.published_at + input.min_age > input.now and Age.first_match({ patterns: input.exclude, name: input.name }) == Err(None)

	## R-C16: the note, only when the release is young and a pattern kept it.
	note : { id : Str, version : Str, now : U64, min_age : U64, published_at : U64, exclude : List(Str), name : Try(Str, [NoName]) } -> Try(Str, [None])
	note = |input| {
		young = input.min_age > 0 and input.published_at + input.min_age > input.now
		match (young, Age.first_match({ patterns: input.exclude, name: input.name })) {
			(Bool.True, Ok(pattern)) => {
				age = if input.now > input.published_at input.now - input.published_at else 0
				who = if input.version.is_empty() input.id else "${input.id} ${input.version}"
				Ok("${who} is ${(age // 86400).to_str()}d old (min-release-age ${(input.min_age // 86400).to_str()}d), not hidden by min-release-age-exclude: ${pattern}")
			}
			_ => Err(None)
		}
	}
}

# One parser of a pattern for `check` and `matches`.
parts_of : Str -> Try((Str, Str), [BadPattern])
parts_of = |pattern| match pattern.split_on("/") {
	[owner, repo] if good_part(owner, Bool.False) and good_part(repo, Bool.True) => Ok((owner, repo))
	_ => Err(BadPattern)
}

good_part : Str, Bool -> Bool
good_part = |part, star_ok| {
	if star_ok and part == "*" {
		Bool.True
	} else {
		!part.is_empty() and part != "." and part != ".." and part.to_utf8().all(|b| (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9') or b == '-' or b == '_' or b == '.')
	}
}
