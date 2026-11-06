import Fail
import JsonDoc
import TalonFile
import ToolBin
import ToolsJson

## The use of prebuilt project tool binaries (slice 093, CLI 6.4: R-PT9 steps 1 and 2, R-PT15, R-PT21, R-PT22, R-PT23, R-B10, R-T22; Design Q237, Q238). Part A (pure, TESTING.md 2.2). The flow (the download, the sha256 of the file, the executable bit, the entry write, the build) is command code and not in this module.
## The texts and the layout of the manifest are proposals (TW24).
ToolBinUse :: [].{

	## What a `talon/x/` entry is: a `Prebuilt` entry with the sha256 of its binary, or a `Built` entry (a source build, with a build id).
	Kind : [Prebuilt({ sha256 : Str }), Built]

	## One entry that the listing of `talon/x/` gave: its dir, the hash of the app bundle (R-B9), its target, and its kind.
	Candidate : { dir : Str, bundle : Str, target : Str, kind : ToolBinUse.Kind }

	## What step 1 of R-PT9 takes: the dir of a `Prebuilt` entry, the dir of a source build entry, or no entry.
	Chosen : [Prebuilt(Str), Source(Str), NoEntry]

	## What step 2 of R-PT9 does when step 1 found no entry: `Download(sha256)` of the host target (the `bin` value), or `Build` (step 3).
	Use : [Download(Str), Build]

	## One manifest of a prebuilt entry (R-PT22, R-B9). The facts of the entry: the full name, the version, the app bundle hash, the target, the sha256 of the binary, the asset URL, and `last_run` (as the manifest of a source build).
	Prebuilt : { name : Str, version : Str, bundle : Str, target : Str, sha256 : Str, url : Str, last_run : Str }

	## R-PT22: the name of the dir of a prebuilt entry: the sha256 (`Crypto.SHA256`, as `XCache.digest`, R-X2) of the text `prebuilt\n<bundle>\n<target>\n<sha256>\n`, 64 lower case hex digits. It never equals the digest of a build id (that text has the full name first).
	digest : { bundle : Str, target : Str, sha256 : Str } -> Str
	digest = |facts| {
		text = "prebuilt\n${facts.bundle}\n${facts.target}\n${facts.sha256}\n"
		Crypto.SHA256.hash(text.to_utf8()).to_hex()
	}

	## R-PT9 step 1, R-PT22, R-PT25, R-B10, R-T22, Design Q237: the entry that a run takes. Only entries with the `bundle` and the `target` count. For `scope` `Project` (`run`, `x <key>`, `install`):
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `ToolBin.allowed` is true, `bin` has a value for `target`, and a `Prebuilt` entry has that sha256 | `Prebuilt(dir)`: it wins over a source build entry (Q237) |
	## | 2 | Not 1, and a `Built` entry is there | `Source(dir)`: also when R-PT25 does not allow binaries, also when a `Prebuilt` entry has another sha256 than `bin` (it is no match) |
	## | 3 | Else | `NoEntry` |
	##
	## For `scope` `Global` (`tln x owner/app@<sel>`, `tln tool install`): a `Prebuilt` entry is never used (R-B10, R-PT22): `Source(dir)` or `NoEntry`. Of two or more entries that match, the first of the list.
	pick : { scope : [Project, Global], bundle : Str, target : Str, bin : Try(ToolBin.Lock, [Unset]), machine : Try(Bool, [Unset]), entries : List(ToolBinUse.Candidate) } -> ToolBinUse.Chosen
	pick = |facts| {
		here = facts.entries.keep_if(|c| c.bundle == facts.bundle and c.target == facts.target)
		built = here.find_first(is_built)
		want = locked(facts.bin, facts.target)
		prebuilt = match want {
			Ok(sha256) if facts.scope == Project and ToolBin.allowed({ machine: facts.machine, bin: facts.bin }) => here.find_first(is_prebuilt(sha256))
			_ => Err(NotFound)
		}
		match (prebuilt, built) {
			(Ok(c), _) => Prebuilt(c.dir)
			(Err(_), Ok(c)) => Source(c.dir)
			(Err(_), Err(_)) => NoEntry
		}
	}

	## R-PT21, R-PT15, R-PT25, R-PT6, R-PT7: step 2 of R-PT9. `Download(sha256)` only when `ToolBin.allowed` is true, `bin` has a value for the host `target`, and the run is online. Else `Build`: also for a host target with no value (with `--frozen` too, R-PT7: no release list), and with `--offline` (R-PT15).
	use : { machine : Try(Bool, [Unset]), bin : Try(ToolBin.Lock, [Unset]), target : Str, offline : Bool } -> ToolBinUse.Use
	use = |facts| match locked(facts.bin, facts.target) {
		Ok(sha256) if !facts.offline and ToolBin.allowed({ machine: facts.machine, bin: facts.bin }) => Download(sha256)
		_ => Build
	}

	## R-PT21, R-DA4: the check of the download. Equal: `Ok`. Not equal: a failure of kind `Integrity` (exit 16) that names the target, both values and the way on (a proposal, TW24):
	## `the <target> binary of <key> <version> has the sha256 <got>, but talon.toml has <want>. Talon deleted the file. To build from source, remove <target> from bin of <key> in talon.toml.`
	verify : { key : Str, version : Str, target : Str, got : Str, want : Str } -> Try({}, Fail)
	verify = |facts| if facts.got == facts.want {
		Ok({})
	} else {
		Err(Fail.new(Integrity, "the ${facts.target} binary of ${facts.key} ${facts.version} has the sha256 ${facts.got}, but talon.toml has ${facts.want}. Talon deleted the file. To build from source, remove ${facts.target} from bin of ${facts.key} in talon.toml."))
	}

	## R-PT23: the line of a use, in place of the platform line of R-SE8 (a proposal: stderr, as the build line): `roc-cfw 1.0.3: prebuilt x64musl binary, sha256 <12 hex> (talon.toml)`.
	use_line : { key : Str, version : Str, target : Str, sha256 : Str } -> Str
	use_line = |facts| "${facts.key} ${facts.version}: prebuilt ${facts.target} binary, sha256 ${Str.from_utf8_lossy(facts.sha256.to_utf8().take_first(12))} (talon.toml)"

	## R-PT23: the warning of a download error (R-PT21: an HTTP error, R-DA7), then Talon builds from source: `warning: the x64musl binary of roc-cfw 1.0.3 could not be downloaded (<reason>). Talon builds it from source.`
	download_warning : { key : Str, version : Str, target : Str, reason : Str } -> Str
	download_warning = |facts| "warning: the ${facts.target} binary of ${facts.key} ${facts.version} could not be downloaded (${facts.reason}). Talon builds it from source."

	## R-PT22, R-B9, R-TF1: the text of the manifest: one line, `format` 1, and the fields in this order: `name`, `source` (`{"kind":"prebuilt","version","url"}`), `target`, `sha256`, `bundle`, `last_run`. There is no `build` field (no build id). The layout is a proposal (TW24).
	manifest_text : ToolBinUse.Prebuilt -> Str
	manifest_text = |entry| TalonFile.render({
		format: 1,
		fields: [
			("name", Text(entry.name)),
			("source", Obj([("kind", Text("prebuilt")), ("version", Text(entry.version)), ("url", Text(entry.url))])),
			("target", Text(entry.target)),
			("sha256", Text(entry.sha256)),
			("bundle", Text(entry.bundle)),
			("last_run", Text(entry.last_run)),
		],
	})

	## R-PT22, R-TF1: the entry back from the text. A manifest that is not a prebuilt manifest (the kind `release` or `git`, another format) is `NotPrebuilt`: the caller reads it as a source entry (`XCache.read`).
	read_manifest : Str -> Try(ToolBinUse.Prebuilt, [NotPrebuilt])
	read_manifest = |text| match TalonFile.open({ path: "manifest.json", text, newest: 1, can_recreate: Bool.True }) {
		Ok(Use(file)) => prebuilt_of(file.fields)
		_ => Err(NotPrebuilt)
	}
}

