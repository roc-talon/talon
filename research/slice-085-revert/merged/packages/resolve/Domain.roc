import semver.Semver
import semver.VersionReq

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
	values = |q| {
		parsed = with_header(q).keep_oks(|c| Semver.parse(c.version).map_ok(|v| (c, v)))
		visible = parsed.keep_if(|(c, v)| admits(q.ranges, v) and (is_header(q, c) or (!c.yanked and !hidden(q, c))))
		visible.sort_with(|(a, va), (b, vb)| order(q.rules.strategy, a, va, b, vb)).map(|(c, _)| c)
	}
}

# Rule 1: the header value is a candidate, also when the list lacks it.
with_header : Domain.Query -> List(Domain.Candidate)
with_header = |q| match q.current {
	Ok(cur) => if q.candidates.any(|c| c.id == cur.id) q.candidates else q.candidates.append({ id: cur.id, version: cur.version, published_at: 0, yanked: Bool.False })
	Err(None) => q.candidates
}

is_header : Domain.Query, Domain.Candidate -> Bool
is_header = |q, c| match q.current {
	Ok(cur) => cur.id == c.id
	Err(None) => Bool.False
}

# Rule 2: an intersection of ranges. A range that does not parse admits nothing.
admits : List(Str), Semver -> Bool
admits = |ranges, v| ranges.all(
	|text| match VersionReq.parse(text) {
		Ok(req) => req.matches(v)
		Err(_) => Bool.False
	},
)

# Rule 4: too young or after the snapshot, unless the user named the version (D12: both limits are inclusive).
hidden : Domain.Query, Domain.Candidate -> Bool
hidden = |q, c| {
	named = match q.named {
		Ok(version) => version == c.version
		Err(None) => Bool.False
	}
	late = match q.rules.snapshot {
		Ok(time) => c.published_at > time
		Err(None) => Bool.False
	}
	!named and (c.published_at + q.rules.min_age > q.rules.now or late)
}

# Rule 5: by version, then the byte order of the ids (D9).
order : [Highest, Lowest], Domain.Candidate, Semver, Domain.Candidate, Semver -> [Before, Same, After]
order = |strategy, a, va, b, vb| match va.order_relative_to(vb) {
	Before => if strategy == Highest After else Before
	After => if strategy == Highest Before else After
	Same => bytes(a.id.to_utf8(), b.id.to_utf8())
}

bytes : List(U8), List(U8) -> [Before, Same, After]
bytes = |a, b| match (a, b) {
	([x, .. as ra], [y, .. as rb]) => match x.order_relative_to(y) {
		Same => bytes(ra, rb)
		other => other
	}
	([], []) => Same
	([], _) => Before
	(_, []) => After
}
