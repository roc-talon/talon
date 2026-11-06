import Clock
import Db
import Fail
import Fx
import Help
import Nightlies
import PinOrder
import Roots
import Share
import ShareQueue
import Toolchain

## The queue step of a round of probes (slice 206e4; CLI 1 R-SH2 to R-SH4, R-TF7; Design Q535, Q536, Q539, Q543). Command code over `Fx`, shared by the search (`ShareHook.enqueue!`) and the ladder (`UnitFlow.first!`): it needs no `ResolveBase`.
## The calls, in this order and only when R-SH2 is true and `facts` is not empty: `platform` (the machine target of the `Pinned` key), `db_query!` `Pinned` (the recorded sha256 of each compiler of the round, filter 3), `clock`, one `db_write!` `Queue` through `ShareQueue.enqueue!` (no row: no call).
## `facts` are the unit probes of this command (the baseline and the whole-app checks are not facts of the round: filter 2). `headers` are the kind and the target names of a hash with no `artifacts` row (Design Q450, Q535). `domain` is the compilers of the round for the `bot` rows.
## A failed `Pinned` read is the warning of R-CC8 (the rows are not queued); `TooNew` is the failure (exit 19).
ShareRound :: [].{

	enqueue! : Fx, { roots : Roots, ran : Fail.Ran, facts : List(Db.Fact), headers : List({ hash : Str, kind : [Package, Platform, App], names : List(Str) }), domain : List(Nightlies.Release) } => Try({}, Fail)
	enqueue! = |fx, round| {
		ran = round.ran
		sharing = { share: ran.share, registry: Url(ran.origin), offline: ran.offline, env: ran.env }
		match Share.state(sharing) {
			Off(_) => return Ok({})
			On => {}
		}
		if round.facts.is_empty() return Ok({})
		host = match Toolchain.host(fx.platform!()) {
			Ok(found) => found
			Err(_) => return Ok({})
		}
		target = Nightlies.target(host)
		open = { path: Roots.item(round.roots, CompatDb), busy_ms: Db.busy_ms, format: Db.format }
		ids = round.facts.map(|f| f.nightly).fold([], |found, id| if found.contains(id) found else found.append(id))
		recorded = match fx.db_query!(open, Pinned(ids.map(|id| { tag: id, target }))) {
			Ok(Pinned(rows)) => rows
			Ok(_) => []
			Err(err) => match Db.on_err({ err, what: Read, path: open.path }) {
				Stop(fail) => return Err(fail)
				Warn(text) => {
					fx.err!("warning: ${text}\n")
					return Ok({})
				}
			}
		}
		queued_at = match Clock.now!(fx, ran.env) {
			Ok(seconds) => Clock.format_utc(seconds)
			Err(_) => return Ok({})
		}
		rows = round.facts.keep_oks(
			|f| match ShareQueue.admit({
				sharing,
				fact: {
					origin: Probed,
					probe: Unit,
					compiler: { id: f.nightly, recorded: recorded.any(|p| p.target == target and PinOrder.same_id(p.tag, f.nightly)) },
					hash: f.hash,
					target: f.target,
					outcome: f.outcome,
					machine_error: Bool.False,
				},
				answers: ran.answers,
				headers: round.headers,
				domain: round.domain,
				talon_version: Help.version,
				queued_at,
			}) {
				Queue(row) => Ok(row)
				Skip(_) => Err(Skipped)
			},
		)
		match ShareQueue.enqueue!(fx, { roots: round.roots, rows, cap: Db.queue_cap }) {
			Ok(_) => Ok({})
			Err(fail) => Err(fail)
		}
	}
}
