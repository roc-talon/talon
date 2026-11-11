import lib.Channel

ChanneladdTest :: [].{}

# Slice 242 (docs/slices/242-channel-commands.md), R-CH12 R-CH13 (Design Q612, Q614, Q615). The pure decisions of `tln roc channel add`: the URL, the tag-prefix, the source conflict and the texts.
# New names for the code agent (a proposal, TW24; until they exist this file does not compile: red on purpose). E = { name : Str, source : Str, tag_prefix : Str }.
#   `Channel.source_of_url : Str -> Try(Str, [BadUrl])`   (R-CH12: the forms; the source keeps its case)
#   `Channel.url_text : Str -> { message : Str, hint : Str }`   (R-CH12: exit 2; the hint is the text of the design)
#   `Channel.prefix_of_tags : List(Str) -> Try(Str, [NoPrefix, Prefixes(List(Str))])`   (R-CH12: the tags of page 1; `Prefixes` is sorted with no double)
#   `Channel.prefix_text : [NoPrefix, Prefixes(List(Str))] -> Str`   (R-CH12: exit 2)
#   `Channel.source_conflict : { name : Str, source : Str, installed : List({ id : Str, source : Try(Str, [Unset]) }) } -> Try({}, [Conflict(Str)])`   (R-CH12: exit 19; the Str is the recorded source)
#   `Channel.conflict_text : { name : Str, source : Str, recorded : Str } -> { message : Str, hint : Str }`
#   `Channel.added_text : { path : Str, table : E, read : U64, newest : { id : Str, has_asset : Bool }, target : Str } -> Str`   (R-CH12: the print; no end of line at the end; the path is the real path, as `would remove $HOME/...` of other commands)
#   `Channel.copied_text : { path : Str, from : Str, table : E } -> Str`   (R-CH13: the print of `add <name>`)
#   `Channel.removed_text : { path : Str, name : Str } -> Str`   (R-CH13: the print of `rm`)

#   (Design Q617) `Channel.prefix_given : { given : Str, tags : List(Str) } -> Try(Str, [BadPrefix, NoTag])`   (item 3: exit 2 for both)
#   `Channel.given_text : { given : Str, kind : [BadPrefix, NoTag], source : Str } -> Str`
#   `Channel.exists_check : { name : Str, source : Str, config : List(E) } -> [Absent, Same, Other(Str)]`   (item 1; the Str is the source in config.toml)
#   `Channel.already_text : { name : Str, source : Str } -> Str`   (item 1: exit 0)
#   `Channel.exists_text : { name : Str, source : Str, existing : Str } -> { message : Str, hint : Str }`   (item 1: exit 2)
#   `Channel.copy_check : { name : Str, config : List(E), project : List(E) } -> [NoTable, Copy(E), Equal, Differ]`   (Q617 R-CH13 item 1: `Differ` is exit 19, the text of `Channel.compare`)
#   `Channel.rm_check : { name : Str, config : List(E) } -> [Found, Builtin, Missing]`   (R-CH13 item 2: `Builtin` and `Missing` are exit 2; `Missing` also covers a table that only the project has)
#   `Channel.rm_fail_text : { name : Str, kind : [Builtin, Missing], path : Str } -> Str`
#   `Channel.no_build_text : Str -> Str`   (Q618: the source; exit 2)
#   `Channel.added_json : ...`: the L2 case ch12-add-json fixes the `data` of `add`, `rm` (no L0 name).

