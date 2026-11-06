-- R-WH4: the example case of the batch note. A batch is all or nothing on both backends (D1 `batch`, BEGIN ... COMMIT on SQLite).
CREATE TABLE example (id INTEGER PRIMARY KEY, amount INTEGER NOT NULL) STRICT;

CREATE TRIGGER example_positive BEFORE INSERT ON example
WHEN NEW.amount < 0
BEGIN
  SELECT RAISE(ABORT, 'negative amount');
END;
