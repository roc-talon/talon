-- Now is 1767225600000 (day 20454). P1 (101,9400,0) has a hint and a bot row, so the hint cleanup DELETE is due; the trigger boom makes that DELETE fail.
-- The compiler 9100 is old (published 1700000000000) and has a row of another artifact (102), so the trigger does not fire in its trim. The hint_days row of day 20400 is old.
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'roc-lang/nightlies:linux_x86_64', 'nightly-2023-11-14-aaaaaaa', 'sha256:1111111111111111111111111111111111111111111111111111111111111111', 1690000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (9100, 'linux_x86_64', 'nightly-2023-11-14-aaaaaaa', 'roc_nightly-linux_x86_64.tar.gz', '1111111111111111111111111111111111111111111111111111111111111111', 1000, 1700000000000, 1);
CREATE TRIGGER boom BEFORE DELETE ON compat_hints WHEN OLD.artifact = 101 BEGIN SELECT RAISE(ABORT, 'boom'); END;
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 101, 9400, 0, 0, 1, 1767225000000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 102, 9100, 0, 0, 1, 1700000100000);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (101, 9400, 0, 0, 0, NULL, 1767225100000, NULL);
INSERT INTO hint_days (day, counted) VALUES (20400, 3);
