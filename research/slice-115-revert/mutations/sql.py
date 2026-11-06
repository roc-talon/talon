# SQL mutations of the reference (slice 115). Usage: sql.py <name> <ref sql dir> <out dir>. Each mutation changes one behavior that a bug is likely to change.
import sys, os, shutil
name, src, out = sys.argv[1:4]
shutil.rmtree(out, ignore_errors=True); shutil.copytree(src, out)
def edit(f, old, new):
    p = os.path.join(out, f); s = open(p).read()
    if old not in s: sys.exit(f'mutation {name}: "{old}" is not in {f}')
    open(p, 'w').write(s.replace(old, new, 1))
M = {
  'window-gt': lambda: edit('prefix.sql', 'c.published_at >= (SELECT', 'c.published_at > (SELECT'),
  'author-counts': lambda: edit('missing.sql', ' AND c.source = 0', ''),
  'series-major-only': lambda: edit('prefix.sql', "AND ((r.version >> 48) <> -32768 OR ((r2.version >> 32) & 65535) = ((r.version >> 32) & 65535))", ''),
  'bound-null': lambda: edit('prefix.sql', 'COALESCE(?3, (SELECT COALESCE(MAX(idx), 0) FROM log))', 'COALESCE(?3, 0)'),
  'no-distinct': lambda: edit('prefix.sql', 'SELECT DISTINCT c.artifact', 'SELECT c.artifact'),
  'audit-bot-filter': lambda: edit('audit.sql', ' AND c.source = 0)', ' AND c.source = 1)'),
  'audit-app-target': lambda: edit('audit.sql', 'WHERE (h.target = 0 OR a.kind = 2)', 'WHERE (h.target = 0 OR a.kind IN (0, 2))'),
  'audit-order': lambda: edit('audit.sql', 'ORDER BY SUM(h.pass_count + h.fail_count + h.crash_count) DESC, n.value', 'ORDER BY SUM(h.pass_count + h.fail_count + h.crash_count) DESC, n.value DESC'),
  'audit-per-version': lambda: edit('audit.sql', 'GROUP BY h.artifact, h.nightly, h.target', 'GROUP BY h.artifact, h.nightly, h.target, h.talon_version'),
}
M[name]()
