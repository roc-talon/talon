-- Slice 103, PRIVATE REFERENCE (test agent). Not the code. The code agent does not read it (TW18).
CREATE TRIGGER releases_label_conflict BEFORE INSERT ON releases
BEGIN
  SELECT RAISE(ABORT, 'label-conflict') WHERE EXISTS (
    SELECT 1 FROM releases WHERE form = NEW.form AND version = NEW.version AND version_text = NEW.version_text AND artifact <> NEW.artifact);
END;

CREATE TRIGGER releases_leaf_check AFTER INSERT ON releases
BEGIN
  SELECT RAISE(ABORT, 'leaf-missing') WHERE NOT EXISTS (SELECT 1 FROM log
    WHERE idx = NEW.log_index AND grp = (SELECT value FROM names WHERE id = NEW.form AND kind = 2));
END;

CREATE TRIGGER toolchains_leaf_check AFTER INSERT ON toolchains
BEGIN
  SELECT RAISE(ABORT, 'leaf-missing') WHERE NOT EXISTS (SELECT 1 FROM log
    WHERE idx = NEW.log_index AND grp = 'roc-lang/nightlies:' || NEW.target AND version = NEW.tag AND hash = 'sha256:' || NEW.sha256);
END;

CREATE TRIGGER sweeps_guard_insert BEFORE INSERT ON sweeps
BEGIN
  SELECT RAISE(ABORT, 'sweep-bound') WHERE NEW.upto_log_index > (SELECT COALESCE(MAX(idx), 0) FROM log) AND NOT EXISTS (SELECT 1 FROM sweeps s0 WHERE s0.nightly = NEW.nightly AND s0.target = NEW.target AND s0.upto_log_index >= NEW.upto_log_index);
  SELECT RAISE(ABORT, 'sweep-incomplete') WHERE EXISTS (SELECT 1 FROM releases r
    WHERE r.log_index <= NEW.upto_log_index AND r.yanked = 0 AND r.withdrawn IS NULL
      AND (SELECT kind FROM artifacts a WHERE a.artifact = r.artifact) IN (1, 2)
      AND NOT EXISTS (SELECT 1 FROM releases r2 WHERE r2.form = r.form AND r2.log_index <= NEW.upto_log_index AND r2.yanked = 0 AND r2.withdrawn IS NULL AND r2.version > r.version AND (r2.version >> 48) = (r.version >> 48)
      AND ((r.version >> 48) <> -32768 OR ((r2.version >> 32) & 65535) = ((r.version >> 32) & 65535)))
      AND (r.published_at >= (SELECT MIN(published_at) FROM toolchains WHERE nightly = NEW.nightly) - 47347200000 OR NOT EXISTS (SELECT 1 FROM releases r3 WHERE r3.form = r.form AND r3.log_index <= NEW.upto_log_index AND r3.yanked = 0 AND r3.withdrawn IS NULL AND r3.version > r.version))
      AND NOT EXISTS (SELECT 1 FROM compat c
      WHERE c.artifact = r.artifact AND c.nightly = NEW.nightly AND c.target = NEW.target AND c.source = 0)) AND NOT EXISTS (SELECT 1 FROM sweeps s0 WHERE s0.nightly = NEW.nightly AND s0.target = NEW.target AND s0.upto_log_index >= NEW.upto_log_index);
END;

