import records.Id

IdTest :: [].{}

# W0 tests of packages/records/Id.roc (slice 104). Expected values come from the design text and from `sha256sum` (python hashlib), not from the code.

bytes32 : List(U8)
bytes32 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]

# R-IK2: name_id is the first 8 bytes of SHA-256(kind byte, bytes) as a big-endian two's complement integer. Row 1 is the example of the design (case K8). Row 5 has the top bit clear (a positive id). Rows 4 and 5 are kind 1 with 32 bytes, as for a hash.
cases : List((U8, Str, I64))
cases = [
	(2, "github.com/roc-lang/unicode/releases/download/{v}/", -2687166099708853831),
	(3, "roc-lang/unicode", -3025687567124958779),
	(2, "", -2611607533499980659),
]

expect cases.map(|(k, text, _)| Id.name_id(k, text.to_utf8())) == cases.map(|(_, _, id)| id)

expect (Id.name_id(1, List.repeat(0, 32)) == 1908961002832976580) and (Id.name_id(1, bytes32) == 5265119941757224538)

# R-IK2: the kind byte keeps the kinds apart.
expect Id.name_id(2, "roc-lang/unicode".to_utf8()) != Id.name_id(3, "roc-lang/unicode".to_utf8())

# R-IK4: the id of a nightly is days * 2^28 + sha. Both tag forms give one id (R-CV1). 2026-10-09 is day 20735, 2026-10-14 is day 20740, 2024-02-29 is day 19782.
expect (Id.nightly_id("nightly-2026-10-09-258ab27") == Ok(5566048545575)) and (Id.nightly_id("nightly-2026-October-09-258ab27") == Ok(5566048545575)) and (Id.nightly_id("nightly-2026-10-14-38a3029") == Ok(5567410745385)) and (Id.nightly_id("nightly-2024-02-29-abcdef0") == Ok(5310370340592)) and (Id.nightly_id("nightly-2028-02-29-abcdef0") == Ok(5702554541808))

# R-IK4: the ids are in date order, and each is under 2^47.
expect {
	a = Id.nightly_id("nightly-2026-10-09-fffffff")
	b = Id.nightly_id("nightly-2026-10-10-0000000")
	match (a, b) {
		(Ok(x), Ok(y)) => x < y and y < 140737488355328
		_ => Bool.False
	}
}

# R-IK4 (Design Q75): a text that is not a nightly tag has no id: a sha of 6 or 8 digits or in upper case, a date that does not exist (2026-02-30, 2027-02-29), a 1-digit month or day, a month name in lower case or in capitals.
bad : List(Str)
bad = ["", "v1.0.0", "nightly-2026-10-09", "nightly-2026-13-09-258ab27", "nightly-2026-Octobre-09-258ab27", "nightly-2026-10-09-zzzzzzz", "nightly-2026-10-09-258ab2", "nightly-2026-10-09-258ab27f", "nightly-2026-10-09-258AB27", "nightly-2026-02-30-258ab27", "nightly-2026-1-09-258ab27", "nightly-2026-10-9-258ab27", "nightly-2026-october-09-258ab27", "nightly-2026-OCTOBER-09-258ab27", "nightly-2027-02-29-258ab27"]

expect bad.map(Id.nightly_id) == bad.map(|_| Err(NotANightly))
