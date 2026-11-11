import lib.Channel

ChannelrefTest :: [].{}

# Slice 241 (docs/slices/241-channel-selection.md), R-CH8 R-CH6 R-CH7 R-CH11 R-CH13 (Design Q612, Q615 items 2 and 7). The pure decisions of the refs `<name>@<selector>` and of the trust of a pin.
# New names for the code agent (a proposal, TW24; until they exist this file does not compile: red on purpose):
#   `Channel.named_ref : { text : Str, config : List(E), project : List(E) } -> [NotNamed, Builtin(Str), User(E, Str), ProjectOnly(E), NoTable(Str), BadSelector(Str)]`
#       E = { name : Str, source : Str, tag_prefix : Str } (the tables of config.toml and of the root talon.toml). `text` is the operand of a `tln roc` command.
#       `<name>@latest` and `<name>@<step>` (`@-1`, `@+2`) name a channel. The `Str` of the result is the selector for `Nightlies.pick`: `@latest`, `@-1`. `Builtin` is the channel `nightly`
#       (R-CH2: no table, no consent). `User(E, _)`: the table is in config.toml (it wins over the project). `ProjectOnly(E)`: no consent (R-CH11, exit 19). `NoTable(name)`: exit 2
#       (Design Q615 item 7, the text of `Channel.unknown_text`). `BadSelector(sel)`: after a name only `latest` and a step are allowed (answer 3 of slice 241): exit 2 with `Channel.bad_selector_text`.
#       A bare `nightly` is `Builtin("@latest")` (answer 4). `NotNamed`: any other text (a bare name is `Channel.install_ref`, a selector with no name is the old rules).
#   `Channel.pin_trust : { text : Str, installed : List(Str), times : List({ id : Str, published_at : U64 }), config : List(E), project : List(E) } -> [NoChannel, Free, Stop(E), NoTable(Str)]`
#       `text` is the text of `[toolchain] roc` (a range, R-CH7). `NoChannel`: the range names no user build (`*`, a semver range, `=<nightly>`, `>=<nightly>`, a text that is no range).
#       `Free`: Talon needs no list: the table is in config.toml, or an installed build is in the range (R-CH13: an installed build stays selectable by its id).
#       `Stop(E)`: a build of the channel is needed, and only the project has its table (R-CH11, Design Q615 item 2: exit 19 before any request; `Channel.trust_text` is the text).
#       `NoTable(name)`: no table in either file (answer 1: exit 2, the text of `Channel.unknown_text`).
#   `Channel.bad_selector_text : { name : Str, selector : Str } -> { message : Str, hint : Str }`  (answer 3; exit 2, kind Usage)
#   `Channel.pin_warning : { text : Str, config : List(E), project : List(E) } -> Try(Str, [None])`  (answer 8: the pin names a user build, the table is in config.toml and not in the project talon.toml: a warning, then the normal run)

reify = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }

other_reify = { name: "reify", source: "someone-else/roc-reify-nightlies", tag_prefix: "nightly-reify-" }

my_fork = { name: "my-fork", source: "acme/roc-fork", tag_prefix: "fork-" }

my = { name: "my", source: "acme/roc-my", tag_prefix: "my-" }

r1 = "reify-2026-10-30-abc1234"

r2 = "reify-2026-11-03-1708298"

f2 = "my-fork-2026-11-03-1708298"

n1 = "nightly-2026-10-14-38a3029"

n2 = "nightly-2026-11-05-bbbbbbb"