CREATE TRIGGER sweeps_guard_update BEFORE UPDATE ON sweeps
BEGIN
  SELECT RAISE(ABORT, 'sweep-smaller') WHERE NEW.upto_log_index < OLD.upto_log_index;
  SELECT RAISE(ABORT, 'sweep-bound') WHERE NEW.upto_log_index > (SELECT COALESCE(MAX(idx), 0) FROM log);
  SELECT RAISE(ABORT, 'sweep-incomplete') WHERE EXISTS (SELECT 1 FROM releases r
    WHERE r.log_index <= NEW.upto_log_index AND r.yanked = 0 AND r.withdrawn IS NULL
      AND (SELECT kind FROM artifacts a WHERE a.artifact = r.artifact) IN (1, 2)
      AND NOT EXISTS (SELECT 1 FROM releases r2 WHERE r2.form = r.form AND r2.log_index <= NEW.upto_log_index AND r2.yanked = 0 AND r2.withdrawn IS NULL AND r2.version > r.version AND (r2.version >> 48) = (r.version >> 48)
      AND ((r.version >> 48) <> -32768 OR ((r2.version >> 32) & 65535) = ((r.version >> 32) & 65535)))
      AND (r.published_at >= (SELECT MIN(published_at) FROM toolchains WHERE nightly = NEW.nightly) - 47347200000 OR NOT EXISTS (SELECT 1 FROM releases r3 WHERE r3.form = r.form AND r3.log_index <= NEW.upto_log_index AND r3.yanked = 0 AND r3.withdrawn IS NULL AND r3.version > r.version))
      AND NOT EXISTS (SELECT 1 FROM compat c
      WHERE c.artifact = r.artifact AND c.nightly = NEW.nightly AND c.target = NEW.target AND c.source = 0));
END;

CREATE TRIGGER sweeps_transitions_insert AFTER INSERT ON sweeps
BEGIN
  INSERT INTO transitions (nightly, target, previous, compared, changed)
    SELECT NEW.nightly, NEW.target, (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1), (SELECT COUNT(*) FROM compat a JOIN compat b
      ON b.artifact = a.artifact AND b.nightly = NEW.nightly AND b.target = a.target AND b.source = 0 AND b.result IN (0, 1)
      WHERE a.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1) AND a.target = NEW.target AND a.source = 0 AND a.result IN (0, 1) ), (SELECT COUNT(*) FROM compat a JOIN compat b
      ON b.artifact = a.artifact AND b.nightly = NEW.nightly AND b.target = a.target AND b.source = 0 AND b.result IN (0, 1)
      WHERE a.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1) AND a.target = NEW.target AND a.source = 0 AND a.result IN (0, 1) AND a.result <> b.result)
    WHERE (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1) IS NOT NULL AND NEW.nightly IS NOT NULL
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1) AND s.target = NEW.target)
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = NEW.nightly AND s.target = NEW.target)
    ON CONFLICT (nightly, target) DO UPDATE SET previous = excluded.previous, compared = excluded.compared, changed = excluded.changed;
  INSERT INTO transitions (nightly, target, previous, compared, changed)
    SELECT (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1), NEW.target, NEW.nightly, (SELECT COUNT(*) FROM compat a JOIN compat b
      ON b.artifact = a.artifact AND b.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1) AND b.target = a.target AND b.source = 0 AND b.result IN (0, 1)
      WHERE a.nightly = NEW.nightly AND a.target = NEW.target AND a.source = 0 AND a.result IN (0, 1) ), (SELECT COUNT(*) FROM compat a JOIN compat b
      ON b.artifact = a.artifact AND b.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1) AND b.target = a.target AND b.source = 0 AND b.result IN (0, 1)
      WHERE a.nightly = NEW.nightly AND a.target = NEW.target AND a.source = 0 AND a.result IN (0, 1) AND a.result <> b.result)
    WHERE NEW.nightly IS NOT NULL AND (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1) IS NOT NULL
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = NEW.nightly AND s.target = NEW.target)
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1) AND s.target = NEW.target)
    ON CONFLICT (nightly, target) DO UPDATE SET previous = excluded.previous, compared = excluded.compared, changed = excluded.changed;
END;

