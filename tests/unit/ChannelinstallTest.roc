import lib.Channel
import lib.Nightlies
import lib.Toolchain

ChannelinstallTest :: [].{}

# Slice 240 (docs/slices/240-install-from-channel.md), R-CH11 R-CH13 R-CH16 R-CV5 (Design Q612, Q614). The pure decisions of `tln roc install <channel>`.
# New names for the code agent (a proposal, TW24; until they exist this file does not compile: red on purpose):
#   `Channel.install_ref : { text : Str, config : List(E), project : List(E) } -> [NotChannel, Latest(E), Build(E, Str), ProjectOnly(E)]`
#       E = { name : Str, source : Str, tag_prefix : Str } (the tables of config.toml and of the root talon.toml). `text` is the operand of `tln roc install`.
#       A bare name of a table, or an id of a table (`Channel.parse_id`, the name is a table), is the channel. A table of config.toml wins (R-CH11). The names
#       are found by the tables, not by the form of the text, so `abc1234` (a sha prefix) or `nightly-2026-10-09-258ab27` is `NotChannel`.
#   `Channel.trust_text : { name : Str, source : Str, .. } -> { message : Str, hint : Str }`  (R-CH11: the failure text for `ProjectOnly`; exit 19)
#   `Channel.unknown_text : Str -> Try(Str, [NotChannelText])`  (Design Q615 item 7: the text of exit 2 for a name with no table in either file. Used only for a text that is a channel name or an id of one (`Channel.parse_id`); the caller applies it after the prefix of an installed id, R-SC10)
#   `Toolchain.meta_from` gets the optional field `channel ?: { name : Str, source : Str }` of its first argument (R-CV5, R-CH13): two keys `channel`, `source` after `published_at`.
#   `Nightlies.source_for : Nightlies.Source, Str -> Nightlies.Source`  (R-CH16: the channel name; `nightly` keeps the source, a user channel is always `Direct`)

reify = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }

other_reify = { name: "reify", source: "someone-else/roc-reify-nightlies", tag_prefix: "nightly-reify-" }

my_fork = { name: "my-fork", source: "acme/roc-fork", tag_prefix: "fork-" }

my = { name: "my", source: "acme/roc-my", tag_prefix: "my-" }

gitfork = { name: "gitfork", source: "acme/roc-gitfork", tag_prefix: "g-" }

