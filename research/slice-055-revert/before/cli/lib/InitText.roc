## The text of the files that `tln init` writes (slice 041, CLI 5). Part A (pure). The design gives the names and the steps (R-IN1, R-IN6) and no text, so the texts are a proposal (TW24).
InitText :: [].{

	## The platform of the default template (R-IN1).
	default_platform : Str
	default_platform = "roc-lang/basic-cli"

	## The text of `main.roc` of an app (R-IN1). `name` is the full name of the platform (`owner/repo`), `url` is its release URL (R-H3). The header has the platform entry and no `roc:` entry: the resolve of the slice writes the pin (R-IN4).
	##
	## | Platform | Body |
	## | --- | --- |
	## | `InitText.default_platform` | `import pf.Stdout` and a `main!` that prints `Hello, World!` |
	## | another | a `main!` that returns `Ok({})` (the design does not say what another platform exposes) |
	app_file : { name : Str, url : Str } -> Str
	app_file = |facts| {
		header = "app [main!] {\n\tpf: platform \"${facts.url}\",\n}\n\n"
		if facts.name == InitText.default_platform {
			"${header}import pf.Stdout\n\nmain! = |_args| {\n\tStdout.line!(\"Hello, World!\")?\n\tOk({})\n}\n"
		} else {
			"${header}main! = |_args| Ok({})\n"
		}
	}

	## The text of `main.roc` of a package (R-IN1): a header that exposes no module and has no entry. The resolve of the slice writes the pin.
	package_file : Str
	package_file = "package [] {\n}\n"

	## The text of `.github/workflows/ci.yml` (R-IN6). `version` is the version of the `tln` that ran `init` (`Help.version`). The steps are the design's: install Talon at that version (`install.sh --yes --version <version>`
	## from `https://github.com/roc-talon/talon/releases`), `tln install --frozen`, `roc check`, `roc test`. The job sets `TALON_AUTO_INSTALL=yes` and runs on `ubuntu-latest`. The step `tln audit` is P3.
	ci_file : Str -> Str
	ci_file = |version| {
		install = "curl -fsSL https://github.com/roc-talon/talon/releases/download/v${version}/install.sh | sh -s -- --yes --version ${version}"
		lines = [
			"name: CI",
			"",
			"on:",
			"  push:",
			"  pull_request:",
			"",
			"jobs:",
			"  check:",
			"    runs-on: ubuntu-latest",
			"    env:",
			"      TALON_AUTO_INSTALL: \"yes\"",
			"    steps:",
			"      - uses: actions/checkout@v4",
			"      - name: Install Talon",
			"        run: ${install}",
			"      - name: Install packages",
			"        run: tln install --frozen",
			"      - name: Check",
			"        run: roc check",
			"      - name: Test",
			"        run: roc test",
		]
		"${Str.join_with(lines, "\n")}\n"
	}
}
