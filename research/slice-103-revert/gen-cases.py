#!/usr/bin/env python3
"""Writes setup.sql and steps.sql of the cases t1 to t6 of slice 103 (test agent only; the expect.tsv files are by hand).
   python3 research/slice-103-revert/gen-cases.py     (run in the repo root)"""
import json, os
D = "sql/tests/cases/triggers"
T = 1790000000000
DAY = 86400000
K1 = "-9223090561877999617"   # 1.0.0
K2 = "-9222809086901288961"   # 2.0.0
K011 = "-9223372032559677441"  # 0.1.1

def P(*a):
    return "-- params: " + json.dumps(list(a)) + "\n"

REL_COLS = "(log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)"
def leaf(form, grp, ver, h, time, vkey, vtext=""):
    # R-SG8 row 3: the leaf is written only for a new label. The MAX is in a subquery (an aggregate with no GROUP BY gives a row also when WHERE is false).
    return P(grp, ver, h, time, form, vkey, vtext) + (
        "INSERT INTO log (idx, grp, version, hash, time)\n"
        "SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4\n"
        "WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);\n")
def release(form, vkey, vtext, art, pub=T, li="(SELECT MAX(idx) FROM log)", withdrawn="NULL"):
    # R-SG8 row 4 (Design Q86): INSERT ... SELECT ... WHERE NOT EXISTS (same label and artifact), with no OR IGNORE.
    return P(form, vkey, vtext, art, pub) + "INSERT INTO releases " + REL_COLS + (
        "\nSELECT " + li + ", ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, " + withdrawn + ", NULL\n"
        "WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);\n")
def err(t): return "-- expect-error: %s\n" % t
def comment(t): return "".join("-- %s\n" % l for l in t.split("\n"))

def sweep(n, t, b, error=None):
    return (err(error) if error else "") + P(n, t, b) + (
        "INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, %d)\n"
        "ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time\n"
        "WHERE excluded.upto_log_index > sweeps.upto_log_index;\n" % T)
def brows(n, arts, src=0, t=0):
    return ("INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)\n"
            "SELECT value, %d, %d, %d, 0, NULL, %d, %s FROM json_each('%s');\n" % (n, t, src, T, "3" if src else "NULL", json.dumps(arts).replace(" ", "")))
def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)

# ---------------------------------------------------------------- t1
w(D + "/t1-publish/setup.sql", "-- The names of the groups (R-IK3): the leaf check reads the URL form from names (R-SG8 row 5). Forms 1 to 6.\n"
  "INSERT INTO names (id, kind, value) VALUES (1, 2, 'g1'), (2, 2, 'g2'), (3, 2, 'g3'), (4, 2, 'g4'), (5, 2, 'g5'), (6, 2, 'g6');\n")
s = comment("R-SG8: a publish is a leaf statement and then a release statement. The texts (group, version, hash) are parameters. The hash text is a stand-in for the base58.\n"
            "Q27, R-SG2: three new labels (forms 1, 2, 3 with 1.0.0, stored key -9223090561877999617). Leaf 1 to 3, release with log_index = MAX(idx).")
s += leaf(1, "g1", "1.0.0", "H11", T + 1, K1) + release(1, K1, "", 11)
s += leaf(2, "g2", "1.0.0", "H12", T + 2, K1) + release(2, K1, "", 12)
s += leaf(3, "g3", "1.0.0", "H13", T + 3, K1) + release(3, K1, "", 13)
s += comment("P2: the same label and the same artifact, sent again. The leaf statement writes nothing (the label exists). The release is ignored.\n"
             "No error, no leaf, no release. (The check is an AFTER trigger: an ignored insert fires nothing.)")
s += leaf(1, "g1", "1.0.0", "H11", T + 900, K1) + release(1, K1, "", 11)
s += comment("P3: the same label and another artifact. The leaf statement writes nothing. The release stops with label-conflict, also with INSERT OR IGNORE.")
s += leaf(1, "g1", "1.0.0", "H99", T + 901, K1) + err("label-conflict") + release(1, K1, "", 99)
s += comment("One artifact can have two labels (R-RE8). Form 4 with artifact 11: leaf 4.")
s += leaf(4, "g4", "1.0.0", "H11", T + 4, K1) + release(4, K1, "", 11)
s += comment("Another version_text is another label (R-IK5): form 1, the same key, text 70000.1.2, artifact 99. Leaf 5.")
s += leaf(1, "g1", "70000.1.2", "H99", T + 5, K1, "70000.1.2") + release(1, K1, "70000.1.2", 99)
s += comment("The text is part of the label: the same text with another artifact is a conflict, and no leaf.")
s += leaf(1, "g1", "70000.1.2", "H98", T + 902, K1, "70000.1.2") + err("label-conflict") + release(1, K1, "70000.1.2", 98)
s += comment("F5, R-SG8 row 4 (Design Q86): a release with no leaf statement, when the newest leaf (5) is the leaf of a release. The release takes log_index 5, which is used.\n"
             "With INSERT OR IGNORE it would be dropped with no error. Without it, the primary key stops it. Nothing is written.")
