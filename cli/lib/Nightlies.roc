import Age
import Channel
import Db
import Fail
import Fallback
import Facts
import Fx
import Clock
import Github
import Ident
import JsonDoc
import Net
import RegistryToolchains
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
	parts = |tag| Nightlies.parts_of("nightly-", tag)

	## R-CH4, R-CH5: the parts of a tag of the channel with the tag-prefix `tag_prefix`: `<tag-prefix><YYYY-MM-DD>-<sha>`. The month name is read for the `nightly` table only (Design Q614 item 7).
	## A tag of another channel, a tag with more parts (`-safe`) and any other text is `Err(NotNightly)`.
	parts_of : Str, Str -> Try({ year : U64, month : U64, day : U64, sha : Str }, [NotNightly])
	parts_of = |tag_prefix, tag| match tag.drop_prefix(tag_prefix).split_on("-") {
		[year, month, day, sha] if tag.starts_with(tag_prefix) => Channel.date_of({ names: tag_prefix == "nightly-" }, year, month, day, sha).map_err(|_| NotNightly)
		_ => Err(NotNightly)
	}

	## R-CH5: the id of a tag. The id of a `nightly` tag is the tag text. For another channel it is `<name>-<date>-<sha>`: the tag-prefix is dropped and the name is put in its place.
	id_of : { name : Str, tag_prefix : Str, tag : Str } -> Try(Str, [NotBuild])
	id_of = |facts| match Nightlies.parts_of(facts.tag_prefix, facts.tag) {
		Ok(_) => if facts.name == "nightly" Ok(facts.tag) else Ok("${facts.name}-${facts.tag.drop_prefix(facts.tag_prefix)}")
		Err(NotNightly) => Err(NotBuild)
	}

	## R-CH4, R-CV2: the start of the name of a compiler asset: `roc_` and the tag-prefix and the target and `-`.
	asset_prefix : { tag_prefix : Str, host : Host } -> Str
	asset_prefix = |facts| "roc_${facts.tag_prefix}${Nightlies.target(facts.host)}-"

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
	releases = |facts| Nightlies.releases_of({ host: facts.host, pages: facts.pages, channel: { name: "nightly", tag_prefix: "nightly-" } })

	## R-CH4: as `releases`, for the channel `channel` (a `github-release` table). The id is `Nightlies.id_of`; the asset starts with `Nightlies.asset_prefix`.
	releases_of : { host : Host, pages : List(Str), channel : { name : Str, tag_prefix : Str, .. } } -> Try(List(Release), [BadPage(U64)])
	releases_of = |facts| facts.pages
		.map_with_index(|text, i| (i + 1, text))
		.fold_try(
			[],
			|found, (n, text)| match JsonDoc.parse(text) {
				Ok(Arr(items)) => items.fold_try(found, |acc, doc| read_release(facts.host, facts.channel, acc, doc).map_err(|_| BadPage(n)))
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
	## release published after that time is hidden). `min_age` 0 hides nothing (`"0d"`). A release whose name (`Age.compiler_name`) a pattern of `exclude` matches is not hidden by the age (R-C15); the snapshot still hides it. `keep` are ids that are never hidden (R-C9: the value that a pin has now).
	## The order of `list` stays. A user that names a compiler is not limited by this (R-NS4, R-C7): `pick` takes the full list for names.
	## R-CH9, R-C15: `channels` are the tables that give the name of a user-channel build (its `source`). `recorded` are the `source` values of the `.talon.json` of installed builds, used when no table has the name.
	visible : { list : List(Release), now : U64, min_age : U64, snapshot : Try(U64, [None]), keep : List(Str), exclude : List(Str), channels ?: List({ name : Str, source : Str, tag_prefix : Str }), recorded ?: List({ id : Str, source : Str }) } -> List(Release)
	visible = |facts| facts.list.keep_if(
		|r| {
			not_after = match facts.snapshot {
				Ok(at) => r.published_at <= at
				Err(None) => Bool.True
			}
			hidden = Age.hides({ now: facts.now, min_age: facts.min_age, published_at: r.published_at, exclude: facts.exclude, name: Age.compiler_name_in({ tables: facts.?channels ?? [], recorded: note_of(facts.?recorded ?? [], r.id) }, r.id) })
			facts.keep.contains(r.id) or (!hidden and not_after)
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

	## R-CV1: two ids of the two tag forms name one nightly when the date and the sha are equal.
	same_nightly : Str, Str -> Bool
	same_nightly = |a, b| match (Nightlies.parts(a), Nightlies.parts(b)) {
		(Ok(x), Ok(y)) => x == y
		_ => Bool.False
	}

	## R-CV6 (slice 030b): the rows to record for a list. One row for each release that has an asset for the host (`Ok(asset)`) and a sha256 (`asset.sha256` is `Ok`), in the order of `releases`:
	## `{ tag: <id>, target: Nightlies.target(host), sha256, source: GithubDigest }` (the source of `direct` mode, R-CV3). A release with `NoAsset`, `Several(n)` or no sha256 gives no row (R-CV4 stops an install of it).
	pins : { host : Host, releases : List(Release) } -> List(Db.Pinned)
	pins = |facts| pins_of(facts.host, facts.releases, GithubDigest)

	## R-CV6 (slice 030b): the list with no release that has a change. A release is dropped when `changed` has a row with its id as `now.tag`. The order of the other releases stays. The tag is compared as text.
	without_changed : { releases : List(Release), changed : List(Facts.Change) } -> List(Release)
	without_changed = |facts| facts.releases.keep_if(|release| !facts.changed.any(|change| change.now.tag == release.id))

	## R-CV6, R-C9 (review of slice 030b, Q1): the `auto` list for a relative step (`@-N`, `@+N`, R-SL7). An installed compiler whose tag changed stays in use, so it must stay a base for a step. `releases` are the releases
	## of the list (the candidates and the others, no changed tag), `dropped` are the releases that `without_changed` took out, `auto` are the ids of `Toolchain.domain`, `base` is `Base.selected!`.
	##
	## | Case | Result |
	## | --- | --- |
	## | `base` is `Err(None)`, or it is not a release of `dropped` (an id, or the same nightly in the other tag form, R-CV1) | `auto` as it is |
	## | `base` is a release of `dropped` | The ids of `releases` and `dropped` in the order of R-NS1 (`order`) that are in `auto`, and the id of that one dropped release in its place. No other dropped release is added, so a step never lands on a changed tag |
	auto_with_base : { releases : List(Release), dropped : List(Release), auto : List(Str), base : Try(Str, [None]) } -> List(Str)
	auto_with_base = |facts| match facts.base {
		Err(None) => facts.auto
		Ok(base) => match facts.dropped.find_first(|release| release.id == base or Nightlies.same_nightly(release.id, base)) {
			Err(_) => facts.auto
			Ok(back) => Nightlies.order(facts.releases.append(back)).map(|release| release.id).keep_if(|id| id == back.id or facts.auto.contains(id))
		}
	}

	## The one fetch (R-CV1, R-DI2): `Github.releases!` for `roc-lang/nightlies`, then `releases`. The calls are those of `Github.releases!` (cache pages in
	## `talon/index/github/roc-lang/nightlies/`, no lock, R-CC11). `source` is the one of `Github.releases!`. A `BadPage(n)` is a failure of kind `Network`:
	## `page <n> of roc-lang/nightlies is not a release list`. A bad page is not cached (G3 of the review): `Github.releases!` does not write a page that is not a JSON array, so the next call asks the server again. With `Missing` the list is empty (the command decides, R-DI12).
	##
	## Slice 030b (R-CV6, R-CV3): after `releases`, `Facts.pin_all!` gets the rows of `Nightlies.pins` (the calls of `compat.db` follow the calls of `Github.releases!`, for each list that is read, also a cached one).
	## `changed` is its result. `releases` is `Nightlies.without_changed`: a tag with a changed sha256 is no candidate for any command. `dropped` are the releases that it took out (the releases of the list with a tag of `changed`, in the order of `releases`). With `Missing` there is no row, so no call. The failure of `Facts.pin_all!` (`TooNew`, exit 19) is the failure of `list!`.
	list! : Fx, { net : Net.Settings, roots : Roots, now : U64, offline : Bool, host : Host } => Try({ releases : List(Release), source : [Live, Cached(U64), Missing], changed : List(Facts.Change), dropped : List(Release) }, Fail)
	list! = |fx, facts| {
		found = Github.releases!(fx, { net: facts.net, roots: facts.roots, owner: "roc-lang", repo: "nightlies", now: facts.now, offline: facts.offline })?
		match Nightlies.releases({ host: facts.host, pages: found.pages }) {
			Ok(list) => {
				changed = Facts.pin_all!(fx, { roots: facts.roots, listed: Nightlies.pins({ host: facts.host, releases: list }) })?
				kept = Nightlies.without_changed({ releases: list, changed })
				Ok({ releases: kept, source: found.source, changed, dropped: list.keep_if(|release| !kept.any(|k| k.id == release.id)) })
			}
			Err(BadPage(n)) => Err(Fail.new(Network, "page ${n.to_str()} of roc-lang/nightlies is not a release list"))
		}
	}

	## Slice 240 (R-CH4, R-CH16, R-CV3, R-CV6): the list of a user channel, as `list!`. The repo is the `source` of the table (`owner/repo`, as written). The pages are cached in `talon/index/github/<owner>/<repo>/`.
	## The rows of `compat.db` have the channel name and its `source`. The list is always `direct`: no registry is read.
	list_channel! : Fx, { net : Net.Settings, roots : Roots, now : U64, offline : Bool, host : Host, channel : { name : Str, source : Str, tag_prefix : Str } } => Try({ releases : List(Release), source : [Live, Cached(U64), Missing], changed : List(Facts.Change), dropped : List(Release), via : Nightlies.Source, fell : Try(Fallback.Fell, [None]) }, Fail)
	list_channel! = |fx, facts| {
		(owner, repo) = match facts.channel.source.split_on("/") {
			[o, r] => (o, r)
			_ => ("", "")
		}
		found = Github.releases!(fx, { net: facts.net, roots: facts.roots, owner, repo, now: facts.now, offline: facts.offline })?
		match Nightlies.releases_of({ host: facts.host, pages: found.pages, channel: facts.channel }) {
			Ok(list) => {
				listed = pins_of(facts.host, list, GithubChannel({ name: facts.channel.name, source: facts.channel.source }))
				changed = Facts.pin_all!(fx, { roots: facts.roots, listed })?
				kept = Nightlies.without_changed({ releases: list, changed })
				Ok(Nightlies.via({ releases: kept, source: found.source, changed, dropped: list.keep_if(|release| !kept.any(|k| k.id == release.id)) }, Direct, Err(None)))
			}
			Err(BadPage(n)) => Err(Fail.new(Network, "page ${n.to_str()} of ${facts.channel.source} is not a release list"))
		}
	}

	## Slice 204 (R-CV1, R-CV2, R-CV3, R-AP50): the nightlies of the host from the rows of a registry (`RegistryToolchains.visible` has already hidden the rows above `log:N`). Pure.
	## One release for each row with `target == Nightlies.target(host)` and a tag that `Nightlies.parts` reads (a row of another target gives no release on this host, as a nightly with no asset for it: R-CV2). Of two rows of one tag and target the row with the smaller `log_index` counts (any order in the list); the later one is dropped (`row_changes` sees it).
	## `id` is the tag, `published_at` is the row value in seconds (`published_at // 1000`: R-AP50 gives milliseconds, R-DI10 seconds). `asset` is `Ok` with `name` = `asset_name`, `size` = the row `size` (R-AP80; a row with size 0 is `Err(NoAsset)`, Q340), `url` = `https://github.com/roc-lang/nightlies/releases/download/<tag>/<asset_name>` (Q1 of slice 204),
	## and `sha256` = `Ok(<the row sha256>)` when it is 64 lower-case hex digits, else `Err(None)` (R-CV4 then stops an install). An `asset_name` that is not a safe path part (`Ident.safe_part`, R-CV2, R-SE18) gives `Err(NoAsset)`. The result is in the order of `order` (R-NS1).
	from_rows : { host : Host, rows : List(RegistryToolchains.Row) } -> List(Release)
	from_rows = |facts| {
		want = Nightlies.target(facts.host)
		mine = facts.rows.keep_if(|row| row.target == want and Nightlies.parts(row.tag).is_ok())
		first = mine.fold([], |acc, row| keep_first(acc, row))
		Nightlies.order(first.map(row_release))
	}

	## Slice 204 (R-CV3, R-CV5, R-CV6): as `pins`, with the source `Registry` (the sha256 comes from the registry, not from a GitHub `digest`). One row for each release with an asset and a sha256, in the order of `releases`.
	registry_pins : { host : Host, releases : List(Release) } -> List(Db.Pinned)
	registry_pins = |facts| pins_of(facts.host, facts.releases, Registry)

	## Slice 204b (R-CV6, R-IX4, Design Q222): the changes that two rows of one tag and one target make. The rows are those of the file (any order, all targets). Only a row is counted that
	## has `target == Nightlies.target(host)`, a tag that `Nightlies.parts` reads, an `asset_name` that is a safe path part, a size above 0 and a sha256 of 64 lower-case hex digits.
	## For each such row that is not the first of its tag and target (the first is the row with the smallest `log_index`): when its sha256 is not the one of the first row, one change `{ first, now }`.
	## `first` and `now` are the pins of the two rows (`tag`, `target`, `sha256`, source `Registry`). The changes are in the order of the later rows by `log_index`. A later row with the same sha256 gives none.
	## `list_registry!` adds these changes to `changed` and drops the release of each tag (`without_changed`): the later row is the mismatch of R-CV6 and the tag is no candidate (exit 16 where a command names it).
	row_changes : { host : Host, rows : List(RegistryToolchains.Row) } -> List(Facts.Change)
	row_changes = |facts| {
		want = Nightlies.target(facts.host)
		counted = facts.rows
			.keep_if(|row| row.target == want and Nightlies.parts(row.tag).is_ok() and Ident.safe_part(row.asset_name) and row.size > 0 and is_sha256(row.sha256))
			.sort_with(|a, b| compare_numbers([a.log_index], [b.log_index]))
		counted
			.fold(
				{ firsts: [], changes: [] },
				|acc, row| match acc.firsts.find_first(|o| o.tag == row.tag) {
					Err(_) => { firsts: acc.firsts.append(row), changes: acc.changes }
					Ok(first) => if first.sha256 == row.sha256 acc else { firsts: acc.firsts, changes: acc.changes.append({ first: row_pin(first), now: row_pin(row) }) }
				},
			)
			.changes
	}

	## Slice 204: the registry source of the list, next to `list!` (the GitHub source). `origin` is the registry, `version` the `tln` version, `log` is `--snapshot log:N` (R-AP19). A command picks the source: slice 206.
	## The calls: those of `RegistryToolchains.list!`, then (rows to releases with `RegistryToolchains.visible` and `from_rows`) `Facts.pin_all!` with `registry_pins`: the `compat.db` calls follow the registry calls, for the visible rows only (Q4 of slice 204: a hidden row is not seen), also for a list from the file.
	## `releases`, `changed` and `dropped` are as in `list!` (R-CV6: a tag with a changed sha256 is no candidate, whatever the source of the first sha256 was). `source` is the one of `RegistryToolchains.list!`. The failure of `RegistryToolchains.list!` or of `pin_all!` is the failure.
	list_registry! : Fx, { roots : Roots, origin : Str, version : Str, offline : Bool, host : Host, log : Try(U64, [None]), source ?: Str } => Try({ releases : List(Release), source : [Live, Cached(U64), Missing], changed : List(Facts.Change), dropped : List(Release) }, Fail)
	list_registry! = |fx, facts| {
		got = RegistryToolchains.list!(fx, { roots: facts.roots, origin: facts.origin, version: facts.version, offline: facts.offline, source: facts.?source ?? "" })?
		shown = RegistryToolchains.visible({ rows: got.rows, log: facts.log })
		found = Nightlies.from_rows({ host: facts.host, rows: shown })
		pinned = Facts.pin_all!(fx, { roots: facts.roots, listed: Nightlies.registry_pins({ host: facts.host, releases: found }) })?
		changed = pinned.concat(Nightlies.row_changes({ host: facts.host, rows: shown }))
		kept = Nightlies.without_changed({ releases: found, changed })
		Ok({ releases: kept, source: got.source, changed, dropped: found.keep_if(|release| !kept.any(|k| k.id == release.id)) })
	}

	## Slice 206e2 (R-CV1, R-IX4, R-CV5): where a command reads its compiler list. `Direct`: the GitHub list (`list!`). `Registry`: the rows of a registry (`list_registry!`, `log` is `--snapshot log:N`).
	## `kept` is true when the command has read the registry list once already: the read uses only the kept file (`offline` true, no request), so the command sends one `GET /v1/toolchains` (R-IX4).
	Source : [Direct, Registry({ origin : Str, version : Str, log : Try(U64, [None]), kept : Bool, source : Str, first : Bool })]

	## Slice 240 (R-CH16, R-CV3): the source of the list of the channel `name`. A user channel is always `Direct`. The `nightly` channel keeps the source of the run.
	source_for : Nightlies.Source, Str -> Nightlies.Source
	source_for = |source, name| if name == "nightly" source else Direct

	## Slice 206e2: the list of `source`: `list!` for `Direct`, `list_registry!` for `Registry` (offline when `kept`). The result and the failures are those of the function.
	## Slice 225 (R-RG9): `via` is the source that gave the list, for the `digest` of its rows (`digest_source`): `Direct` after a fall back.
	via : { releases : List(Release), source : [Live, Cached(U64), Missing], changed : List(Facts.Change), dropped : List(Release) }, Nightlies.Source, Try(Fallback.Fell, [None]) -> { releases : List(Release), source : [Live, Cached(U64), Missing], changed : List(Facts.Change), dropped : List(Release), via : Nightlies.Source, fell : Try(Fallback.Fell, [None]) }
	via = |got, via, fell| { releases: got.releases, source: got.source, changed: got.changed, dropped: got.dropped, via, fell }

	## Slice 240 (R-CH16): with `channel` the list is that of the user channel (`list_channel!` when `source_for` gives `Direct`, which it always does for a user channel).
	list_of! : Fx, { net : Net.Settings, roots : Roots, now : U64, offline : Bool, host : Host, source : Nightlies.Source, channel ?: { name : Str, source : Str, tag_prefix : Str } } => Try({ releases : List(Release), source : [Live, Cached(U64), Missing], changed : List(Facts.Change), dropped : List(Release), via : Nightlies.Source, fell : Try(Fallback.Fell, [None]) }, Fail)
	list_of! = |fx, facts| match facts.?channel {
		Ok(channel) => match Nightlies.source_for(facts.source, channel.name) {
			Direct => Nightlies.list_channel!(fx, { net: facts.net, roots: facts.roots, now: facts.now, offline: facts.offline, host: facts.host, channel })
			other => Nightlies.list_plain!(fx, { net: facts.net, roots: facts.roots, now: facts.now, offline: facts.offline, host: facts.host, source: other })
		}
		Err(_) => Nightlies.list_plain!(fx, { net: facts.net, roots: facts.roots, now: facts.now, offline: facts.offline, host: facts.host, source: facts.source })
	}

	list_plain! : Fx, { net : Net.Settings, roots : Roots, now : U64, offline : Bool, host : Host, source : Nightlies.Source } => Try({ releases : List(Release), source : [Live, Cached(U64), Missing], changed : List(Facts.Change), dropped : List(Release), via : Nightlies.Source, fell : Try(Fallback.Fell, [None]) }, Fail)
	list_plain! = |fx, facts| match facts.source {
		Direct => Ok(Nightlies.via(Nightlies.list!(fx, { net: facts.net, roots: facts.roots, now: facts.now, offline: facts.offline, host: facts.host })?, Direct, Err(None)))
		Registry(r) => match Nightlies.list_registry!(fx, { roots: facts.roots, origin: r.origin, version: r.version, offline: facts.offline or r.kept, host: facts.host, log: r.log, source: r.source }) {
			Ok(listed) => Ok(Nightlies.via(listed, facts.source, Err(None)))
			Err(fail) => {
				# R-RG9 (Design Q601): the first request of a run gives no answer from the built-in default: the list is the GitHub list. `--snapshot log:N` needs the registry.
				if r.log != Err(None) or !r.first return Err(fail)
				fell = Fallback.decide!(fx, fail, r.origin)?
				Ok(Nightlies.via(Nightlies.list!(fx, { net: facts.net, roots: facts.roots, now: facts.now, offline: facts.offline, host: facts.host })?, Direct, Ok(fell)))
			}
		}
	}

	## R-CV5 (slice 206e2): the `sha256_source` of a compiler of the list of `source`: `GithubDigest` for `Direct`, `Registry` for a registry row.
	digest_source : Nightlies.Source -> Db.Source
	digest_source = |source| match source {
		Direct => GithubDigest
		Registry(_) => Registry
	}
}

# The pin rows of a list: one for each release with an asset and a sha256, with the source of the list.
pins_of : Host, List(Release), Db.Source -> List(Db.Pinned)
pins_of = |host, list, source| list.keep_oks(
	|release| match release.asset {
		Ok(asset) => match asset.sha256 {
			Ok(sha256) => Ok({ tag: release.id, target: Nightlies.target(host), sha256, source })
			Err(None) => Err(NoRow)
		}
		Err(_) => Err(NoRow)
	},
)

# R-CV2, R-CV3, R-AP50: the release of one registry row. A row has `size` (0 is no asset, R-AP80) and no URL: the URL is the GitHub download of the tag (Q1 of slice 204).
row_release : RegistryToolchains.Row -> Release
row_release = |row| {
	sha = if is_sha256(row.sha256) Ok(row.sha256) else Err(None)
	url = "https://github.com/roc-lang/nightlies/releases/download/${row.tag}/${row.asset_name}"
	asset = if Ident.safe_part(row.asset_name) and row.size > 0 Ok({ name: row.asset_name, url, size: row.size, sha256: sha }) else Err(NoAsset)
	{ id: row.tag, published_at: row.published_at // 1000, asset }
}

# The pin of a registry row (R-CV6).
row_pin : RegistryToolchains.Row -> Db.Pinned
row_pin = |row| { tag: row.tag, target: row.target, sha256: row.sha256, source: Registry }

# One row for each tag: the row with the smaller `log_index` stays, wherever it is in the list. The place of a tag in `acc` stays.
keep_first : List(RegistryToolchains.Row), RegistryToolchains.Row -> List(RegistryToolchains.Row)
keep_first = |acc, row| match acc.find_first_index(|o| o.tag == row.tag) {
	Err(_) => acc.append(row)
	Ok(i) => match acc.get(i) {
		Ok(old) if row.log_index < old.log_index => acc.set(i, row) ?? acc
		_ => acc
	}
}

# 64 lower-case hex digits.
is_sha256 : Str -> Bool
is_sha256 = |text| text.count_utf8_bytes() == 64 and text.to_utf8().all(|b| (b >= '0' and b <= '9') or (b >= 'a' and b <= 'f'))

# The source that was recorded for an id, if any.
note_of : List({ id : Str, source : Str }), Str -> Try(Str, [None])
note_of = |recorded, id| match recorded.find_first(|r| r.id == id) {
	Ok(r) => Ok(r.source)
	Err(_) => Err(None)
}

# R-NS1: the date of the tag, then `published_at`.
sort_key : Nightlies.Release -> List(U64)
sort_key = |r| match Channel.parse_id(r.id) {
	Ok(p) => [p.year, p.month, p.day, r.published_at]
	Err(NotChannelId) => [0, 0, 0, r.published_at]
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
read_release : Nightlies.Host, { name : Str, tag_prefix : Str, .. }, List(Nightlies.Release), JsonDoc -> Try(List(Nightlies.Release), [Bad])
read_release = |host, channel, found, doc| match doc {
	Obj(pairs) => {
		tag = match field(pairs, "tag_name") {
			Ok(Text(t)) => t
			_ => return Err(Bad)
		}
		id = Nightlies.id_of({ name: channel.name, tag_prefix: channel.tag_prefix, tag })
		if is_true(pairs, "draft") or is_true(pairs, "prerelease") or id.is_err() {
			Ok(found)
		} else {
			published_at = match field(pairs, "published_at") {
				Ok(Text(t)) => Clock.parse_utc(t).map_err(|BadTime| Bad)?
				_ => return Err(Bad)
			}
			Ok(found.append({ id: id ?? tag, published_at, asset: asset_of(host, channel.tag_prefix, pairs) }))
		}
	}
	_ => Err(Bad)
}

# R-CV2: the one asset of the host, or the reason that there is none.
asset_of : Nightlies.Host, Str, List((Str, JsonDoc)) -> Try(Nightlies.Asset, [NoAsset, Several(U64)])
asset_of = |host, tag_prefix, pairs| {
	prefix = Nightlies.asset_prefix({ tag_prefix, host })
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
		if name.starts_with(prefix) and name.ends_with(extension) and Ident.safe_part(name) {
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

# R-SL7: the id `n` places from `base` in `auto`.
step_from : List(Str), Try(Str, [None]), I64 -> Try(Str, Nightlies.PickError)
step_from = |auto, base, n| match base {
	Err(None) => Err(NoBase)
	Ok(b) => match auto.find_first_index(|id| id == b or Nightlies.same_nightly(id, b)) {
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
		match named.find_first(|id| Nightlies.same_nightly(id, text)) {
			Ok(id) => Ok(id)
			Err(NotFound) => match named.keep_if(|id| id.starts_with(text)) {
				[] => Err(NoMatch(text))
				[one] => Ok(one)
				ids => Err(Ambiguous({ text, ids }))
			}
		}
	}
}
