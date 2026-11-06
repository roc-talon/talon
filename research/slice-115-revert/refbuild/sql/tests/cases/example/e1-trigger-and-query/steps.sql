INSERT INTO example (id, amount, label) VALUES (1, 5, 'five');
-- params: [2, 7, "seven; with a semicolon"]
INSERT INTO example (id, amount, label) VALUES (?, ?, ?);
-- expect-error: negative amount
INSERT INTO example (id, amount, label) VALUES (3, -1, 'bad');
INSERT INTO example (id, amount, label)
SELECT value, 9, CASE WHEN value > 5 THEN 'big' ELSE 'small' END FROM json_each('[4, 10]');