s += err("UNIQUE constraint failed: releases.log_index") + release(5, K1, "", 15)
s += comment("A release whose log_index names the leaf of another group: leaf-missing. The leaf of group g6 is leaf 6. The release is of form 5 and names leaf 6.")
s += leaf(6, "g6", "1.0.0", "H16", T + 6, K1)
s += err("leaf-missing") + release(5, K1, "", 15, li="6")
s += comment("The leaf 6 stands. The release of form 6 with log_index = MAX(idx) = 6 passes: this is the leaf of its group.")
s += release(6, K1, "", 16)
s += comment("R-SG3, R-SG8 row 6: a compiler leaf and its toolchains row. Leaf 7 (group, tag, sha256:hex).")
def comp(nightly, target, tag, hashhex, rowhash, rowtag, time, e=None):
    r = P("roc-lang/nightlies:" + target, tag, "sha256:" + hashhex, time, nightly, target)
    r += ("INSERT INTO log (idx, grp, version, hash, time)\n"
          "SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4\n"
          "WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?5 AND target = ?6);\n")
    r += (err(e) if e else "") + P(nightly, target, rowtag, "roc-" + target + ".tar.gz", rowhash, T) + (
          "INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index)\n"
          "SELECT ?1, ?2, ?3, ?4, ?5, ?6, (SELECT MAX(idx) FROM log)\n"
          "WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?1 AND target = ?2);\n")
    return r
s += comp(1000, "linux_x86_64", "nightly-2026-10-09-258ab27", "aa", "aa", "nightly-2026-10-09-258ab27", T + 7)
s += comment("The same tag sent again (R-PU9): no leaf, no row, no error.")
s += comp(1000, "linux_x86_64", "nightly-2026-10-09-258ab27", "aa", "aa", "nightly-2026-10-09-258ab27", T + 903)
s += comment("A toolchains row with no leaf statement, when the newest leaf (7) is the leaf of the linux row: leaf-missing (the group of the leaf is linux_x86_64).")
s += err("leaf-missing") + P(1003, "macos_arm64", "t", "a", "ee", T) + ("INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index)\n"
          "SELECT ?1, ?2, ?3, ?4, ?5, ?6, (SELECT MAX(idx) FROM log)\n"
          "WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ?1 AND target = ?2);\n")
s += comment("TC2: a toolchains row whose leaf has another hash: leaf-missing. Leaf 8 stays as a leaf with no row.")
s += comp(1001, "macos_arm64", "nightly-2026-10-10-aaaaaaa", "bb", "cc", "nightly-2026-10-10-aaaaaaa", T + 8, e="leaf-missing")
s += comment("A toolchains row whose leaf has another version (tag): leaf-missing. Leaf 9 stays.")
s += comp(1002, "windows_x86_64", "nightly-A", "dd", "dd", "nightly-B", T + 9, e="leaf-missing")
s += comment("R-SG8 row 5: a release with no leaf statement gets leaf-missing, and nothing is written. The newest leaf (9) is a compiler leaf and no release has the index 9, so the release is not dropped by INSERT OR IGNORE: the check sees a leaf of another group.\n(If the newest leaf were the index of a release, INSERT OR IGNORE would drop the new release with no error and no trigger. The leaf statement before the release is what the Worker must send.)")
s += err("leaf-missing") + release(5, K1, "", 15)
s += comment("The next release takes the next index after the compiler leaves: form 5, leaf 10.")
s += leaf(5, "g5", "1.0.0", "H15", T + 10, K1) + release(5, K1, "", 15)
w(D + "/t1-publish/steps.sql", s)

# ---------------------------------------------------------------- t2
LI = lambda n: 16 + n
NIGHT = {1: 900, 2: 901, 3: 902, 4: 903, 5: 300, 6: 301, 7: 900, 8: 900}
TGT = ["linux_x86_64", "macos_arm64"]
s = comment("The index of research/bot-set/ B0, with the codes of R-IK7 (app 0, package 1, platform 2) and times in ms (1 day = 86400000).\n"
            "Nightlies 1 to 4 are at the days 900 to 903, 5 at the day 300, 6 at the day 301, 7 and 8 at the day 900. Each has 2 rows in toolchains (R-RE4, R-MX16).\n"
            "R-SG8: each toolchains row has its compiler leaf (log 1 to 16, in the order of the rows), and each release its leaf. A release n has log_index 16 + n.")
