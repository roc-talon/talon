# M4 the closure path left without the member: worker/sql/closure/releases.sql has no `vias` column. Caught by: W1 closure c2, W2 closure ap17 (the release has no rows: 500).
import sys; sys.path.insert(0, __file__.rsplit("/", 1)[0]); from common import edit
B = sys.argv[1]
edit(B + "/worker/sql/closure/releases.sql", ",\n    (SELECT group_concat(via) FROM (SELECT via FROM provenance WHERE release = r.log_index ORDER BY via)) AS vias\n", "\n")
