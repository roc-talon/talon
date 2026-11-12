import lib.Channel
import lib.Locked
import lib.ManageUse
import lib.Pin

ChannelusepinTest :: [].{}

# Slice 243 (docs/slices/243-channel-use-upgrade-gc.md), R-CH14 R-CH15 R-CH6 R-U1 R-U3 R-R4 R-CC6 R-CC7 (Design Q612, Q616). The pure decisions of `tln roc use` on a user channel and of `tln upgrade roc` for a user-channel pin.
# New names for the code agent (a proposal, TW24; until they exist this file does not compile: red on purpose). E = { name : Str, source : Str, tag_prefix : Str }.
#   `Locked.Op` gets the tag `Unpin`: it removes the whole `roc:` entry of the header (as `Remove` does for a dependency). No entry: the failure `roc is not in the header` (kind internal), as `Remove` of a missing alias.
#   `Channel.use_edit : { path : Str, text : Str, id : Str, table : E } -> Try(Str, Fail)`   (the new text of the root talon.toml: `[toolchain] roc = "=<id>"` and `[channels.<name>]`)
#   `Channel.unuse_edit : { path : Str, text : Str } -> Try([Same, Set(Str)], Fail)`   (back to a nightly: the key `[toolchain] roc` goes when it names a user build, and the table of that channel)
#   `Channel.pin_move : { text : Str, newest : Str, times : List({ id : Str, published_at : U64 }) } -> [NotUser, Same, Move(Str)]`   (`upgrade roc`: the value of `[toolchain] roc` and the newest build of the channel)
#   Design Q619: `Pin.use_gate` does not stop on an existing `=<user id>` or `>=<user id>` pin (C1); `Channel.use_edit` removes the table of the channel it leaves (C3); `Channel.unuse_edit` removes an empty `[toolchain]` (C2).
# Changed behavior, no new name: `ManageUse.use_pinnable` (a user id is a pin), `ManageUse.use_plan` (a user id: the header entry goes).

r_old = "reify-2026-11-03-1708298"

r_new = "reify-2026-11-10-abc1234"

r_mid = "reify-2026-10-30-fedcba9"

n_old = "nightly-2026-10-09-258ab27"

reify = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }

reify_text = "[channels.reify]\nshape = \"github-release\"\nsource = \"Karakatiza666/roc-reify-nightlies\"\ntag-prefix = \"nightly-reify-\"\n"

mine_text = "[channels.mine]\nshape = \"github-release\"\nsource = \"Karakatiza666/roc-mine\"\ntag-prefix = \"fork-\"\n"

pin_line = |id| "roc = \"=${id}\"\n"

