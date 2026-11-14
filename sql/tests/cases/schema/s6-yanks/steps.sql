-- R-RE10: a yank by an author (claims, reason), the unyank of the same release by an operator (no claims, no reason), and a yank of another release.
INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (7, 1, 0, 0, '{"run_id":"1"}', 'broken', 1790000000000);
INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (7, 2, 1, 1, NULL, NULL, 1790000000001);
INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (8, 1, 0, 1, NULL, NULL, 1790000000002);
-- R-RE10: (release, seq) is the key.
-- expect-error: UNIQUE constraint failed: yanks.release, yanks.seq
INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (7, 2, 0, 0, NULL, NULL, 1790000000003);
-- R-IK7: action is 0 or 1.
-- expect-error: CHECK constraint failed
INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (9, 1, 2, 0, NULL, NULL, 1790000000004);
-- R-IK7: by is 0 or 1.
-- expect-error: CHECK constraint failed
INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (9, 1, 0, 2, NULL, NULL, 1790000000005);
-- A key column and the closed columns are NOT NULL.
-- expect-error: NOT NULL constraint failed: yanks.seq
INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (9, NULL, 0, 0, NULL, NULL, 1790000000006);
-- expect-error: NOT NULL constraint failed: yanks.time
INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (9, 1, 0, 0, NULL, NULL, NULL);
-- R-RE26, R-IK8: STRICT. A time that is not an integer is an error.
-- expect-error: cannot store TEXT value in INTEGER column yanks.time
INSERT INTO yanks (release, seq, action, by, claims, reason, time) VALUES (9, 1, 0, 0, NULL, NULL, 'abc');
