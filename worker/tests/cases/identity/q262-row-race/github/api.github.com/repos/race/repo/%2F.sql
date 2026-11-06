UPDATE repos SET repository_owner_id = 11 WHERE repo = 5128146954204977808;
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (5128146954204977808, 2, 1, 1, 1, 10, 11, NULL, NULL, 1767225630000);
