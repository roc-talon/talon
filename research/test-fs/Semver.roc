Semver := { major : U64, minor : U64, patch : U64 }.{
	parse : Str -> Try(Semver, [BadSemver])
	parse = |s| {
		parts = s.split_on(".")
		match parts {
			[a, b, c] => {
				major = U64.from_str(a) ? |_| BadSemver
				minor = U64.from_str(b) ? |_| BadSemver
				patch = U64.from_str(c) ? |_| BadSemver
				Ok({ major, minor, patch })
			}
			_ => Err(BadSemver)
		}
	}

	is_lt : Semver, Semver -> Bool
	is_lt = |a, b|
		if a.major != b.major a.major < b.major
		else if a.minor != b.minor a.minor < b.minor
		else a.patch < b.patch
}

expect Semver.parse("1.2.3").is_ok()
expect Semver.parse("1.2").is_err()
expect Semver.parse("a.b.c").is_err()
expect match (Semver.parse("1.2.3"), Semver.parse("1.10.0")) {
	(Ok(a), Ok(b)) => a < b
	_ => Bool.False
}
