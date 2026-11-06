# Slice 109b: the W1 files (sql/tests) that insert `toolchains` rows get the `size` column. Run once from the repo root. Copies each changed file to before/.
import re, os, shutil
BEFORE = 'research/slice-109b-revert/before'
changed = []
def backup(p):
    d = os.path.join(BEFORE, p)
    if not os.path.exists(d):
        os.makedirs(os.path.dirname(d), exist_ok=True); shutil.copy2(p, d)
def edit(p, f):
    s = open(p).read(); t = f(s)
    assert t != s, p
    backup(p); open(p, 'w').write(t); changed.append(p)

HDR = 'INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index)'
HDRN = 'INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)'

# single-line and two-line forms with a literal tuple: (nightly, 'target', 'tag', 'asset', 'sha', published_at, log_index)
TUP = re.compile(r"\((\d+), ('[^']*'), ('[^']*'), ('[^']*'), ('[^']*'), (\d+), (\d+)\)")
def lit(s):
    out = []
    for line in s.splitlines(keepends=True):
        out.append(line.replace(HDR, HDRN) if HDR in line else line)
    s = ''.join(out)
    # tuples only in lines that are an insert into toolchains or the rows after one
    res, on = [], False
    for line in s.splitlines(keepends=True):
        if HDRN in line or 'INSERT INTO toolchains' in line: on = True
        if on:
            line = TUP.sub(lambda m: "(%s, %s, %s, %s, %s, %d, %s, %s)" % (m[1], m[2], m[3], m[4], m[5], 1000 + int(m[7]), m[6], m[7]), line)
            if line.rstrip().endswith(';'): on = False
        res.append(line)
    return ''.join(res)
for p in ['sql/tests/cases/triggers/t5-d1-error-text/steps.sql', 'sql/tests/cases/triggers/t5-d1-error-text/setup.sql', 'sql/tests/cases/triggers/t6-batch-rollback/setup.sql',
          'sql/tests/cases/schema/s5-keys-and-checks/steps.sql', 'sql/tests/cases/triggers/t2-sweep-guard/setup.sql', 'sql/tests/cases/triggers/t3-transitions/setup.sql',
          'sql/tests/cases/compat/a1-audit/setup.sql']:
    edit(p, lit)

# INSERT ... SELECT ?1, ?2, ?3, ?4, ?5, ?6, (SELECT MAX(idx) FROM log): a literal size after ?5 (the params stay)
def sel(s):
    s = s.replace(HDR, HDRN)
    return s.replace('SELECT ?1, ?2, ?3, ?4, ?5, ?6, (SELECT MAX(idx) FROM log)', 'SELECT ?1, ?2, ?3, ?4, ?5, 1000, ?6, (SELECT MAX(idx) FROM log)')
edit('sql/tests/cases/triggers/t1-publish/steps.sql', sel)

# c3: positional rows get a column list and the size
POS = re.compile(r"INSERT INTO toolchains VALUES \((\d+), ('[^']*'), ('[^']*'), ('[^']*'), ('[^']*'), (\d+), (\d+)\);")
edit('sql/tests/cases/closure/c3-order-window/setup.sql', lambda s: POS.sub(lambda m: HDRN + " VALUES (%s, %s, %s, %s, %s, %d, %s, %s);" % (m[1], m[2], m[3], m[4], m[5], 1000 + int(m[7]), m[6], m[7]), s))

# JS
edit('sql/tests/compat.mjs', lambda s: s.replace(
  "INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (?, ?, ?, ?, ?, ?, ?)', [n.id, t, n.tag, 'a', `${n.id}${t}`, n.published_at, ++i]",
  "INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [n.id, t, n.tag, 'a', `${n.id}${t}`, 1000, n.published_at, ++i]"))
def c1(s):
    s = s.replace("const insert = async (table, rows) => {", "const insert = async (table, rows, cols = '') => {")
    s = s.replace("`INSERT INTO ${table} VALUES ${rows", "`INSERT INTO ${table}${cols} VALUES ${rows")
    s = s.replace("q('ab'.repeat(32)), d.t, ++li])));", "q('ab'.repeat(32)), 1000, d.t, ++li])), ' (nightly, target, tag, asset_name, sha256, size, published_at, log_index)');")
    return s
edit('sql/tests/cases/closure/c1-random-reference/test.mjs', c1)

# s1-tables: the column list of the table
def s1(s):
    s = s.replace('toolchains\t7\t1\t1', 'toolchains\t8\t1\t1')
    return s.replace('toolchains\tsha256\tTEXT\t1\t0\t0\n', 'toolchains\tsha256\tTEXT\t1\t0\t0\ntoolchains\tsize\tINTEGER\t1\t0\t0\n')
edit('sql/tests/cases/schema/s1-tables/expect.tsv', s1)
print('\n'.join(changed))
