# Adds the member `provenance` to each release in the fixtures of packages/records/tests/AnswerTest.roc (slice 122).
# The members of a release are in the order of the names: ..., "log_index", "provenance", "published_at", ...
# The lists are strongest first. The value depends on the log index only, so the fixtures show 1, 2 and 4 rows.
import re, sys
VIAS = {1: ["oidc", "ingest"], 2: ["webhook"], 3: ["poll", "ingest"], 4: ["oidc", "webhook", "poll", "ingest"]}
def lst(n):
    v = VIAS.get(n, ["ingest"])
    return "[" + ",".join('\\"%s\\"' % x for x in v) + "]"
p = sys.argv[1]
s = open(p).read()
s2 = re.sub(r'\\"log_index\\":(\d+),\\"published_at\\"', lambda m: '\\"log_index\\":%s,\\"provenance\\":%s,\\"published_at\\"' % (m.group(1), lst(int(m.group(1)))), s)
print(len(re.findall(r'\\"log_index\\":(\d+),\\"published_at\\"', s)), "releases")
open(p, "w").write(s2)