# The `bin` value of a target, if `bin` is a table with that target.
locked : Try(ToolBin.Lock, [Unset]), Str -> Try(Str, [NoValue])
locked = |bin, target| match bin {
	Ok(Hashes(have)) => match have.find_first(|h| h.target == target) {
		Ok(h) => Ok(h.sha256)
		Err(_) => Err(NoValue)
	}
	_ => Err(NoValue)
}

# The fields of a manifest as a prebuilt entry. Another source kind, or a missing field, is no prebuilt entry.
prebuilt_of : List((Str, JsonDoc)) -> Try(ToolBinUse.Prebuilt, [NotPrebuilt])
prebuilt_of = |fields| {
	source = ToolsJson.object_of(fields, "source")
	if ToolsJson.text_of(source, "kind") != Ok("prebuilt") {
		return Err(NotPrebuilt)
	}
	text = |obj, key| ToolsJson.text_of(obj, key).map_err(|Missing| NotPrebuilt)
	Ok({
		name: text(fields, "name")?,
		version: text(source, "version")?,
		bundle: text(fields, "bundle")?,
		target: text(fields, "target")?,
		sha256: text(fields, "sha256")?,
		url: text(source, "url")?,
		last_run: ToolsJson.text_of(fields, "last_run") ?? "",
	})
}

is_built : ToolBinUse.Candidate -> Bool
is_built = |c| match c.kind {
	Built => Bool.True
	Prebuilt(_) => Bool.False
}

is_prebuilt : Str -> (ToolBinUse.Candidate -> Bool)
is_prebuilt = |sha256| |c| match c.kind {
	Prebuilt(p) => p.sha256 == sha256
	Built => Bool.False
}
