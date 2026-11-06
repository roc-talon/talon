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

# Slice 122, R-IK7, R-RE9, R-PU15: `via` is the position in oidc, webhook, poll, ingest. The code order is the strength order. A code outside the list is an error.
expect [0, 1, 2, 3].map(Code.via_name) == [Ok("oidc"), Ok("webhook"), Ok("poll"), Ok("ingest")] and Code.via_name(4) == Err(NoSuchCode) and Code.via_name(255) == Err(NoSuchCode)

# Slice 122, R-AP49 `provenance`, R-PU15 (the strongest one is `oidc`, then `webhook`, then `poll`, then `ingest`), R-SE3: the order does not depend on the order of the input. The 24 orders of the 4 texts all give the same list.
expect {
	all4 = ["oidc", "webhook", "poll", "ingest"]
	perms = all4.join_map(|a| all4.keep_if(|b| b != a).join_map(|b| all4.keep_if(|c| c != a and c != b).join_map(|c| all4.keep_if(|d| d != a and d != b and d != c).map(|d| [a, b, c, d]))))
	perms.len() == 24 and perms.all(|p| Code.via_sort(p) == all4)
}

# Slice 122, R-AP49: a list of 1, 2 or 3 texts is a list of the same texts in the strength order. An empty list stays empty. `ingest` + `oidc` (the publish after an ingest, R-PU16) gives `oidc` first.
expect {
	Code.via_sort([]) == [] and Code.via_sort(["poll"]) == ["poll"] and Code.via_sort(["ingest", "oidc"]) == ["oidc", "ingest"] and Code.via_sort(["ingest", "webhook"]) == ["webhook", "ingest"] and Code.via_sort(["poll", "webhook"]) == ["webhook", "poll"] and Code.via_sort(["ingest", "poll", "webhook"]) == ["webhook", "poll", "ingest"] and Code.via_sort(["oidc", "ingest"]) == ["oidc", "ingest"]
}

# Slice 122, R-AP49, R-AP44: a text that the reader does not know is kept, after the known texts, in the order that it had. The case of the known texts counts: `OIDC` is not `oidc`.
expect {
	Code.via_sort(["future", "ingest", "oidc"]) == ["oidc", "ingest", "future"] and Code.via_sort(["ingest", "future"]) == ["ingest", "future"] and Code.via_sort(["future"]) == ["future"] and Code.via_sort(["OIDC", "poll"]) == ["poll", "OIDC"]
}

# Slice 122, Q342 (Design), R-AP49: two or more unknown texts go after the known ones in ascending byte order of the UTF-8 text, whatever the input order. `Z` (0x5A) comes before `a` (0x61), a short text before a longer one with the same start.
expect {
	want = ["oidc", "ingest", "aa", "zz"]
	inputs = [["zz", "ingest", "aa", "oidc"], ["aa", "zz", "oidc", "ingest"], ["oidc", "zz", "aa", "ingest"], ["ingest", "aa", "zz", "oidc"], ["zz", "aa", "ingest", "oidc"]]
	inputs.all(|i| Code.via_sort(i) == want) and Code.via_sort(["a", "Z", "ab", "poll", "webhook"]) == ["webhook", "poll", "Z", "a", "ab"] and Code.via_sort(["ab", "a", "Z"]) == ["Z", "a", "ab"]
}
