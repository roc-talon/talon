## The domain of one variable (Resolution 1 and 2): the values that the solver may choose, best first. Pure (TESTING.md 2.2, part A). It is the part of the solver that reads no header fact.
##
## The rules, applied in this order to `candidates` (the releases of the group, from the index, in any order):
##
## | # | Rule | Source |
## | --- | --- | --- |
## | 1 | The header value (`current`) is added when no candidate has its `id` | R-C9 |
## | 2 | Each range of `ranges` admits the version (`VersionReq.matches`). The empty list admits each version. A version that does not parse is not a value. | R-C1 |
## | 3 | A `yanked` candidate is not a value, except the header value | R-C6, R-C9 |
## | 4 | A candidate that is too young (`published_at + min_age > now`) or later than the snapshot (`published_at > snapshot`) is not a value, except the header value and the candidate whose version is `named` | R-C7, R-C9 |
## | 5 | The order: `Highest` the highest version first, `Lowest` the lowest first. A version is compared as a semver. A tie (one version, two ids) is in the byte order of the ids. The order of the input does not change the result. | R-VA6, R-DT2 |
##
## The header value is in the domain of its variable also when it is yanked or too young, but a range still excludes it (R-C1). The kind of a release (R-C4) is a header fact, so `Solver` applies it.
Domain :: [].{

	## One release of a group. `id` is the URL of the release (it names the value). `version` is `X.Y.Z`. `published_at` is a time in seconds. `yanked`: yanked, withdrawn, a draft or a prerelease (R-C6).
	Candidate : { id : Str, version : Str, published_at : U64, yanked : Bool }

	## The rules that all variables of one resolve share: the time now, `min-release-age` in seconds (R-C7), the snapshot time (`Err(None)` for none) and the strategy (R-VA6).
	Rules : { now : U64, min_age : U64, snapshot : Try(U64, [None]), strategy : [Highest, Lowest] }

	## One variable: its candidates, its ranges (R-C1, in the text form of `talon.toml`), the header value (`Err(None)` for none, R-C9) and the exact version that the user named (`X@1.2.3`, R-C7).
	Query : { candidates : List(Domain.Candidate), ranges : List(Str), current : Try({ id : Str, version : Str }, [None]), named : Try(Str, [None]), rules : Domain.Rules }

	## The values of the variable (the table above), best first.
	values : Domain.Query -> List(Domain.Candidate)
	values = |_q| crash "todo"
}
