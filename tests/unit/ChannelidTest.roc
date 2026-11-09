import lib.Age
import lib.Channel
import lib.Manage
import lib.Pin
import lib.PinOrder
import lib.Selector
import lib.TalonRemove

ChannelidTest :: [].{}

# Slice 239 (docs/slices/239-github-release-shape.md), R-CH5 R-CH9 R-CH3, R-CH17 (Design Q614; GC treats a user-channel build as a nightly). Ids of a channel, and the functions that work by channel.
# New names for the code agent (a proposal; until they exist this file does not compile: red on purpose):
#   `Channel.parse_id : Str -> Try({ name : Str, year : U64, month : U64, day : U64, sha : Str }, [NotChannelId])`  (read from the right: sha, day, month, year; the rest is the name)
#   `Pin.counts_as_nightly : Str -> Bool`  (R-CH9: the `nightly` switch; true for a nightly tag in both forms and for a user-channel id)
#   `Age.compiler_name_in : { tables : List({ name : Str, source : Str, tag_prefix : Str }), recorded : Try(Str, [None]) }, Str -> Try(Str, [NoName])`  (R-C15, Design Q614 item 6: the `source` of the table of the id; with no table, the `source` recorded in `.talon.json`; with none, `Err(NoName)`: no pattern matches. A nightly and a release always have a name.)
# `Manage.kind_of` and `TalonRemove.describe_compilers` keep their names and types.

