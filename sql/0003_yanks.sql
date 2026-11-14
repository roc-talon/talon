-- Registry schema, slice 246 (yank). Registry R-RE10, R-YK4, R-IK7, R-IK8, R-RE26. One statement for each semicolon. No PRAGMA, no BEGIN (as 0001).
-- R-RE10: one row for each yank and each unyank of a release. Rows are only added, never changed (R-RE6).
-- release: the log index of the release (R-IK6). seq: 1, 2, ... for each release. action: yank 0, unyank 1. by: author 0, operator 1 (R-IK7: the position in the list of R-RE10).
-- claims: the recorded claims of R-TP6 as TEXT for `author`, NULL for `operator`. reason: the reason of a yank (R-YK6), NULL for no reason and for an unyank. time: ms (R-RE26).
-- The table has a rowid: it has a large field (R-IK8, WITHOUT ROWID rule).
CREATE TABLE yanks (
  release INTEGER NOT NULL,
  seq INTEGER NOT NULL,
  action INTEGER NOT NULL CHECK (action IN (0, 1)),
  by INTEGER NOT NULL CHECK (by IN (0, 1)),
  claims TEXT,
  reason TEXT,
  time INTEGER NOT NULL,
  PRIMARY KEY (release, seq)
) STRICT;
