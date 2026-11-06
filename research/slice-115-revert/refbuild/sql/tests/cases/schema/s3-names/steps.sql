-- R-RE22, R-IK3, R-IK8, R-IK2: names (id, kind, value). Cases K4, K5, K12 (the value type) of research/d1-int-keys/ on the real table.
-- A 64-bit id is bound as decimal text (R-IK2). The ids below are outside the 53-bit range.
-- params: ["-5806314255104343322"]
INSERT INTO names (id, kind, value) VALUES (?, 1, x'0707070707070707070707070707070707070707070707070707070707070707');
-- params: ["-2687166099708853831", "github.com/roc-lang/unicode/releases/download/{v}/"]
INSERT INTO names (id, kind, value) VALUES (?, 2, ?);
-- params: ["4611686018427387905", "roc-lang/unicode"]
INSERT INTO names (id, kind, value) VALUES (?, 3, ?);
-- K4: the same name again with ON CONFLICT (kind, value) DO NOTHING is no error and no new row.
-- params: ["-2687166099708853831", "github.com/roc-lang/unicode/releases/download/{v}/"]
INSERT INTO names (id, kind, value) VALUES (?, 2, ?) ON CONFLICT (kind, value) DO NOTHING;
-- The same (kind, value) under another id is skipped by the same conflict target (the id of a name is a function of the name,
-- so the Worker never does this; the unique index is what makes the target valid).
-- params: ["123", "github.com/roc-lang/unicode/releases/download/{v}/"]
INSERT INTO names (id, kind, value) VALUES (?, 2, ?) ON CONFLICT (kind, value) DO NOTHING;
-- Without the conflict clause the same (kind, value) is an error (UNIQUE (kind, value), R-IK3).
-- expect-error: UNIQUE constraint failed: names.kind, names.value
-- params: ["124", "roc-lang/unicode"]
INSERT INTO names (id, kind, value) VALUES (?, 3, ?);
-- K5: a new name with the id of another name is a PRIMARY KEY error, even with the conflict target (kind, value). It stops the batch.
-- expect-error: UNIQUE constraint failed: names.id
-- params: ["-2687166099708853831", "github.com/attacker/x/releases/download/{v}/"]
INSERT INTO names (id, kind, value) VALUES (?, 2, ?) ON CONFLICT (kind, value) DO NOTHING;
-- The kind byte keeps the kinds apart: one text under kind 3 is another name.
-- params: ["6148914691236517205", "github.com/roc-lang/unicode/releases/download/{v}/"]
INSERT INTO names (id, kind, value) VALUES (?, 3, ?);
-- R-IK8, K12: the CHECK of the value type. Kind 1 is a blob. Kinds 2 and 3 are text. An ANY column would take an integer or a real: the CHECK stops it.
-- expect-error: CHECK constraint failed
INSERT INTO names (id, kind, value) VALUES (11, 1, 'not-bytes');
-- expect-error: CHECK constraint failed
INSERT INTO names (id, kind, value) VALUES (12, 2, x'00ff');
-- expect-error: CHECK constraint failed
INSERT INTO names (id, kind, value) VALUES (13, 3, x'00ff');
-- expect-error: CHECK constraint failed
INSERT INTO names (id, kind, value) VALUES (14, 2, 5);
-- expect-error: CHECK constraint failed
INSERT INTO names (id, kind, value) VALUES (15, 3, 1.5);
-- expect-error: CHECK constraint failed
INSERT INTO names (id, kind, value) VALUES (16, 1, 5);
-- Proposal 4 of the slice file: kind is 1, 2 or 3 (R-IK2 has no other kind; the prototype names table has this CHECK).
-- expect-error: CHECK constraint failed
INSERT INTO names (id, kind, value) VALUES (17, 4, 'x');
-- expect-error: CHECK constraint failed
INSERT INTO names (id, kind, value) VALUES (18, 0, 'x');
-- expect-error: NOT NULL constraint failed: names.value
INSERT INTO names (id, kind, value) VALUES (19, 2, NULL);
-- expect-error: NOT NULL constraint failed: names.kind
INSERT INTO names (id, kind, value) VALUES (20, NULL, 'x');
-- R-IK8, K12: STRICT. A text id that is not an integer, and an integer text out of the i64 range, are errors (on a rowid key: datatype mismatch).
-- expect-error: datatype mismatch
INSERT INTO names (id, kind, value) VALUES ('abc', 2, 'y');
-- expect-error: datatype mismatch
INSERT INTO names (id, kind, value) VALUES ('9223372036854775808', 2, 'z');
