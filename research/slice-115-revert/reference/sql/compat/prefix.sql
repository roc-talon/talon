-- The bot set of Registry R-MX11 at the bound ?3 for the nightly ?1 (slice 115). Each statement is this text, a newline, and its file.
-- ?1 the nightly id, ?2 the target code, ?3 the bound (a log index), or NULL for the log size now (the route GET /v1/sweeps/{tag}, R-AP39). The same condition as the triggers sweeps_guard_insert and sweeps_guard_update of sql/0002_triggers.sql.
-- live: R-MX11 row 1. cand: row 2 and 4 (a package or a platform; the newest live release of its form and series). members: row 3 (in the window, or the newest of its form).
WITH
live AS (SELECT r.* FROM releases r WHERE r.log_index <= COALESCE(?3, (SELECT COALESCE(MAX(idx), 0) FROM log)) AND r.yanked = 0 AND r.withdrawn IS NULL),
cand AS (SELECT r.artifact, r.form, r.version, r.published_at FROM live r
    WHERE (SELECT a.kind FROM artifacts a WHERE a.artifact = r.artifact) IN (1, 2)
      AND NOT EXISTS (SELECT 1 FROM live r2 WHERE r2.form = r.form AND r2.version > r.version AND (r2.version >> 48) = (r.version >> 48)
        AND ((r.version >> 48) <> -32768 OR ((r2.version >> 32) & 65535) = ((r.version >> 32) & 65535)))),
members AS (SELECT DISTINCT c.artifact FROM cand c
    WHERE c.published_at >= (SELECT MIN(t.published_at) FROM toolchains t WHERE t.nightly = ?1) - 47347200000
       OR NOT EXISTS (SELECT 1 FROM live r3 WHERE r3.form = c.form AND r3.version > c.version))
