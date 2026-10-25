import Answer
import Args
import Fail
import Ref

## The line of the commands with `--tool` (slice 056, CLI 6.4: R-PT3, R-PT5, R-FL7, R-FL12): `tln add --tool owner/app[@sel] [--as <key>]`, `tln remove --tool <key>...`, `tln update --tool [<key>...]`, `tln upgrade --tool [<key>...]`. Part A (pure). `Args.parse` has checked that `--tool`
## is allowed for the command (R-FL12). This module reads the operands and checks the flags. The failures have the kind `Usage` (exit 2, R-EC2). The texts are proposals (TW24).
ToolsCmd :: [].{

	## What the line asks: `Add`, `Remove`, `Update` or `Upgrade` (the words of the command, with the flag `--tool`).
	Op : [Add, Remove, Update, Upgrade]

	## One line. `ref` is the operand of `Add` (`Ref.parse` with the scope `Tool`), `Err(None)` for the other commands. `keys` are the operands of `Remove`, `Update` and `Upgrade`: keys of `[tools]` (`[]` for `Update` and `Upgrade` means each tool). `as_key` is `--as`.
	## `snapshot` is the text of `--snapshot` (the form is checked by `Intent.direct_snapshot`, as for `install`), `dry_run` is `--dry-run`, `allow_downloads` is `--allow-downloads`: `Ok(Yes)` when set (R-NI5).
	Cmd : { op : Op, ref : Try(Ref, [None]), keys : List(Str), as_key : Try(Str, [Unset]), snapshot : Try(Str, [Unset]), dry_run : Bool, allow_downloads : Try(Answer, [NoFlag]) }

	## R-FL12: is this a line with `--tool`, and for which command? The command is the long form of `Args.command` (`["install"]` for `add`, `i` and `install`). A line with no `--tool` gives `Err(NoTool)`.
	## `--tool` is allowed for these four commands only (`Args.parse` checks it).
	op_of : Args -> Try(ToolsCmd.Op, [NoTool])
	op_of = |_args| crash "todo: slice 056"

	## R-PT3, R-FL7, R-FL12: the checks of a line with `--tool`, in this order. Each failure has the kind `Usage` (exit 2). `<typed>` is the command word as typed (`add`, `i`, `install`, `rm`, `up`).
	##
	## | # | Case | Message |
	## | --- | --- | --- |
	## | 1 | A flag that `--tool` does not take. It takes `--tool`, `--snapshot`, `--dry-run` and `--allow-downloads` (R-PT3), and `--as` for `add`. The global flags (`--json`, `--yes`, `--offline`, `--quiet`, `--file`, `--registry`) are not here | `flag '<flag>' is not for tln <typed> --tool. It takes only <the flags>` (`--snapshot, --dry-run and --allow-downloads`, with `--as, ` first for `add`) |
	## | 2 | `add` with no operand | `tln <typed> --tool needs one app: owner/app` |
	## | 3 | `add` with 2 or more operands (R-FL12: one name) | `tln <typed> --tool takes one app, got <n>` |
	## | 4 | `add`: `Ref.parse(operand, Scope.Tool, false)` fails | Its failure |
	## | 5 | `add`: the name is not `owner/app` (a short name or a host path: a tool is a GitHub release, R-PT1) | `'<name>' is not an owner/app name: tln <typed> --tool needs the full name` |
	## | 6 | `add`: a selector that is no version, range or `latest` (a git sha, R-PT1) | `'<sel>' in '<operand>' is not a release selector (a version, a range or latest)` |
	## | 7 | `add`: `--as` with a text that is not a key (R-PT1) | `'<text>' is not a key of [tools]: use lower case letters, digits, '.', '_' and '-', and start with a letter or a digit` |
	## | 8 | `remove` with no operand | `tln <typed> --tool needs a key of [tools]` |
	## | 9 | `remove`, `update`, `upgrade`: an operand that is not a key (a name with `@sel`, a name with a capital) | the message of row 7 with the operand |
	read : Args -> Try(ToolsCmd.Cmd, Fail)
	read = |_args| crash "todo: slice 056"

	## R-PT3, R-T28: the key of a new tool: `--as`, else the binary name of the app (the repo name of the full name: `Karakatiza666/roc-cloudflare-workers-cli` gives `roc-cloudflare-workers-cli`). A default that is not a key of `[tools]` (R-PT1: a capital letter) is a failure of kind `Usage`:
	## `the binary name '<name>' of <full name> is not a key of [tools]. Pass --as <key>`.
	key_of : { as_key : Try(Str, [Unset]), name : Str } -> Try(Str, Fail)
	key_of = |_facts| crash "todo: slice 056"

	## R-PT3: the failure of `add --tool` for a key that is in `[tools]` with another app (the same app acts as `update <key>`): kind `Usage`, `<key> is a tool of <other> in <path>. Pass --as <key> for another key, or run: tln remove --tool <key>`.
	key_taken : { path : Str, key : Str, other : Str } -> Fail
	key_taken = |_facts| crash "todo: slice 056"

	## R-PT3, R-PT5: the failure for a key that `[tools]` of `path` does not have (`remove`, `update --tool`, `upgrade --tool`): kind `Usage`, `no key '<key>' in [tools] of <path>. Keys: <key>, <key>.` (`none` for no key).
	no_key : { path : Str, key : Str, keys : List(Str) } -> Fail
	no_key = |_facts| crash "todo: slice 056"
}