rows = []; leaves = []
j = 0
for n in range(1, 9):
    for t in TGT:
        j += 1
        leaves.append("(%d, 'roc-lang/nightlies:%s', 't%d', 'sha256:s', %d)" % (j, t, n, T))
        rows.append("(%d, '%s', 't%d', 'a', 's', %d, %d)" % (n, t, n, NIGHT[n] * DAY, j))
s += "INSERT INTO log (idx, grp, version, hash, time) VALUES\n  " + ",\n  ".join(leaves) + ";\n"
s += "INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES\n  " + ",\n  ".join(rows) + ";\n"
s += "INSERT INTO names (id, kind, value) VALUES " + ", ".join("(%d, 2, 'g%d')" % (f, f) for f in range(1, 9)) + ";\n"
s += comment("Artifacts 1 to 6 and 10 to 16 are packages, 9 is a platform, 7 is an app.")
arts = [(1,1),(2,1),(3,1),(4,1),(5,1),(6,1),(7,0),(9,2),(10,1),(11,1),(12,1),(13,1),(14,1),(15,1),(16,1)]
s += "INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES\n  " + ",\n  ".join("(%d, %d, '[]', NULL, NULL, 1)" % a for a in arts) + ";\n"
K = {"0.1.0": "-9223372032559742977", "0.1.1": "-9223372032559677441", "0.2.0": "-9223372028264775681", "1.0.0": K1, "2.0.0": K2, "0.2.1": "-9223372028264710145"}
S = [  # n, form, version, artifact, published day (or ms)
    (1, 1, "0.1.0", 1, 800 * DAY), (2, 1, "0.1.1", 2, 850 * DAY), (3, 1, "0.2.0", 3, 870 * DAY),
    (4, 2, "1.0.0", 4, 100 * DAY), (5, 2, "2.0.0", 5, 880 * DAY), (6, 3, "1.0.0", 6, 10 * DAY),
    (7, 4, "1.0.0", 7, 890 * DAY), (8, 5, "1.0.0", 9, 895 * DAY)]
s += comment("The releases (n, form, version, artifact, published_at). The version keys are key XOR 2^63, as signed:\n"
             "  0.1.0 -9223372032559742977, 0.1.1 -9223372032559677441, 0.2.0 -9223372028264775681, 1.0.0 -9223090561877999617, 2.0.0 -9222809086901288961.\n"
             "  1  form 1  0.1.0  A1   day 800   (an older patch of the series 0.1: not a member)\n"
             "  2  form 1  0.1.1  A2   day 850   (the newest of the series 0.1: a member)\n"
             "  3  form 1  0.2.0  A3   day 870   (the newest of the series 0.2 until release 9: a member)\n"
             "  4  form 2  1.0.0  A4   day 100   (an old series, out of the window of nightly 1: not a member there)\n"
             "  5  form 2  2.0.0  A5   day 880   (a member)\n"
             "  6  form 3  1.0.0  A6   day 10    (out of the window, but the newest of its group: a member)\n"
             "  7  form 4  1.0.0  A7   day 890   (an app: never a member)\n"
             "  8  form 5  1.0.0  A9   day 895   (a platform: a member)")
s += "INSERT INTO log (idx, grp, version, hash, time) VALUES\n  " + ",\n  ".join("(%d, 'g%d', '%s', 'H%d', %d)" % (LI(n), f, v, a, T) for n, f, v, a, p in S) + ";\n"
s += "INSERT INTO releases " + REL_COLS + " VALUES\n  " + ",\n  ".join("(%d, %d, %s, '', %d, NULL, 'u', NULL, NULL, %d, 0, NULL, NULL)" % (LI(n), f, K[v], a, p) for n, f, v, a, p in S) + ";\n"
w(D + "/t2-sweep-guard/setup.sql", s)

