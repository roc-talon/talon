## The handlers of the move routes `PUT` and `DELETE /v1/packages/{owner}/{repo}/successor` (Registry 7.3: R-AP31, R-TP14, R-TP15, R-TP11, R-TP13; 4: R-AP32, R-AP41, R-AP45, R-AP46, R-AP51; slice 247, `docs/slices/247-move.md`).
## The decisions are in `lib/Move.roc` and `records/Move.roc` (pure, W0). This module only orders the effects. The tests are W2: `worker/tests/cases/move/`.
## `main.roc` calls `put!` and `delete!` for the route ids `PutSuccessor` and `DeleteSuccessor`.
## `Err(Refuse(problem))` is a problem answer, `Err(Fault(text))` is 500 `internal` (R-AP48, never a `crash`).
##
## Flow of `put!` (the order of the slice file section 3.1; the first check that fails gives the answer; all D1 calls go to one session `db.with_session!(Primary)`):
## 1. `req.bytes_with!({ max_bytes: IngestRoutes.body_limit })` (R-AP46): `Err(TooLarge)` is 413 `too-large`, `field` `body`. `Move.parse_body`: a fault is `Refuse` (400). No D1 call and no JWKS read before this is done.
## 2. `Auth.move!(req)`: the operator key, or a token (R-TP3 rows 1 to 3, then `Move.check_token`). A fault is `Refuse` (401, 403, 502, 500). No D1 call before it.
## 3. D1 call 1, one read batch: the old row with its newest release (kind, exposes), the successor row with its newest candidate, and the walk of the chain from the successor (a recursive CTE, R-AP41 rule 1).
##    No row for the old name: 404 `Move.no_repo`.
## 4. A token: `Move.put_role`. `Refuse(problem)` is 403. The operator key is `Move({ clear_offer: Bool.True })` with no table (Q247-4).
## 5. `Move.check` of the successor (R-AP31): 422 `successor-mismatch`. (Q247-7: the checks for an `Offer`.)
## 6. `Offer`: D1 call 2, one write batch: the offer, the event `offer` (action 8), the read of the answer. 202.
##    `Move`: `Move.put_effect`. `Same`: 200 with the row, no write, 1 D1 call. `Set` and `Replace`: D1 call 2, one write batch: the row (`Move.set_change`, the offer cleared by `clear_offer`),
##    the event `successor-set` with the claims text of `Publish.claims_json` (NULL for the operator), and last the read of the answer. 201 for `Set`, 200 for `Replace`.
## 7. The answer: the item of `repos` (`records.Closure.encode_repo`), `content-type: application/json`, `cache-control: no-store`, and the header `talon-bookmark` of the last batch. No cache drop (R-AP69 lists no move).
##
## Flow of `delete!`: no body. Steps 2 and 3 as above (the old row is needed for the role; no checks of the successor). `Move.delete_role` (a token) or the operator key. `Move.delete_effect`: `Same` is 200 with no write
## (1 D1 call), `Remove` is D1 call 2: the successor is cleared, the event `successor-removed` (action 7), the read of the answer. 200. The state after a removal is Q247-2.
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import pf.Time
import pf.Cache
import pf.Env
import pf.Log
import records.Closure
import records.Code
import records.Id
import records.Move as Wire
import lib.Identity
import lib.Move
import lib.Oidc
import lib.Problem
import lib.Publish
import lib.Reads
import Auth
import IngestRoutes

