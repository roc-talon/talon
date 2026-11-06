# Until slice 104 lands it (R-AP58): Closure.Run and Closure.Nearest get a nullable error_digest, in the copy of packages/records of ref.sh.
import sys, os
p = os.path.join(sys.argv[1], 'records', 'Closure.roc'); s = open(p).read()
if 'error_digest : Str, from' not in s: sys.exit(0)
s = s.replace('error_digest : Str, from : Str, to : Str }', 'error_digest : Try(Str, [None]), from : Str, to : Str }', 1)
s = s.replace('error_digest : Str, nightly : Str, side : [Before, After] }', 'error_digest : Try(Str, [None]), nightly : Str, side : [Before, After] }', 1)
s = s.replace('RunWire : { hash : Str, target : Str, source : Str, result : Str, error_digest : Str,', 'RunWire : { hash : Str, target : Str, source : Str, result : Str, error_digest : Try(Nullable(Str), [Missing]),')
s = s.replace('NearestWire : { hash : Str, target : Str, source : Str, result : Str, error_digest : Str,', 'NearestWire : { hash : Str, target : Str, source : Str, result : Str, error_digest : Try(Nullable(Str), [Missing]),')
s = s.replace('error_digest: r.error_digest, from: r.from, to: r.to }))?', 'error_digest: Nullable.read(r.error_digest), from: r.from, to: r.to }))?')
s = s.replace('						error_digest: n.error_digest,', '						error_digest: Nullable.read(n.error_digest),')
s = s.replace('result: Code.result_to_str(r.result), error_digest: r.error_digest, from', 'result: Code.result_to_str(r.result), error_digest: Nullable.write(r.error_digest), from')
s = s.replace('				error_digest: n.error_digest,', '				error_digest: Nullable.write(n.error_digest),')
open(p, 'w').write(s)
