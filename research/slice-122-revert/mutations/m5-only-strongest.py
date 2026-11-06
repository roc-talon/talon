# M5 a missing via: the SQL of the reads gives only the strongest code (MIN) in place of all codes. Caught by: W2 reads cases and closure (the lists have 1 text).
import sys; sys.path.insert(0, __file__.rsplit("/", 1)[0]); from common import edit
B = sys.argv[1]
edit(B + "/worker/ReadRoutes.roc", "(SELECT group_concat(via) FROM (SELECT via FROM provenance WHERE release = r.log_index ORDER BY via)) AS vias", "(SELECT CAST(MIN(via) AS TEXT) FROM provenance WHERE release = r.log_index) AS vias")
