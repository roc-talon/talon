#!/usr/bin/env python3
"""PRIVATE REFERENCE of slice 119a: the switch of the three callers to GithubRead.send! and the base64 dependency, applied to a COPY of worker/ (usage: callers-patch.py <worker dir>)."""
import sys, os
d = sys.argv[1]
def edit(rel, pairs):
    p = os.path.join(d, rel)
    s = open(p).read()
    for old, new in pairs:
        assert s.count(old) == 1, (rel, old, s.count(old))
        s = s.replace(old, new)
    open(p, 'w').write(s)

edit('lib/main.roc', [('\t\tbase58:', '\t\tbase64: "https://github.com/niclas-ahden/roc-base64/releases/download/1.0.2/DQBxATK6BtaCWe56bCmkMgdKJR2Ym8NiZZLhYCAgtLac.tar.zst",\n\t\tbase58:')])
edit('ToolchainRoutes.roc', [
    ('import pf.Http\n', 'import pf.Http\nimport GithubRead\nimport lib.GithubApp\n'),
    ('request = Request.get(Toolchains.release_url(tag)).with_header("user-agent", "talon-registry").with_header("accept", "application/vnd.github+json")\n\t\tres = Http.send!(request).map_err(|_| Refuse(Toolchains.github_no_answer))?',
     'request = Request.get(Toolchains.release_url(tag))\n\t\tres = GithubRead.send!(request).map_err(|e| match e {\n\t\t\tNoAnswer => Refuse(Toolchains.github_no_answer)\n\t\t\tToken(f) => token_error(f)\n\t\t})?'),
    ('\t## R-SG8 row 6: the leaf statement', '\ttoken_error : GithubApp.Failure -> ToolchainRoutes.Error\n\ttoken_error = |f| match GithubApp.failure_class(f) {\n\t\tUpstream(detail) => Refuse(Problem.new(Upstream, detail))\n\t\tFault(text) => Fault(text)\n\t}\n\n\t## R-SG8 row 6: the leaf statement'),
])
edit('IngestRoutes.roc', [
    ('import pf.Http\n', 'import pf.Http\nimport GithubRead\nimport lib.GithubApp\n'),
    ('github! = |url, what, api| {\n\t\tbase = Request.get(url).with_header("user-agent", "talon-registry")\n\t\trequest = if (api) base.with_header("accept", "application/vnd.github+json") else base\n\t\tres = Http.send!(request).map_err(|_| Refuse(Ingest.github_no_answer(what)))?',
     'github! = |url, what, _api| {\n\t\tres = GithubRead.send!(Request.get(url)).map_err(|e| match e {\n\t\t\tNoAnswer => Refuse(Ingest.github_no_answer(what))\n\t\t\tToken(f) => match GithubApp.failure_class(f) {\n\t\t\t\tUpstream(detail) => Refuse(Problem.new(Upstream, detail))\n\t\t\t\tFault(text) => Fault(text)\n\t\t\t}\n\t\t})?'),
])
edit('HintRoutes.roc', [
    ('import pf.Http\n', 'import pf.Http\nimport GithubRead\n'),
    ('res = Http.send!(Request.get(Hints.tags_url).with_header("user-agent", "talon-registry")) ? |_| NoTags', 'res = GithubRead.send!(Request.get(Hints.tags_url)) ? |_| NoTags'),
])
