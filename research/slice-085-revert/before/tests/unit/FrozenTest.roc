import lib.Frozen
import lib.Intent
import lib.Locked
import lib.Vars

FrozenTest :: [].{}

h_json1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h_json2 = "J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr"

h_cli = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

json1 = "https://github.com/someone/roc-json/releases/download/2.1.0/${h_json1}.tar.zst"

json2 = "https://github.com/someone/roc-json/releases/download/2.3.0/${h_json2}.tar.zst"

cli = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${h_cli}.tar.zst"

n1 = "nightly-2026-10-09-258ab27"

member = |file, entries, toml| {
	text = "app [main!] {\n${Str.join_with(entries.map(|e| "\t${e},"), "\n")}\n}\n"
	locked = match Locked.read({ path: file, text }) {
		Ok(l) => l
		Err(e) => crash e.line()
	}
	parsed = match toml {
		Err(NoToml) => Err(NoToml)
		Ok({ path, text: toml_text, role }) => match Intent.read({ path, text: toml_text, role }) {
			Ok({ intent, .. }) => Ok({ path, intent })
			Err(e) => crash e.line()
		}
	}
	{ file, locked, toml: parsed }
}

## `tln install --frozen` on members: the findings, as the line of the failure (the text of `Ok` is `ok`).
check = |members, outside, req_text, nightly| {
	built = match Vars.build({ members, priority: Err(Unset) }) {
		Ok(b) => b
		Err(e) => crash e.line()
	}
	scoped = match Vars.scope({ command: Install, names: [], selectors: [], vars: built.vars }) {
		Ok(s) => s
		Err(e) => crash e.line()
	}
	match Frozen.check({ scoped, wants: built.wants, outside, req_text, nightly }) {
		Ok({}) => "ok"
		Err(e) => "${e.kind.code().to_str()} ${e.line()}"
	}
}

# R-LF1 R-SP22 R-SP19 R-SP20 R-SP21 R-WS3 R-I5 R-I8 R-SO17 R-NS5 R-DT6 R-EC14: `--frozen` resolves nothing and fails (exit 14) when plain `install` would resolve something: a header entry outside its range (the range of
# its key, or the implied range), a key of `talon.toml` that the header does not have (or has under another alias), or a `roc:` pin that `[toolchain] roc` or the `nightly` switch does not allow. With no `talon.toml` and one member
# there is nothing to resolve (R-SP21). 2 members with 2 versions of one group: the older one is outside the intersection of the implied ranges (R-WS3). The findings are joined, in this order: uses, keys, the pin.
expect {
	entries = ["pf: platform \"${cli}\"", "json: \"${json1}\""]
	toml = |text| Ok({ path: "/p/talon.toml", text, role: Standalone })
	one = |text| [member("/p/main.roc", entries, toml(text))]
	none = Err(None)
	no_req = Err(Unset)
	a = member("/w/apps/a/main.roc", ["json: \"${json1}\""], Err(NoToml))
	b = member("/w/apps/b/main.roc", ["js: \"${json2}\""], Err(NoToml))
	prefix = "14 tln: error[frozen]: the header does not satisfy talon.toml: "
	rows = [
		("no talon.toml: nothing to resolve (R-SP21)", check([member("/p/main.roc", entries, Err(NoToml))], none, no_req, Bool.True), "ok"),
		("the header satisfies the ranges (R-SP19)", check(one("[dependencies]\njson = \"^2.1\"\npf = \"0.25.*\"\n"), none, no_req, Bool.True), "ok"),
		("an entry outside its range (R-SP20)", check(one("[dependencies]\njson = \"^2.2\"\n"), none, no_req, Bool.True), "${prefix}/p/main.roc: json 2.1.0 is outside ^2.2"),
		("an anchor that the header does not hold", check(one("[dependencies]\njson = \"=2.0.0\"\n"), none, no_req, Bool.True), "${prefix}/p/main.roc: json 2.1.0 is outside =2.0.0"),
		("a key that the header does not have (R-I5)", check(one("[dependencies]\nhttp = \"roc-lang/http@^1\"\n"), none, no_req, Bool.True), "${prefix}talon.toml: key \"http\" is not in the header"),
		("a key that is a header entry under another alias (R-I8)", check(one("[dependencies]\njs = \"someone/roc-json@^2\"\n"), none, no_req, Bool.True), "${prefix}talon.toml: key \"js\" is \"someone/roc-json\", which the header names \"json\""),
		("2 members, 2 versions of one group (R-WS3)", check([a, b], none, no_req, Bool.True), "${prefix}/w/apps/a/main.roc: json 2.1.0 is outside >=2.1.0, <3.0.0 and >=2.3.0, <3.0.0"),
		("a pin outside the compiler range (R-SO17)", check(one(""), Ok(n1), Ok(">=nightly-2026-10-13-91fa0c2"), Bool.True), "${prefix}the roc pin ${n1} is outside [toolchain] roc (>=nightly-2026-10-13-91fa0c2)"),
		("a nightly pin, the switch is off (R-NS5)", check(one(""), Ok(n1), no_req, Bool.False), "${prefix}the roc pin ${n1} is a nightly, and nightly is false"),
		("all findings, in order", check(one("[dependencies]\njson = \"^2.2\"\nhttp = \"roc-lang/http@^1\"\n"), Ok(n1), Ok("0.1.*"), Bool.True), "${prefix}/p/main.roc: json 2.1.0 is outside ^2.2; talon.toml: key \"http\" is not in the header; the roc pin ${n1} is outside [toolchain] roc (0.1.*)"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