# R-CH8: `<name>@<selector>`.
# - A table of config.toml: `User`. Both files: config wins (R-CH10 checks that they are equal). The project only: `ProjectOnly`. No table: `NoTable`.
# - `nightly@latest` and `nightly@-1` are the built-in channel (`Builtin`), with or without tables.
# - A bare name, a selector with no name, a package ref, a bad name, an id: `NotNamed` (the old rules, or `Channel.install_ref`, decide).
expect {
	rows = [
		("reify@latest, config", { text: "reify@latest", config: [reify], project: [] }, User(reify, "@latest")),
		("reify@-1, config", { text: "reify@-1", config: [reify], project: [] }, User(reify, "@-1")),
		("reify@+2, config", { text: "reify@+2", config: [reify], project: [] }, User(reify, "@+2")),
		("reify@-10, config", { text: "reify@-10", config: [reify], project: [] }, User(reify, "@-10")),
		("both files", { text: "reify@latest", config: [reify], project: [reify] }, User(reify, "@latest")),
		("config wins over a table of the project", { text: "reify@latest", config: [reify], project: [other_reify] }, User(reify, "@latest")),
		("a name with -, read to the @", { text: "my-fork@latest", config: [my, my_fork], project: [] }, User(my_fork, "@latest")),
		("the short name is not the long name", { text: "my@latest", config: [my_fork], project: [] }, NoTable("my")),
		("project only", { text: "reify@latest", config: [], project: [reify] }, ProjectOnly(reify)),
		("project only, a step", { text: "reify@-1", config: [], project: [reify] }, ProjectOnly(reify)),
		("project only, another name in config", { text: "reify@latest", config: [my_fork], project: [reify] }, ProjectOnly(reify)),
		("no table at all", { text: "reify@latest", config: [], project: [] }, NoTable("reify")),
		("no table at all, another name", { text: "foo@latest", config: [reify], project: [reify] }, NoTable("foo")),
		("nightly@latest", { text: "nightly@latest", config: [], project: [] }, Builtin("@latest")),
		("nightly@latest, with tables", { text: "nightly@latest", config: [reify], project: [reify] }, Builtin("@latest")),
		("nightly@-1", { text: "nightly@-1", config: [reify], project: [] }, Builtin("@-1")),
		("a bare name", { text: "reify", config: [reify], project: [] }, NotNamed),
		("the bare word nightly is nightly@latest (answer 4)", { text: "nightly", config: [], project: [] }, Builtin("@latest")),
		("the bare word nightly, with tables", { text: "nightly", config: [reify], project: [reify] }, Builtin("@latest")),
		("a selector that is a sha prefix (answer 3)", { text: "reify@abc1234", config: [reify], project: [] }, BadSelector("abc1234")),
		("a selector that is a date (answer 3)", { text: "reify@2026-11-03", config: [reify], project: [] }, BadSelector("2026-11-03")),
		("a selector that is a user id (answer 3)", { text: "reify@reify-2026-11-03-1708298", config: [reify], project: [] }, BadSelector("reify-2026-11-03-1708298")),
		("a selector that is a release (answer 3)", { text: "reify@0.1.0", config: [reify], project: [] }, BadSelector("0.1.0")),
		("nightly with a tag (answer 3)", { text: "nightly@nightly-2026-10-09-258ab27", config: [], project: [] }, BadSelector("nightly-2026-10-09-258ab27")),
		("a bad selector, project only table: the stop comes first", { text: "reify@abc1234", config: [], project: [reify] }, ProjectOnly(reify)),
		("@latest", { text: "@latest", config: [reify], project: [reify] }, NotNamed),
		("@-1", { text: "@-1", config: [reify], project: [reify] }, NotNamed),
		("latest", { text: "latest", config: [reify], project: [] }, NotNamed),
		("an empty selector", { text: "reify@", config: [reify], project: [] }, NotNamed),
		("an empty name", { text: "@", config: [reify], project: [] }, NotNamed),
		("a package ref", { text: "acme/json@1.0.0", config: [reify], project: [] }, NotNamed),
		("a name with upper case", { text: "Reify@latest", config: [reify], project: [] }, NotNamed),
		("a one-letter name", { text: "r@latest", config: [reify], project: [] }, NotNamed),
		("a user id", { text: r2, config: [reify], project: [] }, NotNamed),
		("a nightly id", { text: n1, config: [reify], project: [] }, NotNamed),
		("a release", { text: "0.1.0", config: [reify], project: [] }, NotNamed),
		("empty text", { text: "", config: [reify], project: [reify] }, NotNamed),
	]
	bad = rows.keep_if(|(_, facts, want)| Channel.named_ref(facts) != want).map(|(label, facts, want)| (label, want, Channel.named_ref(facts)))
	dbg bad
	bad == []
}