B8 = LI(8)  # 24, the log size at the start
s = comment("Nightly 1 (day 900). Members at bound %d: A2, A3, A5, A6, A9. A1 (an older patch), A4 (an old series out of the window) and A7 (an app) are not." % B8)
s += comment("Rows for four members. A2 is the newest of the series 0.1: it has no row.") + brows(1, [3, 5, 6, 9])
s += comment("R-MX8, R-MX11 row 2: incomplete. (A group has more than one series.)") + sweep(1, 0, B8, "sweep-incomplete")
s += comment("A2 gets its row. Nothing is needed for A1, A4 and A7.") + brows(1, [2])
s += comment("Complete: the row is written.") + sweep(1, 0, B8)
s += comment("Nightly 4 (day 903): a bound above the log size (%d) is sweep-bound. The rows are all there, so it is the only fault." % B8) + brows(4, [2, 3, 5, 6, 9]) + sweep(4, 0, B8 + 1, "sweep-bound")
s += comment("Nightly 2: an author row does not count (R-RE8, R-MX4). A5 has an author row only.") + brows(2, [2, 3, 6, 9]) + brows(2, [5], src=1)
s += sweep(2, 0, B8, "sweep-incomplete") + comment("The bot row of A5 makes it complete.") + brows(2, [5]) + sweep(2, 0, B8)
s += comment("Nightly 3: A6 is out of the window, but it is the newest of its group. Without its row, incomplete.") + brows(3, [2, 3, 5, 9]) + sweep(3, 0, B8, "sweep-incomplete") + brows(3, [6])
s += comment("R-MX11 row 1: a yank changes the set. A2 is yanked, so A1 is the newest live release of the series 0.1.")
s += "UPDATE releases SET yanked = 1 WHERE log_index = %d;\n" % LI(2)
s += sweep(3, 0, B8, "sweep-incomplete") + brows(3, [1]) + sweep(3, 0, B8)
s += "UPDATE releases SET yanked = 0 WHERE log_index = %d;\n" % LI(2)
s += comment("TC6 (Design Q83): the row of nightly 2 has the bound %d. A yank of release 5 gives A4 a place in the set at that bound, and A4 has no row on nightly 2.\n"
             "The same sweep again, in a batch with a new row (A17): no error, the row keeps its bound, the row of A17 is written.\n"
             "A smaller bound in a batch with a new row (A18): the same." % B8)
s += "UPDATE releases SET yanked = 1 WHERE log_index = %d;\n" % LI(5)
s += "-- batch: 2\n" + brows(2, [17]) + sweep(2, 0, B8)
s += "-- batch: 2\n" + brows(2, [18]) + sweep(2, 0, B8 - 1)
s += "UPDATE releases SET yanked = 0 WHERE log_index = %d;\n" % LI(5)
B9 = LI(9)
s += comment("Release 9: 0.2.1 of form 1 (A10, day 899), with its leaf. The log size is %d. A10 is the newest of the series 0.2, so A3 is not a member at bound %d.\n0.2.1 is -9223372028264710145." % (B9, B9))
s += P(B9, "g1", "0.2.1", "H10", T).replace("-- params: [%d," % B9, "-- params: [")  # placeholder, replaced below
s = s[:s.rindex("-- params:")]  # drop the placeholder line
s += ("INSERT INTO log (idx, grp, version, hash, time) VALUES (%d, 'g1', '0.2.1', 'H10', %d);\n" % (B9, T))
s += "INSERT INTO releases " + REL_COLS + " VALUES (%d, 1, %s, '', 10, NULL, 'u', NULL, NULL, %d, 0, NULL, NULL);\n" % (B9, K["0.2.1"], 899 * DAY)
s += comment("The BEFORE UPDATE trigger: the row of nightly 1 has the bound %d. A raise to %d needs a row for A10." % (B8, B9))
s += sweep(1, 0, B9, "sweep-incomplete") + brows(1, [10])
s += comment("Complete: the row is raised to %d." % B9) + sweep(1, 0, B9)
s += comment("A smaller bound by the upsert changes nothing and is no error (R-MX4). The row keeps %d." % B9) + sweep(1, 0, B8)
s += comment("A direct UPDATE to a smaller bound is sweep-smaller. To a bound above the log size is sweep-bound (R-MX8).")
s += err("sweep-smaller") + "UPDATE sweeps SET upto_log_index = 5 WHERE nightly = 1 AND target = 0;\n"
s += err("sweep-bound") + "UPDATE sweeps SET upto_log_index = %d WHERE nightly = 1 AND target = 0;\n" % (B9 + 1)
s += comment("The BEFORE UPDATE trigger checks the set too, for a code path that does not use the upsert. Nightly 2 has the bound %d and no row for A10." % B8)
s += err("sweep-incomplete") + "UPDATE sweeps SET upto_log_index = %d WHERE nightly = 2 AND target = 0;\n" % B9
s += comment("Nightly 5 (day 300): the window is the 18 months before the published_at of the nightly, not before now. A4 (day 100) is in it.\nThe set at bound %d: A2, A10, A4, A5, A6, A9." % B9)
s += brows(5, [2, 5, 6, 9, 10]) + sweep(5, 0, B9, "sweep-incomplete") + brows(5, [4]) + sweep(5, 0, B9)
s += comment("Nightly 6 (day 301): a withdrawn release is not live (R-PU17). A5 has no row, so incomplete. After the withdrawal of release 5, A4 is the newest of its group and A5 is not needed.")
s += brows(6, [2, 4, 6, 9, 10]) + sweep(6, 0, B9, "sweep-incomplete")
s += "UPDATE releases SET withdrawn = 'deleted', withdrawn_at = %d WHERE log_index = %d;\n" % (T, LI(5))
s += sweep(6, 0, B9)
s += comment("TC5, the edge of the window (Design Q80, R-MX16). Nightly 7 and 8 are at the day 900: t = 77760000000, so the edge is t - 47347200000 = 30412800000.\n"
             "  forms 6 and 7 have two series each, forms 8 has two series too:\n"
             "  10 form 6 1.0.0 A11 published exactly at the edge: in the window, a member\n"
             "  11 form 6 2.0.0 A12 recent: a member\n"
             "  12 form 7 1.0.0 A13 published 1 ms before the edge, and not the newest of its group: not a member\n"
             "  13 form 7 2.0.0 A14 recent: a member\n"
             "  14 form 8 1.0.0 A15 published 1 ms after t: in the window, a member\n"
             "  15 form 8 2.0.0 A16 published 2 ms after t: a member")
