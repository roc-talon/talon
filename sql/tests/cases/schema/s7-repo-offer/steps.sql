-- R-RE11: a row with no offer, a row with an offer (a 64-bit id), and the offer cleared again.
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (1, 100, 10, 0, NULL, 1767000000000, 1767000000000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time, offer) VALUES (2, 200, 20, 0, NULL, 1767000000000, 1767000000000, -3091616050638104172);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time, offer) VALUES (3, 300, 30, 0, NULL, 1767000000000, 1767000000000, 1867293425818598420);
UPDATE repos SET offer = NULL WHERE repo = 3;
-- R-IK8: STRICT. A text for the offer is an error.
-- expect-error: cannot store TEXT value in INTEGER column repos.offer
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time, offer) VALUES (4, 400, 40, 0, NULL, 1767000000000, 1767000000000, 'acme/lib');
-- R-RE15: the event of an offer has the action 8 and the offered name as its successor.
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (1, 1, 8, 100, 100, 10, 10, -3091616050638104172, NULL, 1767000000001);
