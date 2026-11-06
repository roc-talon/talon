import ClosureRequest
import Fail
import PrivacyGuard
import Vars

## The query step of a resolve command (slice 206b; Resolution R-AL2 step 2; CLI 1 R-RG1, R-RG2, R-RG7; CLI 7.3 R-DI1; Registry 4.1 R-AP16, R-AP74; Resolution 11 R-DT3).
## The registry of the run, the groups of the first closure query, the names that the privacy guard checks before it (R-RG4), and the snapshot of a run with a registry. All pure.
## The flow (`tln update`) calls them after the load of the project files (the text of `config.toml` is part of that read), then `PrivacyGuard.check!`, `ClosureIndex.query!`, `LogSnapshot.hide_above`,
## and sets `Request.index` to `Answer`. L0: `tests/unit/IndexqueryTest.roc`. L2: `tests/commands/cases/registry/al2-update-query`.
IndexQuery :: [].{

	## R-RG1, R-RG2, R-RG7 (rows 1 to 3, 6): the registry of a run. The first of `flag` (`--registry`), `env` (`TALON_REGISTRY`) and `config` (the key `registry` of `config.toml`) that is set wins. None set: `Direct` (the built-in default, R-RG2).
	## The text `direct` is `Direct`. Another text is read with `Registry.base`: `Registry(<base URL form>)`. `config.at` is `<path>:<line>` of the key.
	##
	## | Case | Result | Rule |
	## | --- | --- | --- |
	## | The winner is a text that `Registry.base` refuses, from `flag` | kind `Usage` (exit 2): `--registry '<text>' is not a registry URL. Use direct, an https:// URL, or an http:// URL of 127.0.0.1, [::1] or localhost, with no path.` | R-RG7 row 6 |
	## | The same, from `env` | kind `Usage` (exit 2): `TALON_REGISTRY '<text>' is not a registry URL. <the same second sentence>` | R-RG7 row 6 |
	## | `config` is set and `Registry.base` refuses it (also when `flag` or `env` wins: `config.toml` stops as each other key of R-TF4) | kind `Input` (exit 19): `<at>: registry: '<text>' is not a registry URL. <the same second sentence>` | R-RG7 row 6, R-TF4 |
	##
	## The texts are a proposal (TW24). A bad `TALON_REGISTRY` under a `--registry` that wins is not tested (open reading, see the slice file).
	setting : { flag : Try(Str, [Unset]), env : Try(Str, [Unset]), config : Try({ text : Str, at : Str }, [Unset]) } -> Try([Direct, Registry(Str)], Fail)
	setting = |_facts| crash "todo: slice 206b"

	## R-AP16, R-DI1, R-AP74 row 3: the `groups` of the first closure query. One group for each scoped variable that is `free` and has a `name` (the variables whose releases `direct` lists in the first search, `PickFlow.prepare!`), in the order of `scoped` (the order of the variables, R-VA6).
	## A held variable and a movable variable give no group: the first query does not hold the groups of the movable variables (R-SP23, R-AP16; the second query is slice 206d).
	##
	## | Member | Value |
	## | --- | --- |
	## | `group` | `variable.group.form` (the URL form, R-AP15) |
	## | `series` | `Ok(variable.group.series)` (a group is the URL form and the series, Design R-ID2). `any_series` (R-SP5, R-UP3: every series): `Err(None)`, so the answer has all series of the form |
	## | `range` | `ClosureRequest.join_ranges` of the `range` texts of `variable.ranges`, in order |
	groups : List(Vars.Scoped) -> List(ClosureRequest.Group)
	groups = |_scoped| crash "todo: slice 206b"

	## R-RG4: what the first closure query carries, as the sources of `PrivacyGuard.check!`: `Group(group)` for each group of the request, in order, then `Url(entry)` for each entry whose hash goes in `hashes` (an entry that `Ident.of_url` reads), in the order of `entries`.
	## A path entry and a text with no hash give no source. `PrivacyGuard.repos_to_check` makes each repository one check, in lower case, and drops other hosts.
	sources : { groups : List(ClosureRequest.Group), entries : List(Str) } -> List(PrivacyGuard.Source)
	sources = |_facts| crash "todo: slice 206b"

	## R-DT3, R-DT4, R-FL9, R-EV1: the snapshot of a run. `flag` is the text of `--snapshot`, `config` is `[resolution] snapshot` of `talon.toml` (`Intent`). The flag wins over the key.
	##
	## | Case | Result |
	## | --- | --- |
	## | No flag and no key | `None` |
	## | `log:<n>` (flag or key), `registry` true | `Log(n)` |
	## | `log:<n>` (flag or key), `registry` false | the failure of `Intent.direct_snapshot` (exit 2: `snapshot log:<n> needs a registry: direct has no log. Use a UTC time, for example 2026-10-12T00:00:00Z.`) |
	## | A UTC time (`Clock.parse_utc`), either mode | `Time(seconds)` |
	## | A flag text that is neither | the failure of `ResolveSelect` (exit 2: `--snapshot '<text>' is not a UTC time or log:<n>. Use a UTC time, for example 2026-10-12T00:00:00Z.`) |
	snapshot : { registry : Bool, flag : Try(Str, [Unset]), config : Try([Log(U64), Time(U64)], [Unset]) } -> Try([None, Time(U64), Log(U64)], Fail)
	snapshot = |_facts| crash "todo: slice 206b"
}
