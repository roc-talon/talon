import Answer
import Clock
import Common
import Consent
import Db
import Facts
import Fail
import Fx
import Item
import Mode
import Net
import Nightlies
import Pin
import Prompt
import RocInstall
import Roots
import Start
import Text
import Toolchain

## R-SO14 (slice 072b, Resolution 13): no rank selects a compiler (no installed compiler, no `roc` on `PATH`, no `default-roc`, no pin, no range, no `.roc-version`). Talon does not stop with exit code 18. It picks one compiler,
## downloads it under the consent rules R-DL1 to R-DL6, and sets it as `default-roc` when none is set (R-SO15). Exit code 18 stays in P0 only (R-PH6, R-EC18).
##
## Slice 072b wires only the fetch (`Fetch.program_of!`, R-FE4, R-LF1) of the flows of `InstallFlow.install_with!` (`install`, `add`, `update`, `upgrade`, `install --frozen`). Every other flow passes `Stop` (the old exit code 18)
## until slice 072c. The pure decisions are `pick`, `keys`, `gate` and `prompt`. The command code is `offer!` and `ensure!`.
NoRank :: [].{

	## Where the command runs (CLI 1, R-PD1 to R-PD8). `Project` has the hashes of the release entries of the headers of the project (the decision of the case: R-SO14 (1)). `Outside` is no project (R-SO14 (2)).
	Scope : [Outside, Project(List(Str))]

	## What the download needs: the scope and the facts of the consent rules (`Start.Downloads`: `auto` is `TALON_AUTO_INSTALL`, `allow` is `--allow-downloads`, `yes`, `mode`, `quiet`, `offline`, `env`).
	Run : { scope : NoRank.Scope, downloads : Start.Downloads }

	## `Stop`: this flow does not apply R-SO14 yet (slice 072c): the failure `Compiler.failure(NoCompiler)`, exit code 18. `Download`: R-SO14.
	Fallback : [Stop, Download(NoRank.Run)]

	## The result of `ensure!`: the compiler that Talon uses, and the installed list with it (the list that the caller read, and the id of a download).
	Got : { id : Str, installed : List(Str) }

	## R-SO14, R-EF1, R-EF3, R-RU1 (the pick): the compiler to download. `auto` are the ids of the channel, oldest first (`Toolchain.domain`, the `auto` list: the switch and `min-release-age` are applied). `facts` are the rows of
	## `compat.db` for the keys of `keys` (rows of other keys are ignored). The first row that holds wins:
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `auto` is empty | `Err(Empty)` |
	## | 2 | `scope` is `Outside` | the last id of `auto`: the latest in the channel |
	## | 3 | `scope` is `Project(hashes)`. A hash is known when `facts` has a row of that hash with the target `any` (a check row, any outcome, any compiler). A compiler suits when, for each known hash, `facts` has a row with the target `any`, the outcome `Pass`, and a compiler that is `Pin.same_id` with it (R-EF1 rank 1; a build row is no evidence, as in `Evidence.of_pair`). The newest compiler of `auto` that suits | that id |
	## | 4 | `scope` is `Project`, and no compiler suits (also: a known hash has a fail on each compiler) | the last id of `auto` |
	##
	## A project with no known hash (no fact at all, or no release entry): every compiler suits, so the result is row 2. No other source counts in P1 (R-EF1 rank 2 is the registry, P2). The reading of "a recorded pass for each hash of the header entries that has a fact" is question Q1 of slice 072b.
	pick : { auto : List(Str), scope : NoRank.Scope, facts : List(Db.Fact) } -> Try(Str, [Empty])
	pick = |run| match run.auto.last() {
		Err(_) => Err(Empty)
		Ok(latest) => match run.scope {
			Outside => Ok(latest)
			Project(hashes) => {
				checks = run.facts.keep_if(|f| f.target == "any")
				known = hashes.keep_if(|hash| checks.any(|f| f.hash == hash))
				passes = |hash, id| checks.any(|f| f.hash == hash and f.outcome == Pass and Pin.same_id(f.nightly, id))
				suits = run.auto.keep_if(|id| known.all(|hash| passes(hash, id)))
				Ok(suits.last() ?? latest)
			}
		}
	}

	## R-EF1, R-CC8: the keys of the one `db_query!` of the pick. One key for each hash and each id of `auto`: `{ hash, nightly: <id>, target: "any" }`. The hashes are sorted and have no repeat (`Text.sorted_unique`); for each hash the ids are in the order of `auto`.
	## No hash gives no key, and then no call (`Facts.load!`).
	keys : { hashes : List(Str), auto : List(Str) } -> List(Db.Key)
	keys = |run| Text.sorted_unique(run.hashes).join_map(|hash| run.auto.map(|id| { hash, nightly: id, target: "any" }))

	## R-SO14, R-DL5, R-DL10 (the refusals that need no list): the first row that holds wins. Both are kind `Consent` (exit code 13), and no request is made (no list, no `tty!`):
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `offline` (`--offline`) | `Stop`: `no compiler is selected, and --offline stops the download. Run: tln roc install @latest when you are online, then tln roc default <id>.` An answer (`--yes`, `--allow-downloads`, `TALON_AUTO_INSTALL=yes`) does not help: no download can start |
	## | 2 | `Consent.auto_refuses` (`TALON_AUTO_INSTALL=no`, no `--yes`, no `--allow-downloads`) | `Stop`: `no compiler is selected. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install @latest, then tln roc default <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.` |
	## | 3 | any other | `Go` |
	##
	## The texts are proposals (TW24).
	gate : { auto : [Ask, Yes, No], yes : Bool, flag : Try(Answer, [NoFlag]), offline : Bool } -> [Go, Stop(Fail)]
	gate = |run| if run.offline {
		Stop(Fail.new(Consent, "no compiler is selected, and --offline stops the download. Run: tln roc install @latest when you are online, then tln roc default <id>."))
	} else if Consent.auto_refuses({ auto: run.auto, yes: run.yes, flag: run.flag }) {
		Stop(Fail.new(Consent, "no compiler is selected. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install @latest, then tln roc default <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes."))
	} else {
		Go
	}

	## R-NI5, R-DL1, R-DL3, R-SO14 (the prompt, a proposal, TW24): kind `Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"])` (`Prompt.decide` adds `--yes`), yes/no, the interactive default is No (R-DL3: the command does not name the
	## download; the table of R-NI5 has `No`). It names the compiler and says that it becomes the default.
	##
	## | Field | Text |
	## | --- | --- |
	## | `id` | `no-rank-download` |
	## | `question` | `No compiler is selected. Download <id>, <size>? It becomes the default compiler.` (`<size>` is `Toolchain.size_text`) |
	## | `subject` | `the download of <id>` |
	## | `answer_line` | `Yes`: `downloading <id> (<size>), the default compiler`. `No`: `no download of <id>` |
	prompt : { id : Str, size : U64 } -> Prompt
	prompt = |facts| {
		name = facts.id
		size = Toolchain.size_text(facts.size)
		yes_line = "downloading ${name} (${size}), the default compiler"
		no_line = "no download of ${name}"
		Prompt.{
			id: "no-rank-download",
			kind: Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"]),
			shape: YesNo,
			default: No,
			question: "No compiler is selected. Download ${name}, ${size}? It becomes the default compiler.",
			subject: "the download of ${name}",
			answer_line: |answer| if answer == Yes yes_line else no_line,
		}
	}

	## The steps 2 to 6 of `RocInstall.offer!`, with the pick of `pick` in place of `Nightlies.pick`. The calls, in order: `clock!`, `platform!`, `RocInstall.read_config!` (one `read_files!` of `config.toml`), one `list_dirs!` of
	## `<cache>/toolchains`, then the calls of `Nightlies.list!` (the cache of the list, `compat.db`: slice 030b), then for `Project` with a key: `Facts.load!` (one `db_query!` with `facts=<n>`, `n` is the number of keys). The failures:
	##
	## | Case | Failure |
	## | --- | --- |
	## | The host has no asset (`Toolchain.host`) | `Toolchain.host`: kind `Environment` (exit 18) |
	## | `Nightlies.list!` fails | its failure (`Network`, exit 15) |
	## | The list is `Missing` (`--offline` and no cached page) | `Toolchain.offline_no_list` (exit 15) |
	## | `pick` gives `Err(Empty)` (no release is allowed) | `Toolchain.pick_failed` with `Empty` (exit 10, `NoTuple`: with the switch off the text names the switch and its source, R-NS2) |
	## | The asset has no digest | `Toolchain.require_digest` (exit 16) |
	##
	## The picked id is a dir of `toolchains/`: `Present`. Else `Download` with the size of the asset. `RocInstall.offer!` has the shared steps and private helpers (`toolchain_entries!`, `has_dir`, `asset_of`, `published_of`, `env_var`). `RocInstall.roc` has about 420 lines: the code agent makes the helpers public or moves them into a module that both use (each module at most 490 lines).
	offer! : Fx, { env : List((Str, Str)), offline : Bool, scope : NoRank.Scope } => Try(RocInstall.Offer, Fail)
	offer! = |fx, run| {
		roots = Roots.from_env(run.env)?
		real = fx.clock!()
		now = match Clock.now({ talon_now: RocInstall.env_var(run.env, "TALON_NOW"), real }) {
			Ok(t) => t
			Err(BadTime(text)) => return Err(Fail.new(Usage, "TALON_NOW is not a UTC time: ${text}"))
		}
		system = Toolchain.host(fx.platform!())?
		config = RocInstall.read_config!(fx, roots)?
		switch = Pin.switch({ env: Common.nightly_of(run.env), toml: Err(Unset), config: config.nightly })
		entries = RocInstall.toolchain_entries!(fx, Text.join(roots.cache, "toolchains"))
		found = Nightlies.list!(fx, { net: Net.from_env(run.env), roots, now: real, offline: run.offline, host: system })?
		if found.source == Missing return Err(Toolchain.offline_no_list({}))
		auto = Toolchain.domain({ releases: found.releases, now, min_age: config.min_release_age ?? 172800, nightly: switch.nightly }).auto
		facts = match run.scope {
			Outside => []
			Project(hashes) => Facts.load!(fx, { roots, keys: NoRank.keys({ hashes, auto }) })?
		}
		id = match NoRank.pick({ auto, scope: run.scope, facts }) {
			Ok(picked) => picked
			Err(Empty) => return Err(Toolchain.pick_failed({ error: Empty, releases: found.releases, host: system, switch }))
		}
		if RocInstall.has_dir(entries, id) return Ok(Present({ id: id }))
		asset = RocInstall.asset_of(found.releases, id)?
		sha = Toolchain.require_digest({ id, asset })?
		if run.offline return Err(Toolchain.offline_missing(id))
		item = Roots.item(roots, Item.Toolchain(id))
		ctx = { roots, net: Net.from_env(run.env), now, published_at: RocInstall.published_of(found.releases, id), typed: id, id, item, asset, sha, system }
		Ok(Download({ id, size: asset.size, ctx }))
	}

	## R-SO14, R-DL1 to R-DL6, R-NI5, R-SO15, R-CC4: the compiler of a fetch when nothing is installed. `listed` is the list of `<cache>/toolchains` that the caller read. The calls, in order (the L2 cases `fetch/fe-flow` run 13 and
	## `fetch/fe-none` fix them):
	##
	## | Step | Does | Rule |
	## | --- | --- | --- |
	## | 1 | `gate`. `Stop(fail)`: that failure (exit 13), no call | R-DL5, R-DL10 |
	## | 2 | `offer!`. A failure is returned | R-SO14, R-CV1 |
	## | 3 | `Present(found)`: `RocInstall.first_default!` (the lock of `config.toml`, a read, and when none is set a second read and `write_atomic!`), then the result. No download | R-SO14, R-SO15 |
	## | 4 | `Download(offer)`: `Consent.required_want` with the id of the offer and the consent facts. `NeedTty`: one `tty!` call, `Mode.with_tty`, then again. `NeedsConsent`: `Consent.download_stop({ count: 1, size })` (exit 13). The list was read before the question, and no lock is held at that time (R-CC3 point 5) | R-DL4, R-DL5, R-HF1 |
	## | 5 | `Prompt.ask!` with `prompt` (the flag is `Ok(Yes)` when step 4 gave `Install`, else `Err(NoFlag)`). `No`: `Consent.command_declined` (exit 13) | R-DL1, R-NI5 |
	## | 6 | `RocInstall.install_offer!` (the lock of the item, the download, the extract: no default) | R-CC4 |
	## | 7 | `RocInstall.first_default!`: the downloaded compiler becomes `default-roc` when none is set. A default that is set stays | R-SO15 |
	##
	## The compiler is never a `git-`, `link-` or `copy-` build (the channel is nightlies, R-NS6).
	ensure! : Fx, { roots : Roots, run : NoRank.Run, listed : List(Str) } => Try(NoRank.Got, Fail)
	ensure! = |fx, facts| {
		consent = facts.run.downloads
		match NoRank.gate({ auto: consent.auto, yes: consent.yes, flag: consent.allow, offline: consent.offline }) {
			Stop(fail) => return Err(fail)
			Go => {}
		}
		offer = NoRank.offer!(fx, { env: consent.env, offline: consent.offline, scope: facts.run.scope })?
		match offer {
			Present(found) => {
				_ = RocInstall.first_default!(fx, facts.roots, found.id)?
				Ok({ id: found.id, installed: facts.listed.append(found.id) })
			}
			Download(download) => {
				mode = consented!(fx, consent, { id: download.id, size: download.size })?
				question = NoRank.prompt({ id: download.id, size: download.size })
				flag = if mode.decided == Install Ok(Yes) else Err(NoFlag)
				asked = Prompt.ask!(fx, question, { mode: mode.mode, yes: consent.yes, quiet: consent.quiet, flag })?
				if asked.answer != Yes return Err(Consent.command_declined(download.id))
				done = RocInstall.install_offer!(fx, download)?
				_ = RocInstall.first_default!(fx, facts.roots, done.id)?
				Ok({ id: done.id, installed: facts.listed.append(done.id) })
			}
		}
	}
}

# Step 4 of `ensure!`: `Consent.required_want` for the compiler of the offer. `NeedTty` makes one `tty!` call and asks again. `NeedsConsent` is the failure `Consent.download_stop` (exit 13).
consented! : Fx, Start.Downloads, { id : Str, size : U64 } => Try({ decided : [Refuse, AutoNo, NeedsConsent, Install, Ask, NeedTty], mode : Mode }, Fail)
consented! = |fx, consent, offer| {
	want = |mode| Consent.required_want({ id: offer.id, auto: consent.auto, mode, yes: consent.yes, flag: consent.allow })
	mode = if want(consent.mode) == NeedTty Mode.with_tty(consent.mode, fx.tty!()) else consent.mode
	decided = want(mode)
	if decided == NeedsConsent return Err(Consent.download_stop({ count: 1, size: offer.size }))
	Ok({ decided, mode })
}
