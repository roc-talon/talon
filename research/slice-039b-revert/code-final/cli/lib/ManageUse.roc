import Args
import Compiler
import Fail
import JsonDoc
import Locked
import Pin

## The pure decisions of `tln roc use` (slice 026b; split from `Manage` in slice 036b3). `RocUse` has the command code. Texts and `data` fields are a proposal (R-OUT2, TW24).
ManageUse :: [].{

	## R-CS1, R-U1 (slice 026b): the operand of `roc use`: one text, as typed (a full id, a prefix, `@latest`, a step `@-1`). The checks, in this order. Each failure has kind `Usage` (exit 2, R-EC2: a bad ref). The texts are a proposal (TW24).
	##
	## | # | Case | Message |
	## | --- | --- | --- |
	## | 1 | No operand | `tln roc use needs one compiler: a full id, a prefix, @latest or a step like @-1` |
	## | 2 | 2 operands or more | `tln roc use takes one compiler, got <n>` |
	## | 3 | The text starts with `git-`, `link-` or `copy-` (R-U1, R-R4, R-LK3) | `tln roc use does not take <text>: a git, link or copy build cannot be a pin. Use ROC_TOOLCHAIN or tln roc default for it.` |
	##
	## `--no-check` is not read here: `Args.parse` stops it for `roc use` with exit 2 (R-U4, R-EC2). The other flags that `roc use` has are `--file` and `--allow-downloads`.
	read_use : Args -> Try(Str, Fail)
	read_use = |args| match args.operands {
		[] => Err(Fail.new(Usage, "tln roc use needs one compiler: a full id, a prefix, @latest or a step like @-1"))
		[one] => if is_local_build(one) Err(use_refused(one)) else Ok(one)
		many => Err(Fail.new(Usage, "tln roc use takes one compiler, got ${many.len().to_str()}"))
	}

	## R-U1 (slice 026b): the check of the id that the operand named (an installed prefix or the list gave a full id). A pin is a nightly or a release (`Pin.is_id`). Any other id (`git-*`, `link-*`, `copy-*`, `debug-<sha>`) is the failure of row 3 of `read_use`.
	use_pinnable : Str -> Try({}, Fail)
	use_pinnable = |id| if Pin.is_id(id) Ok({}) else Err(use_refused(id))

	## R-CS1, R-U3, R-RP1, R-WS13, R-RP3, R-BL1 (slice 026b): what `roc use` does for each member file, in the order of `members`. `id` is the new compiler. `pin` is the `roc:` entry of the member. `fallback` is the compiler of a member that has no pin
	## (`ROC_TOOLCHAIN`, else the compiler that Resolution 13 selects: R-BL1).
	##
	## | Field | Holds |
	## | --- | --- |
	## | `baseline` | The compiler of the baseline check (R-BL1): the pin of the member, else `fallback` |
	## | `previous` | The pin of the member (`Err(NoPin)` for none) |
	## | `op` | `Ok(Pin(id))`: the edit of the header (`Locked.edit` sets the entry, or adds `roc: "<id>"` as the last entry: R-RP3). `Err(Same)`: the pin is `id` already (`Pin.same_id`, the other tag form of a nightly counts: R-H1, no rewrite). |
	##
	## A member with no pin when `fallback` is `Err(NoCompiler)` is the failure `Compiler.failure(NoCompiler)` (exit 18, R-SO14). The members may have different pins (R-WS4: `roc use` is the fix for it), so the baselines can differ.
	use_plan : { id : Str, members : List({ file : Str, pin : Try(Str, [NoPin]) }), fallback : Try(Str, [NoCompiler]) } -> Try(List(ManageUse.UseRow), Fail)
	use_plan = |facts| facts.members.map_try(
		|member| {
			baseline = match member.pin {
				Ok(pin) => pin
				Err(NoPin) => facts.fallback.map_err(|NoCompiler| Compiler.failure(NoCompiler))?
			}
			same = match member.pin {
				Ok(pin) => Pin.same_id(pin, facts.id)
				Err(NoPin) => Bool.False
			}
			Ok({ file: member.file, baseline, previous: member.pin, op: if same Err(Same) else Ok(Pin(facts.id)) })
		},
	)

	## One row of `use_plan`.
	UseRow : { file : Str, baseline : Str, previous : Try(Str, [NoPin]), op : Try(Locked.Op, [Same]) }

	## R-U6, R-OUT2 (slice 026b, a proposal): the note when `ROC_TOOLCHAIN` is set. A tln command has no compiler argument (rank 1 is for the proxy), so `ROC_TOOLCHAIN` is the one source that has a higher priority than the new pin (Resolution 13). The text, with no `note: ` prefix and no line end:
	## `ROC_TOOLCHAIN is <toolchain>. It has a higher priority than the new pin <id>, so it still selects the compiler. The pin is used when ROC_TOOLCHAIN is not set.`
	use_note : { toolchain : Str, id : Str } -> Str
	use_note = |facts| "ROC_TOOLCHAIN is ${facts.toolchain}. It has a higher priority than the new pin ${facts.id}, so it still selects the compiler. The pin is used when ROC_TOOLCHAIN is not set."

	## R-CS1, R-OUT2 (slice 026b, a proposal): the lines of `roc use` after the ladder, on stdout. `files` are the members that the command wrote, in the order of the write. `previous` is the old `roc:` entry of the member. Each element is one line with its `\n`:
	##
	## | Line | When |
	## | --- | --- |
	## | `<file>` | for each file |
	## | `  ~ roc: <old> -> <id>` | the member had a pin |
	## | `  + roc: <id>` | the member had no pin |
	## | `the roc pin is now <id>` | last, once |
	## | `the roc pin is already <id> in every member. Nothing was written.` | the only line, when `files` is empty (question Q7, review of slice 026b: no member needs a change) |
	##
	use_report : { id : Str, files : List({ file : Str, previous : Try(Str, [NoPin]) }) } -> List(Str)
	use_report = |facts| if facts.files.is_empty() {
		["the roc pin is already ${facts.id} in every member. Nothing was written.\n"]
	} else {
		lines = facts.files.map(
			|f| match f.previous {
				Ok(old) => ["${f.file}\n", "  ~ roc: ${old} -> ${facts.id}\n"]
				Err(NoPin) => ["${f.file}\n", "  + roc: ${facts.id}\n"]
			},
		)
		lines.join().append("the roc pin is now ${facts.id}\n")
	}

	## R-J3, R-J4, R-OUT4 (slice 026b, a proposal): the `data` of `roc use --json`, the keys in this order: `id` (the new pin), `files` (an array of `{ "path", "previous" }`, `previous` is the old pin as text or `null`), `probes` (the number of `roc` runs), `downloads` (the compilers that this run downloaded),
	## `check` (`"passed"`), `build` (`"passed"`, or `null` when no member is an app), `notes` (an array of texts).
	use_data : { id : Str, files : List({ file : Str, previous : Try(Str, [NoPin]) }), probes : U64, downloads : U64, built : Bool, notes : List(Str) } -> JsonDoc
	use_data = |facts| JsonDoc.Obj([
		("id", JsonDoc.Text(facts.id)),
		("files", JsonDoc.Arr(facts.files.map(|f| JsonDoc.Obj([("path", JsonDoc.Text(f.file)), ("previous", text_of(f.previous.map_err(|NoPin| None)))])))),
		("probes", JsonDoc.Num(facts.probes.to_i64_wrap())),
		("downloads", JsonDoc.Num(facts.downloads.to_i64_wrap())),
		("check", JsonDoc.Text("passed")),
		("build", if facts.built JsonDoc.Text("passed") else JsonDoc.Null),
		("notes", JsonDoc.Arr(facts.notes.map(|n| JsonDoc.Text(n)))),
	])
}

# R-U1: the operand names a git, link or copy build.
is_local_build : Str -> Bool
is_local_build = |text| text.starts_with("git-") or text.starts_with("link-") or text.starts_with("copy-")

use_refused : Str -> Fail
use_refused = |ref| Fail.new(Usage, "tln roc use does not take ${ref}: a git, link or copy build cannot be a pin. Use ROC_TOOLCHAIN or tln roc default for it.")

text_of : Try(Str, [None]) -> JsonDoc
text_of = |id| match id {
	Ok(text) => JsonDoc.Text(text)
	Err(None) => JsonDoc.Null
}