# R-CH11 R-CH8 R-CH5: the operand of `tln roc install` and the tables of the 2 files.
# - A bare name, or an id of that name, with a table in config.toml: that channel (`Latest`, `Build`).
# - A table in the project only: `ProjectOnly` (exit 19 before any request). Both files have it: config.toml wins (R-CH10 checks that they are equal).
# - No table in either file, a nightly id, a sha prefix, a ref, a release, a month name id: `NotChannel` (the old rules decide).
expect {
	rows = [
		("bare name, config", { text: "reify", config: [reify], project: [] }, Latest(reify)),
		("id, config", { text: "reify-2026-11-03-1708298", config: [reify], project: [] }, Build(reify, "reify-2026-11-03-1708298")),
		("bare name, both files", { text: "reify", config: [reify], project: [reify] }, Latest(reify)),
		("id, both files", { text: "reify-2026-11-03-1708298", config: [reify], project: [reify] }, Build(reify, "reify-2026-11-03-1708298")),
		("config wins over a table of the project", { text: "reify", config: [reify], project: [other_reify] }, Latest(reify)),
		("bare name, project only", { text: "reify", config: [], project: [reify] }, ProjectOnly(reify)),
		("id, project only", { text: "reify-2026-11-03-1708298", config: [], project: [reify] }, ProjectOnly(reify)),
		("project only, another name in config", { text: "reify", config: [my_fork], project: [reify] }, ProjectOnly(reify)),
		("no table at all", { text: "reify", config: [], project: [] }, NotChannel),
		("an id, no table at all", { text: "reify-2026-11-03-1708298", config: [], project: [] }, NotChannel),
		("the id of another channel", { text: "other-2026-11-03-1708298", config: [reify], project: [] }, NotChannel),
		("a name with -, read from the right", { text: "my-fork-2026-11-03-1708298", config: [my, my_fork], project: [] }, Build(my_fork, "my-fork-2026-11-03-1708298")),
		("the short name is not the long name", { text: "my", config: [my_fork], project: [] }, NotChannel),
		("the bare long name", { text: "my-fork", config: [my, my_fork], project: [] }, Latest(my_fork)),
		("a free name that starts like a reserved one", { text: "gitfork-2026-11-03-1708298", config: [gitfork], project: [] }, Build(gitfork, "gitfork-2026-11-03-1708298")),
		("a month name id is no build of a user channel (Q614 item 7)", { text: "reify-2026-July-31-123c5d7", config: [reify], project: [] }, NotChannel),
		("a nightly id", { text: "nightly-2026-10-09-258ab27", config: [reify], project: [reify] }, NotChannel),
		("a nightly id, month name", { text: "nightly-2026-July-31-123c5d7", config: [], project: [reify] }, NotChannel),
		("the word nightly", { text: "nightly", config: [reify], project: [reify] }, NotChannel),
		("a sha prefix", { text: "abc1234", config: [reify], project: [reify] }, NotChannel),
		("@latest", { text: "@latest", config: [reify], project: [reify] }, NotChannel),
		("a release", { text: "0.1.0", config: [reify], project: [reify] }, NotChannel),
		("a git id", { text: "git-dd03c09e", config: [reify], project: [reify] }, NotChannel),
		("a prefix of a user id is not a name", { text: "reify-2026-11", config: [reify], project: [] }, NotChannel),
		("an id with a short sha", { text: "reify-2026-11-03-170829", config: [reify], project: [] }, NotChannel),
		("empty text", { text: "", config: [reify], project: [reify] }, NotChannel),
	]
	bad = rows.keep_if(|(_, facts, want)| Channel.install_ref(facts) != want).map(|(label, facts, want)| (label, want, Channel.install_ref(facts)))
	dbg bad
	bad == []
}

# R-CH11: the text of the stop. Exit 19 (kind Input) is the work of the command. The `source` is shown as written in the project table, after `github.com/`.
expect {
	got = Channel.trust_text(reify)
	other = Channel.trust_text(my_fork)
	dbg got
	got.message == "talon.toml uses compiler channel reify (github.com/Karakatiza666/roc-reify-nightlies)."
		and got.hint == "Run: tln roc channel add reify"
			and other.message == "talon.toml uses compiler channel my-fork (github.com/acme/roc-fork)."
				and other.hint == "Run: tln roc channel add my-fork"
}

# R-CV5 R-CH13: `.talon.json` of a user-channel build holds `channel` and `source`, after `published_at`. A build with no `channel` (a nightly) has the old text, byte for byte (the main guard).
expect {
	base = { id: "reify-2026-11-03-1708298", url: "https://github.com/Karakatiza666/roc-reify-nightlies/releases/download/nightly-reify-2026-11-03-1708298/roc_nightly-reify-linux_x86_64-2026-11-03-1708298.tar.gz", sha256: "b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78", typed: "reify", compat: Ok("1708298"), now: 1794312000, published_at: 1793700000 }
	user = Toolchain.meta_from({ id: base.id, url: base.url, sha256: base.sha256, typed: base.typed, compat: base.compat, now: base.now, published_at: base.published_at, channel: { name: "reify", source: "Karakatiza666/roc-reify-nightlies" } }, GithubDigest)
	plain = Toolchain.meta_from({ id: base.id, url: base.url, sha256: base.sha256, typed: base.typed, compat: base.compat, now: base.now, published_at: base.published_at }, GithubDigest)
	dbg user
	user == "{\"format\":1,\"id\":\"reify-2026-11-03-1708298\",\"url\":\"${base.url}\",\"sha256\":\"${base.sha256}\",\"sha256_source\":\"github-digest\",\"typed\":\"reify\",\"compat\":\"1708298\",\"installed_at\":\"2026-11-10T12:00:00Z\",\"published_at\":\"2026-11-03T10:00:00Z\",\"channel\":\"reify\",\"source\":\"Karakatiza666/roc-reify-nightlies\"}\n"
		and plain == Toolchain.meta(base)
			and !plain.contains("\"channel\"")
				and !plain.contains("\"source\"")
}

