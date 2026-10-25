import BuildSkip
import Db
import Fail
import Release
import header.Header

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
	is_name = |text| BuildTarget.names.contains(text)

	## R-TG1, R-C10: the names of the targets of the header of a platform release, in source order: the keys of the `targets: { ... }` record of the platform header, except `inputs_dir`.
	## The text of the file is the text that `Release.read` gets. A key of a nested record (`inputs`, `output`, `exports`), a word in a comment or in a string, and a key of another section never count.
	## `targets: {}` is `Ok([])`. A text with no `targets` section (an app, a package, an old platform, a header that does not parse) is `Err(NoSection)`.
	targets_of : Str -> Try(List(Str), [NoSection])
	targets_of = |text| match Header.parse(text) {
		Ok(header) => match header.kind() {
			Platform(_) => {
				span = header.span()
				toks = tokens(text.to_utf8().drop_first(span.start).take_first(span.end - span.start))
				match find_open(toks) {
					Ok(from) => Ok(keys_from(toks, from))
					Err(NoSection) => Err(NoSection)
				}
			}
			_ => Err(NoSection)
		}
		Err(_) => Err(NoSection)
	}

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
	host = |system| match (system.os, system.arch) {
		(Linux, X64) => ["x64musl", "x64glibc"]
		(Linux, Arm64) => ["arm64musl", "arm64glibc"]
		(Macos, X64) => ["x64mac"]
		(Macos, Arm64) => ["arm64mac"]
		(Windows, X64) => ["x64win"]
		_ => []
	}

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
	pick = |x| match x.project {
		Ok(name) => Ok(Named(name))
		Err(Unset) => match x.found {
			Err(NoSection) => Ok(Unlisted)
			Ok(list) => match x.host.find_first(|name| list.contains(name)) {
				Ok(name) => Ok(Named(name))
				Err(_) => match list {
					[one] => Ok(Named(one))
					_ => Err(Fail.new(Usage, none_text(x.file, list, x.host)))
				}
			}
		}
	}

	## R-P4, R-ID6, R-TG2: the key of a build fact (platform hash, compiler, target). `Named(t)` has the target `t` (also on a system with no host target). `Unlisted` is `BuildSkip.key` (`Err(Unknown)` for an unknown system).
	key : { pf : Str, nightly : Str, chosen : BuildTarget.Chosen, system : BuildSkip.System } -> Try(Db.Key, [Unknown])
	key = |x| match x.chosen {
		Named(name) => Ok({ hash: x.pf, nightly: x.nightly, target: name })
		Unlisted => BuildSkip.key({ pf: x.pf, nightly: x.nightly, system: x.system })
	}

	## R-C10: does a platform release admit the `[build] target` of the member? `wanted` is `[build] target`. `Ok(t)` with `found` `Ok(list)`: `list` has `t`. No `[build] target` (`Err(Unset)`): always `True` (rules 2 and 3 of R-TG1 take the target from the release itself). `found` `Err(NoSection)`: `True` (question Q1).
	admits : { wanted : Try(Str, [Unset]), found : Try(List(Str), [NoSection]) } -> Bool
	admits = |x| match (x.wanted, x.found) {
		(Ok(name), Ok(list)) => list.contains(name)
		_ => Bool.True
	}

	## A platform release URL and the target that a member wants of it (R-C10).
	Want : { url : Str, target : Str }

	## The target names that the command read from the header of a platform release (`targets_of`): `found`.
	Seen : { url : Str, found : Try(List(Str), [NoSection]) }

	## R-C10, R-TG5: what each platform release must have. `slots` are the variables of the choice: `urls` are its candidates and its `current`, `files` are the member files that name it (the empty list: every member, as `Pick.Slot.files`). A slot that is no platform gives nothing.
	## For each platform slot, each member of `files` (all `members` for the empty list) that has `Ok(target)` gives one `Want` for each URL of the slot. The order: the slots, then the URLs, then the members, no repeat.
	wanted : { slots : List({ is_platform : Bool, urls : List(Str), files : List(Str) }), members : List({ file : Str, target : Try(Str, [Unset]) }) } -> List(BuildTarget.Want)
	wanted = |x| x.slots
		.keep_if(|slot| slot.is_platform)
		.join_map(
			|slot| {
				members = x.members.keep_if(|m| slot.files.is_empty() or slot.files.contains(m.file)).keep_oks(|m| m.target)
				slot.urls.join_map(|url| members.map(|target| { url, target }))
			},
		)
		.fold([], |found, want| if found.contains(want) found else found.append(want))

	## R-C10, R-C4: the facts for the solver. A fact of a release of kind `Platform` whose URL has a `Want`, whose `seen` entry is `Ok(list)` and with a `Want.target` that `list` lacks, gets the kind `App`: the solver never takes an `App` release for a slot (R-C4), so the release is no candidate.
	## Every other fact is unchanged (a release with no `seen` entry, a `NoSection`, a package, a platform that has the target, a URL with no `Want`). A release with 2 `Want`s is excluded when it lacks one of them.
	gate : { facts : List({ url : Str, release : Release }), seen : List(BuildTarget.Seen), wanted : List(BuildTarget.Want) } -> List({ url : Str, release : Release })
	gate = |x| x.facts.map(|fact| if lacks_target(fact, x.seen, x.wanted) { url: fact.url, release: { kind: App, pf: fact.release.pf, deps: fact.release.deps } } else fact)

	## R-C10: the failure when no platform release has the build target (kind `NoTuple`, exit 10). `alias` is the alias of the platform slot. The text is a proposal (TW24):
	## `no tuple works: <alias> has no platform release with the build target <target> (R-C10). Change [build] target in talon.toml, or use a platform that has it.`
	no_release : { alias : Str, target : Str } -> Fail
	no_release = |x| Fail.new(NoTuple, "no tuple works: ${x.alias} has no platform release with the build target ${x.target} (R-C10). Change [build] target in talon.toml, or use a platform that has it.")
}

