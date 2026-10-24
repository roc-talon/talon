import Fail
import Fx
import Clock
import Github
import JsonDoc
import Net
import Roots
import Selector
import Text

## The list of compiler releases in `direct` mode (CLI 6.2, R-CV1 to R-CV3, R-CV7, R-CV8; Resolution 1, R-NS1; CLI 2, R-SC10, R-SC11, R-SC13).
## The source is the release list of `roc-lang/nightlies`, which `Github.releases!` reads (R-DI2). P0 has no compiler release (R-NS2), so each
## entry is a nightly. These are pure decisions over the text of the pages, one fetch, and the choice of one compiler by the text of an argument of `tln roc`.
## No command uses this module yet (slice 021 and later). `flowprobe nightlies` and `flowprobe compiler` stand in for them.
Nightlies :: [].{

	## A host that has compiler assets (R-CV8). A nightly can lack the asset of a host (the newer nightlies have no `windows_arm64` asset): then it is not a candidate on that host (R-CV2).
	Host : [LinuxX64, LinuxArm64, MacosApple, MacosX64, WindowsX64, WindowsArm64]

	## The asset of a nightly for one host (R-CV2, R-CV3). `url` is `browser_download_url` of the answer: a fake API gives a loopback URL (R-EV19).
	## `sha256` is the 64 hex digits of the `digest` field (`sha256:<hex>`). `Err(None)` is a missing, null or other digest: the install stops with exit 16 (R-CV4, slice 021).
	Asset : { name : Str, url : Str, size : U64, sha256 : Try(Str, [None]) }

	## One nightly of the list. `id` is the tag text (R-CV1). `published_at` is in seconds since the epoch (R-DI10). `asset` is the asset for the host of the call:
	## `NoAsset` (a nightly with no asset for the host is not a candidate on that host, R-CV2) or `Several(n)` (2 or more assets: not a candidate, R-CV2).
	Release : { id : Str, published_at : U64, asset : Try(Asset, [NoAsset, Several(U64)]) }

	## R-CV8: the `<target>` of a host in the name of an asset (`roc_nightly-<target>-...`).
	##
	## | Host | Target |
	## | --- | --- |
	## | `LinuxX64` | `linux_x86_64` |
	## | `LinuxArm64` | `linux_arm64` |
	## | `MacosApple` | `macos_apple_silicon` |
	## | `MacosX64` | `macos_x86_64` |
	## | `WindowsX64` | `windows_x86_64` |
	## | `WindowsArm64` | `windows_arm64` |
	target : Host -> Str
	target = |host| match host {
		LinuxX64 => "linux_x86_64"
		LinuxArm64 => "linux_arm64"
		MacosApple => "macos_apple_silicon"
		MacosX64 => "macos_x86_64"
		WindowsX64 => "windows_x86_64"
		WindowsArm64 => "windows_arm64"
	}

	## R-CV1: the parts of a nightly tag in one of the two forms that roc reads (Design 2): `nightly-2026-10-09-258ab27`, and the month as an English name,
	## `nightly-2026-July-31-123c5d7`. The month name has a capital letter and is in full (`January` to `December`). `month` is the number 1 to 12.
	## The sha is 7 or more hex digits, as `Selector` reads it. Any other text is `Err(NotNightly)`. The form is not kept: two tags of the other form with equal date and
	## sha name the same nightly (R-CV1).
	parts : Str -> Try({ year : U64, month : U64, day : U64, sha : Str }, [NotNightly])
	parts = |tag| match tag.split_on("-") {
		["nightly", year, month, day, sha] if Selector.parse(tag, Bool.False) == Ok(Nightly(tag)) => match (U64.from_str(year), month_number(month), U64.from_str(day)) {
			(Ok(y), Ok(m), Ok(d)) => Ok({ year: y, month: m, day: d, sha })
			_ => Err(NotNightly)
		}
		_ => Err(NotNightly)
	}

	## R-CV1, R-CV2, R-CV3, R-DI3, R-NS1: the nightlies of the pages of the release list (the texts that `Github.releases!` gives, in order), for one host.
	##
	## A release of a page (a JSON object):
	##
	## | Field | Use |
	## | --- | --- |
	## | `tag_name` | A text. A tag that `parts` does not read is not a compiler and is skipped, with no warning. |
	## | `draft`, `prerelease` | `true` skips the release (R-DI3 applies, R-CV1) |
	## | `published_at` | `YYYY-MM-DDTHH:MM:SSZ` (R-DI10). Not read for a skipped release. |
	## | `assets` | A list of objects. Each has `name`, `size`, `digest` and `browser_download_url`. Other fields are not read. A release with no `assets` has no asset. |
	##
	## The asset (R-CV2): the assets whose name starts with `roc_nightly-<target>-` (the `-` after the target is part of the prefix) and ends with `.tar.gz`, or `.zip`
	## for `WindowsX64` and `WindowsArm64`. The date and the sha in the asset name are not compared with the tag. Other assets are not compilers (`roc_nightly-source-*`, `*.wasm.zst`).
	## One match: `Ok(asset)`. None: `Err(NoAsset)`. 2 or more: `Err(Several(n))`. The release stays in the list in each case.
	## The sha256 (R-CV3): the `digest` of that asset. A text `sha256:` and 64 hex digits (lower case) gives the digits. A null, a missing field, another algorithm and any other text give `Err(None)`.
	##
	## A page that is not a JSON array of objects, a release with no text `tag_name`, and a nightly that is not a draft or a prerelease and has no `published_at`
	## that `Clock.parse_utc` reads, are `Err(BadPage(n))`, with `n` the 1-based number of the page. The result is in the order of `order` (R-NS1).
	releases : { host : Host, pages : List(Str) } -> Try(List(Release), [BadPage(U64)])
	releases = |facts| facts.pages
		.map_with_index(|text, i| (i + 1, text))
		.fold_try(
			[],
			|found, (n, text)| match JsonDoc.parse(text) {
				Ok(Arr(items)) => items.fold_try(found, |acc, doc| read_release(facts.host, acc, doc).map_err(|_| BadPage(n)))
				_ => Err(BadPage(n))
			},
		)
		.map_ok(Nightlies.order)

	## R-NS1: the order of the nightlies, the oldest first. The date of the tag first (year, month number, day: the month name is read as its number, not as text).
	## On the same date: `published_at`, then the tag text in byte order. A later date is later also when its `published_at` is earlier.
	## (A release of a compiler that is no nightly has the date of its `published_at`, and is newer on the same date. P0 has none.)
	order : List(Release) -> List(Release)
	order = |list| list.sort_with(
		|a, b| match compare_numbers(sort_key(a), sort_key(b)) {
			Same => Text.compare(a.id, b.id)
			other => other
		},
	)

	## R-C7 for compilers (R-NS3: where Talon selects a compiler by itself): hides the nightlies that are too new. A nightly is visible when it is at least
	## `min_age` seconds old (`now - published_at >= min_age`: "at least 2 days old", R-RU1) and, when there is a `snapshot` time, it is not later than it (R-DT4: a
	## release published after that time is hidden). `min_age` 0 hides nothing (`"0d"`). `keep` are ids that are never hidden (R-C9: the value that a pin has now).
	## The order of `list` stays. A user that names a compiler is not limited by this (R-NS4, R-C7): `pick` takes the full list for names.
	visible : { list : List(Release), now : U64, min_age : U64, snapshot : Try(U64, [None]), keep : List(Str) } -> List(Release)
	visible = |facts| facts.list.keep_if(
		|r| {
			age = if facts.now >= r.published_at facts.now - r.published_at else 0
			not_after = match facts.snapshot {
				Ok(at) => r.published_at <= at
				Err(None) => Bool.True
			}
			facts.keep.contains(r.id) or (age >= facts.min_age and not_after)
		},
	)

	## R-CV2, R-CV8: the candidates on the host of `releases`: the nightlies with one asset (`asset` is `Ok`). A nightly with no asset or with 2 or more is not a candidate.
	## The order of `list` stays. A command builds `named` and `auto` of `pick` from the candidates only (`auto` is `visible` of the candidates): a nightly that cannot be installed on
	## the host is not named, not the newest and not a step (the review of slice 020, Q1).
	candidates : List(Release) -> List(Release)
	candidates = |list| list.keep_if(|r| r.asset.is_ok())

	## Why `pick` found no compiler.
	##
	## | Tag | Case |
	## | --- | --- |
	## | `Empty` | `@latest` and the domain `auto` has no compiler |
	## | `NoMatch(text)` | No id matches the text |
	## | `Ambiguous({ text, ids })` | The prefix matches 2 or more ids. `ids` are those ids in the order of `named`. |
	## | `NoBase` | A relative step, and no compiler is selected (R-SO14) |
	## | `BaseNotListed(id)` | A relative step, and the selected compiler `id` is not in `auto` (question Q3) |
	## | `OutOfRange({ base, step })` | The step goes past the oldest or the newest compiler of `auto` |
	PickError : [Empty, NoMatch(Str), Ambiguous({ text : Str, ids : List(Str) }), NoBase, BaseNotListed(Str), OutOfRange({ base : Str, step : I64 })]

	## R-SC10, R-SC11, R-SC13, R-SL5, R-SL7, R-SL6, R-CV1, R-NS1: the full id of the compiler that an argument of `tln roc ...` (or `roc +<id>`) names.
	## Talon stores only full ids, so the caller writes the result and never the text.
	##
	## `named` are the ids that a user can name, in the order of R-NS1 (the full list: the switch and `min-release-age` do not limit a name, R-NS4, R-C7).
	## `auto` are the ids that Talon can select by itself, in the order of R-NS1 (after the nightly switch, `visible` and the range: R-NS3, R-C7).
	## `base` is the compiler that Resolution 13 selects in the current directory, for a relative step.
	##
	## One leading `@` of `text` is read and dropped. Then:
	##
	## | Text | Result |
	## | --- | --- |
	## | `latest` (after `@`) | The last id of `auto` (R-SL5, R-NS3). `Err(Empty)` for an empty `auto`. |
	## | A step `-N` or `+N` (after `@`) | The id N places before (`-`) or after (`+`) `base` in `auto` (R-SL7). `base` is found as `canonical` finds an id. `Err(NoBase)`, `Err(BaseNotListed)`, `Err(OutOfRange)`. |
	## | A full nightly id that is in `named`, exact | That id |
	## | A full nightly id in the other form (date and sha equal) of an id of `named` | The id of `named`, so the tag text (R-CV1) |
	## | Any other text | A prefix (byte order, no change of case). One id of `named` has it: that id. None: `NoMatch`. 2 or more: `Ambiguous` (R-SC10) |
	pick : { text : Str, named : List(Str), auto : List(Str), base : Try(Str, [None]) } -> Try(Str, PickError)
	pick = |facts| {
		at = facts.text.starts_with("@")
		text = facts.text.drop_prefix("@")
		match (at, Selector.parse(text, Bool.False)) {
			(Bool.True, Ok(Latest)) => match facts.auto.last() {
				Ok(id) => Ok(id)
				Err(_) => Err(Empty)
			}
			(Bool.True, Ok(Step(n))) => step_from(facts.auto, facts.base, n)
			_ => by_name(facts.named, text)
		}
	}

	## The failure of a `PickError` (a proposal, TW24). The texts and kinds:
	##
	## | Error | Kind | Message |
	## | --- | --- | --- |
	## | `Empty` | `NoTuple` | `no compiler release is known` |
	## | `NoMatch("nightly-2026-11")` | `Usage` | `no compiler matches nightly-2026-11` |
	## | `Ambiguous` | `Usage` | `nightly-2026-09-01 matches 2 compilers: <id>, <id>. Use a longer prefix or the full id.` |
	## | `NoBase` | `Environment` | `no compiler is selected, so a relative step has no start. Run: tln roc install @latest and tln roc default <id>` |
	## | `BaseNotListed(id)` | `Usage` | `<id> is not in the list of compilers, so a relative step has no start` |
	## | `OutOfRange({ base, step })` | `Usage` | `no compiler is 1 step older than <base>`, `no compiler is 3 steps newer than <base>` |
	failure : PickError -> Fail
	failure = |error| match error {
		Empty => Fail.new(NoTuple, "no compiler release is known")
		NoMatch(text) => Fail.new(Usage, "no compiler matches ${text}")
		Ambiguous({ text, ids }) => Fail.new(Usage, "${text} matches ${ids.len().to_str()} compilers: ${Str.join_with(ids, ", ")}. Use a longer prefix or the full id.")
		NoBase => Fail.new(Environment, "no compiler is selected, so a relative step has no start. Run: tln roc install @latest and tln roc default <id>")
		BaseNotListed(id) => Fail.new(Usage, "${id} is not in the list of compilers, so a relative step has no start")
		OutOfRange({ base, step }) => {
			count = step.abs().to_str()
			steps = if step.abs() == 1 "1 step" else "${count} steps"
			way = if step < 0 "older" else "newer"
			Fail.new(Usage, "no compiler is ${steps} ${way} than ${base}")
		}
	}

	## The one fetch (R-CV1, R-DI2): `Github.releases!` for `roc-lang/nightlies`, then `releases`. The calls are those of `Github.releases!` (cache pages in
	## `talon/index/github/roc-lang/nightlies/`, no lock, R-CC11). `source` is the one of `Github.releases!`. A `BadPage(n)` is a failure of kind `Network`:
	## `page <n> of roc-lang/nightlies is not a release list`. A bad page is not cached (G3 of the review): `Github.releases!` does not write a page that is not a JSON array, so the next call asks the server again. With `Missing` the list is empty (the command decides, R-DI12).
	list! : Fx, { net : Net.Settings, roots : Roots, now : U64, offline : Bool, host : Host } => Try({ releases : List(Release), source : [Live, Cached(U64), Missing] }, Fail)
	list! = |fx, facts| {
		found = Github.releases!(fx, { net: facts.net, roots: facts.roots, owner: "roc-lang", repo: "nightlies", now: facts.now, offline: facts.offline })?
		match Nightlies.releases({ host: facts.host, pages: found.pages }) {
			Ok(list) => Ok({ releases: list, source: found.source })
			Err(BadPage(n)) => Err(Fail.new(Network, "page ${n.to_str()} of roc-lang/nightlies is not a release list"))
		}
	}
}