# R-CH16 R-CV3: a user channel is always listed with `direct`, also when a registry is set. The `nightly` channel keeps the source of the run.
expect {
	registry = Registry({ origin: "https://registry.example.org", version: "0.0.1", log: Err(None), kept: Bool.False, source: "config.toml", first: Bool.True })
	kept = Registry({ origin: "https://registry.example.org", version: "0.0.1", log: Ok(7), kept: Bool.True, source: "config.toml", first: Bool.False })
	rows = [
		("nightly, registry", Nightlies.source_for(registry, "nightly"), registry),
		("nightly, registry with a snapshot", Nightlies.source_for(kept, "nightly"), kept),
		("nightly, direct", Nightlies.source_for(Direct, "nightly"), Direct),
		("user channel, registry", Nightlies.source_for(registry, "reify"), Direct),
		("user channel, registry with a snapshot", Nightlies.source_for(kept, "reify"), Direct),
		("user channel, direct", Nightlies.source_for(Direct, "reify"), Direct),
		("a name that starts with nightly", Nightlies.source_for(registry, "my-nightly"), Direct),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad.len()
	bad == []
}

# Design Q615 item 7 (R-CH11): the text for a name that has no table. A name or an id of a name gives the text. A nightly id, a ref, a release, a git id and a month name id do not.
expect {
	rows = [
		("bare name", Channel.unknown_text("reify"), Ok("unknown compiler channel reify. Add it: tln roc channel add reify <URL>")),
		("id", Channel.unknown_text("reify-2026-11-03-1708298"), Ok("unknown compiler channel reify. Add it: tln roc channel add reify <URL>")),
		("a name with -", Channel.unknown_text("my-fork-2026-11-03-1708298"), Ok("unknown compiler channel my-fork. Add it: tln roc channel add my-fork <URL>")),
		("a nightly id", Channel.unknown_text("nightly-2026-10-09-258ab27"), Err(NotChannelText)),
		("the word nightly", Channel.unknown_text("nightly"), Err(NotChannelText)),
		("a reserved name", Channel.unknown_text("git-dd03c09e"), Err(NotChannelText)),
		("@latest", Channel.unknown_text("@latest"), Err(NotChannelText)),
		("a release", Channel.unknown_text("0.1.0"), Err(NotChannelText)),
		("a month name id", Channel.unknown_text("reify-2026-July-31-123c5d7"), Err(NotChannelText)),
		("all hex: a sha prefix keeps its old form (Q615 open question 9; R-CH5, R-CH7)", Channel.unknown_text("abcdef1"), Err(NotChannelText)),
		("all hex, digits and letters", Channel.unknown_text("abc1234"), Err(NotChannelText)),
		("all hex, short", Channel.unknown_text("dead"), Err(NotChannelText)),
		("all hex, long", Channel.unknown_text("dd03c09e5f0a3b6c"), Err(NotChannelText)),
		("hex with one other letter is a name", Channel.unknown_text("abcdefg"), Ok("unknown compiler channel abcdefg. Add it: tln roc channel add abcdefg <URL>")),
		("a bad name", Channel.unknown_text("Reify"), Err(NotChannelText)),
		("empty", Channel.unknown_text(""), Err(NotChannelText)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	bad == []
}
