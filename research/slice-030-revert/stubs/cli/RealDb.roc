import lib.Db

## The `compat.db` calls of the real `Fx` on basic-cli `Sqlite` (slice 030, R-CC8, R-TF1 to R-TF3). The SQL is here, the decisions are in `Db` and `Facts` (TW4).
## The docs of `Fx.db_query!` and `Fx.db_write!` have the steps. The spike `research/compat-db/RESULTS.md` has what `Sqlite` can do:
## one connection for each path is kept for the process, so `PRAGMA busy_timeout` and a transaction of several calls hold; a statement with many `VALUES` rows is one write.
RealDb :: [].{

	query! : Db.Open, Db.Query => Try(Db.Answer, Db.Err)
	query! = |_open, _query| crash "todo"

	write! : Db.Open, Db.Write => Try({}, Db.Err)
	write! = |_open, _write| crash "todo"
}
