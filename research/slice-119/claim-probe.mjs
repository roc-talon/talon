// Probe (slice 119): does a SQLite UPDATE ... RETURNING take correlated subqueries of other tables, and what order does it give?
import { DatabaseSync } from 'node:sqlite';
const db = new DatabaseSync(':memory:');
db.exec(`CREATE TABLE repo_checks (repo INTEGER PRIMARY KEY, etag TEXT, checked_at INTEGER, next_check_at INTEGER NOT NULL, fail_count INTEGER NOT NULL, app_installed INTEGER NOT NULL) STRICT;
CREATE TABLE repos (repo INTEGER PRIMARY KEY, repository_id INTEGER NOT NULL, repository_owner_id INTEGER NOT NULL, state INTEGER NOT NULL, successor INTEGER, state_at INTEGER NOT NULL, time INTEGER NOT NULL) STRICT;
CREATE TABLE names (id INTEGER PRIMARY KEY, kind INTEGER NOT NULL, value ANY NOT NULL) STRICT;
INSERT INTO names VALUES (3,3,'c/c'),(1,3,'a/a'),(2,3,'b/b'),(4,3,'d/d');
INSERT INTO repos VALUES (1,100,10,0,NULL,0,0),(2,200,20,0,NULL,0,0),(3,300,30,0,NULL,0,0),(4,400,40,0,NULL,0,0);
INSERT INTO repo_checks VALUES (3,NULL,NULL,10,0,0),(1,'"e1"',5,30,2,1),(2,NULL,NULL,20,0,0),(4,NULL,NULL,99,0,0);`);
const sql = `UPDATE repo_checks SET next_check_at = ?1 + 900000 WHERE repo IN (SELECT repo FROM repo_checks WHERE next_check_at <= ?1 ORDER BY next_check_at, repo LIMIT ?2)
RETURNING CAST(repo AS TEXT) AS repo, etag, fail_count, app_installed, (SELECT value FROM names WHERE id = repo_checks.repo) AS name, (SELECT CAST(repository_id AS TEXT) FROM repos WHERE repos.repo = repo_checks.repo) AS repository_id`;
console.log(db.prepare(sql).all(50, 500));
console.log(db.prepare(sql).all(50, 500));
