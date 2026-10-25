import Fail
import TomlKeys
import toml.Toml

## The `[tools]` table of `talon.toml` (slice 056, CLI 6.4: R-PT1, R-PT2, R-PT3, R-PT5, R-TF4, R-CC7). Part A (pure, TESTING.md 2.2). `Intent.read` calls `read_table` (R-PT1: a form that is not valid is exit code 19, R-TF4), the commands
## call `put`, `drop` and `spans` for the edits. An edit changes only its own bytes (the file is edited with `roc-toml`), so the comments, the order and the blank lines of the file stay.
##
## One entry is an inline table with the key `ref` (required) and the key `url` (optional, because `tln install` writes it, R-PT5):
##
## ```toml
## [tools]
## roc-cfw = { ref = "Karakatiza666/roc-cloudflare-workers-cli@^1", url = "https://github.com/.../releases/download/1.0.3/<hash>.tar.zst" }
## ```
ToolsToml :: [].{

	## One entry of `[tools]`: the key (the name of the program in a step), the `ref` text as written, the `url` text as written (`Err(Unset)` when the entry has none), and the 1-based line of the key.
	Entry : { key : Str, ref : Str, url : Try(Str, [Unset]), line : U64 }

	## R-PT1: is the text a key of `[tools]`? The form is `[a-z0-9][a-z0-9._-]*`: lower case letters, digits, `.`, `_` and `-`, and it starts with a letter or a digit.
	is_key : Str -> Bool
	is_key = |_text| crash "todo: slice 056"

	## R-PT1, R-TF4: the entries of the table `[tools]` of a parsed document, in the order of their lines. No table gives no entry. `issues` are failures of kind `Input` (exit 19): the read of `Intent` takes the first one by line, as for the other tables. `warnings` do not stop the command.
	## The form of the messages is `<table>.<key>...: <why>` (`Intent.read` puts `<path>:<line>: ` before it). The texts are proposals (TW24):
	##
	## | Case | Message | Kind of note |
	## | --- | --- | --- |
	## | `[tools]` is not a table | `tools: must be a table` | issue |
	## | The key is not `is_key` | `tools.<key>: the key is not a tool name (lower case letters, digits, '.', '_' and '-', and the first one a letter or a digit)` | issue |
	## | The value is not a table | `tools.<key>: must be a table with ref and url` | issue |
	## | No `ref`, or a `ref` that is not a string | `tools.<key>.ref: must be a string` | issue |
	## | `ref` is not `Ref.parse` with the scope `Tool` | `tools.<key>.ref: <the failure message of Ref.parse>` | issue |
	## | `ref` is not a full name `owner/app` | `tools.<key>.ref: '<name>' is not an owner/app name` | issue |
	## | `ref` has a selector other than a version, a range or `latest` (a git sha, a compiler) | `tools.<key>.ref: '<selector text>' is not a release selector (a version, a range or latest)` | issue |
	## | `url` is not a string | `tools.<key>.url: must be a string` | issue |
	## | `url` is not a release URL (`Ident.of_url` fails) | `tools.<key>.url: '<url>' is not a release URL with a version and a hash` | issue |
	## | Another key of the entry | `unknown key tools.<key>.<name>` | warning |
	##
	## A `ref` with no selector and `@latest` are the same (R-PT1, R-T26). The `url` text is not compared with the `ref` here: that is R-PT7 (`ToolsPlan.frozen_check`).
	read_table : Toml -> { value : List(ToolsToml.Entry), issues : List(TomlKeys.Note), warnings : List(TomlKeys.Note) }
	read_table = |_doc| crash "todo: slice 056"

	## R-PT3, R-PT5: the text with the entry `<key> = { ref = "<ref>", url = "<url>" }` (the key `ref` first). The entry of `key` that is there is replaced where it is (the comment on its line stays). A new key goes after the last entry of `[tools]`. With no table, a new `[tools]` table goes
	## at the end of the text, after a blank line. The empty text gives `[tools]`, the entry, and the line end (not the form `[tools.<key>]`). A text with no line end at its end gets one first. All other bytes stay.
	##
	## | Case | Result |
	## | --- | --- |
	## | A text that is not TOML | Failure of kind `Input`: `<path>:<line>: not valid TOML` |
	## | The entry cannot be written (`tools` is a value that is not a table) | Failure of kind `Input`: `<path>: the key tools.<key> cannot be written` |
	put : { path : Str, text : Str, key : Str, ref : Str, url : Str } -> Try(Str, Fail)
	put = |_facts| crash "todo: slice 056"

	## R-PT3: the text without the entries `keys` of `[tools]` (`Toml.remove`: the lines of the entry go, with the comment on its last line; the comment lines above and the header of a table that becomes empty stay). All other bytes stay.
	##
	## | Case | Result |
	## | --- | --- |
	## | A key that is not in `[tools]` | Failure of kind `Internal`: `<path>: the key '<key>' is not there` |
	## | A text that is not TOML | Failure of kind `Input`: `<path>:<line>: not valid TOML` |
	## | No key | The text as it is |
	drop : { path : Str, text : Str, keys : List(Str) } -> Try(Str, Fail)
	drop = |_facts| crash "todo: slice 056"

	## R-CC7: the text of the value of each key in `[tools]` (the text that `Toml.get` gives, printed with `Value.print`), `""` for a key that is not there, in the order of `keys`. They are the span texts for `Guard.check_all`.
	spans : { text : Str, keys : List(Str) } -> List(Str)
	spans = |_facts| crash "todo: slice 056"
}

Note : TomlKeys.Note

One : { entry : Try(ToolsToml.Entry, [Bad]), issues : List(Note), warnings : List(Note) }
