import lib.Args
import lib.Channel
import lib.Compiler
import lib.Fail
import lib.Gc
import lib.Manage
import lib.ManageUpdate

ChanneldefaultTest :: [].{}

# Slice 243 (docs/slices/243-channel-use-upgrade-gc.md), R-CH15 R-CH17 R-RU1 R-RU2 R-RR1 R-GC5 R-SO14 (Design Q612, Q615 item 6). The default compiler and a user-channel build: where `roc update [<name>]` looks, when the default moves, which build takes the default
# when the default is removed, what GC does with a user build, and the builds that no pick ever takes.
# New names for the code agent (a proposal, TW24; until they exist this file does not compile: red on purpose):
#   `Manage.update_move_to : { default : Try(Str, [Unset]), id : Str } -> [Move, Stay]`   (R-RU2 with the new build `id`; the old `Manage.update_move` stays)
#   `Manage.update_name : Args -> Try(Try(Str, [NoName]), Fail)`   (the operand of `roc update`: none, or one channel name; `ManageUpdate.update_name`, re-exported by `Manage` as `read_update` is)
#   `Channel.update_ref : { name : Try(Str, [NoName]), default : Try(Str, [Unset]) } -> Str`   (the ref that `roc update` gives to `RocInstall.offer!`)
#   `Manage.unset_note : { removed : Str } -> Try(Str, [None])`   (R1, Design Q619: the note when a user-channel default is removed and no other build of its channel is left; `Err(None)` for every other default)
#   `Channel.toml_pin : Str -> Try(Str, [None])`   (G1: the id of the value of `[toolchain] roc` when it is `=<id>`; any other value, `*` or a range, is `Err(None)`)
#   `Gc.toolchains` gets the optional field `pinned : List(Str)` (ids that a known project pins in its root talon.toml): `Keep(Pinned)` as for a header pin.
#   `ManageUpdate.update_report` gets the default tag `NoDefault` (no default is set).
# Changed behavior, no new name: `Manage.next_default` (a user-channel default moves inside its channel), `ManageUpdate.update_report` (a `Stay` of a user-channel default).
# Guards (green now, they hold the rules that the code must not break): `Gc.toolchains`, `Manage.kind_of`, `Compiler.newest_installed`, `Compiler.installed`.

r_old = "reify-2026-11-03-1708298"

r_new = "reify-2026-11-10-abc1234"

r_mid = "reify-2026-10-30-fedcba9"

mine_new = "mine-2026-11-12-1111111"

n_new = "nightly-2026-10-14-38a3029"

n_old = "nightly-2026-10-09-258ab27"