# R-U1 R-CH14 R-R4 R-LK3: a user-channel id is a pin for `roc use` (it goes to `[toolchain] roc`, never to the header). A `git-`, `link-` or `copy-` id and a `debug-` id are refused as before (exit 2).
expect {
	pinnable = |id| ManageUse.use_pinnable(id).map_err(|f| (f.kind.code(), f.message))
	refused = |id| Err((2, "tln roc use does not take ${id}: a git, link or copy build cannot be a pin. Use ROC_TOOLCHAIN or tln roc default for it."))
	rows = [
		("a user id", pinnable(r_old), Ok({})),
		("the channel is read from the right", pinnable("my-fork-2026-11-03-1708298"), Ok({})),
		("a nightly (guard)", pinnable(n_old), Ok({})),
		("a release (guard)", pinnable("0.1.0"), Ok({})),
		("git (guard)", pinnable("git-dd03c09e"), refused("git-dd03c09e")),
		("link (guard)", pinnable("link-dev"), refused("link-dev")),
		("copy (guard)", pinnable("copy-fix-1"), refused("copy-fix-1")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH14 R-BL1 R-U3: what `roc use <user id>` does for each member. The baseline is the pin of the member, else the compiler that is selected (the fallback), as before. The header edit is `Unpin` for a member that has a `roc:` entry (R-CH14: "removes the header `roc:` entries").
# A member with no `roc:` entry has nothing to remove: `Err(Same)` (the talon.toml edit is not a member row). A nightly id keeps `Pin(id)` (guard). A member with no pin and no compiler is the failure of `Compiler.failure(NoCompiler)` (exit 18, guard).
expect {
	plan = |id, members, fallback| ManageUse.use_plan({ id, members, fallback })
	a = { file: "/p/a/main.roc", pin: Ok(n_old) }
	b = { file: "/p/b/main.roc", pin: Err(NoPin) }
	user = plan(r_old, [a, b], Ok(r_mid))
	user_want = Ok([
		{ file: "/p/a/main.roc", baseline: n_old, previous: Ok(n_old), op: Ok(Unpin) },
		{ file: "/p/b/main.roc", baseline: r_mid, previous: Err(NoPin), op: Err(Same) },
	])
	nightly = plan("nightly-2026-10-14-38a3029", [a, b], Ok(n_old))
	nightly_want = Ok([
		{ file: "/p/a/main.roc", baseline: n_old, previous: Ok(n_old), op: Ok(Pin("nightly-2026-10-14-38a3029")) },
		{ file: "/p/b/main.roc", baseline: n_old, previous: Err(NoPin), op: Ok(Pin("nightly-2026-10-14-38a3029")) },
	])
	none = plan(r_old, [b], Err(NoCompiler)).map_err(|f| f.kind.code())
	user == user_want and nightly == nightly_want and none == Err(18)
}

cli_url = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst"

json_url = "https://github.com/someone/roc-json/releases/download/2.1.0/9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17.tar.zst"

# R-CH14 R-H1 R-RP1: `Locked.edit` with `Unpin`. The whole entry `roc: "..."` goes with its line, and every other byte stays (comments, order, tabs). The entry may be last or in the middle. No entry: the failure of kind internal.
expect {
	edit = |text, ops| Locked.edit({ path: "/p/main.roc", text, ops }).map_err(|e| e.line())
	last = "# my app\napp [main!] {\n\tpf: platform \"${cli_url}\", # the platform\n\tjson: \"${json_url}\",\n\troc: \"${n_old}\",\n}\n\nmain! = |_args| Ok({})\n"
	last_want = "# my app\napp [main!] {\n\tpf: platform \"${cli_url}\", # the platform\n\tjson: \"${json_url}\",\n}\n\nmain! = |_args| Ok({})\n"
	middle = "app [main!] {\n\tpf: platform \"${cli_url}\",\n\troc: \"${n_old}\",\n\tjson: \"${json_url}\",\n}\n"
	middle_want = "app [main!] {\n\tpf: platform \"${cli_url}\",\n\tjson: \"${json_url}\",\n}\n"
	none = "app [main!] {\n\tpf: platform \"${cli_url}\",\n}\n"
	rows = [
		("the last entry", edit(last, [Unpin]), Ok(last_want)),
		("an entry in the middle", edit(middle, [Unpin]), Ok(middle_want)),
		("no entry", edit(none, [Unpin]), Err("tln: error[internal]: roc is not in the header")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH14 R-CH6 R-CC6 R-CC7: the edit of the root talon.toml for `roc use <user id>`. It sets `[toolchain] roc = "=<id>"` and adds `[channels.<name>]` (all keys, the text of `Channel.table_text`). The rules of `Toml.insert` and `Toml.replace` (as `IntentEdit`):
# a key that is there gets a new value and keeps the comment on its line; a new key goes after the last entry of its table; a new table goes at the end of the text after a blank line; the empty text gives a new file. When both are new, `[toolchain]` goes first.
# C1 (Design Q619): an `=<user id>` or `>=<user id>` pin is replaced. C3: when the old pin names another channel, only `[channels.<old>]` goes (with the blank line before it); other tables stay. A table `[channels.<name>]` that is there is not changed (the command compares it with `config.toml` before: R-CH10). Every other byte stays. A text that is not TOML is exit 19: `<path>:<line>: not valid TOML`.
expect {
	use_full = |text| Channel.use_edit({ path: "/p/talon.toml", text, id: r_old, table: reify })
	use = |text| use_full(text).map_err(|f| f.message)
	use_to = |text, id, table| Channel.use_edit({ path: "/p/talon.toml", text, id, table }).map_err(|f| f.message)
	mine_id = "mine-2026-11-12-1111111"
	mine = { name: "mine", source: "Karakatiza666/roc-mine", tag_prefix: "fork-" }
	acme_text = "[channels.acme]\nshape = \"github-release\"\nsource = \"acme/roc\"\ntag-prefix = \"a-\"\n"
	blocks = "[toolchain]\n${pin_line(r_old)}\n${reify_text}"
	rows = [
		("empty file", use(""), Ok(blocks)),
		("a comment", use("# project\n"), Ok("# project\n\n${blocks}")),
		("[toolchain] with a key: roc goes after the last entry", use("[toolchain]\nnightly = true\n\n[dependencies]\nx = \"1\"\n"), Ok("[toolchain]\nnightly = true\n${pin_line(r_old)}\n[dependencies]\nx = \"1\"\n\n${reify_text}")),
		("an older user pin is replaced, its comment stays", use("[toolchain]\nroc = \"=${r_mid}\" # pinned\n\n${reify_text}"), Ok("[toolchain]\nroc = \"=${r_old}\" # pinned\n\n${reify_text}")),
		("the pin and the table are there: no change", use(blocks), Ok(blocks)),
		("the table is there, no [toolchain]", use(reify_text), Ok("${reify_text}\n[toolchain]\n${pin_line(r_old)}")),
		("another channel table is there", use(mine_text), Ok("${mine_text}\n[toolchain]\n${pin_line(r_old)}\n${reify_text}")),
		("no line end at the end", use("[dependencies]\nx = \"1\""), Ok("[dependencies]\nx = \"1\"\n\n${blocks}")),
		("C1: an at-least user pin is replaced by the exact pin", use("[toolchain]\nroc = \">=${r_mid}\"\n\n${reify_text}"), Ok(blocks)),
		("C3: a pin that moves to another channel: only the old table goes, the new table is added, other tables stay", use_to("[toolchain]\nroc = \"=${r_old}\"\n\n${reify_text}\n${acme_text}", mine_id, mine), Ok("[toolchain]\nroc = \"=${mine_id}\"\n\n${acme_text}\n${mine_text}")),
		("C3: the new table is there already", use_to("[toolchain]\nroc = \"=${r_old}\"\n\n${reify_text}\n${mine_text}", mine_id, mine), Ok("[toolchain]\nroc = \"=${mine_id}\"\n\n${mine_text}")),
		("C3: a nightly pin has no table to remove", use_to("[toolchain]\nroc = \"=${n_old}\"\n\n${acme_text}", r_old, reify), Ok("[toolchain]\nroc = \"=${r_old}\"\n\n${acme_text}\n${reify_text}")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	not_toml = use_full("[toolchain]\nroc = \n").map_err(|f| (f.kind.code(), f.message))
	bad == [] and not_toml == Err((19, "/p/talon.toml:2: not valid TOML"))
}

# R-CH14 R-CC6: back to a nightly. The key `[toolchain] roc` goes when its value names a user build (`=<user id>` or `>=<user id>`), and the table `[channels.<name>]` of that channel goes with it (it is unused now). `Toml.remove`: the lines of the entry go; the blank line before the table goes
# with the table (as `Channel.remove_edit`). Every other byte stays. A value that names no user build (`*`, a nightly range, a release) and a file with no key are `Same`: the other rules of R-U5 decide. Not TOML: exit 19.
# C2 (Design Q619): a `[toolchain]` table that is empty after the removal goes too (with the blank line before it, as a table). C3: only the table of the channel that the pin names goes; other tables stay.
expect {
	unuse_full = |text| Channel.unuse_edit({ path: "/p/talon.toml", text })
	unuse = |text| unuse_full(text).map_err(|f| f.message)
	rows = [
		("key and table", unuse("[toolchain]\nnightly = true\n${pin_line(r_old)}\n${reify_text}"), Ok(Set("[toolchain]\nnightly = true\n"))),
		("other tables around", unuse("# project\n[toolchain]\n${pin_line(r_old)}nightly = true\n\n[dependencies]\nx = \"1\"\n\n${reify_text}"), Ok(Set("# project\n[toolchain]\nnightly = true\n\n[dependencies]\nx = \"1\"\n"))),
		("the table of the channel is not in this file", unuse("[toolchain]\nnightly = true\n${pin_line(r_old)}"), Ok(Set("[toolchain]\nnightly = true\n"))),
		("an at-least pin of a user build", unuse("[toolchain]\nnightly = true\nroc = \">=${r_old}\"\n\n${reify_text}"), Ok(Set("[toolchain]\nnightly = true\n"))),
		("the channel is read from the right", unuse("[toolchain]\nnightly = true\nroc = \"=my-fork-2026-11-03-1708298\"\n\n[channels.my]\nshape = \"github-release\"\nsource = \"a/b\"\ntag-prefix = \"x-\"\n\n[channels.my-fork]\nshape = \"github-release\"\nsource = \"a/c\"\ntag-prefix = \"y-\"\n"), Ok(Set("[toolchain]\nnightly = true\n\n[channels.my]\nshape = \"github-release\"\nsource = \"a/b\"\ntag-prefix = \"x-\"\n"))),
		("C2: the empty [toolchain] goes too (only table)", unuse("[toolchain]\n${pin_line(r_old)}\n${reify_text}"), Ok(Set(""))),
		("C2: no table of the channel in this file", unuse("[toolchain]\n${pin_line(r_old)}"), Ok(Set(""))),
		("C2: [toolchain] at the end of the file", unuse("[dependencies]\nx = \"1\"\n\n[toolchain]\n${pin_line(r_old)}\n${reify_text}"), Ok(Set("[dependencies]\nx = \"1\"\n"))),
		("C3: another table stays", unuse("[toolchain]\nnightly = true\n${pin_line(r_old)}\n${reify_text}\n${mine_text}"), Ok(Set("[toolchain]\nnightly = true\n\n${mine_text}"))),
		("no key", unuse("[toolchain]\nnightly = true\n"), Ok(Same)),
		("a nightly range", unuse("[toolchain]\nroc = \">=nightly-2026-10-12-2664a27\"\n"), Ok(Same)),
		("any compiler", unuse("[toolchain]\nroc = \"*\"\n"), Ok(Same)),
		("a nightly pin", unuse("[toolchain]\nroc = \"=${n_old}\"\n"), Ok(Same)),
		("empty file", unuse(""), Ok(Same)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	not_toml = unuse_full("[toolchain]\nroc = \n").map_err(|f| (f.kind.code(), f.message))
	bad == [] and not_toml == Err((19, "/p/talon.toml:2: not valid TOML"))
}

# R-CH15 R-UP8: `tln upgrade roc` for a user-channel pin. `text` is the value of `[toolchain] roc`; `newest` is the newest build of that channel that the `nightly` switch and `min-release-age` allow (the command finds it from the list). The pin moves only up and only inside its channel
# (R-CH9, `Channel.user_order`): `Move(id)` when `newest` is later than the pinned build, `Same` when it is the build or an older one (upgrade never moves down). `NotUser` for a value that names no user build: `*`, a nightly range, a release, a text that is not a range.
# U2 (Design Q619): an at-least pin `>=<user id>` works as a `>=nightly-...` range: it does not move (`NotUser`, no move). Only `=<user id>` moves.
expect {
	t = |id, at| { id, published_at: at }
	move = |text, newest, times| Channel.pin_move({ text, newest, times })
	rows = [
		("an exact pin, a newer build", move("=${r_old}", r_new, []), Move(r_new)),
		("the same build", move("=${r_new}", r_new, []), Same),
		("an older build is not a move", move("=${r_new}", r_mid, []), Same),
		("the channel is read from the right", move("=my-fork-2026-11-03-1708298", "my-fork-2026-11-10-abc1234", []), Move("my-fork-2026-11-10-abc1234")),
		("2 builds of one day: `published_at` first", move("=reify-2026-11-10-fffffff", "reify-2026-11-10-aaaaaaa", [t("reify-2026-11-10-fffffff", 1794394800), t("reify-2026-11-10-aaaaaaa", 1794398400)]), Move("reify-2026-11-10-aaaaaaa")),
		("2 builds of one day, no time: the sha", move("=reify-2026-11-10-aaaaaaa", "reify-2026-11-10-fffffff", []), Move("reify-2026-11-10-fffffff")),
		("U2: an at-least user pin does not move", move(">=${r_old}", r_new, []), NotUser),
		("U2: an at-least user pin, the same build", move(">=${r_new}", r_new, []), NotUser),
		("a nightly range", move(">=nightly-2026-10-12-2664a27", r_new, []), NotUser),
		("a nightly pin", move("=${n_old}", r_new, []), NotUser),
		("any compiler", move("*", r_new, []), NotUser),
		("a release", move("=0.1.0", r_new, []), NotUser),
		("not a range", move("soon", r_new, []), NotUser),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# C1 R-U5 R-CH14 R-CH7 (Design Q619): `Pin.use_gate` for `roc use`. An existing `=<user id>` or `>=<user id>` pin in `[toolchain] roc` is replaced, so the gate does not stop for a user build or a nightly (back to a nightly).
# Any other range (`*`, a nightly range, a nightly pin) stops a user build with exit 10 (R-CH7: no other range form matches a user channel), and nothing is edited. A nightly in a nightly range passes (guard).
expect {
	req_of = |text| match Pin.parse_req(text) {
		Ok(req) => Ok(req)
		Err(_) => Err(Unset)
	}
	gate = |id, text| Pin.use_gate({ id, req: req_of(text), req_text: Ok(text), nightly: Bool.True, source: Config, times: [] }).map_err(|f| f.kind.code())
	rows = [
		("C1: user pin =A, user build R", gate(r_new, "=${r_old}"), Ok({})),
		("C1: user pin >=A, user build R", gate(r_new, ">=${r_old}"), Ok({})),
		("C1: user pin =A, back to a nightly", gate("nightly-2026-10-14-38a3029", "=${r_old}"), Ok({})),
		("C1: user pin >=A, back to a nightly", gate("nightly-2026-10-14-38a3029", ">=${r_old}"), Ok({})),
		("C1: any compiler stops a user build", gate(r_new, "*"), Err(10)),
		("C1: a nightly range stops a user build", gate(r_new, ">=nightly-2026-10-09-258ab27"), Err(10)),
		("C1: a nightly pin stops a user build", gate(r_new, "=${n_old}"), Err(10)),
		("a nightly in a nightly range (guard)", gate("nightly-2026-10-14-38a3029", ">=${n_old}"), Ok({})),
		("a nightly out of a nightly pin (guard)", gate("nightly-2026-10-14-38a3029", "=${n_old}"), Err(10)),
		("no pin (guard)", Pin.use_gate({ id: r_new, req: Err(Unset), req_text: Err(Unset), nightly: Bool.True, source: Config, times: [] }).map_err(|f| f.kind.code()), Ok({})),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
