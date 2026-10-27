import lib.Args
import lib.Fail
import lib.Ident
import lib.Index
import lib.Init
import lib.InitStub
import lib.InitText

InitTest :: [].{}

now = 1792065600

day = 86400

# A release URL of the fixture host (as in `upgrade.roc`).
u = |ver| "https://github.com/roc-lang/basic-cli/releases/download/${ver}/bx${ver.replace_each(".", "x")}.tar.zst"

cand = |ver, days| match Ident.of_url(u(ver)) {
	Ok(ident) => { url: u(ver), ident, tag: ver, published_at: now - days * day, size: 1 }
	Err(_) => crash "bad test URL"
}

# The start release as text: the URL, or `none`.
start_view = |rows, min_age| match Init.start({ name: "roc-lang/basic-cli", list: rows.map(|(ver, days)| cand(ver, days)), now, min_age }) {
	Ok(c) => c.url
	Err(NoRelease) => "none"
}

# The options of `init` as text (the failure is a text: an `Err` record with a `Bool` crashes `roc test`).
read_view = |words| match Args.parse(words) {
	Err(stop) => Fail.line(stop.fail)
	Ok(args) => match Init.read(args) {
		Err(f) => Fail.line(f)
		Ok(plan) => {
			t = match plan.template {
				App => "app"
				Package => "package"
			}
			p = match plan.named {
				Ok(name) => name
				Err(Unset) => "-"
			}
			c = match plan.ci {
				Ci => "ci"
				NoCi => "no-ci"
			}
			"${t} ${p} ${c}"
		}
	}
}

# R-CM1 R-IN1 R-IN6 R-EC2 (the checks of an `init` line): no operand is an app, the template names, `--platform`, `--ci` (default: the CI file). The failure texts are a proposal (TW24).
expect {
	rows = [
		(["init"], "app - ci"),
		(["init", "app"], "app - ci"),
		(["init", "package"], "package - ci"),
		(["init", "package", "--ci", "none"], "package - no-ci"),
		(["init", "--ci", "github"], "app - ci"),
		(["init", "--ci=none", "--platform=acme/pfx"], "app acme/pfx no-ci"),
		(["init", "app", "--platform", "acme/pfx"], "app acme/pfx ci"),
		(["init", "lib"], "tln: error[usage]: unknown template 'lib': use app or package"),
		(["init", "App"], "tln: error[usage]: unknown template 'App': use app or package"),
		(["init", "app", "package"], "tln: error[usage]: tln init takes one template name (app or package), got 2 names"),
		(["init", "--ci", "yes"], "tln: error[usage]: --ci must be github or none, not 'yes'"),
		(["init", "--ci"], "tln: error[usage]: flag '--ci' needs a value"),
		(["init", "--platform"], "tln: error[usage]: flag '--platform' needs a value"),
		# Q4, Q6: `--platform` is a full name `owner/repo` and does not work with a package
		(["init", "package", "--platform", "acme/pfx"], "tln: error[usage]: --platform does not work with the package template: a package has no platform"),
		(["init", "--platform", "pfx"], "tln: error[usage]: 'pfx' is not a platform name: use owner/repo"),
		(["init", "--platform", "acme/pfx@1"], "tln: error[usage]: 'acme/pfx@1' is not a platform name: use owner/repo"),
		(["init", "--platform", "a/b/c"], "tln: error[usage]: 'a/b/c' is not a platform name: use owner/repo"),
		(["init", "--platform", "/pfx"], "tln: error[usage]: '/pfx' is not a platform name: use owner/repo"),
	]
	bad = rows.keep_if(|(words, want)| read_view(words) != want).map(|(words, want)| (words, want, read_view(words)))
	dbg bad
	bad == []
}

