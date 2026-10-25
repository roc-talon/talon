import lib.Alias
import lib.Fail

AliasTest :: [].{}

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
# is refused: never a suffix. A group that the header has already is `Existing` under its alias.
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
			Err("tln: error[usage]: the default alias 'util' for 'owner/util' is used by a path entry in the header. Use --as <alias>, or --as util to replace that entry."),
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

# R-AD18 R-AD19 R-AD38 R-H9 R-H4 R-AD16 R-AD13 (slice 015): an alias of an unmanaged entry (a path entry or a foreign URL). `--as <alias>` that names it is `Unmanaged`: `tln add` replaces the whole entry
# under that alias (R-AD38), also the platform entry. The default alias never replaces: it is `Taken`, and the text says that `--as <that alias>` replaces the entry (R-AD18). The checks 1 and 2 (a valid
# name, no reserved word) come first, so a bad `--as` is no `Unmanaged`. An alias of a release of another group stays `Taken` for `--as` (R-AD18). The group check comes first (R-AD19): a group that the header has
# under another alias is `Existing`, also when `--as` names an unmanaged entry.
expect {
	util_path = { alias: "util", url: "../util/main.roc", is_platform: Bool.False }
	odd_foreign = { alias: "odd", url: "https://example.com/pkg/latest.tar.gz", is_platform: Bool.False }
	pf_path = { alias: "pf", url: "../platform/main.roc", is_platform: Bool.True }
	pf_pkg_path = { alias: "pf", url: "../tools/main.roc", is_platform: Bool.False }
	parser_other = { alias: "parser", url: url("other/parser", "1.0.0"), is_platform: Bool.False }
	js_old = { alias: "js", url: url("someone/roc-json", "2.0.0"), is_platform: Bool.False }
	go = |name, ver, is_platform, as_alias, header| match Alias.choose({ name, url: url(name, ver), is_platform, as_alias, header }) {
		Ok(a) => Ok(a)
		Err(f) => Err(Fail.line(f))
	}
	no = Err(Unset)
	rows = [
		("--as, a path entry", go("owner/util", "1.0.0", Bool.False, Ok("util"), [util_path, odd_foreign]), Ok(Alias.Unmanaged("util"))),
		("--as, a foreign URL", go("owner/lib", "1.0.0", Bool.False, Ok("odd"), [util_path, odd_foreign]), Ok(Alias.Unmanaged("odd"))),
		("--as, the platform entry, a platform release", go("roc-lang/basic-cli", "0.25.0", Bool.True, Ok("pf"), [pf_path, util_path]), Ok(Alias.Unmanaged("pf"))),
		("--as, the platform entry, a package (Add.decide stops it: R-AD32)", go("owner/lib", "1.0.0", Bool.False, Ok("pf"), [pf_path]), Ok(Alias.Unmanaged("pf"))),
		(
			"the default alias, a path entry",
			go("owner/util", "1.0.0", Bool.False, no, [util_path, odd_foreign]),
			Err("tln: error[usage]: the default alias 'util' for 'owner/util' is used by a path entry in the header. Use --as <alias>, or --as util to replace that entry."),
		),
		(
			"the default alias, a foreign URL",
			go("owner/roc-odd", "1.0.0", Bool.False, no, [util_path, odd_foreign]),
			Err("tln: error[usage]: the default alias 'odd' for 'owner/roc-odd' is used by a foreign URL in the header. Use --as <alias>, or --as odd to replace that entry."),
		),
		(
			"the alias pf of a platform that is new, a path entry of a package has the alias",
			go("roc-lang/basic-cli", "0.25.0", Bool.True, no, [pf_pkg_path]),
			Err("tln: error[usage]: the default alias 'pf' for 'roc-lang/basic-cli' is used by a path entry in the header. Use --as <alias>, or --as pf to replace that entry."),
		),
		(
			"--as, not a valid name: the check 1 comes first",
			go("owner/util", "1.0.0", Bool.False, Ok("Util"), [util_path]),
			Err("tln: error[usage]: 'Util' is not a valid alias. Use letters, digits and _, and start with a lowercase letter."),
		),
		("--as, a release of another group stays taken", go("owner/x", "1.0.0", Bool.False, Ok("parser"), [parser_other, util_path]), Err("tln: error[usage]: alias 'parser' is used by another package in the header.")),
		("--as, a free alias is new", go("owner/x", "1.0.0", Bool.False, Ok("tool"), [util_path]), Ok(Alias.New("tool"))),
		("the group is in the header: Existing, also with --as of an unmanaged entry", go("someone/roc-json", "2.1.0", Bool.False, Ok("util"), [js_old, util_path]), Ok(Alias.Existing("js"))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
