-- Now is 1767225600000 = day 20454. All nightlies are new, so the trim finds nothing.
-- P1 (101,9400,0): 2 hints (2 talon_version) and a bot row: deleted. P2 (102,9400,0): only a smoke row: kept. P3 (103,9400,0): no compat row: kept (a bot row comes between run 1 and run 2).
-- P4 (101,9400,8): the bot row is for target 0: kept. P5 (104,9400,0): the bot row is for another nightly: kept.
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 101, 9400, 0, 0, 1, 1767225000000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (77, 101, 9400, 0, 1, 2, 1767225000000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 102, 9400, 0, 0, 1, 1767225000000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 103, 9400, 0, 0, 1, 1767225600000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 101, 9400, 8, 0, 1, 1767225000000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 104, 9400, 0, 0, 1, 1767225000000);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (101, 9400, 0, 0, 0, NULL, 1767225100000, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (102, 9400, 0, 1, 0, NULL, 1767225100000, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (104, 9401, 0, 0, 0, NULL, 1767225100000, NULL);
-- hint_days: the triggers made day 20453 (counted 5) and day 20454 (counted 1). 20451 and older are more than 2 days old; the day 20452 (today - 2) is the edge and stays (Q343).
INSERT INTO hint_days (day, counted) VALUES (20452, 7), (20451, 5), (20424, 9), (20400, 1);
