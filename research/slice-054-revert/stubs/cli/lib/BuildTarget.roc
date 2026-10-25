import BuildSkip
import Db
import Fail
import Release

## The build target of a project file (Resolution 4 "Build target": R-TG1 to R-TG3, R-TG5; Resolution 2: R-C10; slice 054). Part A (TESTING.md 2.2): pure decisions. The command code is `BuildFlow.before!` (ladder step 3) and `PickLoop` (R-C10).
## The texts are a proposal (R-OUT2, TW24): the human accepts or changes them at the review. A platform that has no `targets` list that Talon can read has the case `NoSection`: question Q1 of slice 054.
##
## ```mermaid
## flowchart TD
##     A["platform header text"] --> B["targets_of: the names of the targets"]
##     B --> C["pick: [build] target, else the host target, else the one target"]
##     C -->|"Named(t)"| D["roc build --target=t (LadderPlan.with_target), key target t (key)"]
##     C -->|"Unlisted"| E["roc build with no --target, key target = host (as before slice 054)"]
##     C -->|"exit 2"| F["no target: the message lists the targets"]
##     B --> G["admits, gate: a release without the [build] target is no candidate (R-C10)"]
## ```
BuildTarget :: [].{

	## The Roc targets (Registry R-IK7, the codes 1 to 35, `RocTarget` of nightly `258ab27`). `[build] target` is one of them (R-TG3). The code 0 (`any`) is no Roc target.
	names : List(Str)
	names = [
		"x64mac",
		"x64win",
		"x64mingw",
		"x64freebsd",
		"x64openbsd",
		"x64netbsd",
		"x64musl",
		"x64glibc",
		"x64linux",
		"x64elf",
		"x64v1mac",
		"x64v1win",
		"x64v1mingw",
		"x64v1freebsd",
		"x64v1openbsd",
		"x64v1netbsd",
		"x64v1musl",
		"x64v1glibc",
		"x64v1linux",
		"x64v1elf",
		"arm64mac",
		"arm64win",
		"arm64mingw",
		"arm64linux",
		"arm64musl",
		"arm64glibc",
		"arm64v1win",
		"arm64v1mingw",
		"arm64v1linux",
		"arm64v1musl",
		"arm64v1glibc",
		"arm32linux",
		"arm32musl",
		"wasm32",
		"wasm32v1",
	]

	## R-TG3: `text` is one of `names`, byte for byte (no case change, no space). Question Q2: a name that roc may add later is `false` here.
	is_name : Str -> Bool
	is_name = |_text| crash "todo: slice 054"

	## R-TG1, R-C10: the names of the targets of the header of a platform release, in source order: the keys of the `targets: { ... }` record of the platform header, except `inputs_dir`.
	## The text of the file is the text that `Release.read` gets. A key of a nested record (`inputs`, `output`, `exports`), a word in a comment or in a string, and a key of another section never count.
	## `targets: {}` is `Ok([])`. A text with no `targets` section (an app, a package, an old platform, a header that does not parse) is `Err(NoSection)`.
	targets_of : Str -> Try(List(Str), [NoSection])
	targets_of = |_text| crash "todo: slice 054"

	## R-TG1 rule 2: the host targets of a machine, in the order that `roc build` tries them with no `--target` (CLI 6.4, R-T8: the musl target, else the glibc target). The first has the same name as `BuildSkip.target`.
	##
	## | os | arch | host targets |
	## | --- | --- | --- |
	## | `Linux` | `X64` | `x64musl`, `x64glibc` |
	## | `Linux` | `Arm64` | `arm64musl`, `arm64glibc` |
	## | `Macos` | `X64` | `x64mac` |
	## | `Macos` | `Arm64` | `arm64mac` |
	## | `Windows` | `X64` | `x64win` |
	## | any other | | none |
	host : BuildSkip.System -> List(Str)
	host = |_system| crash "todo: slice 054"

	## The build target that `pick` found. `Named(t)`: `roc build --target=t`, and `t` is in the key of the build fact (R-TG2). `Unlisted`: no `--target`, and the key has the host target (`BuildSkip.target`): the case of question Q1.
	Chosen : [Named(Str), Unlisted]

	## R-TG1: the build target of an app project file. The first rule that holds wins:
	##
	## | # | Rule | Result |
	## | --- | --- | --- |
	## | 1 | `project` is `Ok(t)`: `[build] target` of the `talon.toml` of the member (also when `found` does not have it: R-C10 is the check) | `Ok(Named(t))` |
	## | 2 | `found` is `Ok(list)` and a name of `host` is in `list`: the first name of `host` that `list` has | `Ok(Named(name))` |
	## | 3 | `found` is `Ok([one])` | `Ok(Named(one))` |
	## | 4 | `found` is `Err(NoSection)` (question Q1) | `Ok(Unlisted)` |
	## | 5 | else (no name of `host` in `list`, and the list has no name or 2 or more) | `Err` of kind `Usage` (exit 2): `<file>: no build target: the platform has the targets <t>, <t> (none), and none is the host target (<h>, <h> or unknown). Set the target in the [build] table of talon.toml, for example: target = "<first target>"` |
	##
	## `file` is the project file (for the message). `<t>, <t>` are the names of `found` in source order joined with `, `, or `none`. `<h>` are the names of `host` joined with `, `, or `unknown` when `host` is empty.
	pick : { project : Try(Str, [Unset]), host : List(Str), found : Try(List(Str), [NoSection]), file : Str } -> Try(BuildTarget.Chosen, Fail)
	pick = |_x| crash "todo: slice 054"

	## R-P4, R-ID6, R-TG2: the key of a build fact (platform hash, compiler, target). `Named(t)` has the target `t` (also on a system with no host target). `Unlisted` is `BuildSkip.key` (`Err(Unknown)` for an unknown system).
	key : { pf : Str, nightly : Str, chosen : BuildTarget.Chosen, system : BuildSkip.System } -> Try(Db.Key, [Unknown])
	key = |_x| crash "todo: slice 054"

	## R-C10: does a platform release admit the `[build] target` of the member? `wanted` is `[build] target`. `Ok(t)` with `found` `Ok(list)`: `list` has `t`. No `[build] target` (`Err(Unset)`): always `True` (rules 2 and 3 of R-TG1 take the target from the release itself). `found` `Err(NoSection)`: `True` (question Q1).
	admits : { wanted : Try(Str, [Unset]), found : Try(List(Str), [NoSection]) } -> Bool
	admits = |_x| crash "todo: slice 054"

	## A platform release URL and the target that a member wants of it (R-C10).
	Want : { url : Str, target : Str }

	## The target names that the command read from the header of a platform release (`targets_of`): `found`.
	Seen : { url : Str, found : Try(List(Str), [NoSection]) }

	## R-C10, R-TG5: what each platform release must have. `slots` are the variables of the choice: `urls` are its candidates and its `current`, `files` are the member files that name it (the empty list: every member, as `Pick.Slot.files`). A slot that is no platform gives nothing.
	## For each platform slot, each member of `files` (all `members` for the empty list) that has `Ok(target)` gives one `Want` for each URL of the slot. The order: the slots, then the URLs, then the members, no repeat.
	wanted : { slots : List({ is_platform : Bool, urls : List(Str), files : List(Str) }), members : List({ file : Str, target : Try(Str, [Unset]) }) } -> List(BuildTarget.Want)
	wanted = |_x| crash "todo: slice 054"

	## R-C10, R-C4: the facts for the solver. A fact of a release of kind `Platform` whose URL has a `Want`, whose `seen` entry is `Ok(list)` and with a `Want.target` that `list` lacks, gets the kind `App`: the solver never takes an `App` release for a slot (R-C4), so the release is no candidate.
	## Every other fact is unchanged (a release with no `seen` entry, a `NoSection`, a package, a platform that has the target, a URL with no `Want`). A release with 2 `Want`s is excluded when it lacks one of them.
	gate : { facts : List({ url : Str, release : Release }), seen : List(BuildTarget.Seen), wanted : List(BuildTarget.Want) } -> List({ url : Str, release : Release })
	gate = |_x| crash "todo: slice 054"

	## R-C10: the failure when no platform release has the build target (kind `NoTuple`, exit 10). `alias` is the alias of the platform slot. The text is a proposal (TW24):
	## `no tuple works: <alias> has no platform release with the build target <target> (R-C10). Change [build] target in talon.toml, or use a platform that has it.`
	no_release : { alias : Str, target : Str } -> Fail
	no_release = |_x| crash "todo: slice 054"
}
