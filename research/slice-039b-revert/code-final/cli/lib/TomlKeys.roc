import Probe
import Text
import toml.Toml
import toml.Value

## The reads that `Intent` (`talon.toml`) and `ConfigToml` (`config.toml`) share (slice 031b): the note of a read, the line of a key, the days of an age and the `probe` keys.
TomlKeys :: [].{

	## One note of a read: the 1-based line of the key and the text. The reads sort the notes by line.
	Note : { line : U64, message : Str }

	## The order of two line numbers.
	compare_lines : U64, U64 -> [Before, Same, After]
	compare_lines = |a, b| if a < b Before else if a > b After else Same

	## The line of a key. A key that is not in the file gives 1.
	key_line : Toml, List(Str) -> U64
	key_line = |doc, path| match Toml.line(doc, path) {
		Ok(n) => n
		Err(NoEntry) => 1
	}

	## `"<n>d"`: a whole number of days, in seconds (Q10).
	days_of : Str -> Try(U64, [NotDays])
	days_of = |text| match text.split_last("d") {
		Ok({ before, after }) if after.is_empty() and !before.is_empty() => U64.from_str(before).map_ok(|n| n * 86400).map_err(|_| NotDays)
		_ => Err(NotDays)
	}

	## Slice 031 (R-P5, R-PP7, R-TF4): the `[probe]` keys. In `talon.toml` they are the inline table `probe = { max = 100, max-toolchains = 10, slots = 12 }` of `[resolution]` (CLI 6.1: "same keys as [resolution] probe in talon.toml"). In `config.toml` they are the
	## table `[probe]`. The keys are `max`, `timeout`, `slots` and `max-toolchains`, whole numbers. A key that is not in the file is `Err(Unset)`. Failures have the kind `Input` (exit 19) and one message for the first bad key by line:
	##
	## | Case | Message (a proposal, TW24) |
	## | --- | --- |
	## | A key that is not a whole number (a string, a decimal number, a negative number, a boolean) | `<path>:<line>: <table>.<key>: must be a whole number` (`<table>` is `resolution.probe` in `talon.toml` and `probe` in `config.toml`) |
	## | `slots` or `timeout` is 0 (question Q5) | `<path>:<line>: <table>.<key>: must be 1 or more` |
	## | A key that is not one of the 4 | a warning: `<path>:<line>: unknown key <table>.<key>` (R-TF4) |
	##
	## `<line>` is the line of the key (the line of the inline table for a `talon.toml`).
	##
	## R-P5, R-PP7, R-TF4: the keys of one `probe` table. `path` is the table, `label` is its name in a message. `slots` and `timeout` need 1 or more (Q5 of slice 031).
	read_probe : Toml, List(Str), Str -> { value : Probe.Keys, issues : List(Note), warnings : List(Note) }
	read_probe = |doc, path, label| {
		line_of = |key| match Toml.line(doc, path.append(key)) {
			Ok(n) => n
			Err(NoEntry) => key_line(doc, path)
		}
		none = { max: Err(Unset), timeout: Err(Unset), slots: Err(Unset), max_toolchains: Err(Unset) }
		match Toml.get(doc, path) {
			Err(NotFound) => { value: none, issues: [], warnings: [] }
			Ok(Value.Table(table)) => {
				one = |key, least| match table.get(key) {
					Err(_) => { value: Err(Unset), issues: [] }
					Ok(found) => match probe_number(found, least) {
						Ok(n) => { value: Ok(n), issues: [] }
						Err(why) => { value: Err(Unset), issues: [{ line: line_of(key), message: "${label}.${key}: ${why}" }] }
					}
				}
				max = one("max", 0)
				timeout = one("timeout", 1)
				slots = one("slots", 1)
				toolchains = one("max-toolchains", 0)
				unknown = Text.sorted(table.keys().keep_if(|key| !probe_keys.contains(key)))
				{
					value: { max: max.value, timeout: timeout.value, slots: slots.value, max_toolchains: toolchains.value },
					issues: max.issues.concat(timeout.issues).concat(slots.issues).concat(toolchains.issues),
					warnings: unknown.map(|key| { line: line_of(key), message: "unknown key ${label}.${key}" }),
				}
			}
			Ok(_) => { value: none, issues: [{ line: key_line(doc, path), message: "${label}: must be a table" }], warnings: [] }
		}
	}

}

probe_keys : List(Str)
probe_keys = ["max", "timeout", "slots", "max-toolchains"]

# A whole number of `least` or more.
probe_number : Value, U64 -> Try(U64, Str)
probe_number = |v, least| match v {
	Value.Integer(n) if n >= 0 => if n.to_u64_wrap() >= least Ok(n.to_u64_wrap()) else Err("must be ${least.to_str()} or more")
	_ => Err("must be a whole number")
}
