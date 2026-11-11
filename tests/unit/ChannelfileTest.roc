import lib.Channel

ChannelfileTest :: [].{}

# Slice 242 (docs/slices/242-channel-commands.md), R-CH12 R-CH13 R-CH1 R-CH2 (Design Q612, CLI R-CC6 R-CC7). The text of a table and the edits of config.toml by `tln roc channel add` and `rm`, and the text of `list`.
# New names for the code agent (a proposal, TW24; until they exist this file does not compile: red on purpose). E = { name : Str, source : Str, tag_prefix : Str }.
#   `Channel.table_text : E -> Str`   (the 4 lines of the table, each with an end of line; the form of the design example and of 238)
#   `Channel.add_edit : { path : Str, text : Str, table : E } -> Try(Str, Fail)`   (the new text of config.toml; a text that is not TOML is exit 19, as `Manage.default_set`)
#   `Channel.remove_edit : { path : Str, text : Str, name : Str } -> Try([Same, Set(Str)], Fail)`   (the table, its lines and the blank lines before it go; every other byte stays)
#   `Channel.list_text : { config : List(E), project : List(E) } -> Str`   (Q617 item 7: a header, the built-in row, the tables of `config.toml` in file order, then the tables that only the project has; no end of line at the end)
#   `Channel.list_data : { config : List(E), project : List(E) } -> JsonDoc`   (the `data` of `--json`, a proposal)

reify = { name: "reify", source: "Karakatiza666/roc-reify-nightlies", tag_prefix: "nightly-reify-" }

mine = { name: "mine", source: "Karakatiza666/roc-mine", tag_prefix: "fork-" }

reify_text = "[channels.reify]\nshape = \"github-release\"\nsource = \"Karakatiza666/roc-reify-nightlies\"\ntag-prefix = \"nightly-reify-\"\n"

mine_text = "[channels.mine]\nshape = \"github-release\"\nsource = \"Karakatiza666/roc-mine\"\ntag-prefix = \"fork-\"\n"

reify2_text = "[channels.reify2]\nshape = \"github-release\"\nsource = \"acme/roc-reify2\"\ntag-prefix = \"r2-\"\n"

# R-CH12 R-CH10: the table as the command writes and prints it: the keys in the order of the design example, `shape` always `github-release`.
expect {
	Channel.table_text(reify) == reify_text and Channel.table_text(mine) == mine_text
}