CREATE TRIGGER sweeps_transitions_update AFTER UPDATE ON sweeps
BEGIN
  INSERT INTO transitions (nightly, target, previous, compared, changed)
    SELECT NEW.nightly, NEW.target, (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1), (SELECT COUNT(*) FROM compat a JOIN compat b
      ON b.artifact = a.artifact AND b.nightly = NEW.nightly AND b.target = a.target AND b.source = 0 AND b.result IN (0, 1)
      WHERE a.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1) AND a.target = NEW.target AND a.source = 0 AND a.result IN (0, 1) ), (SELECT COUNT(*) FROM compat a JOIN compat b
      ON b.artifact = a.artifact AND b.nightly = NEW.nightly AND b.target = a.target AND b.source = 0 AND b.result IN (0, 1)
      WHERE a.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1) AND a.target = NEW.target AND a.source = 0 AND a.result IN (0, 1) AND a.result <> b.result)
    WHERE (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1) IS NOT NULL AND NEW.nightly IS NOT NULL
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) < (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa < me.pa OR (t.pa = me.pa AND t.nightly < NEW.nightly))))
      ORDER BY (t.nightly >> 28) DESC, t.pa DESC, t.nightly DESC LIMIT 1) AND s.target = NEW.target)
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = NEW.nightly AND s.target = NEW.target)
    ON CONFLICT (nightly, target) DO UPDATE SET previous = excluded.previous, compared = excluded.compared, changed = excluded.changed;
  INSERT INTO transitions (nightly, target, previous, compared, changed)
    SELECT (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1), NEW.target, NEW.nightly, (SELECT COUNT(*) FROM compat a JOIN compat b
      ON b.artifact = a.artifact AND b.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1) AND b.target = a.target AND b.source = 0 AND b.result IN (0, 1)
      WHERE a.nightly = NEW.nightly AND a.target = NEW.target AND a.source = 0 AND a.result IN (0, 1) ), (SELECT COUNT(*) FROM compat a JOIN compat b
      ON b.artifact = a.artifact AND b.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1) AND b.target = a.target AND b.source = 0 AND b.result IN (0, 1)
      WHERE a.nightly = NEW.nightly AND a.target = NEW.target AND a.source = 0 AND a.result IN (0, 1) AND a.result <> b.result)
    WHERE NEW.nightly IS NOT NULL AND (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1) IS NOT NULL
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = NEW.nightly AND s.target = NEW.target)
      AND EXISTS (SELECT 1 FROM sweeps s WHERE s.nightly = (SELECT t.nightly FROM (SELECT nightly, MIN(published_at) AS pa FROM toolchains GROUP BY nightly) t, (SELECT MIN(published_at) AS pa FROM toolchains WHERE nightly = NEW.nightly) me
      WHERE me.pa IS NOT NULL AND ((t.nightly >> 28) > (NEW.nightly >> 28) OR ((t.nightly >> 28) = (NEW.nightly >> 28) AND (t.pa > me.pa OR (t.pa = me.pa AND t.nightly > NEW.nightly))))
      ORDER BY (t.nightly >> 28), t.pa, t.nightly LIMIT 1) AND s.target = NEW.target)
    ON CONFLICT (nightly, target) DO UPDATE SET previous = excluded.previous, compared = excluded.compared, changed = excluded.changed;
END;

CREATE TRIGGER contributions_count AFTER INSERT ON contributions
BEGIN
  INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time)
  VALUES (NEW.artifact, NEW.nightly, NEW.target, NEW.talon_version,
    NEW.result = 0, NEW.result = 1, NEW.result = 3, NEW.time, NEW.time)
  ON CONFLICT (artifact, nightly, target, talon_version) DO UPDATE SET
    pass_count = pass_count + excluded.pass_count, fail_count = fail_count + excluded.fail_count,
    crash_count = crash_count + excluded.crash_count,
    last_time = MAX(last_time, excluded.last_time);
  INSERT INTO hint_days (day, counted) VALUES (NEW.time / 86400000, 1)
  ON CONFLICT (day) DO UPDATE SET counted = counted + 1;
  SELECT RAISE(ABORT, 'hint-quota') WHERE (SELECT counted FROM hint_days WHERE day = NEW.time / 86400000) > 200000;
END;
