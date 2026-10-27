import Db
import Facts
import Probe
import Text
import Units

## The build skip (Resolution 4 "Build skip": R-BS1, R-BS2; Design 2.1 R-ID6; R-P4; Design 7 R-PH9). Part A (pure, slice 032). Ladder step 3 is `roc build` of the app. Talon skips it when `compat.db` has a build pass for the same
## build id: the key (platform hash, compiler, target) and the used-closure digest, and no recorded fail, hang or crash of that digest. `BuildFlow` is the command code (the calls are in the table of `BuildFlow`). The facts of the ladder are in `Facts`, the store is `Db`.
##
## ```mermaid
## flowchart TD
##     A["step 2 passed (no new errors)"] --> B["BuildSkip.pf_hash: the platform hash, or no key"]
##     B -->|"none"| R["step 3 runs, nothing is recorded"]
##     B --> C["platform!, BuildSkip.key: (platform hash, compiler, target)"]
##     C -->|"unknown system"| R
##     C --> D["the scan of the used modules (once), BuildSkip.digest"]
##     D --> E["db_query: the row of the key"]
##     E --> F{"BuildSkip.decide"}
##     F -->|"Skip"| S["build: skipped (recorded pass)"]
##     F -->|"Build"| G["step 3 runs"]
##     G --> H["db_write: BuildSkip.row of the result: pass, fail, hang or crash (Replace)"]
## ```
BuildSkip :: [].{

	## The system of the machine, as `Fx.platform!` gives it.
	System : { os : [Linux, Macos, Windows, Other(Str)], arch : [X64, Arm64, Other(Str)] }

	## One module that the app uses, as `Uses.level` gives it: the hash of the package and the path of the module in it.
	Used : { hash : Str, path : Str }

	## R-ID6 (slice 032): the build id of a build that can be recorded: the key of the fact (R-P4: platform hash, compiler, target) and the used-closure digest.
	Id : { key : Db.Key, digest : Str }

	## R-BS2: the used-closure digest. The hashes of `used` (a package with a used module), sorted by byte order with no repeat, each followed by a line end (`\n`). The digest is the SHA-256 of the UTF-8 bytes of that text, as 64 lowercase hex digits.
	## So the digest does not depend on the order of the modules, on the module paths, or on how many modules of a package are used. A package that no used module belongs to is not in it. The empty list gives the SHA-256 of no bytes.
	## A patch or an override changes the hash of the entry that it replaces, so the list has the new hash (patches: slice 042).
	digest : List(Used) -> Str
	digest = |used| {
		text = Text.sorted_unique(used.map(|one| one.hash)).fold("", |acc, hash| "${acc}${hash}\n")
		Crypto.SHA256.hash(text.to_utf8()).to_hex()
	}

	## The target of the key (R-P4, R-LD5: the host target, `roc build` runs with no `--target`). The names are the Roc targets that Talon ships (R-HF10):
	##
	## | os | arch | target |
	## | --- | --- | --- |
	## | `Linux` | `X64` | `x64musl` |
	## | `Linux` | `Arm64` | `arm64musl` |
	## | `Macos` | `X64` | `x64mac` |
	## | `Macos` | `Arm64` | `arm64mac` |
	## | `Windows` | `X64` | `x64win` |
	## | any other | | `Err(Unknown)`: no key, so no skip and no record |
	target : System -> Try(Str, [Unknown])
	target = |system| match (system.os, system.arch) {
		(Linux, X64) => Ok("x64musl")
		(Linux, Arm64) => Ok("arm64musl")
		(Macos, X64) => Ok("x64mac")
		(Macos, Arm64) => Ok("arm64mac")
		(Windows, X64) => Ok("x64win")
		_ => Err(Unknown)
	}

	## The hash of the platform of the closure (R-ID6): the first node with `is_platform`. A closure with no such node (the platform is a path entry or a foreign URL: it has no hash, `Units.nodes`) is `Err(NoPlatform)`: the build has no key.
	pf_hash : List(Units.Node) -> Try(Str, [NoPlatform])
	pf_hash = |nodes| match nodes.find_first(|node| node.is_platform) {
		Ok(node) => Ok(node.hash)
		Err(_) => Err(NoPlatform)
	}

	## R-P4, R-ID6: the key of the build fact: `{ hash: platform, nightly, target: BuildSkip.target(system) }`. `nightly` is the id of the compiler that runs the ladder (`Start.Started.id`, R-NS12).
	key : { pf : Str, nightly : Str, system : System } -> Try(Db.Key, [Unknown])
	key = |facts| match BuildSkip.target(facts.system) {
		Ok(host) => Ok({ hash: facts.pf, nightly: facts.nightly, target: host })
		Err(Unknown) => Err(Unknown)
	}

	## R-BS1: skip step 3 or run it. `facts` are the rows that a query for `key` gave (rows of other keys are ignored). The rows of the key with the same `closure` as `digest` decide (a key has one row for each digest, slice 032).
	## `Skip` only when one of them has the outcome `Pass` and a `closure` that is not empty, and none of them has the outcome `Fail`, `Hang` or `Crash` (R-BS2: a recorded fail never allows a skip, also when a pass is recorded for the same digest).
	## A row of another digest never decides: a pass with another digest does not skip, and a fail with another digest does not block. A `Pass` row with no digest never skips. Condition 3 (step 2 passed with no new error) is not here: the command asks only after it.
	decide : { facts : List(Db.Fact), key : Db.Key, digest : Str } -> [Skip, Build]
	decide = |facts| {
		mine = facts.facts.keep_if(|row| row.hash == facts.key.hash and row.nightly == facts.key.nightly and row.target == facts.key.target and row.closure == facts.digest)
		blocked = mine.any(|row| row.outcome != Pass)
		passed = mine.any(|row| row.outcome == Pass)
		if passed and !blocked and !facts.digest.is_empty() Skip else Build
	}

	## R-P4, R-P3, R-BS2: the fact of a build, or no fact. The row is `Facts.of_probe` for a build: the key (the target is the host), the outcome of `class` (`Pass`, `Fail`, `Hang`, `Crash`), the digest in `closure` for every outcome, and for a fail the modules of the platform hash that the `errors` name (R-P4).
	## `NoFact` (a download error, a signal from outside) is `Err(NoFact)`. The command writes the row with `Facts.save!` and `existing: Replace`: the primary key is the key and the digest, so a build of another digest is a new row, and a later result for the same digest replaces the old one.
	row : { key : Db.Key, digest : Str, class : Probe.Class, errors : List(Probe.Err) } -> Try(Db.Fact, [NoFact])
	row = |facts| Facts.of_probe({
		hash: facts.key.hash,
		nightly: facts.key.nightly,
		host: facts.key.target,
		command: Build({ output: "" }),
		class: facts.class,
		errors: facts.errors,
		closure: facts.digest,
	})

	## R-BS1 (slice 032): the `build` state of the outcome of a command. `apps` are the members that have a build, `skipped` are the members that skipped it. No app: `NotRun`. Each app skipped: `Skipped`. Else `Passed`.
	state : { apps : U64, skipped : U64 } -> [Passed, Skipped, NotRun]
	state = |counts| if counts.apps == 0 NotRun else if counts.skipped >= counts.apps Skipped else Passed

	## R-BS2: the line of the summary when step 3 is skipped (a proposal for the text, TW24, but the design gives the words).
	skipped_line : Str
	skipped_line = "build: skipped (recorded pass)"
}
