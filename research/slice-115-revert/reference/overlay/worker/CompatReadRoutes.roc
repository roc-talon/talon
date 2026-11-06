## REFERENCE (private) of worker/CompatReadRoutes.roc, slice 115b.
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import records.Id
import lib.CompatReads
import lib.ClosureQuery
import lib.Problem
import lib.Reads
import ReadRoutes
import "sql/compat/prefix.sql" as prefix_sql : Str
import "sql/compat/missing.sql" as missing_sql : Str
import "sql/compat/members.sql" as members_sql : Str
import "sql/compat/audit.sql" as audit_sql : Str
import "sql/compat/sweep_tag.sql" as sweep_tag_sql : Str
import "sql/compat/sweep_row.sql" as sweep_row_sql : Str
import "sql/compat/log_size.sql" as log_size_sql : Str
import "sql/compat/artifact_present.sql" as present_sql : Str
import "sql/compat/artifact_runs.sql" as runs_sql : Str
import "sql/compat/artifact_hints.sql" as hints_sql : Str

CompatReadRoutes :: [].{

	db = D1.binding("DB")

	sweep! : Request, Str => Try(Response, ReadRoutes.Error)
	sweep! = |req, tag| {
		CompatReads.parse_sweep_target(req.query("target")).map_err(|p| Refuse(p))?
		nightly = Id.nightly_id(tag).map_err(|_| Refuse(CompatReads.no_tag(tag)))?
		session = db.with_session!(Reads.session_of(req.header("talon-bookmark"))).map_err(|e| Fault(Str.inspect(e)))?
		params = (nightly, 0.I64, Sql.null)
		results = session.batch!(
			[
				Sql.stmt(sweep_tag_sql, [nightly]),
				Sql.stmt(sweep_row_sql, [nightly]),
				Sql.stmt(log_size_sql, Sql.none),
				Sql.stmt("${prefix_sql}\n${members_sql}", params),
				Sql.stmt("${prefix_sql}\n${missing_sql}", params),
			],
		).map_err(|e| Fault(Str.inspect(e)))?
		match results {
			[t, s, l, m, x] => {
				tags : List({ tag : Str })
				tags = t.all().map_err(|e| Fault(Str.inspect(e)))?
				stored = match tags {
					[first, ..] => first.tag
					[] => return Err(Refuse(CompatReads.no_tag(tag)))
				}
				sweeps : List(CompatReads.SweepRow)
				sweeps = s.all().map_err(|e| Fault(Str.inspect(e)))?
				sizes : List({ log_size : U64 })
				sizes = l.all().map_err(|e| Fault(Str.inspect(e)))?
				counts : List({ members : U64 })
				counts = m.all().map_err(|e| Fault(Str.inspect(e)))?
				hashes : List({ hash : List(U8) })
				hashes = x.all().map_err(|e| Fault(Str.inspect(e)))?
				missing = hashes.map_try(|r| Reads.base58_of_bytes(r.hash)).map_err(|e| match e { BadRow(text) => Fault(text) })?
				body = CompatReads.sweep_body({
					tag: stored,
					sweep: sweeps.first().map_err(|_| None),
					log_size: sizes.first().map_ok(|r| r.log_size) ?? 0,
					members: counts.first().map_ok(|r| r.members) ?? 0,
					missing,
				})
				Ok(Response.from_bytes(200, "application/json", body.to_utf8()).with_header("cache-control", CompatReads.sweep_cache_control))
			}
			_ => Err(Fault("sweep: the batch gave ${results.len().to_str()} results, not 5"))
		}
	}

	audit! : Request => Try(Response, ReadRoutes.Error)
	audit! = |req| {
		limit = CompatReads.parse_audit(req.query("audit")).map_err(|p| Refuse(p))?
		stmts = [Sql.stmt(audit_sql, [limit.to_i64_wrap()])]
		ReadRoutes.serve!(
			req,
			CompatReads.cache_control,
			stmts,
			|results, _now| match results {
				[r] => {
					rows : List(CompatReads.PairRow)
					rows = r.all().map_err(|e| Fault(Str.inspect(e)))?
					CompatReads.pairs_body(rows).map_err(|e| match e { BadRow(text) => Fault(text) })
				}
				_ => Err(Fault("audit: the batch gave ${results.len().to_str()} results, not 1"))
			},
		)
	}

	artifact_compat! : Request, Str => Try(Response, ReadRoutes.Error)
	artifact_compat! = |req, hash| match Reads.artifact_id(hash) {
		Err(BadHash) => Err(Refuse(Reads.no_artifact(hash)))
		Ok(id) => {
			stmts = [Sql.stmt(present_sql, [id]), Sql.stmt(runs_sql, [id]), Sql.stmt(hints_sql, [id])]
			ReadRoutes.serve!(
				req,
				CompatReads.cache_control,
				stmts,
				|results, _now| match results {
					[p, r, h] => {
						present : List({ present : I64 })
						present = p.all().map_err(|e| Fault(Str.inspect(e)))?
						if present.is_empty() {
							return Err(Refuse(Reads.no_artifact(hash)))
						}
						runs : List(ClosureQuery.RunRow)
						runs = r.all().map_err(|e| Fault(Str.inspect(e)))?
						hints : List(ClosureQuery.HintRow)
						hints = h.all().map_err(|e| Fault(Str.inspect(e)))?
						CompatReads.compat_body({ runs, hints }).map_err(|e| match e { BadRow(text) => Fault(text) })
					}
					_ => Err(Fault("artifact compat: the batch gave ${results.len().to_str()} results, not 3"))
				},
			)
		}
	}
}
