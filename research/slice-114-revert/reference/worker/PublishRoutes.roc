## Private reference of slice 114 (not for the code agent, TW18).
import pf.Request
import pf.Response
import pf.Sql
import pf.Time
import records.Release
import lib.Compat
import lib.Ingest
import lib.Problem
import lib.Publish
import lib.Reads
import Auth
import IngestRoutes

PublishRoutes :: [].{

	post! : Request => Try(Response, IngestRoutes.Error)
	post! = |req| {
		bytes = match req.bytes_with!({ max_bytes: IngestRoutes.body_limit }) {
			Ok(b) => b
			Err(TooLarge) => return Ok(too_large)
			Err(BodyErr(_)) => []
		}
		post = match Publish.parse_body(bytes) {
			Ok(p) => p
			Err(Bad(problem)) => return Err(Refuse(problem))
			Err(TooLarge(problem, extra)) => return Ok(Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, extra).to_utf8()))
		}
		target = Ingest.parse_url(post.url).map_err(|p| Refuse(p))?
		claims = Auth.publish!(req, { owner_repo: "${target.owner}/${target.repo}", tag: target.tag }).map_err(|p| Refuse(p))?
		seen = Publish.claims_ids(claims).map_err(|p| Refuse(p))?
		claims_text = Ok(Publish.claims_json(claims))
		session = IngestRoutes.db.with_session!(Primary).map_err(IngestRoutes.fault)?
		repo_id = Reads.repo_id(target.owner, target.repo)
		first = session.batch!([Sql.stmt(IngestRoutes.label_sql_of(0), IngestRoutes.label_params(target)), Sql.stmt(IngestRoutes.repo_sql, [repo_id])]).map_err(IngestRoutes.fault)?
		rows = IngestRoutes.label_rows(first.first().map_err(|_| Fault("the pre-read gave no result"))?.all())?
		old = IngestRoutes.old_row(first, repo_id, 1)?
		github_repo = { repo: { id: seen.repository_id, owner_id: seen.owner_id, public: Bool.True }, full_name: claims.repository ?? target.name }
		now = Time.now_ms!()
		identity = match IngestRoutes.identity!(target, repo_id, github_repo, old, now, claims_text)? {
			Stop(response) => return Ok(response)
			Go(g) => g
		}
		extra = |at| facts_stmts(target, post.facts, at)
		match Publish.after_read(target, rows, { facts: !post.facts.is_empty(), events: identity.events }).map_err(IngestRoutes.bad_row)? {
			Conflict(problem) => Err(Refuse(problem))
			Answer(release) => IngestRoutes.answer!(session, 200, release)
			Write(_log_index) => {
				provenance = Sql.stmt(Publish.provenance_sql(), (Reads.form_id(target.form), target.column.version, target.column.version_text, Publish.claims_json(claims), now))
				stmts = [provenance].concat(identity.stmts).concat(extra(now)).append(Sql.stmt(IngestRoutes.label_sql_of(0), IngestRoutes.label_params(target)))
				results = session.batch!(stmts).map_err(IngestRoutes.fault)?
				IngestRoutes.dropping(IngestRoutes.answer!(session, 200, IngestRoutes.last_release(results)?), req, target, 200)
			}
			Index => {
				ctx = { github_repo, via: 0, claims: claims_text, extra, candidate: Publish.candidate, no_release: Publish.no_release }
				IngestRoutes.dropping(IngestRoutes.index!(session, target, repo_id, old, ctx), req, target, 201)
			}
		}
	}

	## The author facts (R-PU5): one statement with the rows of all facts, after the release statement of the batch.
	facts_stmts : Ingest.Target, List(Publish.Fact), U64 -> List(Sql.Stmt)
	facts_stmts = |target, facts, now| if facts.is_empty() [] else {
		artifact = Reads.artifact_id(target.hash) ?? 0
		[Sql.stmt(Publish.facts_sql(), (Compat.rows_json(Publish.fact_rows(facts, artifact)), now, Reads.form_id(target.form), target.column.version, target.column.version_text))]
	}

	too_large : Response
	too_large = {
		problem = Problem.new(TooLarge, "the body of the publish request is larger than its limit of ${IngestRoutes.body_limit.to_str()}")
		Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, { field: "body", limit: IngestRoutes.body_limit }).to_utf8())
	}
}
