import lib.Exit
import lib.Fail
import lib.Kind

KindTest :: [].{}

# R-EC0 R-EC1 R-EC2 R-EC10 R-EC11 R-EC12 R-EC13 R-EC14 R-EC15 R-EC16 R-EC17 R-EC18 R-EC19 R-EC20 R-EC21 R-E5:
# the table of CLI 3: each kind has its code and its name, and no code is used twice.
table : () -> List((Kind, I32, Str))
table = || [
	(Done, 0, "ok"),
	(Internal, 1, "internal"),
	(Usage, 2, "usage"),
	(NoTuple, 10, "no_tuple"),
	(AppError, 11, "app_error"),
	(Budget, 12, "budget"),
	(Consent, 13, "consent"),
	(Frozen, 14, "frozen"),
	(Network, 15, "network"),
	(Integrity, 16, "integrity"),
	(Conflict, 17, "conflict"),
	(Environment, 18, "environment"),
	(Input, 19, "input"),
	(Rejected, 20, "rejected"),
	(Findings, 21, "findings"),
]

# A top-level value would run at compile time and crash `roc check` on a stub, so the check is in the expect.
expect {
	bad_codes = table().keep_if(|(kind, code, name)| Kind.code(kind) != code or Kind.name(kind) != name)
	# R-E5: no code is used twice.
	codes = table().map(|(kind, _, _)| Kind.code(kind))
	dbg bad_codes
	bad_codes == [] and codes.fold(Set.empty(), |seen, c| seen.insert(c)).len() == codes.len()
}

# R-E1 R-E2: no child and no failure gives 0. A child with no Talon failure gives the code of the child.
# Failures give the lowest code, and a failure of kind Done does not count.
expect {
	f = |kind| Fail.new(kind, "x")
	codes = [
		Exit.choose({ failures: [], child: Err(NoChild) }),
		Exit.choose({ failures: [], child: Ok(13) }),
		Exit.choose({ failures: [], child: Ok(0) }),
		Exit.choose({ failures: [f(Network), f(Usage)], child: Err(NoChild) }),
		Exit.choose({ failures: [f(Consent), f(Network), f(Frozen)], child: Err(NoChild) }),
		Exit.choose({ failures: [f(Done), f(Network)], child: Err(NoChild) }),
		Exit.choose({ failures: [f(Done)], child: Err(NoChild) }),
	]
	dbg codes
	codes == [0, 13, 0, 2, 13, 15, 0]
}

# R-E4: the last stderr line of a Talon failure is `tln: error[<kind>]: <message>`, with no newline in `line`.
expect {
	lines = [
		Fail.line(Fail.new(Usage, "unknown command 'frobnicate'")),
		Fail.line(Fail.new(Consent, "1 compiler download needs consent")),
		Fail.line(Fail.new(NoTuple, "no tuple works")),
	]
	dbg lines
	lines == [
		"tln: error[usage]: unknown command 'frobnicate'",
		"tln: error[consent]: 1 compiler download needs consent",
		"tln: error[no_tuple]: no tuple works",
	]
}
