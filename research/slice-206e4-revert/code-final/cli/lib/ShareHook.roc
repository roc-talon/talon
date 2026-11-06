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
import JsonDoc
import Nightlies
import QueueSend
import ResolveBase
import Roots
import ShareQueue
import ShareRound

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
				Ok(roots) => QueueSend.send!(fx, { roots, sharing: sharing_of(found), talon_version: Help.version })
				Err(_) => {}
			}
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