# R-CH12: the forms of the URL. `https://github.com/<owner>/<repo>` with `/`, `/releases` or `/releases/tag/<tag>` at the end, and `<owner>/<repo>`. The source keeps its case.
# Any other form is `BadUrl`. The `source` follows R-CH4 (2 parts, no `.git`, no part that starts with `.`).
expect {
	rows = [
		("repo page", "https://github.com/Karakatiza666/roc-reify-nightlies", Ok("Karakatiza666/roc-reify-nightlies")),
		("a / at the end", "https://github.com/Karakatiza666/roc-reify-nightlies/", Ok("Karakatiza666/roc-reify-nightlies")),
		("/releases", "https://github.com/Karakatiza666/roc-reify-nightlies/releases", Ok("Karakatiza666/roc-reify-nightlies")),
		("/releases/tag/<tag>", "https://github.com/Karakatiza666/roc-reify-nightlies/releases/tag/nightly-reify-2026-11-03-1708298", Ok("Karakatiza666/roc-reify-nightlies")),
		("owner/repo", "Karakatiza666/roc-reify-nightlies", Ok("Karakatiza666/roc-reify-nightlies")),
		("the case and the dots stay", "https://github.com/Acme/Roc.Fork_2", Ok("Acme/Roc.Fork_2")),
		("http", "http://github.com/a/b", Err(BadUrl)),
		("another host", "https://gitlab.com/a/b", Err(BadUrl)),
		("a subdomain", "https://www.github.com/a/b", Err(BadUrl)),
		("no scheme, with the host", "github.com/a/b", Err(BadUrl)),
		("one part", "https://github.com/a", Err(BadUrl)),
		("one word", "a", Err(BadUrl)),
		("empty", "", Err(BadUrl)),
		("a page that is no form", "https://github.com/a/b/issues", Err(BadUrl)),
		("3 parts", "a/b/c", Err(BadUrl)),
		(".git", "https://github.com/a/b.git", Err(BadUrl)),
		("owner starts with a dot", "https://github.com/.a/b", Err(BadUrl)),
		("repo with a bad character", "a/b c", Err(BadUrl)),
	]
	bad = rows.keep_if(|(_, url, want)| Channel.source_of_url(url) != want).map(|(label, url, want)| (label, want, Channel.source_of_url(url)))
	dbg bad
	bad == []
}

# R-CH12: the failure for a URL that is not a form. Exit 2 is the work of the command. The hint is the text of the design.
expect {
	got = Channel.url_text("https://gitlab.com/o/r")
	dbg got
	got == { message: "https://gitlab.com/o/r is not a channel source", hint: "known channel sources: github.com/<owner>/<repo>" }
}

