-- R-RE21, R-IK7: UNIQUE name and the key code.
-- expect-error: UNIQUE constraint failed: targets.name
INSERT INTO targets (target, name) VALUES (99, 'x64mac');
-- expect-error: UNIQUE constraint failed: targets.target
INSERT INTO targets (target, name) VALUES (1, 'newname');
-- expect-error: NOT NULL constraint failed: targets.name
INSERT INTO targets (target, name) VALUES (98, NULL);
-- expect-error: datatype mismatch
INSERT INTO targets (target, name) VALUES ('abc', 'another');
-- R-IK7 row 36 and up: a new target gets the next code.
INSERT INTO targets (target, name) VALUES (36, 'riscv64');
