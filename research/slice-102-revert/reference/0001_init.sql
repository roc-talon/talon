-- PRIVATE REFERENCE for slice 102 (the test agent's check that the cases can pass). The code agent writes sql/0001_init.sql from the slice file, not from this file.
-- The registry schema, P2 (Registry 5, 5.1). Every table is STRICT (R-IK8). Times are INTEGER ms since 1970 UTC (R-RE26).

-- R-RE22, R-IK3, R-IK8: one row for each name that has a name_id. The id is a function of (kind, value) (R-IK2).
CREATE TABLE names (
  id INTEGER PRIMARY KEY,
  kind INTEGER NOT NULL CHECK (kind IN (1, 2, 3)),
  value ANY NOT NULL,
  CHECK (typeof(value) = CASE kind WHEN 1 THEN 'blob' ELSE 'text' END),
  UNIQUE (kind, value)
) STRICT;

-- R-RE21, R-IK7
CREATE TABLE targets (
  target INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
) STRICT;

INSERT INTO targets (target, name) VALUES
  (0, 'any'), (1, 'x64mac'), (2, 'x64win'), (3, 'x64mingw'), (4, 'x64freebsd'), (5, 'x64openbsd'), (6, 'x64netbsd'),
  (7, 'x64musl'), (8, 'x64glibc'), (9, 'x64linux'), (10, 'x64elf'),
  (11, 'x64v1mac'), (12, 'x64v1win'), (13, 'x64v1mingw'), (14, 'x64v1freebsd'), (15, 'x64v1openbsd'), (16, 'x64v1netbsd'),
  (17, 'x64v1musl'), (18, 'x64v1glibc'), (19, 'x64v1linux'), (20, 'x64v1elf'),
  (21, 'arm64mac'), (22, 'arm64win'), (23, 'arm64mingw'), (24, 'arm64linux'), (25, 'arm64musl'), (26, 'arm64glibc'),
  (27, 'arm64v1win'), (28, 'arm64v1mingw'), (29, 'arm64v1linux'), (30, 'arm64v1musl'), (31, 'arm64v1glibc'),
  (32, 'arm32linux'), (33, 'arm32musl'), (34, 'wasm32'), (35, 'wasm32v1');

-- R-RE1. kind: app 0, package 1, platform 2 (R-IK7). exposes: a JSON array of module names. size: bytes of the .tar.zst asset (Q74).
CREATE TABLE artifacts (
  artifact INTEGER PRIMARY KEY,
  kind INTEGER NOT NULL CHECK (kind IN (0, 1, 2)),
  exposes TEXT NOT NULL,
  platform INTEGER,
  roc_pin TEXT,
  size INTEGER NOT NULL
) STRICT;

-- R-RE2, R-IK6
CREATE TABLE releases (
  log_index INTEGER PRIMARY KEY,
  form INTEGER NOT NULL,
  version INTEGER NOT NULL,
  version_text TEXT NOT NULL,
  artifact INTEGER NOT NULL,
  repo INTEGER,
  url TEXT NOT NULL,
  tag TEXT,
  roc_version TEXT,
  published_at INTEGER NOT NULL,
  yanked INTEGER NOT NULL,
  withdrawn TEXT CHECK (withdrawn IN ('deleted', 'unpublished', 'prereleased', 'edited', 'asset-replaced', 'repo-missing')),
  withdrawn_at INTEGER,
  UNIQUE (form, version, version_text)
) STRICT;
CREATE INDEX releases_artifact ON releases (artifact, log_index);

-- R-RE3, R-IK7 (source: bot 0, author 1. result: pass 0, fail 1, hang 2, crash 3)
CREATE TABLE compat (
  artifact INTEGER NOT NULL,
  nightly INTEGER NOT NULL,
  target INTEGER NOT NULL,
  source INTEGER NOT NULL CHECK (source IN (0, 1)),
  result INTEGER NOT NULL CHECK (result IN (0, 1, 2, 3)),
  error_digest TEXT,
  time INTEGER NOT NULL,
  log_index INTEGER,
  PRIMARY KEY (artifact, nightly, target, source)
) STRICT, WITHOUT ROWID;
CREATE INDEX compat_artifact_target ON compat (artifact, target, nightly);
CREATE INDEX compat_nightly ON compat (nightly, target, source, artifact);

-- R-RE4: target is the asset target of CLI 6.2 as text.
CREATE TABLE toolchains (
  nightly INTEGER NOT NULL,
  target TEXT NOT NULL,
  tag TEXT NOT NULL,
  asset_name TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  published_at INTEGER NOT NULL,
  log_index INTEGER NOT NULL,
  PRIMARY KEY (nightly, target)
) STRICT, WITHOUT ROWID;

-- R-RE5, R-SG2, R-SG5
CREATE TABLE log (
  idx INTEGER PRIMARY KEY,
  grp TEXT NOT NULL,
  version TEXT NOT NULL,
  hash TEXT NOT NULL,
  time INTEGER NOT NULL
) STRICT;

-- R-RE7
CREATE TABLE sweeps (
  nightly INTEGER NOT NULL,
  target INTEGER NOT NULL,
  upto_log_index INTEGER NOT NULL,
  time INTEGER NOT NULL,
  PRIMARY KEY (nightly, target)
) STRICT, WITHOUT ROWID;

-- R-RE23
CREATE TABLE transitions (
  nightly INTEGER NOT NULL,
  target INTEGER NOT NULL,
  previous INTEGER NOT NULL,
  compared INTEGER NOT NULL,
  changed INTEGER NOT NULL,
  PRIMARY KEY (nightly, target)
) STRICT, WITHOUT ROWID;

-- R-RE9. via: oidc 0, webhook 1, poll 2, ingest 3. claims: JSON text, oidc only.
CREATE TABLE provenance (
  release INTEGER NOT NULL,
  via INTEGER NOT NULL CHECK (via IN (0, 1, 2, 3)),
  claims TEXT,
  time INTEGER NOT NULL,
  PRIMARY KEY (release, via)
) STRICT;

-- R-RE11. state: active 0, missing 1, moved 2.
CREATE TABLE repos (
  repo INTEGER PRIMARY KEY,
  repository_id INTEGER NOT NULL,
  repository_owner_id INTEGER NOT NULL,
  state INTEGER NOT NULL CHECK (state IN (0, 1, 2)),
  successor INTEGER,
  state_at INTEGER NOT NULL,
  time INTEGER NOT NULL
) STRICT;

-- R-RE15. action: bind 0, transfer 1, rename 2, recreate 3, missing 4, found 5, successor-set 6, successor-removed 7, offer 8, operator 9.
CREATE TABLE repo_events (
  repo INTEGER NOT NULL,
  seq INTEGER NOT NULL,
  action INTEGER NOT NULL CHECK (action IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)),
  repository_id_before INTEGER,
  repository_id_after INTEGER,
  owner_id_before INTEGER,
  owner_id_after INTEGER,
  successor INTEGER,
  claims TEXT,
  time INTEGER NOT NULL,
  PRIMARY KEY (repo, seq)
) STRICT;