E = [(10, 6, "1.0.0", 11, 30412800000), (11, 6, "2.0.0", 12, 77000000000), (12, 7, "1.0.0", 13, 30412799999),
     (13, 7, "2.0.0", 14, 77000000000), (14, 8, "1.0.0", 15, 77760000001), (15, 8, "2.0.0", 16, 77760000002)]
s += "INSERT INTO log (idx, grp, version, hash, time) VALUES\n  " + ",\n  ".join("(%d, 'g%d', '%s', 'H%d', %d)" % (LI(n), f, v, a, T) for n, f, v, a, p in E) + ";\n"
s += "INSERT INTO releases " + REL_COLS + " VALUES\n  " + ",\n  ".join("(%d, %d, %s, '', %d, NULL, 'u', NULL, NULL, %d, 0, NULL, NULL)" % (LI(n), f, K[v], a, p) for n, f, v, a, p in E) + ";\n"
B15 = LI(15)
s += comment("Nightly 7: the rows of the members of the earlier forms and of A12, A14, A15, A16. A11 (at the edge) has no row: incomplete.")
s += brows(7, [2, 4, 6, 9, 10, 12, 14, 15, 16]) + sweep(7, 0, B15, "sweep-incomplete")
s += comment("A11 gets its row. A13 (1 ms before the edge) needs none: complete.") + brows(7, [11]) + sweep(7, 0, B15)
s += comment("Nightly 8: A15 (after t) has no row: incomplete. With its row: complete.")
s += brows(8, [2, 4, 6, 9, 10, 11, 12, 14, 16]) + sweep(8, 0, B15, "sweep-incomplete") + brows(8, [15]) + sweep(8, 0, B15)
w(D + "/t2-sweep-guard/steps.sql", s)

# ---------------------------------------------------------------- t3
DAYT = 1790000000000
NI = [(100, 1000), (300, 2000), (200, 3000), (400, 4000), (500, 4000), (268435461, 8000), (536870919, 7000)]
s = comment("Seven nightlies, with 2 rows in toolchains each (R-RE4). The order of R-MX16 is the date (nightly >> 28), then t (published_at), then the id:\n"
            "  date 0: 100 (t 1000), 300 (2000), 200 (3000), 400 (4000), 500 (4000). The order of the ids is 100, 200, 300, 400, 500: it is not the order.\n"
            "  date 1: 268435461 (t 8000). date 2: 536870919 (t 7000). The t of the date 2 is below the t of the date 1: the date comes first.\n"
            "R-SG8: each toolchains row has its compiler leaf (log 1 to 14), each release its leaf (15 and 16).")
leaves = []; rows = []; j = 0
for n, pa in NI:
    for t in TGT:
        j += 1
        leaves.append("(%d, 'roc-lang/nightlies:%s', 't%d', 'sha256:s', %d)" % (j, t, n, DAYT))
        rows.append("(%d, '%s', 't%d', 'a', 's', %d, %d)" % (n, t, n, pa, j))
s += "INSERT INTO log (idx, grp, version, hash, time) VALUES\n  " + ",\n  ".join(leaves) + ",\n  (15, 'g1', '1.0.0', 'H1', %d),\n  (16, 'g1', '1.0.1', 'H11', %d);\n" % (DAYT, DAYT)
s += "INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES\n  " + ",\n  ".join(rows) + ";\n"
s += comment("Artifacts 1 and 11 are packages with a release each (1.0.0 and 1.0.1 of form 1, log 15 and 16). The bot set at bound 15 is A1. A2 to A9 are not indexed: they are outside the set.")
s += "INSERT INTO names (id, kind, value) VALUES (1, 2, 'g1');\n"
s += "INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1, 1, '[]', NULL, NULL, 1), (11, 1, '[]', NULL, NULL, 1);\n"
s += "INSERT INTO releases " + REL_COLS + " VALUES\n  (15, 1, %s, '', 1, NULL, 'u', NULL, NULL, 100, 0, NULL, NULL),\n  (16, 1, -9223090561877934081, '', 11, NULL, 'u', NULL, NULL, 100, 0, NULL, NULL);\n" % K1
w(D + "/t3-transitions/setup.sql", s)

