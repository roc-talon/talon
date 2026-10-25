app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Fail
import lib.Ident
import lib.Index
import lib.Init
import lib.InitText

main! = |_args| Ok({})

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

# R-IN1 R-IN4 R-IN5 R-IN6 (the texts of the files, a proposal, TW24): the app has the platform entry and no `roc:` entry (the resolve writes the pin), and no `talon.toml` text exists. The default platform has a hello world, another platform has the smallest `main!`. The CI file has the version of `tln` twice and the 4 steps of R-IN6.
expect {
	url = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/h.tar.zst"
	hello = InitText.app_file({ name: "roc-lang/basic-cli", url })
	other = InitText.app_file({ name: "acme/pfx", url: "https://github.com/acme/pfx/releases/download/0.2.0/h.tar.zst" })
	ci = InitText.ci_file("1.2.3")
	checks = [
		(InitText.default_platform, "roc-lang/basic-cli"),
		(hello, "app [main!] {\n\tpf: platform \"${url}\",\n}\n\nimport pf.Stdout\n\nmain! = |_args| {\n\tStdout.line!(\"Hello, World!\")?\n\tOk({})\n}\n"),
		(other, "app [main!] {\n\tpf: platform \"https://github.com/acme/pfx/releases/download/0.2.0/h.tar.zst\",\n}\n\nmain! = |_args| Ok({})\n"),
		(InitText.package_file, "package [] {\n}\n"),
		(if hello.contains("roc:") or other.contains("roc:") or InitText.package_file.contains("roc:") "a roc entry" else "no roc entry", "no roc entry"),
		(if other.contains("Stdout") "a Stdout import" else "no Stdout import", "no Stdout import"),
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