# R-CH12: the tag-prefix from the tags of page 1. A tag that ends with `<date>-<sha>` (4 digits, 2, 2, and 7 or more hex digits; the ISO date only, Q614 item 7) gives the text before the date.
# One prefix is the answer. A tag with another end is not read. 2 or more prefixes, or none, are the two failures (the list is sorted with no double).
expect {
	reify = ["nightly-reify-2026-11-03-1708298", "nightly-reify-2026-10-30-abc1234"]
	rows = [
		("one prefix", reify, Ok("nightly-reify-")),
		("a tag with another end is not read", reify.append("v1"), Ok("nightly-reify-")),
		("one tag", ["fork-2026-11-03-1111111"], Ok("fork-")),
		("no tag ends with a date and a sha", ["v1", "v2"], Err(NoPrefix)),
		("no tag", [], Err(NoPrefix)),
		("a month name is not a user date", ["nightly-2026-July-31-123c5d7"], Err(NoPrefix)),
		("a short sha", ["fork-2026-11-03-abc12"], Err(NoPrefix)),
		("a sha with no hex digits", ["fork-2026-11-03-zzzzzzz"], Err(NoPrefix)),
		("something after the sha", ["nightly-reify-2026-11-03-1708298-rc1"], Err(NoPrefix)),
		("Q617-3: a derived prefix with upper case does not count", ["Fork-2026-11-03-abc1234"], Err(NoPrefix)),
		("Q617-3: an empty prefix does not count", ["2026-11-03-abc1234"], Err(NoPrefix)),
		("Q617-3: an empty prefix and a good one: the good one", ["2026-11-03-abc1234", "fork-2026-11-03-1111111"], Ok("fork-")),
		("Q617-3: a prefix of 41 characters does not count", ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-2026-11-03-1111111"], Err(NoPrefix)),
		("Q617-3: a prefix of 40 characters counts", ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-2026-11-03-1111111"], Ok("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-")),
		("Q617-3: a bad prefix and 2 good ones: only the good ones are listed", ["Bad-2026-11-03-aaaaaaa", "x-2026-11-03-bbbbbbb", "y-2026-11-03-ccccccc"], Err(Prefixes(["x-", "y-"]))),
		("2 prefixes, sorted", ["nightly-reify-2026-11-03-1708298", "nightly-2026-11-02-aaaaaaa"], Err(Prefixes(["nightly-", "nightly-reify-"]))),
		("2 prefixes, 3 tags, no double", ["fork-b-2026-11-03-bbbbbbb", "fork-a-2026-11-04-aaaaaaa", "fork-b-2026-10-30-ccccccc"], Err(Prefixes(["fork-a-", "fork-b-"]))),
	]
	bad = rows.keep_if(|(_, tags, want)| Channel.prefix_of_tags(tags) != want).map(|(label, tags, want)| (label, want, Channel.prefix_of_tags(tags)))
	dbg bad
	bad == []
}

# R-CH12: the text of the two failures. The first one is the text of the design example (CLI 6.8 section 3).
expect {
	none = Channel.prefix_text(NoPrefix)
	two = Channel.prefix_text(Prefixes(["fork-a-", "fork-b-"]))
	three = Channel.prefix_text(Prefixes(["a-", "b-", "c-"]))
	dbg [none, two, three]
	none == "no release tag ends with <date>-<sha>. Pass --tag-prefix."
		and two == "release tags have 2 prefixes: fork-a-, fork-b-. Pass --tag-prefix."
			and three == "release tags have 3 prefixes: a-, b-, c-. Pass --tag-prefix."
}

# R-CH12 (exit 19): the installed ids of the name that record another source. The ids are read from the right (R-CH5): `my-fork-...` is of `my-fork`, not of `my`.
# An id with no recorded source (an old record) records no other source. The first other source in the order of the list is the answer.
expect {
	own = "Karakatiza666/roc-reify-nightlies"
	other = "someone-else/roc-reify-nightlies"
	check = |name, installed| Channel.source_conflict({ name, source: own, installed })
	rows = [
		("another source", check("reify", [{ id: "reify-2026-10-30-abc1234", source: Ok(other) }]), Err(Conflict(other))),
		("the same source", check("reify", [{ id: "reify-2026-10-30-abc1234", source: Ok(own) }]), Ok({})),
		("no source recorded", check("reify", [{ id: "reify-2026-10-30-abc1234", source: Err(Unset) }]), Ok({})),
		("an id of another name", check("reify", [{ id: "mine-2026-10-30-abc1234", source: Ok(other) }]), Ok({})),
		("a nightly id", check("reify", [{ id: "nightly-2026-10-14-38a3029", source: Err(Unset) }]), Ok({})),
		("the long name is not the short name", check("my", [{ id: "my-fork-2026-10-30-abc1234", source: Ok(other) }]), Ok({})),
		("the long name", check("my-fork", [{ id: "my-fork-2026-10-30-abc1234", source: Ok(other) }]), Err(Conflict(other))),
		("2 ids, the second differs", check("reify", [{ id: "reify-2026-10-30-abc1234", source: Ok(own) }, { id: "reify-2026-11-03-1708298", source: Ok(other) }]), Err(Conflict(other))),
		("no id", check("reify", []), Ok({})),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH12: the text of the exit 19 failure.
expect {
	got = Channel.conflict_text({ name: "reify", source: "Karakatiza666/roc-reify-nightlies", recorded: "someone-else/roc-reify-nightlies" })
	dbg got
	got
		== {
			message: "channel reify: installed builds record the source someone-else/roc-reify-nightlies, not Karakatiza666/roc-reify-nightlies",
			hint: "Remove them with tln roc remove <id>, or use another name.",
		}
}

# R-CH12: the print of `add <name> <URL>`. The first 6 lines and the last one are the design example (CLI 6.8 section 3, TW16); the example shows `~/...`; the tests use the real path, the form of the other commands (TW24).
# `release` is singular for 1. A newest build with no asset for the host has no `Install:` part (a proposal, TW24).
expect {
	table = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }
	path = "/h/.config/talon/config.toml"
	one = Channel.added_text({ path, table, read: 1, newest: { id: "reify-2026-11-03-1708298", has_asset: Bool.True }, target: "linux_x86_64" })
	three = Channel.added_text({ path, table, read: 3, newest: { id: "reify-2026-11-04-3333333", has_asset: Bool.False }, target: "linux_x86_64" })
	dbg [one, three]
	one
		== "read 1 release of github.com/Karakatiza666/roc-reify-nightlies\nadded channel reify to /h/.config/talon/config.toml:\n  [channels.reify]\n  shape = \"github-release\"\n  source = \"Karakatiza666/roc-reify-nightlies\"\n  tag-prefix = \"nightly-reify-\"\nnewest: reify-2026-11-03-1708298 (has linux_x86_64). Install: tln roc install reify"
		and three
			== "read 3 releases of github.com/Karakatiza666/roc-reify-nightlies\nadded channel reify to /h/.config/talon/config.toml:\n  [channels.reify]\n  shape = \"github-release\"\n  source = \"Karakatiza666/roc-reify-nightlies\"\n  tag-prefix = \"nightly-reify-\"\nnewest: reify-2026-11-04-3333333 (no asset for linux_x86_64)"
}

# R-CH13: the print of `add <name>` (a copy from the project) and of `rm`.
expect {
	table = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }
	copied = Channel.copied_text({ path: "/h/.config/talon/config.toml", from: "/p/talon.toml", table })
	removed = Channel.removed_text({ path: "/h/.config/talon/config.toml", name: "reify" })
	dbg [copied, removed]
	copied
		== "copied channel reify from /p/talon.toml to /h/.config/talon/config.toml:\n  [channels.reify]\n  shape = \"github-release\"\n  source = \"Karakatiza666/roc-reify-nightlies\"\n  tag-prefix = \"nightly-reify-\""
		and removed
			== "removed channel reify from /h/.config/talon/config.toml"
}

# R-CH12 Design Q617 item 3: `--tag-prefix <p>`. A value that breaks the R-CH4 form (`Channel.tag_prefix_check`) is `BadPrefix` (exit 2, before any request). Else a tag of page 1 must start with `<p>` and have `<date>-<sha>` after it; none: `NoTag` (exit 2).
expect {
	tags = ["fork-a-2026-11-04-aaaaaaa", "fork-b-2026-11-03-bbbbbbb", "fork-b-2026-10-30-ccccccc"]
	given = |p, t| Channel.prefix_given({ given: p, tags: t })
	rows = [
		("a tag has it", given("fork-b-", tags), Ok("fork-b-")),
		("no tag has it", given("zzz-", tags), Err(NoTag)),
		("a prefix of another prefix is not it", given("fork-", tags), Err(NoTag)),
		("no tag at all", given("fork-b-", []), Err(NoTag)),
		("no - at the end", given("fork-b", tags), Err(BadPrefix)),
		("upper case", given("Fork-b-", tags), Err(BadPrefix)),
		("empty", given("", tags), Err(BadPrefix)),
		("41 characters", given("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-", tags), Err(BadPrefix)),
		("a bad value comes before the tags", given("Bad_", []), Err(BadPrefix)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Design Q617 item 3: the texts of the two failures (exit 2; a proposal, TW24).
expect {
	a = Channel.given_text({ given: "Bad_", kind: BadPrefix, source: "o/r" })
	b = Channel.given_text({ given: "zzz-", kind: NoTag, source: "o/r" })
	dbg [a, b]
	a == "Bad_ is not a tag prefix. A tag prefix has 1 to 40 characters of a-z, 0-9, . _ and -, and ends with -."
		and b == "no release tag on page 1 of github.com/o/r starts with zzz- and ends with <date>-<sha>"
}

# Design Q617 item 1: `add <name> <URL>` when config.toml has a table of the name. The same source is `Same` (exit 0, nothing changes, no request). Another source is `Other(<the source in config.toml>)` (exit 2). The tag-prefix does not decide.
expect {
	config = [{ name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }, { name: "mine", source: "acme/mine", tag_prefix: "m-" }]
	chk = |name, source| Channel.exists_check({ name, source, config })
	rows = [
		("same source", chk("reify", "Karakatiza666/roc-reify-nightlies"), Same),
		("another source", chk("reify", "someone-else/roc-reify-nightlies"), Other("Karakatiza666/roc-reify-nightlies")),
		("another case is another source", chk("reify", "karakatiza666/roc-reify-nightlies"), Other("Karakatiza666/roc-reify-nightlies")),
		("no table of that name", chk("third", "o/r"), Absent),
		("the long name is not the short name", chk("rei", "o/r"), Absent),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Design Q617 item 1: the two texts. The hint of the exit 2 failure is the order to remove the table first (a proposal for the words, TW24).
expect {
	a = Channel.already_text({ name: "reify", source: "Karakatiza666/roc-reify-nightlies" })
	b = Channel.exists_text({ name: "reify", source: "someone-else/roc-reify-nightlies", existing: "Karakatiza666/roc-reify-nightlies" })
	dbg [a]
	dbg b
	a == "channel reify is already added (github.com/Karakatiza666/roc-reify-nightlies)"
		and b
			== {
				message: "channel reify is added with the source Karakatiza666/roc-reify-nightlies, not someone-else/roc-reify-nightlies",
				hint: "To replace it, run: tln roc channel rm reify",
			}
}

# Design Q617 (R-CH13 item 1): `add <name>` with no URL. `config` and `project` are the tables of the 2 files. No table of the name in the project (no project, no talon.toml: the same, `[]`): `NoTable` (exit 2).
# The table of the project, no table in config.toml: `Copy`. Equal tables (R-CH10: all known keys): `Equal` (exit 0, no change). Different tables: `Differ` (exit 19, R-CH10).
expect {
	r = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }
	r2 = { name: "reify", source: "someone-else/roc-reify-nightlies", tag_prefix: "nightly-reify-" }
	r3 = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "other-" }
	m = { name: "mine", source: "acme/mine", tag_prefix: "m-" }
	chk = |config, project| Channel.copy_check({ name: "reify", config, project })
	rows = [
		("copy", chk([], [r]), Copy(r)),
		("copy, other tables around", chk([m], [m, r]), Copy(r)),
		("equal", chk([r], [r]), Equal),
		("another source", chk([r2], [r]), Differ),
		("another tag-prefix", chk([r3], [r]), Differ),
		("no table in the project", chk([], [m]), NoTable),
		("no table in the project, one in config.toml", chk([r], []), NoTable),
		("no table anywhere", chk([], []), NoTable),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Design Q617 (R-CH13 item 2): `rm <name>`. A table of config.toml: `Found`. The word `nightly` (a built-in name, also a reserved name such as `stable`, `git`): `Builtin`. Any other name, also one that only the project has: `Missing`. `Builtin` and `Missing` are exit 2.
expect {
	r = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }
	chk = |name| Channel.rm_check({ name, config: [r] })
	rows = [
		("a table", chk("reify"), Found),
		("built-in", chk("nightly"), Builtin),
		("unknown", chk("ghost"), Missing),
		("a short name", chk("rei"), Missing),
		("a reserved name that has no table", chk("stable"), Missing),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Design Q617 (R-CH13 item 2): the texts of the two stops (a proposal, TW24).
expect {
	a = Channel.rm_fail_text({ name: "ghost", kind: Missing, path: "/h/.config/talon/config.toml" })
	b = Channel.rm_fail_text({ name: "nightly", kind: Builtin, path: "/h/.config/talon/config.toml" })
	dbg [a, b]
	a == "no channel ghost in /h/.config/talon/config.toml"
		and b == "nightly is a built-in channel and cannot be removed"
}

# R-CH12 Design Q618: page 1 has no build (every tag that ends with `<date>-<sha>` is a draft or a prerelease): exit 2, nothing is written. The text is the one that the user approved.
expect {
	got = Channel.no_build_text("Karakatiza666/roc-nb")
	dbg got
	got == "github.com/Karakatiza666/roc-nb has no build on page 1 (drafts and prereleases do not count)"
}
