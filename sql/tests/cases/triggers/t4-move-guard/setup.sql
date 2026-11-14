-- Rows: 1 = the old name (active, no successor, state_at 1000), 2 and 3 = active successors, 4 = a missing successor.
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (1, 100, 10, 0, NULL, 1000, 1000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (2, 200, 10, 0, NULL, 1000, 1000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (3, 300, 10, 0, NULL, 1000, 1000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (4, 400, 10, 1, NULL, 1000, 1000);
