import pf.Worker
import pf.D1
import pf.Sql
import pf.Time
import pf.Log
import lib.Daily

DailyCrons :: [].{

	db = D1.binding("DB")

	no_params : List(U64)
	no_params = []

	run! : Worker.Scheduled => Try({}, [Fault(Str)])
	run! = |_s| {
		now = Time.now_ms!()
		match db.batch!([Sql.stmt(Daily.hints_sql(), no_params)]) {
			Ok(_) => {}
			Err(e) => Log.warn!("hint cleanup failed", { error: Str.inspect(e) })
		}
		match db.batch!([Sql.stmt(Daily.days_sql(), [now])]) {
			Ok(_) => {}
			Err(e) => Log.warn!("hint days cleanup failed", { error: Str.inspect(e) })
		}
		due : Try(List({ nightly : Str }), _)
		due = db.all!(Daily.due_sql(), [now])
		match due {
			Err(e) => Log.warn!("trim read failed", { error: Str.inspect(e) })
			Ok(rows) => for row in rows {
				stmts = Daily.trim_sqls().map(|sql| Sql.stmt(sql, [row.nightly]))
				match db.batch!(stmts) {
					Ok(_) => {}
					Err(e) => Log.warn!("trim failed", { nightly: row.nightly, error: Str.inspect(e) })
				}
			}
		}
		Ok({})
	}
}
