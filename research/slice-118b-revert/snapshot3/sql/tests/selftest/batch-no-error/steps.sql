-- batch: 2
-- expect-error: negative amount
INSERT INTO example (id, amount) VALUES (1, 5);
INSERT INTO example (id, amount) VALUES (2, 7);
