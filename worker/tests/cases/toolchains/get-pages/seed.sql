-- 2,500 rows: log index i, nightly (i - 1) % 500, target block (i - 1) / 500. All text is made from i.
WITH RECURSIVE s(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM s WHERE i < 2500)
INSERT INTO log (idx, grp, version, hash, time)
SELECT i, 'roc-lang/nightlies:' || CASE (i - 1) / 500 WHEN 0 THEN 'linux_arm64' WHEN 1 THEN 'linux_x86_64' WHEN 2 THEN 'macos_apple_silicon' WHEN 3 THEN 'macos_x86_64' ELSE 'windows_x86_64' END,
  printf('nightly-2026-10-21-%07x', (i - 1) % 500), 'sha256:' || printf('%064x', i), 1700000000000 FROM s;
WITH RECURSIVE s(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM s WHERE i < 2500)
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
SELECT 20000 * 268435456 + (i - 1) % 500,
  CASE (i - 1) / 500 WHEN 0 THEN 'linux_arm64' WHEN 1 THEN 'linux_x86_64' WHEN 2 THEN 'macos_apple_silicon' WHEN 3 THEN 'macos_x86_64' ELSE 'windows_x86_64' END,
  printf('nightly-2026-10-21-%07x', (i - 1) % 500), 'roc_nightly-seed-' || i || '.tar.gz', printf('%064x', i), 1000 + i, 1700000000000 + ((i - 1) % 500) * 86400000, i FROM s;
