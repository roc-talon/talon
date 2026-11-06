# Roc mutations of the reference copy (slice 116). Usage: ROC_MUT=<name> python3 roc.py <worker dir>   (ref.sh: MUTATE_PY=mutations/roc.py ROC_MUT=<name> ./ref.sh w0|w2 ...)
import sys, os
name = os.environ['ROC_MUT']; w = sys.argv[1]
def edit(f, old, new, count=1):
    p = os.path.join(w, f); s = open(p).read()
    if old not in s: sys.exit(f'mutation {name}: "{old[:70]}" is not in {f}')
    open(p, 'w').write(s.replace(old, new, count))
Hn = 'lib/Hints.roc'; R = 'HintRoutes.roc'; C = 'lib/Client.roc'
M = {
  # R-CT4: `written` is the count of returned rows, not `meta.changes` (on D1 `changes` also counts the rows that the trigger writes).
  'written-changes': lambda: edit(R, 'Ok(answer(written.len(),', 'Ok(answer(written.len() * 0 + insert_res.info().changes,'),
  # R-CT4 step order: `first` must see the state before the insert.
  'first-after-insert': lambda: (edit(R, 'Sql.stmt(Hints.first_sql(), (json, now)),\n\t\t\tSql.stmt(Hints.skipped_sql(), (json, now)),\n\t\t\tSql.stmt(Hints.insert_sql(), (json, now, contributor, version)),', 'Sql.stmt(Hints.insert_sql(), (json, now, contributor, version)),\n\t\t\tSql.stmt(Hints.first_sql(), (json, now)),\n\t\t\tSql.stmt(Hints.skipped_sql(), (json, now)),'), edit(R, '[first_res, skipped_res, insert_res] =>', '[insert_res, first_res, skipped_res] =>')),
  # R-CT4 step 1: a pair with a `compat` row of any source is not `first` (an author row counts).
  'first-ignores-compat': lambda: edit(Hn, 'AND NOT EXISTS (SELECT 1 FROM compat k WHERE k.artifact = c.artifact AND k.nightly = c.nightly AND k.target = c.target) AND', 'AND'),
  # R-CT14: the table order of the reasons (unknown-nightly before unknown-target).
  'reason-order': lambda: edit(Hn, "WHEN NOT EXISTS (SELECT 1 FROM toolchains t WHERE t.nightly = r.nightly) THEN 'unknown-nightly' WHEN r.target IS NULL THEN 'unknown-target'", "WHEN r.target IS NULL THEN 'unknown-target' WHEN NOT EXISTS (SELECT 1 FROM toolchains t WHERE t.nightly = r.nightly) THEN 'unknown-nightly'"),
  # R-CT14: `bot-row` is a `bot` row only; an `author` row does not skip the hint.
  'bot-row-any-source': lambda: edit(Hn, ' AND k.source = 0) THEN', ') THEN'),
  # R-CT3: the contributor of a machine that logged in is the account (`links`).
  'link-ignored': lambda: edit(Hn, 'COALESCE((SELECT l.contributor FROM links l WHERE l.machine = ?3), ?3)', '?3'),
  # R-CT13, R-AP25: `Retry-After` is rounded up.
  'retry-floor': lambda: edit(Hn, '(left + 999) // 1000', 'left // 1000'),
  # R-CT12: only a tag of `roc-talon/talon` is a release of Talon.
  'key-no-tags': lambda: edit(Hn, 'if x.tags.contains("v${x.version}") {', 'if Bool.True {'),
  # R-CT2: a real target on a package is 400.
  'package-target-unchecked': lambda: edit(Hn, '} else if kind == 1 {', '} else if kind == 99 {'),
  # R-CT4, Q86: INSERT OR IGNORE drops a row that fails a CHECK.
  'or-ignore': lambda: edit(Hn, 'INSERT INTO contributions', 'INSERT OR IGNORE INTO contributions'),
  # R-CT11 (Q116-b5): the limit comes after the id check and the decode.
  'limit-first': lambda: (edit(R, '\t\theader = match', '\t\tmatch limiter.limit!(Client.rate_key(req.header("cf-connecting-ip"))) {\n\t\t\tOk({}) => {}\n\t\t\tErr(RateLimited) => return Ok(Response.from_bytes(429, "application/problem+json", Client.rate_problem().to_json().to_utf8()).with_header("retry-after", Client.limit_retry_after.to_str()))\n\t\t\tErr(Infra(e)) => return Err(Fault(Str.inspect(e)))\n\t\t}\n\t\theader = match')),
  # R-AP45: a client with a version equal to the minimum is accepted.
  'client-equal-refused': lambda: edit(C, 'Before => Ok(s)', 'Before | Same => Ok(s)'),
  # R-CT11: the key of an IPv6 client is the /64 prefix, not the address.
  'ipv6-full': lambda: edit(C, 'groups.take_first(4).map(hex_short)', 'groups.map(hex_short)'),
  # R-AP48 row 3: the client check comes before the media type and the size.
  # (main.roc) the probe is done with the real body flag
  'client-after-media': lambda: edit('main.roc', 'content_type: Err(NotFound), has_body: Bool.False })', 'content_type: req.header("content-type"), has_body: body_present!(req) })'),
}
M.update({
  # Design Q174: a nightly exactly at the edge is not old.
  'old-edge-in': lambda: edit(Hn, 'AS reason FROM r', 'AS reason FROM r') if False else edit(Hn, ') < ?2 - 31536000000', ') <= ?2 - 31536000000'),
  # Design Q174, R-CT15: the smallest `published_at` of the nightly decides.
  'old-max': lambda: edit(Hn, 'SELECT MIN(t.published_at)', 'SELECT MAX(t.published_at)'),
  # Design Q184: the first product of the User-Agent is read.
  'ua-whole': lambda: edit(C, 'product = match text.split_on(" ") {', 'product = match [text] {'),
})
M[name]()
