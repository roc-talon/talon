-- A scratch table for the results of the compare forms (the runner reads rows only after the last step, and without parameters).
CREATE TABLE probe (label TEXT NOT NULL, val TEXT) STRICT;
