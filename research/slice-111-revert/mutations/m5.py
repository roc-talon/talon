# the path rule is Tar.check_path (safe under a root) in place of check_portable_path (roc unbundle)
import sys
d = sys.argv[1]
p = d + '/lib/ArchiveRead.roc'
s = open(p).read()
old = 'match Tar.check_portable_path(e.path) {\n\t\tErr(problem) => return refuse(BadPath({ path: e.path, problem }))'
new = 'match Tar.check_path(e.path) {\n\t\tErr(EmptyPath) => return refuse(BadPath({ path: e.path, problem: EmptyPath }))\n\t\tErr(Absolute) => return refuse(BadPath({ path: e.path, problem: Absolute }))\n\t\tErr(ParentDir) => return refuse(BadPath({ path: e.path, problem: ParentDir }))'
assert s.count(old) == 1, old
open(p, 'w').write(s.replace(old, new))