# R-IN1 R-IN2 R-C7: the release that the template starts at. The highest version of the releases that min-release-age does not hide (a release at the limit is visible). The resolve then moves it as `upgrade` does.
expect {
	two_days = 2 * day
	rows = [
		# The highest version, not the newest time (0.24.1 is newer than 0.25.0), and numbers, not text (0.10.0 is above 0.9.0)
		(start_view([("0.9.0", 40), ("0.25.0", 30), ("0.24.1", 10), ("0.10.0", 20)], two_days), u("0.25.0")),
		(start_view([("0.9.0", 40), ("0.10.0", 20)], two_days), u("0.10.0")),
		# R-C7: a release of 1 day is hidden by 2 days, and visible when the age is 0 or 1 day. At the limit it is visible.
		(start_view([("0.24.0", 30), ("0.25.0", 30), ("0.26.0", 1)], two_days), u("0.25.0")),
		(start_view([("0.25.0", 30), ("0.26.0", 1)], 0), u("0.26.0")),
		(start_view([("0.25.0", 30), ("0.26.0", 1)], day), u("0.26.0")),
		(start_view([("0.25.0", 30), ("0.26.0", 2)], two_days), u("0.26.0")),
		(start_view([("0.25.0", 30), ("0.26.0", 2), ("0.27.0", 1)], two_days), u("0.26.0")),
		# no release is left
		(start_view([("0.26.0", 1)], two_days), "none"),
		(start_view([("0.25.0", 1), ("0.26.0", 0)], two_days), "none"),
		(start_view([], two_days), "none"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-IN1 R-IN4 R-IN5 R-IN6 (the texts of the files, a proposal, TW24): the app has the platform entry and no `roc:` entry (the resolve writes the pin), and no `talon.toml` text exists. The default platform has a hello world (another platform gets the stub of `InitStub`, slice 055). The CI file has the version of `tln` twice and the 4 steps of R-IN6.
expect {
	url = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/h.tar.zst"
	hello = InitText.app_file({ name: "roc-lang/basic-cli", url })
	ci = InitText.ci_file("1.2.3")
	checks = [
		(InitText.default_platform, "roc-lang/basic-cli"),
		(hello, "app [main!] {\n\tpf: platform \"${url}\",\n}\n\nimport pf.Stdout\n\nmain! = |_args| {\n\tStdout.line!(\"Hello, World!\")?\n\tOk({})\n}\n"),
		(InitText.package_file, "package [] {\n}\n"),
		(if hello.contains("roc:") or InitText.package_file.contains("roc:") "a roc entry" else "no roc entry", "no roc entry"),
		(if ci.contains("curl -fsSL https://github.com/roc-talon/talon/releases/download/v1.2.3/install.sh | sh -s -- --yes --version 1.2.3\n") "install line" else "no install line", "install line"),
		(if ci.contains("runs-on: ubuntu-latest\n") "ubuntu-latest" else "other runner", "ubuntu-latest"),
		(if ci.contains("TALON_AUTO_INSTALL: \"yes\"") "auto install" else "no auto install", "auto install"),
		(if ci.contains("run: tln install --frozen\n") and ci.contains("run: roc check\n") and ci.contains("run: roc test\n") "steps" else "missing step", "steps"),
		(if ci.contains("0.0.0") "the version is fixed" else "the version is a parameter", "the version is a parameter"),
		(if ci.contains("tln audit") "audit" else "no audit", "no audit"),
	]
	bad = checks.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-IN8 R-SM2 (answer OP8, a proposal for the layout, TW24): the stub app of `init --platform`. The app gives the platform each value of its `requires` clause, with the body `crash "write the app"`: a lambda with one `_` for each argument of a
# function type (`()` has none), a record of stubs for a record type (a tab more for each level), `Alias : {}` for each alias of `[Alias : var] for name : ...`, and the app exposes each alias and each name. A type of another form
# (`Str`, `U16`, `List(Str)`, a tag union) has no stub: exit 2, the message names the first such type in source order, also one in a record field (R-SM2 "any other type"). A clause with 2 or more entries is also exit 2 (answer Q6). The reading of the clause (comments, strings, the old form
# `requires {} { ... }`, entries) is in the doc of `InitStub.app_text`.
expect {
	url = "https://github.com/acme/pf/releases/download/0.1.0/h.tar.zst"
	hdr = |clause, before| "platform \"acme\"\n${before}\trequires ${clause}\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n"
	view = |clause, before| match InitStub.app_text({ name: "acme/pf", url, text: hdr(clause, before) }) {
		Ok(text) => text
		Err(f) => Fail.line(f)
	}
	stub_app = |names, body| "app [${names}] {\n\tpf: platform \"${url}\",\n}\n\n${body}"
	crashes = "crash \"write the app\""
	no_clause = "tln: error[usage]: acme/pf has no requires clause: it is not a platform (R-IN8)"
	no_stub = |value, type_text| "tln: error[usage]: cannot make the stub app for acme/pf: the value ${value} of its requires clause has the type ${type_text}, and R-SM2 has no stub for that type (R-IN8). Nothing was written."
	many = |n, text| "tln: error[usage]: cannot make the stub app for acme/pf: its requires clause has ${n} values (${text}), and R-SM2 gives a stub for one value only (R-IN8). Nothing was written."
	rows = [
		# a function of one argument (the new form, a doc comment with `{`, `:` and `,`, a return type with commas and `..`)
		(view("{\n\t\t## the args { and the result: a comment, with : and , in it\n\t\tmain! : List([Utf8(Str), UnixBytes(List(U8))]) => Try({}, [Exit(I32), ..])\n\t}", ""), stub_app("main!", "main! = |_| ${crashes}\n")),
		# the old form with two records, `()` is no argument
		(view("{} { main! : () => {} }", ""), stub_app("main!", "main! = || ${crashes}\n")),
		# 2 and 3 arguments, `->` and `=>`, a comma inside a tuple, a record and a call is no argument separator
		(view("{ f! : a, b => {} }", ""), stub_app("f!", "f! = |_, _| ${crashes}\n")),
		(view("{ g : Str, List(U8) -> U64 }", ""), stub_app("g", "g = |_, _| ${crashes}\n")),
		(view("{ h! : (a, b), { x : U8, y : U8 }, List(Str) => {} }", ""), stub_app("h!", "h! = |_, _, _| ${crashes}\n")),
		# an alias and a record of functions (the basic-webserver form)
		(
			view("{\n\t\t[Context : context] for program : {\n\t\t\tinit! : () => Try(context, Str),\n\t\t\trespond! : Request, context => Try(Response, Str),\n\t\t\tshutdown! : context => {},\n\t\t}\n\t}", ""),
			stub_app("Context, program", "Context : {}\n\nprogram = {\n\tinit!: || ${crashes},\n\trespond!: |_, _| ${crashes},\n\tshutdown!: |_| ${crashes},\n}\n"),
		),
		# 2 aliases and a nested record (the roc-ray form)
		(
			view("{ [Model : model, Msg : msg] for program : { init! : { config : a => b, run! : c => d }, update! : a, b, c => d, render! : a, b => c } }", ""),
			stub_app("Model, Msg, program", "Model : {}\n\nMsg : {}\n\nprogram = {\n\tinit!: {\n\t\tconfig: |_| ${crashes},\n\t\trun!: |_| ${crashes},\n\t},\n\tupdate!: |_, _, _| ${crashes},\n\trender!: |_, _| ${crashes},\n}\n"),
		),
		# one entry with a last comma is one entry
		(view("{} { main! : () => {}, }", ""), stub_app("main!", "main! = || ${crashes}\n")),
		# a record with no field, and a record of a record
		(view("{ z : {} }", ""), stub_app("z", "z = {}\n")),
		# a comment, a string and a nested key named `requires` before the clause never count; a comment inside the clause too
		(
			view("{\n\t\t# main! : Str,\n\t\tmain! : () => {} # a trailing { , : comment\n\t}", "\ttargets: { requires: { x : \"requires { q : Str }\" } }\n"),
			stub_app("main!", "main! = || ${crashes}\n"),
		),
		# R-SM2 "any other type": exit 2, nothing written, the message names the type (answer OP8)
		(view("{ name : Str }", ""), no_stub("name", "Str")),
		(view("{ main! : { go! : () => {}, port : U16 } }", ""), no_stub("main!", "U16")),
		(view("{ main : { run! : () => {}, level : List(U8) } }", ""), no_stub("main", "List(U8)")),
		(view("{ a : { x : Str, y : U8 } }", ""), no_stub("a", "Str")),
		# answer Q6: a clause with 2 or more entries is a form that R-SM2 does not give: exit 2, like a type with no stub (a comma and `name :`, or a comma and `[`, starts an entry)
		(view("{} { main! : () => {}, helper! : Str => {}, }", ""), many("2", "main! : () => {}, helper! : Str => {}")),
		(view("{ main! : () => {}, [A : a] for other : () => A }", ""), many("2", "main! : () => {}, [A : a] for other : () => A")),
		(view("{ a : () => {},\n\t\tb : () => {}, c : () => {} }", ""), many("3", "a : () => {}, b : () => {}, c : () => {}")),
		(view("{ [M : m] for p : { start : M, go! : () => {} } }", ""), no_stub("p", "M")),
		(view("{ mode : [Dev, Prod,\n\t\t\tTest] }", ""), no_stub("mode", "[Dev, Prod, Test]")),
		(view("{ n : Try(U8, [Bad]) }", ""), no_stub("n", "Try(U8, [Bad])")),
		# gap rows (slice 055, decisions of the code agent): no entry, an entry of no known form, and a string token that starts no entry: `has no requires clause`, exit 2
		(view("{}", ""), no_clause),
		(view("{ main! }", ""), no_clause),
		(view("{ [A : a] main! : () => {} }", ""), no_clause),
		(view("{ main! : () => {}, \"x, helper! : Str\" }", ""), stub_app("main!", "main! = || ${crashes}\n")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
