import Ident

## Prebuilt binaries of project tools (slices 091 and 092, CLI 6.4: R-PT17 to R-PT19, R-PT25, R-LY4). Part A (pure, TESTING.md 2.2). Slice 091 stubs: `crash "todo: slice 091"`.
## The check at lock time is `ToolBinCheck` (slice 092). The use is slice 093.
ToolBin :: [].{

	## One locked binary: the target and the sha256 of the file (64 lower case hex digits, R-PT18).
	Hash : { target : Str, sha256 : Str }

	## The value of `bin` of a `[tools]` entry (R-PT18): `Off` is `bin = false` (R-PT25), `Hashes` is a table (it can be empty: Talon checked, and no target passed). The list is in the text order of the targets.
	Lock : [Off, Hashes(List(ToolBin.Hash))]

	## The commands of R-PT19 that can write `bin`, and the ones that never do. `InstallNoUrl` is `install` of an entry with only `ref`. `InstallUrl` is `install` of an entry with a `url`. `Frozen` is `install --frozen`. `Run` is `tln run`. `X` is `tln x <key>`.
	Command : [AddTool, Update, Upgrade, InstallNoUrl, InstallUrl, Frozen, Run, X]

	## What a command does with `bin` (R-PT19): `Keep` writes nothing, `Drop` removes the table of `bin`, `Set` writes the table (the list is in the text order of the targets, also the empty list).
	Write : [Keep, Drop, Set(List(ToolBin.Hash))]

	## R-PT17: the 5 targets (R-HF10), in text order: `arm64mac`, `arm64musl`, `x64mac`, `x64musl`, `x64win`.
	all_targets : List(Str)
	all_targets = ["arm64mac", "arm64musl", "x64mac", "x64musl", "x64win"]

	## R-PT17: the name of the release asset of a prebuilt binary: `<hash>-<target>`, and `<hash>-x64win.exe` for `x64win`. `hash` is the text of the bundle name without `.tar.zst`.
	asset_name : { hash : Str, target : Str } -> Str
	asset_name = |facts| if facts.target == "x64win" "${facts.hash}-${facts.target}.exe" else "${facts.hash}-${facts.target}"

	## R-PT17: the download URL of that asset: the directory of the release `url` (Design 4.1), and the asset name. `NotRelease` when `url` is not a release URL with a version and a hash (`Ident.of_url`).
	asset_url : { url : Str, target : Str } -> Try(Str, [NotRelease])
	asset_url = |facts| match Ident.of_url(facts.url) {
		Err(Foreign) => Err(NotRelease)
		Ok(id) => match facts.url.split_last("/") {
			Ok({ before, .. }) => Ok("${before}/${ToolBin.asset_name({ hash: id.hash, target: facts.target })}")
			Err(_) => Err(NotRelease)
		}
	}

	## R-PT18: is the text a sha256 as `bin` has it? 64 lower case hex digits, no prefix.
	is_sha256 : Str -> Bool
	is_sha256 = |text| {
		bytes = text.to_utf8()
		bytes.len() == 64 and bytes.all(|b| (b >= '0' and b <= '9') or (b >= 'a' and b <= 'f'))
	}

	## R-PT25, R-LY4: do the two levels allow binaries for an entry? `machine` is `tool-binaries` of `config.toml` (`Unset`: true). `bin` is the `bin` of the entry. Not allowed when `machine` is `Ok(False)` (a `bin` table never overrides it) or `bin` is `Ok(Off)`.
	allowed : { machine : Try(Bool, [Unset]), bin : Try(ToolBin.Lock, [Unset]) } -> Bool
	allowed = |facts| {
		machine_off = facts.machine == Ok(Bool.False)
		project_off = facts.bin == Ok(Off)
		!machine_off and !project_off
	}

	## R-PT19: the targets that the check of R-PT20 must try for an entry whose `url` stays: the targets that have no value in `bin` (all 5 when `bin` is missing; none for `Off`), in text order.
	to_check : Try(ToolBin.Lock, [Unset]) -> List(Str)
	to_check = |bin| match bin {
		Ok(Off) => []
		Ok(Hashes(have)) => ToolBin.all_targets.keep_if(|t| !have.any(|h| h.target == t))
		Err(Unset) => ToolBin.all_targets
	}

	## R-PT19: the table after `update` or `upgrade` of a `url` that stays: every `old` value stays, as it is, and each `found` value for a target that has no `old` value is added. The list is in the text order of the targets.
	merge : { old : List(ToolBin.Hash), found : List(ToolBin.Hash) } -> List(ToolBin.Hash)
	merge = |facts| {
		pick = |list, t| list.find_first(|h| h.target == t)
		ToolBin.all_targets.keep_oks(
			|t| match pick(facts.old, t) {
				Ok(h) => Ok(h)
				Err(_) => pick(facts.found, t)
			},
		)
	}

	## R-PT19, R-PT25: what a command writes for `bin`. `url_changed` is true when the command writes a new `url` (a new entry too). `allowed` is `ToolBin.allowed`. `old` is the `bin` of the entry before the command. `ran` is the result of the check of R-PT20 (`NotRun`: no `gh`, a `gh` that is too old, or not allowed).
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | The command is `InstallUrl`, `Frozen`, `Run` or `X` | `Keep` |
	## | 2 | `old` is `Off` (no command writes, changes or removes `bin = false`) | `Keep` |
	## | 3 | Not allowed, or `ran` is `NotRun` | `Drop` when `url_changed` and `old` is a table (the old table belongs to the old `url`), else `Keep` |
	## | 4 | `ran` is `Ok(found)` and `url_changed` | `Set(found)`: also `Set([])` (`bin = {}`) |
	## | 5 | `ran` is `Ok(found)` and the `url` stays | `Set(merge)` when `merge` has a value that `old` has not, else `Keep` |
	write : { command : ToolBin.Command, url_changed : Bool, allowed : Bool, old : Try(ToolBin.Lock, [Unset]), ran : Try(List(ToolBin.Hash), [NotRun]) } -> ToolBin.Write
	write = |facts| {
		old_table = match facts.old {
			Ok(Hashes(have)) => Ok(have)
			_ => Err(NoTable)
		}
		if [InstallUrl, Frozen, Run, X].contains(facts.command) or facts.old == Ok(Off) {
			return Keep
		}
		match facts.ran {
			Err(NotRun) => no_check(facts, old_table)
			Ok(found) => if !facts.allowed {
				no_check(facts, old_table)
			} else if facts.url_changed {
				Set(found)
			} else {
				old = old_table ?? []
				merged = ToolBin.merge({ old, found })
				if merged.len() > old.len() Set(merged) else Keep
			}
		}
	}
}

# Case 3: no check, or not allowed. The old table belongs to the old `url`.
no_check = |facts, old_table| if facts.url_changed and old_table != Err(NoTable) Drop else Keep
