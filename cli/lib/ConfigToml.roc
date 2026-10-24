import Fail
import Pin
import Probe
import TomlKeys
import toml.Toml
import toml.Value

## The `config.toml` of the user (CLI 6.1, R-LY4, R-TF4). Split from `Intent` (slice 031b): the settings, and the read that checks each key.
ConfigToml :: [].{

	## The settings that `config.toml` has (CLI 6.1, R-LY4): `nightly` (R-NS10), `min-release-age` in seconds (R-C7), from slice 022, `default-roc` (R-SO6: rank 6, a full compiler id, `Pin.is_id`), and from slice 028, `gc-age` in seconds (R-GC9: `"<n>d"`, a whole number of days as `min-release-age`; a value of the wrong form is `<path>:<line>: gc-age: must be a number of days, for example "30d"`, exit 19).
	## A `default-roc` that is not a string, or not a full id (a prefix), is a failure of kind `Input` (exit 19, R-TF4, R-SC12): `<path>:<line>: default-roc: must be a full compiler id`. The other keys are known and not read.
	Config : { nightly : Try(Bool, [Unset]), min_release_age : Try(U64, [Unset]), default_roc : Try(Str, [Unset]), gc_age : Try(U64, [Unset]), probe : Probe.Keys }

	## Reads the text of a `config.toml` (R-TF4). A key with a value of the wrong form is a failure of kind `Input` (exit 19): `<path>:<line>: <key>: <why>`.
	## An unknown top-level key is a warning: `<path>:<line>: unknown key <key>`.
	read : { path : Str, text : Str } -> Try({ config : Config, warnings : List(Str) }, Fail)
	read = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(doc) => {
			nightly = config_field(
				doc,
				"nightly",
				|v| match v {
					Value.Boolean(b) => Ok(b)
					_ => Err("must be true or false")
				},
			)
			age = config_field(
				doc,
				"min-release-age",
				|v| match v {
					Value.String(text) => TomlKeys.days_of(text).map_err(|NotDays| "must be a number of days, for example \"2d\"")
					_ => Err("must be a number of days, for example \"2d\"")
				},
			)
			default_roc = config_field(
				doc,
				"default-roc",
				|v| match v {
					Value.String(text) if is_default_id(text) => Ok(text)
					_ => Err("must be a full compiler id")
				},
			)
			gc_age = config_field(
				doc,
				"gc-age",
				|v| match v {
					Value.String(text) => TomlKeys.days_of(text).map_err(|NotDays| "must be a number of days, for example \"30d\"")
					_ => Err("must be a number of days, for example \"30d\"")
				},
			)
			probe = TomlKeys.read_probe(doc, ["probe"], "probe")
			issues = nightly.issues.concat(age.issues).concat(default_roc.issues).concat(gc_age.issues).concat(probe.issues)
			match issues.sort_with(|a, b| TomlKeys.compare_lines(a.line, b.line)) {
				[first, ..] => Err(Fail.new(Input, "${facts.path}:${first.line.to_str()}: ${first.message}"))
				[] => {
					unknown = Toml.table(doc).to_list().keep_if(|(key, _)| !config_keys.contains(key)).map(|(key, _)| { line: TomlKeys.key_line(doc, [key]), message: "unknown key ${key}" })
					warnings = unknown.concat(probe.warnings).sort_with(|a, b| TomlKeys.compare_lines(a.line, b.line)).map(|w| "${facts.path}:${w.line.to_str()}: ${w.message}")
					Ok({ config: { nightly: nightly.value, min_release_age: age.value, default_roc: default_roc.value, gc_age: gc_age.value, probe: probe.value }, warnings })
				}
			}
		}
	}
}

# R-SO6, D6: a nightly, a release, or `git-`, `link-`, `copy-` with a name.
is_default_id : Str -> Bool
is_default_id = |text| Pin.is_id(text) or ["git-", "link-", "copy-"].any(|prefix| text.starts_with(prefix) and !text.drop_prefix(prefix).is_empty())

# The keys of `config.toml` (CLI 6.1). `probe` is a table.
config_keys : List(Str)
config_keys = ["default-roc", "registry", "nightly", "min-release-age", "gc-age", "share", "probe"]

# A top-level key of `config.toml`, or the reason that it is wrong.
config_field : Toml, Str, (Value -> Try(a, Str)) -> { value : Try(a, [Unset]), issues : List(TomlKeys.Note) }
config_field = |doc, key, parse| match Toml.get(doc, [key]) {
	Err(NotFound) => { value: Err(Unset), issues: [] }
	Ok(found) => match parse(found) {
		Ok(parsed) => { value: Ok(parsed), issues: [] }
		Err(why) => { value: Err(Unset), issues: [{ line: TomlKeys.key_line(doc, [key]), message: "${key}: ${why}" }] }
	}
}
