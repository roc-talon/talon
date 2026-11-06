## The types of the account routes (Registry R-AP35, R-AP37, R-CT8 to R-CT10, R-AP73; slice 104e). Pure. No Worker code uses them before slice 117.
## The member order of the encoders is the alphabetical order of the derived codec (a proposal, TW24: the Worker has no bytes for these yet). A time is milliseconds (R-AP50). The decoders follow R-AP51: all members are required (a time may be `null`), an unknown member is ignored.
Account :: [].{

	## `{id, login}`: the GitHub user id (an integer) and the login.
	Who : { id : U64, login : Str }

	## R-AP35 / R-CT10. `first_time` and `last_time` are `Err(None)` (null) for an account with no row.
	Tracker : {
		account : Account.Who,
		machines : U64,
		counted : U64,
		first : U64,
		agreed : U64,
		disagreed : U64,
		unconfirmed : U64,
		first_time : Try(U64, [None]),
		last_time : Try(U64, [None]),
	}

	## R-AP37 answer: the JWT of R-CT9, its expiry in milliseconds, the account.
	Token : { token : Str, expires_at : U64, account : Account.Who }

	## R-AP37 request: `{"github_token":".."}`.
	Login : { github_token : Str }

	encode_tracker : Account.Tracker -> Str
	encode_tracker = |_t| crash "todo"

	decode_tracker : Str -> Try(Account.Tracker, [BadJson(Str)])
	decode_tracker = |_text| crash "todo"

	encode_token : Account.Token -> Str
	encode_token = |_t| crash "todo"

	decode_token : Str -> Try(Account.Token, [BadJson(Str)])
	decode_token = |_text| crash "todo"

	encode_login : Account.Login -> Str
	encode_login = |_l| crash "todo"

	decode_login : Str -> Try(Account.Login, [BadJson(Str)])
	decode_login = |_text| crash "todo"
}
