# M3 duplicate: the read route joins `provenance` in place of the subquery, so a release with 2 rows appears 2 times. Caught by: W2 reads cases (a release with 2 or more rows).
import sys; sys.path.insert(0, __file__.rsplit("/", 1)[0]); from common import edit
B = sys.argv[1]
f = B + "/worker/ReadRoutes.roc"
edit(f, "(SELECT group_concat(via) FROM (SELECT via FROM provenance WHERE release = r.log_index ORDER BY via)) AS vias", "CAST(p.via AS TEXT) AS vias")
edit(f, "LEFT JOIN names rn ON rn.id = r.repo ORDER BY r.log_index\"", "LEFT JOIN names rn ON rn.id = r.repo LEFT JOIN provenance p ON p.release = r.log_index ORDER BY r.log_index\"")
