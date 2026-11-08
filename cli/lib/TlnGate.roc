import Fail
import Help
import Ranges
import TomlKeys
import toml.Toml
import toml.Value

## R-TF10 (Design Q607, Q610): the gate of `[toolchain] tln = "<range>"`. A person writes the key, Talon never does.
## Only major.minor.patch of the version counts: `0.4.0-rc.1` is `0.4.0`.
TlnGate :: [].{

	## `Ok` when the range admits the version, `Outside` when it does not, `BadRange` when the range does not parse.
	check : { range : Str, version : Str } -> Try({}, [BadRange, Outside])
	check = |facts| {
		Ranges.check(facts.range)?
		core = facts.version.split_first("+").map_ok(|s| s.before).ok_or(facts.version).split_first("-").map_ok(|s| s.before).ok_or(facts.version)
		if Ranges.admits({ ranges: [facts.range], version: core }) Ok({}) else Err(Outside)
	}

	## The gate for a parsed `talon.toml`: no key is `Ok`. The failures are kind `Input` (exit 19) and name the line of the key.
	gate : { path : Str, doc : Toml } -> Try({}, Fail)
	gate = |facts| match Toml.get(facts.doc, ["toolchain", "tln"]) {
		Err(_) => Ok({})
		Ok(found) => {
			at = "${facts.path}:${TomlKeys.key_line(facts.doc, ["toolchain", "tln"]).to_str()}: "
			match found {
				Value.String(range) => match TlnGate.check({ range, version: Help.version }) {
					Ok({}) => Ok({})
					Err(BadRange) => Err(Fail.with_hint(Fail.new(Input, "${at}toolchain.tln: '${range}' is not a version range")))
					Err(Outside) => Err(Fail.new(Input, "${at}this project needs tln ${range}, this is tln ${Help.version}. Run: tln tool update talon"))
				}
				_ => Err(Fail.with_hint(Fail.new(Input, "${at}toolchain.tln: must be a string")))
			}
		}
	}
}