MoveRoutes :: [].{

	put! : Request, Str, Str => Try(Response, IngestRoutes.Error)
	put! = |req, owner, repo| {
		bytes = match req.bytes_with!({ max_bytes: IngestRoutes.body_limit }) {
			Ok(b) => b
			Err(TooLarge) => return Ok(too_large)
			Err(BodyErr(_)) => []
		}
		text = Move.parse_body(bytes).map_err(|p| Refuse(p))?
		caller = Auth.move!(req).map_err(|p| Refuse(p))?
		run!(req, owner, repo, Put(text), caller)
	}

	delete! : Request, Str, Str => Try(Response, IngestRoutes.Error)
	delete! = |req, owner, repo| {
		caller = Auth.move!(req).map_err(|p| Refuse(p))?
		run!(req, owner, repo, Delete, caller)
	}

	Caller : [Operator, Token(Oidc.Claims)]

	## What the request wants: a `PUT` with the name of the body as sent, or a `DELETE`.
	Want : [Put(Str), Delete]

	run! : Request, Str, Str, MoveRoutes.Want, MoveRoutes.Caller => Try(Response, IngestRoutes.Error)
	run! = |req, owner, repo, want, caller| {
		old_text = "${owner}/${repo}".with_ascii_lowercased()
		old_parsed = match Move.parse_name("${owner}/${repo}") {
			Ok(n) => n
			Err(BadName) => return Err(Refuse(Move.no_repo(old_text)))
		}
		old_id = Id.name_id(3, old_parsed.name.to_utf8())
		# The successor of a `PUT`: a text that is not a name is no row (the check Index).
		target = match want {
			Put(text) => match Move.parse_name(text) {
				Ok(n) => { name: n.name, id: Ok(Id.name_id(3, n.name.to_utf8())) }
				Err(BadName) => { name: text.with_ascii_lowercased(), id: Err(None) }
			}
			Delete => { name: "", id: Err(None) }
		}
		session = IngestRoutes.db.with_session!(Primary).map_err(IngestRoutes.fault)?
		reads = match want {
			Put(_) => [
				Sql.stmt(old_sql, [old_id]),
				Sql.stmt(newest_sql(""), [old_id]),
				Sql.stmt(succ_sql, [target.id ?? 0]),
				Sql.stmt(newest_sql(" AND r.yanked = 0 AND r.withdrawn IS NULL"), [target.id ?? 0]),
				Sql.stmt(chain_sql, [target.id ?? 0]),
			]
			Delete => [Sql.stmt(old_sql, [old_id])]
		}
		results = session.batch!(reads).map_err(IngestRoutes.fault)?
		found = read_old(results, old_parsed.name)?
		known = match found {
			Ok(f) => f
			Err(None) => return Err(Refuse(Move.no_repo(old_parsed.name)))
		}
		old = known.old
		claims_text = match caller {
			Operator => Err(None)
			Token(claims) => Ok(Publish.claims_json(claims))
		}
		now = Time.now_ms!()
		pre = { session, req, old, old_id, state_at: known.state_at, claims_text, now }
		match want {
			Delete => {
				match caller {
					Operator => {}
					Token(claims) => {
						Move.delete_role({ claims, old }).map_err(|p| Refuse(p))?
						match old_ids!(claims, old)? {
							Stop(response) => return Ok(response)
							Go => {}
						}
					}
				}
				match Move.delete_effect(old) {
					Same => answer!(session, 200, item_of(old, known.state_at, known.owner_changed))
					Remove => remove!(pre)
				}
			}
			Put(_) => {
				name = target.name
				role = match caller {
					Operator => Move({ clear_offer: Bool.True })
					Token(claims) => {
						repeat = old.successor == Ok(name) and claims.repository.map_ok(|r| r.caseless_ascii_equals(name)) == Ok(Bool.True)
						if (repeat) Move({ clear_offer: Bool.True }) else Move.put_role({ claims, old, name })
					}
				}
				verdict = match role {
					Refuse(problem) => return Err(Refuse(problem))
					Offer => {
						match caller {
							Token(claims) => match old_ids!(claims, old)? {
								Stop(response) => return Ok(response)
								Go => {}
							}
							Operator => {}
						}
						Offer
					}
					Move(m) => Move(m)
				}
				succ = match target.id {
					Ok(_) => read_succ(results)?
					Err(None) => Err(None)
				}
				facts = {
					old,
					old_newest: read_newest(results, 1)?,
					name,
					succ: succ_of(succ, results)?,
					chain: read_chain(results)?,
				}
				Move.check(facts).map_err(|p| Refuse(p))?
				successor_id = target.id ?? 0
				match verdict {
					Offer => {
						if old.offer == Ok(name) {
							answer!(session, 202, item_of(old, known.state_at, known.owner_changed))
						} else {
							offer!(pre, name, successor_id)
						}
					}
					Move(m) => match Move.put_effect(old, name) {
						Same => answer!(session, 200, item_of(old, known.state_at, known.owner_changed))
						effect => move!(pre, { name, successor_id, status: Move.put_status(effect), clear_offer: m.clear_offer })
					}
				}
			}
		}
	}

	# ---- the reads of D1 call 1 ----

	## The old row: R-RE11. `successor` and `offer` are names (`names` joins), NULL is `Missing`.
	old_sql : Str
	old_sql = "SELECT r.repository_id AS repository_id, r.repository_owner_id AS owner_id, r.state AS state, sn.value AS successor, o.value AS offer, r.state_at AS state_at, (SELECT e.action FROM repo_events e WHERE e.repo = ?1 AND e.action IN (1, 3) ORDER BY e.seq DESC LIMIT 1) AS owner_action, (SELECT e.time FROM repo_events e WHERE e.repo = ?1 AND e.action IN (1, 3) ORDER BY e.seq DESC LIMIT 1) AS owner_at FROM repos r LEFT JOIN names sn ON sn.id = r.successor LEFT JOIN names o ON o.id = r.offer WHERE r.repo = ?1"

	OldSql : { repository_id : U64, owner_id : U64, state : U64, successor : Try(Str, [Missing]), offer : Try(Str, [Missing]), state_at : U64, owner_action : Try(I64, [Missing]), owner_at : Try(U64, [Missing]) }

	## The newest release of a name: the largest version (R-IK5), the largest log index for a tie. `extra` is the condition of a candidate.
	newest_sql : Str -> Str
	newest_sql = |extra| "SELECT a.kind AS kind, a.exposes AS exposed FROM releases r JOIN artifacts a ON a.artifact = r.artifact WHERE r.repo = ?1${extra} ORDER BY r.version DESC, r.log_index DESC LIMIT 1"

	NewestSql : { kind : U8, exposed : Str }

	succ_sql : Str
	succ_sql = "SELECT state AS state FROM repos WHERE repo = ?1"

	SuccSql : { state : U64 }

	## R-SN8, R-AP41 rule 1: the walk from the successor. The start is on the walk, then each successor while the row is `moved`, fewer than 4 links.
	chain_sql : Str
	chain_sql = "WITH RECURSIVE walk(repo, depth) AS (SELECT ?1, 0 UNION SELECT r.successor, w.depth + 1 FROM walk w JOIN repos r ON r.repo = w.repo WHERE r.state = 2 AND r.successor IS NOT NULL AND w.depth < 3) SELECT n.value AS name FROM walk w JOIN names n ON n.id = w.repo ORDER BY w.depth"

	ChainSql : { name : Str }

	item_sql : Str
	item_sql = "SELECT n.value AS name, r.state AS state, sn.value AS successor, r.state_at AS state_at, (SELECT e.action FROM repo_events e WHERE e.repo = ?1 AND e.action IN (1, 3) ORDER BY e.seq DESC LIMIT 1) AS owner_action, (SELECT e.time FROM repo_events e WHERE e.repo = ?1 AND e.action IN (1, 3) ORDER BY e.seq DESC LIMIT 1) AS owner_at FROM repos r JOIN names n ON n.id = r.repo LEFT JOIN names sn ON sn.id = r.successor WHERE r.repo = ?1"

	ItemSql : { name : Str, state : U64, successor : Try(Str, [Missing]), state_at : U64, owner_action : Try(I64, [Missing]), owner_at : Try(U64, [Missing]) }

	state_of : U64 -> Try(Identity.State, IngestRoutes.Error)
	state_of = |code| match code {
		0 => Ok(Active)
		1 => Ok(Missing)
		2 => Ok(Moved)
		_ => Err(Fault("a repos row has a state that is not 0, 1 or 2"))
	}

	opt : Try(Str, [Missing]) -> Try(Str, [None])
	opt = |t| match t {
		Ok(text) => Ok(text)
		Err(Missing) => Err(None)
	}

	read_old : List(D1.Result), Str -> Try(Try({ old : Move.Old, state_at : U64, owner_changed : Try(Closure.OwnerChanged, [None]) }, [None]), IngestRoutes.Error)
	read_old = |results, name| {
		result = results.get(0).map_err(|_| Fault("the read batch gave no result"))?
		rows : Try(List(MoveRoutes.OldSql), _)
		rows = result.all()
		match rows.map_err(IngestRoutes.fault)? {
			[] => Ok(Err(None))
			[r, ..] => {
				state = state_of(r.state)?
				owner_changed = Reads.owner_changed_of(r.owner_action, r.owner_at).map_err(|BadRow(text)| Fault(text))?
				Ok(Ok({ owner_changed, old: { name, repository_id: r.repository_id, owner_id: r.owner_id, state, successor: opt(r.successor), offer: opt(r.offer) }, state_at: r.state_at }))
			}
		}
	}

	read_newest : List(D1.Result), U64 -> Try(Try(Move.Newest, [None]), IngestRoutes.Error)
	read_newest = |results, at| {
		result = results.get(at).map_err(|_| Fault("the read batch gave no result"))?
		rows : Try(List(MoveRoutes.NewestSql), _)
		rows = result.all()
		match rows.map_err(IngestRoutes.fault)? {
			[] => Ok(Err(None))
			[r, ..] => {
				kind = Code.kind_from_code(r.kind).map_err(|_| Fault("an artifact has a kind that is not 0, 1 or 2"))?
				modules = Move.exposes_of(r.exposed).map_err(|_| Fault("an artifact has an exposes text that is not a list of names"))?
				Ok(Ok({ kind, modules }))
			}
		}
	}

	read_succ : List(D1.Result) -> Try(Try(Identity.State, [None]), IngestRoutes.Error)
	read_succ = |results| {
		result = results.get(2).map_err(|_| Fault("the read batch gave no result"))?
		rows : Try(List(MoveRoutes.SuccSql), _)
		rows = result.all()
		match rows.map_err(IngestRoutes.fault)? {
			[] => Ok(Err(None))
			[r, ..] => Ok(Ok(state_of(r.state)?))
		}
	}

	succ_of : Try(Identity.State, [None]), List(D1.Result) -> Try(Try(Move.Successor, [None]), IngestRoutes.Error)
	succ_of = |state, results| match state {
		Err(None) => Ok(Err(None))
		Ok(s) => Ok(Ok({ state: s, newest: read_newest(results, 3)? }))
	}

	read_chain : List(D1.Result) -> Try(List(Str), IngestRoutes.Error)
	read_chain = |results| match results.get(4) {
		Err(_) => Ok([])
		Ok(result) => {
			rows : Try(List(MoveRoutes.ChainSql), _)
			rows = result.all()
			Ok(rows.map_err(IngestRoutes.fault)?.map(|r| r.name))
		}
	}

	# ---- Q247-9: the ids of a token of the old repository ----

	## A token of the old repository must have the id of the repository or of its owner that the old row has (R-TP9), else 403 `repository-changed` with `issues_url` (R-TP12).
	## A token of the successor has no check here.
	old_ids! : Oidc.Claims, Move.Old => Try([Go, Stop(Response)], IngestRoutes.Error)
	old_ids! = |claims, old| {
		is_old = claims.repository.map_ok(|r| r.caseless_ascii_equals(old.name)) == Ok(Bool.True)
		if !is_old {
			Ok(Go)
		} else {
			ids = Publish.claims_ids(claims).map_err(|p| Refuse(p))?
			if ids.repository_id == old.repository_id or ids.owner_id == old.owner_id {
				Ok(Go)
			} else {
				issues_url = Env.var!("ISSUES_URL").map_err(|_| Fault("the setting ISSUES_URL is missing"))?
				body = Identity.changed_json(Identity.changed(old.name, old.repository_id), issues_url)
				Ok(Stop(Response.from_bytes(403, "application/problem+json", body.to_utf8())))
			}
		}
	}

	# ---- the writes of D1 call 2 ----

	Pre : { session : D1.Session, req : Request, old : Move.Old, old_id : I64, state_at : U64, claims_text : Try(Str, [None]), now : U64 }

	name_id : Str -> I64
	name_id = |name| Id.name_id(3, name.to_utf8())

	old_successor_id : Move.Old -> Try(I64, [None])
	old_successor_id = |old| old.successor.map_ok(name_id)

	row_of : MoveRoutes.Pre -> Identity.Row
	row_of = |pre| {
		old = pre.old
		{ repo: pre.old_id, repository_id: old.repository_id, owner_id: old.owner_id, state: old.state, successor: old_successor_id(old), state_at: pre.state_at, time: 0 }
	}

	## `Set` and `Replace`: the row is `moved` with the new successor and the offer cleared, the event `successor-set`, the answer item. The guard is the state that the read saw
	## (R-AP41 rule 3): a request that lost a race changes no row, and its answer is 422 `successor-mismatch` Index (Q247-11).
	move! : MoveRoutes.Pre, { name : Str, successor_id : I64, status : U16, clear_offer : Bool } => Try(Response, IngestRoutes.Error)
	move! = |pre, input| {
		change = Move.set_change({ row: row_of(pre), successor: input.successor_id, now: pre.now })
		offer = if (input.clear_offer) ", offer = NULL" else ""
		update = Sql.stmt(
			"UPDATE repos SET state = 2, successor = ?2, state_at = ?3${offer} WHERE repo = ?1 AND state_at = ?4 AND successor IS ?5 AND EXISTS (SELECT 1 FROM repos s WHERE s.repo = ?2 AND s.state = 0)",
			(pre.old_id, input.successor_id, pre.now, pre.state_at, Sql.or_null(old_successor_id(pre.old))),
		)
		events = change.events.map(|e| IngestRoutes.event_stmt(e, pre.now, pre.claims_text))
		written!(pre, [update].concat(events), input.status, input.name)
	}

	## `Remove`: the successor is cleared, the state is `active` (Q247-2), the offer is cleared (Q247-5), the event `successor-removed` has the removed name (Q247-8).
	remove! : MoveRoutes.Pre => Try(Response, IngestRoutes.Error)
	remove! = |pre| {
		row = row_of(pre)
		ids = { repository_id: row.repository_id, owner_id: row.owner_id }
		event = Identity.event_of({ ..row, state: Active }, SuccessorRemoved, Ok(ids), ids)
		update = Sql.stmt(
			"UPDATE repos SET successor = NULL, state = 0, state_at = ?2, offer = NULL WHERE repo = ?1 AND state_at = ?3 AND successor IS ?4",
			(pre.old_id, pre.now, pre.state_at, Sql.or_null(row.successor)),
		)
		written!(pre, [update, IngestRoutes.event_stmt({ ..event, successor: row.successor }, pre.now, pre.claims_text)], 200, pre.old.name)
	}

	## `Offer`: the row gets the offer, nothing else changes (R-TP15). The event `offer` has the offered name (Q247-8).
	offer! : MoveRoutes.Pre, Str, I64 => Try(Response, IngestRoutes.Error)
	offer! = |pre, name, successor_id| {
		row = row_of(pre)
		ids = { repository_id: row.repository_id, owner_id: row.owner_id }
		event = Identity.event_of({ ..row, successor: Ok(successor_id) }, Offer, Ok(ids), ids)
		update = Sql.stmt(
			"UPDATE repos SET offer = ?2 WHERE repo = ?1 AND state = 0 AND state_at = ?3",
			(pre.old_id, successor_id, pre.state_at),
		)
		written!(pre, [update, IngestRoutes.event_stmt(event, pre.now, pre.claims_text)], 202, name)
	}

	## The write batch: the statements, then the read of the answer item. The first statement is the guarded `UPDATE`: no changed row is a lost race (Q247-11).
	written! : MoveRoutes.Pre, List(Sql.Stmt), U16, Str => Try(Response, IngestRoutes.Error)
	written! = |pre, stmts, status, name| {
		results = pre.session.batch!(stmts.append(Sql.stmt(item_sql, [pre.old_id]))).map_err(IngestRoutes.fault)?
		changed = results.get(0).map_ok(|r| r.info().changes) ?? 0
		if changed == 0 {
			Err(Refuse(Problem.new(SuccessorMismatch, Wire.detail(name, Index))))
		} else {
			last = results.last().map_err(|_| Fault("the batch gave no result"))?
			rows : Try(List(MoveRoutes.ItemSql), _)
			rows = last.all()
			item = match rows.map_err(IngestRoutes.fault)? {
				[r, ..] => { name: r.name, state: state_of(r.state)?, successor: opt(r.successor), state_at: r.state_at, owner_changed: Reads.owner_changed_of(r.owner_action, r.owner_at).map_err(|BadRow(text)| Fault(text))? }
				[] => return Err(Fault("the answer item has no row"))
			}
			answer!(pre.session, status, item).map_ok(
				|res| {
					key = "${IngestRoutes.origin_of(pre.req.url())}/v1/packages/${pre.old.name}/releases"
					res.after(
						|| {
							match Cache.default.delete!(key) {
								Ok({}) | Err(NotFound) => {}
								Err(e) => Log.warn!("cache drop failed", { key, error: Str.inspect(e) })
							}
							Ok({})
						},
					)
				},
			)
		}
	}

	item_of : Move.Old, U64, Try(Closure.OwnerChanged, [None]) -> Closure.Repo
	item_of = |old, state_at, owner_changed| { name: old.name, state: old.state, successor: old.successor, state_at, owner_changed }

	## The answer: the item of `repos` (R-AP32), `talon-bookmark` of the last call.
	answer! : D1.Session, U16, Closure.Repo => Try(Response, IngestRoutes.Error)
	answer! = |session, status, item| {
		base = Response.from_bytes(status, "application/json", Closure.encode_repo(item).to_utf8()).with_header("cache-control", "no-store")
		Ok(
			match session.bookmark!() {
				Ok(bookmark) => base.with_header("talon-bookmark", bookmark)
				Err(NotFound) => base
			},
		)
	}

	## R-AP46: the 413 of a body that is larger than the limit.
	too_large : Response
	too_large = {
		problem = Problem.new(TooLarge, "the body of the move request is larger than its limit of ${IngestRoutes.body_limit.to_str()}")
		Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, { field: "body", limit: IngestRoutes.body_limit }).to_utf8())
	}
}
