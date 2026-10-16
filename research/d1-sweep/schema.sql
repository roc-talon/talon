-- Prototype schema: only the columns that the sweep check (R-MX4, R-RE8) and the publish batch (Q27) use.
-- Statements are split on lines that hold only ";;" (D1 `exec` splits on newlines, so the test prepares each one).

CREATE TABLE log (idx INTEGER PRIMARY KEY, grp TEXT NOT NULL, version TEXT NOT NULL, hash TEXT NOT NULL)
;;
CREATE TABLE artifacts (hash TEXT PRIMARY KEY, kind TEXT NOT NULL)
;;
CREATE TABLE releases (grp TEXT NOT NULL, version TEXT NOT NULL, hash TEXT NOT NULL, log_index INTEGER NOT NULL,
  PRIMARY KEY (grp, version))
;;
CREATE INDEX releases_hash ON releases (hash, log_index)
;;
CREATE TABLE compat (hash TEXT NOT NULL, nightly TEXT NOT NULL, target TEXT NOT NULL, source TEXT NOT NULL,
  result TEXT NOT NULL, PRIMARY KEY (hash, nightly, target, source))
;;
CREATE TABLE sweeps (nightly TEXT NOT NULL, target TEXT NOT NULL, upto_log_index INTEGER NOT NULL,
  PRIMARY KEY (nightly, target))
;;
-- R-MX4 guard: a sweeps row can exist only when it is complete. It fires for the INSERT part of each upsert.
CREATE TRIGGER sweeps_guard_insert BEFORE INSERT ON sweeps
BEGIN
  SELECT RAISE(ABORT, 'sweep-bound') WHERE NEW.upto_log_index > (SELECT COALESCE(MAX(idx), 0) FROM log);
  SELECT RAISE(ABORT, 'sweep-incomplete') WHERE EXISTS (
    SELECT 1 FROM releases r
    WHERE r.log_index <= NEW.upto_log_index
      AND NOT EXISTS (SELECT 1 FROM compat c
        WHERE c.hash = r.hash AND c.nightly = NEW.nightly AND c.target = NEW.target AND c.source = 'bot'));
END
;;
-- The same guard for an UPDATE that a later code path could write without the upsert.
CREATE TRIGGER sweeps_guard_update BEFORE UPDATE ON sweeps
BEGIN
  SELECT RAISE(ABORT, 'sweep-smaller') WHERE NEW.upto_log_index < OLD.upto_log_index;
  SELECT RAISE(ABORT, 'sweep-bound') WHERE NEW.upto_log_index > (SELECT COALESCE(MAX(idx), 0) FROM log);
  SELECT RAISE(ABORT, 'sweep-incomplete') WHERE EXISTS (
    SELECT 1 FROM releases r
    WHERE r.log_index <= NEW.upto_log_index
      AND NOT EXISTS (SELECT 1 FROM compat c
        WHERE c.hash = r.hash AND c.nightly = NEW.nightly AND c.target = NEW.target AND c.source = 'bot'));
END
;;
-- Q27: the label keeps its first hash. Same label and same hash is a no-op (INSERT OR IGNORE).
CREATE TRIGGER releases_label_conflict BEFORE INSERT ON releases
BEGIN
  SELECT RAISE(ABORT, 'label-conflict') WHERE EXISTS (
    SELECT 1 FROM releases WHERE grp = NEW.grp AND version = NEW.version AND hash <> NEW.hash);
END
;;
-- Q27: a log leaf for each inserted release, and only for an inserted release.
CREATE TRIGGER releases_leaf AFTER INSERT ON releases
BEGIN
  INSERT INTO log (idx, grp, version, hash) VALUES (NEW.log_index, NEW.grp, NEW.version, NEW.hash);
END
