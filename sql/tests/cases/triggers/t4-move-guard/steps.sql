-- Both moves read the old row when it was: state_at 1000, successor NULL.
-- Move A (first writer) wins: state_at is still 1000, no successor: 1 row changes, 1 event (seq 1, action 6, successor 2).
-- batch: 2
-- params: [1, 2, 2000, 1000, null]
UPDATE repos SET state = 2, successor = ?2, state_at = ?3 WHERE repo = ?1 AND state_at = ?4 AND successor IS ?5 AND EXISTS (SELECT 1 FROM repos s WHERE s.repo = ?2 AND s.state = 0);
-- params: [1, 6, 100, 100, 10, 10, 2, 2000, null]
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), ?2, ?3, ?4, ?5, ?6, ?7, ?9, ?8 WHERE changes() > 0;
-- Move B (late writer) read the same old row: state_at is now 2000 and the successor is 2, so the guard fails: 0 rows change, no event.
-- batch: 2
-- params: [1, 3, 2500, 1000, null]
UPDATE repos SET state = 2, successor = ?2, state_at = ?3 WHERE repo = ?1 AND state_at = ?4 AND successor IS ?5 AND EXISTS (SELECT 1 FROM repos s WHERE s.repo = ?2 AND s.state = 0);
-- params: [1, 6, 100, 100, 10, 10, 3, 2500, null]
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), ?2, ?3, ?4, ?5, ?6, ?7, ?9, ?8 WHERE changes() > 0;
-- Move C reads the row after A, but the successor row 4 is missing (state 1): the EXISTS guard fails: 0 rows, no event. The row of name 3 is untouched.
-- batch: 2
-- params: [3, 4, 2600, 1000, null]
UPDATE repos SET state = 2, successor = ?2, state_at = ?3 WHERE repo = ?1 AND state_at = ?4 AND successor IS ?5 AND EXISTS (SELECT 1 FROM repos s WHERE s.repo = ?2 AND s.state = 0);
-- params: [3, 6, 300, 300, 10, 10, 4, 2600, null]
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), ?2, ?3, ?4, ?5, ?6, ?7, ?9, ?8 WHERE changes() > 0;
-- Move D read successor 2 and state_at 2000, and changes it to 3: the guard passes (same values), 1 row, 1 event (seq 2).
-- batch: 2
-- params: [1, 3, 2700, 2000, 2]
UPDATE repos SET state = 2, successor = ?2, state_at = ?3 WHERE repo = ?1 AND state_at = ?4 AND successor IS ?5 AND EXISTS (SELECT 1 FROM repos s WHERE s.repo = ?2 AND s.state = 0);
-- params: [1, 6, 100, 100, 10, 10, 3, 2700, null]
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), ?2, ?3, ?4, ?5, ?6, ?7, ?9, ?8 WHERE changes() > 0;
