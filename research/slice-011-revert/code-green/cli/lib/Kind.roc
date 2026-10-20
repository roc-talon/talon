## The failure kinds and their exit codes (CLI 3, R-EC0 to R-EC21).
## `Done` is the kind `ok`. Talon never reuses a code (R-E5).
Kind := [Done, Internal, Usage, NoTuple, AppError, Budget, Consent, Frozen, Network, Integrity, Conflict, Environment, Input, Rejected, Findings].{
	is_eq : _

	## The exit code of a kind (the table of CLI 3).
	code : Kind -> I32
	code = |kind| match kind {
		Done => 0
		Internal => 1
		Usage => 2
		NoTuple => 10
		AppError => 11
		Budget => 12
		Consent => 13
		Frozen => 14
		Network => 15
		Integrity => 16
		Conflict => 17
		Environment => 18
		Input => 19
		Rejected => 20
		Findings => 21
	}

	## The name of a kind in `tln: error[<kind>]` and in `--json` (the table of CLI 3).
	name : Kind -> Str
	name = |kind| match kind {
		Done => "ok"
		Internal => "internal"
		Usage => "usage"
		NoTuple => "no_tuple"
		AppError => "app_error"
		Budget => "budget"
		Consent => "consent"
		Frozen => "frozen"
		Network => "network"
		Integrity => "integrity"
		Conflict => "conflict"
		Environment => "environment"
		Input => "input"
		Rejected => "rejected"
		Findings => "findings"
	}
}
