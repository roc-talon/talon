Semver := { major : U64, minor : U64, patch : U64 }.{
	parse : Str -> Try(Semver, [BadSemver])
	parse = |s| {
		match s.split_on(".") {
			[a, b, c] => {
				major = U64.from_str(a) ? |_| BadSemver
				minor = U64.from_str(b) ? |_| BadSemver
				patch = U64.from_str(c) ? |_| BadSemver
				# PLANTED: uncomment to check that the target finds a bug
				# if patch > 99999 { return Err(BadSemver) }
				Ok({ major, minor, patch })
			}
			_ => Err(BadSemver)
		}
	}

	to_str : Semver -> Str
	to_str = |v| "${v.major.to_str()}.${v.minor.to_str()}.${v.patch.to_str()}"
}