def rrows(n, t, pairs, src=0, why=None):
    r = comment(why) if why else ""
    r += ("INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)\n"
          "SELECT json_extract(value, '$[0]'), %d, %d, %d, json_extract(value, '$[1]'), NULL, %d, %s FROM json_each('%s');\n"
          % (n, t, src, DAYT, "1" if src else "NULL", json.dumps([list(p) for p in pairs]).replace(" ", "")))
    return r
R = {100: [(1,0),(2,0),(3,0),(4,1),(5,0),(6,2),(7,3)],
     300: [(1,0),(2,1),(3,0),(4,1),(5,3),(6,0),(7,0),(8,0)],
     200: [(1,0),(2,1),(3,1),(4,0),(5,0),(6,0),(7,0),(8,0)],
     400: [(1,0),(2,1),(3,1),(4,0),(5,0),(6,0),(7,0),(8,1)],
     500: [(1,1),(2,1),(3,1),(4,0),(5,2),(6,0),(7,0),(8,1)],
     268435461: [(1,0),(2,1),(3,1),(4,0),(5,0),(6,0),(7,0),(8,1)],
     536870919: [(1,0),(2,1),(3,0),(4,0),(5,0),(6,0),(7,0),(8,1)]}
sw = lambda n, t, b: sweep(n, t, b)
s = comment("Results: 0 pass, 1 fail, 2 hang, 3 crash (R-IK7). A1 has a bot row on each swept nightly, so each sweep is complete (bound 15).\nNightly 100: A6 hangs and A7 crashes. A9 has an author row only.")
s += rrows(100, 0, R[100]) + rrows(100, 0, [(9, 0)], src=1) + sw(100, 0, 15)
s += comment("Nightly 300 is next to 100. A5 crashes, A8 is new (no row on 100). A9: an author row with another result.")
s += rrows(300, 0, R[300]) + rrows(300, 0, [(9, 1)], src=1)
s += comment("T0: the row (300, 0): previous 100, compared 4 (A1 to A4), changed 1 (A2). A hang, a crash, a missing row and an author row are not compared.") + sw(300, 0, 15)
s += comment("Nightly 500 is swept before 400. Its neighbour 400 is not swept, so it writes no row.") + rrows(500, 0, R[500]) + sw(500, 0, 15)
s += comment("Nightly 200 is next to 300 in the order of published_at (the ids give 100, 200, 300). Its row is (200, 0): previous 300.") + rrows(200, 0, R[200]) + sw(200, 0, 15)
s += comment("T4: the sweep of 400 writes both rows: (400, 0) with previous 200, and (500, 0) with previous 400 (500 and 400 have one published_at: the smaller id is first).") + rrows(400, 0, R[400]) + sw(400, 0, 15)
s += comment("TC7: the nightly 268435461 is of the date 1 and has t 8000. The nightly 536870919 is of the date 2 and has t 7000. The order is by the date, so 536870919 comes after 268435461.\nThe row (268435461, 0) has previous 500 (the last of the date 0). Then the row (536870919, 0) has previous 268435461.")
s += rrows(268435461, 0, R[268435461]) + sw(268435461, 0, 15)
s += rrows(536870919, 0, R[536870919]) + sw(536870919, 0, 15)
s += comment("A nightly with no toolchains row (R-MX16): it can be swept (A1 is the newest of its group), but it has no place in the order, so no transition row.")
s += rrows(999, 0, [(1, 0), (2, 0)]) + sw(999, 0, 15)
s += comment("Another target (code 9) has its own sweeps and its own transition. The rows of target 0 do not count in it.")
s += rrows(100, 9, [(1, 0), (2, 0)]) + sw(100, 9, 15) + rrows(300, 9, [(1, 1), (2, 0)]) + sw(300, 9, 15)
s += comment("A bot row that comes later (a range search, R-MX12) changes no transition: A10 on 300 and 200, with different results.")
s += rrows(300, 0, [(10, 0)]) + rrows(200, 0, [(10, 1)])
s += comment("A sweep with the same bound changes nothing. (200, 0) stays at compared 7, changed 2.") + sw(200, 0, 15)
s += comment("A raise of the bound is an UPDATE, and the rows of 400 are computed again: A10 and A11 on 400. Bound 16 needs a bot row for A11 (release 2).")
s += rrows(400, 0, [(10, 1), (11, 0)]) + sw(400, 0, 16)
w(D + "/t3-transitions/steps.sql", s)

