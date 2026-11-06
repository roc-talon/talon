import Args
import Db
import Fail
import JsonDoc
import Opts

## The pure part of `tln probe --smoke <alias or release URL> [--target <t>]...` (slice 218b; Resolution 4 R-PB10, R-PB8, R-SM1, R-SM2, R-SM4, R-SM7; CLI 1 R-CM8, R-FL12; Design Q579). The command code is `ProbeSmokeFlow.run!`.
## The texts and the `data` members are a proposal (R-OUT2, TW24). The slice file `docs/slices/218b-probe-smoke.md` has the questions (TW17).
ProbeSmoke :: [].{

	## R-PB10: what the operand is. `Url` for a text that starts with `https://` or `http://` (a release URL, `http://` is for a loopback test server, TQ4), `Alias` for any other text without `.tar.zst` at its end.
	Operand : [Alias(Str), Url(Str)]

	## What `read` gives. `wanted` are the values of `--target`, in the order of the line (an empty list: each target of the platform header, R-PB10). `opts` is the result of `Opts.read` (`--slots`, `--allow-downloads`, `--probe-downloads`, `--registry`).
	Plan : { operand : ProbeSmoke.Operand, wanted : List(Str), opts : Opts }

	## R-PB10, R-FL12: the operand and the flags of a `probe` line that has `--smoke` or `--target`. `Args.parse` has checked that each flag is allowed for `probe`. The checks, in this order (kind `Usage`, exit 2; the texts are a proposal, TW24; the first fault gives the message, Design Q586: a line with 2 faults is not tested):
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | The failures of `Opts.read` | the texts of `Opts.read` | R-FL5, R-FL11 |
	## | 2 | `--target` without `--smoke` | `flag '--target' works only with --smoke` | R-FL12 |
	## | 3 | `--smoke` with `--range` | `tln probe --smoke cannot run with --range` | R-PB10 |
	## | 4 | `--smoke` with `--share` | `tln probe --smoke cannot run with --share` | R-PB10 |
	## | 5 | 2 operands or more | `tln probe --smoke takes one platform: a header alias or a release URL` | R-PB10 |
	## | 6 | No operand | `tln probe --smoke needs a header alias or a release URL` | R-PB10 |
	## | 7 | An operand that ends with `.tar.zst` and is not a URL (a bundle file) | `tln probe --smoke needs a header alias or a release URL, not a bundle file: the smoke app names the URL of the platform` | R-PB10, Q549 |
	## | 8 | A URL that `Ident.of_url` refuses (no `X.Y.Z` run, two runs, `0.0.0`, an unsafe hash: R-DI5) | `'<url>' is not a release URL: it needs one version X.Y.Z (R-DI5)` | R-PB10, R-DI5 |
	## | 9 | A URL operand with `--file` (a URL uses no project, Design Q591; the place in the order is a reading) | `flag '--file' does not work with a release URL: it uses no project` | R-PB10, R-FL6 |
	read : Args -> Try(ProbeSmoke.Plan, Fail)
	read = |_args| crash "todo: slice 218b"

	## R-PB10, Design Q586 to Q588: the targets to build, after the fetch. `text` is the text of the `main.roc` of the platform (the header), `given` the plan `wanted`, `what` the operand text for the messages. The rows, first match wins (kind `Usage`, exit 2, texts a proposal):
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | The header is not a platform (an app, a package, a text that does not parse) | `'<what>' is not a platform: tln probe --smoke builds the smoke app of a platform` |
	## | 2 | A platform with no target: `targets: {}`, or no `targets` section (Q587) | `'<what>' has no target to build: the header of the platform has no targets` |
	## | 3 | A name of `given` is not in the header list | `'<name>' is not a target of '<what>': it has the targets <a>, <b>` (the first such name in the order of `given`) |
	## | 4 | `given` is empty | the targets of the header, in source order (the order of `data.smoke`) |
	## | 5 | else | `given` in its order, a name that is given again only at its first place (Q588) |
	##
	pick : { text : Str, given : List(Str), what : Str } -> Try(List(Str), Fail)
	pick = |_x| crash "todo: slice 218b"

	## R-PB10, R-SM4, R-SM7: the word of a result, as `data.smoke` and the text write it: `pass`, `fail`, `hang`, `crash`, and `machine-error` for `Machine` (a result with an error of the build machine: no row in `smoke`), and `no-fact` for `NoFact` (R-P3: a build with no fact, no row).
	word : [Row(Db.Outcome), Machine, NoFact] -> Str
	word = |_result| crash "todo: slice 218b"

	## R-PB10, Design Q579, Q590: `{ "smoke": [ { "target", "result" } ] }`, one item for each target, in the order of the list (the order of the targets). The keys of an item are `target`, then `result` (a proposal). A new `data` member of a new mode: no new `schema` (R-J6).
	data : List({ target : Str, result : [Row(Db.Outcome), Machine, NoFact] }) -> JsonDoc
	data = |_items| crash "todo: slice 218b"

	## The human text, one line end after each line (a proposal): `smoke build of <label> on <compiler>:`, then `  <target>: <word>` for each target. `label` is `ProbeShow.label_of` of the node. With `--json` the text goes to stderr (R-OUT4, as `tln probe`).
	text : { label : Str, compiler : Str, items : List({ target : Str, result : [Row(Db.Outcome), Machine, NoFact] }) } -> Str
	text = |_x| crash "todo: slice 218b"
}
