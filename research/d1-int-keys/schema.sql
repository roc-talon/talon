-- Prototype schema for integer keys (Registry 5.1): the name table and the columns that the cases use.
-- Statements are split on lines that hold only ";;" (the test prepares each one).

-- R-IK3: one row for each name that a row refers to. id is a function of (kind, value) (R-IK2).
CREATE TABLE names (id INTEGER PRIMARY KEY, kind INTEGER NOT NULL CHECK (kind IN (1, 2, 3)), value BLOB NOT NULL,
  UNIQUE (kind, value))
;;
CREATE TABLE releases (log_index INTEGER PRIMARY KEY, form INTEGER NOT NULL REFERENCES names (id),
  major INTEGER NOT NULL CHECK (major BETWEEN 0 AND 4294967295),
  minor INTEGER NOT NULL CHECK (minor BETWEEN 0 AND 4294967295),
  patch INTEGER NOT NULL CHECK (patch BETWEEN 0 AND 4294967295),
  artifact INTEGER NOT NULL REFERENCES names (id), UNIQUE (form, major, minor, patch))
;;
CREATE TABLE ids (id INTEGER PRIMARY KEY)
;;
-- R-IK7: a table with a composite key has no rowid. The key is the table (size.mjs: 31 bytes a row in place of 61).
CREATE TABLE compat (artifact INTEGER NOT NULL, nightly INTEGER NOT NULL, target INTEGER NOT NULL,
  source INTEGER NOT NULL CHECK (source IN (0, 1)), result INTEGER NOT NULL CHECK (result IN (0, 1, 2, 3)),
  PRIMARY KEY (artifact, nightly, target, source)) WITHOUT ROWID
;;
-- R-IK8: STRICT. A text parameter that is not an exact integer is an error, not a TEXT or REAL value in an id column.
CREATE TABLE strict_ids (id INTEGER PRIMARY KEY, kind INTEGER NOT NULL, value ANY NOT NULL,
  CHECK (typeof(value) = CASE kind WHEN 1 THEN 'blob' ELSE 'text' END)) STRICT
;;
CREATE TABLE strict_refs (a INTEGER NOT NULL, b INTEGER NOT NULL, PRIMARY KEY (a, b)) STRICT, WITHOUT ROWID
;;
CREATE TABLE loose_refs (a INTEGER NOT NULL, b INTEGER NOT NULL, PRIMARY KEY (a, b)) WITHOUT ROWID
