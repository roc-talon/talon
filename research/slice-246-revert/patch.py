#!/usr/bin/env python3
# Private reference of slice 246: the anchored changes of shared files in a COPY of worker/ (usage: patch.py <copy of worker/>). A change of the live file shows as an error.
import sys, re
w = sys.argv[1]
def sub(path, old, new, count=1):
    p = f"{w}/{path}"
    s = open(p).read()
    if old not in s:
        sys.exit(f"patch.py: {path}: anchor not found: {old[:70]}")
    open(p, "w").write(s.replace(old, new, count))
REASON = "(SELECT y.reason FROM yanks y WHERE y.release = r.log_index AND r.yanked = 1 ORDER BY y.seq DESC LIMIT 1) AS yank_reason, "
# Reads: a field in ReleaseRow (the unit tests are not built by W2) and the record member
sub("lib/Reads.roc", "\t\twithdrawn : Try(Str, [Missing]),\n\t\tvias : Try(Str, [Missing]),\n\t}", "\t\twithdrawn : Try(Str, [Missing]),\n\t\tyank_reason : Try(Str, [Missing]),\n\t\tvias : Try(Str, [Missing]),\n\t}")
sub("lib/Reads.roc", "yank_reason: Err(None),", "yank_reason: row.yank_reason.map_err(|_| None),")
sub("ReadRoutes.roc", "r.withdrawn AS withdrawn, (SELECT group_concat(via)", "r.withdrawn AS withdrawn, " + REASON + "(SELECT group_concat(via)")
sub("IngestRoutes.roc", "r.withdrawn AS withdrawn, (SELECT group_concat(via)", "r.withdrawn AS withdrawn, " + REASON + "(SELECT group_concat(via)")
sub("IngestRoutes.roc", "\t\twithdrawn : Try(Str, [Missing]),\n\t\tvias : Try(Str, [Missing]),\n\t\thas_ingest", "\t\twithdrawn : Try(Str, [Missing]),\n\t\tyank_reason : Try(Str, [Missing]),\n\t\tvias : Try(Str, [Missing]),\n\t\thas_ingest")
sub("IngestRoutes.roc", "\t\t\t\t\t\tvias: r.vias,", "\t\t\t\t\t\tyank_reason: r.yank_reason,\n\t\t\t\t\t\tvias: r.vias,")
sub("YankRoutes.roc", "r.withdrawn AS withdrawn, (SELECT group_concat(via)", "r.withdrawn AS withdrawn, " + REASON + "(SELECT group_concat(via)")
# Route: the line and decide_yank
sub("lib/Route.roc", '\t\t\t["v1", "tokens"] => decide_tokens(input, path)\n', '\t\t\t["v1", "tokens"] => decide_tokens(input, path)\n\t\t\t["v1", "releases", index, "yank"] => decide_yank(input, path, index)\n')
sub("lib/Route.roc", "\t## `/v1/tokens` (slice 117)", '''\t## `/v1/releases/{log_index}/yank` (slice 246): `PUT` with the media check of `decide_post`, `DELETE` with no body check. Another method: 405 with `Allow: DELETE, PUT`.
\tdecide_yank : Route.Input, Str, Str -> Route.Decision
\tdecide_yank = |input, path, index| match input.method {
\t\t"PUT" => match decide_post({ ..input, method: "POST" }, path, PutYank(index)) {
\t\t\tNotAllowed(p, a) => NotAllowed(p, a)
\t\t\tother => other
\t\t}
\t\t"DELETE" => Handle(DeleteYank(index))
\t\t_ => NotAllowed(Problem.new(MethodNotAllowed, "${input.method} is not allowed on ${path}"), ["DELETE", "PUT"])
\t}

\t## `/v1/tokens` (slice 117)''')
sub("lib/Client.roc", "PostCompat | PostRelease | PutToolchain(_)", "PostCompat | PostRelease | PutYank(_) | DeleteYank(_) | PutToolchain(_)")
# The closure SQL file (R-AP17): the same column
sub("sql/closure/releases.sql", "r.yanked AS yanked, r.withdrawn AS withdrawn,\n", "r.yanked AS yanked, r.withdrawn AS withdrawn,\n    " + REASON.rstrip() + "\n")