-- R-RE14
CREATE TABLE repo_checks (
  repo INTEGER PRIMARY KEY,
  etag TEXT,
  checked_at INTEGER,
  next_check_at INTEGER NOT NULL,
  fail_count INTEGER NOT NULL,
  app_installed INTEGER NOT NULL
) STRICT;

-- R-RE12
CREATE TABLE compat_hints (
  artifact INTEGER NOT NULL,
  nightly INTEGER NOT NULL,
  target INTEGER NOT NULL,
  talon_version INTEGER NOT NULL,
  pass_count INTEGER NOT NULL,
  fail_count INTEGER NOT NULL,
  crash_count INTEGER NOT NULL,
  first_time INTEGER NOT NULL,
  last_time INTEGER NOT NULL,
  PRIMARY KEY (artifact, nightly, target, talon_version)
) STRICT, WITHOUT ROWID;

-- R-RE16. result: pass 0, fail 1, crash 3 (a hang is not a hint).
CREATE TABLE contributions (
  contributor INTEGER NOT NULL,
  artifact INTEGER NOT NULL,
  nightly INTEGER NOT NULL,
  target INTEGER NOT NULL,
  result INTEGER NOT NULL CHECK (result IN (0, 1, 3)),
  talon_version INTEGER NOT NULL,
  time INTEGER NOT NULL,
  PRIMARY KEY (contributor, artifact, nightly, target)
) STRICT, WITHOUT ROWID;
CREATE INDEX contributions_pair ON contributions (artifact, nightly, target, time);
CREATE INDEX contributions_nightly ON contributions (nightly);

-- R-RE17
CREATE TABLE contributors (
  contributor INTEGER PRIMARY KEY CHECK (contributor > 0),
  login TEXT NOT NULL,
  tokens_after INTEGER NOT NULL,
  first_time INTEGER NOT NULL,
  last_time INTEGER NOT NULL
) STRICT;

-- R-RE18
CREATE TABLE links (
  machine INTEGER PRIMARY KEY CHECK (machine < 0),
  contributor INTEGER NOT NULL,
  time INTEGER NOT NULL
) STRICT;

-- R-RE19
CREATE TABLE deps (
  artifact INTEGER NOT NULL,
  alias TEXT NOT NULL,
  dep INTEGER NOT NULL,
  form INTEGER,
  version INTEGER,
  version_text TEXT,
  url TEXT NOT NULL,
  PRIMARY KEY (artifact, alias)
) STRICT, WITHOUT ROWID;

-- R-RE20
CREATE TABLE artifact_targets (
  artifact INTEGER NOT NULL,
  target INTEGER NOT NULL,
  PRIMARY KEY (artifact, target)
) STRICT, WITHOUT ROWID;

-- R-RE24
CREATE TABLE hint_days (
  day INTEGER PRIMARY KEY,
  counted INTEGER NOT NULL
) STRICT;

-- R-RE25
CREATE TABLE contributor_totals (
  contributor INTEGER PRIMARY KEY,
  counted INTEGER NOT NULL,
  first INTEGER NOT NULL,
  agreed INTEGER NOT NULL,
  disagreed INTEGER NOT NULL,
  unconfirmed INTEGER NOT NULL,
  first_time INTEGER NOT NULL
) STRICT;
