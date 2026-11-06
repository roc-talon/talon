import records.Code

CodeTest :: [].{}

# W0 tests of packages/records/Code.roc (slice 104). Expected values come from the lists of R-IK7, not from the code.

# R-IK7: result is the position in pass, fail, hang, crash. source is the position in bot, author. Codes and wire text go both ways. A code outside the list is an error.
expect ([Pass, Fail, Hang, Crash].map(Code.result_code) == [0, 1, 2, 3]) and ([0, 1, 2, 3].map(Code.result_from_code) == [Ok(Pass), Ok(Fail), Ok(Hang), Ok(Crash)]) and (Code.result_from_code(4) == Err(NoSuchCode)) and ([Pass, Fail, Hang, Crash].map(Code.result_to_str) == ["pass", "fail", "hang", "crash"]) and (["pass", "fail", "hang", "crash"].map(Code.result_from_str) == [Ok(Pass), Ok(Fail), Ok(Hang), Ok(Crash)]) and (Code.result_from_str("Pass") == Err(NoSuchValue)) and ([Bot, Author].map(Code.source_code) == [0, 1]) and ([0, 1].map(Code.source_from_code) == [Ok(Bot), Ok(Author)]) and (Code.source_from_code(2) == Err(NoSuchCode))

# R-IK7: the target_table. `any` is 0, then the 35 values of RocTarget.
target_table : List((Str, U8))
target_table = [
	("any", 0),
	("x64mac", 1),
	("x64win", 2),
	("x64mingw", 3),
	("x64freebsd", 4),
	("x64openbsd", 5),
	("x64netbsd", 6),
	("x64musl", 7),
	("x64glibc", 8),
	("x64linux", 9),
	("x64elf", 10),
	("x64v1mac", 11),
	("x64v1win", 12),
	("x64v1mingw", 13),
	("x64v1freebsd", 14),
	("x64v1openbsd", 15),
	("x64v1netbsd", 16),
	("x64v1musl", 17),
	("x64v1glibc", 18),
	("x64v1linux", 19),
	("x64v1elf", 20),
	("arm64mac", 21),
	("arm64win", 22),
	("arm64mingw", 23),
	("arm64linux", 24),
	("arm64musl", 25),
	("arm64glibc", 26),
	("arm64v1win", 27),
	("arm64v1mingw", 28),
	("arm64v1linux", 29),
	("arm64v1musl", 30),
	("arm64v1glibc", 31),
	("arm32linux", 32),
	("arm32musl", 33),
	("wasm32", 34),
	("wasm32v1", 35),
]

expect (target_table.map(|(n, _)| Code.target_code(n)) == target_table.map(|(_, c)| Ok(c))) and (target_table.map(|(_, c)| Code.target_name(c)) == target_table.map(|(n, _)| Ok(n)))

# R-IK7: codes 36 and up are the state of the registry. A name or code with no entry is an error.
expect (Code.target_code("riscv64") == Err(NoCode)) and (Code.target_code("") == Err(NoCode)) and (Code.target_name(36) == Err(NoCode))

# R-IK7: a new target name matches [a-z0-9]{1,32}.
expect {
	ok = ["riscv64", "a", "0", "abcdefghijklmnopqrstuvwxyz012345"]
	no = ["", "Linux", "x-y", "x_y", "abcdefghijklmnopqrstuvwxyz0123456", "x y"]
	ok.map(Code.is_new_target_name) == ok.map(|_| Bool.True) and no.map(Code.is_new_target_name) == no.map(|_| Bool.False)
}

# R-IK7, R-AP49: kind is the position in app, package, platform.
expect Code.kind_code(App) == 0 and Code.kind_code(Package) == 1 and Code.kind_code(Platform) == 2 and [0, 1, 2].map(Code.kind_from_code) == [Ok(App), Ok(Package), Ok(Platform)] and Code.kind_from_code(3) == Err(NoSuchCode)
