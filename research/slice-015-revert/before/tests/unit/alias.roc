app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Alias
import lib.Fail

main! = |_args| Ok({})

# A release URL of a GitHub repo at a version. The hash text is not checked here.
url = |repo, ver| "https://github.com/${repo}/releases/download/${ver}/Hhash.tar.zst"

# R-AD8 R-AD9 R-AD10 R-AD11 R-AD12 R-AD15: the default alias is the repo name. Only a leading `roc-` is dropped, and
# `-` and `.` become `_`. No other prefix or suffix is dropped, and nothing is abbreviated.
expect {
	rows = [
		("roc-lang/basic-cli", "basic_cli"),
		("roc-lang/unicode", "unicode"),
		("lukewilliamboswell/roc-parser", "parser"),
		("someone/roc-json", "json"),
		("roc-lang/roc-ray", "ray"),
		("someone/json-roc", "json_roc"),
		("someone/parser-roc", "parser_roc"),
		("someone/my.lib", "my_lib"),
		("someone/Foo-Bar", "Foo_Bar"),
	]
	bad = rows.keep_if(|(name, want)| Alias.default(name) != want).map(|(name, want)| (name, want, Alias.default(name)))
	dbg bad
	bad == []
}

# R-AD14 R-AD16 R-AD17: an alias is a Roc name: a lowercase ASCII letter first, then ASCII letters, digits and `_`.
# The reserved words that the design names are refused.
expect {
	good = ["basic_cli", "json", "a1", "x_", "aB"]
	not_name = ["Json", "9lives", "_x", "a$b", "", "a b", "caf\u(e9)"]
	reserved = ["app", "package", "module", "import", "if", "match", "for"]
	bad_good = good.keep_if(|a| Alias.check(a) != Ok({}))
	bad_name = not_name.keep_if(|a| Alias.check(a) != Err(NotName))
	bad_reserved = reserved.keep_if(|a| Alias.check(a) != Err(Reserved))
	dbg (bad_good, bad_name, bad_reserved)
	bad_good == [] and bad_name == [] and bad_reserved == []
}

# R-AD13 R-AD30 R-AD16 R-AD17 R-AD18 R-AD19 R-AD20 R-I9: the alias of a new entry, and the cases with no new entry.
# The platform is `pf`. `--as` skips the default rule but not the checks. An alias that the header has for another group
# (also a path entry) is refused: never a suffix. A group that the header has already is `Existing` under its alias.
expect {
	json_old = { alias: "json", url: url("someone/roc-json", "2.1.0"), is_platform: Bool.False }
	js_old = { alias: "js", url: url("someone/roc-json", "2.0.0"), is_platform: Bool.False }
	parser_other = { alias: "parser", url: url("other/parser", "1.0.0"), is_platform: Bool.False }
	util_path = { alias: "util", url: "../util/main.roc", is_platform: Bool.False }
	pf_old = { alias: "pf", url: url("roc-lang/basic-cli", "0.25.0"), is_platform: Bool.True }
	go = |name, ver, is_platform, as_alias, header| match Alias.choose({ name, url: url(name, ver), is_platform, as_alias, header }) {
		Ok(a) => Ok(a)
		Err(f) => Err(Fail.line(f))
	}
	no = Err(Unset)
	rows = [
		(go("roc-lang/basic-cli", "0.25.0", Bool.False, no, []), Ok(Alias.New("basic_cli"))),
		(go("someone/roc-json", "2.1.0", Bool.False, no, [parser_other]), Ok(Alias.New("json"))),
		(go("roc-lang/basic-cli", "0.25.0", Bool.True, no, [parser_other]), Ok(Alias.New("pf"))),
		(go("someone/roc-yaml", "1.0.0", Bool.False, Ok("yml"), []), Ok(Alias.New("yml"))),
		(
			go("owner/9lives", "1.0.0", Bool.False, no, []),
			Err("tln: error[usage]: the default alias '9lives' for 'owner/9lives' is not a valid name. Use --as <alias>."),
		),
		(
			go("owner/roc-import", "1.0.0", Bool.False, no, []),
			Err("tln: error[usage]: the default alias 'import' for 'owner/roc-import' is a reserved word. Use --as <alias>."),
		),
		(
			go("owner/roc-parser", "1.0.0", Bool.False, no, [parser_other]),
			Err("tln: error[usage]: the default alias 'parser' for 'owner/roc-parser' is used by another package in the header. Use --as <alias>."),
		),
		(
			go("owner/util", "1.0.0", Bool.False, no, [util_path]),
			Err("tln: error[usage]: the default alias 'util' for 'owner/util' is used by another package in the header. Use --as <alias>."),
		),
		(
			go("owner/roc-parser", "1.0.0", Bool.False, Ok("parser"), [parser_other]),
			Err("tln: error[usage]: alias 'parser' is used by another package in the header."),
		),
		(
			go("owner/x", "1.0.0", Bool.False, Ok("Bad"), []),
			Err("tln: error[usage]: 'Bad' is not a valid alias. Use letters, digits and _, and start with a lowercase letter."),
		),
		(
			go("owner/x", "1.0.0", Bool.False, Ok("app"), []),
			Err("tln: error[usage]: 'app' is a reserved word, not a valid alias."),
		),
		(go("someone/roc-json", "2.1.0", Bool.False, no, [json_old]), Ok(Alias.Existing("json"))),
		(go("someone/roc-json", "2.1.0", Bool.False, no, [parser_other, js_old]), Ok(Alias.Existing("js"))),
		(go("someone/roc-json", "2.1.0", Bool.False, Ok("other"), [js_old]), Ok(Alias.Existing("js"))),
		(go("roc-lang/basic-cli", "0.25.0", Bool.True, no, [pf_old]), Ok(Alias.Existing("pf"))),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad
	bad == []
}