# R-C10: a platform release whose read list lacks one of the targets that members want of its URL.
lacks_target : { url : Str, release : Release }, List(BuildTarget.Seen), List(BuildTarget.Want) -> Bool
lacks_target = |fact, seen, wanted| match fact.release.kind {
	Platform => match seen.find_first(|s| s.url == fact.url) {
		Ok({ found: Ok(list), .. }) => wanted.any(|w| w.url == fact.url and !list.contains(w.target))
		_ => Bool.False
	}
	_ => Bool.False
}

# R-TG1 rule 5: the text of the exit 2.
none_text : Str, List(Str), List(Str) -> Str
none_text = |file, list, host| match list.first() {
	Ok(first) => "${file}: no build target: the platform has the targets ${Str.join_with(list, ", ")}, and none is the host target (${host_text(host)}). Set the target in the [build] table of talon.toml, for example: target = \"${first}\""
	Err(_) => "${file}: no build target: the platform has no targets. Set the target in the [build] table of talon.toml."
}

host_text : List(Str) -> Str
host_text = |host| if host.is_empty() "unknown host" else Str.join_with(host, ", ")

# The scan of a platform header (D6 of slice 054). A token is a word, a bracket, a colon or another byte. Comments and strings give no token.
Tok : [Word(Str), Open, Close, Colon, Other]

no_toks : List(Tok)
no_toks = []

no_names : List(Str)
no_names = []

no_open : Try(U64, [NoSection])
no_open = Err(NoSection)

at : List(U8), U64 -> U8
at = |bytes, i| bytes.get(i) ?? 0

tok_at : List(Tok), U64 -> Tok
tok_at = |toks, i| toks.get(i) ?? Other

is_word_byte : U8 -> Bool
is_word_byte = |b| (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9') or b == '_'

# The index after the string that starts at `start` (the quote), with `\` escapes.
string_end : List(U8), U64 -> U64
string_end = |bytes, start| {
	n = bytes.len()
	var $j = start + 1
	while $j < n and at(bytes, $j) != '"' {
		$j = if at(bytes, $j) == '\\' $j + 2 else $j + 1
	}
	$j + 1
}

word_end : List(U8), U64 -> U64
word_end = |bytes, start| {
	var $j = start
	while is_word_byte(at(bytes, $j)) {
		$j = $j + 1
	}
	$j
}

tokens : List(U8) -> List(Tok)
tokens = |bytes| {
	n = bytes.len()
	var $out = no_toks
	var $i = 0
	while $i < n {
		b = at(bytes, $i)
		if b == '#' {
			while $i < n and at(bytes, $i) != '\n' {
				$i = $i + 1
			}
		} else if b == '"' {
			$i = string_end(bytes, $i)
		} else if b == ' ' or b == '\t' or b == '\n' or b == '\r' {
			$i = $i + 1
		} else if is_word_byte(b) {
			end = word_end(bytes, $i)
			$out = $out.append(Word(Str.from_utf8_lossy(bytes.drop_first($i).take_first(end - $i))))
			$i = end
		} else {
			tok = if b == '{' or b == '[' or b == '(' Open else if b == '}' or b == ']' or b == ')' Close else if b == ':' Colon else Other
			$out = $out.append(tok)
			$i = $i + 1
		}
	}
	$out
}

# The index after `targets: {` at depth 0.
find_open : List(Tok) -> Try(U64, [NoSection])
find_open = |toks| {
	var $depth = 0.I64
	var $k = 0.U64
	var $found = no_open
	while $k < toks.len() and $found.is_err() {
		match tok_at(toks, $k) {
			Open => {
				$depth = $depth + 1
			}
			Close => {
				$depth = $depth - 1
			}
			Word("targets") if $depth == 0 => match (tok_at(toks, $k + 1), tok_at(toks, $k + 2)) {
				(Colon, Open) => {
					$found = Ok($k + 3)
				}
				_ => {}
			}
			_ => {}
		}
		$k = $k + 1
	}
	$found
}

# The keys at depth 1 of the record that `find_open` found, except `inputs_dir`.
keys_from : List(Tok), U64 -> List(Str)
keys_from = |toks, start| {
	var $depth = 1.I64
	var $k = start
	var $keys = no_names
	while $depth > 0 and $k < toks.len() {
		match tok_at(toks, $k) {
			Open => {
				$depth = $depth + 1
			}
			Close => {
				$depth = $depth - 1
			}
			Word(name) if $depth == 1 and name != "inputs_dir" => match tok_at(toks, $k + 1) {
				Colon => {
					$keys = $keys.append(name)
				}
				_ => {}
			}
			_ => {}
		}
		$k = $k + 1
	}
	$keys
}
