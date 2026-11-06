-- batch: 2
INSERT INTO example (id, amount) VALUES (1, 5);
-- params: [2, 7]
INSERT INTO example (id, amount) VALUES (?, ?);
-- batch: 3
-- expect-error: negative amount
INSERT INTO example (id, amount) VALUES (3, 1);
INSERT INTO example (id, amount) VALUES (4, -1);
INSERT INTO example (id, amount) VALUES (5, 1);
INSERT INTO example (id, amount) VALUES (6, 6);
