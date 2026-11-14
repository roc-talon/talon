## Private reference of slice 247 (test agent). Not for the code agent (TW18).
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import pf.Time
import records.Closure
import lib.Identity
import lib.Move
import lib.Oidc
import lib.Problem
import lib.Publish
import lib.Reads
import Auth
import IngestRoutes

MoveRoutes :: [].{

	Who : [Operator, Token(Oidc.Claims)]

	OldSql : { repository_id : U64, owner_id : U64, state : U64, state_at : U64, successor : Try(Str, [Missing]), offer : Try(Str, [Missing]) }
	NewestSql : { kind : U64, modules : Str }
	StateSql : { state : U64, state_at : U64 }
	NameSql : { name : Str, depth : U64 }
	AnswerSql : { name : Str, state : U64, state_at : U64, successor : Try(Str, [Missing]) }

	put! : Request, Str, Str => Try(Response, IngestRoutes.Error)
	put! = |req, owner, repo| {
		bytes = match req.bytes_with!({ max_bytes: IngestRoutes.body_limit }) {
			Ok(b) => b
			Err(TooLarge) => return Ok(too_large)
			Err(BodyErr(_)) => []
		}
		sent = Move.parse_body(bytes).map_err(|p| Refuse(p))?
		who = Auth.move!(req).map_err(|p| Refuse(p))?
		go!(who, owner, repo, Put(sent.with_ascii_lowercased()))
	}

	delete! : Request, Str, Str => Try(Response, IngestRoutes.Error)
	delete! = |req, owner, repo| {
		who = Auth.move!(req).map_err(|p| Refuse(p))?
		go!(who, owner, repo, Delete)
	}

	state_of : U64 -> Try(Identity.State, IngestRoutes.Error)
	state_of = |n| match n {
		0 => Ok(Active)
		1 => Ok(Missing)
		2 => Ok(Moved)
		_ => Err(Fault("a repos row has a state that is not 0, 1 or 2"))
	}

	kind_of : U64 -> Try(_, IngestRoutes.Error)
	kind_of = |n| match n {
		0 => Ok(App)
		1 => Ok(Package)
		2 => Ok(Platform)
		_ => Err(Fault("an artifact has a kind that is not 0, 1 or 2"))
	}

	newest_of : List(D1.Result) , U64 -> Try(Try(Move.Newest, [None]), IngestRoutes.Error)
	newest_of = |results, at| {
		result = results.get(at).map_err(|_| Fault("the read gave no result"))?
		rows : Try(List(MoveRoutes.NewestSql), _)
		rows = result.all()
		match rows.map_err(IngestRoutes.fault)? {
			[] => Ok(Err(None))
			[r, ..] => {
				kind = kind_of(r.kind)?
				modules = Move.exposes_of(r.modules).map_err(|_| Fault("an artifact has exposes that is not a list"))?
				Ok(Ok({ kind, modules }))
			}
		}
	}

	read_sql : List(Str)
	read_sql = [
		"SELECT r.repository_id AS repository_id, r.repository_owner_id AS owner_id, r.state AS state, r.state_at AS state_at, (SELECT s.value FROM names s WHERE s.id = r.successor) AS successor, (SELECT o.value FROM names o WHERE o.id = r.offer) AS offer FROM repos r WHERE r.repo = ?1",
		"SELECT a.kind AS kind, a.exposes AS modules FROM releases r JOIN artifacts a ON a.artifact = r.artifact WHERE r.repo = ?1 ORDER BY r.version DESC, r.log_index DESC LIMIT 1",
		"SELECT r.state AS state, r.state_at AS state_at FROM repos r WHERE r.repo = ?1",
		"SELECT a.kind AS kind, a.exposes AS modules FROM releases r JOIN artifacts a ON a.artifact = r.artifact WHERE r.repo = ?1 AND r.yanked = 0 AND r.withdrawn IS NULL ORDER BY r.version DESC, r.log_index DESC LIMIT 1",
		"WITH RECURSIVE walk(repo, n) AS (SELECT ?1, 0 UNION ALL SELECT r.successor, walk.n + 1 FROM walk JOIN repos r ON r.repo = walk.repo WHERE r.state = 2 AND r.successor IS NOT NULL AND walk.n < 4) SELECT n.value AS name, walk.n AS depth FROM walk JOIN names n ON n.id = walk.repo ORDER BY walk.n",
	]

	answer_sql : Str
	answer_sql = "SELECT n.value AS name, r.state AS state, r.state_at AS state_at, (SELECT s.value FROM names s WHERE s.id = r.successor) AS successor FROM repos r JOIN names n ON n.id = r.repo WHERE r.repo = ?1"

	no_succ : Try(I64, [None])
	no_succ = Err(None)

	event_sql : Str
	event_sql = "INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), ?2, r.repository_id, r.repository_id, r.repository_owner_id, r.repository_owner_id, ?3, ?4, ?5 FROM repos r WHERE r.repo = ?1"

	go! : MoveRoutes.Who, Str, Str, [Put(Str), Delete] => Try(Response, IngestRoutes.Error)
	go! = |who, owner, repo, action| {
		old_name = "${owner}/${repo}".with_ascii_lowercased()
		old_id = Reads.repo_id(owner, repo)
		sent = match action {
			Put(n) => n
			Delete => ""
		}
		succ_id = match Move.parse_name(sent) {
			Ok(n) => Reads.repo_id(n.owner, n.repo)
			Err(_) => 0
		}
		session = IngestRoutes.db.with_session!(Primary).map_err(IngestRoutes.fault)?
		first = session.batch!(
			[
				Sql.stmt(read_sql.get(0) ?? "", [old_id]),
				Sql.stmt(read_sql.get(1) ?? "", [old_id]),
				Sql.stmt(read_sql.get(2) ?? "", [succ_id]),
				Sql.stmt(read_sql.get(3) ?? "", [succ_id]),
				Sql.stmt(read_sql.get(4) ?? "", [succ_id]),
			],
		).map_err(IngestRoutes.fault)?
		old_result = first.get(0).map_err(|_| Fault("the read gave no result"))?
		old_rows : Try(List(MoveRoutes.OldSql), _)
		old_rows = old_result.all()
		row = match old_rows.map_err(IngestRoutes.fault)? {
			[] => return Err(Refuse(Move.no_repo(old_name)))
			[r, ..] => r
		}
		old : Move.Old
		old = {
			name: old_name,
			repository_id: row.repository_id,
			owner_id: row.owner_id,
			state: state_of(row.state)?,
			successor: match row.successor {
				Ok(s) => Ok(s)
				Err(Missing) => Err(None)
			},
			offer: match row.offer {
				Ok(s) => Ok(s)
				Err(Missing) => Err(None)
			},
		}
		now = Time.now_ms!()
		claims_text = match who {
			Operator => Err(None)
			Token(c) => Ok(Publish.claims_json(c))
		}
		succ_state_result = first.get(2).map_err(|_| Fault("the read gave no result"))?
		succ_rows : Try(List(MoveRoutes.StateSql), _)
		succ_rows = succ_state_result.all()
		succ : Try(Move.Successor, [None])
		succ = match succ_rows.map_err(IngestRoutes.fault)? {
			[] => Err(None)
			[r, ..] => Ok({ state: state_of(r.state)?, newest: newest_of(first, 3)? })
		}
		chain_result = first.get(4).map_err(|_| Fault("the read gave no result"))?
		chain_rows : Try(List(MoveRoutes.NameSql), _)
		chain_rows = chain_result.all()
		chain = chain_rows.map_err(IngestRoutes.fault)?.map(|r| r.name)
		old_newest = newest_of(first, 1)?
		unchanged = item_of(old, row.state_at)
		match action {
			Put(name) => {
				role = match who {
					Operator => Move({ clear_offer: Bool.True })
					Token(c) => Move.put_role({ claims: c, old, name })
				}
				offer_only = match role {
					Refuse(problem) => return Err(Refuse(problem))
					Offer => Bool.True
					Move(_) => Bool.False
				}
				facts = { old, old_newest, name, succ: if (Move.parse_name(name) == Err(BadName)) Err(None) else succ, chain }
				Move.check(facts).map_err(|p| Refuse(p))?
				if offer_only {
					stmts = [
						Sql.stmt("UPDATE repos SET offer = ?2 WHERE repo = ?1", (old_id, succ_id)),
						Sql.stmt(event_sql, (old_id, 8, Sql.or_null(Ok(succ_id)), Sql.or_null(claims_text), now)),
						Sql.stmt(answer_sql, [old_id]),
					]
					results = session.batch!(stmts).map_err(IngestRoutes.fault)?
					respond!(session, 202, results)
				} else {
					effect = Move.put_effect(old, name)
					match effect {
						Same => json_response!(session, 200, Closure.encode_repo(unchanged))
						_ => {
							stmts = [
								Sql.stmt("UPDATE repos SET state = 2, successor = ?2, state_at = ?3, offer = NULL WHERE repo = ?1", (old_id, succ_id, now)),
								Sql.stmt(event_sql, (old_id, 6, Sql.or_null(Ok(succ_id)), Sql.or_null(claims_text), now)),
								Sql.stmt(answer_sql, [old_id]),
							]
							results = session.batch!(stmts).map_err(IngestRoutes.fault)?
							respond!(session, Move.put_status(effect), results)
						}
					}
				}
			}
			Delete => {
				match who {
					Operator => {}
					Token(c) => Move.delete_role({ claims: c, old }).map_err(|p| Refuse(p))?
				}
				match Move.delete_effect(old) {
					Same => json_response!(session, 200, Closure.encode_repo(unchanged))
					Remove => {
						stmts = [
							Sql.stmt("UPDATE repos SET state = 0, successor = NULL, state_at = ?2 WHERE repo = ?1", (old_id, now)),
							Sql.stmt(event_sql, (old_id, 7, Sql.or_null(no_succ), Sql.or_null(claims_text), now)),
							Sql.stmt(answer_sql, [old_id]),
						]
						results = session.batch!(stmts).map_err(IngestRoutes.fault)?
						respond!(session, 200, results)
					}
				}
			}
		}
	}

	item_of : Move.Old, U64 -> Closure.Repo
	item_of = |old, state_at| { name: old.name, state: old.state, successor: old.successor, state_at }

	respond! : D1.Session, U16, List(D1.Result) => Try(Response, IngestRoutes.Error)
	respond! = |session, status, results| {
		last = results.last().map_err(|_| Fault("the batch gave no result"))?
		rows : Try(List(MoveRoutes.AnswerSql), _)
		rows = last.all()
		a = match rows.map_err(IngestRoutes.fault)? {
			[r, ..] => r
			[] => return Err(Fault("the row is missing after the write batch"))
		}
		item : Closure.Repo
		item = {
			name: a.name,
			state: state_of(a.state)?,
			successor: match a.successor {
				Ok(s) => Ok(s)
				Err(Missing) => Err(None)
			},
			state_at: a.state_at,
		}
		json_response!(session, status, Closure.encode_repo(item))
	}

	json_response! : D1.Session, U16, Str => Try(Response, IngestRoutes.Error)
	json_response! = |session, status, text| {
		base = Response.from_bytes(status, "application/json", text.to_utf8()).with_header("cache-control", "no-store")
		Ok(
			match session.bookmark!() {
				Ok(bookmark) => base.with_header("talon-bookmark", bookmark)
				Err(NotFound) => base
			},
		)
	}

	too_large : Response
	too_large = {
		problem = Problem.new(TooLarge, "the body of the move request is larger than its limit of ${IngestRoutes.body_limit.to_str()}")
		Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, { field: "body", limit: IngestRoutes.body_limit }).to_utf8())
	}
}