months : List(Str)
months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

# The number of a month in a tag: 2 digits, or the English name in full.
month_number : Str -> Try(U64, [NotMonth])
month_number = |text| match U64.from_str(text) {
	Ok(n) => Ok(n)
	Err(_) => match months.find_first_index(|name| name == text) {
		Ok(i) => Ok(i + 1)
		Err(_) => Err(NotMonth)
	}
}

# R-NS1: the date of the tag, then `published_at`.
sort_key : Nightlies.Release -> List(U64)
sort_key = |r| match Nightlies.parts(r.id) {
	Ok(p) => [p.year, p.month, p.day, r.published_at]
	Err(NotNightly) => [0, 0, 0, r.published_at]
}

compare_numbers : List(U64), List(U64) -> [Before, Same, After]
compare_numbers = |a, b| match (a, b) {
	([x, .. as xs], [y, .. as ys]) => if x < y Before else if x > y After else compare_numbers(xs, ys)
	_ => Same
}

field : List((Str, JsonDoc)), Str -> Try(JsonDoc, [NotFound])
field = |pairs, key| match pairs.find_first(|(k, _)| k == key) {
	Ok((_, value)) => Ok(value)
	Err(NotFound) => Err(NotFound)
}

is_true : List((Str, JsonDoc)), Str -> Bool
is_true = |pairs, key| match field(pairs, key) {
	Ok(Flag(b)) => b
	_ => Bool.False
}

