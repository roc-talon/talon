-- W1: machine -5 sends a pass for the pair (A1, nightly 1, target 0). counted 199997. compat_hints: pass 1, first_time and last_time D+1000.
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)
VALUES (-5, 1, 1, 0, 0, 100, 1728000001000)
ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING;
-- W3: machine -6 sends a fail for the same pair and the same Talon version. counted 199998. pass 1, fail 1, last_time D+2000.
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)
VALUES (-6, 1, 1, 0, 1, 100, 1728000002000)
ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING;
-- TC8 (Design Q82): machine -30 sends a fail with a time below first_time. counted 199999. fail 2. first_time and last_time do not change.
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)
VALUES (-30, 1, 1, 0, 1, 100, 1728000000010)
ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING;
-- W2: machine -5 sends the pair again with another result. ON CONFLICT DO NOTHING skips it: no trigger, counted stays 199999, no count changes.
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)
VALUES (-5, 1, 1, 0, 3, 100, 1728000003000)
ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING;
-- W5: another Talon version is another compat_hints row. A crash. counted 200000: the last row that is allowed.
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)
VALUES (-7, 1, 1, 0, 3, 200, 1728000004000)
ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING;
-- Q1: the next row is over the limit. The trigger stops the statement: no contribution, no compat_hints row, counted stays 200000.
-- expect-error: hint-quota
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)
VALUES (-8, 2, 1, 0, 0, 100, 1728000005000)
ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING;
-- One statement with 2 rows: the first is on the next UTC day (it would be allowed), the second is on the day 20000 (over the limit).
-- The whole statement is undone: the row of the first day is not written, and hint_days has no row for the day 20001.
-- expect-error: hint-quota
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)
SELECT -20 - key, 3, 1, 0, 0, 100, value FROM json_each('[1728086400005, 1728086399998]');
-- The last millisecond of the day 20000 is still the day 20000.
-- expect-error: hint-quota
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)
VALUES (-9, 3, 1, 0, 0, 100, 1728086399999)
ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING;
-- Q2: the first millisecond of the day 20001 is a new UTC day: allowed. hint_days has the row (20001, 1).
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)
VALUES (-9, 3, 1, 0, 0, 100, 1728086400000)
ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING;
