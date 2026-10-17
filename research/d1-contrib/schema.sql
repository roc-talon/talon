-- Prototype schema for user hints (Registry 6.1, R-CT3 to R-CT13): only the columns that the write, the login, the
-- tracker, the daily limit and the delete use. Hashes and nightlies are text here; the registry uses integer ids (5.1).
-- A contributor is one 64-bit integer (R-CT3): a machine is negative (an HMAC with the top bit set), a GitHub account is
-- positive (the GitHub user id). The test replaces :CAP with the daily limit (R-CT13).
-- Statements are split on lines that hold only ";;" (D1 `exec` splits on newlines, so the test prepares each one).

CREATE TABLE compat (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, source TEXT NOT NULL,
  result TEXT NOT NULL, time INTEGER NOT NULL, PRIMARY KEY (hash, nightly, target, source)) STRICT
;;
CREATE TABLE compat_hints (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, talon_version TEXT NOT NULL,
  pass_count INTEGER NOT NULL, fail_count INTEGER NOT NULL, crash_count INTEGER NOT NULL,
  first_time INTEGER NOT NULL, last_time INTEGER NOT NULL, PRIMARY KEY (hash, nightly, target, talon_version)) STRICT
;;
CREATE TABLE contributions (contributor INTEGER NOT NULL, hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL,
  result TEXT NOT NULL CHECK (result IN ('pass', 'fail', 'crash')), talon_version TEXT NOT NULL, time INTEGER NOT NULL,
  PRIMARY KEY (contributor, hash, nightly, target)) STRICT, WITHOUT ROWID
;;
-- The tracker reads the other contributions of a pair (R-CT10 `first`).
CREATE INDEX contributions_pair ON contributions (hash, nightly, target, time)
;;
-- The index of authors: one row for each GitHub account that logged in (R-CT8).
CREATE TABLE contributors (contributor INTEGER PRIMARY KEY CHECK (contributor > 0), login TEXT NOT NULL,
  tokens_after INTEGER NOT NULL, first_time INTEGER NOT NULL, last_time INTEGER NOT NULL) STRICT
;;
-- A machine that logged in, and its account (R-CT8 row 3).
CREATE TABLE links (machine INTEGER PRIMARY KEY CHECK (machine < 0), contributor INTEGER NOT NULL, time INTEGER NOT NULL) STRICT
;;
CREATE TABLE hint_days (day INTEGER PRIMARY KEY, counted INTEGER NOT NULL) STRICT
;;
-- The compilers and their release time (R-RE4). The age of a pair is the age of its compiler (R-CT15).
CREATE TABLE toolchains (nightly TEXT PRIMARY KEY, published_at INTEGER NOT NULL) STRICT
;;
-- The totals of the rows that the trim removed (R-CT15), one row for each contributor.
CREATE TABLE contributor_totals (contributor INTEGER PRIMARY KEY, counted INTEGER NOT NULL, first INTEGER NOT NULL,
  agreed INTEGER NOT NULL, disagreed INTEGER NOT NULL, unconfirmed INTEGER NOT NULL) STRICT
;;
-- The trim selects the rows of one nightly.
CREATE INDEX contributions_nightly ON contributions (nightly)
;;
-- R-RE13 row 3: a hint counts once for each contributor and pair. A row that ON CONFLICT DO NOTHING skips fires no
-- AFTER INSERT trigger. R-CT13: the daily limit of all user hints stops the whole batch.
CREATE TRIGGER contributions_count AFTER INSERT ON contributions
BEGIN
  INSERT INTO compat_hints (hash, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time)
  VALUES (NEW.hash, NEW.nightly, NEW.target, NEW.talon_version,
    NEW.result = 'pass', NEW.result = 'fail', NEW.result = 'crash', NEW.time, NEW.time)
  ON CONFLICT (hash, nightly, target, talon_version) DO UPDATE SET
    pass_count = pass_count + excluded.pass_count, fail_count = fail_count + excluded.fail_count,
    crash_count = crash_count + excluded.crash_count, last_time = excluded.last_time;
  INSERT INTO hint_days (day, counted) VALUES (NEW.time / 86400, 1)
  ON CONFLICT (day) DO UPDATE SET counted = counted + 1;
  SELECT RAISE(ABORT, 'hint-quota') WHERE (SELECT counted FROM hint_days WHERE day = NEW.time / 86400) > :CAP;
END