text_field : List((Str, JsonDoc)), Str -> Str
text_field = |pairs, key| match field(pairs, key) {
	Ok(Text(t)) => t
	_ => ""
}

# One release of a page: the new list, or `Bad` for the cases of `BadPage`.
read_release : Nightlies.Host, List(Nightlies.Release), JsonDoc -> Try(List(Nightlies.Release), [Bad])
read_release = |host, found, doc| match doc {
	Obj(pairs) => {
		tag = match field(pairs, "tag_name") {
			Ok(Text(t)) => t
			_ => return Err(Bad)
		}
		skipped = is_true(pairs, "draft") or is_true(pairs, "prerelease") or Nightlies.parts(tag) == Err(NotNightly)
		if skipped {
			Ok(found)
		} else {
			published_at = match field(pairs, "published_at") {
				Ok(Text(t)) => Clock.parse_utc(t).map_err(|BadTime| Bad)?
				_ => return Err(Bad)
			}
			Ok(found.append({ id: tag, published_at, asset: asset_of(host, pairs) }))
		}
	}
	_ => Err(Bad)
}

# R-CV2: the one asset of the host, or the reason that there is none.
asset_of : Nightlies.Host, List((Str, JsonDoc)) -> Try(Nightlies.Asset, [NoAsset, Several(U64)])
asset_of = |host, pairs| {
	prefix = "roc_nightly-${Nightlies.target(host)}-"
	extension = match host {
		WindowsX64 | WindowsArm64 => ".zip"
		_ => ".tar.gz"
	}
	found = match field(pairs, "assets") {
		Ok(Arr(items)) => items.keep_oks(|item| read_asset(prefix, extension, item))
		_ => []
	}
	match found {
		[one] => Ok(one)
		[] => Err(NoAsset)
		many => Err(Several(many.len()))
	}
}

