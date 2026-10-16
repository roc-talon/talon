-- Prototype schema for user hints (Registry 6.1, R-CT4 to R-CT7): only the columns that the write, the fold and the delete use.
-- Statements are split on lines that hold only ";;" (D1 `exec` splits on newlines, so the test prepares each one).

CREATE TABLE compat (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, source TEXT NOT NULL,
  result TEXT NOT NULL, PRIMARY KEY (hash, nightly, target, source))
;;
CREATE TABLE compat_hints (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, talon_version TEXT NOT NULL,
  pass_count INTEGER NOT NULL, fail_count INTEGER NOT NULL, crash_count INTEGER NOT NULL,
  first_time INTEGER NOT NULL, last_time INTEGER NOT NULL, PRIMARY KEY (hash, nightly, target, talon_version))
;;
CREATE TABLE contributors (contributor TEXT PRIMARY KEY, counted INTEGER NOT NULL, first INTEGER NOT NULL,
  agreed INTEGER NOT NULL, disagreed INTEGER NOT NULL, unconfirmed INTEGER NOT NULL,
  first_time INTEGER NOT NULL, last_time INTEGER NOT NULL, account TEXT)
;;
CREATE TABLE contributions (contributor TEXT NOT NULL, hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL,
  result TEXT NOT NULL CHECK (result IN ('pass', 'fail', 'crash')), talon_version TEXT NOT NULL, time INTEGER NOT NULL,
  PRIMARY KEY (contributor, hash, nightly, target))
;;
CREATE TABLE accounts (github_id TEXT PRIMARY KEY, login TEXT NOT NULL)
;;
-- R-RE13 row 3: a hint counts once for each contributor while its pending row exists.
-- A row that ON CONFLICT DO NOTHING skips fires no AFTER INSERT trigger.
CREATE TRIGGER contributions_count AFTER INSERT ON contributions
BEGIN
  INSERT INTO compat_hints (hash, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time)
  VALUES (NEW.hash, NEW.nightly, NEW.target, NEW.talon_version,
    NEW.result = 'pass', NEW.result = 'fail', NEW.result = 'crash', NEW.time, NEW.time)
  ON CONFLICT (hash, nightly, target, talon_version) DO UPDATE SET
    pass_count = pass_count + excluded.pass_count, fail_count = fail_count + excluded.fail_count,
    crash_count = crash_count + excluded.crash_count, last_time = excluded.last_time;
  UPDATE contributors SET counted = counted + 1 WHERE contributor = NEW.contributor;
END
