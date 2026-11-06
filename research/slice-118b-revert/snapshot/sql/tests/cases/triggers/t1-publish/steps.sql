-- R-SG8: a publish is a leaf statement and then a release statement. The texts (group, version, hash) are parameters. The hash text is a stand-in for the base58.
-- Q27, R-SG2: three new labels (forms 1, 2, 3 with 1.0.0, stored key -9223090561877999617). Leaf 1 to 3, release with log_index = MAX(idx).
-- params: ["g1", "1.0.0", "H11", 1790000000001, 1, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [1, "-9223090561877999617", "", 11, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- params: ["g2", "1.0.0", "H12", 1790000000002, 2, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [2, "-9223090561877999617", "", 12, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- params: ["g3", "1.0.0", "H13", 1790000000003, 3, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [3, "-9223090561877999617", "", 13, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- P2: the same label and the same artifact, sent again. The leaf statement writes nothing (the label exists). The release is ignored.
-- No error, no leaf, no release. (The check is an AFTER trigger: an ignored insert fires nothing.)
-- params: ["g1", "1.0.0", "H11", 1790000000900, 1, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [1, "-9223090561877999617", "", 11, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- P3: the same label and another artifact. The leaf statement writes nothing. The release stops with label-conflict, also with INSERT OR IGNORE.
-- params: ["g1", "1.0.0", "H99", 1790000000901, 1, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- expect-error: label-conflict
-- params: [1, "-9223090561877999617", "", 99, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- One artifact can have two labels (R-RE8). Form 4 with artifact 11: leaf 4.
-- params: ["g4", "1.0.0", "H11", 1790000000004, 4, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [4, "-9223090561877999617", "", 11, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- Another version_text is another label (R-IK5): form 1, the same key, text 70000.1.2, artifact 99. Leaf 5.
-- params: ["g1", "70000.1.2", "H99", 1790000000005, 1, "-9223090561877999617", "70000.1.2"]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [1, "-9223090561877999617", "70000.1.2", 99, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- The text is part of the label: the same text with another artifact is a conflict, and no leaf.
-- params: ["g1", "70000.1.2", "H98", 1790000000902, 1, "-9223090561877999617", "70000.1.2"]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- expect-error: label-conflict
-- params: [1, "-9223090561877999617", "70000.1.2", 98, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- F5, R-SG8 row 4 (Design Q86): a release with no leaf statement, when the newest leaf (5) is the leaf of a release. The release takes log_index 5, which is used.
-- With INSERT OR IGNORE it would be dropped with no error. Without it, the primary key stops it. Nothing is written.
-- expect-error: UNIQUE constraint failed: releases.log_index
-- params: [5, "-9223090561877999617", "", 15, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- A release whose log_index names the leaf of another group: leaf-missing. The leaf of group g6 is leaf 6. The release is of form 5 and names leaf 6.
-- params: ["g6", "1.0.0", "H16", 1790000000006, 6, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- expect-error: leaf-missing
-- params: [5, "-9223090561877999617", "", 15, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT 6, ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- The leaf 6 stands. The release of form 6 with log_index = MAX(idx) = 6 passes: this is the leaf of its group.
-- params: [6, "-9223090561877999617", "", 16, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- R-SG3, R-SG8 row 6: a compiler leaf and its toolchains row. Leaf 7 (group, tag, sha256:hex).
-- params: ["roc-lang/nightlies:linux_x86_64", "nightly-2026-10-09-258ab27", "sha256:aa", 1790000000007, 1000, "linux_x86_64"]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?5 AND target = ?6);
-- params: [1000, "linux_x86_64", "nightly-2026-10-09-258ab27", "roc-linux_x86_64.tar.gz", "aa", 1790000000000]
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
SELECT ?1, ?2, ?3, ?4, ?5, 1000, ?6, (SELECT MAX(idx) FROM log)
WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?1 AND target = ?2);
-- The same tag sent again (R-PU9): no leaf, no row, no error.
-- params: ["roc-lang/nightlies:linux_x86_64", "nightly-2026-10-09-258ab27", "sha256:aa", 1790000000903, 1000, "linux_x86_64"]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?5 AND target = ?6);
-- params: [1000, "linux_x86_64", "nightly-2026-10-09-258ab27", "roc-linux_x86_64.tar.gz", "aa", 1790000000000]
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
SELECT ?1, ?2, ?3, ?4, ?5, 1000, ?6, (SELECT MAX(idx) FROM log)
WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?1 AND target = ?2);
-- A toolchains row with no leaf statement, when the newest leaf (7) is the leaf of the linux row: leaf-missing (the group of the leaf is linux_x86_64).
-- expect-error: leaf-missing
-- params: [1003, "macos_arm64", "t", "a", "ee", 1790000000000]
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
SELECT ?1, ?2, ?3, ?4, ?5, 1000, ?6, (SELECT MAX(idx) FROM log)
WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?1 AND target = ?2);
-- TC2: a toolchains row whose leaf has another hash: leaf-missing. Leaf 8 stays as a leaf with no row.
-- params: ["roc-lang/nightlies:macos_arm64", "nightly-2026-10-10-aaaaaaa", "sha256:bb", 1790000000008, 1001, "macos_arm64"]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?5 AND target = ?6);
-- expect-error: leaf-missing
-- params: [1001, "macos_arm64", "nightly-2026-10-10-aaaaaaa", "roc-macos_arm64.tar.gz", "cc", 1790000000000]
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
SELECT ?1, ?2, ?3, ?4, ?5, 1000, ?6, (SELECT MAX(idx) FROM log)
WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?1 AND target = ?2);
-- A toolchains row whose leaf has another version (tag): leaf-missing. Leaf 9 stays.
-- params: ["roc-lang/nightlies:windows_x86_64", "nightly-A", "sha256:dd", 1790000000009, 1002, "windows_x86_64"]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?5 AND target = ?6);
-- expect-error: leaf-missing
-- params: [1002, "windows_x86_64", "nightly-B", "roc-windows_x86_64.tar.gz", "dd", 1790000000000]
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
SELECT ?1, ?2, ?3, ?4, ?5, 1000, ?6, (SELECT MAX(idx) FROM log)
WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?1 AND target = ?2);
-- R-SG8 row 5: a release with no leaf statement gets leaf-missing, and nothing is written. The newest leaf (9) is a compiler leaf and no release has the index 9, so the release is not dropped by INSERT OR IGNORE: the check sees a leaf of another group.
-- (If the newest leaf were the index of a release, INSERT OR IGNORE would drop the new release with no error and no trigger. The leaf statement before the release is what the Worker must send.)
-- expect-error: leaf-missing
-- params: [5, "-9223090561877999617", "", 15, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- The next release takes the next index after the compiler leaves: form 5, leaf 10.
-- params: ["g5", "1.0.0", "H15", 1790000000010, 5, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [5, "-9223090561877999617", "", 15, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
