## The codes of the closed sets (Registry 5.1, R-IK7): the position of a value in the list of its rule, from 0. Pure.
Code :: [].{

	## `result` of R-RE3 (Resolution 4, R-RC1 to R-RC4): `pass` 0, `fail` 1, `hang` 2, `crash` 3. The wire text is the lower-case name.
	Result : [Pass, Fail, Hang, Crash]

	## `source` of R-RE3 (R-MX5): `bot` 0, `author` 1. The wire text is the lower-case name.
	Source : [Bot, Author]

	## `kind` of an artifact (R-AP49, R-IK7): `app` 0, `package` 1, `platform` 2. The wire text is the lower-case name.
	Kind : [App, Package, Platform]

	kind_code : Code.Kind -> U8
	kind_code = |k| match k {
		App => 0
		Package => 1
		Platform => 2
	}

	kind_from_code : U8 -> Try(Code.Kind, [NoSuchCode])
	kind_from_code = |c| match c {
		0 => Ok(App)
		1 => Ok(Package)
		2 => Ok(Platform)
		_ => Err(NoSuchCode)
	}

	result_code : Code.Result -> U8
	result_code = |r| match r {
		Pass => 0
		Fail => 1
		Hang => 2
		Crash => 3
	}

	result_from_code : U8 -> Try(Code.Result, [NoSuchCode])
	result_from_code = |c| match c {
		0 => Ok(Pass)
		1 => Ok(Fail)
		2 => Ok(Hang)
		3 => Ok(Crash)
		_ => Err(NoSuchCode)
	}

	source_code : Code.Source -> U8
	source_code = |s| match s {
		Bot => 0
		Author => 1
	}

	source_from_code : U8 -> Try(Code.Source, [NoSuchCode])
	source_from_code = |c| match c {
		0 => Ok(Bot)
		1 => Ok(Author)
		_ => Err(NoSuchCode)
	}

	## The wire text of the lower-case names (R-AP17 `runs`, `nearest`).
	result_to_str : Code.Result -> Str
	result_to_str = |r| match r {
		Pass => "pass"
		Fail => "fail"
		Hang => "hang"
		Crash => "crash"
	}

	result_from_str : Str -> Try(Code.Result, [NoSuchValue])
	result_from_str = |s| match s {
		"pass" => Ok(Pass)
		"fail" => Ok(Fail)
		"hang" => Ok(Hang)
		"crash" => Ok(Crash)
		_ => Err(NoSuchValue)
	}

	## The code of a target name (R-IK7): `any` 0, then the 35 values of `RocTarget` from 1. The code of a name that is not in the list is `Err(NoCode)`: the codes 36 and up are the state of the registry (R-IK7), not of this package.
	target_code : Str -> Try(U8, [NoCode])
	target_code = |name| {
		found = target_list.fold({ i: 0.U8, hit: Err(NoCode) }, |acc, n| { i: acc.i + 1, hit: if (n == name) Ok(acc.i) else acc.hit })
		found.hit
	}

	target_list : List(Str)
	target_list = ["any", "x64mac", "x64win", "x64mingw", "x64freebsd", "x64openbsd", "x64netbsd", "x64musl", "x64glibc", "x64linux", "x64elf", "x64v1mac", "x64v1win", "x64v1mingw", "x64v1freebsd", "x64v1openbsd", "x64v1netbsd", "x64v1musl", "x64v1glibc", "x64v1linux", "x64v1elf", "arm64mac", "arm64win", "arm64mingw", "arm64linux", "arm64musl", "arm64glibc", "arm64v1win", "arm64v1mingw", "arm64v1linux", "arm64v1musl", "arm64v1glibc", "arm32linux", "arm32musl", "wasm32", "wasm32v1"]

	## The target name of a code (R-IK7).
	target_name : U8 -> Try(Str, [NoCode])
	target_name = |code| target_list.get(code.to_u64()).map_err(|_| NoCode)

	## R-IK7: a new target name must match `[a-z0-9]{1,32}`.
	is_new_target_name : Str -> Bool
	is_new_target_name = |name| {
		n = name.count_utf8_bytes()
		n >= 1 and n <= 32 and name.to_utf8().all(|b| (b >= 97 and b <= 122) or (b >= 48 and b <= 57))
	}
}
