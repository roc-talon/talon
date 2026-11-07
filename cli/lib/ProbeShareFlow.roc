import Args
import Clock
import ClosureIndex
import Compiler
import Db
import Fail
import Fx
import Help
import IndexQuery
import Item
import Net
import Nightlies
import PrivacyGuard
import ProbeShare
import QueueSend
import Registry
import RocInstall
import Roots
import Share
import ShareFlow
import ShareJson
import Toolchain

## `tln probe --share`, part C (slice 217, round 2; R-PB6, Design Q491 to Q497). Direct style over `Fx`. The pure decisions are in `ProbeShare`. The command (`ProbeFlow`) probes first, prints the probe lines, then calls `send!` and prints the share lines.
## The calls, in order (the L2 cases `probe/ps2` to `probe/ps10`):
##
## | Step | Call | Rule |
## | --- | --- | --- |
## | 1 | `PrivacyGuard.check!` with the source `Url(source)` (no source: no call). A failure ends the command before any read of `compat.db` and before any registry request. | R-PB6, R-RG4, R-RG6 |
## | 2 | `db_query!` `FactsOf(hash)`. `Err(TooNew)`: exit 19 (`Db.on_err`), no request. No fact at all: `Ok` with no row and nothing else (no more call). | R-TF3 |
## | 3 | `platform!`, then `db_query!` `Pinned(keys)` with one key (tag, `Nightlies.target` of this machine) for each nightly of the facts: the tags found are `recorded` (Q492). | R-SH3 filter 3 |
## | 4 | One `ClosureIndex.send!` with `ProbeShare.closure_request` (headers `User-Agent`, `Content-Type`, no ingest). A failure ends the command (exit 15, R-E6). | R-PB6 (3), Q491 |
## | 5 | `ProbeShare.rows` with the answer, `headers: []`. No row: `Ok`, no request. `ProbeShare.batches`. | R-PB6, R-SH3 |
## | 6 | `read_files!` of `share.json`. Does not parse: exit 19, no request. Missing: made with a new id. | R-SH5, R-SH13, Q497 |
## | 7 | Each batch, in order: `http_send!` `QueueSend.request` (`timeout_s` 20, no `clock` before it), `ProbeShare.answer`. The first failure stops: its rows and the rest are `unsent`, and `stop` is its `Fail`. | R-AP10, R-E6, Q498 |
## | 8 | At least one request got a 200 or 201: one `clock!`, then the totals write. A failed write: one line `warning: ...` on stderr (`fx.err!`), no change of the result. | R-SH6, Q497 |
##
## The result: `unsent` is the rows past the 20 requests and the rows after a failed request. `stop` is `Ok(fail)` when a request failed, or `Ok(Fail ...)` of kind `Network` when rows are `unsent` with no failed request (the cap: the send did not finish, exit 15).
## The caller prints the lines first, then ends with the code of `stop` when the probe was 0. No `sleep!`, no retry (R-AP34).
ProbeShareFlow :: [].{

	## What the caller gives.
	## Slice 225 (R-RG9): `setting` is the place of the registry setting (`IndexQuery.source`) for the text of a stop with no answer. Not given (`""`): the short text.
	Input : { roots : Roots, net : Net.Settings, origin : Str, source : Str, hash : Str, env : List((Str, Str)), setting ?: Str }

	## R-PB6 (1), R-FL5, Q494: the first step of `tln probe --share`, right after `ProbeCmd.read` and before any project read. `env_all!`, `Roots.of_run!`, the read of `config.toml`, `Net.registry` with the flag, the environment and the config
	## (the calls of `tln share logout`, slice 220). `Direct`: `ProbeShare.direct` (exit 2). `--offline` with a registry: `ProbeShare.offline` (exit 15). Else the origin of the registry.
	check! : Fx, Args => Try({ origin : Str, setting : Str }, Fail)
	check! = |fx, args| {
		env = fx.env_all!()
		roots = Roots.of_run!(fx, env)?
		config_path = Roots.item(roots, Item.Config)
		config = Share.setting({ path: config_path, text: RocInstall.read_text!(fx, config_path)? })?
		match Net.registry({ flag: args.registry, env: Net.from_env(env).registry, config: config.registry }) {
			Direct => Err(ProbeShare.direct({}))
			Url(origin) => if args.offline Err(ProbeShare.offline({})) else Ok({ origin, setting: IndexQuery.source({ flag: args.registry, env: Net.from_env(env).registry, config: config.registry }) })
		}
	}

	## See the table above.
	send! : Fx, ProbeShareFlow.Input => Try({ shared : ProbeShare.Shared, kept_back : List(ProbeShare.KeptBack), unsent : List(Db.Queued), stop : Try(Fail, [None]) }, Fail)
	send! = |fx, input| {
		guard!(fx, input)?
		open = { path: Roots.item(input.roots, Item.CompatDb), busy_ms: Db.busy_ms, format: Db.format }
		stored = match fx.db_query!(open, FactsOf(input.hash)) {
			Ok(Facts(found)) => found.keep_if(|f| f.hash == input.hash)
			Ok(_) => []
			Err(err) => match Db.on_err({ err, what: Read, path: open.path }) {
				Stop(fail) => return Err(fail)
				Warn(text) => {
					fx.err!("warning: ${text}\n")
					[]
				}
			}
		}
		if stored.is_empty() {
			return Ok(none)
		}
		host = Toolchain.host(fx.platform!())?
		recorded = recorded!(fx, open, { stored, host })?
		request = ProbeShare.closure_request({ hash: input.hash, facts: stored, recorded })
		# Q503: no fact passes the filters 2, 3 and 6 (no `compilers`): no request, and no hash in an answer.
		answer = match request.compilers {
			Err(None) => None
			Ok(_) => Some(ClosureIndex.send!(fx, { origin: input.origin, version: Help.version, request, headers: Registry.headers({ version: Help.version, body: Json }), source: input.?setting ?? "" })?)
		}
		answers = match answer {
			None => []
			Some(found) => [found]
		}
		domain = stored.map(|f| f.nightly).keep_if(|id| Compiler.kind(id) == Nightly).map(|id| { id, published_at: 0, asset: Err(NoAsset) })
		plan = ProbeShare.rows({ hash: input.hash, facts: stored, recorded, answers, headers: [], domain, talon_version: Help.version, queued_at: "" })
		if plan.rows.is_empty() {
			return Ok({ ..none, kept_back: plan.kept_back })
		}
		json_path = Roots.item(input.roots, Item.ShareJson)
		contributor = contributor!(fx, json_path)?
		batches = ProbeShare.batches(plan.rows)
		sent = send_batches!(fx, { origin: input.origin, setting: input.?setting ?? "", contributor, batches: batches.send })
		unsent = sent.unsent.concat(batches.unsent)
		if sent.shared.requests > 0 {
			totals!(fx, input, json_path, sent.shared)
		}
		stop = match sent.stop {
			Ok(fail) => Ok(fail)
			Err(None) => if unsent.is_empty() Err(None) else Ok(ProbeShare.unfinished({ requests: sent.shared.requests, count: unsent.len() }))
		}
		Ok({ shared: sent.shared, kept_back: plan.kept_back, unsent, stop })
	}
}