# R-CH12 R-CC6: the edit of config.toml that adds a table. The table goes at the end of the file. A blank line is before it, unless the text is empty. The file ends with a line end. Every other byte stays.
# A text that is not TOML is a failure of kind `Input` (exit 19): `<path>:<line>: not valid TOML`. A name that is in the file already is `Channel.exists_check` (Q617 item 1): the command does not call `add_edit` then.
expect {
	add_full = |text| Channel.add_edit({ path: "/c/config.toml", text, table: reify })
	add = |text| add_full(text).map_err(|f| f.message)
	rows = [
		("empty file", add(""), Ok(reify_text)),
		("a key", add("nightly = true\n"), Ok("nightly = true\n\n${reify_text}")),
		("no line end at the end", add("nightly = true"), Ok("nightly = true\n\n${reify_text}")),
		("a blank line at the end", add("nightly = true\n\n"), Ok("nightly = true\n\n${reify_text}")),
		("a comment", add("# mine\n"), Ok("# mine\n\n${reify_text}")),
		("another table", add("[probe]\nslots = 12\n"), Ok("[probe]\nslots = 12\n\n${reify_text}")),
		("another channel", add("nightly = true\n\n${mine_text}"), Ok("nightly = true\n\n${mine_text}\n${reify_text}")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad_toml = add_full("nightly = \n")
	dbg bad_toml
	bad == [] and bad_toml.map_err(|f| (f.kind.code(), f.message)) == Err((19, "/c/config.toml:1: not valid TOML"))
}

# R-CH13 R-CC6: the edit of config.toml that removes a table. The header, the keys of the table and the blank lines before it go. Every other byte stays (the default, the other tables).
# `reify` is not `reify2`. A name that is not there is `Same` (no write). Not TOML: kind `Input`.
expect {
	rm_full = |text| Channel.remove_edit({ path: "/c/config.toml", text, name: "reify" })
	rm = |text| rm_full(text).map_err(|f| f.message)
	rows = [
		("the only table", rm(reify_text), Ok(Set(""))),
		("after a key", rm("nightly = true\n\n${reify_text}"), Ok(Set("nightly = true\n"))),
		("between 2 tables", rm("${mine_text}\n${reify_text}\n[probe]\nslots = 12\n"), Ok(Set("${mine_text}\n[probe]\nslots = 12\n"))),
		("reify2 stays", rm("nightly = true\n\n${reify_text}\n${reify2_text}"), Ok(Set("nightly = true\n\n${reify2_text}"))),
		("no such table", rm("nightly = true\n"), Ok(Same)),
		("empty file", rm(""), Ok(Same)),
		("only reify2", rm("${reify2_text}"), Ok(Same)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad_toml = rm_full("nightly = \n")
	dbg bad_toml
	bad == [] and bad_toml.map_err(|f| (f.kind.code(), f.message)) == Err((19, "/c/config.toml:1: not valid TOML"))
}

# R-CH13 R-CH1 R-CH2, Design Q617 item 7: `tln roc channel list`. A header line (as `tln roc list`), then the built-in `nightly` table, then the tables of config.toml in file order, then the tables that only the project talon.toml has,
# marked `talon.toml (not added)`. 4 columns: NAME, SHAPE, SOURCE, FROM (`built-in`, `config.toml`, `talon.toml (not added)`). Every gap is the widest cell and 2 spaces; the last column has no padding (TW24: the form of `tln roc list`).
# A table in both files (equal, R-CH10) is a table of config.toml.
expect {
	my_fork = { name: "my-fork", source: "acme/roc-fork", tag_prefix: "fork-" }
	ab = { name: "ab", source: "a/b", tag_prefix: "x-" }
	list = |config, project| Channel.list_text({ config, project })
	rows = [
		("one user table", list([reify], []), "NAME     SHAPE           SOURCE                             FROM\nnightly  github-release  roc-lang/nightlies                 built-in\nreify    github-release  Karakatiza666/roc-reify-nightlies  config.toml"),
		("file order", list([reify, my_fork], []), "NAME     SHAPE           SOURCE                             FROM\nnightly  github-release  roc-lang/nightlies                 built-in\nreify    github-release  Karakatiza666/roc-reify-nightlies  config.toml\nmy-fork  github-release  acme/roc-fork                      config.toml"),
		("short cells", list([ab], []), "NAME     SHAPE           SOURCE              FROM\nnightly  github-release  roc-lang/nightlies  built-in\nab       github-release  a/b                 config.toml"),
		("none", list([], []), "NAME     SHAPE           SOURCE              FROM\nnightly  github-release  roc-lang/nightlies  built-in"),
		("project only", list([mine], [reify]), "NAME     SHAPE           SOURCE                             FROM\nnightly  github-release  roc-lang/nightlies                 built-in\nmine     github-release  Karakatiza666/roc-mine             config.toml\nreify    github-release  Karakatiza666/roc-reify-nightlies  talon.toml (not added)"),
		("both files", list([reify], [reify]), "NAME     SHAPE           SOURCE                             FROM\nnightly  github-release  roc-lang/nightlies                 built-in\nreify    github-release  Karakatiza666/roc-reify-nightlies  config.toml"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH13, R-J1 to R-J3, Design Q617 item 7 (TW24, R-OUT2): the `data` of `tln roc channel list --json`. The keys are snake_case as in `roc list`. `origin` is `built-in`, `config` or `project`; `added` is false for a table that only the project has.
expect {
	got = Channel.list_data({ config: [reify], project: [mine] }).render()
	dbg got
	got
		== "{\"channels\":[{\"name\":\"nightly\",\"shape\":\"github-release\",\"source\":\"roc-lang/nightlies\",\"tag_prefix\":\"nightly-\",\"origin\":\"built-in\",\"added\":true},{\"name\":\"reify\",\"shape\":\"github-release\",\"source\":\"Karakatiza666/roc-reify-nightlies\",\"tag_prefix\":\"nightly-reify-\",\"origin\":\"config\",\"added\":true},{\"name\":\"mine\",\"shape\":\"github-release\",\"source\":\"Karakatiza666/roc-mine\",\"tag_prefix\":\"fork-\",\"origin\":\"project\",\"added\":false}]}"
}