# R-CH5: the id is read from the right. `nightly-` ids give the name `nightly`. The name is what is left, also when it has `-` or looks like a tag (`nightly-reify`).
# The month name works as in a tag. No id: a release, a local build, an id with a bad date or sha, an empty name, a name that R-CH3 refuses, a reserved name (other than `nightly`).
expect {
	d = |name, y, m, day, sha| Ok({ name, year: y, month: m, day, sha })
	rows = [
		("nightly", Channel.parse_id("nightly-2026-10-09-258ab27"), d("nightly", 2026, 10, 9, "258ab27")),
		("nightly, month name", Channel.parse_id("nightly-2026-July-31-123c5d7"), d("nightly", 2026, 7, 31, "123c5d7")),
		("reify", Channel.parse_id("reify-2026-11-03-1708298"), d("reify", 2026, 11, 3, "1708298")),
		("reify, month name is no id (Q614 item 7)", Channel.parse_id("reify-2026-July-31-123c5d7"), Err(NotChannelId)),
		("a name with -", Channel.parse_id("my-fork-2-2026-11-03-1708298"), d("my-fork-2", 2026, 11, 3, "1708298")),
		("the name nightly-reify is reserved (Q614 item 4)", Channel.parse_id("nightly-reify-2026-11-03-1708298"), Err(NotChannelId)),
		("the name git-fork is reserved", Channel.parse_id("git-fork-2026-11-03-1708298"), Err(NotChannelId)),
		("the name gitfork is free", Channel.parse_id("gitfork-2026-11-03-1708298"), d("gitfork", 2026, 11, 3, "1708298")),
		("the name my-nightly is free", Channel.parse_id("my-nightly-2026-11-03-1708298"), d("my-nightly", 2026, 11, 3, "1708298")),
		("a name with a year", Channel.parse_id("a1-2026-2026-11-03-1708298"), d("a1-2026", 2026, 11, 3, "1708298")),
		("a release", Channel.parse_id("0.1.0"), Err(NotChannelId)),
		("a release with pre", Channel.parse_id("0.2.0-rc1"), Err(NotChannelId)),
		("git", Channel.parse_id("git-dd03c09e"), Err(NotChannelId)),
		("link", Channel.parse_id("link-dev"), Err(NotChannelId)),
		("copy", Channel.parse_id("copy-fix-1"), Err(NotChannelId)),
		("only a name", Channel.parse_id("reify"), Err(NotChannelId)),
		("no sha", Channel.parse_id("reify-2026-11-03"), Err(NotChannelId)),
		("short sha", Channel.parse_id("reify-2026-11-03-170829"), Err(NotChannelId)),
		("sha not hex", Channel.parse_id("reify-2026-11-03-170829z"), Err(NotChannelId)),
		("day of 1 digit", Channel.parse_id("reify-2026-11-3-1708298"), Err(NotChannelId)),
		("year of 2 digits", Channel.parse_id("reify-26-11-03-1708298"), Err(NotChannelId)),
		("month name in lower case", Channel.parse_id("reify-2026-july-31-123c5d7"), Err(NotChannelId)),
		("extra part at the right", Channel.parse_id("reify-2026-11-03-1708298-safe"), Err(NotChannelId)),
		("empty name", Channel.parse_id("-2026-11-03-1708298"), Err(NotChannelId)),
		("name with upper case", Channel.parse_id("Reify-2026-11-03-1708298"), Err(NotChannelId)),
		("name of 1 character", Channel.parse_id("a-2026-11-03-1708298"), Err(NotChannelId)),
		("name with - at the end", Channel.parse_id("ab--2026-11-03-1708298"), Err(NotChannelId)),
		("name of 25 characters", Channel.parse_id("abcdefghijklmnopqrstuvwxy-2026-11-03-1708298"), Err(NotChannelId)),
		("reserved: stable", Channel.parse_id("stable-2026-11-03-1708298"), Err(NotChannelId)),
		("reserved: git", Channel.parse_id("git-2026-11-03-1708298"), Err(NotChannelId)),
		("reserved: zig", Channel.parse_id("zig-2026-11-03-1708298"), Err(NotChannelId)),
		("empty", Channel.parse_id(""), Err(NotChannelId)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH5: the id of a tag (Nightlies.id_of, tested in ChannelreleaseTest) parses back to the name of its channel. A name of 24 characters works.
expect {
	ids = ["nightly-2026-11-09-9e85de7", "reify-2026-11-03-1708298", "abcdefghijklmnopqrstuvwx-2026-11-03-1708298", "x0-2026-07-05-abcdef1"]
	names = ids.map(|id| Channel.parse_id(id).map_ok(|p| p.name))
	dbg names
	names == [Ok("nightly"), Ok("reify"), Ok("abcdefghijklmnopqrstuvwx"), Ok("x0")]
}

# R-CH5: a user-channel id never parses as a nightly or a release id. `Pin.is_nightly` keeps the nightly form only (main guard: the 2 tag forms of a nightly are nightlies),
# `Selector.parse` gives no nightly for it, `PinOrder.is_release` is false, `Pin.is_id` is not asked here (selection is slice 241).
expect {
	user = ["reify-2026-11-03-1708298", "my-fork-2-2026-11-03-1708298", "my-nightly-2026-11-03-1708298"]
	nightly = ["nightly-2026-10-09-258ab27", "nightly-2026-July-31-123c5d7"]
	not_nightly = user.keep_if(|id| Pin.is_nightly(id) or Selector.parse(id, Bool.False) == Ok(Nightly(id)))
	not_release = user.keep_if(|id| PinOrder.is_release(id))
	dbg not_nightly
	not_nightly == [] and not_release == [] and nightly.all(|id| Pin.is_nightly(id))
}

# R-CH9: a user-channel build counts as a nightly for the switch. A nightly tag in both forms counts. A release, a local build, a prefix, a name without a date, a bad sha and a
# reserved name do not count.
expect {
	rows = [
		("nightly", Pin.counts_as_nightly("nightly-2026-10-09-258ab27"), Bool.True),
		("nightly, month name", Pin.counts_as_nightly("nightly-2026-July-31-123c5d7"), Bool.True),
		("reify", Pin.counts_as_nightly("reify-2026-11-03-1708298"), Bool.True),
		("reify, month name is no id", Pin.counts_as_nightly("reify-2026-July-31-123c5d7"), Bool.False),
		("nightly-reify is a reserved name", Pin.counts_as_nightly("nightly-reify-2026-11-03-1708298"), Bool.False),
		("a release", Pin.counts_as_nightly("0.1.0"), Bool.False),
		("git", Pin.counts_as_nightly("git-dd03c09e"), Bool.False),
		("link", Pin.counts_as_nightly("link-dev"), Bool.False),
		("copy", Pin.counts_as_nightly("copy-fix-1"), Bool.False),
		("a name only", Pin.counts_as_nightly("reify"), Bool.False),
		("a prefix", Pin.counts_as_nightly("reify-2026-11"), Bool.False),
		("short sha", Pin.counts_as_nightly("reify-2026-11-03-170829"), Bool.False),
		("reserved", Pin.counts_as_nightly("stable-2026-11-03-1708298"), Bool.False),
		("empty", Pin.counts_as_nightly(""), Bool.False),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-LY1 R-CH9 R-CH17: `Manage.kind_of` (the kind in `tln roc list`) gives `Nightly` to a user-channel build. The local kinds keep their prefix rule. A name that only starts with a
# reserved word (`gitfork`) is a channel. A reserved name with a date (`git-2026-...`) is no channel id, so it stays `Git` by its prefix.
expect {
	rows = [
		("nightly", Manage.kind_of("nightly-2026-10-09-258ab27"), Nightly),
		("nightly, month name", Manage.kind_of("nightly-2026-July-31-123c5d7"), Nightly),
		("reify", Manage.kind_of("reify-2026-11-03-1708298"), Nightly),
		("git-fork: reserved start, the prefix rule", Manage.kind_of("git-fork-2026-11-03-1708298"), Git),
		("gitfork", Manage.kind_of("gitfork-2026-11-03-1708298"), Nightly),
		("a release", Manage.kind_of("0.1.0"), Release),
		("git", Manage.kind_of("git-dd03c09e"), Git),
		("link", Manage.kind_of("link-dev"), Link),
		("copy", Manage.kind_of("copy-fix-1"), Copy),
		("git with a date", Manage.kind_of("git-2026-11-03-1708298"), Git),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH17 R-CH9 (`TalonRemove.kind_of`, private, seen through `describe_compilers`): a user-channel build is counted with the nightlies. The word and the order are those of the
# old text (`nightlies`, `releases`, `git builds`). With no user channel the text is the old one (main guard).
expect {
	zigs = ["0.17.0"]
	with_user = TalonRemove.describe_compilers({ ids: ["nightly-2026-10-09-258ab27", "reify-2026-11-03-1708298", "0.1.0", "git-dd03c09e", "link-dev", "copy-fix-1"], zigs })
	only_user = TalonRemove.describe_compilers({ ids: ["reify-2026-11-03-1708298"], zigs: [] })
	two_channels = TalonRemove.describe_compilers({ ids: ["reify-2026-11-03-1708298", "mine-2026-11-03-abcdef1"], zigs: [] })
	old = TalonRemove.describe_compilers({ ids: ["nightly-2026-10-09-258ab27", "nightly-2026-10-14-38a3029", "git-dd03c09e"], zigs })
	dbg with_user
	with_user == "2 nightlies, 1 release, 1 git build, 1 link, 1 copy, zig 0.17.0"
		and only_user == "1 nightly"
			and two_channels == "2 nightlies"
				and old == "2 nightlies, 1 git build, zig 0.17.0"
}

# R-C15 R-CH9 (Design Q614 item 6): the name for `min-release-age-exclude`. A nightly (both forms) is `roc-lang/nightlies` also with no table. A build of a user channel is the `source` of its
# table. A release is `roc-lang/roc`. With no table for the id, the name is the source recorded in `.talon.json`; with none recorded, `Err(NoName)` (no pattern matches). A table wins over a record.
expect {
	tables = [
		{ name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" },
		{ name: "mine", source: "someone/roc-builds", tag_prefix: "v-" },
	]
	none = Err(None)
	rows = [
		("nightly", Age.compiler_name_in({ tables, recorded: none }, "nightly-2026-10-09-258ab27"), Ok("roc-lang/nightlies")),
		("nightly, month name", Age.compiler_name_in({ tables, recorded: none }, "nightly-2026-July-31-123c5d7"), Ok("roc-lang/nightlies")),
		("nightly, no tables", Age.compiler_name_in({ tables: [], recorded: none }, "nightly-2026-10-09-258ab27"), Ok("roc-lang/nightlies")),
		("reify", Age.compiler_name_in({ tables, recorded: none }, "reify-2026-11-03-1708298"), Ok("Karakatiza666/roc-reify-nightlies")),
		("mine", Age.compiler_name_in({ tables, recorded: none }, "mine-2026-11-03-abcdef1"), Ok("someone/roc-builds")),
		("a table wins over a record", Age.compiler_name_in({ tables, recorded: Ok("other/repo") }, "mine-2026-11-03-abcdef1"), Ok("someone/roc-builds")),
		("no table, a record", Age.compiler_name_in({ tables: [], recorded: Ok("Karakatiza666/roc-reify-nightlies") }, "reify-2026-11-03-1708298"), Ok("Karakatiza666/roc-reify-nightlies")),
		("no table, no record", Age.compiler_name_in({ tables: [], recorded: none }, "reify-2026-11-03-1708298"), Err(NoName)),
		("another channel's table is not used", Age.compiler_name_in({ tables, recorded: none }, "other-2026-11-03-1708298"), Err(NoName)),
		("a release", Age.compiler_name_in({ tables, recorded: none }, "0.1.0"), Ok("roc-lang/roc")),
		("a release, no tables", Age.compiler_name_in({ tables: [], recorded: Ok("x/y") }, "0.12.3"), Ok("roc-lang/roc")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# Main guard (R-C15, slice 084): `Age.compiler_name` is as before for the ids that exist.
expect {
	Age.compiler_name("nightly-2026-10-09-258ab27") == "roc-lang/nightlies"
		and Age.compiler_name("nightly-2026-July-31-123c5d7") == "roc-lang/nightlies"
			and Age.compiler_name("0.1.0") == "roc-lang/roc"
}