# R-RU2 R-CH15: does `roc update` move the global default to the new build `id`? The rows with a nightly or a release default are the rules of today. A user-channel default moves only to a build of the same channel. The channel is read from the right (R-CH5):
# `my-fork-...` is not `my-...`. U1 (Design Q619): a nightly or release default, or no default, with a new user build: the default does not move (`Stay`).
expect {
	moves = |default, id| Manage.update_move_to({ default, id })
	rows = [
		("no default, a nightly", moves(Err(Unset), n_new), Move),
		("a nightly default, a nightly", moves(Ok(n_old), n_new), Move),
		("a release default, a nightly", moves(Ok("0.1.0"), n_new), Move),
		("U1: a nightly default, a user build: stays", moves(Ok(n_new), r_new), Stay),
		("U1: a release default, a user build: stays", moves(Ok("0.1.0"), r_new), Stay),
		("U1: no default, a user build: stays unset", moves(Err(Unset), r_new), Stay),
		("a git default stays", moves(Ok("git-dd03c09e"), n_new), Stay),
		("a link default stays", moves(Ok("link-dev"), n_new), Stay),
		("a copy default stays", moves(Ok("copy-fix-1"), n_new), Stay),
		("a user default, a build of the same channel", moves(Ok(r_old), r_new), Move),
		("a user default, a nightly: stays", moves(Ok(r_old), n_new), Stay),
		("a user default, a build of another channel: stays", moves(Ok(r_old), mine_new), Stay),
		("my-fork default, a build of my: stays", moves(Ok("my-fork-2026-11-03-1708298"), "my-2026-11-10-abc1234"), Stay),
		("my default, a build of my-fork: stays", moves(Ok("my-2026-11-03-1708298"), "my-fork-2026-11-10-abc1234"), Stay),
		("my-fork default, a build of my-fork", moves(Ok("my-fork-2026-11-03-1708298"), "my-fork-2026-11-10-abc1234"), Move),
		("a user default, a git build is no new build: stays", moves(Ok(r_old), "git-dd03c09e"), Stay),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-RR1 R-CH15 R-CH9: the build that takes the default when the default is removed. A user-channel default moves only inside its channel: the newest installed build of that channel (R-CH9: `Channel.user_order`, the date, then `published_at`, then the sha),
# never a nightly and never a build of another channel. A user build counts as a nightly for the `nightly` switch (R-CH9): with the switch off, none is admitted, so the newest build of the channel still takes it (R-RR1, the default stays set).
# A nightly or release default never moves to a user build (R-CH15: no pick takes a user channel): with only user builds left, the default is not set. R1 (Design Q619): a user default with no other build of its channel is not set; it never falls back to a nightly or a release.
expect {
	next = |removed, nightly, installed, times| Manage.next_default({ installed, removed, nightly, times })
	t = |id, at| { id, published_at: at }
	all = [n_old, n_new, r_old, r_new, r_mid, mine_new]
	rows = [
		("a user default: the newest of its channel", next(r_old, Bool.True, all, []), Ok(r_new)),
		("the newest was the default: the second newest", next(r_new, Bool.True, all, []), Ok(r_old)),
		("never a nightly, never another channel", next(r_old, Bool.True, [n_new, r_old, mine_new, r_mid], []), Ok(r_mid)),
		("the channel is read from the right", next("my-fork-2026-11-03-1708298", Bool.True, ["my-2026-11-12-aaaaaaa", "my-fork-2026-10-01-bbbbbbb", "my-fork-2026-11-03-1708298"], []), Ok("my-fork-2026-10-01-bbbbbbb")),
		("the switch is off: the build of the channel takes it", next(r_new, Bool.False, [n_new, r_old, r_new], []), Ok(r_old)),
		("2 builds of one day: `published_at` first, not the sha", next(r_old, Bool.True, [r_old, "reify-2026-11-10-aaaaaaa", "reify-2026-11-10-fffffff"], [t("reify-2026-11-10-aaaaaaa", 1794398400), t("reify-2026-11-10-fffffff", 1794394800)]), Ok("reify-2026-11-10-aaaaaaa")),
		("2 builds of one day, no time: the sha", next(r_old, Bool.True, [r_old, "reify-2026-11-10-aaaaaaa", "reify-2026-11-10-fffffff"], []), Ok("reify-2026-11-10-fffffff")),
		("R1: a user default, no other build of the channel: not set", next(r_old, Bool.True, [n_new, r_old], []), Err(None)),
		("R1: a user default, only builds of other channels: not set", next(r_old, Bool.True, [n_old, n_new, r_old, mine_new, "0.1.0"], []), Err(None)),
		("R1: the switch is off: still not set, no fallback", next(r_old, Bool.False, [n_new, r_old], []), Err(None)),
		("a nightly default: the nightly, not a newer user build (guard)", next(n_new, Bool.True, [n_old, n_new, r_new], []), Ok(n_old)),
		("a nightly default, only user builds left: not set (guard)", next(n_new, Bool.True, [n_new, r_new, r_old], []), Err(None)),
		("a release default, a user build left: not set (guard)", next("0.1.0", Bool.True, ["0.1.0", r_new], []), Err(None)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-RU2 R-CH15 R-OUT2 (TW24 proposal): the note when `roc update` leaves a user-channel default as it is (the new build is a nightly, or of another channel). It follows the note of a git, link or copy default (that text stays).
# The words: `is a build of the channel <name>, so it stays`. U1 (Design Q619): a nightly or release default that stays because the new build is a user build: `is not a build of the channel <name>, so it stays`; no default: `NoDefault`. `Moved` and `Same` are the same for a user build.
expect {
	report = |default| ManageUpdate.update_report({ id: n_new, installed: Bool.False, default, compat: Err(Unknown) })
	user = report(Stay(r_old))
	link = report(Stay("link-dev"))
	moved = ManageUpdate.update_report({ id: r_new, installed: Bool.False, default: Moved(r_old), compat: Err(Unknown) })
	same = ManageUpdate.update_report({ id: r_new, installed: Bool.False, default: Same, compat: Err(Unknown) })
	nightly_stay = ManageUpdate.update_report({ id: r_new, installed: Bool.True, default: Stay(n_new), compat: Err(Unknown) })
	release_stay = ManageUpdate.update_report({ id: r_new, installed: Bool.False, default: Stay("0.1.0"), compat: Err(Unknown) })
	unset = ManageUpdate.update_report({ id: r_new, installed: Bool.True, default: NoDefault, compat: Err(Unknown) })
	u1 = nightly_stay.stdout
		== [
			"installed ${r_new}\n",
			"note: the default compiler ${n_new} is not a build of the channel reify, so it stays. To change it, run: tln roc default ${r_new}\n",
		]
		and release_stay.stdout == ["${r_new} is the newest\n", "note: the default compiler 0.1.0 is not a build of the channel reify, so it stays. To change it, run: tln roc default ${r_new}\n"]
			and unset.stdout == ["installed ${r_new}\n", "note: no default compiler is set, and ${r_new} is a build of the channel reify, so it is not made the default. To use it, run: tln roc default ${r_new}\n"]
	u1 and user
		== { stdout: ["${n_new} is the newest\n", "note: the default compiler ${r_old} is a build of the channel reify, so it stays. To change it, run: tln roc default ${n_new}\n"], stderr: [] }
		and link
			== { stdout: ["${n_new} is the newest\n", "note: the default compiler link-dev is a git, link or copy build, so it stays. To change it, run: tln roc default ${n_new}\n"], stderr: [] }
			and moved == { stdout: ["${r_new} is the newest\n", "the default compiler moved from ${r_old} to ${r_new}\n"], stderr: [] }
				and same == { stdout: ["${r_new} is the newest\n"], stderr: [] }
}

# R-CH15 R-CM15 R-CM19 R-CH3 (TW24 proposal): the operand of `roc update`. None, or one channel name (R-CH3). The word `nightly` is a name. A text that R-CH3 refuses is exit 2 with the text of `tln roc channel add` (a name that is a reserved word and `-` is also refused there).
# More than one operand is exit 2. The global flags are accepted. Whether the table exists is not decided here (`Channel.unknown_name_text`, exit 2). The old text `tln roc update takes no operand` is gone.
expect {
	named = |words| match Args.parse(words) {
		Ok(args) => Manage.update_name(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	bad_name = |name| Err(Fail.new(Usage, "${name} is not a channel name. A name is a-z, 0-9 and -, starts with a letter, has 2 to 24 characters and does not end with -."))
	rows = [
		(["roc", "update"], Ok(Err(NoName))),
		(["roc", "up"], Ok(Err(NoName))),
		(["roc", "update", "--json", "--yes", "--offline", "--quiet"], Ok(Err(NoName))),
		(["roc", "update", "reify"], Ok(Ok("reify"))),
		(["roc", "up", "my-fork", "--json"], Ok(Ok("my-fork"))),
		(["roc", "update", "nightly"], Ok(Ok("nightly"))),
		(["roc", "update", "Reify"], bad_name("Reify")),
		(["roc", "update", "@latest"], bad_name("@latest")),
		(["roc", "update", "a"], bad_name("a")),
		(["roc", "update", "reify-"], bad_name("reify-")),
		(["roc", "update", "nightly-2026-10-14-38a3029"], bad_name("nightly-2026-10-14-38a3029")),
		(["roc", "update", "reify", "mine"], Err(Fail.new(Usage, "tln roc update takes at most one channel name, got 2"))),
		(["roc", "update", "a", "b", "c"], Err(Fail.new(Usage, "tln roc update takes at most one channel name, got 3"))),
	]
	bad = rows.keep_if(|(words, want)| named(words) != want).map(|(words, want)| (words, want, named(words)))
	dbg bad
	bad == []
}

# R-CH15 R-RU1 R-CH8: the ref that `roc update` gives to `RocInstall.offer!`. A name gives `<name>@latest`. No name: the channel of the default (R-CH5: read from the right), else `@latest` as today (a nightly, a release, a git, link or copy default, or none).
# A name wins over the default. The word `nightly` is `nightly@latest` (R-CH8: a bare `nightly` is `nightly@latest`).
expect {
	ref = |name, default| Channel.update_ref({ name, default })
	rows = [
		("no name, no default", ref(Err(NoName), Err(Unset)), "@latest"),
		("no name, a nightly default", ref(Err(NoName), Ok(n_new)), "@latest"),
		("no name, a release default", ref(Err(NoName), Ok("0.1.0")), "@latest"),
		("no name, a git default", ref(Err(NoName), Ok("git-dd03c09e")), "@latest"),
		("no name, a link default", ref(Err(NoName), Ok("link-dev")), "@latest"),
		("no name, a copy default", ref(Err(NoName), Ok("copy-fix-1")), "@latest"),
		("no name, a user default", ref(Err(NoName), Ok(r_old)), "reify@latest"),
		("no name, my-fork default", ref(Err(NoName), Ok("my-fork-2026-11-03-1708298")), "my-fork@latest"),
		("a name, no default", ref(Ok("reify"), Err(Unset)), "reify@latest"),
		("a name, a nightly default", ref(Ok("reify"), Ok(n_new)), "reify@latest"),
		("a name wins over a user default", ref(Ok("mine"), Ok(r_old)), "mine@latest"),
		("nightly, a user default", ref(Ok("nightly"), Ok(r_old)), "nightly@latest"),
		("nightly, no default", ref(Ok("nightly"), Err(Unset)), "nightly@latest"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# GUARD (green now) R-GC5 R-CH17 R-CH13: GC treats a user-channel build as a nightly. The kind of the id is `Nightly` (`Manage.kind_of`), so `Gc.toolchains` applies the nightly rule: the default stays, a build used in the last day stays, a build used in the GC age stays,
# an old build that nothing uses goes. The channel table does not matter (a build of a removed channel is the same row). A `.last-use` or `installed_at` that is unknown keeps it. Not here: a project pin (question G1 of the slice file).
expect {
	now = 100000000
	day = 86400
	age = 2592000
	row = |id, installed_at, last_use, is_default| { id, kind: Manage.kind_of(id), installed_at, last_use, is_default }
	old = Ok(now - age - 1000)
	rows = [
		row(r_old, Ok(now - 90 * day), old, Bool.False),
		row(r_mid, Ok(now - 90 * day), Ok(now - 10 * day), Bool.False),
		row(r_new, Ok(now - 90 * day), Ok(now - 3600), Bool.False),
		row("reify-2026-08-01-aaaaaaa", Ok(now - 90 * day), old, Bool.True),
		row("mine-2026-08-02-bbbbbbb", Err(Unknown), Err(Unknown), Bool.False),
		row("mine-2026-08-03-ccccccc", Ok(now - 40 * day), Err(Unknown), Bool.False),
		row("my-fork-2026-08-04-ddddddd", Ok(now - age), Err(Unknown), Bool.False),
	]
	got = Gc.toolchains({ rows, projects: [], now, age }).map(|c| (c.id, c.verdict))
	want = [
		(r_old, Remove),
		(r_mid, Keep(Used)),
		(r_new, Keep(LastDay)),
		("reify-2026-08-01-aaaaaaa", Keep(Default)),
		("mine-2026-08-02-bbbbbbb", Keep(NoTime)),
		("mine-2026-08-03-ccccccc", Remove),
		("my-fork-2026-08-04-ddddddd", Keep(Used)),
	]
	kinds = [r_old, "my-fork-2026-11-03-1708298", n_new, "0.1.0", "link-dev"].map(|id| Manage.kind_of(id))
	dbg got
	got == want and kinds == [Nightly, Nightly, Nightly, Release, Link]
}

# GUARD (green now) R-CH15 R-SO14 R-SO24 R-ST16 R-NS6: `tln init`, `tln setup` and the pick of R-SO14 never take a user channel. The newest installed compiler (rank 6, the repair of `tln setup`) is a nightly or a release, never a user build, also when the user build is newer.
# With only user builds installed, no compiler is picked (`Err(None)`): the pick of R-SO14 downloads a nightly. The listing of `toolchains/` has the user dirs in `installed_users` only, not in `installed` (R-CH7).
expect {
	newest = |installed| Compiler.newest_installed({ installed, times: [] })
	dir = |name| { name, is_dir: Bool.True, mtime: 0 }
	listing = [dir(r_new), dir(n_old), dir(n_new), dir(mine_new), dir("link-dev")]
	newest([n_old, r_new, mine_new]) == Ok(n_old)
		and newest([r_new, r_old, mine_new]) == Err(None)
			and newest([]) == Err(None)
				and Compiler.installed(listing) == ["link-dev", n_old, n_new]
					and Compiler.installed_users(listing) == [mine_new, r_new]
}

# R1 R-RR1 R-OUT2 (Design Q619, TW24 proposal): the note when the removed default was a user-channel build and no other build of its channel is installed, so the default is not set. The command prints it on stderr as `note: <text>`
# (as `Manage.move_note`). Any other default (a nightly, a release, a git, link or copy build) gets no such note: `Err(None)`. The channel is read from the right (R-CH5).
expect {
	want = "${r_old} was the default and no other build of the channel reify is installed, so no default is set. Install one with tln roc install reify, then run: tln roc default <id>"
	Manage.unset_note({ removed: r_old }) == Ok(want)
		and Manage.unset_note({ removed: "my-fork-2026-11-03-1708298" }).map_ok(|t| t.contains("the channel my-fork ")) == Ok(Bool.True)
			and Manage.unset_note({ removed: n_new }) == Err(None)
				and Manage.unset_note({ removed: "0.1.0" }) == Err(None)
					and Manage.unset_note({ removed: "link-dev" }) == Err(None)
}

# G1 R-GC5 R-PD12 (Design Q619): the id that a root talon.toml pins with `[toolchain] roc = "=<id>"`. A user id or a nightly id; `*`, a range and a text that is no id give `Err(None)`. GC passes these ids to `Gc.toolchains` as `pinned`.
expect {
	pin = |text| Channel.toml_pin(text)
	rows = [
		("a user pin", pin("[toolchain]\nroc = \"=${r_old}\"\n"), Ok(r_old)),
		("a nightly pin", pin("[toolchain]\nnightly = true\nroc = \"=${n_old}\" # pinned\n"), Ok(n_old)),
		("with tables around", pin("[dependencies]\nx = \"1\"\n\n[toolchain]\nroc = \"=${r_new}\"\n\n[channels.reify]\nshape = \"github-release\"\nsource = \"a/b\"\ntag-prefix = \"x-\"\n"), Ok(r_new)),
		("an at-least range", pin("[toolchain]\nroc = \">=${r_old}\"\n"), Err(None)),
		("any compiler", pin("[toolchain]\nroc = \"*\"\n"), Err(None)),
		("no key", pin("[toolchain]\nnightly = true\n"), Err(None)),
		("no table", pin("# project\n"), Err(None)),
		("not an id", pin("[toolchain]\nroc = \"=soon\"\n"), Err(None)),
		("not TOML", pin("[toolchain]\nroc = \n"), Err(None)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# G1 R-GC5 (Design Q619): a build that a known project pins in its root talon.toml (`pinned`) stays, whatever its age, as a build that a header pins (`Keep(Pinned)`, after the last-day rule and before the age rule). A build that nothing pins goes.
# The field is optional: no `pinned` is the rule of today (the guard rows of the test above).
expect {
	now = 100000000
	age = 2592000
	old = Ok(now - age - 1000)
	row = |id, is_default| { id, kind: Manage.kind_of(id), installed_at: Ok(now - 90 * 86400), last_use: old, is_default }
	rows = [row(r_old, Bool.False), row(r_mid, Bool.False), row(n_old, Bool.False), row("reify-2026-08-01-aaaaaaa", Bool.True)]
	got = Gc.toolchains({ rows, projects: [], now, age, pinned: [r_old, n_old] }).map(|c| (c.id, c.verdict))
	got == [(r_old, Keep(Pinned)), (r_mid, Remove), (n_old, Keep(Pinned)), ("reify-2026-08-01-aaaaaaa", Keep(Default))]
}