none : { shared : ProbeShare.Shared, kept_back : List(ProbeShare.KeptBack), unsent : List(Db.Queued), stop : Try(Fail, [None]) }
none = { shared: { requests: 0, sent: 0, counted: 0, first: 0, skipped: 0 }, kept_back: [], unsent: [], stop: Err(None) }

# Step 1: the guard for a `github.com` source.
guard! : Fx, ProbeShareFlow.Input => Try({}, Fail)
guard! = |fx, input| if input.source.is_empty() {
	Ok({})
} else {
	PrivacyGuard.check!(fx, { net: input.net, roots: input.roots, sources: [Url(input.source)], offline: Bool.False, frozen: Bool.False })
}

# Step 3: the tags with a `pinned` row for the host target (Q492).
recorded! : Fx, Db.Open, { stored : List(Db.Fact), host : Nightlies.Host } => Try(List(Str), Fail)
recorded! = |fx, open, facts| {
	target = Nightlies.target(facts.host)
	tags = facts.stored.map(|f| f.nightly).keep_if(|id| Compiler.kind(id) == Nightly).fold([], |found, id| if found.contains(id) found else found.append(id))
	match fx.db_query!(open, Pinned(tags.map(|tag| { tag, target }))) {
		Ok(Pinned(rows)) => Ok(rows.keep_if(|r| r.target == target).map(|r| r.tag))
		Ok(_) => Ok([])
		Err(err) => match Db.on_err({ err, what: Read, path: open.path }) {
			Stop(fail) => Err(fail)
			Warn(text) => {
				fx.err!("warning: ${text}\n")
				Ok([])
			}
		}
	}
}

# Step 6: the id of `share.json`. A missing file is made (R-SH5); a file that does not parse is exit 19.
contributor! : Fx, Str => Try(Str, Fail)
contributor! = |fx, path| match fx.read_files!([path]) {
	[Ok(text)] => Ok(ShareJson.read({ path, text })?.id)
	_ => Ok(ShareFlow.ensure_doc!(fx, path)?.id)
}

# Step 7: the requests, one after another. The first failure stops the loop.
Sent : { shared : ProbeShare.Shared, unsent : List(Db.Queued), stop : Try(Fail, [None]) }

send_batches! : Fx, { origin : Str, setting : Str, contributor : Str, batches : List(List(Db.Queued)) } => Sent
send_batches! = |fx, run| {
	var $shared = none.shared
	var $unsent = []
	var $stop = Err(None)
	for batch in run.batches {
		if $stop == Err(None) {
			req = QueueSend.request({ origin: run.origin, talon_version: Help.version, contributor: run.contributor, rows: batch, timeout_s: 20 })
			match ProbeShare.answer({ origin: run.origin, version: Help.version, count: batch.len(), reply: fx.http_send!(req), source: run.setting }) {
				Ok(done) => {
					$shared = { requests: $shared.requests + 1, sent: $shared.sent + done.sent, counted: $shared.counted + done.counted, first: $shared.first + done.first, skipped: $shared.skipped + done.skipped }
				}
				Err(fail) => {
					$stop = Ok(fail)
					$unsent = batch
				}
			}
		} else {
			$unsent = $unsent.concat(batch)
		}
	}
	{ shared: $shared, unsent: $unsent, stop: $stop }
}

# Step 8: the totals. A failure is one warning (Q497).
totals! : Fx, ProbeShareFlow.Input, Str, ProbeShare.Shared => {}
totals! = |fx, input, path, shared| match Clock.now!(fx, input.env) {
	Err(fail) => fx.err!("warning: the totals of share.json are not saved: ${fail.message}\n")
	Ok(seconds) => {
		add = { sent: shared.sent, counted: shared.counted, first: shared.first }
		now = Clock.format_utc(seconds)
		match ShareFlow.totals_write!(fx, path, |doc| QueueSend.totals({ doc, add, now })) {
			Ok(_) => {}
			Err(fail) => fx.err!("warning: the totals of share.json are not saved: ${fail.message}\n")
		}
	}
}
