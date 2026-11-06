import records.Closure as Wire
import Args
import BuildTarget
import Common
import Db
import Fail
import Fx
import Help
import Ident
import IndexNotes
import Item
import JsonDoc
import Nightlies
import PinOrder
import Probe
import QueueSend
import ResolveBase
import Roots
import Share
import ShareQueue
import ShareRound
import Smoke
import Temp
import Toolchain

## The share hooks of the commands that sent a registry request (slice 206e4; CLI 1 R-SH2 to R-SH4, Registry R-AP29, R-AP30; Design Q533 to Q541). Command code over `Fx` that only calls the parts of slices 210, 215 and 216: `IndexNotes`, `ShareQueue.admit` and `ShareQueue.enqueue!`, `QueueSend.send!`.
## A run that sent a closure query has a `Fail.Ran` (`ran_of`). The flows give it to the end of the command in the `Done` of a success and in the `ran` of a `Fail`.
##
## | Part | Does | Rule |
## | --- | --- | --- |
## | `enqueue!` | After the `db_write!` of the facts of a probe round: R-SH2 (`Share.state`) and at least one fact, else no call. Then `db_query!` `Pinned` (one key for each compiler of the round, with the machine target), `Clock.now!` (`queued_at`), `ShareQueue.admit` for each fact in the order of the round, one `ShareQueue.enqueue!` | R-SH3, R-SH4, R-TF7, Design Q539 |
## | `notes`, `index_notes` | The notes of `IndexNotes` for the answers of the run | R-AP30, Design Q407, Q408, Q540 |
## | `failed!` | `Common.failed!`, then the index notes on stderr (a command that prints them and has not yet), then the send | R-AP30, R-SH4, Design Q533 |
## | `send!` | After the output: `QueueSend.send!`, not after exit 15 or 19 | R-SH4, Design Q533, Q541 |
ShareHook :: [].{

	## The run of a command that sent a closure query: `registry` is `Read` and the index is an `Answer`. `second` is the second answer of a held move. `notes` is true for a command that prints the index notes.
	## Any other run (no registry, `--offline`, no group and no hash, `--frozen`) has `Err(None)`: it sent no request, so it has no hook (R-SH4, Design Q469, Q541).
	ran_of : ResolveBase.Request, { notes : Bool, second : Try(Wire.Answer, [NotRead]) } -> Try(Fail.Ran, [None])
	ran_of = |request, how| match (request.registry, request.index) {
		(Read(query), Answer(a)) => Ok({
			origin: query.origin,
			share: query.share,
			offline: request.offline,
			env: request.downloads.env,
			now: request.now,
			answers: match how.second {
				Ok(other) => [a.answer, other]
				Err(NotRead) => [a.answer]
			},
			notes: how.notes,
			noted: Bool.False,
			headers: [],
			built: [],
		})
		_ => Err(None)
	}

	## The header facts of the hashes that the command read (Q450, Q535): the kind and the target names of each fact. The ladder and the search share them.
	headers_of : List(ResolveBase.Fact), List(BuildTarget.Seen) -> List({ hash : Str, kind : [Package, Platform, App], names : List(Str) })
	headers_of = |known, seen| known.keep_oks(|k| header_of(hash_of(k.url), known, seen))

	## The failure with the run attached (`Err(None)`: as it is). `noted` is true when the notes were printed already.
	attach : Fail, Try(Fail.Ran, [None]), Bool -> Fail
	attach = |fail, ran, noted| match ran {
		Ok(found) => { ..fail, ran: Ok({ ..found, noted }) }
		Err(None) => fail
	}

	## The texts of the index notes of the run, with no `note: ` prefix (R-AP30).
	notes : Fail.Ran -> List(Str)
	notes = |ran| IndexNotes.notes({ now: ran.now, answers: ran.answers })

	## `data` with the member `index_notes` at the end, when the command prints the notes and there is a stale item (Design Q407, Q540). Other values: `data` as it is.
	with_index_notes : JsonDoc, Try(Fail.Ran, [None]) -> JsonDoc
	with_index_notes = |data, ran| match (data, ran) {
		(Obj(members), Ok(found)) if found.notes => match IndexNotes.index_notes({ now: found.now, answers: found.answers }) {
			Ok(doc) => Obj(members.append(("index_notes", doc)))
			Err(None) => data
		}
		_ => data
	}

	## A failure of a command: `Common.failed!`, then (when the failure has a run) the index notes on stderr after the error text (`--quiet` hides them), then the send. The exit code is the one of `Common.failed!`.
	failed! : Fx, Args, Fail => I32
	failed! = |fx, args, fail| {
		code = Common.failed!(fx, args, fail)
		match fail.ran {
			Ok(ran) => {
				if ran.notes and !ran.noted and !args.quiet {
					for text in ShareHook.notes(ran) {
						fx.err!("note: ${text}\n")
					}
				}
				ShareHook.send!(fx, fail.ran, code)
			}
			Err(None) => {}
		}
		code
	}

	## R-SH4, Design Q533: the send at the end of the command, after its output. Not for a run with no request, and not after exit 15 (a network failure) or 19 (a failure of a file). `QueueSend.send!` checks R-SH2 again.
	send! : Fx, Try(Fail.Ran, [None]), I32 => {}
	send! = |fx, ran, code| match ran {
		Err(None) => {}
		Ok(found) => if code == 15 or code == 19 {
			{}
		} else {
			match Roots.of_run!(fx, found.env) {
				Ok(roots) => {
					# Slice 218 (R-SM1, Design Q552, Q553): the smoke builds, after the work and before the send, when the send runs (not after exit 15 or 19).
					ShareHook.smoke!(fx, found, roots)
					QueueSend.send!(fx, { roots, sharing: sharing_of(found), talon_version: Help.version })
				}
				Err(_) => {}
			}
		}
	}

	## Slice 218 (R-SM1 to R-SM5, R-SM7, Design Q548 to Q554): the smoke builds of the keys that the command built (`ran.built`). No output, no change of the exit code, no probe budget, and a failed step ends the step with no more call (a smoke build is a bonus).
	## The calls, in this order, and only when R-SH2 is true and at least one key was built:
	##
	## | # | Calls |
	## | --- | --- |
	## | 1 | `db_query!` `Smoke` (the keys), `platform`, `db_query!` `Pinned`, then `Smoke.choose` |
	## | 2 | For each key with `Build`, in key order: `random`, `make_dirs`, `write_atomic` of `main.roc` (`Smoke.app_text`: no smoke app gives no call for the key) |
	## | 3 | One `probes!` round for all keys: `roc build --target=<key target> main.roc --output=<tmp>/tln-probe.out --no-cache`, `probe.timeout`, no budget |
	## | 4 | One `db_write!` `Smoke` with the rows (`Smoke.result`: `Row`; a machine error and `NoFact` give none), then `delete!` of each temp dir |
	## | 5 | `ShareRound.enqueue!` with `probe: Smoke` for the stored rows (filter 6 stops a hang) |
	smoke! : Fx, Fail.Ran, Roots => {}
	smoke! = |fx, ran, roots| {
		sharing = sharing_of(ran)
		match Share.state(sharing) {
			Off(_) => return {}
			On => {}
		}
		if ran.built.is_empty() return {}
		open = { path: Roots.item(roots, CompatDb), busy_ms: Db.busy_ms, format: Db.format }
		keys = ran.built.map(|b| b.key).fold([], |found, k| if found.contains(k) found else found.append(k))
		done = match fx.db_query!(open, Smoke(keys)) {
			Ok(Smoke(rows)) => rows
			_ => return {}
		}
		host = match Toolchain.host(fx.platform!()) {
			Ok(found) => found
			Err(_) => return {}
		}
		target = Nightlies.target(host)
		ids = keys.map(|k| k.nightly).fold([], |found, id| if found.contains(id) found else found.append(id))
		pins = match fx.db_query!(open, Pinned(ids.map(|id| { tag: id, target }))) {
			Ok(Pinned(rows)) => rows
			_ => return {}
		}
		recorded = ids.keep_if(|id| pins.any(|p| p.target == target and PinOrder.same_id(p.tag, id)))
		domain = ids.map(|id| { id, published_at: 0, asset: Err(NoAsset) })
		choices = Smoke.choose({ built: keys, installed: ran.built.map(|b| b.key.nightly), done, recorded, answers: ran.answers, domain })
		var $jobs = []
		for choice in choices {
			match choice.verdict {
				Build => match ran.built.find_first(|b| b.key == choice.key) {
					Ok(built) => match Smoke.app_text({ url: built.url, text: built.text }) {
						Ok(text) => {
							tmp = Roots.item(roots, Item.TalonTmp(Temp.hex(fx.random!())))
							made = fx.make_dirs!([tmp])
							wrote = match made {
								Ok(_) => fx.write_atomic!([{ path: "${tmp}/main.roc", content: text }])
								Err(_) => Err({ path: tmp, err: Other("make_dirs") })
							}
							match wrote {
								Ok(_) => {
									spec = {
										compiler: built.key.nightly,
										program: built.program,
										args: ["build", "--target=${built.key.target}"].concat(Probe.build_args({ file: "main.roc", options: [], output: "${tmp}/tln-probe.out" }).drop_first(1)),
										dir: tmp,
										env: built.env,
										timeout: built.timeout,
										weight: Probe.weight(Build({ output: "${tmp}/tln-probe.out" })),
									}
									$jobs = $jobs.append({ key: built.key, tmp, spec, slots: built.slots })
								}
								Err(_) => {
									_ = fx.delete!([tmp])
								}
							}
						}
						Err(NoSmoke) => {}
					}
					Err(_) => {}
				}
				Skip(_) => {}
			}
		}
		if $jobs.is_empty() return {}
		pool = $jobs.map(|j| j.slots).fold(0, |most, n| if n > most n else most)
		outputs = fx.probes!({ pool, specs: $jobs.map(|j| j.spec) })
		results = $jobs.map2(outputs, |j, out| (j, Smoke.result(out)))
		rows = results.keep_oks(
			|(j, r)| match r {
				Row(outcome) => Ok({ hash: j.key.hash, nightly: j.key.nightly, target: j.key.target, outcome })
				_ => Err(NoRow)
			},
		)
		stored = if rows.is_empty() {
			Bool.False
		} else {
			match fx.db_write!(open, Smoke(rows)) {
				Ok(_) => Bool.True
				Err(err) => match Db.on_err({ err, what: Write, path: open.path }) {
					Stop(_) => Bool.False
					Warn(text) => {
						fx.err!("warning: ${text}\n")
						Bool.False
					}
				}
			}
		}
		for j in $jobs {
			_ = fx.delete!([j.tmp])
		}
		if stored {
			facts = rows.map(|r| { hash: r.hash, nightly: r.nightly, target: r.target, outcome: r.outcome, modules: [], closure: "" })
			_ = ShareRound.enqueue!(fx, { roots, ran, probe: Smoke, facts, headers: ran.headers, domain })
		}
	}

	## R-SH3, R-SH4, R-TF7, Design Q535, Q536, Q539: the facts of a probe round (`facts`, the unit probes of this command, in the order of the probe results) go into the queue. The calls, in this order and only when R-SH2 is true and `facts` is not empty:
	## `db_query!` `Pinned` (the recorded sha256 of each compiler of the round, filter 3), `clock`, one `db_write!` `Queue` (no row: no call). `known` and `seen` are the header facts that the command read (`PickLoop.read_all!`): the kind and the target names of a hash with no `artifacts` row (Q535: no second read).
	## `domain` is the compilers of the round for the `bot` rows (`PickLoop.round_domain`). A failed `Pinned` read is the warning of R-CC8 (the rows are not queued); `TooNew` is the failure (exit 19).
	enqueue! : Fx, ResolveBase.Request, { facts : List(Db.Fact), known : List(ResolveBase.Fact), seen : List(BuildTarget.Seen), second : Try(Wire.Answer, [NotRead]), domain : List(Nightlies.Release) } => Try({}, Fail)
	enqueue! = |fx, request, round| match ShareHook.ran_of(request, { notes: Bool.False, second: round.second }) {
		Ok(ran) => ShareRound.enqueue!(
			fx,
			{
				roots: request.roots,
				ran,
				probe: Unit,
				facts: round.facts,
				headers: round.facts.keep_oks(|f| header_of(f.hash, round.known, round.seen)),
				domain: round.domain,
			},
		)
		Err(None) => Ok({})
	}
}

# R-SH2: the facts of `Share.state` for the run.
sharing_of : Fail.Ran -> ShareQueue.Sharing
sharing_of = |ran| { share: ran.share, registry: Url(ran.origin), offline: ran.offline, env: ran.env }

# Design Q450, Q535: the kind and the target names of a hash from the header facts that the command read.
header_of : Str, List(ResolveBase.Fact), List(BuildTarget.Seen) -> Try({ hash : Str, kind : [Package, Platform, App], names : List(Str) }, [NoHeader])
header_of = |hash, known, seen| match known.find_first(|k| hash_of(k.url) == hash) {
	Ok(k) => Ok({
		hash,
		kind: k.release.kind,
		names: match seen.find_first(|s| s.url == k.url) {
			Ok(s) => s.found ?? []
			Err(_) => []
		},
	})
	Err(_) => Err(NoHeader)
}

hash_of : Str -> Str
hash_of = |url| match Ident.of_url(url) {
	Ok(ident) => ident.hash
	Err(_) => ""
}