read_asset : Str, Str, JsonDoc -> Try(Nightlies.Asset, [NotAsset])
read_asset = |prefix, extension, doc| match doc {
	Obj(pairs) => {
		name = text_field(pairs, "name")
		if name.starts_with(prefix) and name.ends_with(extension) {
			size = match field(pairs, "size") {
				Ok(Num(n)) => if n >= 0 n.to_u64_wrap() else 0
				_ => 0
			}
			Ok({ name, url: text_field(pairs, "browser_download_url"), size, sha256: sha256_of(text_field(pairs, "digest")) })
		} else {
			Err(NotAsset)
		}
	}
	_ => Err(NotAsset)
}

# R-CV3: `sha256:` and 64 lower case hex digits give the digits.
sha256_of : Str -> Try(Str, [None])
sha256_of = |digest| {
	hex = digest.drop_prefix("sha256:")
	is_hex = |b| (b >= '0' and b <= '9') or (b >= 'a' and b <= 'f')
	if digest.starts_with("sha256:") and hex.count_utf8_bytes() == 64 and hex.to_utf8().all(is_hex) Ok(hex) else Err(None)
}

# R-CV1: two ids of the two tag forms name one nightly when the date and the sha are equal.
same_nightly : Str, Str -> Bool
same_nightly = |a, b| match (Nightlies.parts(a), Nightlies.parts(b)) {
	(Ok(x), Ok(y)) => x == y
	_ => Bool.False
}

