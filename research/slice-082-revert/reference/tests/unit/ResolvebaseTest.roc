import lib.Intent
import lib.Mode
import lib.Net
import lib.Project
import lib.ResolveBase
import lib.Roots

ResolvebaseTest :: [].{}

# The input of `ResolveBase.settings_of`: a request with the fields that the settings do not read set to empty values, and the loaded files from the text of `talon.toml` and of `config.toml` (`Err(Unset)` text: no file).
request = |cmd, dir| {
	project = match Project.find({ file: Err(Unset), walk: [{ dir, names: ["main.roc"], toml: Err(None) }], members: [] }) {
		Ok(p) => p
		Err(_) => crash "no project"
	}
	roots = match Roots.from_env([("HOME", "${dir}/home")]) {
		Ok(r) => r
		Err(_) => crash "no roots"
	}
	{
		command: cmd,
		names: [],
		frozen: Bool.False,
		no_check: Bool.False,
		project,
		roots,
		net: Net.from_env([]),
		now: 1792065600,
		offline: Bool.False,
		strategy: Err(Unset),
		nightly: Err(Unset),
		compiler: Err(NoCompiler),
		selected: "",
		none: Stop,
		toolchain: Err(Unset),
		snapshot: Err(Unset),
		dry_run: Bool.False,
		add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
		prompt: { mode: Mode.from_env({ env: Dict.empty(), json: Bool.False }), yes: Bool.False, quiet: Bool.False, rename_keys: Err(NoFlag), allow_moves: Err(NoFlag) },
		downloads: { auto: Ask, allow: Err(NoFlag), probe: Err(NoFlag), env: [] },
		probe: { no_probe: Bool.False, slots: Err(Unset) },
	}
}

loaded = |toml_text, config_text| {
	intent = match Intent.read({ path: "/p/talon.toml", text: toml_text, role: Standalone }) {
		Ok(done) => done.intent
		Err(_) => crash "bad talon.toml of the test"
	}
	config = match Intent.read_config({ path: "/h/config.toml", text: config_text }) {
		Ok(done) => done.config
		Err(_) => crash "bad config.toml of the test"
	}
	{ members: [], headers: [], tomls: [], intent, config, version_file: Err(None), selected: { id: Err(NoCompiler), from: Path } }
}

# R-C14 R-C7 R-C11 R-LY4 (slice 082): `ResolveBase.settings_of` gives the list of the run. It is the union of `[resolution] min-release-age-exclude` of `talon.toml` and the list of `config.toml`, the project first, each text once (`Age.join`).
# `min-release-age` is different: the value of `talon.toml` replaces the value of `config.toml`, and the list stays the union. `min-release-age = "0d"` and a list: `min_age` 0 and the list (the list has no effect, and no warning).
# No list in both files: `[]`. The result is the same for each command of the request.
expect {
	view = |cmd, toml_text, config_text| {
		s = ResolveBase.settings_of(request(cmd, "/p"), loaded(toml_text, config_text))
		(s.min_age, s.exclude)
	}
	day = 86400
	rows = [
		("no file has the key: the default age, an empty list", view(Install, "", ""), (2 * day, [])),
		("only config.toml: its list", view(Install, "", "min-release-age-exclude = [\"acme/*\"]\n"), (2 * day, ["acme/*"])),
		("only talon.toml: its list", view(Install, "[resolution]\nmin-release-age-exclude = [\"acme/lib\"]\n", ""), (2 * day, ["acme/lib"])),
		("the union: the project first, then the user", view(Install, "[resolution]\nmin-release-age-exclude = [\"acme/lib\", \"b/*\"]\n", "min-release-age-exclude = [\"c/d\", \"x/*\"]\n"), (2 * day, ["acme/lib", "b/*", "c/d", "x/*"])),
		("a text in both lists counts once, in the place of the project", view(Install, "[resolution]\nmin-release-age-exclude = [\"a/b\", \"c/d\"]\n", "min-release-age-exclude = [\"c/d\", \"e/*\"]\n"), (2 * day, ["a/b", "c/d", "e/*"])),
		("the same text twice in one list counts once", view(Install, "", "min-release-age-exclude = [\"a/b\", \"a/b\"]\n"), (2 * day, ["a/b"])),
		("an empty list in talon.toml removes nothing", view(Install, "[resolution]\nmin-release-age-exclude = []\n", "min-release-age-exclude = [\"acme/*\"]\n"), (2 * day, ["acme/*"])),
		("min-release-age of talon.toml replaces config.toml, the list is still the union", view(Install, "[resolution]\nmin-release-age = \"5d\"\nmin-release-age-exclude = [\"p/q\"]\n", "min-release-age = \"1d\"\nmin-release-age-exclude = [\"acme/*\"]\n"), (5 * day, ["p/q", "acme/*"])),
		("min-release-age 5d in talon.toml and a list only in config.toml: the list applies", view(Install, "[resolution]\nmin-release-age = \"5d\"\n", "min-release-age-exclude = [\"acme/*\"]\n"), (5 * day, ["acme/*"])),
		("min-release-age 0d and a list: age 0 and the list", view(Install, "[resolution]\nmin-release-age = \"0d\"\n", "min-release-age-exclude = [\"acme/*\"]\n"), (0, ["acme/*"])),
		("the same for update", view(Update, "[resolution]\nmin-release-age-exclude = [\"a/b\"]\n", "min-release-age-exclude = [\"c/d\"]\n"), (2 * day, ["a/b", "c/d"])),
		("the same for upgrade", view(Upgrade, "[resolution]\nmin-release-age-exclude = [\"a/b\"]\n", "min-release-age-exclude = [\"c/d\"]\n"), (2 * day, ["a/b", "c/d"])),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