# ---------------------------------------------------------------- t4
Dd = 20000 * DAY
w(D + "/t4-hint-quota/setup.sql", "-- The day 20000 (UTC) has counted 199996. The daily limit is 200000 (R-CT13, first guess), so 4 more rows are allowed.\nINSERT INTO hint_days (day, counted) VALUES (20000, 199996);\n")
def ins(c, a, r, tv, t, e=None, why=None):
    x = comment(why) if why else ""
    return x + (err(e) if e else "") + (
        "INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)\n"
        "VALUES (%s, %s, 1, 0, %s, %s, %s)\nON CONFLICT (contributor, artifact, nightly, target) DO NOTHING;\n" % (c, a, r, tv, t))
s = ins(-5, 1, 0, 100, Dd + 1000, why="W1: machine -5 sends a pass for the pair (A1, nightly 1, target 0). counted 199997. compat_hints: pass 1, first_time and last_time D+1000.")
s += ins(-6, 1, 1, 100, Dd + 2000, why="W3: machine -6 sends a fail for the same pair and the same Talon version. counted 199998. pass 1, fail 1, last_time D+2000.")
s += ins(-30, 1, 1, 100, Dd + 10, why="TC8 (Design Q82): machine -30 sends a fail with a time below first_time. counted 199999. fail 2. first_time and last_time do not change.")
s += ins(-5, 1, 3, 100, Dd + 3000, why="W2: machine -5 sends the pair again with another result. ON CONFLICT DO NOTHING skips it: no trigger, counted stays 199999, no count changes.")
s += ins(-7, 1, 3, 200, Dd + 4000, why="W5: another Talon version is another compat_hints row. A crash. counted 200000: the last row that is allowed.")
s += ins(-8, 2, 0, 100, Dd + 5000, e="hint-quota", why="Q1: the next row is over the limit. The trigger stops the statement: no contribution, no compat_hints row, counted stays 200000.")
s += ("-- One statement with 2 rows: the first is on the next UTC day (it would be allowed), the second is on the day 20000 (over the limit).\n"
      "-- The whole statement is undone: the row of the first day is not written, and hint_days has no row for the day 20001.\n"
      "-- expect-error: hint-quota\n"
      "INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time)\n"
      "SELECT -20 - key, 3, 1, 0, 0, 100, value FROM json_each('[%d, %d]');\n" % (Dd + DAY + 5, Dd + DAY - 2))
s += ins(-9, 3, 0, 100, Dd + DAY - 1, e="hint-quota", why="The last millisecond of the day 20000 is still the day 20000.")
s += ins(-9, 3, 0, 100, Dd + DAY, why="Q2: the first millisecond of the day 20001 is a new UTC day: allowed. hint_days has the row (20001, 1).")
w(D + "/t4-hint-quota/steps.sql", s)

# ---------------------------------------------------------------- t5
w(D + "/t5-d1-error-text/setup.sql",
  "-- One compiler leaf and its toolchains row (log 1), one release and its leaf (log 2), one nightly, and the day 20000 at the limit (counted 200000).\n"
  "INSERT INTO names (id, kind, value) VALUES (1, 2, 'g1'), (7, 2, 'a');\n"
  "INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'roc-lang/nightlies:linux_x86_64', 't1', 'sha256:s', 1000), (2, 'g1', '1.0.0', 'H1', 1000);\n"
  "INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1, 1, '[]', NULL, NULL, 1);\n"
  "INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (1, 'linux_x86_64', 't1', 'a', 's', 1000, 1);\n"
  "INSERT INTO releases " + REL_COLS + "\nVALUES (2, 1, %s, '', 1, NULL, 'u', NULL, NULL, 1000, 0, NULL, NULL);\n"
  "INSERT INTO hint_days (day, counted) VALUES (20000, 200000);\n" % K1)
X = "(extended: SQLITE_CONSTRAINT_TRIGGER)"
s = err("D1_ERROR: label-conflict: SQLITE_CONSTRAINT " + X) + release(1, K1, "", 99).replace("-- params: [1,", "-- params: [1,", 1)
s += comment("R-SG8: a release whose log_index names a leaf of another group (form 7 is the group 'a'; leaf 1 is a compiler leaf and no release has the index 1).")
s += err("D1_ERROR: leaf-missing: SQLITE_CONSTRAINT " + X) + release(7, K1, "", 5, li="1")
s += err("D1_ERROR: leaf-missing: SQLITE_CONSTRAINT " + X) + (
    "INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (2, 'macos_arm64', 't2', 'a', 'zz', 1000, 2);\n")
