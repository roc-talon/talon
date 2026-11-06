-- R-WH4: the example case of the W1 runner. A STRICT table, a trigger with RAISE and a CASE ... END inside a statement, and a query.
CREATE TABLE example (id INTEGER PRIMARY KEY, amount INTEGER NOT NULL, label TEXT) STRICT;

CREATE TRIGGER example_positive BEFORE INSERT ON example
WHEN NEW.amount < 0
BEGIN
  SELECT RAISE(ABORT, 'negative amount');
END;