# R-CH6 R-CH7 R-CH11 R-CH13 (Design Q615 item 2): the trust of the compiler range of `[toolchain] roc`.
# - A range that names no user build needs no table (`NoChannel`), also when the project has a table that nothing uses.
# - `=<user id>` and `>=<user id>`: the table in config.toml is `Free`. The project only is `Stop`, unless an installed build is in the range (then no list is needed: `Free`).
expect {
	no_times = []
	rows = [
		("* with a project table", { text: "*", installed: [], times: no_times, config: [], project: [reify] }, NoChannel),
		("a semver range", { text: "0.1.*", installed: [], times: no_times, config: [], project: [reify] }, NoChannel),
		("= nightly", { text: "=${n1}", installed: [], times: no_times, config: [], project: [reify] }, NoChannel),
		(">= nightly", { text: ">=${n1}", installed: [], times: no_times, config: [], project: [reify] }, NoChannel),
		("= release", { text: "=0.1.3", installed: [], times: no_times, config: [], project: [reify] }, NoChannel),
		("a text that is no range", { text: "reify", installed: [], times: no_times, config: [], project: [reify] }, NoChannel),
		("= user id, config", { text: "=${r2}", installed: [], times: no_times, config: [reify], project: [] }, Free),
		("= user id, both files", { text: "=${r2}", installed: [], times: no_times, config: [reify], project: [reify] }, Free),
		(">= user id, config", { text: ">=${r1}", installed: [], times: no_times, config: [reify], project: [] }, Free),
		("= user id, project only", { text: "=${r2}", installed: [n1], times: no_times, config: [], project: [reify] }, Stop(reify)),
		("= user id, project only, another name in config", { text: "=${r2}", installed: [], times: no_times, config: [my_fork], project: [reify] }, Stop(reify)),
		("= user id, project only, the build is installed (R-CH13)", { text: "=${r2}", installed: [n1, r2], times: no_times, config: [], project: [reify] }, Free),
		("= user id, project only, another build is installed", { text: "=${r2}", installed: [r1], times: no_times, config: [], project: [reify] }, Stop(reify)),
		(">= user id, project only, no build installed", { text: ">=${r1}", installed: [], times: no_times, config: [], project: [reify] }, Stop(reify)),
		(">= user id, project only, only nightlies installed", { text: ">=${r1}", installed: [n1, n2], times: no_times, config: [], project: [reify] }, Stop(reify)),
		(">= user id, project only, a build in the range is installed", { text: ">=${r1}", installed: [r2], times: no_times, config: [], project: [reify] }, Free),
		(">= user id, project only, the bound is installed", { text: ">=${r1}", installed: [r1], times: no_times, config: [], project: [reify] }, Free),
		(">= user id, project only, an installed build is before the bound", { text: ">=${r2}", installed: [r1], times: no_times, config: [], project: [reify] }, Stop(reify)),
		("= id of a name with -, project only", { text: "=${f2}", installed: [], times: no_times, config: [my], project: [my_fork] }, Stop(my_fork)),
		("= user id, no table in either file (answer 1)", { text: "=${r2}", installed: [], times: no_times, config: [], project: [] }, NoTable("reify")),
		(">= user id, no table in either file (answer 1)", { text: ">=${r1}", installed: [n1], times: no_times, config: [my_fork], project: [] }, NoTable("reify")),
		("= id of a name with -, config", { text: "=${f2}", installed: [], times: no_times, config: [my_fork], project: [] }, Free),
	]
	bad = rows.keep_if(|(_, facts, want)| Channel.pin_trust(facts) != want).map(|(label, facts, want)| (label, want, Channel.pin_trust(facts)))
	dbg bad
	bad == []
}

# R-CH11 (Design Q615 item 2): the stop of a pin is the stop of 240, the same two lines. The `source` is shown as written in the project table.
expect {
	got = Channel.trust_text(my_fork)
	got.message == "talon.toml uses compiler channel my-fork (github.com/acme/roc-fork)." and got.hint == "Run: tln roc channel add my-fork"
}

# Answer 3: the text of the refusal of a selector other than `latest` and a step. Kind Usage (exit 2). The hint says to use the full id.
expect {
	got = Channel.bad_selector_text({ name: "reify", selector: "abc1234" })
	got.message == "reify@abc1234: only latest or a step (-1, +1) can follow a channel name"
		and got.hint == "To name one build, use its full id: tln roc install reify-<date>-<sha>"
}

# Answer 8 (R-CH6, R-CH11): the pin names a user build, the table is in config.toml and not in the project talon.toml: a warning, not a stop. Other machines and CI cannot resolve the pin.
# No warning when the project has the table (any config), when no table is anywhere (exit 2) or only the project has it (exit 19), or when the range names no user build.
expect {
	msg = |pin, name| "talon.toml pins roc \"${pin}\", but it has no [channels.${name}] table. Other machines and CI cannot resolve the pin. Copy the table from config.toml to talon.toml."
	rows = [
		("= user id, config only", { text: "=${r2}", config: [reify], project: [] }, Ok(msg("=${r2}", "reify"))),
		(">= user id, config only", { text: ">=${r1}", config: [reify], project: [] }, Ok(msg(">=${r1}", "reify"))),
		("= id of a name with -, config only", { text: "=${f2}", config: [my, my_fork], project: [] }, Ok(msg("=${f2}", "my-fork"))),
		("= user id, both files", { text: "=${r2}", config: [reify], project: [reify] }, Err(None)),
		("= user id, project only", { text: "=${r2}", config: [], project: [reify] }, Err(None)),
		("= user id, no table", { text: "=${r2}", config: [], project: [] }, Err(None)),
		("= user id, the table of another name in the project", { text: "=${r2}", config: [reify], project: [my_fork] }, Ok(msg("=${r2}", "reify"))),
		("*", { text: "*", config: [reify], project: [] }, Err(None)),
		("= nightly", { text: "=${n1}", config: [reify], project: [] }, Err(None)),
		(">= nightly", { text: ">=${n1}", config: [reify], project: [] }, Err(None)),
	]
	bad = rows.keep_if(|(_, facts, want)| Channel.pin_warning(facts) != want).map(|(label, facts, want)| (label, want, Channel.pin_warning(facts)))
	dbg bad
	bad == []
}
