-- Registry schema, slice 247 (move). Registry R-RE11 (the column `offer`), R-TP15, R-RE15 (the action `offer`), R-IK2. One statement for each semicolon. No PRAGMA, no BEGIN (as 0001).
-- R-RE11, R-TP15: the offer of an owner who moves to another account. The id of the offered successor name (a `names` row of kind 3, as `successor`), or NULL for no offer.
-- It is an addition to the table `repos` of 0001: no row changes, and the column has no default (the schema has none, 0001).
ALTER TABLE repos ADD COLUMN offer INTEGER;
