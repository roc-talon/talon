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
	app_file = |_facts| crash "todo: slice 041"

	## The text of `main.roc` of a package (R-IN1): a header that exposes no module and has no entry. The resolve of the slice writes the pin.
	package_file : Str
	package_file = "todo: slice 041"

	## The text of `.github/workflows/ci.yml` (R-IN6). `version` is the version of the `tln` that ran `init` (`Help.version`). The steps are the design's: install Talon at that version (`install.sh --yes --version <version>`
	## from `https://github.com/roc-talon/talon/releases`), `tln install --frozen`, `roc check`, `roc test`. The job sets `TALON_AUTO_INSTALL=yes` and runs on `ubuntu-latest`. The step `tln audit` is P3.
	ci_file : Str -> Str
	ci_file = |_version| crash "todo: slice 041"
}
