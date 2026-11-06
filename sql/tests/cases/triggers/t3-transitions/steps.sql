-- Results: 0 pass, 1 fail, 2 hang, 3 crash (R-IK7). A1 has a bot row on each swept nightly, so each sweep is complete (bound 15).
-- Nightly 100: A6 hangs and A7 crashes. A9 has an author row only.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 100, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,0],[2,0],[3,0],[4,1],[5,0],[6,2],[7,3]]');
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 100, 0, 1, json_extract(value, '$[1]'), NULL, 1790000000000, 1 FROM json_each('[[9,0]]');
-- params: [100, 0, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- Nightly 300 is next to 100. A5 crashes, A8 is new (no row on 100). A9: an author row with another result.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 300, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,0],[2,1],[3,0],[4,1],[5,3],[6,0],[7,0],[8,0]]');
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 300, 0, 1, json_extract(value, '$[1]'), NULL, 1790000000000, 1 FROM json_each('[[9,1]]');
-- T0: the row (300, 0): previous 100, compared 4 (A1 to A4), changed 1 (A2). A hang, a crash, a missing row and an author row are not compared.
-- params: [300, 0, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- Nightly 500 is swept before 400. Its neighbour 400 is not swept, so it writes no row.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 500, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,1],[2,1],[3,1],[4,0],[5,2],[6,0],[7,0],[8,1]]');
-- params: [500, 0, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- Nightly 200 is next to 300 in the order of published_at (the ids give 100, 200, 300). Its row is (200, 0): previous 300.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 200, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,0],[2,1],[3,1],[4,0],[5,0],[6,0],[7,0],[8,0]]');
-- params: [200, 0, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- T4: the sweep of 400 writes both rows: (400, 0) with previous 200, and (500, 0) with previous 400 (500 and 400 have one published_at: the smaller id is first).
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 400, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,0],[2,1],[3,1],[4,0],[5,0],[6,0],[7,0],[8,1]]');
-- params: [400, 0, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- TC7: the nightly 268435461 is of the date 1 and has t 8000. The nightly 536870919 is of the date 2 and has t 7000. The order is by the date, so 536870919 comes after 268435461.
-- The row (268435461, 0) has previous 500 (the last of the date 0). Then the row (536870919, 0) has previous 268435461.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 268435461, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,0],[2,1],[3,1],[4,0],[5,0],[6,0],[7,0],[8,1]]');
-- params: [268435461, 0, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 536870919, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,0],[2,1],[3,0],[4,0],[5,0],[6,0],[7,0],[8,1]]');
-- params: [536870919, 0, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- A nightly with no toolchains row (R-MX16): it can be swept (A1 is the newest of its group), but it has no place in the order, so no transition row.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 999, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,0],[2,0]]');
-- params: [999, 0, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- Another target (code 9) has its own sweeps and its own transition. The rows of target 0 do not count in it.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 100, 9, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,0],[2,0]]');
-- params: [100, 9, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 300, 9, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[1,1],[2,0]]');
-- params: [300, 9, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- A bot row that comes later (a range search, R-MX12) changes no transition: A10 on 300 and 200, with different results.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 300, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[10,0]]');
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 200, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[10,1]]');
-- A sweep with the same bound changes nothing. (200, 0) stays at compared 7, changed 2.
-- params: [200, 0, 15]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- A raise of the bound is an UPDATE, and the rows of 400 are computed again: A10 and A11 on 400. Bound 16 needs a bot row for A11 (release 2).
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT json_extract(value, '$[0]'), 400, 0, 0, json_extract(value, '$[1]'), NULL, 1790000000000, NULL FROM json_each('[[10,1],[11,0]]');
-- params: [400, 0, 16]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