# R-SL7: the id `n` places from `base` in `auto`.
step_from : List(Str), Try(Str, [None]), I64 -> Try(Str, Nightlies.PickError)
step_from = |auto, base, n| match base {
	Err(None) => Err(NoBase)
	Ok(b) => match auto.find_first_index(|id| id == b or same_nightly(id, b)) {
		Err(NotFound) => Err(BaseNotListed(b))
		Ok(i) => {
			from = auto.get(i) ?? b
			target = i.to_i64_wrap() + n
			if target < 0 {
				Err(OutOfRange({ base: from, step: n }))
			} else {
				match auto.get(target.to_u64_wrap()) {
					Ok(id) => Ok(id)
					Err(_) => Err(OutOfRange({ base: from, step: n }))
				}
			}
		}
	}
}

# R-SC10, R-SC13: a full id, the same nightly in the other tag form, or a prefix. The exact id wins over a longer id.
by_name : List(Str), Str -> Try(Str, Nightlies.PickError)
by_name = |named, text| {
	if text.is_empty() {
		Err(NoMatch(text))
	} else if named.contains(text) {
		Ok(text)
	} else {
		match named.find_first(|id| same_nightly(id, text)) {
			Ok(id) => Ok(id)
			Err(NotFound) => match named.keep_if(|id| id.starts_with(text)) {
				[] => Err(NoMatch(text))
				[one] => Ok(one)
				ids => Err(Ambiguous({ text, ids }))
			}
		}
	}
}
