# M6 the ingest and publish path left without the member: the label read has no `vias` column (label_sql_of unchanged). Caught by: W2 ingest and publish cases (500).
import sys; sys.path.insert(0, __file__.rsplit("/", 1)[0]); from common import edit
B = sys.argv[1]
edit(B + "/worker/IngestRoutes.roc", ", (SELECT group_concat(via) FROM (SELECT via FROM provenance WHERE release = r.log_index ORDER BY via)) AS vias, EXISTS", ", EXISTS")