s += err("D1_ERROR: sweep-incomplete: SQLITE_CONSTRAINT " + X) + "INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (1, 0, 2, 1000);\n"
s += "INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1, 1, 0, 0, 0, NULL, 1000, NULL);\n"
s += err("D1_ERROR: sweep-bound: SQLITE_CONSTRAINT " + X) + "INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (1, 0, 9, 1000);\n"
s += "INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (1, 0, 2, 1000);\n"
s += err("D1_ERROR: sweep-smaller: SQLITE_CONSTRAINT " + X) + "UPDATE sweeps SET upto_log_index = 0 WHERE nightly = 1 AND target = 0;\n"
s += err("D1_ERROR: hint-quota: SQLITE_CONSTRAINT " + X) + "INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (-5, 1, 1, 0, 0, 100, 1728000001000);\n"
s += comment("R-IK3: a collision of the primary key of names (the same id, another name). It is not a trigger text.")
s += err("D1_ERROR: UNIQUE constraint failed: names.id: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_PRIMARYKEY)") + "INSERT INTO names (id, kind, value) VALUES (7, 2, 'b');\n"
w(D + "/t5-d1-error-text/steps.sql", s)

# ---------------------------------------------------------------- t6
w(D + "/t6-batch-rollback/setup.sql",
  "-- One compiler leaf and its toolchains row (log 1), release 1 (A1, a package, form 1) and its leaf (log 2). One nightly. The day 20000 has counted 199999.\n"
  "INSERT INTO names (id, kind, value) VALUES (1, 2, 'g1');\n"
  "INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'roc-lang/nightlies:linux_x86_64', 't1', 'sha256:s', 1000), (2, 'g1', '1.0.0', 'H1', 1000);\n"
  "INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1, 1, '[]', NULL, NULL, 1);\n"
  "INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (1, 'linux_x86_64', 't1', 'a', 's', 1000, 1);\n"
  "INSERT INTO releases " + REL_COLS + "\nVALUES (2, 1, %s, '', 1, NULL, 'u', NULL, NULL, 1000, 0, NULL, NULL);\n"
  "INSERT INTO hint_days (day, counted) VALUES (19999, 199999);\nINSERT INTO hint_days (day, counted) VALUES (20000, 199999);\n" % K1)
names2 = "INSERT INTO names (id, kind, value) VALUES (2, 2, 'g2')\nON CONFLICT (kind, value) DO NOTHING;\n"
s = comment("Q27, R-SG8 row 3: a publish batch is names, leaf, release. Here: names form 2, leaf and release of a new label (form 2), then the leaf and the release of the label of release 1 with another artifact.\n"
            "The leaf statement of that label writes nothing, and the release stops with label-conflict. The batch fails: no names row, no leaf, no release of form 2.")
s += "-- batch: 5\n" + err("label-conflict") + names2
s += leaf(2, "g2", "1.0.0", "H2", T + 1, K1) + release(2, K1, "", 2)
s += leaf(1, "g1", "1.0.0", "H99", T + 2, K1) + release(1, K1, "", 99)
s += comment("R-SG8 row 4: a release that fails a CHECK fails the batch (withdrawn = 'gone'). The leaf of the batch is not written either.")
s += "-- batch: 3\n" + err("CHECK constraint failed") + names2 + leaf(2, "g2", "1.0.0", "H2", T + 4, K1) + release(2, K1, "", 2, withdrawn="'gone'")
s += comment("The same batch with the new label only: written.")
s += "-- batch: 3\n" + names2 + leaf(2, "g2", "1.0.0", "H2", T + 3, K1) + release(2, K1, "", 2)
s += comment("S2: a sweep batch. The bot row of A1 is missing in the request (a row of A5 is there), so the sweep is incomplete (bound 2: the members are A1). The row of A5 is not written.")
s += "-- batch: 2\n" + err("sweep-incomplete") + brows(1, [5]) + sweep(1, 0, 2)
s += comment("The same batch with the row of A1: complete. Both rows and the sweep are written.")
s += "-- batch: 3\n" + brows(1, [5]) + brows(1, [1]) + sweep(1, 0, 2)
s += comment("R-RE13 row 1: a batch with a used key (another result) and a new key. The first write wins: A1 keeps result 0. No error.")
s += ("-- batch: 2\nINSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1, 1, 0, 0, 1, 'later', 2000, NULL);\n"
      "INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (6, 1, 0, 0, 1, 'x', 2000, NULL);\n")
s += comment("Q1: a hint batch. The first row is allowed (counted 200000), the second is over the limit. The batch fails and the first row is not written.")
ci = "INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (%d, 1, 1, 0, 0, 100, %d);\n"
s += "-- batch: 2\n" + err("hint-quota") + ci % (-5, Dd + 1000) + ci % (-6, Dd + 2000)
w(D + "/t6-batch-rollback/steps.sql", s)
