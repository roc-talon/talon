# Roc mutations of the reference copy (slice 115). Usage: ROC_MUT=<name> python3 roc.py <worker dir>.
import sys, os
name = os.environ['ROC_MUT']; w = sys.argv[1]
def edit(f, old, new, count=1):
    p = os.path.join(w, f); s = open(p).read()
    if old not in s: sys.exit(f'mutation {name}: "{old[:60]}" is not in {f}')
    open(p, 'w').write(s.replace(old, new, count))
C = 'lib/Compat.roc'
M = {
  # R-RE13 row 1, Q86, R-CT4: INSERT OR IGNORE drops a CHECK failure with no error.
  'or-ignore': lambda: edit(C, 'INSERT INTO compat (artifact,', 'INSERT OR IGNORE INTO compat (artifact,'),
  # R-MX8, R-RE6: the upsert changes the row to a smaller bound (the UPDATE trigger then stops with sweep-smaller).
  'sweep-no-where': lambda: edit(C, ' WHERE excluded.upto_log_index > sweeps.upto_log_index', ''),
  # R-MX5, G17: the check of `source` is a search of the text, not a member of the wire records.
  'source-naive': lambda: (edit(C, 'if wire.source.is_ok() {', 'if text.contains("\\"source\\"") {'), edit(C, 'if wire.rows.any(|r| r.source.is_ok()) {', 'if Bool.False {')),
  # R-MX9: the whole message and the kind.
  'failure-substring': lambda: edit(C, '{ kind: Trigger, message: "sweep-incomplete" } => SweepIncomplete', '{ kind: _, message } if message.contains("sweep-incomplete") => SweepIncomplete'),
  # R-MX9: the detail lists up to 100.
  'missing-cap-101': lambda: edit(C, 'missing_limit : U64\n\tmissing_limit = 100', 'missing_limit : U64\n\tmissing_limit = 101'),
  # R-AP10, R-AP56: the 400 of a target comes before the 404 of a hash.
  'plan-order': lambda: edit(C, '''		fact = match facts.artifacts.find_first(|a| a.artifact == r.artifact) {
			Ok(a) => a
			Err(_) => return Err(Reads.no_artifact(r.hash))
		}
		code = target_code(r, fact, facts)?''', '''		fact = match facts.artifacts.find_first(|a| a.artifact == r.artifact) {
			Ok(a) => a
			Err(_) => { if r.target != "any" { return Err(Problem.new(BadRequest, "the target ${r.target} has no code")) } else { return Err(Reads.no_artifact(r.hash)) } }
		}
		code = target_code(r, fact, facts)?'''),
  # R-AP46, R-AP62 (as the closure): the value checks come before the row limit.
  'limits-after-values': lambda: (edit(C, '''		if wire.rows.len() > row_limit {
			return Err(too_large("rows", row_limit))
		}
		rows = wire.rows.map_try(row_of)?''', '''		rows = wire.rows.map_try(row_of)?
		if wire.rows.len() > row_limit {
			return Err(too_large("rows", row_limit))
		}''')),
  # R-AP41, R-MX8: the rows and the sweep are two batches (a 422 leaves the rows written; one more D1 call).
  'split-batch': lambda: edit('CompatRoutes.roc', '''		match db.batch!(stmts) {''', '''		first = db.batch!(rows_stmts)
		match (if sweep_stmts.is_empty() then first else (match first { Ok(_) => db.batch!(sweep_stmts), Err(e) => Err(e) })) {'''.replace('if sweep_stmts.is_empty() then first else', 'if (sweep_stmts.is_empty()) first else')),
  # R-AP43: a 404 answer is put in the Cache API (R-AP55).
  'cache-404': lambda: edit('CompatReadRoutes.roc', 'if present.is_empty() {\n\t\t\t\t\t\t\treturn Err(Refuse(Reads.no_artifact(hash)))\n\t\t\t\t\t\t}', 'if present.is_empty() {\n\t\t\t\t\t\t\treturn Ok("{\\"hints\\":[],\\"runs\\":[]}")\n\t\t\t\t\t\t}'),
  # R-MX5, R-CT1: the contributor header wins over the token.
  'kind-contributor-first': lambda: edit(C, '(Ok(_), _) => Bot\n\t\t(Err(NotFound), Ok(_)) => Hint', '(_, Ok(_)) => Hint\n\t\t(Ok(_), Err(NotFound)) => Bot'),
  # R-AP40: the audit is not cut at the limit.
  'audit-limit': lambda: edit('lib/CompatReads.roc', 'Ok(n) => Ok(U64.min(n, audit_limit))', 'Ok(n) => Ok(n)'),
  # R-AP39: target other than any is accepted.
  'sweep-target-any': lambda: edit('lib/CompatReads.roc', 'Ok(other) => Err(Problem.new(BadRequest, "the query parameter target must be any, got ${other}"))', 'Ok(_) => Ok({})'),
}
# --- changes of 2026-11-02 (design answers Q139 to Q154) ---
M['list-excludes-request'] = lambda: edit('CompatRoutes.roc', '		Err(Refuse(Compat.sweep_incomplete({ tag: sweep.tag, upto_log_index: sweep.upto_log_index, missing })))',
    '		in_request = post.rows.map(|r| r.hash)\n		Err(Refuse(Compat.sweep_incomplete({ tag: sweep.tag, upto_log_index: sweep.upto_log_index, missing: missing.keep_if(|h| !in_request.contains(h)) })))')
# R-AP66 check 10, Q145: an empty list gives the normal text (0 members: ) in place of the text for the empty list.
M['empty-list-normal'] = lambda: edit(C, 'if k == 0 {', 'if k == 999999 {')
# R-AP66 check 6 before check 8 (Q142): the hash of a row is not checked as base58 of 32 bytes in parse_post; the row would be a 404.
import re
def hash_check_late():
    f = os.path.join(w, C); t = open(f).read()
    t2 = re.sub(r'artifact = Reads\.artifact_id\(w\.hash\)\.map_err\(.*\)\?\n', 'artifact = Reads.artifact_id(w.hash) ?? 0\n', t, count=1)
    if t2 == t: sys.exit('mutation hash-check-late: no match')
    open(f, 'w').write(t2)
M['hash-check-late'] = hash_check_late
M[name]()
